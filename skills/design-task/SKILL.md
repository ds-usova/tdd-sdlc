---
description: Settle a change before any plan exists — a spec the user signs (requirements, acceptance scenarios, decisions), a design that reads the same in any language (context, solution, diagrams, the data), and a log of why (every concern the grill examined with its verdict, every question the repository answered, what each decision rested on). Runs the grill subagent, then puts only the genuinely open questions in front of the user.
argument-hint: [ description of the feature or task to design, or a backlog id T<n> ]
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/design/design.sh *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/design/design.sh *)
---

# Design Task

Settle **what** the change does and **what it does when things go wrong**. Record every judgment call it makes as
an answered decision.

This skill produces three files per task and stops. It writes no checklist items, no test scenarios, and no step
IDs.

| File            | Reader                     | Holds                                                                          |
|-----------------|----------------------------|--------------------------------------------------------------------------------|
| `spec.md`       | the user, who signs it     | Objective, Requirements, Acceptance Scenarios, Decisions                       |
| `design.md`     | whoever plans and builds   | Affected Modules, Context, Proposed Solution — diagrams, data, wire shapes     |
| `design-log.md` | whoever asks *why*         | Concerns with verdicts, Findings the repository answered, Decision Bases       |

**The spec is behaviour.** What is promised, what proves it, what the user chose. No table, no endpoint, no class.

**The design reads the same in any language.** It knows what the change stores, what it exposes, what it calls,
what crosses each boundary, and how it behaves at each of them — the table, the endpoint, the wire shape, the
status codes, the invariants. It does not know the class, the framework, the library, the component or the file
that will hold any of it. Those are the plan's, and the plan is project-aware. The test for any sentence: could a
team on another stack implement it without asking?

**The log is the train of thought.** Nobody needs it to build the feature. Everything binding is in the spec or
the design; the log says where each of those facts came from.

## 1. Create the Task Directory

A task owns a directory under the repository-root `docs/`. Create it as `docs/<number>-<task-name>/` and write
the three files inside it — `docs/7-create-expense/spec.md`, `design.md`, `design-log.md`. Whatever else the task
accumulates joins it there. The directory carries the number and the task name; the files do not repeat them.

> **Numbering rule:** `<number>` is one more than the highest already in use, scanning the directory names
> `<number>-*` in **both** `docs/` and `docs/implemented/`. The number and the task name are the change's, not
> this file's.

> **Archiving rule:** active work lives in `docs/`, completed work in `docs/implemented/`. A task is never
> archived here: this skill leaves the directory in `docs/`.

### One Subject per Task

A request that adds more than one subject — a new store *and* a new consumer *and* a new prompt — is one task per
subject, each with its own directory, numbered in dependency order. Every task is then one grill, one plan and one
delivery. The first spec names the sequence in its **Objective**; a later one cites an earlier one's `D` and `F`
by task number, the way it cites an implemented task's, and its design lists it in **Context**.

Split **before** writing, not after the grill: a design that reaches a second `####` section on a subject the
**Objective** did not name has already crossed the line. The measure is subjects, not lines — a plan grows with
the former, and a design that is mostly diagrams may run long. `design.sh validate` prints the counts so the size
is in front of the session on every run.

The seam between two tasks is a stored table, a flag, or a message shape the earlier one ships. Where the split
leaves nothing user-visible until the last task lands, every task ships behind the same flag, and the design says
so.

## 2. Read Module Conventions

After determining the **Affected Modules**, read `<module>/docs/conventions.md` for every affected module, and the
repo-root `docs/conventions.md` if it exists. The conventions give the stack, the diagram format, and the file
locations the **Context** table is written in terms of.

If a module has no conventions file, record a `must-decide` decision asking the user to run `init-conventions`.
Never silently guess a module's conventions.

## 3. Read What Already Exists

Before writing anything, read the closest existing feature end to end — its domain types, its usecase, its
adapters, its migration — and the conventions that govern them. Name it in **Context**; every later section is
allowed to say "as `X` does".

The same holds for a contract a **library generates** rather than the code declaring — a tool or endpoint schema
derived from a signature, a serializer's wire form, a generated client. What reaches the wire is the generator's
reading of the annotated declaration, not the declaration. Read the generator itself before the design fixes the
shape, decompiling it from the dependency if the source is not at hand.

## 4. The Spec

`spec.md` MUST contain these sections, in this order.

### Objective

