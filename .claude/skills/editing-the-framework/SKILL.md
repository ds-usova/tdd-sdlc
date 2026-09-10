---
description: How to write and what not to write when editing this repository's plugin and docs. Use before any change under plugin/ or docs/.
---

# Editing the framework

Read this before changing any file the plugin ships. Then edit. Then run the checklist at the end.

## What to write

- **Instructions only.** A skill, an agent or a template holds conditions, actions and checks. State the
  condition, then the action, then the check.
- **One fact, one home.** A rule is written in one file. Every other file names that file and restates
  nothing. Before writing a paragraph, search for the rule. If it exists, link to it.
- **What an agent needs at the moment it runs.** Its inputs, what it may touch, what it reports. Nothing it
  cannot act on.

## What not to write

- **No rationale.** Why the framework is shaped this way goes to `docs/strategy.md`. Cut a sentence that
  explains instead of instructing.
- **No big picture.** An agent does not need to know what the level above it does with its report, or what
  the framework promises the user.
- **No fact that belongs to another file.** A rule about the backlog lives in `backlog.md`. A skill that
  needs it says "as `backlog.md` says" and stops.
- **No project fact.** Build commands, layer names, file locations, diagram languages and models come from the
  repository's conventions. A skill names what it needs and reads the value there.
- **No section name of a conventions file in a prompt.** An agent gets the conventions index paths. Its own
  file says what facts it needs; it follows the index to them.

## How to write it

- **Short sentences.** One idea each. Split at a dash, a semicolon, "so", "which" or "and" that starts a
  second idea.
- **Lines wrap at 120 characters.** Frontmatter `description:` is the one exception.
- **Articles follow the sound of the id.** "An `RL` entry", "a `DN` entry".

## Scripts and hooks

- **Every script change runs on a fixture before it is reported.** Build a scratch repository, run every
  subcommand the change touches, and show the output. A syntax check alone is not a run.

## Diagrams

`docs/diagrams/*.puml` draw what the prose says. A change to any of these updates the matching diagram in the
same edit, then re-renders it with `docs/diagrams/render.sh`:

| Changed                                                        | Diagram                                          |
|----------------------------------------------------------------|--------------------------------------------------|
| which agent spawns which, or a new agent                       | `agents.puml`                                    |
| a pipeline stage, its gate, or the wave rules                  | `implement-plan-pipeline.puml`                   |
| a task-level gate, the seam, or what happens after the plans   | `implement-plan-task.puml`                       |
| which skill writes which file, or the skill order              | `workflow.puml`, `hero.puml`                     |

Check the rendered SVG before reporting. A diagram that still shows the old shape is a second copy of the rule.

## Before reporting done

1. `grep` the tree for every phrase the change replaced. Nothing old remains.
2. `grep` for the new rule's key phrase. It occurs in one file; every other hit is a link.
3. Every added sentence is a condition, an action or a check. Cut the rest.
4. No line over 120 characters outside a `description:`.
5. Scripts and hooks changed ran on a fixture; the output is in the report.
6. Every diagram the change touches is updated and re-rendered.
