# `rework.md` and `steps.md`

What Phase 1 writes. They follow the repository's documentation conventions like any other document.

## The directory

`docs/<n>-<name>/`, `<n>` one more than the highest `<number>-*` in `docs/` and `docs/implemented/`. The
directory carries the number and the name; no file repeats them.

| The rework reaches                 | The directory holds                                          |
|------------------------------------|--------------------------------------------------------------|
| one module                         | `rework.md`, steps included                                  |
| several                            | `rework.md` without steps, and `<module>/steps.md` for each  |
| several, across a shared signature | one more: `shared/steps.md`, holding `stabilize` steps only  |

**Every file that holds steps has a log beside it** under the file's stem — `rework-log.md`,
`<module>/steps-log.md`, `shared/steps-log.md`. The steps file is what an agent reads and ticks; the log is what
happened to it. **Each steps file and its log are owned by exactly one agent**, so two agents never write one
file. **`rework.md` is the artifact a fresh session resumes from**, its log read with it — see
[`resuming.md`](../../templates/resuming.md).

**`**Closed:** <why>`** in `rework.md`'s header means the rework was decided against before its steps were
applied. It is the header line alone; nothing is written to the log. It is left where it is, never archived,
and not resumed.

## `rework.md`

```
# Rework: <what changes>

**Affected Modules:** `module-a`
**Source:** <one line, a path not a link — a findings file and the row's number, a file, or the request>
**Baseline:** <the commit the suite was green at>

## The fix

<the change in one sentence, then what that sentence needs to be believed — the mechanism it turns on, or the
chain of causes it cuts and where. Where diagrams follow, say so and stop.>

## What changes

**<the first move, in a clause>**

| #   | Kind | What changes | Touches |
|-----|------|--------------|---------|

**<the next move>**

| #   | Kind | What changes | Touches |
|-----|------|--------------|---------|

**Not changed:** <one line — what a reader might fear this rework alters and it does not>

## What the code does now

| What | Where | What is wrong with it |
|------|-------|-----------------------|

## Structure

<Now and Target component diagrams, in the module's diagram language and under its rules for boundaries and
marking. Only where the rework moves responsibility between classes, creates one or removes one; otherwise the
section is left out. A created class is marked as an addition in Target; a deleted one is drawn only in Now.
Whatever moves between the two is labelled with the step IDs that move it.>

## What must stay true

<one line per invariant no test asserts, and how it would be noticed if it broke>

## Steps

<the checklist — step-format.md>

## Open Questions

- **Q1:** …
  - A:
```

`Q` numbers are per file: a steps file's questions start at `Q1` however many `rework.md` asked.

## Each `steps.md`

A `<module>/steps.md` carries `**Affected Module:**` and `**Rework:** [<the rework>](../rework.md)` above its
`## Steps`, and `## Open Questions` where a run has something to ask; `shared/steps.md` names every module on
the seam. **`## What changes` stays in `rework.md`** and covers every steps file.

## Each log

`<file-stem>-log.md` beside its steps file, titled `# Rework Log: <what changes>` after the rework's title, and
holding one section:

| Section     | Holds                                                                           | Written by                         |
|-------------|---------------------------------------------------------------------------------|------------------------------------|
| **Run Log** | `B<n>` entries, one per thing the run recorded — a blocker, a note, a deviation | `rework-module`, `rework.sh block` |

Phase 1 writes the title alone; `rework.sh block` creates the **Run Log** heading at the first entry. An entry
is `- **B<n> (<ID>):** what happened`, `<ID>` the step it belongs to, numbered once per log and appended; a
blocker carries a `- Resolved:` line beneath it, filled when it is settled, and a note nothing waits on carries
none. A rework keeps no **Attempts** and no **Review Findings**.

## What changes

**This section is the rework to a person.** A reader who agrees with **The fix** and these tables can stop; the
rest is evidence.

- **Rows are grouped by the move they make**, under a bold clause saying what that group achieves. A rework is
  usually three or four moves; twenty rows in ID order are not readable.
- **`What changes` starts with a verb** — `move`, `split`, `rename`, `narrow`, `add check`, `drop` — and is one
  clause. A row that needs two is two steps.
- **`Touches` is the one class or package the step reaches**, so the blast radius is read down one column.
- **`Not changed:` names what a reader would fear this rework alters and it does not** — the SQL text, a test
  assertion, a public port.

**Write the tables from the checklist, never the checklist from the tables.** They are written once at Phase 1;
a step re-classified in Phase 2 edits both. Ticks live in the checklist only. **Nothing in a steps file is
history**: what a run wrote into it is a tick, `abandoned — <why>` on a header, a corrected `survives:`, a
widened `files:`, and an Open Question — each of the last three with a `B` entry in the log saying so.
