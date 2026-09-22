#!/usr/bin/env bash
# SubagentStop hook: appends one line to the task's review/cost.jsonl for a framework agent that
# stopped.
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

# Only framework agents are recorded: the type, with any leading `<plugin>:` stripped, is one of the
# files under agents/. The bare name is what gets recorded. The plugin root is two levels above this
# script.
plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || exit 0
activity_parser="$plugin_root/scripts/cost/activity-parse.jq"
known=0
for f in "$plugin_root"/agents/*.md; do
    [ -f "$f" ] || continue
    b="$(basename "$f" .md)"
    [ "$b" = "$agent_type" ] || [ "$b" = "${agent_type#*:}" ] && known=1 && agent_type="$b" && break
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
prompt="$(jq -Rrn '
    [inputs | select(length > 0) | (fromjson? // empty)]
    | map(select(.type == "user")) | first | .message.content as $c
    | if ($c | type) == "string" then $c
      elif ($c | type) == "array" then ([$c[] | select(.text?) | .text] | first // "")
      else "" end' < "$transcript" 2>/dev/null | tr -d '\r')"

# A PreToolUse hook prepends these four lines to step-carrying implementation agents. Older
# transcripts and agents without an assignment keep no assignment object.
assignment_workflow="$(printf '%s\n' "$prompt" | sed -n 's/^Workflow: //p' | head -1)"
assignment_file="$(printf '%s\n' "$prompt" | sed -n 's/^Work file: //p' | head -1 | tr '\134' '/')"
assignment_items_text="$(printf '%s\n' "$prompt" | sed -n 's/^Assigned items: //p' | head -1)"
assignment_basis="$(printf '%s\n' "$prompt" | sed -n 's/^Assignment basis: //p' | head -1)"
prompt_chars="$(printf '%s' "$prompt" | wc -m | tr -d ' \r')"
prompt_preview="$(printf '%s' "$prompt" | jq -Rs '.[0:1000]' | jq -r . 2>/dev/null | tr -d '\r')"

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

brief_chars=0
if [ -n "$assignment_workflow" ] && [ -n "$assignment_items_text" ] \
    && [ "$assignment_items_text" != "none" ] && [ -f "$repo_root/$assignment_file" ]; then
    read -r -a assignment_ids <<< "$assignment_items_text"
    brief=""
    case "$assignment_workflow" in
        implement-plan)
            brief="$(bash "$plugin_root/scripts/plan/plan.sh" show "${assignment_ids[@]}" \
                "$repo_root/$assignment_file" 2>/dev/null)" ;;
        fix-bug)
            brief="$(bash "$plugin_root/scripts/fix/fix.sh" show "${assignment_ids[@]}" \
                --file "$repo_root/$assignment_file" 2>/dev/null)" ;;
        rework)
            brief="$(bash "$plugin_root/scripts/rework/rework.sh" show "${assignment_ids[@]}" \
                --file "$repo_root/$assignment_file" 2>/dev/null)" ;;
        upgrade-deps)
            brief="$(bash "$plugin_root/scripts/upgrade/upgrade.sh" show "${assignment_ids[@]}" \
                --file "$repo_root/$assignment_file" 2>/dev/null)" ;;
    esac
    [ -z "$brief" ] || brief_chars="$(printf '%s' "$brief" | wc -m | tr -d ' \r')"
fi
# A task the tree does not hold is a path the prompt only mentioned. Nothing is created for it.
[ -d "$repo_root/$task" ] || exit 0
out_dir="$repo_root/$task/review"
mkdir -p "$out_dir" 2>/dev/null || exit 0

# One transcript line per content block, every line of one message carrying the whole message's usage:
# the lines are grouped by `message.id`, the last line of each group is the message. A line without an
# id is a group of its own. A message without the cache write split is counted at the 5-minute TTL.
usage="$(jq -Rn '
    def cc5m: (.message.usage.cache_creation.ephemeral_5m_input_tokens
        // (if (.message.usage.cache_creation | type) == "object" then 0
            else (.message.usage.cache_creation_input_tokens // 0) end));
    def cc1h: (.message.usage.cache_creation.ephemeral_1h_input_tokens // 0);
    def ctx: ((.message.usage.input_tokens // 0) + cc5m + cc1h
        + (.message.usage.cache_read_input_tokens // 0));
    [inputs | select(length > 0) | (fromjson? // empty)] as $l
    | ($l | map(select(.type == "assistant"))) as $a
    | ($a | to_entries | group_by(.value.message.id // ("line-" + (.key | tostring)))
        | map(last.value)) as $m
    | ($l | map(select(.timestamp))) as $t
    | {
        input:          ($m | map(.message.usage.input_tokens // 0) | add // 0),
        output:         ($m | map(.message.usage.output_tokens // 0) | add // 0),
        cache_read:     ($m | map(.message.usage.cache_read_input_tokens // 0) | add // 0),
        cache_create_5m:($m | map(cc5m) | add // 0),
        cache_create_1h:($m | map(cc1h) | add // 0),
        turns:          ($m | length),
        peak_ctx:       ($m | map(ctx) | max // 0),
        model:          ($a | last | .message.model // ""),
        started:        ($t | first | .timestamp // ""),
        ended:          ($t | last  | .timestamp // ""),
        idle:           (($t | map(.type == "user") | index(true)) as $p
                         | [$t | to_entries[] | select($p != null and .key > $p)
                            | select(.value.type == "user" and (.value.message.content | type) == "string")
                            | [$t[.key - 1].timestamp, .value.timestamp]])
      }' < "$transcript" 2>/dev/null | tr -d '
')"
[ -n "$usage" ] || exit 0

get() { printf '%s' "$usage" | jq -r ".$1 // empty" | tr -d '\r'; }
started="$(get started)"
ended="$(get ended)"
model="$(get model)"
[ -n "$model" ] || model="$meta_model"
idle="$(printf '%s' "$usage" | jq -c '.idle // []' | tr -d '\r')"

# Keep the bounded activity intervals with the cost line. The report can then be regenerated after
# Claude Code has removed the agent transcript. Missing parser data degrades to an empty timeline;
# cost recording itself still succeeds.
activity_file="${TMPDIR:-/tmp}/tdd-sdlc-agent-activity.$$"
printf '[]\n' > "$activity_file" 2>/dev/null || exit 0
trap 'rm -f "$activity_file" "$activity_file.tmp"' EXIT
if [ -f "$activity_parser" ] && [ -n "$started" ] && [ -n "$ended" ]; then
    if ! jq -cRs --arg lane "$agent_id" --arg from "$started" --arg to "$ended" \
        -f "$activity_parser" "$transcript" 2>/dev/null | tr -d '\r' > "$activity_file.tmp"; then
        printf '[]\n' > "$activity_file.tmp"
    fi
    mv "$activity_file.tmp" "$activity_file"
fi

# Wall time from first to last message, and the active part of it: the wall time less every idle
# window. An idle window ends at a user line whose content is a string, as docs/cost-recording.md says
# under "Idle windows". GNU `date -d` is absent on macOS, so the stamps are parsed and differenced by
# hand. All are UTC, so no zone enters it.
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
active="$(printf '%s' "$idle" | jq -r '.[] | @tsv' | tr -d '\r' | awk -F'\t' -v total="${seconds:-0}" '
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
    {
        x = epoch($1); y = epoch($2)
        if (x == "" || y == "" || y <= x) next
        gap += y - x
    }
    END { d = total - gap; print (d < 0 ? 0 : d) }')"

# The offset is the machine's at the moment the hook fires, as `date +%z` prints it. The report renders
# local times from it.
offset="$(date +%z 2>/dev/null | tr -d '\r')"
[ -n "$offset" ] || offset="+0000"

line="$(jq -nc \
    --arg id "$agent_id" --arg parent "$parent" \
    --arg started "$started" --arg ended "$ended" \
    --arg session "$session_id" --arg agent "$agent_type" --arg model "$model" \
    --arg plan "$plan" --arg offset "$offset" --argjson seconds "${seconds:-0}" \
    --arg workflow "$assignment_workflow" --arg work_file "$assignment_file" \
    --arg items "$assignment_items_text" --arg basis "$assignment_basis" \
    --arg preview "$prompt_preview" --argjson prompt_chars "${prompt_chars:-0}" \
    --argjson brief_chars "${brief_chars:-0}" \
    --argjson active "${active:-0}" --argjson idle "${idle:-[]}" \
    --slurpfile activity "$activity_file" \
    --argjson input "$(get input)" --argjson output "$(get output)" \
    --argjson cache_read "$(get cache_read)" \
    --argjson cache_create_5m "$(get cache_create_5m)" --argjson cache_create_1h "$(get cache_create_1h)" \
    --argjson turns "$(get turns)" --argjson peak_ctx "$(get peak_ctx)" '
    {id: $id}
    + (if $parent == "" then {} else {parent: $parent} end)
    + {started: $started, ended: $ended, session: $session, agent: $agent, model: $model,
       turns: $turns,
       tokens: {input: $input, output: $output, cache_read: $cache_read,
                cache_create_5m: $cache_create_5m, cache_create_1h: $cache_create_1h},
       peak_ctx: $peak_ctx, seconds: $seconds, active: $active, idle: $idle,
       activity: ($activity[0] // []), offset: $offset}
    + (if $plan == "" then {} else {plan: $plan} end)
    + (if $workflow == "" then {} else
         {assignment: {workflow: $workflow, work_file: $work_file,
                       items: (if $items == "none" or $items == "" then [] else ($items | split(" ")) end),
                       basis: $basis, prompt_chars: $prompt_chars, brief_chars: $brief_chars,
                       prompt_preview: $preview}}
       end)' | tr -d '\r')"
rm -f "$activity_file"

# One short printf per stop, appended; agents of one wave stop close together and each writes one line.
[ -n "$line" ] && printf '%s\n' "$line" >> "$out_dir/cost.jsonl"
exit 0
