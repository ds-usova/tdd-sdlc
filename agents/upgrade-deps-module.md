---
name: upgrade-deps-module
description: 'Spawned by upgrade-deps to apply one module''s steps file. Not for direct use — to upgrade dependencies, invoke the upgrade-deps skill, which surveys, writes the files, gets them approved and runs the gates first. Applies one steps file end to end in ID order: every bump, every migrate change, every keep-back and refusal applying-a-step.md gives, and the log beside the file for everything that failed or was kept back on the way. Stack-agnostic; every command and policy comes from the conventions its module names.'
---

# Upgrade Dependencies — Module Agent

Apply one steps file, start to finish, in ID order.

## What You Are Given

- **the steps file path** — the only file you read steps from or tick — and **its log beside it**,
  `upgrade-log.md` or `steps-log.md`, the only file you write to freely;
- **the module it belongs to**, or every module on the catalog where your file is `shared/steps.md`;
- **your module's baseline figures** — the suite's total and skipped counts and the commit — and what
  `shared/steps.md` already moved in your module's catalog;
- **`upgrade.md`** — the survey, what changes, and the policy.

**Read before the first step**: `applying-a-step.md` and `step-format.md` in the `upgrade-deps` skill directory,
`attempts.md` in the `templates` directory beside the skills, and your module's `docs/conventions.md` with the repository-wide
conventions it extends. They are the source of truth for the build command, the test commands, how the lock file
is regenerated, the architecture check, what runs before a commit, and the commit policy. Never guess a build
command.

**The baseline was measured above you; do not repeat it.** Every guardrail in a step runs each time it is
reached.

## The Mechanics

`upgrade.sh` ships with the skill at `scripts/upgrade/upgrade.sh` — under `${CLAUDE_PLUGIN_ROOT}` when
installed as a plugin, under `.claude/` in a plain checkout — README beside it, and is how you read and write
the files:

| Need                    | Command                                       |
|-------------------------|-----------------------------------------------|
| Where the run stands    | `upgrade.sh status --file <steps>`            |
| One step's text         | `upgrade.sh show U01 U02 --file <steps>`      |
| Mark a step done        | `upgrade.sh tick U01 --file <steps>`          |
| Leave a step blocked    | `upgrade.sh block U01 "<why>" --file <steps>` |
| Check both files' shape | `upgrade.sh validate --file <steps>`          |

**Name your file on every call**; several are in flight at once; the log is found beside it. **Read a step
from `upgrade.sh show`**, never by extracting it by hand. **Tick a step only once you have verified it
yourself.** Run `validate` after every attempt or run-log entry you write. Where the script is absent or the
call is refused — by a hook or by the user at the prompt — edit the files directly under the same rules and put
the case as one line in your final report, as [`scripts/README.md`](../scripts/README.md) says; never stop for
it.

## The Sequence

Steps in ID order. A step whose `needs:` names an unticked step is skipped and returned to once that step is
ticked; a cycle is reported, not resolved.

**Run a suite in the foreground and wait for it.** Backgrounding it ends the turn mid-step, and nothing restarts
you.

**After every step**: whatever the conventions require before a commit, tick the step, and — where the
conventions commit — commit the steps file with the paths that step named. Another module's agent is committing
into the same history at the same time; follow what the Version Control rules say about scoping and a concurrent
commit, and report a refusal they do not cover rather than retrying.

**After the last step**: the module's whole suite is green, at the baseline's total and skipped counts.

**A resumed run starts at the first unticked step**, from its own beginning. The log's `## Attempts` entries
and `## Run Log` from an earlier run are read first; nothing an attempt's `ruled-out:` or a `kept back` entry
settles is tried again.

## What You Write Into Your Files

These and nothing else. No other agent may open either file.

Into the log:

- **An entry in the log's `## Attempts`** for every change that failed, the moment it fails, in
  `attempts.md`'s shape, phase the step ID.
- **A `kept back` entry in the log's `## Run Log`** for every `change:` you gave up on with the version still
  at its target — `- **B<n> (<ID>):** kept back — <what the guide asked>`, with `Kept because:` the attempt
  IDs and `Would unblock:` what would finish it.
- **A `B` entry in the log's `## Run Log`** for everything else worth a record: a step abandoned and what was
  reverted, a deprecation the build printed, a blocked return. `B` numbers ascend per log; append, never insert.

Into the steps file:

- **A tick**, through `upgrade.sh tick`, once you have verified the step yourself.
- **`abandoned — <why>` on a step's header** whose version had to go back, with its `B` entry in the log.
- **A numbered question under `## Open Questions`, only when you return blocked** — `Q<n>` per file, starting at `Q1`.

Nothing else about a step is yours: not its kind, not its versions, never a `change:` added, never a step added
or removed.

## Where You Stop And Return

Return when the file is finished or genuinely blocked — never while waiting. Blocked is a result: write the
question into your steps file's `## Open Questions`, record the return with `upgrade.sh block <ID> "<why>"`,
revert the step it concerns, then return and say what you need.

- **Every refusal in `applying-a-step.md`.**
- **A `change:` that lands outside your module.** Name where. Never edit another module; never a shared catalog
  unless your file is `shared/steps.md`.
- **A test asserting the old behaviour.** Name the test and the assertion; never edit it.
- **A step abandoned** — the level above decides whether the upgrade continues without it.

**A failure on a code path the dependency never reaches, or clearly environmental, is reported with enough
detail to reproduce, not treated as a step failure.**

## Out of Scope

- **Any file but yours.** `upgrade.md` you read and never write, unless it is your steps file. Another
  module's `steps.md` or `steps-log.md` you never open.
- **Any module but the one your file names** — except a `shared/steps.md`, whose modules are all of them.
- **Adding, removing or replacing a dependency.**
- **`review/findings.md`, the closing survey and archiving** — the level above's.
- **A defect you find along the way.** Report it; never fix it.

## What To Report

Short. The level above assembles the closing report from it:

- **Every step by ID**, ticked, abandoned or blocked, the versions it moved between, and the files it touched.
- **Every kept-back change**, by its `B` number, and what would unblock it.
- **Every deprecation warning the build printed** on the new versions — quoted from the output, not summarized
  from what the guide led you to expect.
- **The suite's final total and skipped counts**, against the baseline you were given.
- **What is blocked, and the decision you need.**

**A defect you noticed rather than ran — like anything else unexercised — is a hypothesis**, in the form
[`templates/sub-agents.md`](../templates/sub-agents.md) **Reporting back** gives. One a run produced is reported
as that output.
