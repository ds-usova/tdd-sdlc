---
description: Implement a planned task end to end. Checks every plan is ready and every module is green, lands whatever crosses between the modules, then runs one pipeline agent per plan — concurrently — and finishes the task when the last one lands. Given a single plan, runs it the same way, as a task of one.
argument-hint: >-
  [ a task directory, or a single plan file ] [ optional section name ]
allowed-tools: >-
  Bash(${CLAUDE_PLUGIN_ROOT}/scripts/plan/plan.sh *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan/plan.sh *)
  Bash(${CLAUDE_PLUGIN_ROOT}/scripts/design/design.sh *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/design/design.sh *)
  Bash(${CLAUDE_PLUGIN_ROOT}/scripts/cost/cost.sh *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/cost/cost.sh *)
  Bash(${CLAUDE_PLUGIN_ROOT}/scripts/findings/findings.sh *)
  Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/findings/findings.sh *)
---

# Implement Plan

Use this skill when the user asks to implement a plan that was just discussed or is referenced by path — e.g.
"implement this plan", "implement docs/1-add-widget/plan.md".

**This skill runs the task. It never runs a plan itself.** Every plan is run by an
`implement-plan-module` sub-agent, which holds the stages, the guardrails and the tick policy. Your jobs are the
gates before anything starts, the seam that crosses modules, the pipelines, and finishing the task.

**Three levels, and each only coordinates the one below.**

| Level | Who                               | Owns                                                   |
|-------|-----------------------------------|--------------------------------------------------------|
| task  | this skill                        | the gates, the seam, the pipelines, finishing the task |
| plan  | `implement-plan-module`, one each | one plan's stages, guardrails and ticks                |
| step  | the step agents it spawns         | one class, one test class, one refactor pass           |

**Point a sub-agent at the rule; do not restate it.** A rule the repository writes down is passed as the file
that owns it, named so the agent reads it there, never as a remembered version of what that file says. The same
applies to counts and inventories drawn from the tree: read them, never recall them.

## Input Resolution

A task owns a directory: `docs/<n>-<task-name>/`, holding `spec.md`, `design.md`, `design-log.md`, one plan per
module with its `plan-log.md` beside it, and — where anything crosses between them — a `shared/plan.md`. Phase 3
adds a `review/` folder to it: the report of what was done, and beside it which test stands behind each
acceptance scenario, what the task left open, what it cost, and the evidence that everything else was measured.

| Invoked with     | The task directory is                                      |
|------------------|------------------------------------------------------------|
| a task directory | the one given                                              |
| a plan file      | `plan.sh task <that plan>` prints it, and every plan in it |
| nothing          | the plan referenced in the conversation, else ask          |

**A single plan is a task of one plan.** It takes exactly the phases below, and its one pipeline is spawned the
same way.

Read the repository-wide conventions, and `<module>/docs/conventions.md` for every module the task's plans name.
Follow the conventions index to wherever they live. They answer the build and test commands, the parallelism
rules and the version-control policy this skill needs, and each pipeline reads its own module's again.

## Phase 0 — Two Gates, Before Anything Is Spawned

Both are hard. Run them in this order.

**Before either gate, the scripts.** Run `plan.sh status` on one of the task's plans. Refused or absent, tell
the user and write that plan log's **Caveats** entry, as [`scripts/README.md`](../../scripts/README.md) says —
once, here in the session, before anything is spawned — and continue. Every check below that names a script
then has the same fallback: read the file and answer the question by hand.

**Gate 1 — every plan is ready.** A plan is ready only when the user has closed the loops the planning phase
opened. Check every plan in the task directory, `shared/plan.md` included:

- **The spec** beside the design the plan's `**Design:**` header links. `design.sh settled <design>` exits 0:
  no decision is still `must-decide`. `design.sh approved <design>` exits 0: the spec carries an `Approved`
  line whose hash matches the spec as it stands. Run both once for the design the plans share, not once per
  plan. Where `approved` fails, the line is missing or the spec changed after it was written. Either way: stop,
  and say to run `plan-task` on the task again. The script ships with the `design-task` skill at
  `scripts/design/design.sh`.
- **Open Questions**, in the plan: every `- **OQ<nn>:**` has a non-empty `- A:`.
- **Run Log**, in the `plan-log.md` beside it: every `RL` entry a previous partial run left with a `- Resolved:`
  line has that line filled.
- **Review Findings**, in the same log: every `- **RF<nn>:**` has a non-empty `- Action:`. A deliberate "won't fix"
  counts. A `mechanical` finding carrying `Action: applied — …` satisfies the gate on its own. A `decision`
  finding, and anything marked `- Escalated:`, needs the user's answer. A plan whose review found nothing has
  its "no issues found" line instead, and that passes.
