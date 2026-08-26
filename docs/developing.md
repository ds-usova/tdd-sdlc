# Developing the plugin

- `claude --plugin-dir <path-to-tdd-sdlc>` runs a session on the working tree.
- An edit to a `SKILL.md` takes effect immediately. A change under `agents/` or `hooks/` needs `/reload-plugins`.
- `claude plugin validate .` before every tag. Consumers receive a new copy only when `version` in
  `.claude-plugin/plugin.json` changes.
- Diagrams: edit `docs/diagrams/*.puml`, re-render with `docs/diagrams/render.sh` (public PlantUML server, `curl`
  only).