What needs to be achieved, and why it matters to whoever asked. A short paragraph. What it promises is the next
section's; this one says why.

**A task started from the backlog names its row.** Where the argument is a `T<n>` id, read the row in
`docs/backlog.md` and the findings row it links; that row's *what* and *why* seed this paragraph, and its first
line is `Closes T<n>`. `implement-plan` reads that line to close the row when the task is archived.

### Requirements

What the change promises, one line each, numbered `R1`, `R2`, …:

```
- **R1:** A person can pick the currency their amounts are assumed to be in.
- **R2:** A chosen currency reaches the model on every turn.
```

A requirement is a behaviour the user signs off, in their words — not a mechanism, not a status code. Every
**Acceptance Scenario** names the requirement it proves, and `design.sh validate` refuses a requirement no
scenario proves and a scenario proving nothing. Three to eight is the usual count; more is a second subject.

Numbers are assigned once and never reused.

### Acceptance Scenarios

What the change does, as behaviour a person can agree or disagree with. One block per entry point, each scenario
numbered `A1`, `A2`, … in this format:

```
- **A1:** [what the scenario is, one line]
  - Given: [the state before]
  - When: [what the user or caller does]
  - Then: [what they get back, and what changed]
  - Proves: R1, R3

- **A2:** [the next one]
  - Given: …
```

**The four lines are nested under the scenario, and a blank line separates one scenario from the next.** Flat
bullets render as one undifferentiated list, where a reader cannot see a scenario begin or end.

**One per branch of the design's flow diagram**, happy path and every failure alike. A branch drawn but never
accepted is a behaviour nobody agreed to; a scenario with no branch is a flow the diagram is missing.

**`Proves:` names the requirement.** One scenario may prove several; every requirement is proved by at least one.
That line is what ties a user's promise to the red-phase test that will check it.

Numbers are assigned once and never reused. Every red-phase step in the plan cites the scenarios it covers, so a
scenario no step names is a visible gap.

**These are behaviour, never mechanics.** No class, no test class, no layer. "Then: the response is 400 with
`PERIOD_INVALID`" is a scenario; "then `ListExpensesUseCase` throws" is a plan step.

### Decisions

Every judgment call the user made or still has to make, one entry each, in this exact format:

```
- **D1:** [the question, one line]
  - Answer: [what the change does]
  - Basis: decided (user, <date>) | must-decide — [what the repository does not say]

- **D2:** [the next question]
  - Answer: …
```

**`Answer` and `Basis` are nested under their entry, and a blank line separates one entry from the next.**

Numbered `D1`, `D2`, … assigned once and never renumbered: an entry that is answered, withdrawn, or reversed keeps
its number, so anything citing it stays valid for the life of the change.

**Only two bases live here: `decided` and `must-decide`.** This section is what the user reads. It holds the calls
they made and the ones still waiting for them, and nothing else. An entry is the question, the answer, and who
chose. **The reasoning is the log's**: the alternative that lost, why, and the files it rested on go under the
same `D` number in the log's **Decision Bases**. `design.sh validate` refuses a `decided` entry with no such
line.

An `assumed` or `deferred` question is a **Findings** row in the log instead. It was still asked and still
answered — it just needs no reader. `design.sh validate` refuses a `D` entry carrying either basis.

**The four bases, and what each obliges:**

| Basis         | Means                                                            | Lives in                  | Owes                                                        |
|---------------|------------------------------------------------------------------|---------------------------|-------------------------------------------------------------|
| `decided`     | the user chose between defensible options                        | the spec's Decisions      | who chose and when here; the alternative and the files in the log's Decision Bases |
| `must-decide` | a product, operational, or business rule that exists nowhere yet | the spec's Decisions      | an empty `Answer:` and what the repository does not say     |
| `assumed`     | the repository determines the answer                             | the log's Findings        | the answer, one clause, and the file that determines it     |
| `deferred`    | real, but out of scope for this change                           | the log's Findings        | what happens instead, and what would bring it back          |

`must-decide` is the only one that leaves `Answer:` empty, and it is what `settled` counts. An `assumed` row
with no file to point at is a `must-decide` in disguise. Reading code this repository does not own is not
evidence of what it does at runtime: `assumed` needs something in the tree that already exercises the path and
what it was observed to produce; otherwise the row is `deferred`, naming what would settle it.

**Answer against the repository before asking.** Ask only what the repository genuinely cannot answer, and say in
`Basis:` precisely what it does not say — so the user answers a question rather than picks from a menu.

