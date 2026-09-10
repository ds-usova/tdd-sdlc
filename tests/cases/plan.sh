#!/usr/bin/env bash
# plan.sh and plan-parse.awk, on the fixture repository under tests/fixtures/plan/good.
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

REPO="$(fixture plan/good repo)"
TASK="$REPO/docs/1-add-widget"
PLAN="$TASK/plan.md"
LOG="$TASK/plan-log.md"
repo "$REPO"

# Every command runs from inside the repository: the plan is found from git's top level.
plan() { (cd "$REPO" && bash "$R/scripts/plan/plan.sh" "$@"); }

# A broken copy of the repository, for --file: good/ with one bad/ variant laid over it. It sits outside
# $REPO, so its plan is never the plan in flight.
bad_plan() { printf '%s\n' "$(variant plan "$1" "bad-$1")/docs/1-add-widget/plan.md"; }
validate_bad() { plan validate --file "$1" 2>&1; }

echo "-- validate, status, next on the template"
check_ok "validate: the example plan has no problems" plan validate
check_match "validate: counts 23 items and 2 run-log entries" '23 items, 2 run-log entries, no problems' "$(plan validate)"
check_match "status: every item open" 'TOTAL +0/23' "$(plan status)"
check_match "status: the first group lists its open ids" 'Stabilization +0/10 +open: ST01, ST02' "$(plan status)"
check_match "next: the earliest group with open work" '^group: Stabilization' "$(plan next)"
check_match "next: ST01 eligible" '^ST01 +depth' "$(plan next)"
check_no_match "next: a later group is not offered" '^GU01' "$(plan next)"
check_fails "next: an ambiguous --group is refused" plan next --group phase
check_fails "next: a --group nothing matches is refused" plan next --group nowhere

echo "-- after:"
green="$(plan next --group green --all)"
check_match "next --group green: GU03 eligible with a chain of 2" '^GU03 +depth 2' "$green"
check_no_match "next --group green: GI02 not eligible" '^GI02' "$green"
check_match "next --all: GI02 waits on GU03" '\(waiting\) GI02 +after GU03' "$green"
check_match "tick GU03 prints the ticked line" '^- \[x\] GU03' "$(plan tick GU03)"
check_match "next --group green: GI02 eligible once GU03 is ticked" '^GI02 +depth' "$(plan next --group green)"
check_match "next --section: only the section's items" '^GU01' "$(plan next --group green --section unit)"
check_no_match "next --section: other sections excluded" '^GI01' "$(plan next --group green --section unit)"

echo "-- tick and status agree"
plan tick ST01 ST02 >/dev/null
check_match "status after tick: 2/10 and ST01 no longer open" 'Stabilization +2/10 +open: ST03' "$(plan status)"
check_match "status after tick: total" 'TOTAL +3/23' "$(plan status)"
check_match "tick again: reported, not rewritten" '^already ticked: ST01$' "$(plan tick ST01)"
check_fails "tick: an unknown id in the batch fails" plan tick ST03 ZZ99
check_match "tick: an unknown id ticks nothing" '^- \[ \] ST03' "$(plan show ST03)"
check_fails "show: an unknown id fails" plan show ZZ99

echo "-- show"
check_match "show: the fenced block indented under ST01 belongs to it" 'operationId: createWidget' "$(plan show ST01)"
check_no_match "show: the next item is not printed" 'ST02' "$(plan show ST01)"
check "show: several ids come blank-line separated" "1" "$(plan show RU02 RU03 | grep -c '^$')"
check_match "show: a bare plan path is accepted" '^- \[x\] GU03' "$(plan show GU03 docs/1-add-widget/plan.md)"

echo "-- block"
check_match "block: numbered after the log's last entry" 'recorded as RL03' "$(plan block RI01 "database is down, see docs/notes.md")"
check_match "block: the entry is appended to the Run Log" '^- \*\*RL03 \(RI01\):\*\* database is down, see docs/notes.md$' "$(cat "$LOG")"
check_match "block: an empty Resolved line under it" '^  - Resolved:$' "$(cat "$LOG")"
check_match "block: leaves the item open" '^- \[ \] RI01' "$(plan show RI01)"
check_ok "block: the log still validates" plan validate
printf '%s\n' "" "## Caveats" "" "- **CV01:** plan.sh refused from RU01 on. Ticks and validation by hand." >> "$LOG"
check_ok "caveats: a Caveats section in the log still validates" plan validate
check_match "caveats: the counts are unchanged" '23 items, 3 run-log entries, no problems' "$(plan validate)"
check_fails "block: an unknown id is refused" plan block ZZ99 "note"
check_fails "block: needs a note" plan block RI01

