#!/usr/bin/env bash
# scripts/upgrade/upgrade.sh and its upgrade-parse.awk: status, show, tick, block, validate.
# The fixtures live under tests/fixtures/upgrade/; its README.md says what each one is.
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

S="$R/scripts/upgrade/upgrade.sh"

# Runs the script from inside PROJECT, so the upgrade is located from that git root.
run() { local p="$1"; shift; (cd "$p" && bash "$S" "$@" 2>&1); }

P="$(fixture upgrade/good repo)"; repo "$P"
D="$P/docs/3-bump-libs"

# --- validate, the whole directory and one file
check_ok "validate: the directory passes" run "$P" validate docs/3-bump-libs
out="$(run "$P" validate docs/3-bump-libs)"
check_match "validate: counts upgrade.md's steps, attempt and entry" 'upgrade.md: 4 steps, 1 attempt, 1 run-log entry, no problems' "$out"
check_match "validate: counts module-a/steps.md too" 'module-a/steps.md: 1 step, 0 attempts, 0 run-log entries, no problems' "$out"
check_ok "validate: one file by --file" run "$P" validate --file docs/3-bump-libs/module-a/steps.md

# --- status
out="$(run "$P" status)"
check_match "status: done over total of the upgrade.md found under docs/" '^  1/4$' "$out"
check_match "status: open ids exclude the ticked and the abandoned" '^  open: UP01 UP03$' "$out"
check_match "status: the abandoned step is listed apart" '^  abandoned: UP04$' "$out"
out="$(run "$P" status docs/3-bump-libs/module-a/steps.md)"
check_match "status: a positional path names the module file" '^  0/1' "$out"

# --- show
out="$(run "$P" show UP03)"
check_match "show: prints the header" '^- \[ \] UP03 · migrate' "$out"
check_match "show: prints the lines indented under it" 'change: .* · application.yml' "$out"
check_no_match "show: stops at the next step" 'UP04' "$out"
out="$(run "$P" show UP01 UP02)"
check "show: several ids are separated by one blank line" 1 "$(printf '%s\n' "$out" | grep -c '^$')"
check_fails "show: an unknown id fails" run "$P" show UP99

# --- tick
out="$(run "$P" tick UP01)"
check_match "tick: reports what it ticked" '^ticked: UP01$' "$out"
check_match "tick: writes the box" '^- \[x\] UP01 ' "$(cat "$D/upgrade.md")"
out="$(run "$P" tick UP02)"
check_match "tick: one already ticked is reported and left" '^already ticked: UP02$' "$out"
check_fails "tick: an unknown id in the batch fails" run "$P" tick UP03 UP99
check_match "tick: and ticks nothing of the batch" '^- \[ \] UP03 ' "$(cat "$D/upgrade.md")"

# --- block
out="$(run "$P" block UP03 "waiting on a fixed release of the client · see notes.md")"
check_match "block: numbers the entry after the last one" 'recorded as RL02 in docs/3-bump-libs/upgrade-log.md' "$out"
check_match "block: appends the note to the Run Log" '^- \*\*RL02 \(UP03\):\*\* waiting on a fixed release of the client · see notes.md$' "$(cat "$D/upgrade-log.md")"
check_match "block: with an empty Resolved line" '^  - Resolved:$' "$(tail -1 "$D/upgrade-log.md")"
check_match "block: leaves the step open" '^- \[ \] UP03 ' "$(cat "$D/upgrade.md")"
run "$P" block UP05 "the module's lock file is stale" docs/3-bump-libs/module-a/steps.md > /dev/null
check_match "block: creates the Run Log where the log has none" '^## Run Log$' "$(cat "$D/module-a/steps-log.md")"
check_match "block: as RL01" '^- \*\*RL01 \(UP05\):\*\* the module' "$(cat "$D/module-a/steps-log.md")"
check_ok "block: the logs still validate" run "$P" validate docs/3-bump-libs
check_fails "block: an unknown id fails" run "$P" block UP99 "note"
check_fails "block: a note in several words is bad usage" run "$P" block UP03 waiting on a release

# --- validate refuses a broken file. Each variant is good/ with one bad/ file laid over it.
check_match "validate: a file without **Format:** 2 is refused" 'no \*\*Format:\*\* line' "$(run "$(variant upgrade no-format-line)" validate)"
check_match "validate: another format number is refused" '\*\*Format:\*\* 1, and this plugin reads format 2' "$(run "$(variant upgrade format-1)" validate)"
check_match "validate: a duplicate UP id" 'duplicate ID UP01 \(first at line' "$(run "$(variant upgrade duplicate-up01)" validate)"
check_match "validate: needs: naming nothing" 'UP03 names UP77, which no step defines' "$(run "$(variant upgrade needs-names-nothing)" validate)"
check_match "validate: a placeholder left in" 'UP02.s "guide:" is empty or still a placeholder' "$(run "$(variant upgrade guide-placeholder)" validate)"
check_match "validate: a change: naming no place" 'UP03.s "change:" names no place' "$(run "$(variant upgrade change-without-place)" validate)"
p="$(variant upgrade change-on-bump)"
check_match "validate: a bump cannot carry change:" 'UP02 is a bump step and cannot carry "change:"' "$(run "$p" validate)"
check "validate: and the bump's change: is all that is wrong" 1 "$(run "$p" validate | grep -c .)"
check_match "validate: a Run Log in the steps file" "'## Run Log' sits in the upgrade.md" "$(run "$(variant upgrade run-log-in-steps)" validate)"

p="$(variant upgrade missing-log)"; rm "$p/docs/3-bump-libs/upgrade-log.md"
out="$(run "$p" validate)"
check_match "validate: a missing log" 'no upgrade log at docs/3-bump-libs/upgrade-log.md' "$out"
check_fails "block: refuses without a log" run "$p" block UP01 "note"

p="$(variant upgrade unclosed-fence)"
check_fails "status: an unclosed fence in the log is refused" run "$p" status
check_match "validate: names the line the fence opened at" 'upgrade-log.md:19: a fenced block opened here never closes' "$(run "$p" validate)"

check_match "validate: a kept-back entry owes Would unblock:" 'RL02 is kept back and owes "Would unblock:"' "$(run "$(variant upgrade kept-back-without-unblock)" validate)"

# --- usage
check_rc "an unknown command exits 2" 2 run "$P" frobnicate
check_rc "no command exits 2" 2 run "$P"

finish
