#!/usr/bin/env bash
#
# Reads and updates an upgrade's checklist by step ID, so that ticking a box or pulling out one step is
# an addressed operation rather than a text match against a wrapped bullet.
#
# The steps file stays the single source of truth for the work; the log beside it is what happened
# to it. Nothing here stores state anywhere else. There is no scheduling command, because an upgrade
# declares no order - "needs:" states a fact, not a sequence.
#
# See the README next to this script.

set -u

# The parser ships beside this script and is found relative to it. The project is not: installed as
# a plugin, this file sits in a cache directory outside any checkout, so the upgrade is located from
# where the command was run rather than from where the script lives.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
parser="$script_dir/upgrade-parse.awk"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

upgrade_file=""
log_file=""

usage() {
    cat <<'EOF'
Usage:
  <plugin>/scripts/upgrade/upgrade.sh status   [--file <steps>]
  <plugin>/scripts/upgrade/upgrade.sh show     <ID>... [--file <steps>]
  <plugin>/scripts/upgrade/upgrade.sh tick     <ID>... [--file <steps>]
  <plugin>/scripts/upgrade/upgrade.sh block    <ID> <note> [--file <steps>] [--log <log>]
  <plugin>/scripts/upgrade/upgrade.sh validate [--file <steps> | <upgrade directory>] [--log <log>]

Commands:
  status    Done/total, the IDs still open, and the IDs abandoned.
  show      One step: its header and everything indented under it. Several IDs print in order,
            separated by a blank line.
  tick      Mark the steps done. Several IDs are one batch: all are resolved before any is written,
            so a name nothing defines ticks none of them. One already ticked is reported and left.
  block     Leave the step open and record the note as the next B entry of the log's Run Log.
  validate  Duplicate or missing IDs, an unrecognized kind, a line the kind does not take, a line
            the kind owes and does not carry, a placeholder value, a "change:" naming no place,
            "needs:" pointing at a step nothing defines, an unanswered Open Question, a missing log,
            an attempts or run-log section left in the steps file, an attempt missing a line or its
            evidence or filed under no step, a B entry outside the log's Run Log or numbered below
            the one before it, and a kept-back entry missing what kept it or what would unblock it.

--file defaults to the single upgrade.md in flight under docs/. A <module>/steps.md, and an
archived upgrade under docs/implemented/, are addressed by passing --file explicitly, or the path
bare on any subcommand. Each file's
log sits beside it as <file-stem>-log.md - upgrade-log.md, steps-log.md; --log names another.
validate given the upgrade's directory validates upgrade.md and every steps file under it, each
with its own log, in one call; a step named with its file ("shared/steps.md · U01") is not
resolved across files.

Exit codes: 0 done - 1 nothing matched or validate found problems - 2 bad usage.
EOF
}

die() {
    echo "$1" >&2
    exit "${2:-2}"
}

# In-place editing is done by rewriting through a sibling temp file rather than with `sed -i`, whose
# spelling differs between GNU and BSD.
rewrite_file() {
    local target="$1"
    shift
    local tmp="${target}.upgrade-tmp.$$"
    if "$@" > "$tmp" && mv "$tmp" "$target"; then
        return 0
    fi
    rm -f "$tmp"
    return 1
}

locate_upgrade() {
    if [ -n "$upgrade_file" ]; then
        [ -f "$upgrade_file" ] || die "no such file: $upgrade_file"
        return
    fi

    local found
    found="$(find "$repo_root/docs" -mindepth 2 -maxdepth 2 -name upgrade.md \
        -not -path '*/implemented/*' 2>/dev/null | sort)"

    local count
    count="$(printf '%s' "$found" | grep -c . || true)"

    case "$count" in
        0) die "no upgrade.md in flight under docs/ - name one with --file" ;;
        1) upgrade_file="$found" ;;
        *) die "several upgrades are in flight; name one with --file:
$found" ;;
    esac
}

# The log sits beside its file under the file's own stem; --log overrides it. Absent, it is passed
# to nothing: validate reports it, and block refuses.
resolve_log() {
    local stem
    if [ -z "$log_file" ]; then
        stem="$(basename "$upgrade_file" .md)"
        log_file="$(dirname "$upgrade_file")/${stem}-log.md"
    fi
}

# Steps come from the steps file alone; the log is not read.
parse() {
    awk -v mode="$1" -f "$parser" "$upgrade_file"
}

# Both files, the log only where it exists; the parser is told how many it got.
parse_with_log() {
    local files=("$upgrade_file")
    [ -f "$log_file" ] && files+=("$log_file")
    awk -v mode="$1" -v files="${#files[@]}" -f "$parser" "${files[@]}"
}

# A truncated read must not answer as a whole one. Both files are checked, so a B number is never
# computed from a half-read log. Only validate reports it and carries on, since reporting it is the
# whole of what validate does.
assert_read_whole() {
    resolve_log
    parse_with_log fence || die "read as far as an unclosed fenced block - nothing below it counted" 1
}

cmd_validate() {
    local failed=0
    resolve_log
    parse_with_log validate || failed=1
    if [ ! -f "$log_file" ]; then
        echo "no upgrade log at ${log_file#"$repo_root/"} - the attempts and the run log live there"
        failed=1
    fi
    return "$failed"
}

