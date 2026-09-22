---
description: Translate a settled spec and design into a step-by-step implementation plan before starting to code. Use on a task design-task has settled, or when the user explicitly asks for a plan. A refactoring is rework, not a plan.
argument-hint: [ task directory, or a description of the feature to plan ]
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/plan/plan.sh *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan/plan.sh *) Bash(${CLAUDE_PLUGIN_ROOT}/scripts/design/design.sh *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/design/design.sh *)
---

# Plan Task

When the user asks you to plan a task, write a step-by-step implementation plan to a file before starting work.

**This skill decides structure and sequencing. It never decides behaviour.** Which classes exist, which layer each
sits in, which ports they talk through, which test covers what, and in what order it all gets built — all of that is
settled here. What the change *does*, including what it does about a failure, a duplicate request or a missing
constraint, was settled by `design-task`. Anything this skill finds unsettled goes back there, never into this plan
as a new question.

> **Layering is the module's, not this framework's.** Its conventions name the layers, the packages they map to, and
> which may depend on which. Read them and apply what they say.
>
> **Placing a class is this file's decision.** The step that creates or changes it names the implementation target.
>
> A module whose conventions name no layers is planned the same way. No dependency rule is enforced beyond the ones
> its conventions state. What the phase structure below depends on is the module's **test types**, which its testing
> conventions map.

## 1. Require a Settled Design

Every plan is written from a task `design-task` settled — `docs/<n>-<task-name>/`, holding `spec.md` and
`design.md`. Read both in full before anything else. The spec carries the **Objective**, the **Requirements**,
the **Acceptance Scenarios** a person signed off, and the **Decisions** the user made. The design carries
**Affected Modules**, the **Proposed Solution** and the flow the change follows. All of it binds the plan. The
design follows [`stack-neutral-design.md`](../../templates/stack-neutral-design.md). Name the implementation it
deliberately omits.

The `design-log.md` beside them is not a third input. Open it only to chase a reference: a `DF<nn>` the spec
or design cites, or the file a claim rests on when the step needs to mirror it.

Cite a decision or a finding by its clause, never by its number alone — "DN02, a choice is never cleared", not "DN02".

**Two gates, both hard:**

- **No spec or design for this task** — stop and say so. Do not write the plan and do not reconstruct either
  inline. Point the user at `design-task`.
- **`design.sh settled` exits non-zero** — stop and repeat what it printed. Those entries decide what the
  steps are.
- **`design.sh approved` exits non-zero** — run `design.sh approve "<who>" <task>` with `<who>` the output of
  `git config user.name`, or `the user` where that is empty. Then `approved` again, and go on. Say in step 7
  that the spec was marked approved.
  The script ships with the `design-task` skill at `scripts/design/design.sh` — under `${CLAUDE_PLUGIN_ROOT}` when
  installed as a plugin, under `.claude/` in a plain checkout. Refused or absent is not non-zero: tell the user
  once as [`scripts/README.md`](../../scripts/README.md) says, then read the spec's `Basis:` lines yourself.

**A design gap found while planning goes back to the design, never into the plan.** A gap is a case neither
the spec's **Decisions** nor the log's **Findings** covers. Where the repository answers it, write a
**Findings** row in the design log with the file that answers it. Where nothing does, write a `DN` entry in
the spec with `Basis: must-decide` and ask the user in step 7. Once the answer is written into the spec, run
`design.sh approve` again with the same `<who>` as step 1.

## 2. Create a Plan File per Module

`design-task` already created the task directory and its three files. Write **one plan per module** the design's
**Affected Modules** names, and a **plan log** beside each:

| Design's Affected Modules       | Where the plan goes                               |
|---------------------------------|---------------------------------------------------|
| one module                      | `docs/<n>-<task-name>/plan.md`                    |
| several                         | `docs/<n>-<task-name>/<module>/plan.md`, one each |
| several, with a shared artifact | one more: `docs/<n>-<task-name>/shared/plan.md`   |

> **Naming rule:** the directory carries the name; the file does not repeat it. A task directory holds `spec.md`,
> `design.md`, `design-log.md`, `plan.md` and `plan-log.md`, or the same three and `module-a/plan.md`,
> `module-a/plan-log.md`, `module-b/plan.md`, `module-b/plan-log.md`.

**Two files per plan, split by who reads them:**

