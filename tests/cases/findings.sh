#!/usr/bin/env bash
# findings.sh on a small repository with two tracked reproduction test classes.
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

REPO="$WORK/repo"
TASK="$REPO/docs/12-add-widget"
FILE="$TASK/review/findings.md"
FINDINGS="$R/scripts/findings/findings.sh"
mkdir -p "$TASK" "$REPO/src/test"
cat > "$REPO/src/test/CreateWidgetTest.java" <<'EOF'
class CreateWidgetTest {}
EOF
repo "$REPO"
# This reproduction is deliberately untracked and named unlike its class. The writer uses the same
# tracked/untracked, basename-or-source lookup as plan acceptance.
cat > "$REPO/src/test/contract_checks.py" <<'EOF'
class SharedContractTest:
    pass
EOF
findings() { (cd "$REPO" && bash "$FINDINGS" "$@"); }

echo "-- init and the empty file"
check_match "init creates the conventional file" 'created: .*docs/12-add-widget/review/findings.md$' \
  "$(findings init "$TASK" --title "Add a widget")"
check_match "init writes the review title" '^# Review: Add a widget$' "$(cat "$FILE")"
check_match "init writes the clean opening" '^\*\*Nothing open\.\*\*$' "$(cat "$FILE")"
check_ok "check accepts the empty file" findings check "$TASK"
check_fails "init refuses to replace an existing file" findings init "$TASK" --title Replacement

echo "-- bugs require a tracked disabled reproduction"
cp "$FILE" "$WORK/before"
check_fails "add-bug refuses a missing test argument" findings add-bug "$TASK" \
  --module api --summary "an empty name is accepted" --given state --when action --then result \
  --actual actual --fix validate --target src/CreateWidget.java
check "a rejected add changes no bytes" "$(cat "$WORK/before")" "$(cat "$FILE")"
check_fails "add-bug refuses Test none" findings add-bug "$TASK" \
  --module api --summary symptom --given state --when action --then result --actual actual \
  --test none --fix validate --target src/CreateWidget.java
check_fails "add-bug refuses an untracked test class" findings add-bug "$TASK" \
  --module api --summary symptom --given state --when action --then result --actual actual \
  --test MissingTest#reproduces --fix validate --target src/CreateWidget.java
check "all rejected bugs leave the file unchanged" "$(cat "$WORK/before")" "$(cat "$FILE")"
check_fails "a module cannot inject a broken code span" findings add-bug "$TASK" \
  --module 'bad`module' --summary symptom --given state --when action --then result --actual actual \
  --test CreateWidgetTest#reproduces --fix validate --target src/CreateWidget.java
check_fails "a summary cannot close its Markdown heading" findings add-bug "$TASK" \
  --module api --summary 'bad ** heading' --given state --when action --then result --actual actual \
  --test CreateWidgetTest#reproduces --fix validate --target src/CreateWidget.java
check "injected Markdown leaves the file unchanged" "$(cat "$WORK/before")" "$(cat "$FILE")"

check_match "add-bug records its test reference" '^added bug: CreateWidgetTest#rejectsEmptyName$' \
  "$(findings add-bug "$TASK" --module api --summary "an empty name is accepted" \
    --given "a create request with an empty name" --when "the request is submitted" \
    --then "validation rejects it" --actual "a widget is created" \
    --test CreateWidgetTest#rejectsEmptyName --fix "validate the command" --target src/CreateWidget.java)"
check_match "the writer supplies the disabled marker" \
  '^- \*\*Test\*\* `CreateWidgetTest#rejectsEmptyName`, disabled$' "$(cat "$FILE")"
check_match "the opening count follows the new bug" '^\*\*1 bug open\.\*\*$' "$(cat "$FILE")"
check_ok "the bug file validates" findings check "$TASK"
cp "$FILE" "$WORK/one-bug"
check_fails "the writer refuses a duplicate defect test key" findings add-bug "$TASK" \
  --module api --summary "the same reproduction is filed twice" --given state --when action --then result \
  --actual actual --test CreateWidgetTest#rejectsEmptyName --fix deduplicate --target src/CreateWidget.java