- If an `Action:` or `A:` prescribes a change to the plan's steps or scenarios, confirm the plan text was
  actually updated to match. A decision written next to a finding but never applied to the step is unresolved.
- **A plan edited since its review is offered a re-review, never given one.** Where a step, scenario or
  signature changed after the last **Review Findings** entry — an `Action:` applied by hand, an answer that
  reshaped a step — say so once and ask, via `AskUserQuestion`, whether to spawn `review-plan` on it before
  going on. Declined, the gate proceeds; accepted, its findings join the log and are actioned like the rest.

**One unready plan stops the task, with nothing started.** List what is unresolved and ask the user. If they
resolve it in the conversation, write their answers into the plan or its log, apply the resulting step changes,
and only then proceed.

**Gate 2 — every module is green.** Run the full build and entire test suite, including the architecture test,
of every module the task's plans name. Use the commands from each module's conventions.

- **Everything green**, the expected case: proceed.
- **Anything already red**: stop immediately, before a file is touched. Report the failures — test name, error,
  suspected cause — and wait. Do not fix them.

Record each module's run: `plan.sh suite record --stage baseline --total <n> --skipped <n> --verdict green
<module paths> <plan>`, on every plan that module has. Each pipeline is handed its own module's total and
skipped counts.

**No pipeline repeats either gate.**

**A measurement is not repeated over an unchanged tree.** Before a guardrail runs a module's full suite, it
asks `plan.sh suite check <plan>`. Exit 0: the tree matches the last recorded run; read its figures and go on.
Exit 1: run the suite, then `plan.sh suite record` it. A guardrail still gates the commit that follows it. Where
the script is refused or absent, run the suite.

## Phase 1 — The Seam, Alone

Present only when the design named an artifact more than one module reads at build time — a schema, a generated
contract, a repository-root file. Then the task holds `shared/plan.md`, and it is implemented first and alone,
by its own `implement-plan-module` agent.

- **It owns the seam, both sides' wiring to it, and whatever the change to it breaks** — the artifact, each
  consuming module's generation or build hookup, and every call site the regenerated code no longer satisfies.
- **It stabilizes those call sites; it never reimplements them.** A changed signature keeps its logic and gains a
  `TODO`, a new method gets a stub with its intent comment, a test that cannot compile is disabled rather than
  removed.
- **Its exit guardrail is Stage 1's, over every module it lists** — they compile, their architecture tests pass,
  their pre-existing suites are still green, and nothing was lost. Never a bespoke compile check. Tell its agent
  that its Affected Modules are all of them, not one. A module whose files this plan never touched — one that
  only regenerates from the artifact and compiles clean — is answered by phase 0's figures under the rule above.
- **A disabled test's reason names the module plan and step that owes the rework** — `module-a/plan.md · RI03`.
- **A blocked shared plan stops the task here**, with no module pipeline started. Report it and stop.

## Phase 2 — One Pipeline Per Plan

Spawn one `implement-plan-module` sub-agent per module plan, in the shape
[`templates/sub-agents.md`](../../templates/sub-agents.md) gives. Give each its plan path, its module's phase-0
figures, and the section name if the user narrowed the run to one.

- **Nothing waits.** One blocking does not stop the rest.
- **A pipeline that returns with children in flight is resumed, not restarted.** It picks up its own plan and
  ticks. Resuming is [`templates/sub-agents.md`](../../templates/sub-agents.md)'s **continue an agent** row.
- **A step agent's report can arrive here.** A grandchild's task-notification reaches you, not the pipeline
  that spawned it. Relay what it says in the message that resumes the pipeline.
- **How many start at once is the repository tier's answer.** Read the cap on concurrent agents at the level
  that binds all the modules and start no more pipelines than it allows, starting the next as a running one
  finishes. If no cap is stated, the default in [`templates/sub-agents.md`](../../templates/sub-agents.md)
  applies.
- **What happens inside a pipeline is its own.** Its module's cap, its stage order, its guardrails, its ticks.
  You reconcile nothing about a step and never edit a plan a pipeline owns.
- **Report per plan as each returns.** One finishing does not wait for another.

## Phase 3 — Finish The Task

When every pipeline has returned:

1. **Ask `plan.sh task docs/<n>-<task-name>/`.** It lists every plan the directory holds and exits 0 only when
   all of them are complete, `shared/plan.md` included. Anything else: leave the directory in place and summarize
   what is open. The phases end here.

   **No suite runs here.** A module whose files moved after its pipeline returned is a defect: something wrote
   outside its own module. Record it in that plan's Run Log. Rerun that module's suite. Stop on red.
2. **Ask `plan.sh acceptance docs/<n>-<task-name>/`.** It follows every `AC` scenario in `spec.md` to a ticked
   step, that step's test class and the file in the tree that holds it
   ([`scripts/plan/README.md`](../../scripts/plan/README.md), **Acceptance**). Write what it printed to
   `review/acceptance.md`, verbatim. A scenario it reports as `missing` or `absent` is a Run Log entry for
   the plan that named it, measured like any other in the next step. It never stops the phases.
3. **Write `review/findings.md`** — everything the task leaves open, from every plan at once.

   Each plan log's **Run Log** is the source. Lift what is **still open** — a confirmed defect no scenario
   covered, a gap the design never named, an inconsistency the change left behind. A blocker the run settled
   stays in the log as that plan's history and never appears here; so does a question the plan already answers.

   **A Run Log entry is not a finding yet.** Measure each one — one pass over the class it claims — before it
   becomes a block or a row, per [`findings.md`](../../templates/findings.md)'s **Measured, Not Noticed**. What
   the measurement contradicts stays in the log as history; what it narrows is filed narrowed; what one pass
   cannot settle is reported to the user as unmeasured and filed nowhere.

   The shape is [`findings.md`](../../templates/findings.md). A task fills all five of its sections. A
   **Deferred change** is behaviour the design did not ask for and the code should have — never a defect, never
   a cleanup; it becomes its own task later, not a rework.

   Create and update it as [`findings.md`](../../templates/findings.md) says.

   **Run `cost.sh report docs/<n>-<name>/` before archiving** and show the person what it printed. Refused or
   absent: say so and go on.

   **A bug block is a reproduction the pipelines reported** ([`reproducing.md`](../../templates/reproducing.md)).
   Nothing else becomes one.

   **A performance figure over its threshold is a Performance row** — the test, the threshold and the figure,
   from the pipelines' reports ([`findings.md`](../../templates/findings.md)). A figure under its threshold is
   not a row. The test itself stays in the tree either way.

   **Every critical block, bug block, `RX`, `DX` and `PX` row it files is appended to `docs/backlog.md`**, one
   pointer each, in the shape [`backlog.md`](../../templates/backlog.md) gives — a `BC` row per critical
   block, a `BB` row per bug, a `BR` row per candidate, a `BT` row per deferred change, a `BP` row per
   performance figure, each taking the next id in its table, with the link written to the archived path. The
   findings file stays the row's owner.

   **Close the row this task came from.** Where the spec's **Objective** names a backlog `BT` row, close the
   owning `DX` row as [`findings.md`](../../templates/findings.md) says. Update the backlog as
   [`backlog.md`](../../templates/backlog.md) says.
4. **Write `review/report.md`**, last, as [`report.md`](../../templates/report.md) says. Its **Done** and
   **Measured** rows come from the pipelines' reports. **A figure under an open `BP` row's threshold closes that
   row** as [`findings.md`](../../templates/findings.md) says. Update the backlog as
   [`backlog.md`](../../templates/backlog.md) says.
5. **Archive**, on exit 0 from `plan.sh task` and on nothing else: move the **whole task directory** — every
   `plan.md` and its `plan-log.md`, the `design.md` they link, the `spec.md` and `design-log.md` beside it,
   `review/`, and anything else the task accumulated — into `docs/implemented/`. Move the directory, not the
   files.
6. **Commit** per the commit policy. This is where its **squash-before-archiving** setting applies.
7. **What the conventions run over finished work.** Every affected module's conventions say what happens once a
   change is complete — a measurement, a documentation pass. Follow the conventions index to wherever they say
   it, and run that list in its order, passing each entry the archived plan. An entry listed by several affected
   modules runs once. Each states its own commit behaviour.

## Version Control

Whether this run commits at all, and how, is the conventions' commit policy. Expect it at the level that binds
all the modules.

**Missing or silent means no commits.** Never invent a commit policy.

**Several pipelines commit into that one history at once.** Follow whatever the policy says about scoping a
commit and about a concurrent one, and report a refusal it does not cover rather than improvising a retry.

## Response Style

- One line per phase as it starts, and one per pipeline as it returns.
- A pipeline's own progress is its report, not yours to relay in full.
- Final summary: every plan log's **Caveats** first, as [`scripts/README.md`](../../scripts/README.md) says;
  then whether the task was archived, and a pointer to `review/report.md` rather than a second copy of what it
  says.
