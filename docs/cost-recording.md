# Recording what a run costs

Your conventions assign a model to each kind of agent the plugin spawns
([`templates/conventions/agent.md`](../templates/conventions/agent.md), **Sub-Agent Models**). This page says
what those choices cost. After every `implement-plan`, `fix-bug`, `rework` or `upgrade-deps` run, the task
directory holds `review/cost.md`: what each agent cost in tokens and time, and a timeline of when everything
ran. Nothing has to be switched on.

## Terms

- **Task directory**: `docs/<n>-<task>/`, where `<n>` is the task's number. Archiving moves the whole directory
  to `docs/implemented/` ([`README.md`](../README.md)).
- **Framework agent**: any sub-agent type shipped under `agents/`, such as `tdd-unit-red-phase-step` or
  `review-plan`. Which skill spawns which is [`agents.md`](agents.md).
- **Pipeline**: the `implement-plan-module` agent that runs one plan. A task with several modules has one plan
  and one pipeline per module, plus a `shared` plan that runs first ([`implement-plan.md`](implement-plan.md)).
- **Step**: an agent a pipeline spawns for one class or one test class. Steps run in **waves**, batches of
  steps in parallel.
- **Session**: the Claude Code session you typed the command into. The skill's own work happens there; agents
  are its sub-agents.
- **Transcript**: the JSON-lines file Claude Code writes per session and per sub-agent. The numbers on this
  page come from transcripts, never from anything an agent says about itself.

## The report

`review/cost.md` opens with one table per session that worked on the task:

```
| agent                   | n | tokens | time | model  | largest |
|-------------------------|---|--------|------|--------|---------|
| session (own turns)     | 1 | 2.1M   | 60m  |        |         |
| grill-design            | 1 | 3.3M   | 7m   | opus   | 3.3M    |
| review-plan             | 1 | 2.2M   | 6m   | opus   | 2.2M    |
| implement-plan-module   | 3 | 11.4M  | 29m  | opus   | 5.9M    |
| tdd-unit-red-phase-step | 5 | 3.1M   | 5m   | sonnet | 0.7M    |
```

- **session (own turns)** is the skill itself: the designer, the planner, the task level of `implement-plan`.
  They run in the session, not as sub-agents, so their cost is one row.
- **n** is how many agents of that type ran. **tokens** is their sum. **largest** is the biggest single one.
- **time** is the type's span from its first start to its last end. Times nest: a pipeline's minutes contain
  its steps' minutes. Tokens add up across rows; minutes never do.
- **tokens** count input, output, cache reads and cache writes together. A short agent with a large context
  can cost more than a long one with a small context. That is the number the bill is made of.

Below the tables come a per-plan split, a task total with one span from the first framework call to the
report, and the timelines.

### Reading a timeline

One overview for the task, then one timeline per plan. A row is an agent: its name, the clock time it
started and ended, a bar, its time and its tokens. Each column of the bar is a slice of the timeline's span; a
`█` is a column the agent was running in, a `·` one it was not. The axis above the bars carries clock times.
Columns are one minute wide where the span fits in forty columns, wider where it does not.

Agents of one type under one parent are grouped: a row `type ×3` carries the group's span and summed tokens,
and its members follow as `#1`, `#2`, `#3`. A wave reads as members sharing a start time. A waiting pipeline
reads as a long bar over short ones.

The example is a two-module task with a seam: design and plan in the same session, the shared plan first and
alone, then both module pipelines in parallel.

```
task 7-add-widget · overview
agent                                start  end    13:40     14:00     14:20       time  tokens
session (own turns)                  13:40  14:40  ██████████████████████████████   60m    2.1M
grill-design                         13:42  13:49  ·████·························    7m    3.3M
review-plan                          13:55  14:01  ·······████···················    6m    2.2M
implement-plan-module shared         14:05  14:09  ············███···············    4m    1.1M
implement-plan-module module-a       14:09  14:34  ··············█████████████···   25m    5.9M
implement-plan-module module-b       14:09  14:30  ··············███████████·····   21m    4.4M
```

```
module-a/plan.md
agent                                start  end   14:09     14:19     14:29  time  tokens
implement-plan-module                14:09  14:34  █████████████████████████   25m    5.9M
  stabilization-step                 14:09  14:12  ███······················    3m    1.9M
  tdd-unit-red-phase-step ×3         14:13  14:16  ····███··················    3m    2.0M
    #1                               14:13  14:15  ····██···················    2m    0.7M
    #2                               14:13  14:15  ····██···················    2m    0.6M
    #3                               14:13  14:16  ····███··················    3m    0.7M
  tdd-integration-red-phase-step     14:13  14:17  ····████·················    4m    1.4M
  tdd-unit-green-phase-step ×3       14:18  14:21  ·········███·············    3m    0.9M
    #1                               14:18  14:19  ·········█···············    1m    0.3M
    #2                               14:18  14:20  ·········██··············    2m    0.3M
    #3                               14:18  14:21  ·········███·············    3m    0.3M
  tdd-integration-green-phase-step   14:21  14:24  ············███··········    3m    0.9M
  tdd-system-green-phase-step        14:24  14:25  ···············█·········    1m    0.1M
  tdd-refactor-phase                 14:27  14:33  ··················██████·    6m    3.5M
```

