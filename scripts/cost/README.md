# The Cost Reporter

`cost.sh` turns a task's `review/cost.jsonl` into its `review/cost.md`. It stores nothing of its own and
recomputes the report every time. Everything about the lines and the report is
[`docs/cost-recording.md`](../../docs/cost-recording.md).

## Where it lives

It ships **with the skills that use it**, at `scripts/cost/` under the plugin root — `${CLAUDE_PLUGIN_ROOT}` once
installed, `.claude/` in a plain checkout. `cost-render.awk` sits beside it and is found relative to the script,
so the pair travels together.

The **task** is found the other way round, from `git rev-parse --show-toplevel` (falling back to the working
directory).

## Usage

Run it with bash, from anywhere inside the project:

```
<plugin>/scripts/cost/cost.sh report docs/7-add-widget
<plugin>/scripts/cost/cost.sh report docs/7-add-widget --puml
<plugin>/scripts/cost/cost.sh report
```

| Command           | Effect                                                                              |
|-------------------|-------------------------------------------------------------------------------------|
| `report [<path>]` | Read `review/cost.jsonl` and write `review/cost.md` beside it.                      |
| `report … --puml` | Also write `review/cost.puml`, one `@startgantt` block per timeline, for rendering. |

Exit codes: **0** done, **1** no cost lines to report on, **2** bad usage. `--help` or `-h` prints the usage.

**The task is named as a directory, as its `review/cost.jsonl`, or not at all** when one task under `docs/`
carries a `cost.jsonl`. An archived task under `docs/implemented/` is named explicitly. The ambiguity is
reported, never guessed.

## Portability

Everything the plan reader's **Portability** section says applies here, and the allow rule is the same shape:

| Install        | Allow rule                                   |
|----------------|----------------------------------------------|
| plain checkout | `Bash(bash .claude/scripts/cost/cost.sh:*)`  |
| plugin         | `Bash(bash <root>/scripts/cost/cost.sh:*)`   |
| plugin, quoted | `Bash(bash "<root>/scripts/cost/cost.sh":*)` |

`report` needs `jq`, and exits 1 saying so without it. Times are **UTC**: every stamp the host writes carries
`Z`, and the report does no zone conversion.

## Where it stops

It reads the lines' **shape**, not their meaning. A line the hooks never wrote is a run that went unrecorded,
and the report cannot tell that from a cheap one. A session whose mapping file is gone gets `unavailable` for
its own turns and no session row in the timeline.
