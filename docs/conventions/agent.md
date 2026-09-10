# [Conventions](../conventions.md) > Agent Configuration

How a coding agent commits, parallelizes work, and which model does what. Every agent-only fact belongs here.

## Version Control

Commit incrementally: no — the developer commits. An agent leaves the tree changed and says what it changed.

## Sub-Agent Models

- Deciding work — the session's model: planning, plan review, the refactor pass over a finished diff.
- Executing work — `claude-sonnet-5`: stabilization, and every red- and green-phase step agent.
- Everything else: the session's model.

## Parallelism

- Max concurrent implementation agents on this module's plan: 4.
- Max concurrent agents across all modules: n/a — one module.
- Max concurrent test runs: unlimited. A case file works under its own temporary directory and its own
  `$XDG_CACHE_HOME`.
- Notes: none.

Parallel agents share one working tree: an agent stays inside the files its step owns, and never draws
conclusions from a file another agent is writing.

## Follow-Up Work in a Plan

What runs once a change is complete, and what it earns, is [Follow-Up Work](follow-up.md).

- A plan lists under **Post-Implementation Steps** one item per diagram the change alters, as `Re-render
  <name>.puml`, and one item per reference page the change moves a rule out of, as `Update docs/<page>.md:
  <what>`. A format bump is raised as a numbered question and becomes an item only on an answered yes.
