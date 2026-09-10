# Developing the plugin

- `claude --plugin-dir <path-to-tdd-sdlc>/plugin` runs a session on the working tree. Only `plugin/` ships.
- Before editing anything the plugin ships, read `.claude/skills/editing-the-framework/SKILL.md`. It is a project
  skill: `/editing-the-framework` loads it in a session on this repository.
- An edit to a `SKILL.md` takes effect immediately. A change under `agents/` or `hooks/` needs `/reload-plugins`.
- `claude plugin validate plugin` before every tag. Consumers receive a new copy only when `version` in
  `plugin/.claude-plugin/plugin.json` changes.
- Diagrams: edit `docs/diagrams/*.puml`, re-render with `docs/diagrams/render.sh` (public PlantUML server, `curl`
  only).

## Releasing

1. `bash plugin/scripts/cost/cost.sh refresh-pricing`, then commit `plugin/scripts/cost/pricing.json` when it
   changed. It is the rates a report uses offline; a release ships it as it is.
2. `claude plugin validate plugin`
3. Bump `version` in `plugin/.claude-plugin/plugin.json` and commit it.
4. `git push`.
5. `claude plugin tag --push plugin`.

Nothing pushes an update to anyone. A user stays on the version they installed until they run those two
commands.