**Cite a decision by its clause, not its number alone.** In any file, in a plan, in a report: "D2 — a choice is
never cleared", not "D2". The user has not memorised the numbers.

The spec is **settled** when no entry carries `Basis: must-decide`.

## 5. The Design

`design.md` MUST contain these, in this order.

### Affected Modules

A single line at the very top, immediately after the title:

```
**Affected Modules:** `module-a`, `module-b`
```

Only the top-level modules whose code, config, or migrations change. One module is still listed.

Where the list holds more than one, the design owes one fact about the boundary between them:

- **Which artifacts are shared** — an API schema, a message schema, anything outside both modules that both read
  at build time. Name each in the **Proposed Solution** where it is described, along with the modules that read
  it. No module owns one: a shared artifact is implemented on its own, before either module's work.

A design whose modules wait on each other for anything *else* has not found the boundary — say so, or move the
seam.

### Context

What already exists that this change builds on or mirrors. It is a reading list, not an argument. The grill reads
it to find ground truth, and every "same as X" elsewhere resolves against it.

A table — `What exists` | `Where` | `What this change does with it` — one row per thing, one line each. `Where` is
a link. A row that needs a paragraph is carrying a fact the **Proposed Solution** acts on, and that section owns
it.

**Context is the only section that names a source file.** A document this change invalidates, a config file it
edits, a lint rule it touches: each is a row here, with what happens to it in the third column. The **Proposed
Solution** refers to them by what they are, never by path.

### Proposed Solution

What the change adds at the surfaces a person can see: what crosses the module's boundary, what it stores, and
how it behaves.

- A database change includes the migration content in the module's migration format.
- An API contract change includes the endpoint and schema changes.
- A message or event carries its shape, field by field.
- **Name responsibilities, not classes.** "The read side answers a page of expenses" is this file's; which class
  holds it, in which package, is the plan's.

**Order: the proposal, then the diagrams, then the details.** Details before diagrams make a reader scan for the
picture, and a reader who has to hunt stops reading.

- **What the change adds** — the API surface, the stored shape, the shape of a response. Short.
- **Diagrams** — the section below.
- **Details** — one `####` per module and concern, holding only what a box cannot: a field, an invariant, a
  status mapping, the SQL, a wire shape.

**Stack-neutral, by rule.** Design-level and kept: SQL, columns, endpoint paths, wire fields, status codes,
invariants, how a row is found, what a transaction holds, what crosses to another system. Plan-level and cut: a
framework class, a library call, a component, a hook, a style token, a method, a source file. `design.sh validate`
refuses a source file named in this section; the grill's **Stack-neutral** concern catches the rest.

**There is no closing list of files touched.** Every file the change reaches is a **Context** row, and every
behaviour is a box in a diagram or a row in a table here.

**A fact has one home.** The diagram owns what happens and in what order; a table owns what fits inside a box; a
paragraph exists only for a reason a reader would otherwise get wrong. A fact stated in the migration, restated
under the endpoint and restated again in a diagram label is three places to drift. State it once and link to it.

| Instead of                                                             | Write                                         |
|------------------------------------------------------------------------|-----------------------------------------------|
| "`FooController` calls `ListFooPort`, implemented by `ListFooUseCase`" | nothing — the plan owns every class          |
| a port/use-case/command/answer table                                   | nothing — the plan owns every signature      |
| "the amount is validated before anything is stored"                    | the invariant, in that field's row of a table |
| "the controller answers 400 when the filter is out of bounds"          | an exception/status/cause table               |
| "a `NavLink` carrying `aria-current`"                                  | "the control marks itself current"            |

Tables by default. Prose only where a table cannot hold the reason, and then two sentences at most.

#### Diagrams

Include diagrams whenever the change introduces new behaviour or a new flow; a one-line stub change needs none.

