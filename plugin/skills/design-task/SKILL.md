---
description: Settle a change before any plan exists — a spec the user signs, optional stack-neutral design artifacts, and a log of why. Runs the grill subagent, then puts only the genuinely open questions in front of the user.
argument-hint: [ description of the feature or task to design, or a backlog id BT<nn> ]
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/design/design.sh *) Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/design/design.sh *)
---

# Design Task

Settle **what** the change does and **what it does when things go wrong**. Record every judgment call it makes as
an answered decision.

This skill produces a spec, a log and only the design artifacts the task needs. It then stops. The one exception
is a withdrawal §1's measurement forces: the backlog row and the owning findings row's status. It writes no
checklist items, implementation tests or step IDs.

| File | Reader | Holds |
|------|--------|-------|
| `spec.md` | the user, who signs it | Scope, behaviour, decisions and the design-artifact index |
| linked design artifacts | whoever needs that view | A flow, contract, stored shape or algorithm |
| `design-log.md` | whoever asks *why* | Concerns, repository Findings, Decision Bases |

**The spec is the entry point.** It holds what is promised, what proves it, what the user chose and where to look
for any extra design view. No class belongs there.

**Every design artifact is stack-neutral.**

**The log is the train of thought.** Everything binding is in the spec or a linked artifact. The log says where
those facts came from.

## 1. Create the Task Directory

**A task started from a backlog `BT` row measures the row before the directory exists.** Read the row's owning
findings entry and check its *why* against the code it names, in one pass over the whole class the claim
generalizes over ([`findings.md`](../../templates/findings.md), **Measured, Not Noticed**). What the measurement
narrows narrows the task, and §4's **Objective** says what was measured. What it contradicts ends the run before
anything is created: report it, set the owning findings row's `Status` to `withdrawn` with that clause, remove
the `BT` row from `docs/backlog.md` in the same edit, and take no number.

A task owns a directory under the repository-root `docs/`. Create it as `docs/<number>-<task-name>/` and write
`spec.md`, `design-log.md` and any design artifacts indexed by the spec. Whatever else the task accumulates joins
it there. The directory carries the number and task name; the files do not repeat them.

> **Numbering rule:** `<number>` is one more than the highest already in use, scanning the directory names
> `<number>-*` in **both** `docs/` and `docs/implemented/`.

> **Archiving rule:** active work lives in `docs/`, completed work in `docs/implemented/`. A task is never
> archived here: this skill leaves the directory in `docs/`.

### One Subject per Task

A request that adds more than one subject — a new store *and* a new consumer *and* a new prompt — is one task per
subject, each with its own directory, numbered in dependency order. Every task is then one grill, one plan and one
delivery. The first spec names the sequence in its **Objective**; a later one cites an earlier one's `DN` and `DF`
by task number, the way it cites an implemented task's.

Split **before** writing, not after the grill. An artifact about a second subject the **Objective** did not name
has already crossed the line. The measure is subjects, not lines. `design.sh validate` prints the counts.

The seam between two tasks is a stored table, a flag, or a message shape the earlier one ships. Where the split
leaves nothing user-visible until the last task lands, every task ships behind the same flag, and the relevant
artifact says so.

## 2. Read Module Conventions

After determining the **Affected Modules**, read `<module>/docs/conventions.md` for every affected module, and the
repo-root `docs/conventions.md` if it exists. The conventions give the stack, the diagram format, and the
repository facts that constrain the design.

If a module has no conventions file, record a `must-decide` decision asking the user to run `init-conventions`.
Never silently guess a module's conventions.

**An open critical row in an affected module is asked about once, here.** Read the **Critical** table of
`docs/backlog.md`. Keep the rows whose `Module` names an affected module. Where any remain, ask the user in one
`AskUserQuestion`: take those rows first, or go on with this task. One question, whatever the count. Going on
is not recorded anywhere. A row in a module this task does not touch is not asked about. A task started from a
`BC` row is started the way its `Kind` says: `fix-bug` for a bug, `rework` for a refactoring candidate, this
skill for a deferred change.

## 3. Read What Already Exists

Before writing anything, read the closest existing feature end to end — its domain types, its usecase, its
adapters, its migration — and the conventions that govern them. Use what it establishes to write the neutral
behaviour.

The same holds for a contract a **library generates** rather than the code declaring — a tool or endpoint schema
derived from a signature, a serializer's wire form, a generated client. Read the generator itself before the
design fixes the shape, decompiling it from the dependency if the source is not at hand.

