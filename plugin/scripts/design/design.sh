#!/usr/bin/env bash
#
# Reads a task's spec by decision ID, and answers the one question every stage downstream asks of
# it: is this settled, or does something still need deciding?
#
# A task directory holds a spec, optional design artifacts linked from it, and design-log.md.
# `settled`, `status` and `show` read the spec; `validate` reads the spec and the log. It also
# checks every linked artifact. Nothing here stores state beside them, and nothing here edits them.
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
log_file=""

usage() {
    cat <<'EOF'
Usage:
  <plugin>/scripts/design/design.sh settled  [<task>]
  <plugin>/scripts/design/design.sh approved [<task>]
  <plugin>/scripts/design/design.sh approve  <who> [<task>]
  <plugin>/scripts/design/design.sh status   [<task>]
  <plugin>/scripts/design/design.sh show     <ID>... [<task>]
  <plugin>/scripts/design/design.sh validate [<task>] [--spec <f>] [--log <f>]

Commands:
  settled   Exit 0 when no decision is still must-decide; exit 1 and list the open ones when any is.
  approved  Exit 0 when the spec's **Approved:** line carries the hash of the spec as it stands; exit 1
            and say whether the line is missing or predates an edit. plan-task and implement-plan
            check both settled and approved before they run.
  approve   Write or rewrite "**Approved:** <who>, <date>, <hash>" under the spec's **Format:** line.
            The hash is of the spec from its first "## " heading to the end, so a later edit to
            the spec makes the approval stale.
  status    How many decisions rest on each basis.
  show      One decision: its question, Answer and Basis. Several IDs print in order, separated by
            a blank line.
  validate  The spec: missing or out-of-order sections, duplicate IDs, an R no scenario proves, a
            scenario proving no R, an entry outside Decisions, a missing or repeated Answer:/Basis:,
            an unrecognized basis, a basis with nothing after it, an answered must-decide, an
            unanswered decided, a basis that belongs in the log, the Affected Modules line and the
            Design Artifacts index. Each linked artifact must exist beside the spec. The log: its sections, no
            Grilled (...) line, a concern the named grill owns with no row, a row with no verdict or
            why, an F row out of order or with an empty cell, a decided entry with no Decision Bases
            line. A must-decide is not itself a problem here - a spec in flight is expected to have
            them; that is what `settled` is for.

<task> is the task directory, or any Markdown file directly inside it. The spec and log are found
beside it. --file is accepted for either. Without one, the single docs/<n>-<task>/ in flight is
used. An archived task under docs/implemented/ is addressed explicitly. --spec and --log override
one file each.

Exit codes: 0 done - 1 no such entry, not settled, or validate found problems - 2 bad usage.
EOF
}

die() {
    echo "$1" >&2
    exit "${2:-2}"
}

# A task is addressed by its directory or by any Markdown file directly inside it.
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
    [ -n "$log_file" ] || log_file="$task_dir/design-log.md"
    [ -f "$spec_file" ] || die "no spec file: $spec_file"
}

# An explicit --spec/--log wins over the positional whichever order they were given in.
take_task() {
    [ -z "$task_dir" ] || die "task given twice: $task_dir and $1"
    if [ -d "$1" ]; then task_dir="$1"; return 0; fi
    [ -f "$1" ] || die "no such task or file: $1"
    task_dir="$(dirname "$1")"
    case "$(basename "$1")" in
        spec.md)       [ -n "$spec_file" ] || spec_file="$1" ;;
        design-log.md) [ -n "$log_file" ] || log_file="$1" ;;
    esac
}

# Every file a script validates carries "**Format:** <n>" in its header, written by the skill that
# created it. A file with no such line predates format 2 - single-letter ids, D3 and B7 - and is
# reported as such rather than failing on symptoms. The number is scripts/README.md's, "Formats".
FORMAT=2
check_format() {
    local file="$1" found
    found="$(sed -n 's/^\*\*Format:\*\*[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$file" | head -1)"
    if [ -z "$found" ]; then
        echo "${file#"$repo_root/"}: no **Format:** line - written before format $FORMAT (ids were one letter: D3, B7). Migrate the ids by hand and add \"**Format:** $FORMAT\" under the title, or archive it as it is"
        return 1
    fi
    if [ "$found" != "$FORMAT" ]; then
        echo "${file#"$repo_root/"}: **Format:** $found, and this plugin reads format $FORMAT"
        return 1
    fi
    return 0
}

