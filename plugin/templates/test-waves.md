# Test Waves

How `implement-plan-module` turns eligible RED or GREEN steps into parallel test-step agents and verifies their
result.

## Bundling

**Bundle by grouping and layer, not by class.** A grouping is the source grouping the module conventions name —
a package, a directory, a feature folder. Steps whose target classes share a grouping *and* a layer go to one
sub-agent. A grouping that holds both layers (a pure mapper beside its adapter's slice test) gets one bundle per
layer.

A bundle starts only when every step in it is eligible; leave a step out rather than hold the bundle for it. The
bundled agent **reports per step ID**, and each is ticked separately.

**Never hand one production class to two parallel agents.**

## The cap

Apply the agent cap in [`sub-agents.md`](sub-agents.md). When it forces a choice, keep one grouping in one wave.
Take bundles from different groupings first. Put the second bundle of a grouping in the next wave. Among the rest,
take them in the order the scheduler gives.

## Launching a wave

Launch and await the wave as [`sub-agents.md`](sub-agents.md) says. Bundles spawned and awaited one at a time are
not a wave.

## Who verifies a wave

**Who runs the guardrail depends on how many agents share a source set.**

- **One bundle in a module this wave** — the sub-agent verifies itself and reports the result.
- **More than one** — the sub-agents **do not run tests at all**. Say so in the prompt: write the files, report,
  verify nothing. The orchestrator compiles the module, then runs **the wave's test classes** once when the wave
  is done: each step's own test class, plus every class its `update:` bullets name, with the focused run command
  the conventions give. It maps each failure back to a step by its test class name and re-delegates only what
  actually failed. Each re-delegation is an attempt against that step's budget ([`sub-agents.md`](sub-agents.md),
  **Budget and escalation**).

**A wave never runs the module's full suite.** A wave whose focused classes pass and whose module compiles is
done. Later stages run a wider suite only where their own guardrail says so.

Never let an agent wait out or work around a compile error in a file it does not own. It resolves at the wave's
single verification.

## Ticking

Tick each item as its sub-agent reports success and the wave's verification confirms it. If one reports a
blocker, leave the item unchecked, record the blocker, and let the rest of the wave continue. The stage is
complete only when every item is ticked or recorded as blocked. A blocked step's dependents are not spawned;
they are recorded as blocked by that dependency.
