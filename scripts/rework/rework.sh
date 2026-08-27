#!/usr/bin/env bash
#
# Reads and updates a rework's checklist by step ID, so that ticking a box or pulling out one step is
# an addressed operation rather than a text match against a wrapped bullet.
#
# The rework file stays the single source of truth for the work, and the log beside it for what
# happened to it: nothing here stores state anywhere else. There is no scheduling command, because a
# rework declares no order - "needs:" states a fact, not a sequence.
#
# See the README next to this script.

set -u

# The parser ships beside this script and is found relative to it. The project is not: installed as
# a plugin, this file sits in a cache directory outside any checkout, so the rework is located from
# where the command was run rather than from where the script lives.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
parser="$script_dir/rework-parse.awk"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

rework_file=""
log_file=""

usage() {
    cat <<'EOF'
Usage:
  <plugin>/scripts/rework/rework.sh status   [--file <rework>] [--log <log>]
  <plugin>/scripts/rework/rework.sh show     <ID>... [--file <rework>] [--log <log>]
  <plugin>/scripts/rework/rework.sh tick     <ID>... [--file <rework>] [--log <log>]
  <plugin>/scripts/rework/rework.sh block    <ID> <note> [--file <rework>] [--log <log>]
  <plugin>/scripts/rework/rework.sh validate [--file <rework> | <rework directory>] [--log <log>]

Commands:
  status    Done/total, the IDs still open, and the IDs abandoned.
  show      One step: its header and everything indented under it. Several IDs print in order,
            separated by a blank line.
  tick      Mark the steps done. Several IDs are one batch: all are resolved before any is written,
            so a name nothing defines ticks none of them.
  block     Leave the step open and record the note as the next B entry of the log's Run Log.
  validate  Duplicate or missing IDs, an unrecognized kind, a line the kind does not take, a line
            the kind owes and does not carry, a placeholder value, a "survives:" naming no tier,
            "needs:"/"disables:" pointing at a step nothing defines, an unanswered Open Question, a
            fenced block that never closes, a missing log, a Run Log or an Attempts section or a B
            or A entry in the steps file, and a B entry outside the log's Run Log or numbered below
            the one before it.

--file defaults to the single rework.md in flight under docs/. A <module>/steps.md, and an
archived rework under docs/implemented/, are addressed by passing --file explicitly, or by a path
given positionally on any subcommand. Each file's log
sits beside it as <file-stem>-log.md - rework-log.md, steps-log.md; --log names another. validate
given the rework's directory validates rework.md and every steps file under it, each with its log,
in one call; a step named with its file ("shared/steps.md · R01") is not resolved across files.

Exit codes: 0 done - 1 nothing matched or validate found problems - 2 bad usage.
EOF
}

die() {
    echo "$1" >&2
    exit "${2:-2}"
}

# In-place editing is done by rewriting through a sibling temp file rather than with `sed -i`, whose
# spelling differs between GNU and BSD: on BSD the flag takes the backup suffix as its argument, so
# the GNU form silently means something else. The temp file is a sibling so the move stays on one
# filesystem.
rewrite_file() {
    local target="$1"
    shift
    local tmp="${target}.rework-tmp.$$"
    if "$@" > "$tmp" && mv "$tmp" "$target"; then
        return 0
    fi
    rm -f "$tmp"
    die "could not write $target"
}

locate_rework() {
    if [ -n "$rework_file" ]; then
        [ -f "$rework_file" ] || die "no such file: $rework_file"
        return
    fi

    local found
    found="$(find "$repo_root/docs" -mindepth 2 -maxdepth 2 -name rework.md \
        -not -path '*/implemented/*' 2>/dev/null | sort)"

    local count
    count="$(printf '%s' "$found" | grep -c . || true)"

    case "$count" in
        0) die "no rework.md in flight under docs/ - name one with --file" ;;
        1) rework_file="$found" ;;
        *) die "several reworks are in flight; name one with --file:
$found" ;;
    esac
}

# The log sits beside its file under the one name, the file's stem with "-log" appended; --log
# overrides it. Absent, it is passed to nothing: validate reports it, and block refuses.
resolve_log() {
    local base
    base="$(basename "$rework_file" .md)"
    [ -n "$log_file" ] || log_file="$(dirname "$rework_file")/${base}-log.md"
}

