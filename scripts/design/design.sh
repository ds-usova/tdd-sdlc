#!/usr/bin/env bash
#
# Reads a task's spec by decision ID, and answers the one question every stage downstream asks of
# it: is this settled, or does something still need deciding?
#
# A task directory holds three files this script reads: spec.md (requirements, scenarios, the
# user's decisions), design.md (context, the solution), design-log.md (the grill's concerns, the
# findings, what each decision rested on). `settled`, `status` and `show` read the spec; `validate`
# reads all three. Nothing here stores state beside them, and nothing here edits them.
#
# See the README next to this script.

set -u

# The parser ships beside this script and is found relative to it. The project is not: installed as
# a plugin, this file sits in a cache directory outside any checkout, so the task is located from
# where the command was run rather than from where the script lives.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
parser="$script_dir/design-parse.awk"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

task_dir=""
spec_file=""
design_file=""
log_file=""

usage() {
    cat <<'EOF'
Usage:
  <plugin>/scripts/design/design.sh settled  [<task>]
  <plugin>/scripts/design/design.sh status   [<task>]
  <plugin>/scripts/design/design.sh show     <ID>... [<task>]
  <plugin>/scripts/design/design.sh validate [<task>] [--spec <f>] [--design <f>] [--log <f>]

Commands:
  settled   The gate. Exit 0 when no decision is still must-decide; exit 1 and list the open ones
            when any is. What plan-task and implement-plan check before they run.
  status    How many decisions rest on each basis.
  show      One decision: its question, Answer and Basis. Several IDs print in order, separated by
            a blank line.
  validate  The spec: missing or out-of-order sections, duplicate IDs, an R no scenario proves, a
            scenario proving no R, an entry outside Decisions, a missing or repeated Answer:/Basis:,
            an unrecognized basis, a basis with nothing after it, an answered must-decide, an
            unanswered decided, a basis that belongs in the log. The design: the Affected Modules
            line, its sections, a source file named in Proposed Solution. The log: its sections, no
            Grilled (...) line, a concern the named grill owns with no row, a row with no verdict or
            why, an F row out of order or with an empty cell, a decided entry with no Decision Bases
            line. A must-decide is not itself a problem here - a spec in flight is expected to have
            them; that is what `settled` is for.

<task> is the task directory, or any one of its files - spec.md, design.md, design-log.md; the
others are found beside it. --file is accepted for either. Without one, the single docs/<n>-<task>/
in flight is used. An archived task under docs/implemented/ is addressed explicitly. --spec,
--design and --log override one file each.

Exit codes: 0 done - 1 no such entry, not settled, or validate found problems - 2 bad usage.
EOF
}

die() {
    echo "$1" >&2
    exit "${2:-2}"
}

# A task is addressed by its directory or by any file in it; the three files are then siblings.
resolve_task() {
    local candidates=()
    if [ -z "$task_dir" ]; then
        while IFS= read -r f; do
            candidates+=("$f")
        done < <(find "$repo_root/docs" -maxdepth 2 -name 'spec.md' -type f \
            -not -path '*/implemented/*' 2>/dev/null | sort)
        case "${#candidates[@]}" in
            0) die "no <n>-<task>/spec.md in $repo_root/docs - pass the task directory" ;;
            1) task_dir="$(dirname "${candidates[0]}")" ;;
            *)
                {
                    echo "docs/ holds ${#candidates[@]} tasks in flight - pass one:"
                    printf '  %s\n' "${candidates[@]%/spec.md}" | sed "s|^$repo_root/||"
                } >&2
                exit 2
                ;;
        esac
    fi
    [ -d "$task_dir" ] || die "no such task directory: $task_dir"
    [ -n "$spec_file" ] || spec_file="$task_dir/spec.md"
    [ -n "$design_file" ] || design_file="$task_dir/design.md"
    [ -n "$log_file" ] || log_file="$task_dir/design-log.md"
    [ -f "$spec_file" ] || die "no spec file: $spec_file"
}

# An explicit --spec/--design/--log wins over the positional whichever order they were given in.
take_task() {
    [ -z "$task_dir" ] || die "task given twice: $task_dir and $1"
    if [ -d "$1" ]; then task_dir="$1"; return 0; fi
    [ -f "$1" ] || die "no such task or file: $1"
    task_dir="$(dirname "$1")"
    case "$(basename "$1")" in
        spec.md)       [ -n "$spec_file" ] || spec_file="$1" ;;
        design.md)     [ -n "$design_file" ] || design_file="$1" ;;
        design-log.md) [ -n "$log_file" ] || log_file="$1" ;;
        *)             [ -n "$spec_file" ] || spec_file="$1" ;;
    esac
}

command="${1:-}"
[ -n "$command" ] || { usage; exit 2; }
shift

args=()
while [ $# -gt 0 ]; do
    case "$1" in
        --file)    take_task "${2:-}"; shift 2 ;;
        --spec)    spec_file="${2:-}"; shift 2 ;;
        --design)  design_file="${2:-}"; shift 2 ;;
        --log)     log_file="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        # A bare path is accepted wherever --file is, on every subcommand - including a directory
        # name with no slash in it. Without this it lands in args and is silently ignored, and the
        # command validates the one task in flight instead - the wrong one, with no way to tell.
        *.md|*/*)  take_task "$1"; shift ;;
        *)
            if [ -d "$1" ] || [ -f "$1" ]; then take_task "$1"; else args+=("$1"); fi
            shift ;;
    esac
done

case "$command" in
    validate)
        resolve_task
        # Only files that exist are passed; the parser reports a missing one from the count.
        set -- "$spec_file"
        if [ -f "$design_file" ]; then
            set -- "$@" "$design_file"
            [ -f "$log_file" ] && set -- "$@" "$log_file"
        fi
        awk -f "$parser" -v mode=validate -v files=$# "$@"
        ;;

    status)
        resolve_task
        awk -f "$parser" -v mode=status "$spec_file"
        ;;

    settled)
        resolve_task
        open="$(awk -f "$parser" -v mode=open "$spec_file")"
        if [ -z "$open" ]; then
            echo "settled - every decision has a basis"
            exit 0
        fi
        {
            echo "not settled - still must-decide:"
            echo "$open" | sed 's/^/  /'
        } >&2
        exit 1
        ;;

    show)
        [ "${#args[@]}" -gt 0 ] || die "show needs at least one decision ID"
        resolve_task
        first=1
        for id in "${args[@]}"; do
            range="$(awk -f "$parser" -v mode=range -v want="$id" "$spec_file")" \
                || die "no decision $id in ${spec_file#"$repo_root/"}" 1
            [ -n "$range" ] || die "no decision $id in ${spec_file#"$repo_root/"}" 1
            [ "$first" = "0" ] && echo
            first=0
            sed -n "${range% *},${range#* }p" "$spec_file"
        done
        ;;

    *)
        die "unknown command '$command' (try --help)"
        ;;
esac
