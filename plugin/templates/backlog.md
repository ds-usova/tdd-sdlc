# The backlog

Every piece of work still open across the repository: every critical entry, every bug still unfixed, every
refactoring candidate, every deferred change and every performance figure past its threshold. A `fix-bug`
starts from a bug entry. A `rework` starts from a refactoring candidate or a performance entry. A
`design-task` starts from a deferred change.

## Where it lives

The repository's conventions name the place. There are three:

| Place                   | Filing                                      | Closing                                                   | Id                    |
|-------------------------|---------------------------------------------|-----------------------------------------------------------|-----------------------|
| `docs/backlog.md`       | a block under `## Open`, in the shape below | the block is removed, or kept as the conventions say      | `BB` `BR` `BT` `BP`   |
| a tracker, such as Jira | an issue carrying the block's fields        | the tracker's closed state, and a comment with the status | the tracker's own key |
| `none`                  | nothing                                     | nothing                                                   | none                  |

The default is in [`contract.md`](conventions/contract.md).

**A tracker the session cannot reach files nothing.** The run's report lists each entry it could not file, in
the block shape, and says why.

**With `none`, nothing is filed.** The findings file and the logs are written as usual. The report says the
backlog is off. A `fix-bug`, `rework` or `design-task` starts from a description only.

**A tracker issue is never deleted.** It is closed with its status.

## Rules

**An entry carries its own text.** Everything a run needs to start from it is in the entry. The file it came
from is its origin, and may be gone.

**A record, not an offer.** A run that files an entry says "recorded, not started" and stops. It never proposes
to take the entry next.

**An entry a run files is measured work.** It comes only from a findings entry that measured what it claims —
[`findings.md`](findings.md)'s **Measured, Not Noticed** — from a baseline test that failed twice
([`red-baseline.md`](red-baseline.md)), or from a decision the user made mid-run. An
observation a run merely reported gets no entry.

**An entry the user asks for is filed as the user states it.** Its origin is `user, <date>`. Ask for the kind
where the user did not give it.

**An entry is measured once more by whoever starts from it**, before that run writes a file, over the tree as it
stands now. What does not hold is reported and the entry closed `withdrawn` — never worked.

**Closing an entry edits the backlog only.** The file the entry came from is not touched.

**No backlog id is written into the tree.** The rule is [`reproducing.md`](reproducing.md).

## The fields

- **Kind** — `bug`, `refactoring candidate`, `deferred change` or `performance`. It says which skill takes the
  entry.
- **Priority** — `critical`, `high`, `normal` or `low`. A critical findings entry files `critical`. Every other
  entry files `normal`. The user changes it at any time.
- **Size** — the filing run's estimate:

  | Size | The work                                     |
  |------|----------------------------------------------|
  | `S`  | a few files in one module, no new test class |
  | `M`  | one module, or a new test class              |
  | `L`  | several modules, or a contract between them  |

- **Module** — the module the entry names; several, comma-separated, where it names several.
- **Raised by** — `task <n>`, `fix <n>`, `rework <n>`, `upgrade <n>` or `user`, then the date.
- **Origin** — a relative link from `docs/` to where the entry was written at the archived path: the findings
  file, a `deferred` `DF` row in a design log, an answered `OQ` in a rework or fix file. None for a user entry
  or a red baseline test.
- **The body** — copied from the origin, whole:

  | Kind                            | Body                                                              |
  |---------------------------------|-------------------------------------------------------------------|
  | bug                             | `Given`, `When`, `Then`, `Actual`, `Test`, `Fix`                  |
  | refactoring candidate, deferred | `What`, `Why`                                                     |
  | performance                     | `Test`, `Threshold`, `Measured`                                   |
  | a critical entry                | `Measured`, `Grows because`, `Breaks as`, `Test` for a bug, `Fix` |
  | a user entry                    | `What`, and `Why` where the user gave one                         |
  | a red baseline test, a bug      | `Test`, `Error`, `Runs` — the verdict of the run and the re-run   |

## `docs/backlog.md`

```
# Backlog

**Format:** 2
**Last ids:** BB03 · BR01 · BT00 · BP00

## Open

### BB03 · `<module>` — <the symptom or the what, in one line>

- **Kind** bug · **Priority** normal · **Size** S
- **Raised by** task <n>, <date> · [origin](implemented/<n>-<task>/review/findings.md)
- **Given** <the state the system is in>
- **When** <what happens>
- **Then** <what should follow>
- **Actual** <what follows instead>
- **Test** `<TestClass#method>`, disabled
- **Fix** <the proposal> · `<class or file>`

## Closed

### BR01 · `<module>` — <the what, in one line>

- **Status** done · rework <n>
- **Kind** refactoring candidate · **Priority** normal · **Size** M
- ...
```

**The id** is the kind's prefix — `BB` bug, `BR` refactoring candidate, `BT` deferred change, `BP` performance —
and one more than that prefix's number on the `Last ids` line. The same edit raises the line. An id never
changes and is never given twice.

**`## Open` is ordered by priority, then by id.** A changed priority moves the block.

**A closed block's status** is `done · <run> <n>`, `done · directly`, `withdrawn · <what the measurement found>`
or `wontfix · <why>`. The run's report names the block with it. What happens to the block, the conventions say:

| The conventions say          | The closed block                                                         |
|------------------------------|--------------------------------------------------------------------------|
| remove closed entries        | is removed                                                               |
| keep closed entries          | moves to `## Closed`, newest first, with `Status` as its first line      |
| nothing                      | waits for the question below                                             |

**The conventions silent, ask before closing**, in one `AskUserQuestion` with two questions:

- remove closed entries (recommended), or keep them under `## Closed`;
- write the answer into the repository conventions beside the backlog's place (recommended), or ask each time.

Close as answered. Where the user chose to write it, write it in the same edit.

`## Closed` exists only where closed entries are kept.

**A file without the `**Format:** 2` line is format 1.** It is never migrated. The first entry filed into it adds
the format line, the `Last ids` line and `## Open` below the old tables. `Last ids` starts from the highest
number each prefix already has in the file. A format-1 row is started from by its id like any other entry. Its
origin link gives the text. Where that file is gone, say so and ask the user for the description. A format-1 row
is closed by removing it.

## Filing and closing

**A run files every open entry of its findings file** once that file is written: each open critical block, bug
block and table row becomes one backlog entry.

**A run started from an entry closes it at its own close**, `done · <run> <n>`. A performance entry closes only
on a figure under its threshold, measured at that close. Otherwise it stays open.

**The user may file or close an entry at any time.** Close it `done · directly` or `wontfix · <why>`.
