#!/usr/bin/env bash
#
# Turns the cost lines the hooks appended during a run into the task's review/cost.md. It stores
# nothing of its own. See the README next to this script.

set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
renderer="$script_dir/cost-render.awk"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
repo_root_abs="$(cd "$repo_root" && pwd)"

jsonl=""
puml=0

usage() {
    cat <<'EOF'
Usage:
  <plugin>/scripts/cost/cost.sh report [<task directory> | <cost.jsonl>] [--puml]

Commands:
  report    Read the task's review/cost.jsonl and write review/cost.md beside it. --puml also
            writes review/cost.puml. What the report holds is docs/cost-recording.md.

The task is named as a directory, as its review/cost.jsonl, or not at all when one task under docs/
carries a cost.jsonl. An archived task under docs/implemented/ is named explicitly.

Exit codes: 0 done - 1 no cost lines to report on - 2 bad usage.
EOF
}

die() {
    echo "$1" >&2
    exit "${2:-2}"
}

# In-place editing is done by rewriting through a sibling temp file rather than with `sed -i`, whose
# spelling differs between GNU and BSD. The temp file is a sibling so the move stays on one
# filesystem.
rewrite_file() {
    local target="$1"
    shift
    local tmp="${target}.cost-tmp.$$"
    if "$@" > "$tmp" && mv "$tmp" "$target"; then
        return 0
    fi
    rm -f "$tmp"
    die "could not write $target"
}

resolve_jsonl() {
    local given="$1" candidates=()
    if [ -n "$given" ]; then
        case "$given" in
            *.jsonl) jsonl="$given" ;;
            *)
                if [ -d "$given" ]; then
                    jsonl="$(cd "$given" && pwd)/review/cost.jsonl"
                else
                    jsonl="$given/review/cost.jsonl"
                fi
                ;;
        esac
        [ -f "$jsonl" ] || die "no cost lines yet: ${jsonl#"$repo_root_abs/"} does not exist" 1
        return 0
    fi
    while IFS= read -r f; do
        candidates+=("$f")
    done < <(find "$repo_root_abs/docs" -maxdepth 3 -path '*/review/cost.jsonl' -type f \
        -not -path '*/implemented/*' 2>/dev/null | sort)
    case "${#candidates[@]}" in
        0) die "no <n>-<task>/review/cost.jsonl under $repo_root_abs/docs - name the task directory" 1 ;;
        1) jsonl="${candidates[0]}" ;;
        *)
            {
                echo "docs/ holds ${#candidates[@]} tasks with cost lines - name one:"
                printf '  %s\n' "${candidates[@]#"$repo_root_abs/"}"
            } >&2
            exit 2
            ;;
    esac
}

