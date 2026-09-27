---
description: Fix a bug that already exists, across one module or several. Reproduces it with a test, diagnoses it, writes a fix file per module, stops for approval, then applies them — one sub-agent per module, concurrently — logging every approach that failed and why. Given an existing bug.md, resumes it without retrying what its log rules out.
argument-hint: >-
  [ a bug report, a failing test, a stack trace, a backlog entry's id, or the path of an existing bug.md ]
allowed-tools: >-
  Bash(${CLAUDE_PLUGIN_ROOT}/scripts/fix/fix.sh *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/fix/fix.sh *)
  Bash(${CLAUDE_PLUGIN_ROOT}/scripts/cost/cost.sh *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/cost/cost.sh *)
  Bash(${CLAUDE_PLUGIN_ROOT}/scripts/findings/findings.sh *)
  Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/findings/findings.sh *)
---

# Fix Bug

Make code that already exists do what the repository already promised.

## When Not To Use It

**A bug is behaviour the repository already promises and does not deliver.** Where nobody promised it, this is a
feature.

- **New behaviour** — that is `design-task`, then `plan-task`. Where one new assertion proves it and no contract
  moves, `small-change`.
- **Restructuring code that behaves correctly** — that is `rework`.
- **A failure inside a plan still being implemented** — its own green phase owns that diff.

## The Three Kinds of Step

| Kind | What it does |
|------|--------------|
| `stabilize` | moves what the fix needs first: a signature, interface, or contract between two services |
| `red` | adds one test that reproduces the bug and fails on its symptom |
| `green` | changes production code until that test passes and the suite stays green |

**Every fix ends with a `red` step that failed and a `green` step that made it pass.** Their grammar is
[`step-format.md`](step-format.md). **Every approach that failed on the way is written into the log's
`## Attempts`**, with the output it produced — [`attempts.md`](../../templates/attempts.md).

## The Files

The fix owns `docs/<n>-<name>/`: one `bug.md`, one `fix.md` per module, and `shared/fix.md` where two modules
must agree on a contract — and beside each, its log: `bug-log.md`, `fix-log.md`, `shared/fix-log.md`. What each
carries is [`the-files.md`](the-files.md). Where the diagnosis reaches more than one
module, [`crossing-modules.md`](crossing-modules.md) decides which module the fix is cut in and what
`shared/fix.md` holds. `fix.sh` (`scripts/fix/` under the plugin root, README beside it) reads, ticks and
validates the files, and writes the log: `start` and `tick` keep `In flight:`, `block` appends to the Run Log.
Refused or absent on the first call, tell the user once as [`scripts/README.md`](../../scripts/README.md) says
and edit the files by hand.

## Conventions

Read the repository-wide conventions and `<module>/docs/conventions.md` for every module the bug reaches. They
answer the build and test commands, the test types and what each may fake, the layering check, how a test is
disabled, the cap on concurrent agents, the models, what runs before a commit, the commit policy, and what runs
over finished work. Every tier binds a step.

## Phase 0 — Reproduce and Baseline

**Given the path of an existing `bug.md`, [`resuming.md`](resuming.md) replaces this phase and Phase 1.**

**The affected modules are clean**, as [`baseline.md`](../../templates/baseline.md) says.

**Reproduce the bug.** Run what the report describes — the test, the request, the command.

- **It fails every time** — run it twice to know that. Record the exact output; `reproduces:` is written against
  it.
- **There is nothing to run yet.** Write the test that shows the symptom and take its failure as the reproduction.
  Then disable it, as [`disabling-a-test.md`](../../templates/disabling-a-test.md) says. It stays in the tree,
  uncommitted. The `red` step names it in `test-files:` and its work is to enable it. Take
  the cheapest test type that fails for the bug's own reason, and say in the diagnosis why a cheaper one does not.
- **It fails some runs and not others.** Run until it has failed twice and record `<failures> in <runs>`; that
  pair goes into `reproduces:`. The `red` step then runs until it has failed twice, giving up at three times that
  run count. The `green` step runs three times the runs the `red` step took, and passes every time.
