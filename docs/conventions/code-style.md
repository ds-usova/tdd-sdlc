# [Conventions](../conventions.md) > Code Style

How scripts and shipped prose are written, and what a cleanup pass may touch.

## Scripts and Hooks

- Shell: `#!/usr/bin/env bash` and `set -u`, never `-e`. POSIX awk for parsing and rendering, in files beside
  the script, found relative to it.
- Locating things: the plugin by `dirname "${BASH_SOURCE[0]}"`; the repository by `git rev-parse
  --show-toplevel`, falling back to the working directory. Nothing is derived from where the script was installed.
- Windows: a path read from a hook's input or a mapping file has its backslashes turned to slashes before it is
  compared; a line read from a transcript or a file is stripped of `\r`.
- Exit codes: 0 done; 1 nothing matched, `validate` found problems, or a gate found something open; 2 a usage
  error. A `die` prints to stderr and exits 2 unless given another code. `validate` reports every problem it
  finds, naming file and line, before it exits.
- Hooks: exit 0 silently when `jq` is absent or the command is not the hook's business; a refusal is one JSON
  line with `permissionDecision: "deny"` and a reason that says what to do instead.
- Comments: a header comment says what the file is for; a comment inside says why a branch exists, never what
  the line does.
- Null handling: an absent field reads as empty and is tested with `[ -n ]`; a script never prints a bare
  `null`.
- Logging: none. A script prints its result to stdout and its complaint to stderr.
- Stub marker: `stub-intent:`.

## Shipped Prose

Skills, agents and templates are instructions, written by the rules in
`.claude/skills/editing-the-framework/SKILL.md`: what to write, what not to, how, and the checklist before a
change is reported. Lines wrap at 120 characters there and in every prose file of this repository.

## Reference Pages

`docs/*.md` and each script's `README.md` are for a person: labelled lists, one-line bullets, a table where a
rule has conditions and outcomes, and a link wherever a fact already has a home.

## Refactoring Conventions

- Priorities: a rule stated twice, in two files or a file and a prompt; a sentence that explains where it
  should instruct; a shell idiom that differs between two scripts doing the same thing.
- Extraction targets: a rule more than one skill reads goes to `plugin/templates/`; a shell helper more than one
  script needs stays duplicated in each.
- Shared helpers that may be extended: `tests/lib.sh`.
- Leave-alone list: `plugin/scripts/cost/pricing.json` (refreshed as [Build](build.md), Dependencies, says;
  never edited);
  `docs/diagrams/*.svg` (rendered, never edited); the `**Format:**` number a file carries and the id prefixes in
  `plugin/scripts/README.md`, which move only with a format change.
- Thresholds: a rule found in two places is consolidated at once; a shell idiom is aligned when the script it is
  in is already being changed.
