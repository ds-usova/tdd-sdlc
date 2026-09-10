#!/usr/bin/env bash
# The two PreToolUse hooks that refuse a command: a commit message naming a framework id, and an
# archive of a task whose stabilization stubs still carry their marker. Each is fed the JSON the
# harness sends and either prints a deny decision or prints nothing.
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

COMMIT="$R/scripts/hooks/deny-plan-step-in-commit-message.sh"
ARCHIVE="$R/scripts/hooks/deny-archive-with-stubs.sh"
P="$(fixture hooks/good proj)"; repo "$P"

# hook SCRIPT COMMAND -> prints "deny: <reason>" or "allow"
hook() {
  local out
  out="$(printf '{"tool_input":{"command":%s},"cwd":%s}' "$(printf '%s' "$2" | jq -Rs .)" \
    "$(printf '%s' "$P" | jq -Rs .)" | bash "$1")"
  if [ -z "$out" ]; then echo allow
  else echo "deny: $(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason')"; fi
}

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
            'git commit -m "closes BC02"|BC02'; do
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
