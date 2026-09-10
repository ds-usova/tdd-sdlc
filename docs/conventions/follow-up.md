# [Conventions](../conventions.md) > Follow-Up Work

What happens once a change is complete — the suite green, nothing left open.

## What Runs

1. `bash tests/run.sh`, given the finished tree — the whole suite, green. A red run means the change is not
   finished; report it rather than continue.
2. `grep` over the tree for every phrase the change replaced, and for the new rule's key phrase — the checklist
   in `.claude/skills/editing-the-framework/SKILL.md`, Before reporting done. Nothing old remains; the new rule
   occurs in one file and every other hit is a link.
3. `bash docs/diagrams/render.sh`, when a `.puml` changed — re-renders every SVG; the rendered file is checked
   by eye and committed with its source.
4. `claude plugin validate plugin`, when anything under `plugin/` changed.

None of these commits its own output.

## What Gets Written

- A diagram update — one per `.puml` whose shape the change altered; which diagram a change touches is the table
  in `.claude/skills/editing-the-framework/SKILL.md`, Diagrams. Never asks for consent.
- A `docs/*.md` page update — where the change moves a rule a reference page states, or adds a file the page
  lists.
  - `docs/developing.md` for anything a developer of the plugin runs;
  - `docs/agents.md` for a new agent or a changed spawn;
  - `docs/implement-plan.md` for a stage or gate.
- A `README.md` update — where the change alters what a consumer sees: a skill, a hook, a requirement, the
  layout table.
- A format bump — where a file's shape changes so that an older reader misreads it: the number in every file
  of that kind, `check_format` in its script, and a row in `plugin/scripts/README.md`, Formats. Asked for, never
  assumed.
- A version bump — `version` in `plugin/.claude-plugin/plugin.json`, only at a release, by the developer.
- Decision records: none. A change to why the framework has its shape is a change to `docs/strategy.md`.
