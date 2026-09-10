# fix fixtures

`good/` is a complete repository with one bug at `docs/3-double-charge/`: `bug.md`, `bug-log.md`, `fix.md` with three open steps (FS01, FR01, FG01) and `fix-log.md` with two attempts. `tests/cases/fix.sh` copies it, makes it a git repository and runs every happy-path command against it.

Each `bad/<what-is-wrong>/` holds only the file that differs from `good/`, at the same relative path. The case file copies `good/` again and overlays one variant, then runs `validate` on the fix file.

| Directory                | What is wrong                                            | Check it drives                                  |
|--------------------------|----------------------------------------------------------|--------------------------------------------------|
| `no-format-line`         | `fix.md` has no `**Format:**` line                       | "no **Format:** line"                            |
| `duplicate-fr01`         | a fourth step repeats FR01, and nothing else is wrong    | "duplicate ID FR01"                              |
| `needs-names-nothing`    | FR01 needs FS09, which no step defines                   | "names FS09, which this file defines no step for"|
| `reproduces-placeholder` | FR01's `reproduces:` is `TBD`                            | "is empty or still a placeholder"                |
| `green-without-fixes`    | FG01 has no `fixes:` line                                | "is a green step and owes fixes:"                |
| `attempts-in-fix-md`     | an `## Attempts` heading sits in `fix.md`                | "'## Attempts' sits in the fix.md"               |
| `missing-log`            | `fix.md` alone, with no `fix-log.md` beside it; used on its own, not overlaid, because an overlay cannot remove a file | "no fix log at" |
