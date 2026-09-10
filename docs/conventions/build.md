# [Conventions](../conventions.md) > Build

The exact commands that check the plugin and run its tests. Every command runs from the repository root, in
Git Bash on Windows or any POSIX shell elsewhere.

## Commands

- Compile / type-check: `bash -n plugin/scripts/<name>/<name>.sh` parses one script; `claude plugin validate
  plugin` checks the plugin's manifest and structure. There is no compiler.
- Run a single test class: `bash tests/run.sh <name>`, one case file; several names run several.
- Run the full test suite: `bash tests/run.sh`.
- Run the architecture-enforcement check: none — the dependency rule is reviewed by hand.
- Format: none — no formatter is configured.
- Contract codegen: n/a.
- Coverage guardrail: none.
- Before a commit: nothing. `docs/developing.md`, Releasing, is the list that runs before a tag.

## Reading a Run

`tests/run.sh` prints `== <name>` per case file, then one line per check, `ok` or `FAIL`. A `FAIL` shows the
expected value beside the actual one, or the first lines of a `diff` for a golden file. Each case file ends
with `<name>: <n> ok, <m> failed`, and the run ends with `all case files passed` or `<k> case file(s) failed`
and a non-zero exit. The per-check lines are the detail; there is no log file to open.

## Module Facts

- The scripts under test are addressed as `$R/scripts/<name>/<name>.sh` inside a case file; `$R` is `plugin/`.
- A case file needs `jq` on `PATH`, as the hooks do; without it the hooks are silent and their checks fail.

## Dependencies

- Manifest: none. The plugin declares no library. The tools it needs at run time are listed in `README.md`,
  Requirements, and `plugin/.claude-plugin/plugin.json` carries only the plugin's own version.
- Lock file: none.
- Outdated versions: none — there is nothing to list.
- Vulnerabilities: none — no scanner, nothing to scan.
- Routine upgrades: n/a.
- Pinned on purpose: `plugin/scripts/cost/pricing.json`, the offline rates table. It is data, refreshed by
  `bash plugin/scripts/cost/cost.sh refresh-pricing` before a release, and committed when it changed.
- Custom flow: none.

## Docker / Local Runtime

Nothing. The tools on `PATH` in [Orientation](orientation.md), Tech Stack, are the whole environment.
