#!/usr/bin/env bash
# SubagentStop hook: appends one line to the task's review/cost.jsonl for a framework agent that
# stopped. What is recorded and how it is attributed is docs/cost-recording.md.
set -u

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

input="$(cat)"
# jq built for Windows ends every line with a carriage return, which is part of no path or id.
# One jq call, one field per line.
{
    read -r agent_type
    read -r agent_id
    read -r session_id
    read -r transcript
    read -r cwd
} < <(printf '%s' "$input" | jq -r '
    .agent_type // "", .agent_id // "", .session_id // "", .agent_transcript_path // "", .cwd // ""' \
    | tr -d '\r')
agent_type="${agent_type:-}"; agent_id="${agent_id:-}"; session_id="${session_id:-}"
[ -n "$agent_type" ] || exit 0
[ -n "$agent_id" ] || exit 0
[ -n "$session_id" ] || exit 0

# Windows hands paths over with backslashes; every path below is used as a POSIX one.
posix() { printf '%s' "$1" | tr '\134' '/'; }
transcript="$(posix "${transcript:-}")"
cwd="$(posix "${cwd:-}")"
[ -f "$transcript" ] || exit 0

# Only framework agents are recorded: the type is one of the files under agents/. The plugin root is
# two levels above this script.
plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || exit 0
known=0
for f in "$plugin_root"/agents/*.md; do
    [ -f "$f" ] || continue
    b="$(basename "$f" .md)"
    [ "$b" = "$agent_type" ] && known=1 && break
done
[ "$known" -eq 1 ] || exit 0

meta="$(dirname "$transcript")/agent-${agent_id}.meta.json"
parent=""
meta_model=""
if [ -f "$meta" ]; then
    parent="$(jq -r '.parentAgentId // empty' "$meta" 2>/dev/null | tr -d '\r')"
    meta_model="$(jq -r '.model // empty' "$meta" 2>/dev/null | tr -d '\r')"
fi

# The prompt is the first user line's content: a string, or an array whose first text block carries
# the text.
prompt="$(jq -Rn '
    [inputs | select(length > 0) | (fromjson? // empty)]
    | map(select(.type == "user")) | first | .message.content as $c
    | if ($c | type) == "string" then $c
      elif ($c | type) == "array" then ([$c[] | select(.text?) | .text] | first // "")
      else "" end' < "$transcript" 2>/dev/null | tr -d '\r')"

git_dir="$(cd "${cwd:-.}" 2>/dev/null && git rev-parse --git-dir 2>/dev/null)" || exit 0
case "$git_dir" in
    /*|?:*) ;;
    *) git_dir="${cwd:-.}/$git_dir" ;;
esac
map="$git_dir/tdd-sdlc/sessions/$session_id"
mapped=""
[ -f "$map" ] && mapped="$(sed -n '1p' "$map")"

# Every plan path the prompt names. Where the session's mapped task owns one of them, that one wins;
# otherwise the first. The plan names the task. Without a plan path, the task is the first
# docs/<n>-<name> in the prompt, then the mapping.
plans="$(printf '%s' "$prompt" | tr '\134' '/' \
    | grep -Eo '(^|[^A-Za-z0-9_])docs/[0-9]+-[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*'\
'/(plan|fix|steps|rework|upgrade|bug)\.md' \
    | sed -E 's|^.*(docs/)|\1|')"
plan=""
if [ -n "$plans" ]; then
    if [ -n "$mapped" ]; then
        plan="$(printf '%s\n' "$plans" | grep -E "^$mapped/" | head -1)"
    fi
    [ -n "$plan" ] || plan="$(printf '%s\n' "$plans" | head -1)"
fi
if [ -n "$plan" ]; then
    task="$(printf '%s' "$plan" | sed -E 's|^(docs/[0-9]+-[A-Za-z0-9._-]+)/.*|\1|')"
else
    task="$(printf '%s' "$prompt" | tr '\134' '/' \
        | grep -Eo '(^|[^A-Za-z0-9_])docs/[0-9]+-[A-Za-z0-9._-]+' \
        | head -1 | sed -E 's|^.*(docs/)|\1|')"
fi
[ -n "$task" ] || task="$mapped"
[ -n "$task" ] || exit 0

repo_root="$(cd "${cwd:-.}" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$repo_root" ] || exit 0
# A task the tree does not hold is a path the prompt only mentioned. Nothing is created for it.
[ -d "$repo_root/$task" ] || exit 0
out_dir="$repo_root/$task/review"
mkdir -p "$out_dir" 2>/dev/null || exit 0

usage="$(jq -Rn '
    [inputs | select(length > 0) | (fromjson? // empty)] as $l
    | ($l | map(select(.type == "assistant"))) as $a
    | ($l | map(select(.timestamp))) as $t
    | {
        input:       ($a | map(.message.usage.input_tokens // 0) | add // 0),
        output:      ($a | map(.message.usage.output_tokens // 0) | add // 0),
        cache_read:  ($a | map(.message.usage.cache_read_input_tokens // 0) | add // 0),
        cache_create:($a | map(.message.usage.cache_creation_input_tokens // 0) | add // 0),
        model:       ($a | last | .message.model // ""),
        started:     ($t | first | .timestamp // ""),
        ended:       ($t | last  | .timestamp // "")
      }' < "$transcript" 2>/dev/null | tr -d '\r')"
[ -n "$usage" ] || exit 0

get() { printf '%s' "$usage" | jq -r ".$1 // empty" | tr -d '\r'; }
started="$(get started)"
ended="$(get ended)"
model="$(get model)"
[ -n "$model" ] || model="$meta_model"

# Wall time from first to last message. GNU `date -d` is absent on macOS, so the two stamps are
# parsed and differenced by hand. Both are UTC, so no zone enters it.
seconds="$(awk -v a="$started" -v b="$ended" '
    function days(y, m, d,   era, yoe, doy, doe) {
        if (m <= 2) y = y - 1
        era = int((y >= 0 ? y : y - 399) / 400)
        yoe = y - era * 400
        doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
        doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
        return era * 146097 + doe - 719468
    }
    function epoch(s,   p) {
        if (s !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/) return ""
        return days(substr(s, 1, 4) + 0, substr(s, 6, 2) + 0, substr(s, 9, 2) + 0) * 86400 \
            + substr(s, 12, 2) * 3600 + substr(s, 15, 2) * 60 + substr(s, 18, 2)
    }
    BEGIN {
        x = epoch(a); y = epoch(b)
        if (x == "" || y == "") { print 0; exit }
        d = y - x
        print (d < 0 ? 0 : d)
    }')"

line="$(jq -nc \
    --arg id "$agent_id" --arg parent "$parent" \
    --arg started "$started" --arg ended "$ended" \
    --arg session "$session_id" --arg agent "$agent_type" --arg model "$model" \
    --arg plan "$plan" --argjson seconds "${seconds:-0}" \
    --argjson input "$(get input)" --argjson output "$(get output)" \
    --argjson cache_read "$(get cache_read)" --argjson cache_create "$(get cache_create)" '
    {id: $id}
    + (if $parent == "" then {} else {parent: $parent} end)
    + {started: $started, ended: $ended, session: $session, agent: $agent, model: $model,
       tokens: {input: $input, output: $output, cache_read: $cache_read, cache_create: $cache_create},
       seconds: $seconds}
    + (if $plan == "" then {} else {plan: $plan} end)' | tr -d '\r')"

# One short printf per stop, appended; agents of one wave stop close together and each writes one line.
[ -n "$line" ] && printf '%s\n' "$line" >> "$out_dir/cost.jsonl"
exit 0