echo "-- validate guards"
p="$(bad_plan no-format-line)"
check_fails "validate: no Format line fails" plan validate --file "$p"
check_match "validate: no Format line is named" 'no \*\*Format:\*\* line' "$(validate_bad "$p")"
p="$(bad_plan format-1)"
check_match "validate: an older format is named" '\*\*Format:\*\* 1, and this plugin reads format 2' "$(validate_bad "$p")"
p="$(bad_plan duplicate-st01)"
check_match "validate: duplicate id" '^duplicate ID: ST01' "$(validate_bad "$p")"
p="$(bad_plan after-names-nothing)"
check_match "validate: after: naming nothing" '^GI02 depends on GU99, which no item defines' "$(validate_bad "$p")"
p="$(bad_plan then-placeholder)"
check_match "validate: a placeholder then:" '^RU01 leaves "then:" empty at line' "$(validate_bad "$p")"
p="$(bad_plan update-names-missing-method)"
check_match "validate: update: naming a method not in the tree" "RU03 names 'whenNothing_thenNothing\(\)' in an update: bullet" "$(validate_bad "$p")"
# missing-log holds the plan alone, so it is used as is rather than laid over good/.
p="$(fixture plan/bad/missing-log)/docs/1-add-widget/plan.md"
check_match "validate: a missing log" '^no plan log at' "$(validate_bad "$p")"
p="$(bad_plan unclosed-fence)"
check_fails "status: refuses a plan whose fence never closes" plan status --file "$p"

echo "-- stub, stubs, tick refusing a stubbed class"
check_match "stub: records the file relative to the root" '^recorded: src/CreateWidgetUseCase.java$' "$(plan stub src/CreateWidgetUseCase.java)"
check_match "stub: the log gains a Stubs section with the marker" '^Marker: `stub-intent:`$' "$(cat "$LOG")"
check_match "stub: a path already recorded is reported" '^already recorded:' "$(plan stub src/CreateWidgetUseCase.java)"
check_rc "stubs: exit 1 while the marker remains" 1 plan stubs
check_match "stubs: names file:line" 'src/CreateWidgetUseCase.java:3:' "$(plan stubs)"
check_fails "tick: a green item whose class still carries the marker is refused" plan tick GU01
check_match "tick: the refused item stays open" '^- \[ \] GU01' "$(plan show GU01)"
# The implementer removes the marker: the behaviour under test.
sed '/stub-intent:/d' "$REPO/src/CreateWidgetUseCase.java" > "$WORK/tmp" \
  && mv "$WORK/tmp" "$REPO/src/CreateWidgetUseCase.java"
check_ok "stubs: exit 0 once the marker is gone" plan stubs
check_ok "tick: GU01 ticks once implemented" plan tick GU01

echo "-- suite"
check_match "suite record: appends the run" '^recorded: baseline · tree [0-9a-f]{12} · total 10 · skipped 1 · green$' \
  "$(plan suite record --stage baseline --total 10 --skipped 1 --verdict green src)"
check_match "suite check: unchanged tree prints the figures" '^unchanged since baseline: total 10, skipped 1, green$' "$(plan suite check)"
# A source edit after the record: the tree hash must move.
echo "// moved" >> "$REPO/src/WidgetUtilsTest.java"
check_rc "suite check: exit 1 once the tree moved" 1 plan suite check
check_fails "suite record: a verdict other than green/red is refused" plan suite record --stage x --total 1 --skipped 0 --verdict maybe src

echo "-- task"
check_rc "task: open plans exit 1" 1 plan task
check_match "task: names the directory and the count" 'plan.md +4/23 +19 open' "$(plan task)"
check_match "task: a plan path reaches the same directory" '^docs/1-add-widget$' "$(plan task docs/1-add-widget/plan.md | head -1)"

echo "-- usage"
check_rc "an unknown command exits 2" 2 plan frobnicate
overlay plan/bad/two-plans-in-flight "$REPO"
check_fails "two plans in flight: status without --file is refused" plan status
check_match "two plans in flight: both are listed" 'docs/2-other/plan.md' "$(plan status 2>&1)"

finish
