---
description: Make one small change to finished code — a label, a default value, a button position, one missed case. If the change alters what the spec promises, it updates that spec and waits for approval first. Otherwise it just makes the change. One module, one new test at most, never the whole test suite.
argument-hint: [ what to change, in a sentence ]
---

# Small Change

Change one small thing in code that is already finished.

## When Not To Use It

- **The change touches a contract**: a database schema, an API, a message format, a boundary between modules, a
  dependency. Use `design-task`, then `plan-task`.
- **The code does not do what it already promised.** That is a bug. Use `fix-bug`.
- **The code works, but its structure is bad.** Use `rework`.
- **The code belongs to a plan that is still being implemented.** That plan finishes the work.

## Is It Small?

Ask three questions, in order. **If any answer is yes, stop.** Tell the user which question stopped the run and
which skill to use instead. Change nothing.

| # | Question                                                                             | If yes        |
|---|--------------------------------------------------------------------------------------|---------------|
| 1 | Does it touch a schema, an API, a message format, a module boundary or a dependency? | `design-task` |
| 2 | Does it touch more than one module?                                                  | `design-task` |
| 3 | Does it need more than one new test assertion?                                       | `design-task` |

**Count assertions for question 3. Do not guess.**

- Default page size changes from 20 to 50. One assertion checks the new default. **Small**, even if other tests
  also mention 20.
- Default page size changes, and empty pages now show a message. Two assertions, two behaviours. **Not small.**

## Two Kinds of Small Change

Ask: **does the change alter what the spec promises?** The spec is the `spec.md` of the task that built this
code. Its promises are the requirements (`RQ`) and acceptance scenarios (`AC`).

|                  | No: cosmetic                               | Yes: a promise changes                             |
|------------------|--------------------------------------------|----------------------------------------------------|
| Examples         | button colour, position, label, a log line | default value, a result, a validation rule         |
| Files in `docs/` | not touched                                | the task's `spec.md`, `design.md`, `design-log.md` |
| Asks the user    | no                                         | yes, shows the spec change before any code         |
| Test             | only if there is something to check        | always exactly one new test                        |

## Conventions

Read `docs/conventions.md` and `<module>/docs/conventions.md` for the module you change. You need from them:

- the command that compiles the module;
- the command that runs one test class, and the one that runs the whole suite;
- which test type (unit, integration, system) each part of the module gets;
- how test classes are named;
- which test code is shared: base classes, builders, fixtures;
- the commit policy;
- which model runs agents.

## Phase 0 — Prepare

1. **Ask the three questions** in **Is It Small?** Stop on any yes.
2. **Decide which kind of change it is**: cosmetic, or a promise changes.
3. **Find the tests that could break**, as [`which-tests-run.md`](which-tests-run.md) says. Do it now, before you
   edit code: the search looks for the old value.
4. **Run the tests step 3 found, once, before you change anything.** Write down which of them already fail. A
   test that fails now was not broken by this change.
5. **Check the files you will edit for uncommitted changes**, with `git status`: the production files, the test
   class for the new test, and the tests step 3 found. Uncommitted changes in other files do not matter.
   Some of these files have them: list the files and ask the user whether to proceed, and say that nothing will
   be committed. The user says no: stop.

Do not run the whole suite. Do not write a plan.

**Never undo anything by yourself.** No `git restore`, no `git checkout`, no deleting a file you wrote. When the
run stops early, leave the tree as it is, and report every file you changed. The user decides what to keep. The
one thing you do put back is the deliberate break in Phase 3, step 5, which you typed yourself a moment before.

## Phase 1 — Update the Spec

**Cosmetic change: skip this phase.**

1. **Find the task that built this code.** Search `docs/implemented/*/` for the production files you change. The
   task whose `plan.md` names them is the owner. Two tasks match: take the one archived last.
   No task matches: this code has no spec, so no promise can change. Treat the change as cosmetic, and say so in
   the report.
2. **Count earlier changes to this task.** Each one is an entry in its `design-log.md`. Two already: stop. Tell
   the user this task has been changed twice already, and the change needs `design-task`.
