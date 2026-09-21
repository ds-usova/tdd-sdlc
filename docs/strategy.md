# Why the framework has this shape

[`README.md`](../README.md) says what the plugin does. This file says why.

## Framework versus project

**The skills are the framework. The conventions are the project.**

A skill names what it needs — the build command, the test-type mapping, the diagram language, the sub-agent
models, the commit policy — and never supplies the value. Every value lives in your repository's conventions,
`docs/conventions.md` for the repository and `<module>/docs/conventions.md` per module, written by
`init-conventions` from what the repository already does.

A rule paraphrased into a prompt is a second copy that drifts where no review looks. So a skill names the fact
it needs and lets the agent follow the conventions index to it. The facts, who reads each, and the default when
one is absent: [`contract.md`](../plugin/templates/conventions/contract.md). Where your repository says nothing, the
skill has a default — PlantUML with C4, the session's model, generic layer names — and the run continues on the
default instead of stopping. The two facts with no default, the build commands and the test-type mapping, stop
it.

## Files are the contract between steps

Every step writes its files and stops — `spec.md` with `design.md` and `design-log.md`, `plan.md` with
`plan-log.md`, `rework.md` with `rework-log.md`, `upgrade.md` with `upgrade-log.md`; `fix-bug` writes `bug.md`,
then `fix.md`, each with its log. The next step reads the file, not the conversation. It may run in the same session
or a fresh one, and must work the same either way. An answer given in chat is written into the file before it
counts.

That is also how each file is judged. A design a cold session cannot plan from was underspecified; a plan a cold
agent cannot implement was underspecified. A script per file (`design.sh settled`, `plan.sh validate`, …) makes
"finished" a mechanical verdict the next step gates on.

## Gates, not reports

A gate is a command whose real output decides whether the next stage runs: the suite is green, the new tests
fail, the test count is unchanged, no plan has an open item. It is run by the agent that owns the stage, never
by the one reporting on it. **No gate is ever passed on a sub-agent's claim**, and a failed gate never advances.
That is what makes it safe to run individual steps on a cheaper model.

## A design for the person, a plan for the model

The feature workflow — design, plan, implement — has two readers. A person approves what the change does and
what it does when it fails — the design, with no class in it. A model executes how it is built — the plan, with
every class, signature and test scenario. The handoff between them is the spec and its design, settled when every
decision it lists has an answer.

The design contains no implementation reading list. A repository fact that answers a design question is evidence
in `design-log.md`; a class or file that changes is a plan fact. Files inspected during research leave no record
unless they support a decision. This keeps the design readable in any technology and gives each fact one home.

The plan's diagrams are an approval surface, not proof that the planner found every class. They show one
architectural placement decision at a time and omit routine implementation targets. The step map supplies those
targets to agents, while plan review checks all of them against the repository and its conventions. A large feature
therefore gives the person several small choices to judge instead of one exhaustive dependency graph to skip.

Rework, bug-fixing and upgrades have only the person to satisfy, so each is one skill: write the steps, stop
for approval, apply them. Their safety net is the suite already green. A bug fix additionally owes one test that
failed on the symptom before the fix; bug fixes and upgrades log every attempt that failed, so a stopped run
leaves a record.

## One agent per module

A module is a part of the system with its own build and its own tests — a backend service, a web app, a shared
library. One toolchain, one set of conventions, one plan, one agent.

A task spanning modules keeps one design and gets one plan per module. Whatever crosses between them — a schema
both builds read — is its own `shared/plan.md`, landed first and alone, so the module plans wait on nothing.

Each plan's agent fans out into step agents, one per class or test class. Three levels, each coordinating only
the one below: a step never sees another plan, a pipeline never sees another module, and only the task level
can tell the task is finished.

## Proportionality

Ceremony that costs more than the change buys nothing, because it does not get used. A user who must write a
spec, a design and a plan to move a button will move the button by hand, and the repository then holds two kinds
of change: the ones with a record and the ones without. That is the drift the framework exists to stop, arriving
by the back door.

So one count decides the path: **how many new assertions prove the change**. One is a small change, and
`small-change` owns it. More is a feature. A moved contract is a feature at any count, because what a contract
costs is paid by whoever depends on it.

The user picks by size. What follows from it — whether the spec is amended, whether a test is possible, which
tests run — the skill decides, and writes down what it decided.

## Where the plugin stops

The feature workflow ends at `implement-plan`: the task directory moves to `docs/implemented/`, and whatever your
conventions list as running after a change is run. What a run could not finish — a bug it found, a refactoring it
declined to do inside a feature, a behaviour the design never asked for — gets one row in `docs/backlog.md`, which
outlives the archived task and feeds the next `fix-bug`, `rework` or `design-task` run. A task directory still under
`docs/` is itself the record of unfinished work. `review/report.md` is what a finished run says for itself: what
was done, measured and left, linking the findings and `review/cost.md`, the run's cost per agent and per model
([`cost-recording.md`](cost-recording.md)). Documentation, release notes, and everything else that
outlives the plan are your repository's job, in whatever form it already keeps them.

An archived task is not closed for good. `small-change` takes one back out of `docs/implemented/`, amends its
spec, and archives it again at the same path, so the backlog rows pointing there keep resolving. The third such
change to one task is a feature, and the run ends there.

## The ids

Every id is two capital letters and at least two digits, one prefix per kind, no letter pair reused across
files, so `DN03` can be cited from anywhere without saying which file it lives in. Numbers are assigned once and
never reused; a withdrawn entry keeps its number.

