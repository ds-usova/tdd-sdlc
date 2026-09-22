#!/usr/bin/env bash
# The two PreToolUse hooks that refuse a command: a commit message naming a framework id, and an
# archive of a task whose stabilization stubs still carry their marker. Each is fed the JSON the
# harness sends and either prints a deny decision or prints nothing.
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

COMMIT="$R/scripts/hooks/deny-plan-step-in-commit-message.sh"
ARCHIVE="$R/scripts/hooks/deny-archive-with-stubs.sh"
ASSIGN="$R/scripts/hooks/validate-agent-assignment.sh"
P="$(fixture hooks/good proj)"; repo "$P"

# hook SCRIPT COMMAND -> prints "deny: <reason>" or "allow"
hook() {
  local out
  out="$(printf '{"tool_input":{"command":%s},"cwd":%s}' "$(printf '%s' "$2" | jq -Rs .)" \
    "$(printf '%s' "$P" | jq -Rs .)" | bash "$1")"
  if [ -z "$out" ]; then echo allow
  else echo "deny: $(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason')"; fi
}

agent_hook() {
  local type="$1" description="$2" prompt="$3"
  printf '{"tool_name":"Agent","tool_input":{"subagent_type":%s,"description":%s,"prompt":%s},"cwd":%s}' \
    "$(printf '%s' "$type" | jq -Rs .)" "$(printf '%s' "$description" | jq -Rs .)" \
    "$(printf '%s' "$prompt" | jq -Rs .)" "$(printf '%s' "$P" | jq -Rs .)" | bash "$ASSIGN"
}

# --- the assignment hook
out="$(agent_hook stabilization-step 'widget stabilization' \
  $'Apply docs/4-widget/mod/plan.md.\n- [ ] ST01 — stabilize')"
check "a framework assignment is allowed" allow "$(printf '%s' "$out" | jq -r \
  '.hookSpecificOutput.permissionDecision')"
header="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.prompt' | head -4)"
check_match "the hook prepends the workflow" '^Workflow: implement-plan$' "$header"
check_match "the hook prepends the work file" '^Work file: docs/4-widget/mod/plan.md$' "$header"
check_match "the hook records the assigned item" '^Assigned items: ST01$' "$header"
check_match "the Agent description becomes the basis" '^Assignment basis: widget stabilization$' "$header"

out="$(agent_hook implement-plan-module 'whole plan' 'Run without naming a work file.')"
check "a missing work file is denied" deny "$(printf '%s' "$out" | jq -r \
  '.hookSpecificOutput.permissionDecision')"
check_match "the denial tells the model what is missing" 'name the work file' "$(printf '%s' "$out" | jq -r \
  '.hookSpecificOutput.permissionDecisionReason')"

out="$(agent_hook tdd-unit-red-phase-step 'one test' 'Write docs/4-widget/mod/plan.md without an RU item.')"
check "a plan step without a matching id is denied" deny "$(printf '%s' "$out" | jq -r \
  '.hookSpecificOutput.permissionDecision')"

out="$(agent_hook tdd-unit-red-phase-step 'reproduction brief' 'Write one focused regression test.')"
small_header="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.prompt' | head -4)"
check_match "an unplanned reproduction records no work file" '^Work file: none$' "$small_header"
check_match "an unplanned reproduction records no items" '^Assigned items: none$' "$small_header"

out="$(agent_hook grill-design 'review' 'Review this design.')"
check "an agent without implementation items is ignored" "" "$out"

mkdir -p "$P/docs/5-fix" "$P/docs/6-upgrade/module-a" "$P/docs/7-rework/module-a"
cp "$TESTS_DIR/fixtures/fix/good/docs/3-double-charge/fix.md" "$P/docs/5-fix/fix.md"
cp "$TESTS_DIR/fixtures/upgrade/good/docs/3-bump-libs/module-a/steps.md" \
  "$P/docs/6-upgrade/module-a/steps.md"
cp "$TESTS_DIR/fixtures/rework/good/docs/3-widget/mod/steps.md" \
  "$P/docs/7-rework/module-a/steps.md"
out="$(agent_hook fix-bug-module 'whole work file' 'Apply docs/5-fix/fix.md.')"
fix_header="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.prompt' | head -4)"
check_match "a bug fix records its workflow" '^Workflow: fix-bug$' "$fix_header"
check_match "a bug fix records every open item" '^Assigned items: FS01 FR01 FG01$' "$fix_header"
out="$(agent_hook upgrade-deps-module 'whole work file' \
  'Apply docs/6-upgrade/module-a/steps.md for docs/6-upgrade/upgrade.md.')"