**What to write them in comes from the module's conventions file** — its **Diagram Format** entry names the
language, the fenced block's language tag, and any preamble a diagram needs. Where a module names none, use
PlantUML with the bundled C4-PlantUML standard library: fenced ` ```plantuml ` blocks, and `!include
<C4/C4_Container>` for a C2. Angle brackets, no `.puml` extension: that resolves against PlantUML's own bundled
stdlib, needing neither a network fetch nor a relative path. Where a renderer's PlantUML predates the bundled
stdlib, fall back to the raw URL for the same file
(`https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml`).
See `example-design.md`, beside this file, for working syntax.

**No class appears in any of them.** Here a box is a responsibility, a module, or a system.

What each diagram must **show**:

- **Flow diagram** — always. The flow from the entry point, through the change's responsibilities, to whatever it
  calls or stores, showing every alternative branch: a validation failure, a not-found case, an outbound call
  erroring. Every branch a **Decisions** entry settles appears. A straight-line happy path means the failure modes
  were never designed, and the red phase's unhappy-path tests will not exist either.

  Name each box for what it does, not for the class that will do it. "Validate the period", not
  `PeriodValidator`.

  Whether that is a sequence diagram (`alt`/`else`/`end` fragments) or an activity diagram is decided by the
  repository's own diagram conventions — read them and pick. A flow carrying both several participants and real
  branching is two diagrams, not one overloaded one.
- **Container diagram (C4 level 2)** — always. It is the design's structural picture, and the only one: the
  component diagram that draws classes belongs to the plan.

  Every module in **Affected Modules** as a `Container(...)`, plus what each talks to *for this change* — the
  caller, the store, the external system. Draw what crosses, and label it with what it carries: the call, the
  message, the shared table.

  **Where the list holds more than one module, that crossing is the contract between them**, and it is the one
  thing no module's own plan can draw. Where it holds one, the diagram still answers what the module reaches
  outside itself, which is where every failure mode in the log's **Concerns** comes from.

  No system-context diagram (C4 level 1). What systems exist is a property of the repository, not of one change.

## 6. The Design Log

`design-log.md`, in this order. Leave each section as a placeholder while writing the spec and the design; the
grill runs in the next step and the log is written from its report.

### Concerns

One `Grilled (<date>): <grill>, <grill>` line, then one table:

| Concern | Verdict | Why |
|---------|---------|-----|

**One row per concern the grill owns, every time.** `grill-design` owns failure modes, idempotency & retry,
concurrency, recovery, data, contract compat, lifecycle, authorization, observability, limits, business
invariants and stack-neutral. `grill-frontend` owns empty & extreme, default state, layout stability,
consistency, colour system, motion, third-party UI, library reach, input & locale, person's state, reachability
and stack-neutral. A concern that came out clear still gets its row — "no paging" is a verdict, and "one row per
person, keyed by the person" is its why. `design.sh validate` refuses a missing row, an empty verdict and a
verdict with no why.

**Why is a business rule, a file, or a `D`/`F`.** Never "not applicable" alone.

### Findings

Every question the change answered that needs no reader — the `assumed` and the `deferred`:

| #  | Question | Answer | Evidence |
|----|----------|--------|----------|

- **Very short, all three columns.** A question is a clause, an answer is a clause, and evidence is a link.
- **Evidence is a file** — the class, the migration, the conventions page, the ADR. Never an argument. A row with
  no file to point at is a `must-decide`, not a row.
- **A `deferred` row's answer says what happens instead**, and its evidence is what would bring it back.
- **`F1`, `F2`, … on the same terms as a `D`:** assigned once, never renumbered, never reused. The spec and the
  design cite a row the way they cite an entry, and a row that is answered or withdrawn keeps its number.

The `F` sequence is the task's own. A plan log's **Review Findings** numbers its own `F1` upward, in its own
file, and the two never meet.

A question that needs a paragraph was not settled. It is a `must-decide` in the spec's **Decisions**, and the
user answers it.

### Decision Bases

One line per `D` in the spec, same number: what the user chose over, why, and the files the choice rested on.

```
- **D2:** The user chose a choice that stays set over one that can be returned to nothing; the request schema
  cannot express null (`<api-schema-file>`), and `<sibling-usecase-file>` never clears a stored value either.
