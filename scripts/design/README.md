# The Design Reader

`design.sh` reads a task's spec and answers the question every stage after it asks: is this settled, or does
something still need deciding? Its `validate` reads all three of the task's files — the spec, the design, and the
design log.

## Why it exists

A spec exists to be *finished before the plan starts*. Its whole value is that the judgment calls — what happens
when the database is down, what a duplicate request does, what the migration does to existing rows — are answered
while they still cost a paragraph, instead of after twenty-five checklist items depend on them.

That only holds if "finished" is checkable. Left to a reading, a `must-decide` slips through, a decision arrives
with a basis but no answer, a requirement has no scenario behind it, or a concern is marked clear with nothing to
say why — and the cost lands later, wherever someone invents their own answer to the same question. `settled` is
the one-word verdict anything downstream can gate on, and `validate` is the shape check that keeps the format
worth gating on.

It stores nothing of its own and edits nothing: the files stay the single source of truth, and a decision is
answered by whoever makes it.

## Where it lives

It ships **with the skills that use it**, at `scripts/design/` under the plugin root — `${CLAUDE_PLUGIN_ROOT}` once
installed, `.claude/` in a plain checkout. `design-parse.awk` sits beside it and is found relative to the script, so
the pair travels together.

The **task** is found the other way round, from `git rev-parse --show-toplevel` (falling back to the working
directory). Once installed, this script runs from a cache directory outside any checkout, so nothing about the
project can be derived from where the script is.

## Usage

Run it with bash, from anywhere inside the project:

```
<plugin>/scripts/design/design.sh settled
<plugin>/scripts/design/design.sh validate docs/7-create-expense
<plugin>/scripts/design/design.sh show D4 D7
```

| Command        | Effect                                                                                  |
|----------------|-----------------------------------------------------------------------------------------|
| `settled`      | Exit 0 when nothing is still `must-decide`; exit 1 and list what is.                    |
| `status`       | How many decisions rest on each basis.                                                  |
| `show <ID>...` | One decision: its question, `Answer:` and `Basis:`. Several print blank-line separated. |
| `validate`     | See [What `validate` checks](#what-validate-checks).                                    |

Exit codes: **0** done, **1** no such entry, not settled, or `validate` found problems, **2** bad usage.

A task is addressed by its directory or by any one of its files — `spec.md`, `design.md`, `design-log.md` — and
the others are found beside it; `--file` is accepted for either. Without one, the single `docs/<n>-<task>/` in
flight is used. An archived task under `docs/implemented/` has to be named explicitly. `--spec`, `--design` and
`--log` override one file each.

### Decision entries

An entry in the spec is three lines — the question, the answer, and who chose:

```
- **D4:** What happens when the same widget is created twice concurrently?
  - Answer: One request wins with 200; the other returns the same 409 a sequential duplicate returns.
  - Basis: decided (user, 2026-07-30)
```

`D<n>` is assigned once and never renumbered. Only `decided` and `must-decide` are entries; the reasoning behind a
decided one is a **Decision Bases** line in the log, under the same number. The four bases and what each obliges
are defined in the `design-task` skill this ships with (`skills/design-task/SKILL.md`, **Decisions**); worked examples are at
`skills/design-task/example-spec.md`, `example-design.md` and `example-design-log.md` under the plugin root.

### What `validate` checks

The spec:

| Check                                                                  | Catches                                                                 |
|------------------------------------------------------------------------|-------------------------------------------------------------------------|
| Every required section, in order                                       | a spec a plan cannot be written from                                    |
| A `Requirements` line no scenario proves, a scenario proving no `R`    | a promise with no test behind it, behaviour nobody asked for            |
| Duplicate `D`, `R` or `A` IDs, an entry outside the Decisions section  | a decision nothing can address                                          |
| A missing or repeated `Answer:` / `Basis:`                             | an entry no gate can classify                                           |
| A basis that is not `decided` or `must-decide`, or with nothing after  | an assumption in the user's section — it belongs in the log             |
| A `must-decide` carrying an answer, or a `decided` carrying none       | an entry whose two halves disagree                                      |
| A `Design Findings` section or an `F` row outside the log              | the old shape — the log owns those now                                  |

The design:

| Check                                                                  | Catches                                                                 |
|------------------------------------------------------------------------|-------------------------------------------------------------------------|
| No `design.md` beside the spec                                         | a spec with nothing that says how                                       |
| The `**Affected Modules:**` line, and every required section, in order | a design missing the context the plan reads it for                      |
| A source file named under **Proposed Solution**, as a token or a link  | a plan-level fact in the design — it reads the same in any language     |

The log:

| Check                                                                  | Catches                                                                 |
|------------------------------------------------------------------------|-------------------------------------------------------------------------|
| No log beside the spec, or no `Grilled (<date>): <grill>` line         | a design the grill never saw                                            |
| A concern the named grill owns with no row, or a row with no why       | a concern nobody can tell was examined                                  |
| An `F` row numbered below the row above it, or with an empty cell      | a row inserted at the wrong line, or a claim with no evidence           |
| A `decided` entry with no **Decision Bases** line, or one for no entry | a decision whose reasoning was never written down                       |

A `must-decide` entry is **not** a problem here: a spec in flight is expected to have them, and that is exactly
what `settled` is for. `validate` asks whether the files are well-formed; `settled` asks whether the spec is
finished.

A clean run prints the task's size — requirements, scenarios, decisions, `####` sections under **Proposed
Solution**, concerns, findings. The counts are a mirror, not a gate: a task carrying more than one subject is
split into one task per subject (`design-task`, **One Subject per Task**), and the counts are what show the moment
to do it.

Placeholder values — empty, `-`, `—`, `TBD`, `N/A` — count as unfilled, the same set `plan.sh` rejects in a
`given:`/`when:`/`then:`.

### Portability

The constraints are `plan.sh`'s, for the same reasons: **`bash`, `awk`, `sed`, `git`, `find`** and nothing else, no
GNU-only spellings, strict POSIX awk (checked with `gawk --posix`), Git Bash on Windows, `*.sh` and `*.awk` pinned
to LF in `.gitattributes`, and `design.sh` committed with mode `755`. `bash design.sh …` works either way.

Whoever installs this has to allow the script in their own permission settings, since permissions are the
consumer's and not the plugin's. A prefix rule is matched as a literal string, so a quoted path matches no rule
written bare:

| Install        | Allow rule                                       |
|----------------|--------------------------------------------------|
| plain checkout | `Bash(bash .claude/scripts/design/design.sh:*)`  |
| plugin         | `Bash(bash <root>/scripts/design/design.sh:*)`   |
| plugin, quoted | `Bash(bash "<root>/scripts/design/design.sh":*)` |

`<root>` is the directory the plugin was installed to, written out in full. Allow the quoted spelling as well as
the bare one, or an agent that quotes an absolute path is refused by a rule that appears to cover it. Drop the
`bash ` prefix for a rule covering the script invoked directly.

## Where it stops

It parses the files' **shape**, not their meaning. It cannot tell whether a Findings row is true, whether the
evidence cited actually says what the row claims, whether a concern's why holds, or whether the decision is a good
one. A well-formed spec that is wrong about the codebase validates cleanly — that is what the grill pass and the
reader are for. The source-file check knows a fixed list of extensions; a framework class named bare is the
grill's **Stack-neutral** row to catch.

Bullets inside fenced code blocks are skipped, so a file quoting its own entry format does not acquire phantom
decisions from the example.