upgrade_header="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.prompt' | head -4)"
check_match "an upgrade steps file records its workflow" '^Workflow: upgrade-deps$' "$upgrade_header"
check_match "an upgrade records every open item" '^Assigned items: UP05$' "$upgrade_header"
out="$(agent_hook rework-module 'whole work file' \
  'Apply docs/7-rework/module-a/steps.md for docs/7-rework/rework.md.')"
rework_header="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.prompt' | head -4)"
check_match "a rework steps file records its workflow" '^Workflow: rework$' "$rework_header"
check_match "a rework omits abandoned items" '^Assigned items: WK01 WK03$' "$rework_header"

# --- the commit-message hook
# Each pair is a command and the ids the hook must name for it, separated by a pipe.
for pair in "git commit -m 'Implements ST01 and GU07'|ST01, GU07" \
            'git commit -m "closes DN03"|DN03' \
            "git commit -m'RL12 resolved'|RL12" \
            'git commit --message="see BB01"|BB01' \
            'git commit --message=FS01|FS01' \
            'git -C sub commit -m "UP01"|UP01' \
            'git add -A && git commit -m "after WK02"|WK02' \
            "git commit -am 'RQ01 met'|RQ01" \
            'git commit -m "scripts by hand, CV01"|CV01' \
            'git commit -m "closes BC02"|BC02' \
            'git commit -m "measured PM01"|PM01' \
            'git commit -m "tuned PX01, closes BP01"|PX01, BP01'; do
  c="${pair%|*}"; ids="${pair##*|}"
  check_match "refused: $c" "^deny: .*names $ids\\. " "$(hook "$COMMIT" "$c")"
done
for c in 'git commit -m "Q3 planning, A4 paper, P1 incident, D1 done"' \
         'git commit -m "rq01 is not an id"' \
         'git commit -m "ST1 is one digit"' \
         'git commit -m "aST01b is inside a word"' \
         'git commit -m "Fix the widget" -- docs/7-add-widget/plan.md' \
         'git log --grep ST01' \
         'echo ST01 > note.txt'; do
  check "allowed: $c" allow "$(hook "$COMMIT" "$c")"
done
check_match "a message file is read" '^deny: .*names RF02\.' "$(hook "$COMMIT" 'git commit -F msg.txt')"
check_match "a --file= message file is read" '^deny: .*names RF02\.' "$(hook "$COMMIT" 'git commit --file=msg.txt')"
check_match "a heredoc body is read" '^deny: .*names AT01\.' \
  "$(hook "$COMMIT" $'git commit -F - <<EOF\nRetry\n\nsee AT01\nEOF')"
check_match "each id is named once" 'names DF01, DF02\.' \
  "$(hook "$COMMIT" 'git commit -m "DF01 DF02 DF01"')"
check "an empty command is ignored" allow "$(hook "$COMMIT" '')"

# --- the archive hook
(cd "$P" && bash "$R/scripts/plan/plan.sh" stub src/Widget.java --file docs/4-widget/mod/plan.md \
  --log docs/4-widget/mod/plan-log.md > /dev/null)
check_match "the fixture's log records the stub" '^- `src/Widget.java`$' "$(cat "$P/docs/4-widget/mod/plan-log.md")"
check_match "mv into docs/implemented with a marker left is refused" \
  '^deny: The task is not finished.*plan-log.md: .*Widget' "$(hook "$ARCHIVE" 'mv docs/4-widget docs/implemented/')"
check_match "git mv is refused the same way" '^deny: ' "$(hook "$ARCHIVE" 'git mv docs/4-widget docs/implemented/4-widget')"
check_match "a chained archive is refused" '^deny: ' "$(hook "$ARCHIVE" 'git add -A && mv docs/4-widget/ docs/implemented/')"
check "a move elsewhere is not the hook's business" allow "$(hook "$ARCHIVE" 'mv docs/4-widget docs/old/')"
check "a commit is not the hook's business" allow "$(hook "$ARCHIVE" 'git commit -m "archive docs/implemented"')"
check "a directory the tree does not hold is ignored" allow "$(hook "$ARCHIVE" 'mv docs/9-none docs/implemented/')"
overlay hooks/clean "$P"
check "the archive is allowed once the marker is gone" allow "$(hook "$ARCHIVE" 'mv docs/4-widget docs/implemented/')"

finish
