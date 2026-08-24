# The backlog

`docs/backlog.md`, at the repository root of `docs/`: every bug still unfixed and every refactoring candidate
still open across every archived task and rework, in two tables. A person opens it to learn what the repository
owes itself without opening a task's `review/findings.md`; a `fix-bug` starts from a row in the first table, a
`rework` from a row in the second.

**It holds pointers, never a second copy.** The task's `findings.md` owns the row — its text, its status, its
reasoning. The backlog carries one clause and a link, and a row leaves the backlog when the owner closes it.

**The backlog assigns the id.** A findings file numbers its candidates `R1` upward within itself and gives a bug
no number at all, so neither names a row across the repository. The backlog gives every row one id on append —
`B<n>` for a bug, `C<n>` for a refactoring candidate, each counted from 1 and never reused — and that id is
what a fix or rework is planned against.

Shape:

```
# Backlog

Work still open from reviews: one row per bug not yet fixed, one row per `R` row whose owner still says
`open`. The owning `review/findings.md` holds the finding; this file only points at it. The `#` column is the
id to name when planning a bug fix or a rework — `B<n>` for a bug, `C<n>` for a refactoring candidate — and it
never changes once given.

## Bugs

| #  | Raised by | Module     | What                                   | Where                                                 |
|----|-----------|------------|----------------------------------------|-------------------------------------------------------|
| B1 | task <n>  | `<module>` | <the block's heading, cut to a clause> | [findings](implemented/<n>-<task>/review/findings.md) |

## Refactoring candidates

| #  | Raised by | Module     | What                              | Where                                                 |
|----|-----------|------------|-----------------------------------|-------------------------------------------------------|
| C1 | task <n>  | `<module>` | <the row's what, cut to a clause> | [findings](implemented/<n>-<task>/review/findings.md) |
```

- **#** — the backlog's own id, `B<n>` or `C<n>`, one more than the highest in its table.
- **Raised by** — `task <n>` or `rework <n>`, the directory's number.
- **Module** — the module the finding names; several, comma-separated, where it names several.
- **What** — one clause: a bug's heading cut to a line, a candidate's *what* cut to a line; the case and the
  *why* stay with the owner.
- **Where** — a relative link from `docs/` to the owning `findings.md`.

Rows are appended in the order they are filed and never renumbered; a closed row is removed, not struck through.
A table with no rows keeps its heading and header line, so a reader sees it is empty rather than missing.

Who writes it:

| Moment                                               | Who                       | Does                                                              |
|------------------------------------------------------|---------------------------|-------------------------------------------------------------------|
| a task's `review/findings.md` is written             | `implement-plan`, phase 3 | appends one `B` row per bug block and one `C` row per `R` row     |
| a rework's `review/findings.md` is written           | `rework`, phase 3         | appends one `B` row per bug block                                 |
| a fix closes the bug it came from                    | `fix-bug`, phase 7        | removes that `B` row                                              |
| a rework closes the row it came from                 | `rework`, phase 4         | removes that `C` row; leaves it if the owner's status stays `open` |
| a person closes a row directly (`done · directly`)   | whoever set the status    | removes the row                                                   |
