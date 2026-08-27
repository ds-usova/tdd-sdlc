# The Fix Reader

`fix.sh` reads and updates a bug fix's checklist by step ID — what is done, what one step says, what is being
tried right now, marking a step done or blocked, whether the file's and its log's grammar holds, whether every
module's fix is complete, and what the attempt logs add up to.

## Why it exists

A fix's step format is decided by its kind. Each of the three owes some labelled lines and may not carry others:
a `red` step owes `reproduces:` and may not name a production file, a `green` step owes `fixes:` and may not name
a test file at all. Every one of those mistakes is silent: a `green` step that quietly edits the test it is
proven by turns the whole verification model into a formality.

It also reads the log beside each file — its `## Attempts`, where the same silence costs more: an attempt written
without the output that killed it is a rumour the next session has to reproduce — and its `## Run Log`, where an
entry inserted above an older one rewrites the order things happened in.

The log's `**In flight:**` line is maintained rather than checked, for the same reason: it is what a stopped run
leaves behind, and it goes stale exactly when nobody is watching — when a step lands. `start` and `tick` write
it, so it never depends on somebody remembering. `block` writes the Run Log's next entry for the same reason:
the number comes from the log, not from a count somebody kept.

The second reason is addressing. A step handed to a sub-agent has to arrive as the file wrote it, not as a prompt
remembered it. `show` is what makes that possible.

There is no scheduling command. A fix runs every `stabilize` step, then every `red` one, then every `green` one,
in every fix — so there is nothing for a `next` to compute.

## Where it lives

It ships **with the skill that uses it**, at `scripts/fix/` under the plugin root — `${CLAUDE_PLUGIN_ROOT}` once
installed, `.claude/` in a plain checkout. `fix-parse.awk` sits beside it and is found relative to the script, so
the pair travels together.

The **fix file** is found the other way round, from `git rev-parse --show-toplevel` (falling back to the working
directory), since once installed the script runs from a cache directory outside any checkout.

## Usage

Run it with bash, from anywhere inside the project:

```
<plugin>/scripts/fix/fix.sh status
<plugin>/scripts/fix/fix.sh show R01
<plugin>/scripts/fix/fix.sh start G01 guarding on the persisted request id
<plugin>/scripts/fix/fix.sh tick S01 R01
<plugin>/scripts/fix/fix.sh block G01 "the symptom survives a correct fix - a second cause"
<plugin>/scripts/fix/fix.sh validate --file docs/7-double-charge/bug.md
<plugin>/scripts/fix/fix.sh task docs/7-double-charge/
<plugin>/scripts/fix/fix.sh attempts docs/7-double-charge/
```

