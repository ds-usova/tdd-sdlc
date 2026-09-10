# Fixtures for tests/cases/upgrade.sh

`good/` is a project with one upgrade in flight: `docs/3-bump-libs/upgrade.md` with four steps, its
`upgrade-log.md` holding one attempt and one Run Log entry, and `module-a/steps.md` with one step beside a
`steps-log.md` that has no Run Log yet.

Each directory under `bad/` holds only the file that differs from `good/`, at the same relative path. The
case copies `good/`, overlays one variant, and runs `validate` on it.

| Directory | What is wrong, and the check it drives |
|-----------|----------------------------------------|
| `no-format-line` | `upgrade.md` has no `**Format:**` line; refused as "no **Format:** line" |
| `format-1` | `upgrade.md` says `**Format:** 1`; refused because the plugin reads format 2 |
| `duplicate-up01` | UP04 is renumbered UP01; the duplicate ID is reported with its first line |
| `needs-names-nothing` | UP03 `needs: UP77`, which no step defines |
| `guide-placeholder` | UP02's `guide:` is `TBD`, a placeholder left in |
| `change-without-place` | UP03's `change:` names no place after ` · ` |
| `change-on-bump` | UP02 is a bump step but carries a `change:` line beside its `guide:`; nothing else is wrong |
| `run-log-in-steps` | `upgrade.md` has a `## Run Log` heading, which belongs in the log |
| `unclosed-fence` | `upgrade-log.md` opens a fenced block at line 19 that never closes; `status` refuses too |
| `kept-back-without-unblock` | `upgrade-log.md` has RL02 marked kept back with no `Would unblock:` line |

The missing-log check has no directory: the case deletes `upgrade-log.md` from a copy of `good/`.
