# plan fixtures

`good/` is a complete repository for `plan.sh`: the worked example plan and log at `docs/1-add-widget/`, the spec
beside them, and the two source files the plan refers to. `src/WidgetUtilsTest.java` holds the method RU03's
update bullet names; `src/CreateWidgetUseCase.java` carries a `stub-intent:` marker. `spec.md` numbers `AC01`
to `AC06`; the plan's red steps name the first five, so `AC06` is the scenario `acceptance` reports as missing
until the case file adds a coverage note. `tests/cases/plan.sh` copies it, makes it a git repository and runs
every command inside it.

Each `bad/<what-is-wrong>/` holds only the files that differ from `good/`, at the same relative path. The case file
overlays one over a fresh copy of `good/` and points `plan.sh` at it with `--file`. `bad/` means "an overlay",
not "must fail": `pm-good` is a valid variant the case file expects to pass.

| Directory                     | What is wrong                                                        | Check it drives                        |
|-------------------------------|----------------------------------------------------------------------|----------------------------------------|
| `no-format-line`              | the `**Format:**` line is deleted                                    | validate refuses and names the line    |
| `format-1`                    | `**Format:** 1` instead of 2                                         | validate names the older format        |
| `duplicate-st01`              | a second `ST01` item appended                                        | validate reports the duplicate id      |
| `after-names-nothing`         | `GI02` says `after: GU99`, which no item defines                     | validate reports the dangling `after:` |
| `then-placeholder`            | a `then:` in RU01 left as the `—` placeholder                        | validate reports the empty `then:`     |
| `update-names-missing-method` | RU03's `update:` bullet names `whenNothing_thenNothing()`            | validate greps the tree and refuses    |
| `missing-log`                 | `plan.md` with no `plan-log.md` beside it (used alone, not overlaid) | validate reports the missing log       |
| `unclosed-fence`              | a code fence opened at the end and never closed                      | status refuses the plan                |
| `pm-good`                     | a `Performance` section with `PM01` and a `PM02 … rerun` first under Post-Implementation | validate passes; show carries `threshold:` |
| `pm-rerun-with-threshold`     | the rerun item also carries a `threshold:` line                      | validate reports it                    |
| `pm-bare`                     | `PM01` with neither `covers:` nor `scenarios:`                      | validate reports both                  |
| `pm-two-sections`             | a second `Performance` section under Red Phase, holding an `RS` item | validate reports the section and the item; the correct section passes |
| `pm-not-first`                | `Performance` after `Manual Request Files`                           | validate names the section's position  |
| `pm-misplaced`                | `PM01` under the system red phase, and no `threshold:`               | validate reports both                  |
| `pm-threshold-placeholder`    | `PM01`'s `threshold:` is `TBD`                                       | validate reports the empty threshold   |
| `two-plans-in-flight`         | a second plan at `docs/2-other/plan.md`                              | status without `--file` is refused     |
