#!/usr/bin/env bash
# design.sh and design-parse.awk: every subcommand on the task in tests/fixtures/design/good, in the
# shape design-task writes. Each refusal is a bad/<what-is-wrong> overlay; see the fixtures' README.
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
D="$R/scripts/design/design.sh"

# bad_task NAME - the task directory of a copy of good with bad/NAME laid over it, as a repo.
bad_task() { printf '%s\n' "$(variant design "$1")/docs/1-add-widget"; }
in_dir() { local d="$1"; shift; (cd "$d" && "$@"); }

# --- a settled task, every subcommand ----------------------------------------------------------

P="$(fixture design/good repo)"; repo "$P"
T="$P/docs/1-add-widget"
out="$(bash "$D" validate "$T" 2>&1)"
check_rc "validate: settled task exits 0" 0 bash "$D" validate "$T"
check_match "validate: prints the size line" "^2 requirements, 2 scenarios, 2 decisions, 1 solution sections, 12 concerns, 2 findings, no problems$" "$out"
check_ok "validate: addressed by one of its files" bash "$D" validate "$T/design-log.md"
printf '%s\n' "" "## Caveats" "" "- **CV01:** design.sh absent at the grill. Findings checked by hand." >> "$T/design-log.md"
check_ok "validate: a Caveats section in the design log still validates" bash "$D" validate "$T"
check_match "validate: and the size line is unchanged" "^2 requirements, 2 scenarios, 2 decisions, 1 solution sections, 12 concerns, 2 findings, no problems$" "$(bash "$D" validate "$T" 2>&1)"
check_ok "validate: the single task in flight is found from the repo" in_dir "$P" bash "$D" validate
check_ok "settled: no must-decide left" bash "$D" settled "$T"
check "status: counts per basis" "$(printf 'decided\t2\ntotal\t2')" "$(bash "$D" status "$T")"
check "show: question, Answer and Basis of one entry" \
  "$(printf -- '- **DN04:** What happens when the same widget is created twice concurrently?\n  - Answer: One request wins with 200; the other returns 409.\n  - Basis: decided (user, 2026-07-30)')" \
  "$(bash "$D" show DN04 "$T")"
check "show: several IDs print in order, blank-line separated" \
  "$(printf '%s\n' \
    "- **DN01:** Must a widget's name be unique, and what does a duplicate return?" \
    "  - Answer: Unique per parent. A duplicate returns 409." \
    "  - Basis: decided (user, 2026-07-30)" \
    "" \
    "- **DN04:** What happens when the same widget is created twice concurrently?" \
    "  - Answer: One request wins with 200; the other returns 409." \
    "  - Basis: decided (user, 2026-07-30)")" \
  "$(bash "$D" show DN01 DN04 "$T")"
check_fails "show: an unknown ID fails" bash "$D" show DN99 "$T"
check_rc "unknown command exits 2" 2 bash "$D" frobnicate "$T"

# --- approve / approved --------------------------------------------------------------------------

check_fails "approved: no Approved line yet" bash "$D" approved "$T"
check_match "approve: writes who, date and hash" '^\*\*Approved:\*\* the user, [0-9]{4}-[0-9]{2}-[0-9]{2}, [0-9a-f]{12}$' "$(bash "$D" approve "the user" "$T")"
check "approve: the Format line stays on line 3" "**Format:** 2" "$(sed -n 3p "$T/spec.md")"
check_match "approve: the Approved line sits under it, on line 4" \
  '^\*\*Approved:\*\* the user, [0-9]{4}-[0-9]{2}-[0-9]{2}, [0-9a-f]{12}$' "$(sed -n 4p "$T/spec.md")"
check_ok "approved: passes once written" bash "$D" approved "$T"
# The edit after approval is the behaviour under test: an edit below the headings.
sed 's/^Allow API clients to create widgets\./Allow API clients to create and list widgets./' \
  "$T/spec.md" > "$WORK/tmp" && mv "$WORK/tmp" "$T/spec.md"
check_match "approved: an edit below the headings makes it stale" "predates an edit" "$(bash "$D" approved "$T" 2>&1)"

# --- settled fails on an open decision -----------------------------------------------------------

T="$(bad_task open-dn07)"
check_ok "validate: a must-decide is not a problem" bash "$D" validate "$T"
out="$(bash "$D" settled "$T" 2>&1)"
check_rc "settled: exits 1 with a must-decide" 1 bash "$D" settled "$T"
check_match "settled: names the open entry" $'^  DN07\tWho may create' "$out"
check_match "status: counts the must-decide" $'^must-decide\t1$' "$(bash "$D" status "$T")"
T="$(bad_task must-decide-with-answer)"
check_match "validate: a must-decide carrying an Answer" "DN07 is must-decide but carries an Answer" "$(bash "$D" validate "$T")"

# --- validate: the format line ----------------------------------------------------------------------

T="$(bad_task no-format-line)"
out="$(bash "$D" validate "$T" 2>&1)"
check_rc "validate: no Format line exits 1" 1 bash "$D" validate "$T"
check_match "validate: names the missing Format line" 'spec.md: no \*\*Format:\*\* line - written before format 2' "$out"
T="$(bad_task format-1)"
check_match "validate: a foreign format number" 'spec.md: \*\*Format:\*\* 1, and this plugin reads format 2' "$(bash "$D" validate "$T" 2>&1)"

# --- validate: duplicate ids and placeholders --------------------------------------------------------

T="$(bad_task duplicate-ids)"
out="$(bash "$D" validate "$T" 2>&1)"
check_match "validate: duplicate RQ" "^spec: RQ01 is defined twice$" "$out"
check_match "validate: duplicate AC" "^spec: AC01 is defined twice$" "$out"
check_match "validate: duplicate DN" "^spec: DN01 is defined twice$" "$out"

T="$(bad_task placeholders)"
out="$(bash "$D" validate "$T" 2>&1)"
check_rc "validate: placeholders exit 1" 1 bash "$D" validate "$T"
check_match "validate: a TBD requirement" "^spec: RQ02 states nothing$" "$out"
check_match "validate: a decided with nothing after it" "^spec: DN01 is 'decided' with nothing after it" "$out"
check_match "validate: a findings row with an empty cell" "^design log: DF02 leaves a cell empty" "$out"
check_match "validate: a concern with no why" "^design log: concern 'recovery' has a verdict with no why$" "$out"

# --- validate: the design and the log -------------------------------------------------------------------

T="$(bad_task design-gaps)"
out="$(bash "$D" validate "$T" 2>&1)"
check_match "validate: a source file under Proposed Solution" 'design: Proposed Solution names a source file, `WidgetController.java`' "$out"
check_match "validate: no Affected Modules line" "^design: no '\*\*Affected Modules:\*\*' line" "$out"
check_match "validate: a grill-design concern with no row" "^design log: grill-design ran but Concerns has no 'concurrency' row$" "$out"
check_match "validate: a decided entry with no Decision Bases line" "^design log: DN04 is decided but Decision Bases has no entry" "$out"
rm "$T/design.md"   # an overlay cannot remove a file
check_match "validate: no design beside the spec" "^no design.md beside the spec$" "$(bash "$D" validate "$T" 2>&1)"

# --- two tasks in flight --------------------------------------------------------------------------------

P="$(variant design second-task-in-flight)"
out="$(in_dir "$P" bash "$D" settled 2>&1)"
check_rc "no task given with two in flight exits 2" 2 in_dir "$P" bash "$D" settled
check_match "and lists the first task" '^  .*/docs/1-add-widget$' "$out"
check_match "and lists the second task" '^  .*/docs/9-second$' "$out"

finish