```
module-b/plan.md
agent                                start  end   14:09     14:19     14:29  time  tokens
implement-plan-module                14:09  14:30  █████████████████████   21m    4.4M
  stabilization-step                 14:09  14:11  ██···················    2m    1.2M
  tdd-unit-red-phase-step ×2         14:12  14:14  ···██················    2m    1.1M
    #1                               14:12  14:14  ···██················    2m    0.6M
    #2                               14:12  14:13  ···█·················    1m    0.5M
  tdd-system-red-phase-step          14:12  14:17  ···█████·············    5m    1.9M
  tdd-unit-green-phase-step ×2       14:18  14:20  ·········██··········    2m    0.5M
    #1                               14:18  14:19  ·········█···········    1m    0.2M
    #2                               14:18  14:20  ·········██··········    2m    0.3M
  tdd-system-green-phase-step        14:21  14:23  ············██·······    2m    0.4M
  tdd-refactor-phase                 14:24  14:29  ···············█████·    5m    2.8M
```

A fix, a rework or an upgrade has the overview only, since its module agents spawn no steps. Its rows are the
session, the shared module agent, the module agents in parallel, then the refactor pass per module and any
reproduction at the finish. An upgrade has no refactor pass.

```
fix 12-widget-listed-twice
agent                                start  end    15:10     15:20     15:30     15:40       time  tokens
session (own turns)                  15:10  15:44  ██████████████████████████████████   34m    1.6M
fix-bug-module shared                15:16  15:19  ······███·························    3m    0.8M
fix-bug-module module-a              15:19  15:31  ·········████████████·············   12m    2.6M
fix-bug-module module-b              15:19  15:27  ·········████████·················    8m    1.9M
tdd-refactor-phase module-a          15:32  15:37  ······················█████·······    5m    2.1M
tdd-refactor-phase module-b          15:32  15:35  ······················███·········    3m    1.4M
tdd-unit-red-phase-step module-a     15:38  15:40  ····························██····    2m    0.4M
```

### What to do with it

- **Set the models.** The **Sub-Agent Models** section of your conventions names an executing model for step
  work and a deciding model for review and refactoring. The per-type rows say what each choice costs.
- **Find the long tail.** A single agent far above its type's average is one that looped. The budget rule
  stops that after three attempts and escalates once to the deciding model
  ([`templates/sub-agents.md`](../templates/sub-agents.md), **Budget and escalation**); every escalation is an
  `RL` note in the plan log, which names the step.
- **Assert a budget.** A plugin eval can read `cost.jsonl` and fail when a type exceeds a budget, so a cost
  regression fails a test.

## How the numbers are collected

<p align="center">
<img src="diagrams/cost-flow.svg" alt="A framework script call maps the session to its task; a sub-agent ending fires a hook that writes one line to the task's cost.jsonl; cost.sh renders cost.md at the finish" width="900">
</p>

Two hooks, registered by the plugin in `hooks/hooks.json`, and one script.

1. **`PreToolUse` on Bash** (`scripts/hooks/map-session-to-task.sh`) watches for a call to a framework
   script — `plan.sh`, `fix.sh`, `rework.sh`, `upgrade.sh`, `design.sh`, `cost.sh` — that names a task
   directory. It writes that directory to `.git/tdd-sdlc/sessions/<session>`, with the session's transcript
   path, the time of the first such call and the time of the latest. Every skill makes such a call before it
   spawns anything, so a framework session is always mapped. A session that never makes one is not a framework
   session. Mapping files older than 30 days are deleted on the next write; losing one only means later agents
   of that session without a plan path in their prompt go unrecorded.
