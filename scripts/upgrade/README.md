# The Upgrade Reader

`upgrade.sh` reads and updates an upgrade's checklist by step ID — what is done, what one step says, marking a
step done or blocked, and whether the file's grammar and the log beside it hold.

## Why it exists

An upgrade's step format is decided by its kind. A `bump` owes `files:` and `guide:` and may carry no
`change:`; a `migrate` owes a `change:` per guide item, each naming where it lands. Every one of those mistakes
is silent — a `change:` on a `bump` is a source edit nobody approved, and a `migrate` with no `change:` is a
bump that will edit code by feel.

The second reason is addressing. A step handed to a sub-agent has to arrive as the file wrote it, not as a
prompt remembered it. `show` is what makes that possible.

The third is the log. An attempt without its evidence, or filed under a step nothing defines, is a rumour the
next session has to reproduce; a kept-back entry that does not say what would unblock it is a migration nobody
can finish. `validate` refuses both.

## Where it lives

It ships **with the skill that uses it**, at `scripts/upgrade/` under the plugin root —
`${CLAUDE_PLUGIN_ROOT}` once installed, `.claude/` in a plain checkout. `upgrade-parse.awk` sits beside it and is
found relative to the script, so the pair travels together.

The **upgrade file** is found the other way round, from `git rev-parse --show-toplevel` (falling back to the
working directory).

## Usage

Run it with bash, from anywhere inside the project:

```
<plugin>/scripts/upgrade/upgrade.sh status
<plugin>/scripts/upgrade/upgrade.sh show U03
<plugin>/scripts/upgrade/upgrade.sh tick U02 U04
<plugin>/scripts/upgrade/upgrade.sh validate
```