```

`design.sh validate` checks all three files — see [`scripts/design/README.md`](../../scripts/design/README.md)
for the list. `design.sh settled` answers the separate question — whether anything is still open. The script
ships with these instructions at `scripts/design/design.sh` — under `${CLAUDE_PLUGIN_ROOT}` when installed as a
plugin, under `.claude/` in a plain checkout. Address a task by its directory or by any of its three files.

Run `validate` before invoking the grill, and both it and `settled` again before handing over. Refused or absent
on the first call, tell the user once as [`scripts/README.md`](../../scripts/README.md) says and answer each
check by reading the files.

## 7. Invoke the Grill Subagent

Once the spec and the design are written, spawn a grill against the task directory. Use the model the module
conventions' **Sub-Agent Models** section names for deciding work; without such a section, the default model.

**Which grill depends on what the change touches**, read from each affected module's conventions:

| The module serves          | Spawn            |
|----------------------------|------------------|
| an API, a store, a message | `grill-design`   |
| a user interface           | `grill-frontend` |

**A change spanning both earns both, spawned as one wave and read together**
([`templates/sub-agents.md`](../../templates/sub-agents.md)). The two ask disjoint questions: a
design run only past `grill-design` comes back clean on authorization and idempotency while nothing has asked what
its screen does with an empty list or a name too long to fit. Where both reports raise one thing, it is written
once.

Never grill the design in this context instead — the agent must judge the files as written, not the reasoning
that produced them, and this session holds that reasoning.

**A design going past a grill a second time goes back to the same agent**, with `SendMessage` to the `agentId`
its first run answered with, saying what changed since. It keeps everything it read, so it judges the new half
instead of re-deriving the old one. Spawn a fresh agent only for the first pass, for a grill of a different kind,
or when the first one is no longer reachable.

### Landing the Report

**The grill writes nothing.** It reports, and this session decides where each finding goes. Every finding lands in
exactly one place, and never in two:

| The finding                                    | Lands as                                                              |
|------------------------------------------------|-----------------------------------------------------------------------|
| a concern's verdict                            | that concern's row in the log's **Concerns**, verdict and why         |
| changes what the design says gets built        | an edit to the design, plus whichever row or entry its basis calls for |
| the grill marked it `assumed` or `deferred`    | one row in the log's **Findings**                                     |
| the grill marked it `must-decide`              | a `D` entry in the spec, which step 8 puts to the user                |
| a **Stack-neutral** failure                    | an edit to the design, and the row's verdict once it passes           |

**The basis decides the home, and the grill already assigned it.** This session re-homes a finding only by
changing its basis — a `must-decide` the repository turns out to answer becomes a row, and an `assumed` whose
evidence does not hold becomes an entry.

**An answer the design already carries is still a row.** The grill cannot see whether the solution section three
pages up already says what it just derived, and the row is what stops the next grill deriving it again.

Assign the `D` and `F` numbers here, each past the highest already in its own sequence. A finding challenging an
existing entry or row becomes a *new* one citing it; neither is ever rewritten, except to correct a claim a
finding proved false.

Then run `design.sh validate` and fix what it reports.

## 8. Put the Open Questions to the User — in One Batch

Read the spec's **Decisions** section back after the grill has run and act on it:

- **Try every `must-decide` against the repository once more** before it reaches the user. The grill works in a
  fresh context and does not know what this session has already read. An entry the code answers stops being an
  entry: it becomes a **Findings** row with its evidence, and the user never sees it.
- **Ask the rest in a single round**, via `AskUserQuestion` — every remaining `must-decide` in one batch, each with
  the options that are actually defensible and a recommendation first. One question is one entry. Where there are
  more entries than the tool takes in one call, the rest go in a second call in the same turn — never two entries
  folded into one question, since one answer would then settle two calls.
- **Write the answers back**: `Answer:` filled in and `Basis: decided (user, <date>)` in the spec; the
  alternative, the reasoning and the files in the log's **Decision Bases**. The chat answer is not the record; the
  files are. Anything the user's answer invalidates elsewhere — a sequence diagram branch, a paragraph of the
  solution, a concern's verdict — is corrected in the same edit.

**An answer that adds a subject sends the task back through step 7 before step 9.** Picking between the options
offered needs no second grill. Answering with something the design did not contain — another migration, another
table, a second concern folded in — leaves a half nobody has judged. Send it back to the same grill (step 7).

A widened design also invalidates entries written before it. Re-read the ones the new subject touches.

## 9. Hand Over

- Present the spec, and name the design and the log beside it.
- **Report what the grill added and what step 8 answered from the repository** — each `D` with its clause.
- **Run `design.sh validate` and `design.sh settled`** and report what they say.
- List any entry still `must-decide`, and say that the spec is unfinished while any remains.
- **Stop.** Do not plan, write code, create other files, or run build commands.

**The three files are the whole handoff, and this session ends with them.** This session holds what the files
deliberately leave out — a shape considered and dropped. What is worth keeping of that is already in the log.
Whoever works from the task next must work from the files alone, or they inherit context nobody else can see.
Starting cold is also the format's own test: a design a fresh session cannot work from was underspecified.

Say so when handing over, so the user knows the stop is the design's, not an unfinished job.
