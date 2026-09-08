# Why the framework has this shape

[`README.md`](../README.md) says what the plugin does. This file says why.

## Framework versus project

**The skills are the framework. The conventions are the project.**

A skill names what it needs — the build command, the test-type mapping, the diagram language, the sub-agent
models, the commit policy — and never supplies the value. Every value lives in your repository's conventions,
`docs/conventions.md` for the repository and `<module>/docs/conventions.md` per module, written by
`init-conventions` from what the repository already does.

A rule paraphrased into a prompt is a second copy that drifts where no review looks. So a skill names the file
that owns a rule and lets the agent read it. Where your repository says nothing, the skill has a default —
PlantUML with C4, the session's model, generic layer names — and the run continues on the default instead of
stopping.

## Files are the contract between steps

Every step writes its files and stops — `spec.md` with `design.md` and `design-log.md`, `plan.md` with
`plan-log.md`, `rework.md` with `rework-log.md`, `upgrade.md` with `upgrade-log.md`; `fix-bug` writes `bug.md`,
then `fix.md`, each with its log. The next step reads the file, not the conversation — it may run in the same session or
a fresh one, and must work the same either way. An answer given in chat is written into the file before it
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

## Where the plugin stops

The feature workflow ends at `implement-plan`: the task directory moves to `docs/implemented/`, and whatever your
conventions list as running after a change is run. What a run could not finish — a bug it found, a refactoring it
declined to do inside a feature, a behaviour the design never asked for — gets one row in `docs/backlog.md`, which
outlives the archived task and feeds the next `fix-bug`, `rework` or `design-task` run. A task directory still under
`docs/` is itself the record of unfinished work. What the run cost, per agent and per model, is `review/cost.md`
beside the findings ([`cost-recording.md`](cost-recording.md)). Documentation, release notes, and everything else that
outlives the plan are your repository's job, in whatever form it already keeps them.

## The ids

Every id is two capital letters and at least two digits, one prefix per kind, no letter pair reused across
files, so `DN03` can be cited from anywhere without saying which file it lives in. Numbers are assigned once and
never reused; a withdrawn entry keeps its number.

| Prefix                          | Names                                        | Lives in                  | Scope       |
|---------------------------------|----------------------------------------------|---------------------------|-------------|
| `RQ` `AC` `DN`                  | requirement, acceptance scenario, decision   | `spec.md`                 | the task    |
| `DF`                            | design finding                               | `design-log.md`           | the task    |
| `ST` `RU` `RI` `RS` `GU` `GI` `GS` `PI` | plan steps                           | `plan.md`                 | one plan    |
| `OQ`                            | open question                                | any steps-carrying file   | that file   |
| `RF`                            | review finding                               | `plan-log.md`             | one plan    |
| `RL` `AT`                       | run-log entry, attempt                       | every log                 | that log    |
| `FS` `FR` `FG`                  | fix steps: stabilize, red, green             | `fix.md`                  | that file   |
| `WK`                            | rework step                                  | `rework.md`, `steps.md`   | that file   |
| `UP`                            | upgrade step                                 | `upgrade.md`, `steps.md`  | that file   |
| `RX` `DX`                       | refactoring candidate, deferred change       | `review/findings.md`      | the task    |
| `BB` `BR` `BT`                  | backlog bug, rework candidate, deferred task | `docs/backlog.md`         | the repository |

The commit-message hook refuses exactly this list, and nothing shaped like it occurs in ordinary prose. The
format number every file carries, and what changed between formats, is
[`scripts/README.md`](../scripts/README.md), **Formats**.

## The invariants

- A skill contains no fact about any project.
- A skill points at a rule it does not own; it never restates it.
- The file is the record; the conversation is not.
- One fact, one owner: a plan does not restate the design, a prompt restates neither.
- A gate is run by whoever is accountable for the stage, on real command output.
- Nothing is filed as work until it is measured; what a run only noticed is a hypothesis.
- Nothing is archived while any step is open. What a run leaves open for a person is filed, never left in the
  directory.