# Steps are read from the file, run-log entries from the log beside it. The log is passed only where
# it exists; the parser is told how many files it got.
parse() {
    resolve_log
    local files=("$rework_file")
    [ -f "$log_file" ] && files+=("$log_file")
    awk -v mode="$1" -v files="${#files[@]}" -f "$parser" "${files[@]}"
}

# A truncated read must not answer as a whole one. Only validate reports it and carries on, since
# reporting it is the whole of what validate does. The log is read too, so the next B number is
# never computed on half a log.
assert_read_whole() {
    parse fence || die "read as far as an unclosed fenced block - nothing below it counted" 1
}

# The parser's checks over the file and, where it exists, the log; then the log's absence, which
# only this script can name the path of.
validate_one() {
    local failed=0
    resolve_log
    parse validate || failed=1
    if [ ! -f "$log_file" ]; then
        echo "no rework log at ${log_file#"$repo_root/"} - the run log lives there"
        failed=1
    fi
    return "$failed"
}

# Every file of one rework: rework.md and each <module>/steps.md or shared/steps.md beside it. The
# logs are not enumerated; each is read with the file it belongs to.
cmd_validate_dir() {
    local dir="$1" f found=0 failed=0
    [ -d "$dir" ] || die "no such directory: $dir"
    [ -z "$log_file" ] || die "--log names one log; a directory validates each file with its own"

    while IFS= read -r f; do
        [ -n "$f" ] || continue
        found=$((found + 1))
        rework_file="$f"
        log_file=""
        validate_one || failed=1
    done < <(find "$dir" -maxdepth 2 \( -name 'rework.md' -o -name 'steps.md' \) -type f | sort)

    [ "$found" -gt 0 ] || die "${dir} holds no rework.md or steps.md" 1
    return "$failed"
}

cmd_status() {
    local total=0 done_count=0 open="" abandoned=""
    while IFS=$'\t' read -r id state _ _ _; do
        [ -n "$id" ] || continue
        total=$((total + 1))
        case "$state" in
            x) done_count=$((done_count + 1)) ;;
            a) abandoned="${abandoned:+$abandoned }$id" ;;
            *) open="${open:+$open }$id" ;;
        esac
    done < <(parse list)

    [ "$total" -gt 0 ] || die "$rework_file defines no steps" 1

    printf '%s\n  %d/%d\n' "$rework_file" "$done_count" "$total"
    [ -z "$open" ] || printf '  open: %s\n' "$open"
    [ -z "$abandoned" ] || printf '  abandoned: %s\n' "$abandoned"
    if [ -z "$open" ] && [ -z "$abandoned" ]; then
        printf '  every step is ticked\n'
    fi
}

step_range() {
    local id="$1" rid _ rstart rend
    while IFS=$'\t' read -r rid _ _ rstart rend; do
        if [ "$rid" = "$id" ]; then
            echo "$rstart $rend"
            return 0
        fi
    done < <(parse list)
    return 1
}

step_state() {
    local id="$1" rid rstate _
    while IFS=$'\t' read -r rid rstate _ _ _; do
        if [ "$rid" = "$id" ]; then
            echo "$rstate"
            return 0
        fi
    done < <(parse list)
    return 1
}

cmd_show() {
    [ "$#" -gt 0 ] || die "show needs at least one ID"

    local first=1 id range
    for id in "$@"; do
        range="$(step_range "$id")" || die "no such step: $id" 1

        [ "$first" = 1 ] || echo
        first=0
        sed -n "${range% *},${range#* }p" "$rework_file"
    done
}

cmd_tick() {
    [ "$#" -gt 0 ] || die "tick needs at least one ID"

    # Every ID is resolved before any line is written, so a typo ticks nothing. A step already
    # ticked is named and left alone.
    local lines="" ticked="" id state range
    for id in "$@"; do
        state="$(step_state "$id")" || die "no such step: $id" 1
        if [ "$state" = x ]; then
            echo "already ticked: $id"
            continue
        fi
        range="$(step_range "$id")"
        lines="${lines:+$lines,}${range% *}"
        ticked="${ticked:+$ticked }$id"
    done
    [ -n "$lines" ] || return 0

    # Anchored to the checkbox at the head of the line. An unanchored substitution rewrites the first
    # "[ ]" anywhere on it, which on an already-ticked step is somewhere in its prose - a silent edit
    # to a step's text that nothing else would ever report.
    rewrite_file "$rework_file" awk -v targets="$lines" '
        BEGIN { n = split(targets, t, ","); for (i = 1; i <= n; i++) mark[t[i]] = 1 }
        NR in mark { sub(/^-[ \t]+\[ \]/, "- [x]") }
        { print }
    ' "$rework_file"

    echo "ticked: $ticked"
}

