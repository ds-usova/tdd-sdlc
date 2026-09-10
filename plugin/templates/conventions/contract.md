# What the agents read from your conventions

Your conventions are two indexes, `docs/conventions.md` for the repository and `<module>/docs/conventions.md`
per module, each linking to the pages that hold the rules. Every skill and agent of this plugin needs some of
those rules. This page lists which ones, who needs each, and what happens when your conventions do not state
it.

An agent that needs the commit policy follows your index to wherever you wrote it. The page layout
`init-conventions` writes ([`templates/conventions/`](README.md)) is one way to hold
the facts. Any layout the index leads to works the same.

- [Who the readers are](#who-the-readers-are)
- [How to read "Absent"](#how-to-read-absent)
- [Build and run](#build-and-run)
- [Architecture](#architecture)
- [Testing](#testing)
- [Code style](#code-style)
- [Follow-up work](#follow-up-work)
- [Agent configuration](#agent-configuration)
- [Repository tier](#repository-tier)
- [The minimum](#the-minimum)

## Who the readers are

- **`design-task`, `plan-task`**: the skills that write the spec and the plan.
- **`implement-plan`**: the skill that runs a plan. Per module it starts a pipeline, and the pipeline runs a
  **stabilization step** (writes the new classes as stubs), **red steps** (write the tests, one per test
  class), **green steps** (make them pass, one per class) and a **refactor pass** over the finished diff.
- **`fix-bug`, `rework`, `upgrade-deps`**: the skills that fix a bug, restructure code, or move dependency
  versions. Each runs one **module agent** per affected module, which applies steps and runs the suite.
- **The close of a run**: what `implement-plan`, `fix-bug`, `rework` and `upgrade-deps` do after every step is
  done and the suite is green, ending with the task directory moved to `docs/implemented/`.

## How to read "Absent"

Absent means your conventions say nothing about the fact. A page that says "none" is an answer, not an
absence. Three outcomes occur in the tables. They differ in when the gap is found and who finds it:

- **The run stops.** The skill checks for the fact before it starts work, finds it missing, and asks you for it,
  usually by asking you to run `init-conventions`. Nothing has been written yet. The agent is told not to derive
  the value itself, even where the tree makes it look obvious: a guessed test command is a guessed gate. Answer,
  and run the skill again.
- **A default applies.** The agent proceeds with the value named in the table. Nothing stops.
- **A blocker.** The gap is found in the middle of a run, by a step agent that cannot ask you. It stops its own
  step, reports what was missing, and the run ends with that in its report. Work done by earlier steps stays in
  the tree, and the task directory stays under `docs/`. Add the fact to your conventions, and run the skill
  again: it resumes from the open steps. A step agent never fills a gap with a tool or a pattern of its own.

## Build and run

| Fact                                                                                                                       | Who reads it                                                                                | Absent                                                                                         |
|----------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| The command that compiles the module, and where commands run from                                                          | every step, every module agent                                                              | the run stops at its first suite run; a command is never guessed                               |
| The command that runs one test class                                                                                       | every red and green step                                                                    | the run stops at its first suite run; a command is never guessed                               |
| The command that runs the full suite                                                                                       | every pipeline, every module agent, the close of a run                                      | the run stops at its first suite run; a command is never guessed                               |
| The check that enforces the layer rules, and its command                                                                   | stabilization, refactor pass, every module agent, `review-plan`                             | no check runs                                                                                  |
| What runs before a commit, such as a formatter                                                                             | every agent that commits                                                                    | nothing runs before a commit                                                                   |
| A coverage guardrail: the command and its minimum                                                                          | a pipeline's whole-plan guardrail; the close of a `fix-bug`, `rework` or `upgrade-deps` run | not run; when named, a failure blocks the archive, or in a pipeline is recorded in the run log |
| Dependencies: the manifest, and how the lock file is regenerated                                                           | `upgrade-deps`                                                                              | the manifest is the whole edit                                                                 |
| Dependencies: the command that lists outdated versions                                                                     | `upgrade-deps`                                                                              | the stack's own tool, then the registry                                                        |
| Dependencies: the vulnerability scanner                                                                                    | `upgrade-deps`                                                                              | the stack's own audit command; else none                                                       |
| Dependencies: which upgrades need no decision, such as patch and minor, and which are a task of their own, such as a major | `upgrade-deps`                                                                              | every newer version is proposed; you pick                                                      |
| Dependencies: a documented upgrade flow of your own                                                                        | `upgrade-deps`                                                                              | the skill's own phases                                                                         |

## Architecture

| Fact                                                                    | Who reads it                                             | Absent                                                  |
|-------------------------------------------------------------------------|----------------------------------------------------------|---------------------------------------------------------|
| The layers, the packages they map to, which may depend on which         | `plan-task`, `review-plan`, green steps, refactor pass   | classes are grouped as the code is; no rule is enforced |
| Where the API schema, migrations, generated code and request files live | stabilization, integration and system steps, `plan-task` | a step that needs one reports a blocker                 |
| The diagram language, its fenced-block tag, and any preamble            | `design-task`, `plan-task`, `rework`                     | PlantUML with the bundled C4 library                    |

## Testing

| Fact                                                                                                                                                 | Who reads it                                                           | Absent                                                                                                                                       |
|------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| **The test-type mapping**: which parts of the module get unit, integration or system tests, and the real dependency an integration test runs against | `plan-task`, every red step, `fix-bug`                                 | **the run stops**: the module cannot be planned. With no conventions file at all, `plan-task` plans on generic defaults and opens a question |
| The test framework, container dependencies, HTTP stubbing, the API test client                                                                       | every red step                                                         | what the neighbouring tests use; a blocker only where there are none                                                                         |
| How one inbound adapter is booted alone, with its ports mocked                                                                                       | integration red steps                                                  | a step that needs it reports a blocker                                                                                                       |
| How a test fires a scheduled or message-driven entry point                                                                                           | system red and green steps                                             | a step that needs it reports a blocker                                                                                                       |
| How test methods and test classes are named                                                                                                          | every red step, refactor pass                                          | the pattern the neighbouring tests follow                                                                                                    |
| Test base classes and shared builders, and what each provides                                                                                        | every red step, refactor pass                                          | the ones the neighbouring tests use                                                                                                          |
| Testing style: parameterized tests, assertions, annotations, imports, how deeply a mock is verified                                                  | every red step, refactor pass                                          | the idioms the neighbouring tests follow; a blocker only where there are none                                                                |
| How a test is disabled                                                                                                                               | stabilization, every reproduction, `fix-bug`, `rework`, `upgrade-deps` | the mechanism an already-disabled test in the module uses; else the test framework's own                                                     |

## Code style

| Fact                                                                                                    | Who reads it                    | Absent                                                                                  |
|---------------------------------------------------------------------------------------------------------|---------------------------------|-----------------------------------------------------------------------------------------|
| Production-code style: injection, nulls, logging, errors, imports, method size, mapping, adapter idioms | every green step, refactor pass | the idioms the neighbouring production code follows; a blocker only where there is none |
| The token a stub's intent comment starts with                                                           | stabilization, refactor pass    | `stub-intent:`                                                                          |
| Refactoring: what to tackle first, where extracted code goes, what to leave alone                       | refactor pass, `rework`         | a default checklist; the report says none were found                                    |

## Follow-up work

| Fact                                                                        | Who reads it       | Absent                                        |
|-----------------------------------------------------------------------------|--------------------|-----------------------------------------------|
| What runs over finished work, in order: a measurement, a documentation pass | the close of a run | nothing runs                                  |
| What documents a change earns, and which of them need your approval         | `plan-task`        | nothing is written; approval is never assumed |
| How a plan lists those documents                                            | `plan-task`        | the plan has no post-implementation items     |

## Agent configuration

| Fact                                                                                                                                                                         | Who reads it                                          | Absent                                     |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|--------------------------------------------|
| **The commit policy**: whether the agent commits, how often, on which branch, in what message format, and what a commit covers when another module's agent is committing too | every skill and module agent                          | **no commits**; a policy is never invented |
| Which model runs deciding work and which runs executing work                                                                                                                 | every agent spawn                                     | the session's model                        |
| How many agents may run at once in this module                                                                                                                               | every wave of steps                                   | four at once                               |
| How many may run at once across all modules                                                                                                                                  | `implement-plan`, `fix-bug`, `rework`, `upgrade-deps` | two modules at once                        |

## Repository tier

Rules that bind every module belong to the repository index, `docs/conventions.md`, and a module page links
there instead of repeating them. Two facts above usually live there: the commit policy, because a repository has
one history, and the cap across all modules, because one machine runs them all. One fact lives only there:

| Fact                                         | Who reads it                                            | Absent                                                               |
|----------------------------------------------|---------------------------------------------------------|----------------------------------------------------------------------|
| How documents in this repository are written | `init-conventions`, `fix-bug`, `rework`, `upgrade-deps` | labelled lists, one-line bullets, a table for a rule with conditions |

## The minimum

The framework runs without most of this. It does not run without these two:

- the build commands: compile, one test class, the full suite;
- the test-type mapping.

Everything else has a default. The one to set deliberately is the commit policy: silent means the agent never
commits.

`init-conventions` writes what your tree answers and asks you for the rest. On hand-over it lists every fact on
this page it could not find, so the gaps are visible before the first run.