| File          | Holds                                         | Read by                         |
|---------------|-----------------------------------------------|---------------------------------|
| `plan.md`     | architecture decisions, steps, open questions | person, step agents, plan tools |
| `plan-log.md` | **Review Findings** and the **Run Log**        | readiness gate, re-review       |

Nothing in the plan is history. A finding stays in the log after its fix is in the plan. A blocker stays there
after the run settled it. Create both when the plan is written: the log opens with a `## Review Findings`
heading and nothing under it until step 5 fills it. `plan.sh validate` refuses a plan with no log beside it, a
finding in the plan, or a blockers section in the plan.

**The design is never split; the plans always are.** One module, one toolchain, one set of conventions per plan.

**A plan is self-contained.** Its own step IDs, its own dependency graph, its own Open Questions, its own log. IDs
restart in each file.

**Affected Modules** in the header names the one module that plan implements.

### The Shared Plan

Everything that crosses between modules goes in `shared/plan.md`, and nothing crosses any other way. It is
implemented first, alone, before any module plan starts. A module plan never waits on another and never names
one.

**What belongs in it**, in three layers:

1. **The artifact** — an API schema, a message schema, any file more than one module's **build** reads, whether it
   generates sources from it or merely validates against it.
2. **Each consuming module's wiring to it** — the generator invocation, the build hookup, the script that produces
   the generated sources.
3. **Every call site the change to it breaks.** Those call sites are stabilized here.

**The artifact is shared; the behaviour it describes is not.** A schema both modules generate from goes here. The
endpoint that schema declares does not — the module serving it implements it in its own plan, and the consumer
mocks the call. The test is what breaks while the thing is missing: another module's **build** means shared, a
mocked call means it belongs to whoever implements it.

**Layer 3 gets it compiling, nothing more.** Its items follow the **Interface-First / Build Stabilization** rules
unchanged:

| What the change broke        | What layer 3 does                                |
|------------------------------|--------------------------------------------------|
| a method's signature         | keep its logic, add a `TODO`, return the minimum |
| a method that now must exist | add a stub with an intent comment                |
| a test that cannot compile   | disable it, naming the step that will rework it  |

Making any of it work again is the module plan's job.

**Its header names every module on the seam:**

```
**Format:** 2
**Affected Modules:** `module-a`, `module-b`
**Design:** [<task name>](../design.md)
```

The plan is finished when **every module in that list** compiles, passes its architecture test, and still has a
green pre-existing suite. The list is where those commands come from, one set per module's build conventions.

**It has a Stabilization group and no other.** Every item ID is an `ST`. It reads the repository-tier conventions
plus each listed module's build section. It needs no layer or test mapping.

**Write it only when the design names a shared artifact.** No file means nothing crosses.

> **Archiving rule:** Once every checklist item in the **entire** plan file is ticked (`[x]`), move **the task's
> whole directory** from `docs/` into `docs/implemented/<n>-<task-name>/`. In-progress work lives in `docs/`. Never
> archive a plan because one section is complete; archive it only when no unchecked `- [ ]` item is left anywhere in
> the file.

### Re-planning

A task directory that already holds a plan is re-planned. The input is the spec and the design as they now
stand, and the tree as it now is. The old plan is not an input. Which case applies is read off the plan,
never asked:

| The plan is                          | Do                                                                              |
|--------------------------------------|---------------------------------------------------------------------------------|
| under `docs/implemented/`            | nothing. A change to an archived task is a new task.                            |
| in `docs/`, no item ticked           | rewrite `plan.md` from the spec and design                                      |
| in `docs/`, some items ticked        | keep every ticked item as it is; delete every open item; write the rest anew   |

**Ticked items are a record, not a plan.** They say what is in the tree. They are never unticked and never
edited. New items take the next ids in their group. Where the spec no longer wants what a ticked item built,
a Stabilization item removes or moves it. A deleted item's id stays unused.

**The log stays.** Its **Review Findings** keep their numbers and the new review continues past the highest.
An **Open Question** keeps its number and its answer where the question still applies; one that no longer
applies keeps its number and gains `- A: withdrawn — <why>`.

**Then the rest of this skill runs as for a new plan**: the review (step 5, in re-review mode), the mechanical
findings (step 6), the hand-over (step 7). Before handing over, append one `RL` note to the log's Run Log:
`re-planned from the spec approved <hash>`, with the ids removed and the ids added.

## 3. Read Module Conventions

After determining the **Affected Modules**, read `<module>/docs/conventions.md` for **every** affected module before
generating the plan's layer sections. Also read the repo-root `docs/conventions.md` if it exists. A module's own
file overrides and extends it.

