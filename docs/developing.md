# Developing the plugin

- `claude --plugin-dir <path-to-tdd-sdlc>` runs a session on the working tree.
- An edit to a `SKILL.md` takes effect immediately. A change under `agents/` or `hooks/` needs `/reload-plugins`.
- `claude plugin validate .` before every tag. Consumers receive a new copy only when `version` in
  `.claude-plugin/plugin.json` changes.
- Diagrams: edit `docs/diagrams/*.puml`, re-render with `docs/diagrams/render.sh` (public PlantUML server, `curl`
  only).

## Releasing

1. `claude plugin validate .`
2. Bump `version` in `.claude-plugin/plugin.json` and commit it.
3. `git push`.
4. `claude plugin tag --push`.

Nothing pushes an update to anyone. A user stays on the version they installed until they run those two
commands.
