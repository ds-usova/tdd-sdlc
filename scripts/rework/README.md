# The Rework Reader

`rework.sh` reads and updates a rework's checklist by step ID — what is done, what one step says,
marking a step done or blocked, and whether the file's grammar and its log's hold.

## Why it exists

A rework's step format is decided by its kind. Five kinds, and each owes some labelled lines and may not carry
others: an `extract` owes `frozen:` and `cover:`, a `tests` step owes `survives:` and may not name a production
file at all. Every one of those mistakes is silent — a stray `frozen:` on a `tests` step does nothing, and a
missing `proves:` turns a `pin` into a claim nobody checked.

The second reason is addressing. A step handed to a sub-agent has to arrive as the file wrote it, not as a
prompt remembered it. `show` is what makes that possible.

There is no scheduling command. Steps run in ID order, and `needs:` only says which earlier work a run depends
on, so there is nothing for a `next` to compute.

## Where it lives

It ships **with the skill that uses it**, at `scripts/rework/` under the plugin root —
`${CLAUDE_PLUGIN_ROOT}` once installed, `.claude/` in a plain checkout. `rework-parse.awk` sits beside it and is
found relative to the script, so the pair travels together.

The **rework file** is found the other way round, from `git rev-parse --show-toplevel` (falling back to the
working directory). Once installed, this script runs from a cache directory outside any checkout, so nothing
about the project can be derived from where the script is.

## Usage

Run it with bash, from anywhere inside the project:

```
<plugin>/scripts/rework/rework.sh status
<plugin>/scripts/rework/rework.sh show R03
<plugin>/scripts/rework/rework.sh tick R02 R04
<plugin>/scripts/rework/rework.sh validate
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

`--file <rework>` names the file, and is accepted on every subcommand, as is a path given positionally —
`status docs/7-x/module-a/steps.md`. Without one, the single `rework.md` in flight under `docs/` is used. A
multi-module rework's `<module>/steps.md`, an archived rework under `docs/implemented/`, and one of two reworks
in flight at once all have to be named explicitly. `validate` given the rework's directory validates `rework.md`
and every `steps.md` under it in one call, each with its log.

**Every file that holds steps has a log beside it**, named after the file's stem — `rework-log.md`,
`steps-log.md` — holding its **Run Log**; `--log` names another, takes one file, never a directory, and is
refused beside a directory, whose every file is validated with its own log. Every command reads both, so an
unclosed fence in either refuses the call; `validate` reports on both, and `block` writes to the log. The steps
file stays what a step agent reads; the log is what happened to it. `validate` ends with `<file>: N steps, K
run-log entries, no problems` when it finds nothing — `0 steps` included, since a multi-module `rework.md` holds
none by design.

A run-log entry is `- **B<n> (<ID>):** <what happened>` at the left margin, `<ID>` a step the steps file
defines, numbered from 1 per log in the order it was written and never renumbered; `block` writes one with an
empty `- Resolved:` line beneath it, and whoever settles the blocker fills that line. An entry recording a fact
nobody has to act on — a boundary a step widened, a mutation that did not bite — carries no `Resolved:` line;
whoever writes one creates the `## Run Log` heading where it is absent, as `block` does. The heading is
exactly `## Run Log`. `block`'s note is one argument — quote it — and may contain anything, a slash or `.md`
included.

A step whose header ends in `abandoned — <why>` keeps its open box; `status` counts it closed and lists it
apart from the open ones.

**A step in another file is named with that file** — `needs: shared/steps.md · R01`. `validate` skips that
form rather than resolving it, and holds every bare ID to the file it appears in.

### Step IDs

A step is `- [ ] <ID> · <kind> · <text>`, the ID being a letter prefix and a number — `R01`, `R02`. The kinds
and the numbering rule belong to the rework format, defined by the `rework` skill this ships with.

`files:` and `test-files:` carry their paths as bullets under the label rather than as text beside it, so their
label line is empty by design. Every other label keeps its value on its own line.

