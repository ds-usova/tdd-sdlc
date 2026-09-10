# [Conventions](../conventions.md) > Architecture & Layering

Where a file goes, what may depend on what, and what a document draws.

## Package Structure

- Module root: the repository root.
- Build tool / module system: none. `plugin/` is what ships; `claude plugin validate plugin` checks its manifest.
- Base namespace: the skills are invoked as `/tdd-sdlc:<name>`; the scripts are called by path under
  `${CLAUDE_PLUGIN_ROOT}/scripts/`.
- Source set layout: `plugin/` production, `tests/` tests, `docs/` reference pages.

```
tdd-sdlc
├── .claude-plugin/            # marketplace.json — the marketplace entry that distributes plugin/
├── plugin/                    # everything that ships; nothing outside it does
│   ├── .claude-plugin/        # plugin.json — name, version
│   ├── skills/<name>/         # SKILL.md and the references only that skill reads
│   ├── agents/                # every sub-agent a skill spawns; none is for direct use
│   ├── templates/             # files more than one skill reads; conventions/ holds the consumer templates
│   ├── scripts/<name>/        # one script per file format: <name>.sh, its awk files, README.md
│   ├── scripts/hooks/         # the shipped hooks
│   ├── hooks/hooks.json       # wires the hooks to their events
│   └── settings.json          # the allow rules a consumer copies
├── tests/
│   ├── run.sh                 # runs every case file, or the ones named
│   ├── lib.sh                 # the check helpers and the temporary directory every case file uses
│   ├── cases/<name>.sh        # one case file per script, and one for the hooks
│   └── fixtures/<name>/       # committed fixtures; a case file copies one before writing to it
├── docs/                      # reference pages, diagrams, the conventions, tasks in flight and archived
│   ├── conventions/           # these files
│   └── diagrams/              # *.puml sources, the rendered *.svg beside each, render.sh
└── .claude/                   # repository-only: the editing skill, and a hook that guards shipped files
```

## Naming Across the Layer Boundary

- A skill is a directory under `plugin/skills/` named as it is invoked; an agent file is named as the skill
  spawns it, `<stage>-<phase>-step` for a step agent, `<skill>-module` for a module agent.
- A script directory is named for the file it reads (`plan`, `design`, `fix`, `rework`, `upgrade`, `cost`), and
  the script and its case file carry that name. An awk file beside it is named for what it parses or renders:
  `<name>-parse.awk` for the script's own file, `pricing-parse.awk`, `cost-render.awk`.
- A shipped file names a consumer's fact in placeholder form — `<module>`, `<the module conventions>` — never a
  value from any one repository.

## File Locations

- API schema file: none.
- Migration folder: none. A format change bumps the `**Format:**` number a file carries; the table is
  `plugin/scripts/README.md`, Formats.
- Generated sources: `docs/diagrams/*.svg`, rendered from the `.puml` beside each by `docs/diagrams/render.sh`.
- Bundled data: `plugin/scripts/cost/pricing.json`, the rates a cost report uses offline.
- Manual / request files: none.

## Architecture Enforcement

- Dependency rule:
  - A skill names what it needs and reads the value from a consumer's conventions; it never supplies one.
  - A skill may point at an agent, a template or a script.
  - An agent may point at a template or a script.
  - A script reads and edits one file format and reads nothing under `skills/` or `agents/`.
  - A template is the one home of a rule; every other file links to it.
  - Nothing under `plugin/` refers to a path outside it.
- Tool: none — the rule is reviewed by hand, against the checklist in
  `.claude/skills/editing-the-framework/SKILL.md`. One clause has a mechanical guard:
  `.claude/scripts/hooks/deny-repo-token-in-plugin.ps1`, a `PreToolUse` hook on `Edit` and `Write` wired from
  `.claude/settings.json`, refuses a write under `plugin/` that carries a token from its list of
  repository-specific names.
- Test class / config file: none.

## Diagram Format

- Diagram language: PlantUML.
- Fenced-block language tag: none — a diagram is a file under `docs/diagrams/`, not a fenced block.
- Preamble / includes: none.
- Renderer constraints: `render.sh` sends the source to the public PlantUML server over `curl`; nothing private
  goes in a diagram. A page embeds the rendered SVG, never the source.
- Rendered output: the `.svg` beside each `.puml`, committed. When it is re-rendered is
  [Follow-Up Work](follow-up.md).