- **It does not reproduce here, and could.** Stop, say what was run and what happened, ask for the missing
  condition. On a run started from a backlog entry, the paragraph below decides first.
- **It cannot reproduce here at all.** Stop, say what environment or data it needs. Whether to fix it blind is
  the user's call.

**Never write a fix for a bug nobody has seen fail.**

**A run started from a backlog entry measures the entry, not only the case it quotes**, as
[`backlog.md`](../../templates/backlog.md) says. Where it holds, the reproduction is the measurement.

**Baseline**, as [`baseline.md`](../../templates/baseline.md) says, with the reproduction test disabled or
reverted. Record beside the figures any machine state a skip depends on. **Name the disabled reproduction test
beside them.** The closing gate expects the skipped count one lower than measured. Red only on the test the
report already names is still a baseline.

## Phase 1 — Diagnose, and Write the Files

**Write `bug.md` and `bug-log.md` as soon as the symptom and the reproduction are known.** Then work out why
the bug happens: `## Why it happens` is a chain from the
symptom to the line that is wrong, every link proved. A probe — a log line, a counter, a query by hand, a seam a
test can drive — is how a link is proved. **A probe that failed is an attempt**, phase `diagnosis`, in the log's
`## Attempts`. A probe the fix needs again becomes a `stabilize` step. Every probe's edits are reverted before
the files are presented — the disabled reproduction test is the one edit that stays, uncommitted. An effect an
edit does not undo — a migration run, an offset consumed — is named in the diagnosis, put back by hand where
possible, and recorded as an `RL` entry in the log's Run Log.

Then write every `fix.md` with its `fix-log.md`, and run `fix.sh validate <the directory>` until it exits 0.

## Phase 2 — Stop

Present the files and stop. Nothing touches a source file until the user asks for the steps to be applied.

**Open Questions are rare here.** One is written only where the diagnosis needs a call the user must make, or
where the fix settles a decision worth an ADR under the Follow-Up conventions, or where an affected module has
performance tests. That module gets the question `plan-task` asks (**Open Questions**), the tests whose entry
point the fix's path reaches recommended. Ask them in one batch via `AskUserQuestion` and write each answer in as
`- A:`.

**A change the user rules out of scope here is filed now**, as a deferred change in the backlog. Its origin is
the answered `OQ` that records the decision ([`backlog.md`](../../templates/backlog.md)). Nothing else is
written about it.

**A fix turned down here** gets `**Closed:** <why>` in `bug.md`'s header — who decided and on what, in that one
line — is left where it is, and is reported as closed. The disabled reproduction test is reverted. **A fix called
off later** takes the same line. An effect nothing reverted is an `RL` entry in `bug-log.md`'s Run Log.

## Phase 3 — Apply

**Every `stabilize`, then every `red`, then every `green`**, in every fix. No file declares the order.

1. **`shared/fix.md` first, alone**, where there is one, by its own `fix-bug-module` agent given every module on
   the seam. Nothing else starts until it lands.
2. **One `fix-bug-module` agent per `fix.md`, concurrently**, spawned and waited for as
   [`templates/sub-agents.md`](../../templates/sub-agents.md) says. Each gets its file path and its log's,
   `bug.md`, its module's phase-0 figures, the conventions its module names, and what the shared fix disabled in
   that module.
   Cap the number running at once, and pick the model, by what the conventions say about the cap on concurrent
   agents and the models; where they state no cap, the default in `templates/sub-agents.md` applies.
3. **What happens inside an agent is its own** — its steps, its guardrails, its log, its ticks. Never edit a file
   or a log an agent owns while it runs. Report per module as each returns.

**An agent that returns on an exhausted budget is escalated once before anything is amended**
([`templates/sub-agents.md`](../../templates/sub-agents.md), **Budget and escalation**): re-spawn that module's
agent on the deciding model; it reads the log's **Attempts** and starts at that step. Only the escalation's
exhausted budget is a blocked return.