2. **`SubagentStop`** (`scripts/hooks/record-agent-cost.sh`) fires once, when a sub-agent ends. It decides
   whether and where to record ([below](#how-an-agent-is-attributed)), reads the agent's transcript, and
   appends one JSON line to `docs/<n>-<task>/review/cost.jsonl`. The start time is the transcript's first
   timestamp and the end time its last, so no start hook is needed. The file moves with the task at archive and is never
   cleaned.
3. **`cost.sh report <task>`** (`scripts/cost/cost.sh`, usage in [its README](../scripts/cost/README.md)) reads
   `cost.jsonl` and writes `cost.md`. `implement-plan` runs it before archiving; `fix-bug`, `rework` and
   `upgrade-deps` run it at their finish. The session row comes from the session transcript the mapping
   names, summed between the session's first framework call and its latest; the report's own call is the
   latest, so the running session is summed to now. The report is a snapshot; running it again recomputes.

Both hooks are silent without `jq`, like the other hooks.

### One line per agent

| Field     | Value                                                                  | Source                 |
|-----------|------------------------------------------------------------------------|------------------------|
| `id`      | the agent id                                                           | the hook's input       |
| `parent`  | the id of the agent that spawned it; absent when the session did       | the agent's meta file  |
| `started` | the first message's timestamp                                          | the transcript         |
| `ended`   | the last message's timestamp                                           | the transcript         |
| `session` | the session id                                                         | the hook's input       |
| `agent`   | the agent type, one of `agents/*.md`                                   | the hook's input       |
| `model`   | the model that answered                                                | the transcript         |
| `tokens`  | input, output, cache read, cache create                                | the transcript, summed |
| `seconds` | wall time from first to last message, waiting included                 | the transcript         |
| `plan`    | the plan path the agent was spawned with, where its prompt names one   | the transcript         |

An agent can stop more than once: a pipeline that hands a wave back stops, is resumed, and stops again, and the
hook fires each time. Every stop appends a line; the report keeps the last line per `id`.

## How an agent is attributed

<p align="center">
<img src="diagrams/cost-attribution.svg" alt="Skip unless the agent type is a framework agent; take the task from the prompt's path, else from the session mapping, else skip; sum usage and append" width="420">
</p>

- **Only framework agents are recorded.** A `general-purpose` or `Explore` agent is skipped, whatever session
  it runs in. The survey agents `init-conventions` spawns and the agents that run a plan's post-implementation
  steps are general-purpose and go unrecorded.
- **The agent's own prompt names its task.** A pipeline is spawned with its plan path; a grill or a reviewer
  with the task directory; a step with its plan path. The plan path names the plan the agent worked on, which
  is how two plans of one task are told apart, and the task with it. Two tasks worked in one session cannot
  misfile each other.
- **The session mapping is the fallback.** An agent whose prompt names no path is filed under the session's
  mapped task. No mapping, no record. A task directory the tree does not hold is never created.
- **A step without a known parent joins its plan.** This happens when the meta file was missing when the agent
  stopped. Its row still lands under the pipeline for its plan.
- **A plan run twice gets two timelines.** A second pipeline for the same plan is drawn as `<plan> (2)`.

**Parallel pipelines** serve one task and land in one file, split per plan. **A task resumed in a new session**
gets a new mapping at that session's first script call; the report shows two sessions of one task. **A stray
script call** from an ordinary session maps it, but nothing is recorded unless a framework agent is spawned
there too.

## What is not recorded

- The session's turns before its first framework call. The session row starts there.
- An agent's turn count or anything it says about its own work.
- Anything from a session with no framework script call.

## What the host provides

The hooks rely on these Claude Code behaviours, measured on 2026-09-08. The `SubagentStop` event and its
stdin are in Claude Code's hooks reference. The transcript's line shape, the meta file, and how nested agents
report are not documented, and were measured. If an update changes them, recording degrades silently and
`cost.md` shows fewer rows.

1. **`SubagentStop` stdin** carries `session_id`, `transcript_path` (the session's), `cwd`, `agent_id`,
   `agent_type`, `agent_transcript_path`, `last_assistant_message`, `hook_event_name`, `stop_hook_active`. An
   internal helper agent stops with an empty `agent_type`; the type filter skips it.
2. **The transcript** is JSON lines. A line with `"type": "assistant"` carries `timestamp`, and `message.model`
   and `message.usage` with `input_tokens`, `output_tokens`, `cache_creation_input_tokens`,
   `cache_read_input_tokens`. The first line with `"type": "user"` is the prompt. Beside every sub-agent
   transcript sits `agent-<id>.meta.json` with `agentType`, `description`, `spawnDepth`, `parentAgentId` for an
   agent another agent spawned, and `model` where the spawn set one.
3. **Grandchildren fire the hook.** A step a pipeline spawned stops and is reported like the pipeline itself.
4. **`session_id` is the top session's** for a grandchild, and so is its transcript's directory:
   `<projects>/<session>/subagents/agent-<id>.jsonl`.
5. **One agent stops several times.** A parent stops once while waiting on its child and once at the end.

*Diagram sources: [`diagrams/cost-flow.puml`](diagrams/cost-flow.puml),
[`diagrams/cost-attribution.puml`](diagrams/cost-attribution.puml). Re-render with `diagrams/render.sh`.*
