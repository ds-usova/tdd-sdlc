# [Conventions](../conventions.md) > Testing Conventions

What each test type targets, and how a test in this repository is written.

## Test Types

- **Unit-test targets:** none. An awk file under `plugin/scripts/<name>/` is tested only through the script
  that runs it.
- **Integration-test targets, against infrastructure:** every script under `plugin/scripts/<name>/` and every
  hook under `plugin/scripts/hooks/`, each run by its command line against a real git repository built under a
  temporary directory. The real dependency is the file system and `git`; for `cost.sh`, also a `curl` on
  `PATH`, replaced by a fake.
- **Integration-test targets, against the framework:** none — the plugin has no framework entry points.
- **System-test entry points:** none yet. A skill's prose is verified by reading; an end-to-end eval of a
  skill on a scratch repository is not in the tree.

## Test Tooling

- Test framework: `tests/run.sh` and `tests/lib.sh`, this repository's own. No external framework.
- Container-based dependencies: none.
- HTTP stubbing for outbound calls: a fake `curl` script placed first on `PATH`, as `tests/cases/cost.sh` does.
- API-level test client: a script is invoked as `bash "$R/scripts/<name>/<name>.sh" <command>`; a hook is fed
  its JSON on stdin with `printf ... | bash "$R/scripts/hooks/<hook>.sh"`.
- Inbound-adapter slice testing: none.
- Firing non-HTTP entry points: none.
- Disabling a test: never — a failing check is fixed or deleted.

## Naming Conventions

- Case file naming: `tests/cases/<name>.sh`, one per script directory, plus `hooks.sh`. A new script gets a new
  case file of the same name.
- Check naming: the first argument of every `check*` call is a sentence in lower case stating what holds, so a
  failure reads as the rule broken — `"a batch with an unknown id ticks nothing"`.
- Test base: `tests/lib.sh`, sourced at the top of every case file. It provides `check`, `check_match`,
  `check_no_match`, `check_ok`, `check_fails`, `check_golden`, a temporary `$WORK` removed on exit, `fixture`
  to copy a committed fixture into it, `overlay` to lay a variant over that copy, `repo` to make a directory a
  git repository, and `finish`, which every case file ends with.
- Shared builders: none beyond `lib.sh`. Every file a case reads is a committed fixture; a case file never
  builds one. An edit a case makes to its copy is the behaviour under test, or the input a hook is fed.

## Testing Style

- Parameterized tests: a `for` loop over command shapes where the same check applies to each, as the mapper
  and commit-hook cases do.
- Assertion style: only the `check*` helpers of `lib.sh`; never a bare `[ ... ] || exit 1`.
- Golden files: `check_golden` against a committed file under `tests/fixtures/<name>/`, with the values that
  carry the run's own date or clock replaced by a placeholder first. `UPDATE_GOLDEN=1 bash tests/run.sh <name>`
  rewrites it after a deliberate change to the output's shape.
- Fixtures:
  - `tests/fixtures/<name>/good/` is the complete correct repository the case runs against;
  - `bad/<what-is-wrong>/` holds only the files that differ from it, at the same paths, one directory per refusal;
  - a further directory holds an overlay of another kind, named for what it does — `hooks/clean/` removes the
    stub marker;
  - inputs that are not a repository sit beside them, named for what they are — `cost/agents/`, `cost/records/`,
    `cost/fakebin/`;
  - `README.md` beside them says what each directory and variant is for.
  - A case copies `good/` under `$WORK`, overlays a variant, and never writes into the tree.
  - Inputs that are not files — a command shape fed to a hook — stay in the case file.
- One case file exercises every subcommand its script has: the happy path, and every refusal `validate` makes.
  The exception is `cost.sh refresh-pricing`, a release step that rewrites a shipped file.
- Verification depth: a check compares the script's printed line or the file it wrote; it does not inspect the
  script's internals.
