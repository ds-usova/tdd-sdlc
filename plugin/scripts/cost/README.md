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

`activity.html` is self-contained. Open it directly from disk. The header gives the work time, the implementation
time from the first stabilization, red, green or refactor agent to the last, the idle time, the agent and
wave counts and the agent cost. Hovering the time axis names the clock time under the pointer. The theme button
cycles system, light and dark; the browser keeps the choice where it can. A term with a dotted underline explains
itself on hover or focus; the template's `glossary` holds every explanation.

**Tabs** appear when the task ran more than one module. A module is the plan of a pipeline agent. The first tab is
the whole task. Each other tab is one module. It holds each pipeline agent on that plan and every agent below it,
at any depth. A stabilization, red, green or refactor agent outside every pipeline joins a module only when its own plan
is that module's. Every other agent belongs to no module; only the whole task shows it. A module is named by its
plan's directory under the task, `shared` for the seam's plan. Two modules with the same directory name are
named by their plan paths. A module tab recomputes the header, **Worth a look** and every section from its own
agents, on the whole run's time axis. On the whole task, an agent row names its module and a pipeline row is
named by it. The panel names an agent's plan. A task of one module shows no tabs and names no module.

**Worth a look** lists what these fixed rules find. A rule that finds nothing adds no line.

- The longest implementation phase and its longest agent. The ratio to the next agent is named when it is 2× or
  more.
- The agent of another phase that is 2× or more the next agent of its phase, the largest ratio only.
- The returns by phase, with their time and cost.
- Each escalation, with both models, the attempts, its time and cost.
- The retries by phase, with their time and cost.
- The orchestrators' own work inside the phases, when it is more than 20% of the implementation time.
- The repeated shell command with the largest total, when that total is more than five minutes.

A tie goes to the earlier start. Below the header are the sections that follow.

**Timeline** has one row per phase, in run order: main session, design, plan, pipeline agents, stabilization, red,
green, refactor, other agents. The agent type decides the phase. Open a phase to see its agents. Red and green open
into unit, integration and system first. A stabilization, red, green or refactor row draws its waves and the
orchestrator's own tool calls and model turns inside the phase. A wave is the agents one orchestrator launched in
one phase with at most 60 seconds between launches. Main session and pipeline rows draw only their own work;
delegation is left out.

**Returns to an earlier phase** lists every plan item a returning agent took, most returns first. A returning
agent is one launched after an agent of a later phase had started. A step agent is compared with the agents of its
own orchestrator. A design or plan agent is compared with every agent. An item's row gives its returns by phase and
the time and cost of the agents that took it; an agent with several items counts in each row. Open a row to see
its agents: first the phase agents of the main flow that took the item, marked `first run` and drawn in outline,
then the returns. Returns are left out of the phase rows and marked on the time axis. The returns and escalations
sections draw their own window, from the first implementation agent, first run or return to the end of the latest
return or escalation. They band that scale by official stage: at each moment, the latest implementation phase the
main flow has started, then `After the phases` once its last implementation agent has ended. The item names come
from the header lines of the work files the assignments name, read when the report runs; an archived task's work
file is looked for under its task directory.

**Escalations to another model** lists every agent that took over a step already attempted. The earlier attempt is
the latest agent of the same type and orchestrator with exactly the same assigned items that started before it. A
larger model than that attempt's is an escalation. Haiku, Sonnet and Opus rank in that order; an unknown family ranks
above them. The same or a smaller model is a retry, listed under **Worth a look** and noted on the agent's row. An
agent whose items only overlap an earlier agent's is new work, not a retry. Under each escalation are the earlier
attempts on the previous model. Escalations are marked on the time axis.

**Tool time** sums complete tool calls by tool, lists shell commands run more than once, and lists the longest
calls. Delegation and `AskUserQuestion` are left out.

Work is the time when a session turn, a tool call or an agent ran. Idle is the rest, first activity to last.
`AskUserQuestion` and a resume gap count as idle. Idle stretches longer than five minutes are cut to 45 seconds on
the scale and left out of every phase total. Select an agent row or a longest call to open its details in the
side panel. The panel shows the assignment, turns, peak context, active time, cost, the longest tool calls and at
most 1,000 launch-prompt characters. A relaunch's reason, recorded from its `Reason:` header line, shows on its row
and in the panel. A reason that names a run-log entry, `RL11`, links to the log beside the work file.

The data keeps five states. `model` is the interval from an input to its response, up to ten minutes. `tool` is a
paired tool call. `waiting` is a delegated call. `paused` is a resume gap or an input-to-response gap longer than
ten minutes, where active model work was not observed. `unknown` is an incomplete tool call. An agent line with no
activity draws as a hatched bar. The page never calls a model interval thinking; the transcript cannot separate
inference, generation and transport delay.

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
lane. A session whose mapping file is gone gets `unavailable` for its own turns and no activity lane. Pricing
and unknown-model handling follow [`cost-recording.md`](../../../docs/cost-recording.md#prices).
