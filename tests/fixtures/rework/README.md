# Fixtures for tests/cases/rework.sh

`good/` is a complete repository: `docs/3-widget/rework.md` with no steps of its own, its `rework-log.md`, and
`mod/steps.md` with four steps (one ticked, one abandoned) beside its `mod/steps-log.md`. Every
subcommand runs against a copy of it.

Each directory under `bad/` holds only the file that differs from `good/`, at the same relative path. A case
copies `good/` again and overlays one of them.

| Directory             | What is wrong                                                               | Check it drives                             |
|-----------------------|-----------------------------------------------------------------------------|---------------------------------------------|
| `no-format-line`      | the `**Format:**` line is missing                                           | validate reports a pre-format-2 file        |
| `format-1`            | `**Format:** 1` instead of 2                                                | validate names the other format number      |
| `duplicate-wk01`      | WK03 is renamed WK01, so the id appears twice                               | validate reports the duplicate's first line |
| `needs-names-nothing` | WK03 has `needs: WK77`, which no step defines                               | validate reports the unknown dependency     |
| `frozen-placeholder`  | WK01 has `frozen: TBD`                                                      | validate reports the placeholder value      |
| `files-on-tests-step` | WK02, a tests step, carries a `files:` list                                 | validate reports the line the kind refuses  |
| `unanswered-oq01`     | OQ01's `A:` line is empty                                                   | validate reports the open question          |
| `missing-log`         | `mod/orphan.md` is a sound steps file with no `mod/orphan-log.md` beside it | validate reports the missing log's path     |
| `unclosed-fence`      | a ``` line opens before `## Open Questions` and never closes                | status refuses the file and says why        |