| Command             | Effect                                                                                                |
|---------------------|-------------------------------------------------------------------------------------------------------|
| `status`            | Done/total, the IDs still open, and the IDs abandoned.                                                |
| `show <ID>...`      | One step: its header and everything indented under it. Several print blank-line separated.            |
| `start <ID> <text>` | Write the log's `**In flight:**` — the step and, in a clause, the approach being tried.               |
| `tick <ID>...`      | Mark the steps done, empty the log's `**In flight:**`; an already-ticked ID is reported, not ticked.  |
| `block <ID> <note>` | Leave the step open; record the note as the next `B` entry of the log's **Run Log**.                  |
| `validate`          | See [What `validate` checks](#what-validate-checks).                                                  |
| `task`              | Every fix file the bug directory holds, its done/total, and whether all of them are done.             |
| `attempts`          | The attempt IDs every log of the bug holds, as one line.                                              |

Exit codes: **0** done, **1** no such step, `validate` found problems, or `task` found something open, **2** bad
usage — a log missing where `start`, `tick` or `block` would write it included.

`--file <fix>` names the file, on every subcommand, and a bare path does the same: `status docs/7-x/fix.md`
answers for that file. `validate` accepts a bug directory, which validates `bug.md`, every `fix.md` under it and
the log beside each in one call, and `task` and `attempts` accept a bug directory or any fix inside one.
`block`'s note is one quoted argument and may contain anything, a slash or `.md` included; a note given as
several words is refused rather than cut down to its first. `--log` takes one file, never a directory, and is
refused beside a bug directory, whose every file is validated with its own log.

**Every file has a log beside it under its own stem** — `bug-log.md` beside `bug.md`, `fix-log.md` beside each
`fix.md` — holding its **Attempts**, its **Run Log** and, for a fix, the `**In flight:**` line; `--log` names
another. `validate` reads both, and `start`, `tick` and `block` write to the log. The file stays what a step
agent reads; the log is what happened to it. Log files are never enumerated as files of their own: a directory
`validate` finds them through the file each sits beside.

**`attempts` prints `bug-log.md · A1–A3, module-a/fix-log.md · A1, module-b/fix-log.md · —`** — a range where a
log's numbers run without a gap, the list where they do not, an em dash where a log holds none.

A run-log entry is `- **B<n> (<ID>):** <what happened>`, numbered from 1 in the order it was written and never
renumbered; `block` writes one with an empty `- Resolved:` line beneath it, and whoever settles the blocker fills
that line. An entry recording a fact nobody has to act on — a boundary a step widened, a migration a revert left
run — carries no `Resolved:` line; whoever writes one creates the `## Run Log` heading after **Attempts** where
it is absent, as `block` does. The heading is matched exactly as `## Run Log`, by the parser and by `block`
alike. The parenthesis names the step the entry is about, and `validate` checks the file defines it; beside a
`bug.md`, which holds no steps, it names `diagnosis` or a module instead.

**`start` refuses a log with no `**In flight:**` line**, on the same principle: it maintains a line the format
declares, and never invents one. Without `--file`, the single `fix.md` in flight under `docs/` is used. A
`bug.md` is always named explicitly — `validate` reads it and its log — and so is an archived file under
`docs/implemented/`, or one of two fixes in flight at once.

**`tick`, `start` and `block` write, so they refuse anything but a `fix.md`, and refuse one with no log beside
it.** The kinds cannot tell the formats apart — a rework's steps have kinds of their own and one of them is also
called `stabilize` — so only the name does. The reading commands say so and answer anyway. `status` also refuses
a file that defines no steps at all. `tick` resolves every ID before it writes any, so a typo ticks nothing; a
step already ticked is reported as `already ticked: <ID>` and its line is not touched.

**A step whose header carries `abandoned — <why>` is closed, not open.** The marker is the word and the em dash
together, so a step whose text merely mentions abandoning something stays open. `status` lists it apart from the
open ones, and `task` counts a fix complete whose every step is ticked or abandoned.

### Step IDs

A step is `- [ ] <ID> · <kind> · <text>`, the ID being a letter prefix and a number — `S01` for `stabilize`, `R01`
for `red`, `G01` for `green`. The kinds and the numbering rule belong to the fix format, defined by the `fix-bug`
skill this ships with.

`files:` and `test-files:` carry their paths as bullets under the label rather than as text beside it, and
`evidence:` carries a fenced block under it, so those label lines are empty by design. Every other label keeps its
value on its own line.

### What `validate` checks

| Check                                                                        | Catches                                                                 |
|------------------------------------------------------------------------------|-------------------------------------------------------------------------|
| Duplicate IDs, a step with no ID                                             | a step nothing can address                                              |
| A kind the format does not define                                            | a typo that silently exempts the step from every rule                   |
| An ID whose prefix contradicts its kind                                      | a `red` step numbered `G02`, which every report then misreads           |
| A labelled line the kind does not take                                       | `test-files:` on a `green` step, which is the one thing it may not edit |
| A labelled line the kind owes and does not carry                             | a `red` step with no `reproduces:`, a failure nobody named              |
| A `stabilize` step naming neither `files:` nor `test-files:`                 | a step that stabilizes nothing                                          |
| A value left empty, `TBD`, `—`, or still in `<angle brackets>`               | a step agent given no instruction                                       |
| A `files:` or `test-files:` with no bullet under it                          | a boundary that names nothing                                           |
| A `files:`, `test-files:` or `evidence:` carrying its value beside the label | a boundary a reader has to scan for commas                              |
| The same labelled line written twice on one step                             | a half-finished edit, where the second silently wins                    |
| `needs:` or `fixes:` naming a step nothing defines                           | a green step paired with a reproduction that was dropped                |
| `disables:` naming no step at all                                            | a test turned off with nothing owing its return                         |
| `fixes:` naming no step at all                                               | a green step whose pairing was never written                            |
| A `fixes:` naming itself, or naming a step that is not a `red` one           | a pairing that proves nothing                                           |
| A `red` step no `green` step fixes, unless it is `abandoned — <why>`         | a reproduction that would be committed and left failing                 |
| No log beside the file                                                       | a fix nothing can record against                                        |
| An `## Attempts` or `## Run Log` section, an `A` or `B` entry, in the file   | the old shape — the log owns those now                                  |
| A duplicate attempt number                                                   | two entries the log cannot tell apart                                   |
| An attempt outside the log's `## Attempts` section                           | a log written where nothing reads it                                    |
| An attempt missing `why:`, `result:`, `evidence:` or `ruled-out:`            | a failure recorded without what it settles                              |
| An `evidence:` with no fenced block directly under it                        | an attempt whose output nobody kept                                     |
| An attempt filed under neither `diagnosis` nor a step the file defines       | a log entry attached to a step that was renumbered                      |
| A `B` entry outside the log's `## Run Log`                                   | a record `block` cannot number after                                    |
| A `B` entry numbered below the entry above it                                | a record inserted where it did not happen                               |
| A `B` entry naming no step, or a step the file does not define               | a record nothing can be traced back from                                |
| A fenced block that never closes, in either file                             | pasted output whose own fence swallowed the rest of the file            |
| An Open Question whose `- A:` is empty                                       | a run about to start on a decision nobody made                          |

A clean file prints its step, attempt and run-log entry counts — `fix.md: 4 steps, 1 attempt, 2 run-log
entries, no problems` — so "no problems" and "not a fix file" never look the same. A
`fix.md` with no steps is reported; a log with no attempts is a run that failed at nothing, and `bug.md` holds
no steps by design.

**`status`, `show`, `start`, `tick` and `block` refuse a file or log whose fenced block never closed**, since
everything below it went unread and half a file answers as confidently as a whole one. `validate` reports it and
carries on, because reporting is what `validate` is for.

**A duplicate ID's own block is not judged.** The second `R01` is reported and its lines are skipped. A file
carrying a duplicate ID or an unrecognized kind is also spared the pairing check. Fix those and run again.

Bullets inside fenced code blocks are skipped, so a fix quoting the step format does not acquire phantom steps
from the example. **What closes a fence is the same character at exactly the opening length**, as in Markdown
itself: an attempt's evidence is a fence inside a fence, and a document quoting this format nests one example
inside another.

## Where it stops

It parses the files' **shape**, not their meaning. It cannot tell whether a `red` step's test actually reaches
the bug, whether `reproduces:` describes the symptom the user reported, whether an attempt's evidence is the run
it claims to be, or whether a `Resolved:` line holds anything true. Those are the questions phase 2's approval
and the step's own red run exist to answer.

## Portability

It runs on macOS, Linux and Windows. What that costs:

- **`bash`, `awk`, `sed`, `git`, `find`, `grep`** — nothing else, and no GNU-only spellings. The parser runs on
  `mawk`, BSD `awk` and `gawk` alike. Its one departure from POSIX is the `\x` escape it spells the middot
  with, which `gawk --posix` rejects.
- **Edits go through a sibling temp file, not `sed -i`**, whose argument differs between GNU and BSD.
- **Windows** needs a **Git Bash** prompt, which supplies all of the above.
- `*.sh` and `*.awk` must be pinned to LF in `.gitattributes` — a CRLF checkout fails on the first line — and
  `fix.sh` must be committed with mode `755`, or a Unix clone cannot run it. `bash fix.sh …` works either way.

Whoever installs this has to allow the script in their own permission settings, since permissions are the
consumer's and not the plugin's. A prefix rule is matched as a literal string, so a quoted path matches no rule
written bare:

| Install        | Allow rule                                 |
|----------------|--------------------------------------------|
| plain checkout | `Bash(bash .claude/scripts/fix/fix.sh:*)`  |
| plugin         | `Bash(bash <root>/scripts/fix/fix.sh:*)`   |
| plugin, quoted | `Bash(bash "<root>/scripts/fix/fix.sh":*)` |

`<root>` is the directory the plugin was installed to, written out in full. Allow the quoted spelling as well as
the bare one, or an agent that quotes an absolute path is refused by a rule that appears to cover it. Drop the
`bash ` prefix for a rule covering the script invoked directly.
