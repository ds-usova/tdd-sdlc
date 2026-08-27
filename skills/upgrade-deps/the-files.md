# The files

What `upgrade.md`, each `<module>/steps.md` and the log beside each of them carry. Every file follows the
repository's documentation conventions. The directory carries the number and the name; no file repeats them.

## `upgrade.md`

```
# Upgrade: <the module, or the modules, and what moves>

**Affected Modules:** `module-a`
**Source:** <one line — the request, or the conventions entry that scheduled this run>
**Baseline:** <the commit the suite was green at>
**Surveyed with:** <what listed versions and what listed vulnerabilities, or `manifest + registry` / `none`>
**Policy:** <the conventions' line on which versions are routine, or `open — chosen in Phase 2`>

## Survey

| Dependency | Current | Newest | Target | Vulnerabilities | Guide | Status |
|------------|---------|--------|--------|-----------------|-------|--------|

## What changes

**<the first move, in a clause — "the test stack moves one minor", "the HTTP client crosses a major">**

| #   | Kind | What changes | Touches |
|-----|------|--------------|---------|

**Not changed:** <one line — a version a reader might expect to move and it does not, and why>

## Steps

<the checklist — step-format.md>

## Open Questions

- **Q1:** …
  - A:
```

**`**Closed:** <why>`** after `**Policy:**` means the upgrade was decided against or abandoned wholesale — every
dependency deferred in Phase 2, or every step abandoned — and stays where it is, unarchived; a file carrying
it is not resumed. It is the header line alone; nothing is written to the log. Absent on every upgrade that
reaches Phase 4.

### Survey

- **One row per dependency that is behind or vulnerable.** A row per BOM, with the libraries it pins listed
  under it in `Dependency` as `└ name`.
- **`Target`** is what this run moves to: the newest routine version under the policy, or the newest of all
  where the policy is open. A row the user leaves unselected keeps its `Target` and its `Status` says why.
- **`Vulnerabilities`** is the identifiers the scanner reported and the version that fixes each, or `—`.
- **`Guide`** is a link, or `none found`.
- **`Status`** is one of `proposed`, `deferred`, `not offered` (a major the policy keeps for its own story),
  `done`, `kept back`, `blocked`. Written `proposed` at Phase 1, settled at Phase 2, finalized at Phase 4. It is
  the one place the run's outcome is written back into the steps file: the survey is what a reader opens.

### What changes

The upgrade to a person: a reader who agrees with the survey and these tables can stop. Rows grouped by the move
they make. `What changes` starts with a verb — `bump`, `rename`, `replace call`, `move setting`. `Touches` is
the manifest, or the one package a `migrate` change reaches.

### Open Questions

`Q1` upward per file, assigned once, never renumbered; a question in `<module>/steps.md` is `Q1` of that file,
and anything outside the file cites both: `module-a/steps.md · Q2`. An agent that returns blocked writes its
question here, in the steps file it owns; the blocked return itself is a `B` entry in the log.

## `<module>/steps.md`

Carries `**Affected Module:**` and `**Upgrade:** [<the upgrade>](../upgrade.md)` above its `## Steps`, its own
`## Open Questions`, and nothing else. `## Survey` and `## What changes` stay in `upgrade.md` and cover every
steps file. `shared/steps.md` names every module the catalog serves.

## The log

Every steps file has a log beside it under its own stem: `upgrade-log.md` beside `upgrade.md`, `steps-log.md`
beside `<module>/steps.md` and `shared/steps.md`. One log per steps file, written at Phase 1 as its title and
an empty `## Attempts`; `## Run Log` is created at the first entry, never empty. `upgrade.sh validate` reports
a steps file without one. The steps file is what an agent reads; the log is what happened to it.

```
# Upgrade Log: <upgrade.md's title, after the colon>

## Attempts

<see templates/attempts.md — phase is a step ID>

## Run Log

- **B1 (U03):** kept back — <what the guide asked>
  - Kept because: A1, A2, A3
  - Would unblock: <a fixed release, a dependency of the module's own that has to move first, a decision>

- **B2 (U05):** <what happened>
  - Resolved:
```

### Attempts

`A1` upward per log, in the shape [`attempts.md`](../../templates/attempts.md) gives, phase the step ID.
Anything outside the log cites both: `module-a/steps-log.md · A3`.

### Run Log

`- **B<n> (<ID>):** <note>`, `B1` upward per log, numbered in the order written and never renumbered; a new
entry is appended, never inserted above an older one. `upgrade.sh block` writes one with an empty `- Resolved:`
line beneath it, and whoever settles the blocker fills that line. An entry recording a fact nobody has to act
on — a boundary a step widened, a deprecation the build printed — carries no `Resolved:`.

**A kept-back change is a `B` entry** — the section that keeps a half-done migration honest. One entry per
change a guide asked for that stays undone at the target version: the note is `kept back — <what the guide
said>`, `Kept because:` is the attempt IDs in one clause, and `Would unblock:` is what would let the next run
finish it. `validate` refuses one missing either line. A step abandoned gets `abandoned — <why>` on its header
in the steps file and a `B` entry here saying what was reverted.

Absent on most upgrades' logs. Never removed once written.
