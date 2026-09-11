#!/usr/bin/env bash
# PreToolUse hook on Bash: refuses a `git commit` whose message names an id from one of the framework's
# files - a plan step, a decision, a finding, a run-log entry, a backlog row. Those documents are
# archived once the work lands, so an id in a commit message stops resolving the moment a reader meets
# it. A consumer without jq gets a hook that is silent, never one that fails every matched tool call.
set -u

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

input="$(cat)"
command_text="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
[ -n "$command_text" ] || exit 0

printf '%s' "$command_text" | grep -Eiq '(^|[;&|][[:space:]]*)git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+commit\b' || exit 0

# Only the message is searched. A pathspec may legitimately name a plan file, so the ids are looked
# for where a reader would meet them: -m '...', -m "...", -m"...", --message=..., -F <file>,
# --file <file>, and a heredoc feeding the command.
messages=()
add_messages() {
    while IFS= read -r line; do
        [ -n "$line" ] && messages+=("$line")
    done
}

# -m / --message with a single- or double-quoted value, with or without a space before the quote.
# -m may sit at the end of a run of short flags, as in -am.
add_messages < <(printf '%s' "$command_text" | awk '
    {
        s = $0
        while (match(s, /(-[a-zA-Z]*m|--message)[ \t]*=?[ \t]*'"'"'[^'"'"']*'"'"'/)) {
            seg = substr(s, RSTART, RLENGTH)
            sub(/^(-[a-zA-Z]*m|--message)[ \t]*=?[ \t]*'"'"'/, "", seg)
            sub(/'"'"'$/, "", seg)
            print seg
            s = substr(s, RSTART + RLENGTH)
        }
    }')
add_messages < <(printf '%s' "$command_text" | awk '
    {
        s = $0
        while (match(s, /(-[a-zA-Z]*m|--message)[ \t]*=?[ \t]*"[^"]*"/)) {
            seg = substr(s, RSTART, RLENGTH)
            sub(/^(-[a-zA-Z]*m|--message)[ \t]*=?[ \t]*"/, "", seg)
            sub(/"$/, "", seg)
            print seg
            s = substr(s, RSTART + RLENGTH)
        }
    }')
# An unquoted --message=word or -m word.
add_messages < <(printf '%s' "$command_text" | awk '
    {
        s = $0
        while (match(s, /(-[a-zA-Z]*m|--message=)[ \t]*[^ \t"'"'"'-][^ \t]*/)) {
            seg = substr(s, RSTART, RLENGTH)
            sub(/^(-[a-zA-Z]*m|--message=)[ \t]*/, "", seg)
            print seg
            s = substr(s, RSTART + RLENGTH)
        }
    }')
# -F <file> / --file <file> / --file=<file>: the message is in the file, read relative to the cwd.
while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ "$f" = "-" ] && continue
    case "$f" in /*) path="$f" ;; *) path="${cwd:-.}/$f" ;; esac
    [ -f "$path" ] && add_messages < "$path"
done < <(printf '%s' "$command_text" | awk '
    {
        s = $0
        while (match(s, /(-F|--file)[ \t]*=?[ \t]*[^ \t]+/)) {
            seg = substr(s, RSTART, RLENGTH)
            sub(/^(-F|--file)[ \t]*=?[ \t]*/, "", seg)
            gsub(/["'"'"']/, "", seg)
            print seg
            s = substr(s, RSTART + RLENGTH)
        }
    }')
# A heredoc: everything after the first line is the message.
if printf '%s' "$command_text" | grep -q '<<'; then
    add_messages < <(printf '%s\n' "$command_text" | tail -n +2)
fi

if [ ${#messages[@]} -eq 0 ]; then
    exit 0
fi

# Every id prefix the framework's files define - two capital letters and at least two digits - and
# nothing else. Plan steps: ST RU RI RS GU GI GS PM PI. Spec: RQ AC DN. Design log: DF. Plan: OQ. Plan
# log: RF. Every log: RL AT CV. Findings file: RX DX PX. Backlog: BC BB BR BT BP. Fix steps: FS FR FG. Rework
# steps: WK. Upgrade steps: UP. Case-sensitive on purpose: "rq01" is not an id.
# The message is split into words at every character an id cannot contain, so two ids one space
# apart are both seen.
pattern='^(ST|RU|RI|RS|GU|GI|GS|PM|PI|RQ|AC|DN|DF|OQ|RF|RL|AT|CV|RX|DX|PX|BC|BB|BR|BT|BP|FS|FR|FG|WK|UP)[0-9]{2,}$'
found=()
for message in "${messages[@]}"; do
    while IFS= read -r hit; do
        [ -z "$hit" ] && continue
        already=0
        for f in "${found[@]:-}"; do
            [ "$f" = "$hit" ] && already=1 && break
        done
        [ "$already" -eq 0 ] && found+=("$hit")
    done < <(printf '%s' "$message" | tr -c 'A-Za-z0-9_' '\n' | grep -E "$pattern")
done

if [ ${#found[@]} -eq 0 ]; then
    exit 0
fi

names="$(printf '%s, ' "${found[@]}")"
names="${names%, }"

reason="A commit message names no plan step, design entry, finding or backlog row, and this one names ${names}. An id belongs to a document that is archived once the work lands, so the message stops resolving the moment it would be read. Say what the commit does instead. See skills/plan-task/SKILL.md, 'An ID never leaves those places'."

jq -nc --arg reason "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