**An agent that returns blocked changes the plan, not the rules.** It returns for one of: an exhausted budget
after escalation, a symptom that survives a correct `green` step, a cause in another module, a step whose kind is wrong,
a test asserting the old behaviour that nobody foresaw, or a refusal from [`applying-a-step.md`](applying-a-step.md).
The return itself is an `RL` entry in that fix's log — the agent wrote it, or `fix.sh block` does. What follows
is [`templates/sub-agents.md`](../../templates/sub-agents.md), **A blocked return**; the files it amends include
`bug.md`, and a new `red`/`green` pair moves whole. An abandoned step is closed: `fix.sh task` counts it so.

### What Is Never Done

[`templates/applying-steps.md`](../../templates/applying-steps.md), **What is never done**, binds this session
too. A second defect found along the way is reproduced at Phase 4
([`reproducing.md`](../../templates/reproducing.md)).

## Phase 4 — Finish

1. **`fix.sh task docs/<n>-<name>/` exits 0.** Anything open: leave the directory in place and summarize what is
   open. The phases end there.
2. **The diff says what the steps claimed.** Read the diff from `**Baseline:**`, scoped to the affected modules'
   paths: every test file it touches is named in some step's `test-files:`, and each step changed only what it
   named. A test changed under no step is a defect whatever the suite says. Remove what a minimal green left
   behind in the same read: a stale intent comment, a dead stub branch, an unused import, a fixture duplicated
   from a neighbouring class, a step reference in a comment or a test name. **Nothing in `disables:` is still
   off**, and the skipped count is back to phase
   0's — apart from a machine state the baseline recorded, restored where it can be, and apart from the
   reproductions step 7 adds.
3. **A refactor round per module whose diff touches more than one production file or created one.** A diff
   inside one existing class gets none; step 2 read it. One `tdd-refactor-phase` agent per such module, on the
   model the module's conventions name for the refactor pass, the session's model where they name none. It gets
   the diff from `**Baseline:**`, `bug.md` and every `fix.md` as its brief, the module's conventions by name,
   and the last full suite run's figures with whether the tree has changed since. **It never touches a `red`
   step's test** — say so in the prompt. **It runs no suite**; step 4 is the run over its result.
4. **Full build and full suite of every affected module, green.** **Skipped where
   step 12's list holds an entry that runs the suite over this same tree**; the build conventions name it, and its
   verdict is this one. A red run belongs to the step or refactor that edited what failed.
5. **Whatever else the modules' build conventions require of a finished change** — a coverage guardrail, a
   formatting gate. A guardrail that fails blocks the archive.
6. **`fix.sh attempts docs/<n>-<name>/`** — one line naming every attempt in every log, for the report.
7. **Run every performance test the user's `- A:` named**, the way the testing conventions say, and keep each
   figure beside its threshold for the report. Then **write `review/findings.md`**, in the shape
   [`findings.md`](../../templates/findings.md) gives. A fix files **Critical**, **Bug** and **Performance** only.
   Every case the module agents reported is reproduced here, as [`reproducing.md`](../../templates/reproducing.md)
   says; a figure past its threshold is a **Performance** row. Create and update it as
   [`findings.md`](../../templates/findings.md) says. **File its open entries in the backlog** as [`backlog.md`](../../templates/backlog.md) says.
8. **Run `cost.sh report docs/<n>-<name>/`** and show the person what it printed. Refused or absent: say so and go on.
9. **Then write `review/report.md`** as [`report.md`](../../templates/report.md) says. **Measured** holds what
   step 7 ran; **Manual checks** holds every check a module agent reported that the suite cannot cover.
10. **Close the entry this fix came from**, where `Source:` names a backlog entry, as
   [`backlog.md`](../../templates/backlog.md) says.
11. **Archive**: move `docs/<n>-<name>/` into `docs/implemented/`, and commit the move where the conventions
   commit at all.
12. **What the conventions run over finished work**, in their order, each entry once, each handed the archived
   `bug.md`.

## Version Control

Commit as the conventions' commit policy says; where they state none, as
[`contract.md`](../../templates/conventions/contract.md) says.

## Report

[`report-format.md`](report-format.md).