Read from the conventions: the module's tech stack and test tooling, how it organizes code, its dependency rule if
it has one, its naming conventions, its file locations, and **which of its parts fall into which test type**.

**A module whose conventions carry no test-type mapping cannot be planned.** Say so and ask for it, rather than
reading a test type off a package name.

**A performance tool is optional.** Where the conventions name none, or say performance is not measured, a spec
scenario whose `Then:` is a measurement gets no step, and the plan says so as a coverage note
([Post-Implementation Steps](#post-implementation-steps)). Never pick a tool for the module.

If a module has no conventions file at all: use generic defaults, and add an entry under **Open Questions** in
the generated plan asking the user to run `init-conventions`, or to fill in the templates at
`templates/conventions/` under the plugin root by hand. Never fail silently and never guess module conventions.

## 4. Plan Structure

The plan file MUST contain the following sections. Headings below that say "reference" or "Step Format" are
instructions for writing those sections, not sections to reproduce in the plan.

### Header

Three lines at the very top of the plan, immediately after the title:

```
**Format:** 2
**Affected Modules:** `module-a`
**Design:** [<task name>](design.md)
```

**Format** is the file-format number `plan.sh validate` checks ([`scripts/README.md`](../../scripts/README.md),
**Formats**); every plan this skill writes carries `2`.

**Affected Modules** is read differently by the two kinds of plan, and neither reading is inferred:

| Plan             | The property names                               |
|------------------|--------------------------------------------------|
| a module plan    | the one module it implements                     |
| `shared/plan.md` | every module on the seam, producer and consumers |

Never omit it. The design's own **Affected Modules** is the list of all of them.

**No plan declares an order.** `shared/plan.md` finishes before any module plan starts, and nothing else crosses.

`after:` is for steps inside one file. It never names a step in another plan; `plan.sh validate` fails on an ID it
cannot find. The one place a plan mentions another is a disabled test's reason, which points at the step that will
rework it.

**Design** links the design this plan translates; the spec sits beside it. The objective, the behaviour, the
schema and the flow live there and are **not** repeated here.

The link is relative and survives archiving: `design.md` from a single-module plan, `../design.md` from a per-module
or shared one.

### Architecture Decisions

Write this section as [`plan-architecture-decisions.md`](../../templates/plan-architecture-decisions.md) says.

### Step-by-Step Implementation Map (To-Do List)

A checklist of actionable, sequential steps required to complete the task, as Markdown checkboxes.

The map is organized into **four major groups**, each a `### <Group>` heading directly under this section, in this
fixed order — use only the groups the task actually needs:

1. **Stabilization** — every pre-TDD artifact and prep step: contract-defining artifacts (API schema, CLI interface,
   message schema — whatever the module's conventions file defines), database changes, interface/signature sync,
   configuration, and shared test infrastructure. Always first; nothing in Red Phase can start before it.
2. **Red Phase** — RED-phase TDD steps across all three test layers. Tests compile and are expected to fail at
   runtime; no production implementation happens here.
3. **Green Phase** — GREEN-phase TDD steps across all three test layers, implemented against Red Phase's tests, unit
   and integration before system.
4. **Post-Implementation Steps** — steps that only make sense once the feature is fully implemented and green: the
   performance measurement where the spec asks for one, then whatever the conventions say a finished change earns
   (e.g. updating manual `.http` request files). Always last.

Within each group, its sections appear as `#### <Section>` headings, in the fixed order listed below for that group
— use only the sections that apply.

**Under a group, items and nothing else.** The one prose a group admits is a coverage note — one paragraph saying
which spec scenario an existing test already holds, so a reader does not go looking for its step
(`AC05 is held by the existing regression tests in SettingsPage.test.tsx`), or which measurable scenario the
conventions leave unmeasured (`AC05 is a measurement; the conventions say performance is not measured`). A
paragraph saying what a branch does, which case is folded into which, or why, is behaviour. Where the design
lacks it, it goes back there as a `DN` or a **Findings** row. Where the design has it, the step's scenarios
already carry it. An item says **what** is created or changed and names its concrete implementation target. The
reasoning behind it is the design log's **Decision Bases**, cited by clause where a step needs it, never
restated under the item.

**Every checklist item carries an ID**, written immediately after the checkbox and separated from the rest by ` · `.
The ID names the item everywhere else it comes up — `after:` dependencies, blocker records, sub-agent prompts, and
step reports:

| Prefix | Items                     | Prefix | Items                       |
|--------|---------------------------|--------|-----------------------------|
| `ST`   | Stabilization             | `GU`   | TDD Unit Green Phase        |
| `RU`   | TDD Unit Red Phase        | `GI`   | TDD Integration Green Phase |
| `RI`   | TDD Integration Red Phase | `GS`   | TDD System Test Green Phase |
| `RS`   | TDD System Test Red Phase | `PI`    | Post-Implementation Steps   |
| `PM`   | Performance               |         |                             |

Numbering restarts at `01` per prefix and follows the order the items are listed. An ID is never reused or
renumbered once the plan is written — a dropped step leaves a gap.

**An ID never leaves those places.** Not a commit message, not a test or display name, not a class, a file or a
comment. The same holds for a design's `DN`, `DF` and `AC` entries, an Open Question's `OQ`, and a findings
file's `RX`. Say what the thing does instead. A `@Disabled` reason is the one exception.

**An `update:` bullet is written from the test's body, never from its name.** Open the method, read what it
asserts, and say what changes about those assertions. Where the same change reaches many tests of one class, do
not stretch one sentence over a list of names: write a **premise** bullet — the fact about the change and what
follows for a test that meets it — and let the step agent decide test by test which bodies meet it. The forms
are in `step-formats.md`'s **Existing-test updates rule**.

`plan.sh validate` checks the result: duplicate IDs, items with no ID, `after:` naming an ID nothing defines,
dependency cycles, a `given:`/`when:`/`then:` or `threshold:` left as a placeholder, an `update:` bullet naming a
test method that exists nowhere in the repository, a `PM` item outside a **Performance** section or without its
`covers:`, `threshold:` or `scenarios:`, a **Performance** section anywhere but first under
**Post-Implementation Steps**, a missing log or a finding left in the plan, and — once the review has run — a
finding in the log missing its `Resolution:`, or a `mechanical` one whose `Action:` was never written. Run it
before handing the plan over, and again after applying findings. The script ships with these instructions at
`scripts/plan/plan.sh` — under `${CLAUDE_PLUGIN_ROOT}` when installed as a plugin, under `.claude/` in a plain
checkout.

#### Stabilization

Its sections — **API Contract**, **Database**, **Interface-First / Build Stabilization** and its three labelled
sub-groups, and the closing architecture-test item — are
[`templates/stabilization-group.md`](../../templates/stabilization-group.md). How each item is carried out
is [`stabilizing.md`](../../templates/stabilizing.md) beside it.

#### Red Phase

The three red-phase types are separated by **what is real and what is faked**, and the module's conventions map
its own parts onto them.

- **TDD Unit Red Phase** — write meaningful unit tests that build for classes the conventions map to the unit type,
  with every dependency mocked; tests are expected to fail at this stage (stubs return null/defaults); no production
  implementation yet
- **TDD Integration Red Phase** — write meaningful integration tests that build for classes the conventions map to
  the integration type, each against the **real** thing it talks to. Two variants: a class that calls infrastructure
  is driven directly, against a real database, store or stub server as the conventions define it; a class the
  framework calls is reached through the framework, with what it delegates to mocked. Same RED-phase rules — no
  production implementation yet
- **TDD System Test Red Phase** — write a thin set of end-to-end system tests that build, against the fully wired
  application with **nothing mocked**, entered the way production enters it: an HTTP request via the module's
  API-level test client, or the framework firing the entry point itself — a test-configured schedule, a message
  published to the test broker — never a direct method call. Scope is what only the whole application can prove: per
  entry point, one happy path and a representative error path raised from deep in the stack. Validation matrices
  belong to the entry point's integration step. Tests are expected to fail at runtime until the full stack is
  implemented — no production implementation yet

#### Green Phase

- **TDD Unit Green Phase** — implement the production logic for each class from `TDD Unit Red Phase`, one class per
  step, until its unit tests pass
- **TDD Integration Green Phase** — implement each class from `TDD Integration Red Phase`, one class per step, until
  its integration tests pass; for an entry-point step that is the class itself — binding, mapping, validation
  wiring, error mapping — never what it delegates to, which has its own step
- **TDD System Test Green Phase** — run each system test class from `TDD System Test Red Phase` and confirm all
  tests pass; fix implementation bugs anywhere in the stack (never the tests) until the full test class is green. An
  entry point with an integration step is already implemented there; one without — a framework-fired trigger — is
  wired here

#### Post-Implementation Steps

- **Performance** — one item per entry point a spec scenario measures, and one `rerun` item per existing test
  the user said `yes` to under [Open Questions](#open-questions). When the section exists, where it sits and
  both item formats are `step-formats.md`'s **Performance Step Format**. Where the conventions say performance
  is not measured, the coverage note above stands in for the writing item.
- **Manual Request Files** — manual request files (e.g. `.http`), only if the module's conventions file lists this
  as a convention

The other sections come from the module's conventions — whatever they say a finished change earns, filtered to
what this plan can produce, in the order they list it. Follow the conventions index to wherever that is stated.
The framework prescribes none of them beyond **Performance** and the rule that they run last.

Where the conventions put an artifact under the user's approval, that approval is a question under
[Open Questions](#open-questions) like any other, and only an answered yes becomes an item here.

### Step Formats — reference

The exact shape of every Red Phase, Green Phase and Performance item, **The Four Test Types** that decide which
phase a step belongs to, and the scenario-authoring rules that bind them all, are
[`templates/step-formats.md`](../../templates/step-formats.md). Read it before writing or reviewing a step;
`plan.sh validate` checks what it can of the result.
[`templates/example-plan.md`](../../templates/example-plan.md) is a complete worked plan in those formats.

### Open Questions

**Scope:** this section holds questions about *executing* the plan — a blocker foreseen in a step, a tool or
credential that may be missing, an approval a conventions file requires. Questions about what the change should
**do** belong in the spec's **Decisions** section and are settled before this plan exists. What happens *while*
the plan runs — a step blocked, a test that passed red for a reason, a boundary widened — is the log's **Run
Log**, never this section.

Generate placeholders for the user's answers beneath each open question, nested under it, for example:

- **OQ01:** [Your question here]?
  - A:

- **OQ02:** [Next question]?
  - A:

The answer is nested and a blank line separates the questions.

**Number every question** (`OQ01`, `OQ02`, …). Numbers are assigned once and never renumbered: a question that is
answered or withdrawn keeps its number, and a new one takes the next unused value.

**An artifact the module's conventions put under the user's approval is asked here, never assumed.** Where a
conventions file says a post-implementation artifact is written only with the user's consent, the plan asks for it
as a numbered question — what would be written, and what holds the same fact if it is not — and a `yes` becomes the
item in **Post-Implementation Steps** that authorizes it.

**A module with performance tests is asked which of them to rerun, once.** Read the tests where the testing
conventions say they live, and read each one for the entry point it drives. Split them by whether this task's
design touches that entry point — the flow diagram and the container diagram say which — and write one
question: `OQ<nn>: the module has performance tests for POST /widgets and GET /widgets (this task touches
their entry points) and for POST /exports (it does not). Rerun which after the change?`, with the touched ones
recommended. Every test named in the answer becomes a `rerun` item under **Performance**; an unanswered
question adds none, and the readiness gate stops on it like any other. A module with no performance tests
gets no question.

### The Plan Log

`plan-log.md` beside the plan, titled `# Plan Log: <task name>`, with two sections in this order:

| Section             | Holds                                                                           | Written by                        |
|---------------------|---------------------------------------------------------------------------------|-----------------------------------|
| **Review Findings** | `RF<nn>` entries, one per finding the reviewer raised, with what became of each   | this skill, steps 5–7             |
| **Run Log**         | `RL<nn>` entries, one per thing the run recorded — a blocker, a note, a deviation | `implement-plan`, `plan.sh block` |

The **Run Log** heading is not written here; `plan.sh block` creates it at the first entry. An entry is
`- **RL<nn> (<ID>):** what happened`, `<ID>` the step it belongs to, numbered once and appended; a blocker carries
a `- Resolved:` line beneath it, filled when it is settled, and a note that nothing waits on carries none.

#### Review Findings

Populated by the `review-plan` subagent invoked in the next step — the log holds the heading and nothing under it
while the rest of the plan is written. Each finding uses this exact format:

```
- **RF01:** [what's wrong or missing, with file/class/scenario reference]
  - Resolution: mechanical | decision
  - Action:

- **RF02:** [the next one]
  - Resolution: …
```

**`Resolution` and `Action` are nested under their finding, and a blank line separates one finding from the next.**
The same holds for `Escalated:` where a finding carries one.

Findings are numbered on the same terms as the questions above — `RF01`, `RF02`, … assigned once, never renumbered, and
continuing past the highest existing number on a re-review.

`Resolution:` is the reviewer's classification of **who** resolves the finding — `mechanical` when a written rule or
the code already determines the fix, `decision` when it is a genuine choice. The reviewer assigns it; the
orchestrator acts on it in step 6. It is never the planner's call.

If the review has nothing to report, this section still contains a single "No issues found" statement (or
equivalent).

## 5. Invoke the Review Subagent

Once every section in **4. Plan Structure** is written, spawn the **`review-plan` agent** against the just-created
plan file, on the model the module conventions name for deciding work; where they name none, the default model.

Never review the plan in this context instead.

**The reviewer writes nothing.** It reports, and this session writes its findings into the log's **Review
Findings** section. Assign the `RF` numbers here, past the highest already in the section. Carry each finding's
`Resolution:` across unchanged.

A finding the plan already answers is written down anyway, with that answer as its `Action:`.

Only then proceed to **6. Resolve the Mechanical Findings** below.

## 6. Resolve the Mechanical Findings

Apply every finding the reviewer marked `Resolution: mechanical` to the plan, then write under it what changed:

```
  - Action: applied — [what changed in the plan, in a clause]
```

A finding marked `Resolution: decision` keeps that classification — this step never regrades the reviewer's verdict.
It still gets **attempted against the repository**: the sibling service's code, the module conventions, an existing
ADR, the schema. Answer it when the evidence is there and write the evidence into `Action:`
(`resolved — the sibling service's own `WidgetPort` imposes no `UPDATE` rule`). Leave `Action:` empty for the user only
when the answer is a product, operational, or business rule that exists nowhere yet — and add a
`- Missing: [what the repository does not say]` line beside it, nested under the finding like the rest.

**An `Action:` prescribing a mechanism this session did not exercise ends `— unverified`.** Reading that a thing
exists does not verify how it behaves.

How to apply them:

- **Batch by affected step, not by finding.** Group the findings by the item each one touches and rewrite that
  item once, satisfying all of them together.
- **Compress the finding as you apply it.** In the same edit, cut it to one sentence, keeping the `- **RF<nn>:**` /
  `- Resolution:` / `- Action:` shape. A `decision` finding resolved against the repository keeps one clause of
  evidence in its `Action:`, the file it rests on, not the trail:

  ```
  - **RF01:** RU01's scenarios omitted the unknown `parentId` and the duplicate name under one parent.
  - Resolution: mechanical
  - Action: applied — added both scenarios.
  ```

  Keep the ID and its number, one sentence of what was wrong, and the `Action:` line. Drop the reasoning, the
  file-and-line citations, and the instruction of what to change. A finding that was **not** applied keeps its
  full text: an empty `Action:`, a `- Missing:` line, an `- Escalated:` line.
- **Stay inside the finding.** Apply what the finding says to change and nothing adjacent that looks improvable.
- **Escalate rather than guess.** If a `mechanical` finding does not say clearly enough what to change, or applying
  it would cross one of the boundaries `review-plan` lists (adding or removing a checklist item, changing a step's
  target class, touching a contract artifact, contradicting an answered Open Question), do not apply it: leave
  `Action:` empty, add a line `- Escalated: [why]` beneath it, and let the user decide.
- **Re-run `plan.sh validate`** afterwards.

## 7. Review Only — Do NOT Implement

- Lead with the plan's **Architecture Decisions** section, then link the complete generated plan.
- **Say that the spec was marked approved**, where step 1 wrote the line.
- **Report what step 6 applied** — the findings' IDs and a clause each, in one short list.
- **Ask what is still open, in one batch, via `AskUserQuestion`** — every unanswered Open Question, every `decision`
  finding, and anything escalated, each with the options that are actually defensible and a recommendation first. Do
  not print them and wait for the file to come back edited.
- **Write each answer into the files verbatim**, as the `- A:` under its question in the plan or the `- Action:`
  under its finding in the log, and correct anything elsewhere in the plan that the answer invalidates in the
  same edit. An answer that prescribes content is quoted, not summarized.
- **A question the user leaves unanswered stays in the file, unanswered.** Do not guess one to fill the gate, and do
  not ask again in a second round.
- **Stop here. Do not implement anything.** Do not write code, create files, or run commands.
- Wait for the user to explicitly ask you to start implementation before doing any work.
- Tell the user that implementation will not start while any Open Question lacks an `A:` or any Review Finding lacks
  an `Action:`; the `implement-plan` skill's plan-readiness gate checks exactly this.
