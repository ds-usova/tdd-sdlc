#!/usr/bin/env bash
# fix.sh: status, show, start, tick, block, validate, task, attempts - and what validate refuses.
# Fixtures live under tests/fixtures/fix/; its README.md lists the bad variants.
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

P="$(fixture fix/good repo)"; repo "$P"
D="$P/docs/3-double-charge"

# The script finds the bug from the working directory's git root, so every call runs inside the fixture.
fx() { (cd "$P" && bash "$R/scripts/fix/fix.sh" "$@"); }
fx_out() { fx "$@" 2>&1; }

# A fresh copy of good with one bad/NAME variant laid over it, outside the fixture repo so the default
# lookup under docs/ never finds it. Prints the path of the fix file to validate.
bad() { printf '%s\n' "$(variant fix "$1")/docs/3-double-charge/fix.md"; }

# --- validate, the happy path
check_ok "validate the bug directory" fx validate docs/3-double-charge
check_match "validate counts the fix's steps, attempts and entries" \
  'fix\.md: 3 steps, 2 attempts, 0 run-log entries, no problems' "$(fx_out validate docs/3-double-charge)"

# --- status, show
check_match "status finds the one fix in flight" '^  0/3$' "$(fx_out status)"
check_match "status lists every open step" '^  open: FS01 FR01 FG01$' "$(fx_out status)"
out="$(fx_out show FR01)"
check_match "show prints the step header" '^- \[ \] FR01 · red · A request' "$out"
check_match "show prints the lines under the step" '^  - reproduces: the second call' "$out"
check_no_match "show stops at the next step" 'FG01' "$out"
check_fails "show refuses a step nothing defines" fx show FR09

# --- start, tick
check_ok "start writes the in-flight line" fx start FG01 guarding on the persisted request id
check_match "the log carries the step and the approach" \
  '^\*\*In flight:\*\* FG01 · guarding on the persisted request id$' "$(cat "$D/fix-log.md")"
check_fails "tick with an unknown id fails" fx tick FS01 FR09
check_no_match "and ticks nothing" '^- \[x\]' "$(cat "$D/fix.md")"
check_match "tick marks the steps done" '^ticked: FS01 FR01$' "$(fx_out tick FS01 FR01)"
check_match "tick empties the in-flight line" '^\*\*In flight:\*\*$' "$(cat "$D/fix-log.md")"
check_match "a ticked step is reported, not ticked again" '^already ticked: FS01$' "$(fx_out tick FS01)"

# --- block
check_match "block records the next run-log entry" \
  'FG01 left open; recorded as RL01' "$(fx_out block FG01 "the symptom survives a correct fix")"
check_match "the entry sits under Run Log" '^## Run Log$' "$(cat "$D/fix-log.md")"
check_match "the entry names the step and the note" \
  '^- \*\*RL01 \(FG01\):\*\* the symptom survives a correct fix$' "$(cat "$D/fix-log.md")"
check_match "with an empty Resolved line beneath it" '^  - Resolved:$' "$(cat "$D/fix-log.md")"
check_fails "block refuses an unquoted note" fx block FG01 a second cause
check_ok "the log block wrote still validates" fx validate docs/3-double-charge
printf '%s\n' "" "## Caveats" "" "- **CV01:** fix.sh refused from FG01 on. Ticks by hand." >> "$D/fix-log.md"
check_ok "a Caveats section in the log still validates" fx validate docs/3-double-charge
check_match "and the counts are unchanged" 'fix.md: 3 steps, 2 attempts, 1 run-log entry, no problems' "$(fx_out validate docs/3-double-charge)"

# --- attempts, task
check "attempts sums every log" "bug-log.md · AT01, fix-log.md · AT01–AT02" "$(fx_out attempts docs/3-double-charge)"
check_rc "task reports an open fix with exit 1" 1 fx task docs/3-double-charge
check_match "task shows the fix's count" '^  fix\.md +2/3 +open$' "$(fx_out task docs/3-double-charge)"
fx tick FG01 > /dev/null
check_match "task is complete once every step is ticked" 'every fix complete' "$(fx_out task docs/3-double-charge)"

# --- what validate refuses
check_match "a file without Format: 2" 'no \*\*Format:\*\* line' "$(fx_out validate "$(bad no-format-line)")"
b="$(bad duplicate-fr01)"
check_match "a duplicate id" 'duplicate ID FR01' "$(fx_out validate "$b")"
check "and the repeated id is all that is wrong" 1 "$(fx_out validate "$b" | grep -c .)"
check_match "needs: naming a step nothing defines" 'FR01 names FS09, which this file defines no step for' \
  "$(fx_out validate "$(bad needs-names-nothing)")"
check_match "a placeholder left in" 'FR01.s "reproduces:" is empty or still a placeholder' \
  "$(fx_out validate "$(bad reproduces-placeholder)")"
check_match "a green step owing fixes:" 'FG01 is a green step and owes "fixes:"' "$(fx_out validate "$(bad green-without-fixes)")"
check_match "an Attempts section left in the fix file" "'## Attempts' sits in the fix.md" \
  "$(fx_out validate "$(bad attempts-in-fix-md)")"

# missing-log is used on its own, not laid over good: an overlay cannot remove the log.
b="$(fixture fix/bad/missing-log)"
check_match "a missing log" 'no fix log at' "$(fx_out validate "$b/docs/3-double-charge/fix.md")"

finish
