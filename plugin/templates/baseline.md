# A baseline

What a run does before its first edit. `implement-plan` reads only **A red baseline**; its Gate 2 runs and records
the suite itself.

## A clean tree

**The affected modules are clean before anything is measured.** Uncommitted work under one of them: name the
files and stop. Uncommitted work elsewhere is left alone.

## The run

Full build and full suite of every affected module, with its own commands. **A whole-suite run that already
answers for this commit is read, not repeated.**

- **Green**: record the commit and, per module, the total and skipped counts. Each module agent gets its
  module's figures.
- **Anything red**: **A red baseline**, below.

## A red baseline

A test the skill itself expects red, such as the bug's own reproduction, is not covered here.

### Re-run once

**Re-run each failing test class once, alone,** with the module's single-test command.

| The re-run                                           | What happens                                         |
|------------------------------------------------------|------------------------------------------------------|
| passes; the module lists it as a known unstable test | it does not block; the baseline counts it as passing |
| passes; the test is not listed                       | ask, as below                                        |
| fails again                                          | stop; file it, as below                              |
| fails on the environment                             | stop; file nothing; report the error                 |

A failure on the environment is a container that did not start or a refused connection, not an assertion.

Where the conventions name no single-test command, nothing is re-run. Every failure then stops the run and is
filed.

### A test that passed on re-run

Ask about every such test in `AskUserQuestion`, one question per test, four to a call:

- add it to the module's known unstable tests and go on (recommended);
- stop the run.

Write each test the user chose to add into the conventions, with the error it failed with, before going on.

### A test that failed again

**Stop before a file is touched.** Change nothing and fix nothing.

**File one bug entry per failing test**, as [`backlog.md`](backlog.md) says for a red baseline test. A test an
open entry already names is not filed again.

**Report** each failure — test name, error, suspected cause — and the entry it was filed as.
