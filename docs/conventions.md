# Conventions — `tdd-sdlc`

The index of this repository's conventions. The repository is one module: a Claude Code plugin under `plugin/`,
its tests under `tests/`, its reference pages under `docs/`. The content lives in section files under
[`conventions/`](conventions/).

- [Orientation](conventions/orientation.md) — what the plugin is built from, and what to read first.
- [Architecture & Layering](conventions/architecture.md) — the tree, what may depend on what, file locations,
  diagram format.
- [Testing Conventions](conventions/testing.md) — which parts get which test type, the harness, how a case
  file is written.
- [Code Style](conventions/code-style.md) — how scripts and shipped prose are written, and what a cleanup pass
  may touch.
- [Build](conventions/build.md) — the commands that check the plugin and run its tests.
- [Follow-Up Work](conventions/follow-up.md) — what runs once a change is complete, and what it earns.
- [Agent Configuration](conventions/agent.md) — commit behaviour, sub-agent models, parallelism.

There is no tier above.