## 4. The Spec

`spec.md` opens with the title, then `**Format:** 2` and `**Affected Modules:**`. The latter names every top-level
module whose code, configuration or migrations change. `plan-task` later adds
`**Approved:** <who>, <date>, <hash>` beneath `**Format:**`
([`scripts/design/README.md`](../../scripts/design/README.md)). The spec MUST contain these sections, in this
order.

### Objective

What needs to be achieved, and why it matters to whoever asked. A short paragraph. What it promises is the next
section's; this one says why.

**A task started from the backlog names its row.** Where the argument is a `BT<nn>` id, read the row in
`docs/backlog.md` and the findings row it links; that row's *what* and *why* seed this paragraph **as §1's
measurement left them**, never as the row wrote them. Its first line is `Closes BT<nn>`, which `implement-plan`
reads to close the row when the task is archived.

### Requirements

What the change promises, one line each, numbered `RQ01`, `RQ02`, …:

```
- **RQ01:** A person can pick the currency their amounts are assumed to be in.
- **RQ02:** A chosen currency reaches the model on every turn.
```

A requirement is a behaviour the user signs off, in their words — not a mechanism, not a status code. Every
**Acceptance Scenario** names the requirement it proves, and `design.sh validate` refuses a requirement no
scenario proves and a scenario proving nothing. Three to eight is the usual count; more is a second subject.

Numbers are assigned once and never reused.

### Acceptance Scenarios

What the change does, as behaviour a person can agree or disagree with. One block per entry point, each scenario
numbered `AC01`, `AC02`, … in this format:

```
- **AC01:** [what the scenario is, one line]
  - Given: [the state before]
  - When: [what the user or caller does]
  - Then: [what they get back, and what changed]
  - Proves: RQ01, RQ03

- **AC02:** [the next one]
  - Given: …
```

**The four lines are nested under the scenario, and a blank line separates one scenario from the next.**

**One per branch of a linked flow artifact**, happy path and every failure alike. A branch with no scenario is a
gap in the scenarios; a scenario with no branch is a gap in the artifact. A task with no flow artifact applies
this check directly to its described behaviour.

**`Proves:` names the requirement.** One scenario may prove several; every requirement is proved by at least one.

Numbers are assigned once and never reused.

**These are behaviour, never mechanics.** No class, no test class, no layer. "Then: the response is 400 with
`PERIOD_INVALID`" is a scenario; "then `ListExpensesUseCase` throws" is a plan step.

**A `Then:` may be a measurement.** "Then: the page answers in under 300 ms at 10,000 rows" is a scenario: a
figure, its unit, and the load it holds under. Latency, throughput and memory are the measurements. The plan maps
such a scenario to a performance step where the module's conventions name a tool, and records it as unmeasured
where they do not. Idempotency, a limit and a page size are ordinary behaviour with an ordinary `Then:`.
Retention and availability are neither: they are the infrastructure's and belong in a relevant design artifact.

### Decisions

Every judgment call the user made or still has to make, one entry each, in this exact format:

```
- **DN01:** [the question, one line]
  - Answer: [what the change does]
  - Basis: decided (user, <date>) | must-decide — [what the repository does not say]

- **DN02:** [the next question]
  - Answer: …
```

**`Answer` and `Basis` are nested under their entry, and a blank line separates one entry from the next.**

Numbered `DN01`, `DN02`, … assigned once and never renumbered: an entry that is answered, withdrawn, or reversed keeps
its number.

**Only two bases live here: `decided` and `must-decide`.** An entry is the question, the answer, and who chose.
**The reasoning is the log's**: the alternative that lost, why, and the files it rested on go under the same `DN`
number in the log's **Decision Bases**. `design.sh validate` refuses a `decided` entry with no such line.

An `assumed` or `deferred` question is a **Findings** row in the log instead. `design.sh validate` refuses a `DN`
entry carrying either basis.

**The four bases, and what each obliges:**

| Basis         | Means                                                            | Lives in                  | Owes                                                        |
|---------------|------------------------------------------------------------------|---------------------------|-------------------------------------------------------------|
| `decided`     | the user chose between defensible options                        | the spec's Decisions      | who chose and when here; the alternative and the files in the log's Decision Bases |
| `must-decide` | a product, operational, or business rule that exists nowhere yet | the spec's Decisions      | an empty `Answer:` and what the repository does not say     |
| `assumed`     | the repository determines the answer                             | the log's Findings        | the answer, one clause, and the file that determines it     |
| `deferred`    | real, but out of scope for this change                           | the log's Findings        | what happens instead, and what would bring it back          |