cmd_block() {
    local id="${1:-}" note="${2:-}"
    [ -n "$id" ] && [ -n "$note" ] || die "block needs a step ID and a note"
    [ "$#" -le 2 ] || die "block takes one ID and one note - quote the note"
    resolve_log
    step_range "$id" > /dev/null || die "no such step: $id" 1
    [ -f "$log_file" ] || die "no rework log at ${log_file#"$repo_root/"} - rework writes it beside the file"

    # Appended as the next B entry at the end of the log's Run Log, which is created when absent.
    # The number comes from the parser, so the entry lands above nothing that came before it.
    local b runlog_start next_section insert_at
    b="$(parse nextblock)"
    runlog_start="$(grep -n '^## Run Log' "$log_file" | head -1 | cut -d: -f1)"
    if [ -z "$runlog_start" ]; then
        rewrite_file "$log_file" awk '{ print } END { print ""; print "## Run Log" }' "$log_file"
        runlog_start="$(grep -n '^## Run Log' "$log_file" | head -1 | cut -d: -f1)"
    fi
    next_section="$(awk -v s="$runlog_start" 'NR > s && /^## / { print NR; exit }' "$log_file")"
    [ -n "$next_section" ] || next_section="$(( $(wc -l < "$log_file") + 1 ))"
    insert_at="$(awk -v s="$runlog_start" -v e="$next_section" \
        'NR > s && NR < e && NF { last = NR } END { print (last ? last : s) }' "$log_file")"

    # The note travels in the environment, not through -v, which would expand escape sequences
    # in whatever the caller wrote.
    entry="- **B${b} (${id}):** ${note}" \
        rewrite_file "$log_file" awk -v n="$insert_at" \
            '{ print } NR == n { print ""; print ENVIRON["entry"]; print "  - Resolved:" }' "$log_file"
    echo "$id left open; recorded as B${b} in ${log_file#"$repo_root/"}"
}

command="${1:-}"
[ -n "$command" ] || { usage; exit 2; }
shift || true

args=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --file)
            [ "$#" -ge 2 ] || die "--file needs a path"
            rework_file="$2"
            shift 2
            ;;
        --log)
            [ "$#" -ge 2 ] || die "--log needs a path"
            [ -d "$2" ] && die "--log takes one file"
            log_file="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        # A mistyped flag must not fall through to the step IDs. "show"/"tick" would report it as a step
        # nothing defines, and "status"/"validate" take no IDs at all - so a wrong flag naming a rework
        # would be discarded in silence and the command answered for whichever file --file defaulted to.
        --*)
            die "unknown option '$1' (try --help)"
            ;;
        *)
            args+=("$1")
            shift
            ;;
    esac
done

case "$command" in
    status|show|tick|block|validate) ;;
    --help|-h) usage; exit 0 ;;
    *) die "unknown command '$command' (try --help)" ;;
esac

# A directory validates the whole rework; a path to one file is the same as naming it with --file.
if [ "$command" = validate ] && [ "${#args[@]}" -gt 0 ]; then
    if [ -d "${args[0]}" ]; then
        cmd_validate_dir "${args[0]}"
        exit "$?"
    fi
    [ -f "${args[0]}" ] || die "no such file or directory: ${args[0]}"
    rework_file="${args[0]}"
    args=()
fi

# A path given positionally names the file on every command, as it does on validate. Without this,
# "status docs/7-x/module-a/steps.md" would answer for whichever rework.md the default resolution
# found, which on a multi-module rework is the wrong one and says nothing about it. block's note is
# exempt: a reason may well name a file.
rest=()
for arg in ${args[@]+"${args[@]}"}; do
    if [ "$command" = "block" ] && [ "${#rest[@]}" -lt 2 ]; then
        rest+=("$arg")
    elif [ -f "$arg" ]; then
        rework_file="$arg"
    else
        rest+=("$arg")
    fi
done
args=(${rest[@]+"${rest[@]}"})

locate_rework

case "$command" in
    status)   assert_read_whole; cmd_status ;;
    show)     assert_read_whole; cmd_show ${args[@]+"${args[@]}"} ;;
    tick)     assert_read_whole; cmd_tick ${args[@]+"${args[@]}"} ;;
    block)    assert_read_whole; cmd_block ${args[@]+"${args[@]}"} ;;
    validate) validate_one ;;
esac
