# [Conventions](../conventions.md) > Orientation

What the plugin is built from, and what to read before changing it.

## Tech Stack

Versions live in the files that pin them and are not repeated here.

- Language / framework: Bash and POSIX awk for the scripts and hooks; Markdown with YAML frontmatter for the
  skills, agents and templates; PowerShell for the one repository-only hook under `.claude/scripts/hooks/`.
- Host: Claude Code's plugin system. `plugin/.claude-plugin/plugin.json` is the manifest; `plugin/hooks/hooks.json`
  wires the four shipped hooks.
- Database: none.
- Persistence: the files a run writes under a consuming repository's `docs/`, and a per-user rates cache
  `cost.sh` keeps under `$XDG_CACHE_HOME/tdd-sdlc/`.
- Messaging / caching: none.
- External services consumed: the published Claude pricing and models pages, fetched by `cost.sh` over `curl`;
  the public PlantUML server, used only by `docs/diagrams/render.sh`.
- APIs exposed: seven skills (`/tdd-sdlc:<name>`), fifteen sub-agents the skills spawn, and six script
  command lines under `plugin/scripts/`.
- Contract-first codegen: none — every file is hand-written.
- Tools on `PATH`: `bash`, `awk`, `sed`, `git`, `find`, `grep`; `jq`, without which the hooks exit silently and
  `cost.sh` refuses to run; `curl` for `cost.sh` to fetch rates and for `render.sh`; `od` for `render.sh`. What
  a consumer needs of these is `README.md`, Requirements.

## Documentation References

Where these disagree with the conventions, the conventions win.

- Why the framework has this shape: [`docs/strategy.md`](../strategy.md).
- Which agent spawns which: [`docs/agents.md`](../agents.md) and `docs/diagrams/agents.svg`.
- How a plan runs — levels, gates, waves: [`docs/implement-plan.md`](../implement-plan.md).
- What a run costs and how it is recorded: [`docs/cost-recording.md`](../cost-recording.md).
- Working on the plugin — running it from the tree, releasing: [`docs/developing.md`](../developing.md).
- What the skills read from a consumer's conventions:
  [`plugin/templates/conventions/contract.md`](../../plugin/templates/conventions/contract.md).
- Each script's command line and file format: the `README.md` beside it under `plugin/scripts/<name>/`;
  the formats table is [`plugin/scripts/README.md`](../../plugin/scripts/README.md).
- Decision records: none — the reasoning behind a shape goes into `docs/strategy.md`.
- Operational docs: none — the plugin has no deployment.
