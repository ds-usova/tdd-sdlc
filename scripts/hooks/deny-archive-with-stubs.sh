#!/usr/bin/env bash
# PreToolUse hook on Bash: refuses to move a task directory into docs/implemented/ while a file the
# task's stabilization stubbed still carries the stub marker. The check itself is `plan.sh stubs`,
# run per plan log the directory holds; this script only recognises the archive command and turns
# the verdict into a deny. A consumer without jq gets a hook that is silent, never one that fails.
set -u

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

input="$(cat)"
command_text="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
[ -n "$command_text" ] || exit 0

# An archive is `mv` or `git mv` whose destination is under docs/implemented. Anything else - a
# commit, a build, a move of some other file - is not this hook's business.
printf '%s' "$command_text" | grep -Eq '(^|[;&|][[:space:]]*)(git[[:space:]]+)?mv[[:space:]]' || exit 0
printf '%s' "$command_text" | grep -Eq 'docs/implemented(/|[[:space:]]|$)' || exit 0

# The source is every argument that looks like a task directory: docs/<n>-<name>, absolute or not.
sources=()
while IFS= read -r tok; do
    [ -n "$tok" ] && sources+=("$tok")
done < <(printf '%s' "$command_text" | tr ' \t' '\n\n' | tr -d '"'"'" \
    | grep -E '(^|/)docs/[0-9]+-[^/]+/?$' | grep -Ev 'docs/implemented/')
[ "${#sources[@]}" -gt 0 ] || exit 0

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plan_sh="$script_dir/../plan/plan.sh"
[ -f "$plan_sh" ] || exit 0

[ -n "$cwd" ] && cd "$cwd" 2>/dev/null

problems=""
for src in "${sources[@]}"; do
    [ -d "$src" ] || continue
    while IFS= read -r log; do
        plan="$(dirname "$log")/plan.md"
        [ -f "$plan" ] || continue
        # One line per file still carrying the marker, prefixed with the log it was recorded in.
        out="$(bash "$plan_sh" stubs --file "$plan" --log "$log" 2>&1)" \
            || problems="${problems}$(printf '%s' "$out" | sed -n 's/^[[:space:]]\{1,\}//p' | sed "s|^|${log}: |" | tr '\n' ';')"
    done < <(find "$src" -maxdepth 2 -name 'plan-log.md' -type f | sort)
done

[ -n "$problems" ] || exit 0

detail="$(printf '%s' "$problems" | sed 's/;$//; s/;/; /g')"
reason="The task is not finished: a method stabilization stubbed still carries its stub marker, so it was never implemented — ${detail}. Implement it, or remove the marker where the method is deliberately left as a stub, then archive. See templates/stabilizing.md."
jq -nc --arg reason "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
