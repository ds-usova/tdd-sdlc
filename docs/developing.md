# Developing the plugin

- `claude --plugin-dir <path-to-tdd-sdlc>/plugin` runs a session on the working tree. Only `plugin/` ships.
- An edit to a `SKILL.md` takes effect immediately. A change under `agents/` or `hooks/` needs `/reload-plugins`.
- How the plugin is laid out, tested, checked and written, and what runs once a change is complete:
  [`docs/conventions.md`](conventions.md). Before editing anything the plugin ships, load
  `/editing-the-framework`, the project skill that holds the writing rules.
- Consumers receive a new copy only when `version` in `plugin/.claude-plugin/plugin.json` changes.

## Releasing

1. `bash plugin/scripts/cost/cost.sh refresh-pricing`, then commit `plugin/scripts/cost/pricing.json` when it
   changed. It is the rates a report uses offline; a release ships it as it is.
2. `bash tests/run.sh`, green.
3. `claude plugin validate plugin`
4. Bump `version` in `plugin/.claude-plugin/plugin.json` and commit it.
5. `git push`.
6. `claude plugin tag --push plugin`.

Nothing pushes an update to anyone. A user stays on the version they installed until they run those two
commands.