# Every file of one upgrade: upgrade.md and each <module>/steps.md or shared/steps.md beside it,
# each with the log beside it.
cmd_validate_dir() {
    local dir="$1" f found=0 failed=0
    [ -d "$dir" ] || die "no such directory: $dir"
    [ -z "$log_file" ] || die "--log names one log; a directory validates each file with its own"

    while IFS= read -r f; do
        [ -n "$f" ] || continue
        found=$((found + 1))
        upgrade_file="$f"
        log_file=""
        cmd_validate || failed=1
    done < <(find "$dir" -maxdepth 2 \( -name 'upgrade.md' -o -name 'steps.md' \) -type f | sort)

    [ "$found" -gt 0 ] || die "${dir} holds no upgrade.md or steps.md" 1
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

    [ "$total" -gt 0 ] || die "$upgrade_file defines no steps" 1

    printf '%s\n  %d/%d\n' "$upgrade_file" "$done_count" "$total"
    [ -z "$open" ] || printf '  open: %s\n' "$open"
    [ -z "$abandoned" ] || printf '  abandoned: %s\n' "$abandoned"
    if [ -z "$open" ] && [ -z "$abandoned" ]; then
        printf '  every step is ticked\n'
    fi
}

# The header line of one step, or nothing.
step_start() {
    local id="$1" rid _ rstart
    while IFS=$'\t' read -r rid _ _ rstart _; do
        if [ "$rid" = "$id" ]; then
            echo "$rstart"
            return 0
        fi
    done < <(parse list)
    return 1
}

cmd_show() {
    [ "$#" -gt 0 ] || die "show needs at least one ID"

    local first=1 id start end matched
    for id in "$@"; do
        matched=""
        while IFS=$'\t' read -r rid _ _ rstart rend; do
            if [ "$rid" = "$id" ]; then
                start="$rstart"
                end="$rend"
                matched=1
                break
            fi
        done < <(parse list)

        [ -n "$matched" ] || die "no such step: $id" 1

        [ "$first" = 1 ] || echo
        first=0
        sed -n "${start},${end}p" "$upgrade_file"
    done
}

cmd_tick() {
    [ "$#" -gt 0 ] || die "tick needs at least one ID"

    # Every ID is resolved before any line is written, so a typo ticks nothing. One already ticked
    # is reported and left as it is.
    local lines="" ticked="" id rid state start found
    for id in "$@"; do
        found=""
        while IFS=$'\t' read -r rid state _ start _; do
            [ "$rid" = "$id" ] || continue
            found=1
            if [ "$state" = x ]; then
                echo "already ticked: $id"
            else
                lines="${lines:+$lines,}$start"
                ticked="${ticked:+$ticked }$id"
            fi
            break
        done < <(parse list)
        [ -n "$found" ] || die "no such step: $id" 1
    done

    [ -n "$lines" ] || return 0

    rewrite_file "$upgrade_file" awk -v targets="$lines" '
        BEGIN { n = split(targets, t, ","); for (i = 1; i <= n; i++) mark[t[i]] = 1 }
        NR in mark { sub(/^-[ \t]+\[ \]/, "- [x]") }
        { print }
    ' "$upgrade_file" || die "could not write $upgrade_file"

    echo "ticked: $ticked"
}

cmd_block() {
    local id="${1:-}" note="${2:-}"
    [ -n "$id" ] && [ -n "$note" ] || die "block needs a step ID and a note"
    [ "$#" -le 2 ] || die "block takes one ID and one note - quote the note"
    resolve_log
    step_start "$id" > /dev/null || die "no such step: $id" 1
    [ -f "$log_file" ] || die "no upgrade log at ${log_file#"$repo_root/"} - upgrade-deps writes it beside the file"

    # Appended as the next B entry at the end of the log's Run Log, which is created when absent.
    # The number comes from the parser, so the entry lands above nothing that came before it.
    local b runlog_start next_section insert_at
    b="$(parse_with_log nextblock)"
    runlog_start="$(grep -n '^## Run Log' "$log_file" | head -1 | cut -d: -f1)"
    if [ -z "$runlog_start" ]; then
        rewrite_file "$log_file" awk '{ print } END { print ""; print "## Run Log" }' "$log_file" \
            || die "could not write $log_file"
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
            '{ print } NR == n { print ""; print ENVIRON["entry"]; print "  - Resolved:" }' "$log_file" \
        || die "could not write $log_file"
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
            upgrade_file="$2"
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

# A directory validates the whole upgrade; a path to one file is the same as naming it with --file.
if [ "$command" = validate ] && [ "${#args[@]}" -gt 0 ]; then
    if [ -d "${args[0]}" ]; then
        cmd_validate_dir "${args[0]}"
        exit "$?"
    fi
    [ -f "${args[0]}" ] || die "no such file or directory: ${args[0]}"
    upgrade_file="${args[0]}"
fi

# A path given positionally names the file on every command, as it does on validate. Without this,
# "status docs/7-x/module-a/steps.md" would answer for whichever upgrade.md the default resolution
# found. block's ID and note are exempt: a reason may well name a file.
rest=()
for arg in ${args[@]+"${args[@]}"}; do
    if [ "$command" = "block" ] && [ "${#rest[@]}" -lt 2 ]; then
        rest+=("$arg")
    elif [ -f "$arg" ]; then
        upgrade_file="$arg"
    else
        rest+=("$arg")
    fi
done
args=(${rest[@]+"${rest[@]}"})

locate_upgrade

case "$command" in
    status)   assert_read_whole; cmd_status ;;
    show)     assert_read_whole; cmd_show ${args[@]+"${args[@]}"} ;;
    tick)     assert_read_whole; cmd_tick ${args[@]+"${args[@]}"} ;;
    block)    assert_read_whole; cmd_block ${args[@]+"${args[@]}"} ;;
    validate) cmd_validate ;;
esac