3. **Move the task directory from `docs/implemented/` back to `docs/`**, to the same path it had before.
4. **Edit the spec.** Change the `RQ` and `AC` rows the change affects, and the parts of `design.md` they rely on.
   A new `AC` gets the next free number. Never reuse a number.
5. **Add one entry to `design-log.md`**: what changed and why.
6. **Show the user the diff of `spec.md`, and wait.** Do not edit code until they approve. If the diff is in a
   spec that has nothing to do with the change, you found the wrong task: say so and stop.

## Phase 2 — Write the Failing Test

**Nothing to check** — a colour, a spacing, a position: skip this phase. Write in the report that no test was
possible.

**Otherwise, write exactly one test**, of one type. Pick the cheapest type that fails because of this change. The
conventions say which types exist for this part of the module.

**A red agent writes the test.** Spawn one agent of that type — `tdd-unit-red-phase-step`,
`tdd-integration-red-phase-step` or `tdd-system-red-phase-step` — and wait for it, as
[`templates/sub-agents.md`](../../templates/sub-agents.md) says. Give it:

- the production class the test checks;
- the test class to write the test in;
- the scenario, as given / when / then;
- the paths of the two conventions files.

Also tell it two things it would not expect:

- **the production class is already implemented**: it has no stubs and no intent comments;
- **the test must fail against the current code**, because the current code still has the old behaviour.

**The test stays enabled.** Do not disable it.

**The test passes straight away:** it is not a failing test. Either the change is already in the code, or the
test does not check it. Tell the user which, and stop.

## Phase 3 — Make It Pass

**You change the production code yourself.** Do not spawn an agent. Edit only the files the change needs.

Then, in this order:

1. **Run the new test.** It passes.
2. **Run the tests [`which-tests-run.md`](which-tests-run.md) found.** Some may fail now, because they still
   expect the old value.
3. **Fix those tests, and only those.** Change only the expected value, the label or the selector: `20` becomes
   `50`. Do not add an assertion. Do not remove one.
   **A test you cannot fix that way** — you would have to decide what it should check — means the change has a
   second behaviour. Stop and ask the user, with the test, the line that fails, and the decision it needs.
   Two answers:
   - **the user decides what the test should check**: make that one edit, and say in the report that a second
     behaviour was decided here. In a run that changes a promise, put it in the `design-log.md` entry too;
   - **the user wants it done properly**: disable that test, as
     [`templates/disabling-a-test.md`](../../templates/disabling-a-test.md) says. The reason says in words what
     the test now expects. Leave everything else in the tree, name the disabled test in the report, and tell the
     user to use `design-task`.
4. **Run the same tests again.** All pass.
5. **Check the new test really catches the change.** Break the code it checks, run the test, see it fail, put
   the code back, run it again. How: **Mutation** in [`rework/applying-a-step.md`](../rework/applying-a-step.md).
   No new test: skip this step.

**A test fails that does not check what you changed:** compare it with the list from Phase 0, step 4.

- It was already failing then: it is not yours. Name it in the report and carry on.
- It was passing then: your change broke it. Stop. Leave the tree as it is, and tell the user what you changed.

Never edit that test to make it pass.

## Phase 4 — Finish

1. **Every test you ran passes**, except two kinds that do not block: one that already failed in Phase 0, step
   4, and one you disabled in Phase 3, step 3. Name both in the report.
   Do not run the whole suite. The one exception: you changed shared test code, as
   [`which-tests-run.md`](which-tests-run.md) says.
2. **Move the task directory back to `docs/implemented/`**, if Phase 1 moved it out.
3. **Commit the change on its own**, as the commit policy says. Add only the files this run changed. No commit
   policy: do not commit, and tell the user the change is not committed.
   The user let you edit files with uncommitted changes: do not commit anything. Tell the user which files mix
   their work with this change.
4. **Report, in six lines:**
   - what changed;
   - cosmetic, or a promise changed;
   - which `AC` changed, or `none`;
   - the new test, or why there is none;
   - every test class you ran, and any test left failing or disabled;
   - `full suite not run`, unless you ran it.

## Response Style

One line when each phase starts. Only two long outputs: the spec diff in Phase 1 and the report in Phase 4.