### What `validate` checks

| Check                                                            | Catches                                               |
|------------------------------------------------------------------|-------------------------------------------------------|
| Duplicate IDs, a step with no ID                                 | a step nothing can address                            |
| A kind the format does not define                                | a typo that silently exempts the step from every rule |
| A labelled line the kind does not take                           | `frozen:` on a `tests` step, which does nothing       |
| A labelled line the kind owes and does not carry                 | a `pin` with no `proves:` — a claim nobody checked    |
| A `pin` naming neither `files:` nor `test-files:`                | a check or setting that edits nothing                 |
| A value left empty, `TBD`, `—`, or still in `<angle brackets>`   | a step agent given no instruction                     |
| A `files:` or `test-files:` with no bullet under it              | a boundary that names nothing                         |
| A `survives:` with nothing after the middot                      | a scenario that never said what it was proven against |
| A bare `needs:` or `disables:` ID nothing in the file defines    | a reference to a step that was renumbered or dropped  |
| An Open Question whose `- A:` is empty                           | a run about to start on a decision nobody made        |
| A fenced block that never closes                                 | a file read as half of itself                         |
| No `<stem>-log.md` beside the file                               | a run with nowhere to record against                  |
| A `Run Log`, `Attempts`, `B` or `A` entry in the steps file      | the old shape — the log owns those                    |
| A `B` entry outside the log's `Run Log`                          | a record `block` cannot number after                  |
| A `B` entry numbered below the entry above it                    | a record inserted where it did not happen             |
| A `B` entry with no `(<ID>)`, or naming a step nothing defines   | a record about nothing in the steps file              |

**A duplicate ID's own block is not judged.** The second `R01` is reported and its lines are skipped, since
attributing them to an ID that already means something else would report the same step twice. Fix the ID and run
again.

Bullets inside fenced code blocks are skipped, so a rework quoting the step format does not acquire phantom
steps from the example. A fence closes only on the same marker at the same length, as in Markdown, so a block
quoting another block reads as one; one that never closes is reported by every command, since `status`, `show`
and `tick` would otherwise answer for half a file.

## Where it stops

It parses the file's **shape**, not its meaning. It cannot tell whether a `frozen:` test actually reaches the
body being moved, whether a `survives:` scenario is the one that matters, or whether the `measures:` number is
the right one. Those are the questions phase 2's approval and the step's own mutation exist to answer.

## Portability

It runs on macOS, Linux and Windows. What that costs:

- **`bash`, `awk`, `sed`, `git`, `find`, `grep`** — nothing else, and no GNU-only spellings. The parser is
  strict POSIX awk, so `mawk` and BSD `awk` serve as well as `gawk`.
- **Edits go through a sibling temp file, not `sed -i`**, whose argument differs between GNU and BSD.
- **Windows** needs a **Git Bash** prompt, which supplies all of the above.
- `*.sh` and `*.awk` must be pinned to LF in `.gitattributes` — a CRLF checkout fails on the first line — and
  `rework.sh` must be committed with mode `755`, or a Unix clone cannot run it. `bash rework.sh …` works either
  way.

Whoever installs this has to allow the script in their own permission settings, since permissions are the
consumer's and not the plugin's. A prefix rule is matched as a literal string, so a quoted path matches no rule
written bare:

| Install        | Allow rule                                       |
|----------------|--------------------------------------------------|
| plain checkout | `Bash(bash .claude/scripts/rework/rework.sh:*)`  |
| plugin         | `Bash(bash <root>/scripts/rework/rework.sh:*)`   |
| plugin, quoted | `Bash(bash "<root>/scripts/rework/rework.sh":*)` |

`<root>` is the directory the plugin was installed to, written out in full. Allow the quoted spelling as well as
the bare one, or an agent that quotes an absolute path is refused by a rule that appears to cover it. Drop the
`bash ` prefix for a rule covering the script invoked directly.