`must-decide` is the only one that leaves `Answer:` empty, and it is what `settled` counts. An `assumed` row
with no file to point at is a `must-decide` in disguise. Code this repository does not own is not evidence.
`assumed` needs something in the tree that already exercises the path and what it was observed to produce;
otherwise the row is `deferred`, naming what would settle it.

**Answer against the repository before asking.** Ask only what the repository genuinely cannot answer, and say in
`Basis:` precisely what it does not say.

**Cite a decision by its clause, not its number alone.** In any file, in a plan, in a report: "DN02 — a choice is
never cleared", not "DN02".

The spec is **settled** when no entry carries `Basis: must-decide`.

## 5. Design Artifacts

The spec ends with `## Design Artifacts`. Write `None.` when the spec already communicates the whole change.
Otherwise list only the views a person needs after reading the spec:

```
## Design Artifacts

- [Checkout sequence](checkout-sequence.md) — how reservation, payment and release meet.
- [REST API update](rest-api-update.md) — the changed operations, fields and statuses.
```

Each artifact answers one question that prose in the spec cannot show clearly. Name the file after that question,
using a lowercase Markdown filename. The framework defines no fixed artifact kinds or filenames.

Prefer a diagram, table, schema or pseudocode. Add only the prose needed to read it. Do not repeat an objective,
requirement, scenario or decision; cite its `RQ`, `AC` or `DN` clause where the connection would otherwise be
unclear. Apply [`stack-neutral-design.md`](../../templates/stack-neutral-design.md) to every artifact.

Common reasons to add an artifact include:

- a flow whose ordering, branching or concurrency matters;
- a contract crossing module boundaries;
- a stored shape and the transitions that change it;
- an algorithm easier to verify as pseudocode or a state diagram.

Where **Affected Modules** names several modules, at least one artifact shows every boundary between them and what
crosses it. Name any schema or other file that several modules read at build time and which modules read it. Such
an artifact is implemented before the module plans.

Use the diagram language named by the module conventions. Where they name none, use PlantUML. A diagram box is a
responsibility, module or system. Never draw classes; implementation placement belongs to the plan.

`design.sh validate` checks that every indexed artifact exists beside the spec and names no source file. An
unindexed file is not a task input. See `example-flow.md` and `example-api-update.md` beside this skill.

## 6. The Design Log

`design-log.md`, in this order. Leave each section as a placeholder while writing the spec and artifacts; the
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

**Why is a business rule, a file, or a `DN`/`DF`.** Never "not applicable" alone.

### Findings

Every question the change answered that needs no reader — the `assumed` and the `deferred`:

| #  | Question | Answer | Evidence |
|----|----------|--------|----------|

- **Very short, all three columns.** A question is a clause, an answer is a clause, and evidence is a link.
- **Evidence is a file** — the class, the migration, the conventions page, the ADR. Never an argument. A row with
  no file to point at is a `must-decide`, not a row.
- **A `deferred` row's answer says what happens instead**, and its evidence is what would bring it back.
- **`DF01`, `DF02`, … on the same terms as a `DN`:** assigned once, never renumbered, never reused. The spec and an
  artifact cite a row the way they cite an entry, and a row that is answered or withdrawn keeps its number.

The `DF` sequence is the task's own. A plan log's **Review Findings** numbers its own `RF01` upward, in its own
file, and the two never meet.

A question that needs a paragraph was not settled. It is a `must-decide` in the spec's **Decisions**, and the
user answers it.

### Decision Bases

One line per `DN` in the spec, same number: what the user chose over, why, and the files the choice rested on.

```
- **DN02:** The user chose a choice that stays set over one that can be returned to nothing; the request schema
  cannot express null (`<api-schema-file>`), and `<sibling-usecase-file>` never clears a stored value either.
```

`design.sh validate` checks the spec, linked artifacts and log — see
[`scripts/design/README.md`](../../scripts/design/README.md)
for the list. `design.sh settled` answers the separate question — whether anything is still open. The script
ships with these instructions at `scripts/design/design.sh` — under `${CLAUDE_PLUGIN_ROOT}` when installed as a
plugin, under `.claude/` in a plain checkout. Address a task by its directory or any Markdown file inside it.