check "a duplicate defect key changes no bytes" "$(cat "$WORK/one-bug")" "$(cat "$FILE")"
check "a rejected mutation leaves no temporary files" 0 \
  "$(find "$TASK/review" -name '*.findings-*' | wc -l | tr -d ' ')"

echo "-- critical findings have their own schema"
check_fails "a critical bug also requires a test" findings add-critical "$TASK" --module shared \
  --summary "two modules read a contract differently" --kind bug --measured "two readers, two meanings" \
  --grows-because "each consumer copies one meaning" --breaks-as "the second consumer rejects data" \
  --fix "share the decoder" --target src/Decoder.java
check_fails "a non-bug critical rejects a test" findings add-critical "$TASK" --module shared \
  --summary "validation is copied" --kind refactoring-candidate --measured "four copies" \
  --grows-because "each command adds one" --breaks-as "a command accepts invalid data" \
  --test SharedContractTest#reproduces --fix "share validation" --target src/Validation.java
check_match "a critical refactoring candidate is added" '^added critical finding$' \
  "$(findings add-critical "$TASK" --module shared --summary "validation is copied" \
    --kind refactoring-candidate --measured "four commands repeat it" \
    --grows-because "each command adds another copy" --breaks-as "one command accepts invalid data" \
    --fix "share validation" --target src/Validation.java)"
check_match "critical uses Measured rather than bug observations" \
  '^- \*\*Measured\*\* four commands repeat it$' "$(cat "$FILE")"
check_no_match "a non-bug critical carries no disabled test" 'SharedContractTest#reproduces' "$(cat "$FILE")"
cp "$FILE" "$WORK/one-critical"
check_fails "the writer refuses a duplicate Critical heading key" findings add-critical "$TASK" --module shared \
  --summary "validation is copied" --kind deferred-change --measured "four commands" \
  --grows-because "each command adds another copy" --breaks-as "one command rejects valid data" \
  --fix "share validation" --target src/Validation.java
check "a duplicate Critical key changes no bytes" "$(cat "$WORK/one-critical")" "$(cat "$FILE")"

check_ok "a critical bug finds an untracked class from source text" findings add-critical "$TASK" --module shared \
  --summary "two modules read a contract differently" --kind bug --measured "two readers, two meanings" \
  --grows-because "each consumer copies one meaning" --breaks-as "the second consumer rejects data" \
  --test SharedContractTest#readsTheSameContract --fix "share the decoder" --target src/Decoder.java
check_match "critical bug renders its test" \
  '^- \*\*Test\*\* `SharedContractTest#readsTheSameContract`, disabled$' "$(cat "$FILE")"

echo "-- table commands assign IDs, escape pipes, and restore section order"
check_match "performance starts at PX01" '^added: PX01$' "$(findings add-performance "$TASK" \
  --module api --test WidgetLoadTest#loads --threshold 'p95 | 100 ms' --figure 'p95 | 140 ms')"
check_match "deferred starts at DX01" '^added: DX01$' "$(findings add-deferred "$TASK" \
  --module api --what "return validation details" --why "all 8 invalid requests return one generic error")"
check_match "refactoring starts at RX01" '^added: RX01$' "$(findings add-refactoring "$TASK" \
  --module api --what "share validation" --why "all 4 commands repeat the same checks")"
check_match "the next refactoring gets RX02" '^added: RX02$' "$(findings add-refactoring "$TASK" \
  --module ui --what "name the formatter" --why "both pages repeat the same measured branch")"
headings="$(grep '^## ' "$FILE" | tr '\n' '|')"
check "sections are in fixed order despite reverse additions" \
  '## Critical|## Bug|## Refactoring candidate|## Deferred change|## Performance|' "$headings"
check_match "table pipes are escaped" 'p95 \\| 100 ms.*p95 \\| 140 ms' "$(cat "$FILE")"
check_match "the opening line counts every open kind" \
  '^\*\*2 critical findings, 1 bug, 2 refactoring candidates, 1 deferred change, 1 performance finding open\.\*\*$' \
  "$(cat "$FILE")"
check_ok "the complete writer output validates" findings check "$TASK"