| Command             | Effect                                                                                     |
|---------------------|--------------------------------------------------------------------------------------------|
| `status`            | Done/total, the IDs still open, and the IDs abandoned.                                     |
| `show <ID>...`      | One step: its header and everything indented under it. Several print blank-line separated. |
| `tick <ID>...`      | Mark the steps done. Every ID is resolved before any is written; one already ticked is     |
|                     | reported as `already ticked: <ID>` and left as it is.                                      |
| `block <ID> <note>` | Leave the step open; record the note as the next `B` entry of the log's **Run Log**.       |
| `validate`          | See [What `validate` checks](#what-validate-checks).                                       |

Exit codes: **0** done, **1** no such step or `validate` found problems, **2** bad usage.

`--file <upgrade>` names the file, and is accepted on every subcommand. Without one, the single `upgrade.md` in
flight under `docs/` is used. A multi-module upgrade's `<module>/steps.md`, an archived upgrade under
`docs/implemented/`, and one of two upgrades in flight at once all have to be named explicitly. Every subcommand
also takes the path positionally, the same as `--file`; `validate` given the upgrade's directory validates
`upgrade.md` and every `steps.md` under it, each with its own log, in one call.

**Every steps file has a log beside it under its own stem** — `upgrade-log.md` beside `upgrade.md`,
`steps-log.md` beside `<module>/steps.md` and `shared/steps.md` — holding its **Attempts** and its **Run Log**;
`--log` names another, one file only. `validate` reads both, and `block` writes to the log. The steps file stays
what an agent reads; the log is what happened to it. Every command reads both files whole before answering: an
unclosed fenced block in either is refused with the line it opened at.

**A step in another file is named with that file** — `needs: shared/steps.md · U01`. `validate` skips that
form rather than resolving it, and holds every bare ID to the file it appears in.

### Step IDs

A step is `- [ ] <ID> · <kind> · <text>`, the ID being a letter prefix and a number — `U01`, `U02`. A step
whose header carries `abandoned — <why>` is closed, and reported apart from the open ones. The kinds and the
numbering rule belong to the upgrade format, defined by the `upgrade-deps` skill this ships with.

`files:` and `test-files:` carry their paths as bullets under the label rather than as text beside it, so their
label line is empty by design. Every other label keeps its value on its own line.

A run-log entry is `- **B<n> (<ID>):** <what happened>`, numbered from 1 in the order it was written and never
renumbered; `block` writes one with an empty `- Resolved:` line beneath it, and whoever settles the blocker
fills that line. An entry recording a fact nobody has to act on carries no `Resolved:` line. A kept-back change
is the entry `- **B<n> (<ID>):** kept back — <what the guide asked>` with `- Kept because:` and
`- Would unblock:` beneath it; `validate` refuses one missing either. The `## Run Log` heading is created at the
first entry, never empty: whoever writes an entry by hand adds it after **Attempts** where it is absent, as
`block` does. `block`'s note may contain anything, a slash, a middot or `.md` included, and is quoted as one
argument.

### What `validate` checks

| Check                                                                                    | Catches                                                 |
|------------------------------------------------------------------------------------------|---------------------------------------------------------|
| Duplicate IDs, a step with no ID                                                         | a step nothing can address                              |
| A kind the format does not define                                                        | a typo that silently exempts the step from every rule   |
| A labelled line the kind does not take                                                   | `change:` on a `bump` — a source edit nobody approved   |
| A labelled line the kind owes and does not carry                                         | a `migrate` with no `change:`, a step with no `guide:`  |
| A value left empty, `TBD`, `—`, or still in `<angle brackets>`                           | an agent given no instruction                           |
| A `files:` or `test-files:` with no bullet under it                                      | a boundary that names nothing                           |
| A `change:` with nothing after the middot                                                | a guide item that never said where it lands             |
| A bare `needs:` ID nothing in the file defines                                           | a reference to a step that was renumbered or dropped    |
| No `<stem>-log.md` beside the steps file                                                 | a file no run can record against                        |
| An `Attempts`, `Run Log` or `Kept back` heading, an `A` or a `B` entry in the steps file | the old shape — the log owns those now                  |
| An attempt missing `why:`, `result:`, `evidence:` or `ruled-out:`                        | a failure the next session has to reproduce             |
| An `evidence:` with no fenced block under it                                             | a failure described instead of pasted                   |
| An attempt filed under a step nothing defines                                            | a log entry that belongs to nothing                     |
| A `B` entry outside the log's `Run Log`, naming no step, or naming one nothing defines   | a record `block` cannot number after                    |
| A `B` entry numbered below the entry above it, or repeating it                           | a record inserted where it did not happen               |
| A `kept back` entry missing `Kept because:` or `Would unblock:`                          | a migration nobody can finish                           |
| A fenced block that never closes, in either file                                         | pasted output that swallowed the rest of the file       |
| An Open Question whose `- A:` is empty                                                   | a run about to start on a decision nobody made          |

Bullets inside fenced code blocks are skipped, so an upgrade quoting the step format does not acquire phantom
steps from the example, and evidence pasted under an attempt is never read as steps. A checkbox in the log is
a record, not a step.

## Where it stops

It parses the file's **shape**, not its meaning. It cannot tell whether a `guide:` is the right release's,
whether a `change:` is what the guide actually asks, or whether the version in the header is the newest. Those
are the questions phase 2's approval and the step's own suite run exist to answer.

## Portability

As `rework.sh`: **`bash`, `awk`, `sed`, `git`, `find`, `grep`**, no GNU-only spellings, strict POSIX awk, edits
through a sibling temp file. Windows needs a **Git Bash** prompt. `*.sh` and `*.awk` are pinned to LF in
`.gitattributes` and `upgrade.sh` is committed with mode `755`.

Whoever installs this has to allow the script in their own permission settings, since permissions are the
consumer's and not the plugin's. A prefix rule is matched as a literal string, so a quoted path matches no rule
written bare:

| Install        | Allow rule                                         |
|----------------|----------------------------------------------------|
| plain checkout | `Bash(bash .claude/scripts/upgrade/upgrade.sh:*)`  |
| plugin         | `Bash(bash <root>/scripts/upgrade/upgrade.sh:*)`   |
| plugin, quoted | `Bash(bash "<root>/scripts/upgrade/upgrade.sh":*)` |

`<root>` is the directory the plugin was installed to, written out in full. Allow the quoted spelling as well as
the bare one, or an agent that quotes an absolute path is refused by a rule that appears to cover it. Drop the
`bash ` prefix for a rule covering the script invoked directly.
