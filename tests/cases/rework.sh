#!/usr/bin/env bash
# rework.sh and rework-parse.awk: every subcommand on a two-file rework (rework.md above mod/steps.md), the
# happy path first and then each failure validate guards. Fixtures live under tests/fixtures/rework/.
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

PROJ="$(fixture rework/good repo)"
repo "$PROJ"
DIR="$PROJ/docs/3-widget"
SF="docs/3-widget/mod/steps.md"
STEPS="$DIR/mod/steps.md"
LOG="$DIR/mod/steps-log.md"

# Runs the script from inside a fixture repo, where the rework is located from git's root.
rw() { (cd "$PROJ" && bash "$R/scripts/rework/rework.sh" "$@"); }

# --- validate and status on a sound rework ---------------------------------------------------------
check_ok "validate of the rework directory passes" rw validate docs/3-widget
out="$(rw validate docs/3-widget 2>&1)"
check_match "validate counts the module's steps" 'steps\.md: 4 steps, 0 run-log entries, no problems' "$out"
check_match "validate counts rework.md's zero steps as no fault" 'rework\.md: 0 steps, 0 run-log entries, no problems' "$out"

out="$(rw status "$SF" 2>&1)"
check_match "status counts the ticked step" '^  1/4$' "$out"
check_match "status lists the open ids" '^  open: WK01 WK03$' "$out"
check_match "status lists the abandoned id apart" '^  abandoned: WK04$' "$out"
check_fails "status of the stepless rework.md fails" rw status
check_match "status names the stepless file" 'defines no steps' "$(rw status 2>&1)"

# --- show ------------------------------------------------------------------------------------------
expected='- [ ] WK03 · pin · enforce the layering rule
  - test-files:
    - `test/ArchTest.java`
  - needs: WK02
  - proves: removing the rule fails ArchTest'
check "show prints the step's header and its block" "$expected" "$(rw show WK03 --file "$SF")"
check "show separates several ids with a blank line" \
  "$(rw show WK04 "$SF")"$'\n\n'"$(rw show WK03 "$SF")" "$(rw show WK04 WK03 "$SF")"
check_fails "show of an unknown id fails" rw show WK99 "$SF"

# --- tick ------------------------------------------------------------------------------------------
check_fails "tick with an unknown id in the batch fails" rw tick WK01 WK99 "$SF"
check_match "the batch with the unknown id ticked nothing" '^- \[ \] WK01' "$(cat "$STEPS")"
check "tick reports what it ticked" "ticked: WK01" "$(rw tick WK01 "$SF")"
check_match "tick marks the box in the file" '^- \[x\] WK01' "$(cat "$STEPS")"
check "tick of a ticked step names it" "already ticked: WK02" "$(rw tick WK02 "$SF")"
check_rc "tick of a ticked step exits 0" 0 rw tick WK02 "$SF"
check_match "status counts the new tick" '^  2/4$' "$(rw status "$SF")"

# --- block -----------------------------------------------------------------------------------------
check "block records the first entry" "WK03 left open; recorded as RL01 in docs/3-widget/mod/steps-log.md" \
  "$(rw block WK03 "waiting on the db, see notes.md" "$SF")"
log="$(cat "$LOG")"
check_match "block created the Run Log heading" '^## Run Log$' "$log"
check_match "block wrote the entry" 'RL01 \(WK03\):\*\* waiting on the db, see notes\.md$' "$log"
check "block put an empty Resolved line beneath it" "  - Resolved:" "$(grep -A1 'RL01 (WK03)' "$LOG" | tail -1)"
check_match "block leaves the step open" '^- \[ \] WK03' "$(cat "$STEPS")"
rw block WK01 "second note" "$SF" > /dev/null
check "block appends the next entry below the one before" "RL01 RL02" \
  "$(grep -o 'RL0[0-9]' "$LOG" | tr '\n' ' ' | sed 's/ $//')"
check_match "validate counts the appended entries" '2 run-log entries, no problems' "$(rw validate "$SF" 2>&1)"
printf '%s\n' "" "## Caveats" "" "- **CV01:** rework.sh refused from WK01 on. Ticks by hand." >> "$LOG"
check_ok "a Caveats section in the log still validates" rw validate "$SF"
check_match "and the counts are unchanged" '2 run-log entries, no problems' "$(rw validate "$SF" 2>&1)"
check_fails "block of an unknown id fails" rw block WK99 "a note" "$SF"
check_fails "block with an unquoted note is bad usage" rw block WK03 two words

# --- usage, on the sound copy. It sits here because the variants below are broken copies, where a
# call fails whatever it is given, so a refusal there would prove nothing. ----------------------
check_rc "an unknown option exits 2" 2 rw status --flie "$SF"
check_match "and names the option" "^unknown option '--flie'" "$(rw status --flie "$SF" 2>&1)"
check_rc "an unknown command exits 2" 2 rw next "$SF"
check_match "and names the command" "^unknown command 'next'" "$(rw next "$SF" 2>&1)"

# --- what validate guards ------------------------------------------------------------------------
# Each variant is a fresh copy of good/ with the file from bad/<name>/ laid over it; pointing PROJ
# at it is what makes rw run there.
validate_bad() { rw validate "$SF" 2>&1; }

PROJ="$(variant rework no-format-line)"
check_fails "a file without a Format line fails validate" validate_bad
check_match "and is reported as pre-format 2" 'no \*\*Format:\*\* line' "$(validate_bad)"
PROJ="$(variant rework format-1)"
check_match "another format number is named" 'Format:\*\* 1, and this plugin reads format 2' "$(validate_bad)"
PROJ="$(variant rework duplicate-wk01)"
check_match "a duplicate id is reported with its first line" 'duplicate ID WK01 \(first at line 9\)' "$(validate_bad)"
PROJ="$(variant rework needs-names-nothing)"
check_match "a needs: naming no step is reported" 'WK03 names WK77, which no step defines' "$(validate_bad)"
PROJ="$(variant rework frozen-placeholder)"
check_match "a placeholder value is reported" 'WK01.s "frozen:" is empty or still a placeholder' "$(validate_bad)"
PROJ="$(variant rework files-on-tests-step)"
check_match "a line the kind does not take is reported" 'WK02 is a tests step and cannot carry "files:"' "$(validate_bad)"
PROJ="$(variant rework unanswered-oq01)"
check_match "an unanswered open question is reported" 'OQ01 has no answer' "$(validate_bad)"
PROJ="$(variant rework missing-log)"
check_match "a missing log is reported with its path" 'no rework log at docs/3-widget/mod/orphan-log.md' \
  "$(rw validate docs/3-widget/mod/orphan.md 2>&1)"

PROJ="$(variant rework unclosed-fence)"
check_fails "an unclosed fence refuses status" rw status "$SF"
check_match "and says what was not read" 'never closes' "$(rw status "$SF" 2>&1)"

finish
