# Which tests run

A small change does not run the whole test suite. It runs only the tests that could break. This file says how to
find them.

## Find the tests before you change the code

Do this before you edit any production file. The search in step 2 looks for the old value, and your edit removes
it.

Collect three groups of test classes:

1. **The test class of each file you change.** The testing conventions say how a test class is named after the
   class it tests. For example, `PageConfig` is tested by `PageConfigTest`.
2. **The test classes that mention what you change.** Search the test code for it. The next section says what to
   search for.
3. **The new test class**, if Phase 2 writes one.

Run these classes, and no others.

## What to search for

Search for something that appears only where your change matters.

| You change                  | Search for     | Example                     |
|-----------------------------|----------------|-----------------------------|
| a constant, field or method | its name       | `DEFAULT_PAGE_SIZE`         |
| a label or message          | the text       | `Save changes`              |
| a selector or test id       | the selector   | `data-testid="save-button"` |
| a plain number or boolean   | do not search  | `20`, `true`                |

A plain number or boolean appears all over the test code. Skip step 2 for it.

The search finds more than about twenty test classes: what you searched for is too common. Search for the name
instead of the value. Still too many: skip step 2.

## When to run the whole suite

**You changed shared test code: run the whole suite.** Shared test code is a base test class, a test data builder,
a fixture, or anything else the testing conventions list as shared. This is the shared test infrastructure rule of
[`rework/applying-a-step.md`](../rework/applying-a-step.md), **What A Step Runs**.

## What this misses

A test that checks your change some other way: not in the test class of a changed file, not by what you searched
for, and not through shared test code. Nothing here finds it.

So the report always says `full suite not run`, and the change is committed on its own.
