#!/usr/bin/env bash
# PreToolUse hook on Agent: derives and prepends a checked assignment header for framework
# implementation agents. Other agents pass unchanged.
set -u

command -v jq >/dev/null 2>&1 || exit 0
input="$(cat)"

tool="$(printf '%s' "$input" | jq -r '.tool_name // ""' | tr -d '\r')"
[ "$tool" = "Agent" ] || exit 0
agent="$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // ""' | tr -d '\r')"
agent="${agent##*:}"

case "$agent" in
    implement-plan-module|stabilization-step|tdd-unit-red-phase-step|tdd-integration-red-phase-step|\
    tdd-system-red-phase-step|tdd-unit-green-phase-step|tdd-integration-green-phase-step|\
    tdd-system-green-phase-step|fix-bug-module|rework-module|upgrade-deps-module) ;;
    *) exit 0 ;;
esac

prompt="$(printf '%s' "$input" | jq -r '.tool_input.prompt // ""' | tr -d '\r')"
description="$(printf '%s' "$input" | jq -r '.tool_input.description // ""' | tr -d '\r\n')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // ""' | tr -d '\r' | tr '\134' '/')"
[ -n "$prompt" ] || reason="Assignment header could not be derived: the Agent prompt is empty."

repo_root="$(cd "${cwd:-.}" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || repo_root="${cwd:-.}"
repo_root="$(printf '%s' "$repo_root" | tr '\134' '/')"

work_file=""
paths="$(printf '%s' "$prompt" | tr '\134' '/' \
    | grep -Eo '(^|[^A-Za-z0-9_])docs/[0-9]+-[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*'\
'/(plan|fix|steps|rework|upgrade|bug)\.md' \
    | sed -E 's|^.*(docs/)|\1|' | awk '!seen[$0]++')"

pick_path() {
    local pattern="$1"
    printf '%s\n' "$paths" | grep -E "$pattern" | head -1
}

workflow=""
case "$agent" in
    implement-plan-module|stabilization-step|tdd-unit-green-phase-step|\
    tdd-integration-green-phase-step|tdd-system-green-phase-step)
        workflow="implement-plan"; work_file="$(pick_path '/plan\.md$')" ;;
    fix-bug-module)
        workflow="fix-bug"; work_file="$(pick_path '/(shared/)?fix\.md$')" ;;
    rework-module)
        workflow="rework"; work_file="$(pick_path '/steps\.md$')"
        [ -n "$work_file" ] || work_file="$(pick_path '/rework\.md$')" ;;
    upgrade-deps-module)
        workflow="upgrade-deps"; work_file="$(pick_path '/steps\.md$')"
        [ -n "$work_file" ] || work_file="$(pick_path '/upgrade\.md$')" ;;
    tdd-unit-red-phase-step|tdd-integration-red-phase-step|tdd-system-red-phase-step)
        if work_file="$(pick_path '/plan\.md$')" && [ -n "$work_file" ]; then
            workflow="implement-plan"
        elif work_file="$(pick_path '/(shared/)?fix\.md$')" && [ -n "$work_file" ]; then
            workflow="fix-bug"
        elif work_file="$(pick_path '/rework\.md$|/steps\.md$')" && [ -n "$work_file" ]; then
            if printf '%s' "$prompt" | grep -qi 'upgrade'; then workflow="upgrade-deps"
            else workflow="rework"; fi
        else
            workflow="small-change"; work_file="none"
        fi ;;
esac

reason="${reason:-}"
if [ "$work_file" != "none" ]; then
    [ -n "$work_file" ] || reason="Assignment header could not be derived: name the work file in the Agent prompt."
    if [ -z "$reason" ]; then
        case "$work_file" in
            docs/*) ;;
            *) reason="Assignment header could not be derived: the work file must be under docs/." ;;
        esac
    fi
    if [ -z "$reason" ] && [ ! -f "$repo_root/$work_file" ]; then
        reason="Assignment header could not be derived: $work_file does not exist."
    fi
fi

prefix=""
case "$agent" in
    stabilization-step) prefix="ST" ;;
    tdd-unit-red-phase-step) prefix="RU" ;;
    tdd-integration-red-phase-step) prefix="RI" ;;
    tdd-system-red-phase-step) prefix="RS" ;;
    tdd-unit-green-phase-step) prefix="GU" ;;
    tdd-integration-green-phase-step) prefix="GI" ;;
    tdd-system-green-phase-step) prefix="GS" ;;
esac

items=""
if [ "$work_file" != "none" ] && [ -f "$repo_root/$work_file" ]; then
    if [ -n "$prefix" ]; then
        items="$(printf '%s\n' "$prompt" \
            | sed -n -E "s/^- \[[ x]\] (${prefix}[0-9]+) .*/\1/p" \
            | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/ $//')"
    else
        items="$(grep -Ev 'abandoned —|kept back —' "$repo_root/$work_file" \
            | sed -n -E 's/^- \[ \] ([A-Z]+[0-9]+) .*/\1/p' \
            | tr '\n' ' ' | sed 's/ $//')"
    fi
fi

if [ -z "$reason" ] && [ -z "$items" ]; then
    case "$agent" in
        tdd-unit-red-phase-step|tdd-integration-red-phase-step|tdd-system-red-phase-step)
            if [ "$workflow" = "implement-plan" ]; then
                reason="Assignment header could not be derived: no assigned item IDs match $agent."
            else
                items="none"
            fi ;;
        *)
            reason="Assignment header could not be derived: no assigned item IDs match $agent." ;;
    esac
fi

if [ -z "$reason" ] && [ "$items" != "none" ] && [ -f "$repo_root/$work_file" ]; then
    for id in $items; do
        if ! grep -Eq "^- \[[ x]\] ${id} ([·—]|$)" "$repo_root/$work_file"; then
            reason="Assignment header could not be derived: $id is not an item in $work_file."
            break
        fi
    done
fi

if [ -n "$reason" ]; then
    jq -nc --arg reason "$reason" '
        {hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
                              permissionDecisionReason: $reason}}'
    exit 0
fi

[ -n "$description" ] || description="$agent assignment"
header="Workflow: $workflow
Work file: $work_file
Assigned items: $items
Assignment basis: $description"
normalized="$header

$prompt"

printf '%s' "$input" | jq -c --arg prompt "$normalized" '
    {hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        updatedInput: (.tool_input + {prompt: $prompt})
    }}'
