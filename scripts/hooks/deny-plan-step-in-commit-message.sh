#!/usr/bin/env bash
# Bash port of the plugin's deny-plan-step-in-commit-message hook.
# A consumer without jq gets a hook that is silent, never one that fails every matched tool call.
set -u

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

input="$(cat)"

command_text="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"

if [ -z "$command_text" ]; then
    exit 0
fi

if ! printf '%s' "$command_text" | grep -Eiq '^[[:space:]]*git[[:space:]]+commit\b'; then
    exit 0
fi

# Only the message is searched. A pathspec may legitimately name a plan file, so the ids are looked for
# where a reader would meet them: -m '...', -m "...", --message=...
messages=()

while IFS= read -r line; do
    [ -n "$line" ] && messages+=("$line")
done < <(printf '%s' "$command_text" | awk '
    {
        s = $0
        while (match(s, /-m[ \t]+'"'"'[^'"'"']*'"'"'/)) {
            seg = substr(s, RSTART, RLENGTH)
            sub(/^-m[ \t]+'"'"'/, "", seg)
            sub(/'"'"'$/, "", seg)
            print seg
            s = substr(s, RSTART + RLENGTH)
        }
    }
')

while IFS= read -r line; do
    [ -n "$line" ] && messages+=("$line")
done < <(printf '%s' "$command_text" | awk '
    {
        s = $0
        while (match(s, /-m[ \t]+"[^"]*"/)) {
            seg = substr(s, RSTART, RLENGTH)
            sub(/^-m[ \t]+"/, "", seg)
            sub(/"$/, "", seg)
            print seg
            s = substr(s, RSTART + RLENGTH)
        }
    }
')

while IFS= read -r line; do
    [ -n "$line" ] && messages+=("$line")
done < <(printf '%s' "$command_text" | awk '
    {
        s = $0
        while (match(s, /--message=[^ \t]+/)) {
            seg = substr(s, RSTART, RLENGTH)
            sub(/^--message=/, "", seg)
            print seg
            s = substr(s, RSTART + RLENGTH)
        }
    }
')

if [ ${#messages[@]} -eq 0 ]; then
    exit 0
fi

# ST01, RU02, RI03, RS04, GU05, GI06, GS07, P01 - the plan's own step ids, and D3/F12/A7/Q2 from a design.
found=()
for message in "${messages[@]}"; do
    while IFS= read -r hit; do
        [ -z "$hit" ] && continue
        already=0
        for f in "${found[@]:-}"; do
            [ "$f" = "$hit" ] && already=1 && break
        done
        [ "$already" -eq 0 ] && found+=("$hit")
    done < <(printf '%s' "$message" | grep -Eo '\b(ST|RU|RI|RS|GU|GI|GS|P|D|F|A|Q|R)[0-9]{1,3}\b')
done

if [ ${#found[@]} -eq 0 ]; then
    exit 0
fi

names="$(IFS=', '; echo "${found[*]}")"

reason="A commit message names no plan step, design entry or finding, and this one names ${names}. An id belongs to a document that is archived once the work lands, so the message stops resolving the moment it would be read. Say what the commit does instead. See skills/plan-task/SKILL.md, 'An ID never leaves those places'."

jq -nc --arg reason "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
