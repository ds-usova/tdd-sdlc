# Disabling a test

How a test is switched off so the runner still reports it as *skipped*. Every skill and agent that disables a
test reads it here.

The mechanism, in this order:

1. the one the module's testing conventions give;
2. where they give none, the one an already-disabled test in the module uses;
3. where there is none, the test framework's own skip mechanism, and the report says so.

What the disable's reason says is the workflow's own rule: `stabilizing.md` for a stabilize step,
`reproducing.md` for a reproduction.
