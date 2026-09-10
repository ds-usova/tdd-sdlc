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

usage() {
    cat <<'EOF'
Usage:
  <plugin>/scripts/cost/cost.sh report [<task directory> | <cost.jsonl>]
  <plugin>/scripts/cost/cost.sh refresh-pricing

Commands:
  report           Read the task's review/cost.jsonl and write review/cost.md beside it. What the
                   report holds is docs/cost-recording.md.
  refresh-pricing  Fetch the published rates and rewrite the plugin's own pricing.json, beside the
                   script, dated today. Run before a release, as docs/developing.md says.

The task is named as a directory, as its review/cost.jsonl, or not at all when one task under docs/
carries a cost.jsonl. An archived task under docs/implemented/ is named explicitly.

Exit codes: 0 done - 1 no cost lines to report on, or the fetch failed - 2 bad usage.
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

# The last line per id, in start order, as JSON. A line recorded before the hook wrote `turns`,
# `cache_create_5m`, `cache_create_1h`, `peak_ctx` and `offset` is skipped and counted
# (docs/cost-recording.md); the last-per-id rule runs first, so a new line supersedes an old one.
current_lines() {
    jq -Rc -n '
        [inputs | select(length > 0) | (fromjson? // empty) | select(.id)] as $lines
        | reduce $lines[] as $x ({}; .[$x.id] = $x)
        | [.[]] | sort_by(.started)[]
        | select(.turns != null and .tokens.cache_create_5m != null and .tokens.cache_create_1h != null
                 and .peak_ctx != null and .offset != null)' < "$jsonl" | tr -d '\r'
}

skipped_count() {
    jq -Rr -n '
        [inputs | select(length > 0) | (fromjson? // empty) | select(.id)] as $lines
        | reduce $lines[] as $x ({}; .[$x.id] = $x)
        | [.[] | select(.turns == null or .tokens.cache_create_5m == null
                        or .tokens.cache_create_1h == null or .peak_ctx == null or .offset == null)]
        | length' < "$jsonl" | tr -d '\r'
}

# ---------------------------------------------------------------- prices

# Two tables the transcript does not carry: dollars per million tokens and the context window, per
# model id. The bundled file ships with the plugin; a fetched copy is cached per user and refreshed
# only when a report needs it (docs/cost-recording.md, "Where the rates come from").
pricing_bundled="$script_dir/pricing.json"
pricing_parser="$script_dir/pricing-parse.awk"
pricing_cache="${XDG_CACHE_HOME:-$HOME/.cache}/tdd-sdlc/pricing.json"
pricing_page="https://platform.claude.com/docs/en/about-claude/pricing.md"
models_page="https://platform.claude.com/docs/en/models/overview.md"
rates_line=""
prices_tsv=""

# Whole days from a date or timestamp to now; a large number when it cannot be read.
days_since() {
    awk -v a="$1" -v b="$(date -u +%Y-%m-%d)" '
    function days(y, m, d,   era, yoe, doy, doe) {
        if (m <= 2) y = y - 1
        era = int((y >= 0 ? y : y - 399) / 400)
        yoe = y - era * 400
        doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
        doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
        return era * 146097 + doe - 719468
    }
    function day(s) {
        if (s !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) return ""
        return days(substr(s, 1, 4) + 0, substr(s, 6, 2) + 0, substr(s, 9, 2) + 0)
    }
    BEGIN { x = day(a); y = day(b); print (x == "" || y == "") ? 100000 : y - x }'
}

# The bundled file with the cache merged over it, as one JSON document on stdout.
pricing_current() {
    if [ -f "$pricing_cache" ]; then
        jq -s '.[1] * {models: ((.[0].models // {}) * (.[1].models // {}))}' \
            "$pricing_bundled" "$pricing_cache" 2>/dev/null
    else
        cat "$pricing_bundled"
    fi
}

# An id is looked up as written, then without a trailing -YYYYMMDD.
pricing_has() {
    local id="$1" bare
    bare="$(printf '%s' "$id" | sed -E 's/-[0-9]{8}$//')"
    printf '%s' "$2" | jq -e --arg id "$id" --arg bare "$bare" '
        (.models[$id] // .models[$bare]) as $m | $m != null and $m.missing == null' >/dev/null 2>&1
}

# The date a `missing` entry carries for the id, or nothing.
pricing_missing_since() {
    printf '%s' "$2" | jq -r --arg id "$1" '.models[$id].missing // empty' 2>/dev/null | tr -d '\r'
}

# Fetches the two pages and parses them into fetched_rows, one model per line as pricing-parse.awk
# writes it. Sets fetch_reason and returns 1 when the fetch or the parse fails; nothing goes to
# stderr.
fetch_rows() {
    local tmp="${TMPDIR:-/tmp}/cost-pricing.$$" err
    fetch_reason=""
    fetched_rows=""
    if ! command -v curl >/dev/null 2>&1; then
        fetch_reason="curl is not installed"
        return 1
    fi
    mkdir -p "$tmp" 2>/dev/null || { fetch_reason="could not create $tmp"; return 1; }
    if ! curl -fsSL --max-time 10 "$pricing_page" -o "$tmp/pricing.md" 2>"$tmp/err"; then
        err="$(head -1 "$tmp/err" | tr -d '\r')"
        rm -rf "$tmp"
        fetch_reason="${err:-curl failed on the pricing page}"
        return 1
    fi
    if ! curl -fsSL --max-time 10 "$models_page" -o "$tmp/models.md" 2>"$tmp/err"; then
        err="$(head -1 "$tmp/err" | tr -d '\r')"
        rm -rf "$tmp"
        fetch_reason="${err:-curl failed on the models page}"
        return 1
    fi
    fetched_rows="$(awk -f "$pricing_parser" "$tmp/pricing.md" "$tmp/models.md" 2>/dev/null | tr -d '\r')"
    rm -rf "$tmp"
    if [ -z "$fetched_rows" ]; then
        fetch_reason="no model table on the pricing page"
        return 1
    fi
    return 0
}

# fetched_rows on stdin to a models object on stdout, merged over the bundled file's: a multiplier at
# its default is left out, as in the bundled file.
rows_to_models() {
    jq -R -s --slurpfile bundled "$pricing_bundled" '
        [split("\n")[] | select(length > 0) | split("\t")
         | {key: .[0], value: ({input: (.[1] | tonumber), output: (.[2] | tonumber)}
             + (if .[3] != "" and (.[3] | tonumber) != 0.1 then {cache_read: (.[3] | tonumber)} else {} end)
             + (if .[4] != "" and (.[4] | tonumber) != 1.25 then {cache_write_5m: (.[4] | tonumber)} else {} end)
             + (if .[5] != "" and (.[5] | tonumber) != 2 then {cache_write_1h: (.[5] | tonumber)} else {} end)
             + (if .[6] != "" then {window: (.[6] | tonumber)} else {} end))}]
        | from_entries as $fetched
        | ($bundled[0].models // {}) * $fetched'
}

# Fetches, and rewrites the cache as the rows merged over the bundled file, with a `missing` entry
# for every needed model neither lists. Sets fetch_reason and returns 1 when the fetch or the parse
# fails; nothing goes to stderr.
fetch_pricing() {
    local now today
    fetch_rows || return 1
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    today="${now%%T*}"
    mkdir -p "$(dirname "$pricing_cache")" 2>/dev/null || { fetch_reason="could not create the cache"; return 1; }
    printf '%s\n' "$fetched_rows" | rows_to_models 2>/dev/null \
        | jq --arg today "$today" --arg now "$now" --arg needed "$1" '
        ($needed | split(" ") | map(select(length > 0))) as $need
        | def bare: sub("-[0-9]{8}$"; "");
          reduce $need[] as $id (.;
            if (.[$id] // .[$id | bare]) != null then . else .[$id] = {missing: $today} end)
        | {dated: $today, fetched: $now, fetch_failed: null, models: .}' \
        > "$pricing_cache.tmp.$$" 2>/dev/null \
        && mv "$pricing_cache.tmp.$$" "$pricing_cache" \
        || { rm -f "$pricing_cache.tmp.$$"; fetch_reason="could not write the cache"; return 1; }
    return 0
}

# Fetches, and rewrites the bundled file as the rows merged over it, dated today, one model per line.
# Prints the models whose entry changed and the ones added; dies when the fetch fails.
refresh_pricing() {
    local today before after
    fetch_rows || die "fetching current rates failed: $fetch_reason" 1
    today="$(date -u +%Y-%m-%d)"
    before="$(jq -c '.models' "$pricing_bundled")"
    after="$(printf '%s\n' "$fetched_rows" | rows_to_models)" || die "could not parse the fetched rates" 1
    rewrite_file "$pricing_bundled" \
        printf '{\n  "dated": "%s",\n  "source": %s,\n  "models": {\n%s\n  }\n}\n' \
        "$today" \
        "$(jq -c '.source' "$pricing_bundled" | sed 's/","/",\n             "/')" \
        "$(printf '%s' "$after" \
            | jq -r 'to_entries | map("    " + (.key | tojson) + ":" + (.value | tojson)) | join(",\n")' \
            | sed 's/:/: /g; s/,/, /g; s/, $/,/')"
    echo "${pricing_bundled#"$repo_root_abs/"}"
    jq -n -r --argjson a "$before" --argjson b "$after" '
        ($b | to_entries[] | select($a[.key] == null) | "  added    " + .key),
        ($b | to_entries[] | select($a[.key] != null and $a[.key] != .value) | "  changed  " + .key)'
}

# Writes the cache as the current view plus the failure's time and reason, so the fetch is not
# retried for a day.
note_fetch_failure() {
    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    mkdir -p "$(dirname "$pricing_cache")" 2>/dev/null || return 0
    pricing_current | jq --arg f "$now $1" '.fetch_failed = $f' > "$pricing_cache.tmp.$$" 2>/dev/null \
        && mv "$pricing_cache.tmp.$$" "$pricing_cache" || rm -f "$pricing_cache.tmp.$$"
}

# Decides whether to fetch, fetches, and sets rates_line and prices_tsv. $1 is the needed model ids,
# space separated.
ensure_pricing() {
    local needed="$1" current fetched failed why id since need_fetch=0 dated
    current="$(pricing_current)"
    fetched="$(printf '%s' "$current" | jq -r '.fetched // empty' | tr -d '\r')"
    failed="$(printf '%s' "$current" | jq -r '.fetch_failed // empty' | tr -d '\r')"
    dated="$(jq -r '.dated // empty' "$pricing_bundled" | tr -d '\r')"

    for id in $needed; do
        if pricing_has "$id" "$current"; then continue; fi
        since="$(pricing_missing_since "$id" "$current")"
        if [ -z "$since" ] || [ "$(days_since "$since")" -gt 1 ]; then need_fetch=1; fi
    done
    # No cache yet is a fetch. The cache's age is its fetch, or its failed fetch when it has never
    # been fetched.
    stamp="${fetched:-$failed}"
    if [ -z "$stamp" ] || [ "$(days_since "$stamp")" -gt 7 ]; then need_fetch=1; fi
    if [ -n "$failed" ] && [ "$(days_since "$failed")" -le 1 ]; then need_fetch=0; fi

    if [ "$need_fetch" -eq 1 ]; then
        if fetch_pricing "$needed"; then
            current="$(pricing_current)"
            fetched="$(printf '%s' "$current" | jq -r '.fetched // empty' | tr -d '\r')"
            failed=""
        else
            note_fetch_failure "$fetch_reason"
            failed="$(date -u +%Y-%m-%dT%H:%M:%SZ) $fetch_reason"
        fi
    fi

    # A failure is named while it still holds the fetch back: this run's, or one less than a day old.
    why=""
    if [ -n "$failed" ] && [ "$(days_since "$failed")" -le 1 ]; then
        why=" (fetching current rates failed: ${failed#* })"
    fi
    if [ -n "$fetched" ] && [ -z "$failed" ]; then
        rates_line="Rates: fetched ${fetched%%T*}."
    elif [ -n "$fetched" ]; then
        rates_line="Rates: cached copy from ${fetched%%T*}$why."
    else
        rates_line="Rates: the plugin's table, dated ${dated:-unknown}$why."
    fi

    prices_tsv="${TMPDIR:-/tmp}/cost-prices.$$"
    printf '%s' "$current" | jq -r '
        .models | to_entries[] | select(.value.missing == null)
        | [.key, .value.input, .value.output, (.value.cache_read // 0.1),
           (.value.cache_write_5m // 1.25), (.value.cache_write_1h // 2), (.value.window // "")]
        | @tsv' 2>/dev/null | tr -d '\r' > "$prices_tsv"
}

# usd_read, usd_write, usd_out and window for one model's counts, tab separated; four empty fields
# when the model is priced nowhere. Input and cache reads are priced at the model's input rate and
# the read multiplier, cache writes at their TTL's multiplier, output at the output rate.
price_fields() {
    awk -F '\t' -v id="$1" -v inp="$2" -v out="$3" -v cc5="$4" -v cc1="$5" -v cr="$6" '
    BEGIN { bare = id; sub(/-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/, "", bare) }
    $1 == id { row = $0; exit }
    $1 == bare && row == "" { row = $0 }
    END {
        if (row == "") { printf "\t\t\t\n"; exit }
        split(row, f, "\t")
        printf "%.6f\t%.6f\t%.6f\t%s\n",
            (inp + cr * f[4]) * f[2] / 1000000,
            (cc5 * f[5] + cc1 * f[6]) * f[2] / 1000000,
            out * f[3] / 1000000, f[7]
    }' "$prices_tsv"
}

# ---------------------------------------------------------------- records

# One TSV line per agent.
agent_records() {
    local line f priced
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        f="$(printf '%s' "$line" | jq -r '
            [(.model // ""), (.tokens.input // 0), (.tokens.output // 0),
             (.tokens.cache_create_5m // 0), (.tokens.cache_create_1h // 0), (.tokens.cache_read // 0)]
            | @tsv' | tr -d '\r')"
        priced="$(price_fields "$(printf '%s' "$f" | cut -f1)" "$(printf '%s' "$f" | cut -f2)" \
            "$(printf '%s' "$f" | cut -f3)" "$(printf '%s' "$f" | cut -f4)" \
            "$(printf '%s' "$f" | cut -f5)" "$(printf '%s' "$f" | cut -f6)")"
        printf '%s' "$line" | jq -r --arg priced "$priced" '
            ["A", .id, (.parent // ""), (.started // ""), (.ended // ""), (.session // ""),
             (.agent // ""), (.model // ""),
             (.tokens.input // 0), (.tokens.output // 0),
             (.tokens.cache_create_5m // 0), (.tokens.cache_create_1h // 0), (.tokens.cache_read // 0),
             (.turns // 0), (.peak_ctx // 0), (.offset // "")]
            + ($priced | split("\t"))
            + [(.seconds // 0), (.plan // "")]
            | @tsv' | tr -d '\r'
    done < <(current_lines)
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

# The session's window from its mapping file: transcript, first framework call (line 3), latest
# (line 4, which the report's own call refreshes), offset (line 5). Nothing when unavailable.
session_window() {
    local s="$1" git_dir map transcript first to offset
    git_dir="$(cd "$repo_root_abs" && git rev-parse --git-dir 2>/dev/null)" || return 0
    case "$git_dir" in
        ""|/*|?:*) ;;
        *) git_dir="$repo_root_abs/$git_dir" ;;
    esac
    map="$git_dir/tdd-sdlc/sessions/$s"
    [ -f "$map" ] || return 0
    transcript="$(sed -n '2p' "$map" | tr '\134' '/')"
    first="$(sed -n '3p' "$map")"
    to="$(sed -n '4p' "$map")"
    offset="$(sed -n '5p' "$map")"
    [ -n "$to" ] || to="$(last_ended_of "$s")"
    if [ ! -f "$transcript" ] || [ -z "$first" ] || [ -z "$to" ]; then return 0; fi
    printf '%s\t%s\t%s\t%s\n' "$transcript" "$first" "$to" "$offset"
}

# The skill's own turns: the session transcript's assistant messages inside the window, grouped by
# `message.id` as the hook groups them, one TSV line per model the session answered with:
# model, input, output, cache_create_5m, cache_create_1h, cache_read, turns, peak_ctx.
session_tokens() {
    local transcript="$1" from="$2" to="$3"
    jq -Rr -n --arg from "$from" --arg to "$to" '
        def cc5m: (.message.usage.cache_creation.ephemeral_5m_input_tokens
            // (if (.message.usage.cache_creation | type) == "object" then 0
                else (.message.usage.cache_creation_input_tokens // 0) end));
        def cc1h: (.message.usage.cache_creation.ephemeral_1h_input_tokens // 0);
        def ctx: ((.message.usage.input_tokens // 0) + cc5m + cc1h
            + (.message.usage.cache_read_input_tokens // 0));
        [inputs | select(length > 0) | (fromjson? // empty)
         | select(.type == "assistant")
         | select((.timestamp // "")[0:19] >= $from[0:19] and (.timestamp // "")[0:19] <= $to[0:19])]
        | to_entries | group_by(.value.message.id // ("line-" + (.key | tostring))) | map(last.value)
        | group_by(.message.model // "")[]
        | [(.[0].message.model // ""),
           (map(.message.usage.input_tokens // 0) | add // 0),
           (map(.message.usage.output_tokens // 0) | add // 0),
           (map(cc5m) | add // 0), (map(cc1h) | add // 0),
           (map(.message.usage.cache_read_input_tokens // 0) | add // 0),
           length, (map(ctx) | max // 0)]
        | @tsv' < "$transcript" | tr -d '\r'
}

# Every model id the report needs a rate for: the agent lines' and the sessions' own.
needed_models() {
    local s w
    {
        current_lines | jq -r '.model // empty' | tr -d '\r'
        while IFS= read -r s; do
            [ -n "$s" ] || continue
            w="$(session_window "$s")"
            [ -n "$w" ] || continue
            session_tokens "$(printf '%s' "$w" | cut -f1)" "$(printf '%s' "$w" | cut -f2)" \
                "$(printf '%s' "$w" | cut -f3)" | cut -f1
        done < <(sessions_of)
    } | grep -v '^$' | sort -u | tr '\n' ' '
}

# S records: one per session. Each model's messages are priced at that model; the row's peak context
# is the largest one and its window that model's. The two `unavailable` branches print the full width.
session_records() {
    local s w transcript first to offset line priced
    local inp out cc5 cc1 cr turns model models ur uw uo pw pk unpriced i o c5 c1 r t p
    while IFS= read -r s; do
        [ -n "$s" ] || continue
        w="$(session_window "$s")"
        if [ -z "$w" ]; then
            printf 'S\t%s\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tunavailable\n' "$s"
            continue
        fi
        transcript="$(printf '%s' "$w" | cut -f1)"; first="$(printf '%s' "$w" | cut -f2)"
        to="$(printf '%s' "$w" | cut -f3)"; offset="$(printf '%s' "$w" | cut -f4)"
        inp=0; out=0; cc5=0; cc1=0; cr=0; turns=0; models=""; ur=0; uw=0; uo=0; pw=""; pk=-1; unpriced=0
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            model="$(printf '%s' "$line" | cut -f1)"; i="$(printf '%s' "$line" | cut -f2)"
            o="$(printf '%s' "$line" | cut -f3)"; c5="$(printf '%s' "$line" | cut -f4)"
            c1="$(printf '%s' "$line" | cut -f5)"; r="$(printf '%s' "$line" | cut -f6)"
            t="$(printf '%s' "$line" | cut -f7)"; p="$(printf '%s' "$line" | cut -f8)"
            inp=$((inp + i)); out=$((out + o)); cc5=$((cc5 + c5)); cc1=$((cc1 + c1)); cr=$((cr + r))
            turns=$((turns + t))
            if [ -n "$model" ] && ! printf '%s' ",$models," | grep -q ",$model,"; then
                models="${models:+$models,}$model"
            fi
            priced="$(price_fields "$model" "$i" "$o" "$c5" "$c1" "$r")"
            if [ -z "$(printf '%s' "$priced" | cut -f1)" ]; then
                unpriced=1
            else
                ur="$(awk -v a="$ur" -v b="$(printf '%s' "$priced" | cut -f1)" 'BEGIN { printf "%.6f", a + b }')"
                uw="$(awk -v a="$uw" -v b="$(printf '%s' "$priced" | cut -f2)" 'BEGIN { printf "%.6f", a + b }')"
                uo="$(awk -v a="$uo" -v b="$(printf '%s' "$priced" | cut -f3)" 'BEGIN { printf "%.6f", a + b }')"
            fi
            if [ "$p" -gt "$pk" ]; then pk="$p"; pw="$(printf '%s' "$priced" | cut -f4)"; fi
        done < <(session_tokens "$transcript" "$first" "$to")
        [ "$pk" -ge 0 ] || pk=0
        if [ "$unpriced" -eq 1 ]; then ur=""; uw=""; uo=""; fi
        printf 'S\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tok\n' \
            "$s" "$first" "$to" "$inp" "$out" "$cc5" "$cc1" "$cr" "$turns" "$pk" "$offset" \
            "$ur" "$uw" "$uo" "$pw" "$models"
    done < <(sessions_of)
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
        [ -f "$pricing_bundled" ] || die "no pricing table beside the script: $pricing_bundled"
        resolve_jsonl "$target"
        review_dir="$(cd "$(dirname "$jsonl")" && pwd)"
        task_dir="$(dirname "$review_dir")"
        task_name="$(basename "$task_dir")"
        now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

        ensure_pricing "$(needed_models)"
        records="${TMPDIR:-/tmp}/cost-records.$$"
        { agent_records; session_records; } > "$records" \
            || { rm -f "$records" "$prices_tsv"; die "could not read $jsonl" 1; }
        skipped="$(skipped_count)"
        if ! grep -q '^A' "$records"; then
            rm -f "$records" "$prices_tsv"
            die "${jsonl#"$repo_root_abs/"} holds no agent lines" 1
        fi

        rewrite_file "$review_dir/cost.md" \
            awk -v task="$task_name" -v now="$now" -v skipped="${skipped:-0}" \
                -v rates="$rates_line" -f "$renderer" "$records"
        echo "${review_dir#"$repo_root_abs/"}/cost.md"
        echo "$rates_line"
        rm -f "$records" "$prices_tsv"
        ;;

    refresh-pricing)
        command -v jq >/dev/null 2>&1 || die "refresh-pricing needs jq" 1
        [ -f "$pricing_bundled" ] || die "no pricing table beside the script: $pricing_bundled"
        [ -z "$target" ] || die "refresh-pricing takes no task"
        refresh_pricing
        ;;

    *)
        die "unknown command '$command' (try --help)"
        ;;
esac
