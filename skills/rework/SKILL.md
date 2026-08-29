---
description: Restructure code that already exists without changing what it does. Reads the code, writes a rework file with the edits at code level, stops for approval, then applies them — one agent per module, concurrently — against the suite that is already green.
argument-hint: [ a findings entry, a file or class, a description of what to change, or the path of an existing rework.md ]
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/rework/rework.sh *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/rework/rework.sh *)
---

# Rework

Change the shape of code the repository already has, never what it does. The suite that is already green is the
safety net.

## The Five Kinds of Step

- `inline` reshapes or relocates inside classes that already exist
- `extract` moves responsibility to another class, new or already there
- `tests` restructures test code and touches no production file
- `pin` adds, tightens or drops a check or a setting
- `stabilize` moves a signature and carries every call site it breaks to compiling

What each edits, runs and owes is [`applying-a-step.md`](applying-a-step.md); its lines are
[`step-format.md`](step-format.md). Both sit beside this file.

**Moved code needs no red leg.** **A `stabilize` step is the precondition of whatever works against the signature
it moved.**

## When Not To Use It

- **Anything a caller could not ask for before** — a feature, a field, a changed outcome, however small the diff.
  That is `design-task`, then `plan-task`.
- **A bug** — `fix-bug`.
- **Cleanup inside a plan still being implemented** — its own refactor pass owns that diff. A row the plan's
  finished `review/findings.md` left behind is this skill's input, not that pass's.

## Input Resolution

The argument is a row from a task's `review/findings.md`, a file or class name, or a description. Each is a
starting point; the scope comes from reading the code. **A path to an existing `rework.md` resumes it** under
[`resuming.md`](../../templates/resuming.md), which replaces Phase 0 and Phase 1.

Read the repository-wide conventions and `<module>/docs/conventions.md` for every module the change reaches.
They answer the build and test commands, the layering rule and what checks it, the diagram format, how a test is
disabled, what runs before a commit, the commit policy, and **what this repository says about refactoring** — its
priorities, where extracted code goes, what it will not have touched. All of it binds a step.

## Phase 0 — Baseline

**The affected modules are clean before anything is measured.** Uncommitted work under one: name the files and
stop. Uncommitted work elsewhere is left alone.

**A run started from a backlog `C` row, or from a findings entry directly, measures it before the suite.** Check
the entry's *why* against the code it names, in one pass over the whole class it generalizes over
([`findings.md`](../../templates/findings.md), **Measured, Not Noticed**).

- **It holds** — proceed; the measurement is the first line of `rework.md`'s context.
- **It holds for fewer cases than it claims** — the scope is what the measurement found, and the file says so.
- **It does not hold**, or the change it asks for would break what is already correct: report what was measured,
  set the entry's `Status` to `withdrawn` with that clause, remove its `C` row from `docs/backlog.md` in the
  same edit, and stop.

Run the full build and the entire suite of every affected module with its own commands. A whole-suite run that
already answers for this commit is read, not repeated; that holds at every gate in this skill.

- **Green**: record the commit.
- **Anything red**: stop, change nothing, report the failures. Fixing them is not this rework's scope.

Nothing is written before this passes.

## Phase 1 — Write the Files

A rework owns `docs/<n>-<name>/`: `rework.md`, one steps file per agent where it reaches more than one module,
and **a log beside every file that holds steps** — `rework-log.md`, `<module>/steps-log.md`,
`shared/steps-log.md` — written here with its title alone. What each holds is [`the-files.md`](the-files.md).
`rework.sh` (`scripts/rework/` under the plugin root, README beside it) reads, ticks and validates them, and
`rework.sh block` writes the log. Refused or absent on the first call, tell the user once as
[`scripts/README.md`](../../scripts/README.md) says and edit the files by hand.

Run `rework.sh validate <the directory>` until it exits 0 before presenting anything; a missing log fails it.

## Phase 2 — Stop

Present the files and stop. Ask every Open Question in one batch via `AskUserQuestion`, and write each answer
into the file as its `- A:`.

**Do not touch a source file until the user asks for the steps to be applied.** A step whose kind the user
disputes is re-classified in the file first.

**A rework that settles a decision worth recording asks here whether to record it**, as a numbered Open Question
like any other. An answered `yes` is what authorizes the archiving pass to write it down. Most reworks settle
none and ask nothing.

## Phase 3 — Apply the Steps

**`rework.sh validate` exits 0 on every steps file and its log before the first source file is touched**, again
after any answer or re-classification written in Phase 2.

