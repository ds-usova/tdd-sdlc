# The backlog

`docs/backlog.md`, at the repository root of `docs/`: every critical entry, every bug still unfixed, every
refactoring candidate, every deferred change and every performance figure past its threshold still open, across
every archived task, fix, rework and upgrade, in five tables. A `fix-bug` starts from a bug row, a `rework` from
a candidate row, a `design-task` from a deferred-change row. A performance row waits for a run that measures the
test under its threshold. A critical row starts whichever of the three its kind says.

**A record, not an offer.** A run that files a row says "recorded, not started" and stops. It never proposes
to take the row next.

**Every row is measured work.** A row is appended only from an entry whose findings file measured what it claims
— [`findings.md`](findings.md)'s **Measured, Not Noticed**. An observation a run merely reported gets no row
here and no id.

**A row is measured once more by whoever starts from it**, before that run writes a file: the same pass, over
the tree as it stands now. What does not hold is reported, its owner's status set to `withdrawn`, and the row
removed — never worked.

**It holds pointers, never a second copy.** The owner holds the text, the status and the reasoning. The
backlog carries one clause and a link. A row leaves the backlog when the owner closes it, by `done`,
`withdrawn` or `wontfix`.

**The owner is usually a `review/findings.md`, and not always.** A deferred change decided mid-run is filed
the moment the user decides it. Its owner is where the decision was written: a `deferred` `DF` row in a
design log, an answered `OQ` in a rework or fix file, a `DN` entry. The `Where` column links there.

**No backlog id is written into the tree.** The rule is [`reproducing.md`](reproducing.md).

**The backlog assigns the id.** A findings file numbers its candidates `RX01` upward, its deferred changes
`DX01` upward and its performance rows `PX01` upward within itself and gives a bug or a critical entry no number
at all. The backlog gives every row one id on append —
`BC<nn>` for a critical entry, `BB<nn>` for a bug, `BR<nn>` for a refactoring candidate, `BT<nn>` for a deferred
change, `BP<nn>` for a performance figure — each counted from 1 and never reused. That id is what a fix, a
rework or a design is started from.

Shape:

```
# Backlog

Work still open: one row per critical entry, one per bug not yet fixed, one per `RX`, `DX` and `PX` row whose
owner still says `open`. The owner holds the finding; this file only points at it. The `#` column is the id to
name when starting a fix, a rework or a design — `BC<nn>` critical, `BB<nn>` bug, `BR<nn>` refactoring
candidate, `BT<nn>` deferred change, `BP<nn>` performance — and it never changes once given.

## Critical

| #    | Raised by | Module     | Kind     | What                                   | Where                                                 |
|------|-----------|------------|----------|----------------------------------------|-------------------------------------------------------|
| BC01 | task <n>  | `<module>` | <kind>   | <the block's heading, cut to a clause> | [findings](implemented/<n>-<task>/review/findings.md) |

## Bugs

| #  | Raised by | Module     | What                                   | Where                                                 |
|----|-----------|------------|----------------------------------------|-------------------------------------------------------|
| BB01 | task <n>  | `<module>` | <the block's heading, cut to a clause> | [findings](implemented/<n>-<task>/review/findings.md) |

## Refactoring candidates

| #  | Raised by | Module     | What                              | Where                                                 |
|----|-----------|------------|-----------------------------------|-------------------------------------------------------|
| BR01 | task <n>  | `<module>` | <the row's what, cut to a clause> | [findings](implemented/<n>-<task>/review/findings.md) |

## Deferred changes

| #  | Raised by | Module     | What                              | Where                                                 |
|----|-----------|------------|-----------------------------------|-------------------------------------------------------|
| BT01 | task <n>  | `<module>` | <the row's what, cut to a clause> | [findings](implemented/<n>-<task>/review/findings.md) |

## Performance

| #    | Raised by | Module     | What                                      | Where                                                 |
|------|-----------|------------|-------------------------------------------|-------------------------------------------------------|
| BP01 | task <n>  | `<module>` | `<test>` · <threshold> · measured <figure> | [findings](implemented/<n>-<task>/review/findings.md) |
```

- **#** — the backlog's own id, `BC<nn>`, `BB<nn>`, `BR<nn>`, `BT<nn>` or `BP<nn>`, one more than the highest in
  its table.
- **Raised by** — `task <n>`, `fix <n>`, `rework <n>` or `upgrade <n>`, the directory's number.
- **Kind** — critical rows only: `bug`, `deferred change` or `refactoring candidate`. It says which skill takes
  the row.
- **Module** — the module the finding names; several, comma-separated, where it names several.
- **What** — one clause: a bug's heading cut to a line, a candidate's or a deferred change's *what* cut to a
  line, a performance row's test, threshold and figure; the case and the *why* stay with the owner.
- **Where** — a relative link from `docs/` to the owning `findings.md`.

Rows are appended in the order they are filed and never renumbered; a closed row is removed, not struck through.
A table with no rows keeps its heading and header line.

Who writes it:

| Moment                                             | Who                       | Does                                                                                    |
|----------------------------------------------------|---------------------------|-----------------------------------------------------------------------------------------|
| a task's `review/findings.md` is written           | `implement-plan`, phase 3 | appends one `BB` row per bug block, one `BR` row per `RX` row, one `BT` row per `DX` row and one `BP` row per `PX` row |
| a rework's `review/findings.md` is written         | `rework`, phase 3         | appends one `BB` row per bug block, one `BT` row per `DX` row and one `BP` row per `PX` row |
| a fix's or an upgrade's `review/findings.md` is written | `fix-bug`, `upgrade-deps`, at the close | appends one `BP` row per `PX` row, beside the rows each already files |
| a run measures a figure under an open `BP` row's threshold | `implement-plan`, `fix-bug`, `rework`, `upgrade-deps`, at the close | removes that `BP` row and sets the owner's status to `done · <run> <n>` |
| a fix closes the bug it came from                  | `fix-bug`, step 10        | removes that `BB` row                                                                    |
| a rework closes the row it came from               | `rework`, step 6          | removes that `BR` row; leaves it if the owner's status stays `open`                      |
| a task closes the row its design came from         | `implement-plan`, phase 3 | removes that `BT` row and sets the owner's status to `done · task <n>`                   |
| a person closes a row directly (`done · directly`, `wontfix`) | whoever set the status | removes the row                                                                  |
| a run's opening measurement withdraws its row      | `fix-bug` and `rework`, phase 0; `design-task`, §1 | removes that row and sets the owner's status to `withdrawn` |