echo "-- closing entries recomputes counts"
check_match "close records a numbered status" '^closed: RX01$' \
  "$(findings close "$TASK" RX01 --status done --reason 'task 14 | directly')"
check_match "the row carries the rendered and escaped status" \
  '^\| RX01 \| done · task 14 \\\| directly \|' "$(cat "$FILE")"
check_fails "an already closed row is refused" findings close "$TASK" RX01 --status done --reason directly
check_match "close-bug identifies a block by its reproduction" '^closed bug: CreateWidgetTest#rejectsEmptyName$' \
  "$(findings close-bug "$TASK" --test CreateWidgetTest#rejectsEmptyName --status done --reason 'fix 4')"
check_match "the block status follows Fix" '^- \*\*Status\*\* done · fix 4$' "$(cat "$FILE")"
check_fails "an already closed bug is refused" findings close-bug "$TASK" \
  --test CreateWidgetTest#rejectsEmptyName --status withdrawn --reason disproved
check_match "a non-bug critical closes by its stable heading" '^closed critical: shared — validation is copied$' \
  "$(findings close-critical "$TASK" --module shared --summary 'validation is copied' \
    --status done --reason 'rework 3')"
check_fails "an already closed critical is refused" findings close-critical "$TASK" --module shared \
  --summary 'validation is copied' --status withdrawn --reason disproved
check_match "closed blocks and rows leave the opening count" \
  '^\*\*1 critical finding, 1 refactoring candidate, 1 deferred change, 1 performance finding open\.\*\*$' \
  "$(cat "$FILE")"
check_ok "the closed file validates" findings check "$TASK"

echo "-- check covers the manual fallback"
cp "$FILE" "$WORK/manual.md"
sed 's/SharedContractTest#readsTheSameContract/CreateWidgetTest#rejectsEmptyName/' "$FILE" > "$WORK/duplicate-test.md"
check_match "check reports a duplicate manual defect key" \
  "Test reference 'CreateWidgetTest#rejectsEmptyName' is already used" \
  "$(findings check "$WORK/duplicate-test.md" 2>&1)"
sed 's/two modules read a contract differently/validation is copied/' "$FILE" > "$WORK/duplicate-critical.md"
check_match "check reports a duplicate manual Critical key" 'Critical heading is already used' \
  "$(findings check "$WORK/duplicate-critical.md" 2>&1)"
git -C "$REPO" rm -q src/test/CreateWidgetTest.java
check_ok "a closed bug stays valid after its old test class is removed" findings check "$TASK"
sed 's/`SharedContractTest#readsTheSameContract`, disabled/none/' "$FILE" > "$WORK/bad-test.md"
check_match "check reports Test none in a hand-written file" 'expected `TestClass#method`, disabled' \
  "$(findings check "$WORK/bad-test.md" 2>&1)"
sed 's/| RX02 | open |/| RX02 | finished |/' "$FILE" > "$WORK/bad-status.md"
check_match "check reports a bad table status" "RX02 has invalid Status 'finished'" \
  "$(findings check "$WORK/bad-status.md" 2>&1)"
sed 's/^\*\*.*/**Nothing open.**/' "$FILE" > "$WORK/stale.md"
check_match "check reports a stale manual count" 'opening count is stale' "$(findings check "$WORK/stale.md" 2>&1)"
sed 's/| RX02 | open | `ui` |/| RX02 | open |  |/' "$FILE" > "$WORK/empty-cell.md"
check_match "check reports an empty manual table cell" 'Refactoring candidate row has an empty cell' \
  "$(findings check "$WORK/empty-cell.md" 2>&1)"
sed 's/| RX02 | open | `ui` |/| RX02 | open | ui |/' "$FILE" > "$WORK/bare-module.md"
check_match "check requires a backticked table module" 'expected `module`' \
  "$(findings check "$WORK/bare-module.md" 2>&1)"
sed 's/SharedContractTest#readsTheSameContract/MissingTest#readsTheSameContract/' "$FILE" > "$WORK/missing-class.md"
check_match "check resolves manual test references against the non-ignored tree" \
  "no non-ignored MissingTest class exists outside docs/" \
  "$(findings check "$WORK/missing-class.md" 2>&1)"

finish
