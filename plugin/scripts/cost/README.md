# The Cost Reporter

`cost.sh` turns a task's `review/cost.jsonl` into `review/cost.md` and `review/activity.html`. It recomputes
both reports every time.

## Where it lives

It ships **with the skills that use it**, at `scripts/cost/` under the plugin root — `${CLAUDE_PLUGIN_ROOT}` once
installed, `.claude/` in a plain checkout. `cost-render.awk`, `pricing.json` and `pricing-parse.awk` sit beside
it and are found relative to the script, so the four travel together. The fetched rates are cached per user at
`$XDG_CACHE_HOME/tdd-sdlc/pricing.json`, `~/.cache` by default.

The **task** is found the other way round, from `git rev-parse --show-toplevel` (falling back to the working
directory).

## Usage

Run it with bash, from anywhere inside the project:

```
<plugin>/scripts/cost/cost.sh report docs/7-add-widget
<plugin>/scripts/cost/cost.sh report
<plugin>/scripts/cost/cost.sh refresh-pricing
```

| Command           | Effect                                                                                   |
|-------------------|------------------------------------------------------------------------------------------|
| `report [<path>]` | Write `review/cost.md` and `review/activity.html`. Print both paths, then `Rates:`.        |
| `refresh-pricing` | Rewrite `pricing.json` from the published rates. Print the models whose rows changed.     |

## Activity page

`activity.html` is self-contained. Open it directly from disk. It has one lane per session and agent, filters
for lanes, states, tools, workflow, assigned item and minimum duration, and zoom controls. Hover or select an
interval to read its tool, bounded input summary, timestamps and duration.

The assignments table joins a step-carrying implementation agent to the workflow, work file and item IDs that
the launch hook prepended to its prompt. It shows the assignment basis, plan-brief and prompt characters, peak
context, turns, active time and cost. **View** opens the exact launch header and at most 1,000 prompt characters.

The page uses four states: `model` for a model turn, `tool` for a paired tool call, `waiting` for a resume gap
or delegated call, and `unknown` for every uncovered or incomplete interval. It never calls a model interval
thinking. The transcript cannot separate inference, generation and transport delay.

The stop hook stores agent intervals in `cost.jsonl`. The report reads session intervals from the mapped
session transcript. Tool calls are paired by `tool_use.id` and `tool_result.tool_use_id` before their times are
clipped to the lane. A tool summary contains at most 500 characters of its command, path or description. Tool
results, full prompts, model text and thinking are never copied.

`activity-template.html` owns the page structure and behaviour. `activity-parse.jq` owns transcript parsing.
`cost.sh report` embeds the derived JSON in the template as base64. Agents never write HTML. The same records,
session mapping and template produce the same `activity.html` byte for byte.

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
times in the offset the hooks recorded. The machine's own zone and `TZ` play no part.

## Where it stops

It reads the lines' **shape**, not their meaning. A line the hooks never wrote is a run that went unrecorded,
and the report cannot tell that from a cheap one. A legacy agent line without activity appears as an unknown
lane. A session whose mapping file is gone gets `unavailable` for its own turns and no activity lane. A model
in no rates table is rendered unpriced, a dash where its dollars would be.
