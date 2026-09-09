# Reproducing a reported defect

How a defect an agent reported becomes a bug that can be filed. Every skill and agent that files or reproduces
a bug reads it here.

## The case

An agent that hits a defect outside its own step reports it as a case. Four lines: the state before, the exact
call, what was expected, what came back. Precise enough that a test can be written from the report alone. The
agent writes no test and fixes nothing.

## Whose defect it is

The orchestrator decides first, before anything is spawned.

| The case is in                                       | It is                     | What happens                                                    |
|------------------------------------------------------|---------------------------|-----------------------------------------------------------------|
| a class this run creates or changes                  | this run's own defect     | a missing scenario: recorded in the Run Log, added to the plan  |
| code this run never touches                          | a pre-existing bug        | reproduced below, then filed                                    |

A run's own defect never becomes a backlog row. Where the run has no plan to add a scenario to, it is a
blocker.

## The reproduction

The orchestrator spawns the red agent of the type the module's conventions give for the class in the case. It
hands the case as a **reproduction brief** instead of plan steps. One agent per case, one at a time, never in a
wave. When: at a stage boundary in a pipeline; at the finish of a fix, a rework or an upgrade.

The red agent does one thing. It writes one test in the class the conventions put it in. It runs it. The test must
fail, and fail for the symptom's reason. Then it disables the test as `disabling-a-test.md` says. It reports the class
and the method. A test that passes, or fails for another reason, is not a reproduction; the agent says so and changes
nothing.

**The disabled reason is the symptom in words.** Never a backlog id, a task number or a step id. The findings
block names the test; the backlog row points at the block.

## What the orchestrator records

- Every reproduction goes into the Run Log with its class and method.
- Every guardrail's skipped count from then on reads: the baseline, plus what stabilization disabled and a
  later step clears, plus the reproductions the Run Log names.
- A case that did not reproduce stays a hypothesis in the Run Log. Nothing is filed from it.

## What is filed

The reproduced case becomes a **Bug** block in `review/findings.md`, with the test on its `Test` line
([`findings.md`](findings.md)), and a `BB` row in `docs/backlog.md` ([`backlog.md`](backlog.md)). `fix-bug`
starts from the row. Its `red` step enables the test.

Nothing is fixed by the run that found it. A pre-existing bug that blocks a step is a blocker like any other.