An id never appears in a commit message, a test name, a class, a file or a comment. Those outlive the task
directory, which moves to `docs/implemented/` when the work lands, so the id would stop resolving exactly when a
reader met it. The one exception is a disabled test's reason: it names the step that owes the rework, and it
clears itself when that step lands.

| Prefix                          | Names                                        | Lives in                  | Scope       |
|---------------------------------|----------------------------------------------|---------------------------|-------------|
| `RQ` `AC` `DN`                  | requirement, acceptance scenario, decision   | `spec.md`                 | the task    |
| `DF`                            | design finding                               | `design-log.md`           | the task    |
| `ST` `RU` `RI` `RS` `GU` `GI` `GS` `PM` `PI` | plan steps                      | `plan.md`                 | one plan    |
| `OQ`                            | open question                                | any steps-carrying file   | that file   |
| `RF`                            | review finding                               | `plan-log.md`             | one plan    |
| `RL` `AT`                       | run-log entry, attempt                       | every log                 | that log    |
| `FS` `FR` `FG`                  | fix steps: stabilize, red, green             | `fix.md`                  | that file   |
| `WK`                            | rework step                                  | `rework.md`, `steps.md`   | that file   |
| `UP`                            | upgrade step                                 | `upgrade.md`, `steps.md`  | that file   |
| `RX` `DX` `PX`                  | refactoring candidate, deferred change, performance figure | `review/findings.md` | the task |
| `BB` `BR` `BT` `BP`             | backlog bug, rework candidate, deferred task, performance figure | `docs/backlog.md` | the repository |

The commit-message hook refuses exactly this list, and nothing shaped like it occurs in ordinary prose. The
format number every file carries, and what changed between formats, is
[`scripts/README.md`](../plugin/scripts/README.md), **Formats**.

## Rules that look stricter than they need to be

Each of these is stated as a bare rule in a skill, an agent or a template. This is why.

- **The author never reviews its own file.** The grill and the plan review run in spawned agents, never in
  the session that wrote the design or the plan, and the planner never regrades a `Resolution:` the reviewer
  assigned. The writing session holds the reasoning that produced the file; the reviewer must judge the file as
  written. A planner grading the review of its own plan reclassifies real objections into things it can quietly
  apply.
- **System green steps run one agent at a time.** A system step's write scope is the whole production stack,
  and two entry points routinely share a usecase or an outbound adapter. One class, one agent only protects a
  step whose write scope is one class.
- **Shared stabilization stays serial; isolated module stabilization may wave.** The shared plan owns a seam and
  the cross-module compilation fallout from changing it. A module plan can expose bounded write sets instead.
  Disjoint sets bound each agent's context, while compilation after a wave discovers missing call sites before
  another wave starts. Ambiguous fallout returns to sequential ownership. The orchestrator runs the architecture
  test and pre-existing suite once, after all stabilization work.
- **A wave is spawned in the background and collected with `TaskOutput`, never as one blocking `Agent` call
  per bundle.** Several blocking calls in one message run concurrently in principle, but nothing forces them
  into one message. A wave issued that way once ran four bundles serially.
- **The stub marker is one fixed string, and a stub's intent comment names the work, never the step id.**
  `plan.sh stubs`, `plan.sh tick` and the archive hook find unimplemented stubs by grepping for the marker. A
  marker that survives every green step is a method nobody implemented, and the suite cannot see it because
  nothing calls a method no scenario covered. Nothing finds its work by grepping for a step id, and a module
  whose conventions ban citing a plan step in a comment fails the build on one.
- **A refused or absent script never stops a run.** A refusal is the operator's choice, and not running a
  plugin's scripts on one's own machine is legitimate. The scripts add a mechanical, never-skipped check over
  what reading the file gives; without them the run loses guardrails and nothing else. So the skill says so
  once, continues by hand, and never re-runs a declined call.
- **A `hypothesis:` is promoted only at task level, and coverage is measured only there.** A class-wide check
  over a tree still being written answers nothing. The task level, after every step exists, is the first point
  where either figure means anything.
- **A pipeline never archives, and readiness is checked only above it.** Another pipeline may still be writing
  to the task directory. The readiness gate promises that an unready plan changes no file, and a pipeline cannot
  keep that promise once a sibling is already writing.
- **A green step never edits the reproduction test.** A fix proven by a test the same step edited is proven by
  nothing. If the test needs changing, the reproduction, and the diagnosis resting on it, was wrong.
- **A small change never runs the full suite, and commits alone.** A two-minute change that owes a ten-minute
  suite gets made outside the framework instead, which is the drift the skill exists to stop. The cost: a
  break in a test it did not run surfaces as a red baseline in the next run.
- **RED exit reuses the focused results that ticked its steps.** Red agents may change only their own planned
  test classes, and every wave verifies those classes before ticking. Repeating the full suite at the boundary
  spends time to reproduce evidence the plan already preserves.
- **The refactor agent reports a suspected bug only with a constructed failing case, and answers every
  refactoring priority in order, including the ones it did not reach.** Both are history. A confident overflow
  finding on an algorithm with exactly the right headroom took an induction proof and a dedicated agent to put
  down. An unanswered priority and one that found nothing read identically, which is how a diff with one policy
  duplicated in two classes passed two refactor passes.

## The invariants

- A skill contains no fact about any project.
- A skill points at a rule it does not own; it never restates it.
- The file is the record; the conversation is not.
- One fact, one owner: a plan does not restate the design, a prompt restates neither.
- A gate is run by whoever is accountable for the stage, on real command output.
- Nothing is filed as work until it is measured; what a run only noticed is a hypothesis.
- Nothing is archived while any step is open. What a run leaves open for a person is filed, never left in the
  directory.