# In-place editing goes through a sibling temp file rather than `sed -i`, whose spelling differs
# between GNU and BSD.
rewrite_file() {
    local target="$1"
    shift
    local tmp="${target}.design-tmp.$$"
    if "$@" > "$tmp" && mv "$tmp" "$target"; then
        return 0
    fi
    rm -f "$tmp"
    die "could not write $target"
}

# The spec from its first "## " heading to the end, carriage returns stripped, hashed by git, which
# is already required; sha1sum is not on every platform. The header lines above it - the title,
# Format, Approved - are not part of what was approved.
spec_hash() {
    awk 'BEGIN { on = 0 } /^## / { on = 1 } on { sub(/\r$/, ""); print }' "$1" | git hash-object --stdin | cut -c1-12
}

approved_line() {
    sed -n 's/^\*\*Approved:\*\*[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' "$1" | head -1
}

artifact_paths() {
    awk '
        /^## / { in_artifacts = ($0 == "## Design Artifacts"); next }
        in_artifacts && /^- \[[^]]+\]\([^)]+\)/ {
            path = $0
            sub(/^- \[[^]]+\]\(/, "", path)
            sub(/\).*/, "", path)
            print path
        }
    ' "$1"
}

command="${1:-}"
[ -n "$command" ] || { usage; exit 2; }
shift

args=()
while [ $# -gt 0 ]; do
    case "$1" in
        --file)    take_task "${2:-}"; shift 2 ;;
        --spec)    spec_file="${2:-}"; shift 2 ;;
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
        rc=0
        artifacts=()
        while IFS= read -r artifact; do
            [ -n "$artifact" ] || continue
            case "$artifact" in
                */*|*\\*|spec.md|design-log.md|*.md.md|.*|*[!a-z0-9.-]*)
                    echo "spec: design artifact '$artifact' must be a lowercase Markdown filename beside the spec"
                    rc=1
                    ;;
                *.md)
                    if [ -f "$task_dir/$artifact" ]; then
                        artifacts+=("$task_dir/$artifact")
                    else
                        echo "spec: design artifact '$artifact' does not exist beside the spec"
                        rc=1
                    fi
                    ;;
                *)
                    echo "spec: design artifact '$artifact' must be a Markdown file"
                    rc=1
                    ;;
            esac
        done < <(artifact_paths "$spec_file")

        # The parser receives artifacts between the spec and the log. Only existing files are passed;
        # the checks above report a missing artifact and the parser reports a missing log.
        set -- "$spec_file"
        for artifact in "${artifacts[@]}"; do set -- "$@" "$artifact"; done
        [ -f "$log_file" ] && set -- "$@" "$log_file"
        logidx=0
        [ -f "$log_file" ] && logidx=$#
        awk -f "$parser" -v mode=validate -v files=$# -v logidx="$logidx" "$@" || rc=1
        check_format "$spec_file" || rc=1
        exit "$rc"
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

    approved)
        resolve_task
        approved="$(approved_line "$spec_file")"
        if [ -z "$approved" ]; then
            echo "not approved - the spec carries no **Approved:** line; plan-task writes it when started on the spec" >&2
            exit 1
        fi
        recorded="${approved##*, }"
        current="$(spec_hash "$spec_file")"
        if [ "$recorded" != "$current" ]; then
            echo "approval predates an edit - the spec changed since **Approved:** was written; run plan-task on it again" >&2
            exit 1
        fi
        echo "approved by ${approved%, *}"
        exit 0
        ;;

    approve)
        who="${args[0]:-}"
        [ -n "$who" ] || die "approve needs who approved"
        resolve_task
        hash="$(spec_hash "$spec_file")"
        [ -n "$hash" ] || die "could not hash the spec - is git on PATH?"
        line="**Approved:** $who, $(date +%Y-%m-%d), $hash"
        if grep -q '^\*\*Approved:\*\*' "$spec_file"; then
            line="$line" rewrite_file "$spec_file" awk '/^\*\*Approved:\*\*/ { print ENVIRON["line"]; next } { print }' "$spec_file"
        elif grep -q '^\*\*Format:\*\*' "$spec_file"; then
            line="$line" rewrite_file "$spec_file" awk '{ print } /^\*\*Format:\*\*/ { print ENVIRON["line"] }' "$spec_file"
        else
            die "the spec has no **Format:** line to write the approval under"
        fi
        echo "$line"
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