Run `validate` before invoking the grill, and both it and `settled` again before handing over. Refused or absent
on the first call, tell the user once as [`scripts/README.md`](../../scripts/README.md) says and answer each
check by reading the files.

## 7. Invoke the Grill Subagent

Once the spec and its artifacts are written, spawn a grill against the task directory. Use the model the module
conventions name for deciding work; where they name none, the default model.

**Which grill depends on what the change touches**, read from each affected module's conventions:

| The module serves          | Spawn            |
|----------------------------|------------------|
| an API, a store, a message | `grill-design`   |
| a user interface           | `grill-frontend` |

**A change spanning both earns both, spawned as one wave and read together**
([`templates/sub-agents.md`](../../templates/sub-agents.md)). Where both reports raise one thing, it is written
once.

Never perform the grill in this context instead of spawning the agent.

**A task going past a grill a second time goes back to the same agent**, with `SendMessage` to the `agentId`
its first run answered with, saying what changed since. Spawn a fresh agent only for the first pass, for a grill
of a different kind, or when the first one is no longer reachable.

### Landing the Report

**The grill writes nothing.** It reports, and this session decides where each finding goes. Every finding lands in
exactly one place, and never in two:

| The finding                                    | Lands as                                                              |
|------------------------------------------------|-----------------------------------------------------------------------|
| a concern's verdict                            | that concern's row in the log's **Concerns**, verdict and why         |
| changes the agreed behaviour or a design view  | an edit to the spec or artifact, plus the row or entry its basis calls for |
| the grill marked it `assumed` or `deferred`    | one row in the log's **Findings**                                     |
| the grill marked it `must-decide`              | a `DN` entry in the spec, which step 8 puts to the user                |
| a **Stack-neutral** failure                    | an edit to the artifact, and the row's verdict once it passes         |

**The basis decides the home, and the grill already assigned it.** This session re-homes a finding only by
changing its basis — a `must-decide` the repository turns out to answer becomes a row, and an `assumed` whose
evidence does not hold becomes an entry.

**An answer an artifact already carries is still a row.**

Assign the `DN` and `DF` numbers here, each past the highest already in its own sequence. A finding challenging an
existing entry or row becomes a *new* one citing it; neither is ever rewritten, except to correct a claim a
finding proved false.

Then run `design.sh validate` and fix what it reports.

## 8. Put the Open Questions to the User — in One Batch

Read the spec's **Decisions** section back after the grill has run and act on it:

- **Try every `must-decide` against the repository once more** before it reaches the user. An entry the code
  answers stops being an entry: it becomes a **Findings** row with its evidence, and the user never sees it.
- **Ask the rest in a single round**, via `AskUserQuestion` — every remaining `must-decide` in one batch, each with
  the options that are actually defensible and a recommendation first. One question is one entry. Where there are
  more entries than the tool takes in one call, the rest go in a second call in the same turn — never two entries
  folded into one question.
- **Write the answers back**: `Answer:` filled in and `Basis: decided (user, <date>)` in the spec; the
  alternative, the reasoning and the files in the log's **Decision Bases**. Anything the user's answer
  invalidates elsewhere — a diagram branch, a table row, a concern's verdict — is
  corrected in the same edit.

**An answer that rules something out of scope files it now.** Where the user's answer says a change is real
and belongs to a later task, append a `BT` row to `docs/backlog.md` in the same edit. Its owner is the
`deferred` **Findings** row this answer produces, and the `Where` column links to the design log
([`backlog.md`](../../templates/backlog.md)).

**An answer that adds a subject sends the task back through step 7 before step 9.** Picking between the options
offered needs no second grill. An answer the artifacts did not contain — another migration, table or subject —
goes back to the same grill (step 7).

A widened task also invalidates entries written before it. Re-read the ones the new subject touches.

## 9. Hand Over

- Present the spec, name its design artifacts and the log beside it.
- **Report what the grill added and what step 8 answered from the repository** — each `DN` with its clause.
- **Run `design.sh validate` and `design.sh settled`** and report what they say.
- List any entry still `must-decide`, and say that the spec is unfinished while any remains.
- **Stop.** Do not plan, write code, create other files, or run build commands.

**The indexed files are the whole handoff, and this session ends with them.** Whoever works from the task next
works from those files alone.

Say so when handing over, so the user knows the stop is deliberate, not an unfinished job.
