# Stabilization Waves

How `implement-plan-module` chooses whole-group or parallel stabilization and verifies each stabilization wave.

Never wave `shared/plan.md`. Give its whole Stabilization group to one agent in listed order.

For a module plan, read each item's `writes:` set from [`stabilization-group.md`](stabilization-group.md). Keep
the section barriers: API Contract, then Database, then Interface-First / Build Stabilization. Within the current
section, ask `plan.sh next --group stabilization --section <section>` for eligible items.

Items with overlapping write sets belong to one bundle. A file overlaps itself. A directory overlaps every path
below it. Bundle items whose write set is missing, uncertain, or broader than one source grouping together.

Use waves only when some section has at least two concurrently eligible bundles with disjoint write sets.
Otherwise give the whole group to one agent.

Apply the agent cap and launch the wave as [`sub-agents.md`](sub-agents.md) says.

Pass `whole group` or `stabilization-wave bundle` as the spawned `stabilization-step` agent's execution mode.

After each wave, the orchestrator compiles the module, including test sources. Map each failure to one bundle.
Handle a newly discovered path as `stabilization-group.md` requires, record the widening in the Run Log, and
re-delegate only that bundle. If ownership is ambiguous, repair the affected bundles sequentially. Tick a
bundle's items only after compilation succeeds.

In whole-group mode, tick each item the agent reports done after its compilation succeeds. Block the rest with
the reason it reports.

After every section is complete, run [`stabilization-exit.md`](stabilization-exit.md).
