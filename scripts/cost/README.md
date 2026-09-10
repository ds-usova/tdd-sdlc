# The Cost Reporter

`cost.sh` turns a task's `review/cost.jsonl` into its `review/cost.md`. It stores nothing of its own and
recomputes the report every time. Everything about the lines and the report is
[`docs/cost-recording.md`](../../docs/cost-recording.md).

## Where it lives

It ships **with the skills that use it**, at `scripts/cost/` under the plugin root — `${CLAUDE_PLUGIN_ROOT}` once
installed, `.claude/` in a plain checkout. `cost-render.awk`, `pricing.json` and `pricing-parse.awk` sit beside
it and are found relative to the script, so the four travel together. The fetched rates are cached per user at
`$XDG_CACHE_HOME/tdd-sdlc/pricing.json`, `~/.cache` by default; when and why is
[`docs/cost-recording.md`](../../docs/cost-recording.md), **Where the rates come from**.

The **task** is found the other way round, from `git rev-parse --show-toplevel` (falling back to the working
directory).

## Usage

Run it with bash, from anywhere inside the project:

```
<plugin>/scripts/cost/cost.sh report docs/7-add-widget
<plugin>/scripts/cost/cost.sh report
<plugin>/scripts/cost/cost.sh refresh-pricing
```

| Command           | Effect                                                                              |
|-------------------|-------------------------------------------------------------------------------------|
| `report [<path>]` | Read `review/cost.jsonl` and write `review/cost.md` beside it. Prints its path, then `Rates:`. |
| `refresh-pricing` | Rewrite `pricing.json` beside the script from the published rates. Prints the models it changed. |

Exit codes: **0** done, **1** no cost lines to report on or the fetch failed, **2** bad usage. `--help` or `-h`
prints the usage.

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

`report` needs `jq`, and exits 1 saying so without it. `cost.jsonl` stays **UTC**; `cost.md` renders clock
times in the offset the hooks recorded, as [`docs/cost-recording.md`](../../docs/cost-recording.md), **Times**,
says. The machine's own zone and `TZ` play no part.

## Where it stops

It reads the lines' **shape**, not their meaning. A line the hooks never wrote is a run that went unrecorded,
and the report cannot tell that from a cheap one. A session whose mapping file is gone gets `unavailable` for
its own turns and no session row in the timeline. A model in no rates table is rendered as
[`docs/cost-recording.md`](../../docs/cost-recording.md), **Prices**, says.
