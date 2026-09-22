# Why the framework has this shape

[`README.md`](../README.md) says what the plugin does. This file records why its boundaries and strict rules
exist.

## Contents

- [Framework versus project](#framework-versus-project)
- [Files are the contract between steps](#files-are-the-contract-between-steps)
- [Gates, not reports](#gates-not-reports)
- [A design for the person, a plan for the model](#a-design-for-the-person-a-plan-for-the-model)
- [Agent boundaries](#agent-boundaries)
- [Proportionality](#proportionality)
- [Where the plugin stops](#where-the-plugin-stops)
- [IDs](#ids)
- [Why strict rules exist](#why-strict-rules-exist)

---

## Framework versus project

### The split

**Framework:** skills define the workflow and the checks.

**Project:** conventions provide build commands, test mapping, diagram language, agent models and commit policy.

`init-conventions` writes those values from the repository's existing practice. Repository-wide facts live in
`docs/conventions.md`. Module facts live in `<module>/docs/conventions.md`.

### One fact, one home

A copied rule can drift without either copy looking wrong. A skill therefore names the fact it needs and follows
the conventions index to its owner. It does not paraphrase the value into its prompt.

[`contract.md`](../plugin/templates/conventions/contract.md) lists each required fact, its readers and its absent
value.

### Defaults

Most missing facts have a framework default. Examples include PlantUML with C4, the session's model and generic
layer names.

Two facts have no safe default:

- build commands;
- the test-type mapping.

A run stops when either is missing. It continues on the documented default for every other absent fact.

---

## Files are the contract between steps

### The handoff

Each step writes its artifact and stops. The next step reads the artifact instead of the conversation.

- A feature uses `spec.md`, `design.md`, `design-log.md`, `plan.md` and `plan-log.md`.
- A rework uses `rework.md` and `rework-log.md`.
- An upgrade uses `upgrade.md` and `upgrade-log.md`.
- A bug fix uses `bug.md`, then `fix.md`, each with its log.

An answer given in chat counts only after it is written into the owning file. A fresh session must be able to
continue from the files alone.

### Mechanical completion

A cold session exposes missing information. If it cannot plan from a design or implement from a plan, that file
is underspecified.

Each artifact therefore has a deterministic completion check, such as `design.sh settled` or
`plan.sh validate`. The next step gates on that result.

---

## Gates, not reports

**Rule:** real command output decides whether the next stage starts.

A gate may prove that:

- the suite is green;
- the new tests fail;
- the test count is unchanged;
- no plan item remains open.

The agent accountable for the stage runs its gate. A sub-agent's report never passes it. A failed gate never
advances.

This separation lets a cheaper model execute a bounded step without being trusted to certify the stage.

---

## A design for the person, a plan for the model

### Two readers

**Design:** tells a person what changes, where responsibility belongs and how failure behaves. It contains no
class inventory.

**Plan:** tells a model how to build the approved change. It names classes, signatures and test scenarios.

The settled spec and design form the handoff between them.

### Evidence and implementation details

A repository fact that answers a design question is evidence in `design-log.md`. A class or file that changes is
a plan fact. Research files leave no record unless they support a decision.

This keeps the design technology-neutral and gives each fact one home.

### Architecture diagrams

Plan diagrams are an approval surface. Each shows one placement decision and only the dependencies needed to
judge it. Routine implementation targets stay in the step map.

Plan review checks all targets against the repository and its conventions. A person gets several small choices
instead of one exhaustive graph to skip.

### Other workflows

Rework, bug-fixing and upgrades combine planning and execution in one skill. Each writes its steps, stops for
approval and then applies them.

Their starting safety net is a green suite. A bug fix also owes a test that fails on the symptom before the fix.
Bug fixes and upgrades preserve every failed attempt, so a stopped run leaves a useful record.

---

## Agent boundaries

### One module, one pipeline

A module has one build, one test suite and one set of conventions. Examples include a backend service, a web app
or a shared library.

A task has one design and one plan per module. A contract shared by several modules gets `shared/plan.md`. That
plan lands first and alone.

### Three levels

Each level coordinates only the level below it:

1. The task coordinates module pipelines.
2. A module pipeline coordinates bounded step agents.
3. A step agent implements only its assignment.

A step never needs another plan. A pipeline never needs another module's internal work. Only the task level
decides that the whole task is complete.

---

## Proportionality

### Choosing the workflow

Ceremony that costs more than a change will be bypassed. That creates recorded changes and unrecorded changes,
which is the drift the framework exists to prevent.

The user chooses the workflow by one measure: **how many new assertions prove the change**.

- One assertion is a small change.
- More than one assertion is a feature.
- A moved contract is always a feature because its dependants pay the cost.

The chosen skill decides the consequences, including spec amendments, test feasibility and which tests run. It
writes those decisions into the task artifacts.

---

## Where the plugin stops

### Finished work

`implement-plan` ends the feature workflow. It runs the repository's configured follow-up work and moves the task
directory to `docs/implemented/`.

`review/report.md` records what was done, measured and left. It links the findings and the cost report described
in [`cost-recording.md`](cost-recording.md).

Documentation, release notes and other long-lived artifacts follow the repository's own conventions.

### Unfinished work

Unfinished work gets one row in `docs/backlog.md`. This includes a discovered bug, deferred refactoring or
behaviour outside the approved design.

The backlog outlives an archived task and feeds a later `fix-bug`, `rework` or `design-task` run. A task directory
still under `docs/` is itself the record of an unfinished run.

### Reopening an archive

`small-change` may restore a task from `docs/implemented/`, amend its spec and archive it at the same path.
Existing backlog links keep resolving.

The third such amendment becomes a feature and stops the small-change run.

---

## IDs

### Identity

Every ID uses two capital letters and at least two digits. Each kind owns one prefix, and no pair is reused across
files. An ID such as `DN03` is therefore unambiguous without its file path.

Numbers are assigned once. A withdrawn entry keeps its number.

### Where IDs may appear

An ID does not appear in a commit message, test name, class, source file or comment. Those artifacts outlive the
task directory, so the reference would stop resolving when the task is archived.

The exception is a disabled test's reason. It names the step that owes the repair and disappears when the step
lands.

| Prefix | Names | Lives in | Scope |
|---|---|---|---|
| `RQ` `AC` `DN` | requirement, acceptance scenario, decision | `spec.md` | task |
| `DF` | design finding | `design-log.md` | task |
| `ST` `RU` `RI` `RS` `GU` `GI` `GS` `PM` `PI` | plan steps | `plan.md` | plan |
| `OQ` | open question | any steps-carrying file | file |
| `RF` | review finding | `plan-log.md` | plan |
| `RL` `AT` | run-log entry, attempt | every log | log |
| `FS` `FR` `FG` | fix steps: stabilize, red, green | `fix.md` | file |
| `WK` | rework step | `rework.md`, `steps.md` | file |
| `UP` | upgrade step | `upgrade.md`, `steps.md` | file |
| `RX` `DX` `PX` | refactoring, deferred work, performance | `review/findings.md` | task |
| `BB` `BR` `BT` `BP` | backlog bug, rework, task, performance | `docs/backlog.md` | repository |

The commit-message hook refuses exactly these prefixes. Ordinary prose that only resembles an ID remains valid.

File format numbers and their changes live in
[`scripts/README.md`](../plugin/scripts/README.md), **Formats**.

---

## Why strict rules exist

### Trust and evidence

- **Independent review**
  - **Rule:** an author never reviews its own file.
  - **Why:** the writing session remembers reasoning that the artifact may not contain. A separate agent judges
    only what was written.
  - **Prevents:** an author silently applying or downgrading an objection to its own work.

- **Immutable reproduction**
  - **Rule:** a green step never edits the reproduction test.
  - **Why:** changing both the fix and its proof proves nothing. A required test change invalidates the
    reproduction and its diagnosis.

- **Task-level conclusions**
  - **Rule:** only the task level promotes a `hypothesis:` or measures coverage.
  - **Why:** a partial tree cannot answer either question. Every step first exists at task level.

- **Reused RED evidence**
  - **Rule:** RED exit reuses the focused results that allowed each step to be ticked.
  - **Why:** RED agents only change assigned test classes. A full-suite rerun would reproduce evidence already
    preserved by the plan.

- **Evidence-backed refactor findings**
  - **Rule:** a refactor agent reports a suspected bug only with a constructed failing case. It answers every
    priority, including those it did not reach.
  - **Why:** an omitted priority looks identical to a priority that found nothing.
  - **Observed failures:** a false overflow finding required a separate proof to dismiss. A duplicated policy
    survived two passes because unanswered priorities looked complete.

### Concurrency and ownership

- **Serial system green**
  - **Rule:** system-green steps run one agent at a time.
  - **Why:** a system step can write across the production stack. Different entry points often share a use case
    or outbound adapter.
  - **Prevents:** two agents editing the same production path while each appears to own one test class.

- **Serial shared stabilization**
  - **Rule:** shared stabilization stays serial. Isolated module stabilization may run in waves.
  - **Why:** a shared plan owns a cross-module seam and its compilation fallout. A module plan can expose
    smaller, disjoint write sets.
  - **Check:** compile after each module wave. Run the architecture test and pre-existing suite after all
    stabilization work.
  - **Fallback:** uncertain or overlapping fallout returns to one sequential owner.

- **Whole-wave launch**
  - **Rule:** start every agent in a wave in the background, then collect the wave with `TaskOutput`.
  - **Why:** separate blocking `Agent` calls may serialize the work. This happened in a real four-bundle wave.

- **Project-defined bundle affinity**
  - **Rule:** the framework owns compatibility boundaries. Project conventions group compatible items.
  - **Framework boundaries:** agent type, stage, dependency readiness and disjoint ownership.
  - **Project choices:** feature, component, source grouping or one compatible set.
  - **Measurement:** plan-brief limits bound known input. Peak context shows later growth from code and tools.

- **Task-owned readiness and archival**
  - **Rule:** readiness and archival belong above a pipeline.
  - **Why:** a sibling pipeline may still be writing. A pipeline cannot promise an untouched tree after another
    one has started.

### Deterministic safeguards

- **Launch-derived assignment telemetry**
  - **Rule:** the `Agent` hook derives assignment telemetry from the launch prompt.
  - **Why:** every implementation spawn already carries its work. A separate logging command is easy to forget.
  - **Join:** the stop hook attaches the normalized assignment to the real agent ID.

- **One stub marker**
  - **Rule:** every unfinished stub uses one marker. Its intent comment names the work, not a plan-step ID.
  - **Why:** `plan.sh stubs`, `plan.sh tick` and the archive hook all find unfinished work by that marker.
  - **Prevents:** an uncalled method remaining stubbed while the suite passes.

- **Recoverable script refusal**
  - **Rule:** a refused or absent plugin script never stops a run.
  - **Why:** the operator may choose not to execute plugin scripts on their machine.
  - **Fallback:** continue by hand, record the lost guardrail once and do not retry the declined call.

### Proportional cost

- **Focused small changes**
  - **Rule:** a small change runs focused tests and commits alone.
  - **Why:** attaching a long suite to a two-minute change makes the workflow too expensive to use.
  - **Trade-off:** a distant regression appears as a red baseline in the next run.
