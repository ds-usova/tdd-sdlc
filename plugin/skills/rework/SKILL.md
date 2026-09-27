---
description: Restructure code that already exists without changing what it does. Reads the code, writes a rework file with the edits at code level, stops for approval, then applies them — one agent per module, concurrently — against the suite that is already green.
argument-hint: >-
  [ a backlog entry's id, a findings entry, a file or class, a description of what to change, or the path of an existing rework.md ]
allowed-tools: >-
  Bash(${CLAUDE_PLUGIN_ROOT}/scripts/rework/rework.sh *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/rework/rework.sh *)
  Bash(${CLAUDE_PLUGIN_ROOT}/scripts/cost/cost.sh *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/cost/cost.sh *)
  Bash(${CLAUDE_PLUGIN_ROOT}/scripts/findings/findings.sh *)
  Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/findings/findings.sh *)
---

# Rework

Change the shape of code the repository already has, never what it does.

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
  That is `design-task`, then `plan-task`. Where one new assertion proves it and no contract moves,
  `small-change`.
- **A bug** — `fix-bug`.
- **Cleanup inside a plan still being implemented** — its own refactor pass owns that diff. A row the plan's
  finished `review/findings.md` left behind is this skill's input, not that pass's.

## Input Resolution

The argument is a backlog entry's id, a row from a task's `review/findings.md`, a file or class name, or a
description. Each is a starting point; the scope comes from reading the code. **A path to an existing
`rework.md` resumes it** under [`resuming.md`](../../templates/resuming.md), which replaces Phase 0 and Phase 1.

Read the repository-wide conventions and `<module>/docs/conventions.md` for every module the change reaches.
They answer the build and test commands, the layering rule and what checks it, the diagram language, how a test
is disabled, what runs before a commit, the commit policy, the cap on concurrent agents, the models, and **what
this repository says about refactoring** — its priorities, where extracted code goes, what it will not have
touched. All of it binds a step.

## Phase 0 — Baseline

**The affected modules are clean before anything is measured**, as
[`baseline.md`](../../templates/baseline.md) says.

**A run started from a backlog entry, or from a findings entry directly, measures it before the suite**, as
[`backlog.md`](../../templates/backlog.md) says. A performance entry is measured by rerunning its test. A change
that would break what is already correct does not hold either. A findings entry that does not hold is closed as
[`findings.md`](../../templates/findings.md) says. Where it holds, the measurement is the first line of
`rework.md`'s context.

**Baseline**, as [`baseline.md`](../../templates/baseline.md) says. Its read-not-repeated rule holds at every gate
in this skill. Nothing is written before this passes.

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

**An affected module with performance tests gets the question `plan-task` asks** (**Open Questions**), the tests
whose entry point a step's files sit under recommended. The answer is read at the close.

**Do not touch a source file until the user asks for the steps to be applied.** A step whose kind the user
disputes is re-classified in the file first.

**A change the user rules out of scope here is filed now**, as a deferred change in the backlog. Its origin is
the answered `OQ` that records the decision ([`backlog.md`](../../templates/backlog.md)).

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
   [`templates/sub-agents.md`](../../templates/sub-agents.md) says, capped and given its model by what the
   conventions say about the cap on concurrent agents and the models, the default there where they say
   nothing; each handed its file's path, its module, its
   baseline figures, what the shared file disabled in its module, and `rework.md`. It applies its steps in ID
   order and returns finished or blocked. An agent returning on an exhausted budget is escalated once before
   its return counts as blocked ([`templates/sub-agents.md`](../../templates/sub-agents.md), **Budget and
   escalation**). A blocked return is [`templates/sub-agents.md`](../../templates/sub-agents.md), **A blocked
   return**.

**A step reaches a sub-agent as `rework.sh show <ID> --file <steps>`**, never as a prompt retelling it.

**Commit as the conventions' commit policy says**; where they state none, as
[`contract.md`](../../templates/conventions/contract.md) says.

### What Is Never Done

[`templates/applying-steps.md`](../../templates/applying-steps.md), **What is never done**, binds this session
too. A defect found along the way is a new rework or a new task.

## Phase 4 — Finish

1. **Nothing left in any `disables:` is still off**, and every steps file's last run is green. Anything red or
   still disabled names the step that left it, and the directory is not archived. An invariant from **What must
   stay true** that could not be kept, and a step abandoned — `abandoned — <why>` on its header, its `RL` entry
   in the log's Run Log — are reported here; `status` counts an abandoned step closed and lists it apart.
2. **A refactor round per module** — see below. **Then one full build and full suite of every affected module,
   green** — the one full run of the rework. **Skipped where item 8's list holds an entry that runs the suite
   over this same tree**; the build conventions name it, and its verdict is this one. A red run belongs to the
   step or refactor that edited what failed.
3. **Run every performance test the user's `- A:` named**, the way the testing conventions say, and keep each
   figure beside its threshold for the report. Then **write `review/findings.md`** into the rework's directory,
   in the shape [`findings.md`](../../templates/findings.md) gives: **Critical**, **Bug** and **Performance** — a
   figure past its threshold; a check the change needs a person to make is the report's, below. **What the
   module agents reported is measured before it is filed**, as **Measured, Not Noticed** there says; a defect is
   reproduced as [`reproducing.md`](../../templates/reproducing.md) says. **Critical** takes
   what the refactor round measured as growing with every task on top, a copied block this rework touched in every
   copy included. Where the rework touched one module, the section's opening line names it instead of the
   module-first rule. **A rework files no refactoring candidates**; something worth doing later goes in the report,
   and the user decides whether it becomes a rework. **It may file a Deferred change**: a behaviour the code should
   have that this rework could not add. Create and update it as [`findings.md`](../../templates/findings.md)
   says. **File its open entries in the backlog** as [`backlog.md`](../../templates/backlog.md) says.
4. **Run `cost.sh report docs/<n>-<name>/`** and show the person what it printed. Refused or absent: say so and go on.
5. **Then write `review/report.md`** as [`report.md`](../../templates/report.md) says. **Measured** holds what
   item 3 ran; **Manual checks** holds every check the change needs a person to make.
6. **Close the entry this rework came from**, where `Source:` names a backlog entry, as
   [`backlog.md`](../../templates/backlog.md) says. Nothing here blocks.
7. **Archive** once the closing gate is clean and `rework.sh status` reports every steps file ticked — a manual
   check open in `review/report.md` never blocks: move `docs/<n>-<name>/` into `docs/implemented/`, and commit
   the move where the conventions commit at all.
8. **What the conventions run over finished work.** Every affected module's conventions list what happens once a
   change is complete — a coverage guardrail, a formatting gate, a measurement, a documentation pass. Run that
   list in its order, passing each entry the archived `rework.md`. An entry listed by several modules runs once,
   and a gate item 2 already ran over the same tree is not run again.

### The Refactor Round

**One `tdd-refactor-phase` agent per affected module, over that module's diff**, on the model the module's
conventions name for the refactor pass — the session's model where they name none. Never one pass across two
modules. Each gets its module's diff from the
**Baseline:** commit, `rework.md` as the brief a tidier shape must not contradict, the module's conventions
by name, and the last full suite run's figures for its module with whether the tree has changed since.

## Report

What the finished rework tells the user is [`report-format.md`](report-format.md), beside this file.
