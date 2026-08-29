# The backlog

`docs/backlog.md`, at the repository root of `docs/`: every bug still unfixed, every refactoring candidate and
every deferred change still open across every archived task and rework, in three tables. A person opens it to
learn what the repository owes itself without opening a task's `review/findings.md`; a `fix-bug` starts from a
row in the first table, a `rework` from a row in the second, a `design-task` from a row in the third.

**Every row is measured work.** A row is appended only from an entry whose findings file measured what it claims
— [`findings.md`](findings.md)'s **Measured, Not Noticed**. An observation a run merely reported gets no row
here and no id.

**A row is measured once more by whoever starts from it**, before that run writes a file: the same pass, over a
tree that has moved since, by the only reader who did not write the row. What does not hold is reported, its
owner's status set to `withdrawn`, and the row removed — never worked.

**It holds pointers, never a second copy.** The task's `findings.md` owns the row — its text, its status, its
reasoning. The backlog carries one clause and a link, and a row leaves the backlog when the owner closes it.

**The backlog assigns the id.** A findings file numbers its candidates `R1` upward and its deferred changes `D1`
upward within itself and gives a bug no number at all, so none of them names a row across the repository. The
backlog gives every row one id on append — `B<n>` for a bug, `C<n>` for a refactoring candidate, `T<n>` for a
deferred change, each counted from 1 and never reused — and that id is what a fix, a rework or a design is
started from.

Shape:

```
# Backlog

Work still open from reviews: one row per bug not yet fixed, one row per `R` row and one per `D` row whose
owner still says `open`. The owning `review/findings.md` holds the finding; this file only points at it. The
`#` column is the id to name when starting a bug fix, a rework or a design — `B<n>` for a bug, `C<n>` for a
refactoring candidate, `T<n>` for a deferred change — and it never changes once given.

## Bugs

| #  | Raised by | Module     | What                                   | Where                                                 |
|----|-----------|------------|----------------------------------------|-------------------------------------------------------|
| B1 | task <n>  | `<module>` | <the block's heading, cut to a clause> | [findings](implemented/<n>-<task>/review/findings.md) |

## Refactoring candidates

| #  | Raised by | Module     | What                              | Where                                                 |
|----|-----------|------------|-----------------------------------|-------------------------------------------------------|
| C1 | task <n>  | `<module>` | <the row's what, cut to a clause> | [findings](implemented/<n>-<task>/review/findings.md) |

## Deferred changes

| #  | Raised by | Module     | What                              | Where                                                 |
|----|-----------|------------|-----------------------------------|-------------------------------------------------------|
| T1 | task <n>  | `<module>` | <the row's what, cut to a clause> | [findings](implemented/<n>-<task>/review/findings.md) |
```

- **#** — the backlog's own id, `B<n>`, `C<n>` or `T<n>`, one more than the highest in its table.
- **Raised by** — `task <n>` or `rework <n>`, the directory's number.
- **Module** — the module the finding names; several, comma-separated, where it names several.
- **What** — one clause: a bug's heading cut to a line, a candidate's or a deferred change's *what* cut to a
  line; the case and the *why* stay with the owner.
- **Where** — a relative link from `docs/` to the owning `findings.md`.

Rows are appended in the order they are filed and never renumbered; a closed row is removed, not struck through.
A table with no rows keeps its heading and header line, so a reader sees it is empty rather than missing.

Who writes it:

| Moment                                             | Who                       | Does                                                                                    |
|----------------------------------------------------|---------------------------|-----------------------------------------------------------------------------------------|
| a task's `review/findings.md` is written           | `implement-plan`, phase 3 | appends one `B` row per bug block, one `C` row per `R` row and one `T` row per `D` row  |
| a rework's `review/findings.md` is written         | `rework`, phase 3         | appends one `B` row per bug block and one `T` row per `D` row                           |
| a fix closes the bug it came from                  | `fix-bug`, phase 7        | removes that `B` row                                                                    |
| a rework closes the row it came from               | `rework`, phase 4         | removes that `C` row; leaves it if the owner's status stays `open`                      |
| a task closes the row its design came from         | `implement-plan`, phase 3 | removes that `T` row and sets the owner's status to `done · task <n>`                   |
| a person closes a row directly (`done · directly`) | whoever set the status    | removes the row                                                                         |
| a run's opening measurement withdraws its row      | `fix-bug` and `rework`, phase 0; `design-task`, §1 | removes that row and sets the owner's status to `withdrawn` |
