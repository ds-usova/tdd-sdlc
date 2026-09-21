# design fixtures

`good/` is one settled task as `design-task` writes it: `docs/1-add-widget/` holds `spec.md`,
`design.md` and `design-log.md` with two decided entries, every RQ proved and every grill-design
concern rowed.

Each directory under `bad/` holds only the files that differ from `good/`, at the same paths.
A case copies `good/`, overlays one variant and runs the subcommand it drives.

| Directory                | What is wrong                                                                 | Drives                                        |
|--------------------------|-------------------------------------------------------------------------------|-----------------------------------------------|
| `open-dn07`              | DN07 is must-decide with an empty Answer                                      | `settled` exits 1; `status` counts it         |
| `must-decide-with-answer`| DN07 is must-decide yet carries an Answer                                     | `validate`: must-decide carrying an Answer    |
| `no-format-line`         | spec.md has no `**Format:**` line                                             | `validate`: written before format 2           |
| `format-1`               | spec.md says `**Format:** 1`                                                  | `validate`: a foreign format number           |
| `duplicate-ids`          | RQ01, AC01 and DN01 are each defined twice                                    | `validate`: defined twice                     |
| `placeholders`           | RQ02 is TBD, DN01 is decided with nothing after it, DF02 has an empty cell, Recovery has no why | `validate`: placeholder checks |
| `design-gaps` | extra design section and missing required facts | `validate`: design and log checks |
| `second-task-in-flight`  | a second task, `docs/9-second/`, with its own spec.md                         | no task given with two in flight exits 2      |
