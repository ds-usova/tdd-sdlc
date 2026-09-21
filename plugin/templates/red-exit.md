# The Red Exit Check

What the orchestrator verifies once every red-phase item is ticked or recorded as blocked, before any green step
is spawned.

Do not run the module's full suite here. [`test-waves.md`](test-waves.md) verifies each red step's focused test
classes before the item is ticked. The checked red item is the durable evidence that its tests compiled and
produced the expected RED result. A cold resume reads the checkbox; it does not reconstruct the runner's output.

Confirm that every non-blocked red item is checked. Confirm that every allowed expected pass has the Run Log
entry `implement-plan-module` requires. An unchecked item has no RED evidence and cannot enter green.

Green does not start until this holds for every non-blocked item.
