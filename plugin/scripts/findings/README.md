# The findings writer

`findings.sh` is the deterministic writer and validator for a run's `review/findings.md`. It keeps the five
sections in their prescribed order, assigns `RX`, `DX`, and `PX` identifiers, renders disabled-test evidence,
escapes table pipes, and recomputes the opening counts after every change.

## Usage

Run it with bash from inside the project. A task directory resolves to its `review/findings.md`; a direct path to
the file works too.

Use `init` when the file is absent. On a resume, run `check` before the next mutation. Use only the mutation
commands below. Run `check` before updating the backlog, writing the report, or archiving. Correct rejected input
and retry the command.

```text
findings.sh init docs/12-add-widget --title "Add a widget"
findings.sh add-bug docs/12-add-widget --module api --summary "an empty name is accepted" \
  --given "a create request with an empty name" --when "the request is submitted" \
  --then "validation rejects it" --actual "a widget is created" \
  --test "CreateWidgetTest#rejectsEmptyName" --fix "validate the command" \
  --target "src/CreateWidget.java"
findings.sh add-refactoring docs/12-add-widget --module api --what "share name validation" \
  --why "all four commands repeat the same checks"
findings.sh close docs/12-add-widget RX01 --status done --reason "task 14"
findings.sh close-bug docs/12-add-widget --test "CreateWidgetTest#rejectsEmptyName" \
  --status withdrawn --reason "the production runner accepts whitespace by contract"
findings.sh close-critical docs/12-add-widget --module api --summary "validation is copied" \
  --status done --reason "rework 3"
findings.sh check docs/12-add-widget
```

The mutation commands are `add-bug`, `add-critical`, `add-refactoring`, `add-deferred`, `add-performance`,
`close`, `close-bug`, and `close-critical`. `add-critical --kind bug` requires `--test`; the other critical kinds
reject one. `add-bug` and a critical bug accept only `TestClass#method`. The class must occur in the basename or
text of a tracked or untracked non-ignored file outside `docs/`. The
writer adds the Markdown suffix `, disabled` itself. `close` accepts `done`, `withdrawn`, and `wontfix`;
the two block-closing commands accept `done` and `withdrawn`. `--reason directly` renders `done · directly`.

Every mutation first runs the same structural checks exposed by `check`. It writes a sibling temporary file,
checks the complete candidate, and replaces the original only after that succeeds. A rejected argument, malformed
existing file, missing test class, or interrupted render leaves the original untouched.

The opening line is canonical and counts only open entries, in section order. With none it is
`**Nothing open.**`; otherwise it reads, for example,
`**1 bug, 2 refactoring candidates, 1 deferred change open.**`. Closed entries remain in their sections.

## What `check` checks

`check` applies equally to script-written files and files written by hand after the script was refused or absent.
It checks the title, opening count, section names and order, the distinct schemas for Bug and Critical blocks,
field order, unique close-command keys, disabled-test syntax, open defects' test classes, table widths, sequential
IDs, and status grammar. A closed historical defect stays valid if a later refactor removes its old test class.

## Portability and refusal

The script uses Bash, POSIX `awk`, `sed`, `grep`, and Git. In an installed plugin it is typically invoked as:

```text
bash "${CLAUDE_PLUGIN_ROOT}/scripts/findings/findings.sh" check docs/12-add-widget
```

Permission settings may allow the script directly or that `bash` invocation. If the script is refused or absent,
follow the plugin-wide fallback in [`scripts/README.md`](../README.md). The script never retries or weakens a
rejected operation.