1. **`shared/steps.md` first, alone**, where there is one, by its own `rework-module` agent given every module
   on the seam. Its exit condition: every module on the seam compiles, passes its layering check, and its suite
   stands where phase 0 left it apart from exactly what its `disables:` turned off. A blocked shared file stops
   the run there.
2. **One `rework-module` agent per steps file, concurrently**, spawned and waited for as
   [`templates/sub-agents.md`](../../templates/sub-agents.md) says, each handed its file's path, its module, its
   baseline figures, what the shared file disabled in its module, and `rework.md`. It applies its steps in ID
   order and returns finished or blocked. A blocked agent's question is written into its steps file's
   `## Open Questions` and the return itself is a `B` entry in the log's Run Log; answer the question there,
   fill the entry's `Resolved:`, and spawn the agent again.

**A step reaches a sub-agent as `rework.sh show <ID> --file <steps>`**, never as a prompt retelling it.

**Whether anything is committed is the conventions' Version Control rules.** A repository silent on it gets no
commits anywhere in this skill. Where they do commit, the step's own green run is the guardrail the commit
follows, and the commit is provisional: the closing full run proves the whole.

### What Is Never Done

- A test is never deleted or weakened to make a step green. A `stabilize` step may disable one, under the rule
  [`applying-a-step.md`](applying-a-step.md) gives for it.
- A defect found along the way is reported, never fixed. It is a new rework or a new task.
- Nothing outside the steps is improved because it was nearby. A step never reaches past its own boundary.

## Phase 4 — Finish

1. **Nothing left in any `disables:` is still off**, and every steps file's last run is green. Anything red or
   still disabled names the step that left it, and the directory is not archived. An invariant from **What must
   stay true** that could not be kept, and a step abandoned — `abandoned — <why>` on its header, its `B` entry
   in the log's Run Log — are reported here; `status` counts an abandoned step closed and lists it apart.
2. **A refactor round per module** — see below. **Then one full build and full suite of every affected module,
   green** — the one full run of the rework. **Skipped where item 6's list holds an entry that runs the suite
   over this same tree**; the build conventions name it, and its verdict is this one. A red run belongs to the
   step or refactor that edited what failed.
3. **Write `review/findings.md`** into the rework's directory, in the shape
   [`findings.md`](../../templates/findings.md) gives: **Critical**, **Bug**, and **Manual test** where the
   change needs a person to look. **What the module agents reported is measured before it is filed**
   (**Measured, Not Noticed**): a defect an agent noticed and did not reproduce is reproduced here or left in
   the log, never turned into a block on its say-so. Where the rework touched one module, the section's opening
   line names it instead of the module-first rule. **A rework files no refactoring candidates**; something worth doing later
   goes in the report, and the user decides whether it becomes a rework. **It may file a Deferred change**: a
   behaviour the code should have that this rework, being behaviour-preserving, could not add. A rework with
   nothing open still gets the file. **Every bug block and every `D` row it files is appended to
   `docs/backlog.md`** — a `B` row per bug, a `T` row per deferred change, each taking the next id in its table,
   in the shape [`backlog.md`](../../templates/backlog.md) gives, with the link written to the archived path.
4. **Close the row this rework came from.** Where `Source:` names a findings file and a row, set the row's
   `Status`: `done · <this rework's number>`, or leave it `open` with one clause naming what remains. A row set
   to `done` leaves `docs/backlog.md` in the same edit — its `C` row is removed, never
   struck through ([`backlog.md`](../../templates/backlog.md)); one left `open` keeps its backlog row. Nothing
   here blocks.
5. **Archive** once the closing gate is clean and `rework.sh status` reports every steps file ticked — a manual
   check open in `review/findings.md` never blocks: move `docs/<n>-<name>/` into `docs/implemented/`, and commit
   the move where the conventions commit at all.
6. **What the conventions run over finished work.** Every affected module's conventions list what happens once a
   change is complete — a coverage guardrail, a formatting gate, a measurement, a documentation pass. Run that
   list in its order, passing each entry the archived `rework.md`. An entry listed by several modules runs once,
   and a gate item 2 already ran over the same tree is not run again.

### The Refactor Round

**One `tdd-refactor-phase` agent per affected module, over that module's diff**, on the model the module's
conventions name for the refactor pass — the session's model where they name none. Never one pass across two
modules: that is a diff no single set of refactoring conventions describes. Each gets its module's diff from the
**Baseline:** commit, `rework.md` as the brief a tidier shape must not contradict, the module's conventions
by name, and the last full suite run's figures for its module with whether the tree has changed since.

## Report

What the finished rework tells the user is [`report-format.md`](report-format.md), beside this file.
