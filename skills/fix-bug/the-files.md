# `bug.md` and `fix.md`

What Phase 1 writes. They follow the repository's documentation conventions like any other document.

## The directory

`docs/<n>-<name>/`, `<n>` one more than the highest used in `docs/` and `docs/implemented/`.

| The bug reaches                     | The directory holds                  |
|-------------------------------------|--------------------------------------|
| one module                          | `bug.md`, `fix.md`                   |
| several                             | `bug.md`, `<module>/fix.md` for each |
| several, on a contract between them | one more: `shared/fix.md`            |

**Every file has a log beside it under its own stem** — `bug-log.md`, `fix-log.md`, `shared/fix-log.md`. The
file binds; the log is what happened to it, and `fix.sh validate` refuses a file with no log beside it.

**`bug.md` holds the bug. Each `fix.md` holds one module's work and, with its log, is owned by exactly one
agent** — the module agents run concurrently, so two of them never write the same file.

## `bug.md`

```
# Bug: <the symptom, in the user's terms>

**Affected Modules:** `module-a`, `module-b`
**Source:** <one line — a findings file and row, a report, an issue, or the request>
**Baseline:** <the commit, then per module: total, skipped, and any machine state a skip depends on>

## What happens

- **Given** <the state the system is in>
- **When** <what happens>
- **Then** <what should follow>
- **Actual** <what follows instead>

## How it reproduces

<the exact command, request or test, and the output it produced — quoted, not described>

## Why it happens

<the chain of causes, from the symptom back to the line that is wrong>

## What the fix must not break

<one line per behaviour that currently works and depends on the code being changed>
```

**`## Why it happens` is a chain, and every link is evidence.** A link nothing proved is marked `unverified` on
its own line; a chain with one is a hypothesis, and the section says what would settle it.

**`**Closed:** <why>`** in the header means the fix was decided against or abandoned. It is left where it is,
never archived, and not resumed. It is the header line alone; nothing is written to the log.
**`## Structure`**, two component diagrams Now and Target in the module's diagram
language, is added only where the fix moves responsibility between classes. **`## Open Questions`**, in the
`- **Q1:** … / - A:` form, is added only where Phase 2 has something to ask.

## `bug-log.md`

```
# Bug Log: <the symptom, as bug.md's title>

## Attempts

<see templates/attempts.md — the diagnosis's failed approaches, phase `diagnosis`>

## Run Log

- **B1 (diagnosis):** <what happened — an effect a probe's revert did not undo, a second defect found and
  not fixed>
```

**The log is written from the first probe.** Phase 1 creates it with `## Attempts` and nothing under it; the
`## Run Log` heading appears with its first entry. An entry is `- **B<n> (<what it is about>):** what
happened`, numbered from 1 in the order written and never renumbered, appended after the last — a fix file's
step ID in the parenthesis where it concerns one, `diagnosis` or a module where it does not. A `B` entry here
records a fact; nothing waits on it, so it carries no `Resolved:` line.

`fix.sh attempts <the directory>` prints every log's attempt numbers as one line — `bug-log.md · A1–A3,
module-a/fix-log.md · A1, module-b/fix-log.md · —` — for the report.

## Each `fix.md`

```
# Fix: <what changes in this module>

**Affected Module:** `module-a`
**Bug:** [<the bug>](../bug.md)

## Steps

| #   | Kind | What changes | Touches |
|-----|------|--------------|---------|

<the checklist — see step-format.md>
```

**The table is the whole fix to anyone not applying it.** `What changes` starts with a verb and is one clause —
a row that needs two is two steps. `Touches` is the one class or package the step reaches, so the blast radius
is read down one column. What proves a step is its kind's, and is not repeated per row. Write the table from
the steps, never the steps from the table.

**`## Open Questions`** appears in a `fix.md` only when its agent returns blocked and writes the question it
needs answered. `Q` numbers are per file, starting at `Q1` in each `fix.md` however many `bug.md` asked;
anything outside the file cites both: `module-a/fix.md · Q2`.

**Nothing else in a `fix.md` is written after approval** but a tick, `abandoned — <why>` on a struck step's
header, a named widening of a `stabilize` step's boundary, and the answer to an Open Question. Everything the
run records goes in the log beside it.

## Each `fix-log.md`

```
# Fix Log: <what changes in this module, as fix.md's title>

**In flight:** <the step being applied and the approach being tried — empty between steps>

## Attempts

<see templates/attempts.md — this module's failed approaches, each under the step's ID>

## Run Log

- **B1 (G01):** <what happened — a blocked return, a widened boundary, an effect a revert did not undo>
  - Resolved: <how it was settled, filled by whoever settles it>
```

**`In flight:` is what a stopped run otherwise leaves nowhere.** `fix.sh start` writes it when a step starts,
`fix.sh tick` empties it. A resumed run reads it for what was being tried and for nothing else — the first
unticked step, not this line, says where to pick up. Phase 1 writes the line with nothing after it.

**The Run Log is where the run writes.** An entry is `- **B<n> (<ID>):** what happened`, `<ID>` the step it
concerns, numbered from 1 and appended after the last. `fix.sh block` writes one for a blocked return, with a
`- Resolved:` line beneath it that whoever settles it fills; a note nothing waits on — a boundary a step widened,
a step the level above struck as abandoned, a schema a revert left migrated — is appended by hand, with no
`Resolved:` line. The `## Run Log` heading is created at the first entry, as `block` does.

## A Test That Pins the Wrong Behaviour

**The commonest bug is one an existing test asserts.** That test is the `red` step's: it goes in `test-files:`,
the step changes its assertion to the reported symptom, and the run fails as any `red` step must. This is not
weakening a test. The test is named in `## What the fix must not break`, with what it was protecting and why that
is not lost.