# One TSV line per agent, the last line per id winning, in start order.
agent_records() {
    jq -Rr -n '
        [inputs | select(length > 0) | (fromjson? // empty) | select(.id)] as $lines
        | reduce $lines[] as $x ({}; .[$x.id] = $x)
        | [.[]] | sort_by(.started)[]
        | ["A", .id, (.parent // ""), (.started // ""), (.ended // ""), (.session // ""),
           (.agent // ""), (.model // ""),
           ((.tokens.input // 0) + (.tokens.output // 0)
            + (.tokens.cache_read // 0) + (.tokens.cache_create // 0)),
           (.seconds // 0), (.plan // "")]
        | @tsv' < "$jsonl" | tr -d '\r'
}

# Every session the file names.
sessions_of() {
    jq -Rr -n '[inputs | select(length > 0) | (fromjson? // empty)
                | .session // empty] | unique[]' < "$jsonl" | tr -d '\r'
}

last_ended_of() {
    jq -Rr -n --arg s "$1" '
        [inputs | select(length > 0) | (fromjson? // empty)
         | select(.session == $s) | .ended // empty] | sort | last // ""' < "$jsonl" | tr -d '\r'
}

# The skill's own turns: the session transcript's assistant messages inside the window the mapping
# file bounds.
session_tokens() {
    local transcript="$1" from="$2" to="$3"
    jq -Rr -n --arg from "$from" --arg to "$to" '
        [inputs | select(length > 0) | (fromjson? // empty)
         | select(.type == "assistant")
         | select((.timestamp // "")[0:19] >= $from[0:19] and (.timestamp // "")[0:19] <= $to[0:19])
         | (.message.usage.input_tokens // 0) + (.message.usage.output_tokens // 0)
           + (.message.usage.cache_read_input_tokens // 0)
           + (.message.usage.cache_creation_input_tokens // 0)]
        | add // 0' < "$transcript" | tr -d '\r'
}

# S records: one per session, from its mapping file: the window opens at the session's first
# framework call (line 3) and closes at its latest (line 4), which the report's own call refreshes.
session_records() {
    local git_dir sessions=() s map transcript first to tokens
    git_dir="$(cd "$repo_root_abs" && git rev-parse --git-dir 2>/dev/null)" || git_dir=""
    case "$git_dir" in
        ""|/*|?:*) ;;
        *) git_dir="$repo_root_abs/$git_dir" ;;
    esac

    while IFS= read -r s; do
        [ -n "$s" ] && sessions+=("$s")
    done < <(sessions_of)
    [ "${#sessions[@]}" -gt 0 ] || return 0

    for s in "${sessions[@]}"; do
        map="$git_dir/tdd-sdlc/sessions/$s"
        if [ -z "$git_dir" ] || [ ! -f "$map" ]; then
            printf 'S\t%s\t\t\t0\tunavailable\n' "$s"
            continue
        fi
        transcript="$(sed -n '2p' "$map" | tr '\134' '/')"
        first="$(sed -n '3p' "$map")"
        to="$(sed -n '4p' "$map")"
        [ -n "$to" ] || to="$(last_ended_of "$s")"
        if [ ! -f "$transcript" ] || [ -z "$first" ] || [ -z "$to" ]; then
            printf 'S\t%s\t\t\t0\tunavailable\n' "$s"
            continue
        fi
        tokens="$(session_tokens "$transcript" "$first" "$to")"
        printf 'S\t%s\t%s\t%s\t%s\tok\n' "$s" "$first" "$to" "${tokens:-0}"
    done
}

command="${1:-}"
[ -n "$command" ] || { usage; exit 2; }
case "$command" in
    --help|-h) usage; exit 0 ;;
esac
shift

target=""
while [ $# -gt 0 ]; do
    case "$1" in
        --puml)    puml=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *)
            [ -z "$target" ] || die "the task is named once: $target and $1"
            target="$1"; shift ;;
    esac
done

case "$command" in
    report)
        command -v jq >/dev/null 2>&1 || die "report needs jq" 1
        [ -f "$renderer" ] || die "no renderer beside the script: $renderer"
        resolve_jsonl "$target"
        review_dir="$(cd "$(dirname "$jsonl")" && pwd)"
        task_dir="$(dirname "$review_dir")"
        task_name="$(basename "$task_dir")"
        now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

        records="${TMPDIR:-/tmp}/cost-records.$$"
        { agent_records; session_records; } > "$records" || { rm -f "$records"; die "could not read $jsonl" 1; }
        if ! grep -q '^A' "$records"; then
            rm -f "$records"
            die "${jsonl#"$repo_root_abs/"} holds no agent lines" 1
        fi

        rewrite_file "$review_dir/cost.md" \
            awk -v MODE=md -v task="$task_name" -v now="$now" -f "$renderer" "$records"
        echo "${review_dir#"$repo_root_abs/"}/cost.md"
        if [ "$puml" -eq 1 ]; then
            rewrite_file "$review_dir/cost.puml" \
                awk -v MODE=puml -v task="$task_name" -v now="$now" -f "$renderer" "$records"
            echo "${review_dir#"$repo_root_abs/"}/cost.puml"
        fi
        rm -f "$records"
        ;;

    *)
        die "unknown command '$command' (try --help)"
        ;;
esac
