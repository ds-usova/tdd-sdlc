#!/usr/bin/env bash
#
# Reads and updates a plan's checklist by item ID, so that ticking a box or pulling out one step is
# an addressed operation rather than a text match against a wrapped bullet in a thousand-line file.
#
# The plan stays the single source of truth: nothing here stores state beside it, and the dependency
# graph is parsed out of the "after:" fields on demand rather than kept in a second file.
#
# See the README next to this script.

set -u

# The parser ships beside this script and is found relative to it. The project is not: installed as
# a plugin, this file sits in a cache directory outside any checkout, so the plan is located from
# where the command was run rather than from where the script lives.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
parser="$script_dir/plan-parse.awk"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# Git prints a drive-letter path on Windows while `pwd` prints a POSIX one, and comparing a directory
# against its parent needs both in the same spelling.
repo_root_abs="$(cd "$repo_root" && pwd)"

plan_file=""
log_file=""

usage() {
    cat <<'EOF'
Usage:
  <plugin>/scripts/plan/plan.sh status   [--file <plan>]
  <plugin>/scripts/plan/plan.sh next     [--group <g>] [--section <s>]... [--all] [--file <plan>]
  <plugin>/scripts/plan/plan.sh show     <ID>... [--file <plan>]
  <plugin>/scripts/plan/plan.sh tick     <ID>... [--file <plan>]
  <plugin>/scripts/plan/plan.sh block    <ID> <note> [--file <plan>] [--log <log>]
  <plugin>/scripts/plan/plan.sh validate [--file <plan>] [--log <log>]
  <plugin>/scripts/plan/plan.sh stub     [<path>...] [--marker <token>] [--file <plan>] [--log <log>]
  <plugin>/scripts/plan/plan.sh stubs    [--file <plan>] [--log <log>]
  <plugin>/scripts/plan/plan.sh suite    record --stage <s> --total <n> --skipped <n> --verdict green|red <path>... [--file <plan>]
  <plugin>/scripts/plan/plan.sh suite    check [--file <plan>] [--log <log>]
  <plugin>/scripts/plan/plan.sh task     [<task directory> | <plan>]
  <plugin>/scripts/plan/plan.sh acceptance [<task directory> | <plan>]

Commands:
  status    Done/total per group, and the IDs still open.
  next      Items whose "after:" dependencies are all ticked, longest remaining chain first.
            --all also lists the items that are still waiting, and on what.
            --group and --section confine it to part of the plan, matched case-insensitively on any
            part of the heading. A run covering one phase must pass --group, or the phase after it
            becomes eligible the moment this one is finished. --section may be repeated.
  show      One item: its header and everything indented under it. Several IDs print in order,
            separated by a blank line.
  tick      Mark the items done. Several IDs are one batch: all are resolved before any is written,
            so a name nothing defines ticks none of them.
  block     Leave the item open and record the reason as the next RL entry of the plan log's Run Log.
  validate  A missing or older **Format:** line, duplicate IDs, items with no ID, dependencies on IDs nothing defines, cycles, placeholder
            given/when/then values, update: bullets naming a test method that is nowhere in the tree,
            a finding or a blockers section left in the plan, a missing plan log, and findings in it
            missing a Resolution: or an unapplied mechanical Action:.
  stub      Record the files stabilization stubbed, as the log's Stubs section. The first call writes
            the section with the marker an intent comment starts with (--marker, default
            "stub-intent:"); later calls append. No path records an empty section. Paths are
            recorded relative to the repository root.
  stubs     Every recorded file still carrying the marker, file:line each. Exit 1 while any does.
            tick refuses a green item whose target class's recorded file still carries it.
  suite     record: append a full suite run to the log's Suite Runs section - the stage, the figures,
            the verdict, and a hash of the tree under the paths given. check: rehash the paths the last
            entry names; exit 0 and print its figures when the tree is unchanged, exit 1 when it moved.
            No commit is made: the hash is git write-tree over a throwaway index.
  task      Every plan the task holds, its done/total, and whether all of them are finished.
            Takes the task directory, or nothing when only one task is in flight. A plan works
            too, for a caller that has one and not the directory. Exit 0 means nothing is open
            anywhere in the task.
  acceptance
            Every AC scenario the task's spec.md numbers, against the plans: the ticked red and
            performance steps naming it, each step's test class, and the file in the tree that
            class lives in - or a coverage note holding it. Exit 0 means every scenario is
            covered or held. A report, not a gate: what to do with a scenario nothing covers is
            the caller's.

--file defaults to the single plan in flight under docs/. A task owns a directory holding the spec,
the design and its log, and one plan per module it touches: plan.md for a single-module task,
<module>/plan.md for each module of a multi-module one. Each plan's plan-log.md sits beside it;
--log names another. Archived plans under docs/implemented/ are addressed by passing --file
explicitly.

A multi-module task therefore has several plans in flight, and every command names the one it
addresses - the ambiguity is reported, never guessed.

Exit codes: 0 done - 1 nothing matched, validate found problems, or task found something open -
2 bad usage.
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
    local tmp="${target}.plan-tmp.$$"
    if "$@" > "$tmp" && mv "$tmp" "$target"; then
        return 0
    fi
    rm -f "$tmp"
    die "could not write $target"
}

rewrite_plan() {
    rewrite_file "$plan_file" "$@"
}

# The log sits beside its plan under the one name; --log overrides it. Absent, it is passed to
# nothing: validate reports it, and block refuses.
resolve_log() {
    [ -n "$log_file" ] || log_file="$(dirname "$plan_file")/plan-log.md"
}

resolve_plan() {
    local candidates=()
    if [ -n "$plan_file" ]; then
        [ -f "$plan_file" ] || die "no such plan file: $plan_file"
        return 0
    fi
    while IFS= read -r f; do
        candidates+=("$f")
    # maxdepth 3 so a per-module plan at <n>-<task>/<module>/plan.md is found alongside the
    # single-module <n>-<task>/plan.md.
    done < <(find "$repo_root/docs" -maxdepth 3 -name 'plan.md' -type f \
        -not -path '*/implemented/*' 2>/dev/null | sort)

    case "${#candidates[@]}" in
        0) die "no <n>-<task>/plan.md or <n>-<task>/<module>/plan.md in $repo_root/docs - pass --file <plan>" ;;
        1) plan_file="${candidates[0]}" ;;
        *)
            {
                echo "docs/ holds ${#candidates[@]} plans in flight - pass --file <plan>:"
                printf '  %s\n' "${candidates[@]#"$repo_root/"}"
            } >&2
            exit 2
            ;;
    esac
}

item_range() {
    awk -f "$parser" -v mode=range -v want="$1" "$plan_file"
}

# A truncated read must not answer as a whole one. Only validate reports it and carries on, since
# reporting it is the whole of what validate does.
assert_read_whole() {
    resolve_log
    local files=("$plan_file")
    [ -f "$log_file" ] && files+=("$log_file")
    awk -f "$parser" -v mode=fence "${files[@]}" \
        || die "${plan_file#"$repo_root/"} read as far as an unclosed fenced block - nothing below it counted" 1
}

# A task owns one directory directly under docs/, and its plans sit either in it or one level deeper.
# Walking up to that level is exact, where looking for a sibling design.md is not: a task may be
# planned before its design is written, and an archived task keeps the same shape one level lower.
task_dir_of() {
    local dir
    dir="$(cd "$(dirname "$1")" && pwd)"
    while [ "$dir" != "/" ] && [ "$dir" != "$repo_root_abs" ]; do
        local parent
        parent="$(dirname "$dir")"
        if [ "$parent" = "$repo_root_abs/docs" ] || [ "$parent" = "$repo_root_abs/docs/implemented" ]; then
            break
        fi
        dir="$parent"
    done
    echo "$dir"
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

# The log's Stubs section: the marker an unimplemented stub's intent comment starts with, and the
# files stabilization stubbed. Written by `stub`, read by `stubs` and by `tick`; the marker travels in
# the file rather than in a flag, so a check months later reads the token the run actually used.
stubs_section_range() {
    awk '/^## Stubs/ { s = NR; next } s && /^## / { print s, NR - 1; e = 1; exit } END { if (s && !e) print s, NR }' "$log_file"
}

stubs_marker() {
    local range
    range="$(stubs_section_range)"
    [ -n "$range" ] || return 1
    sed -n "${range% *},${range#* }p" "$log_file" | sed -n 's/^Marker: `\(.*\)`[[:space:]]*$/\1/p' | head -1
}

stubs_files() {
    local range
    range="$(stubs_section_range)"
    [ -n "$range" ] || return 0
    sed -n "${range% *},${range#* }p" "$log_file" | sed -n 's/^- `\([^`]*\)`.*/\1/p'
}

# Prints file:line: text for every recorded file still carrying the marker. An optional class name
# narrows it to files whose basename is that class.
stubs_remaining() {
    local marker_token class="${1:-}" f
    marker_token="$(stubs_marker)" || return 0
    [ -n "$marker_token" ] || return 0
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        if [ -n "$class" ]; then
            case "$(basename "$f")" in
                "$class".*|"$class") ;;
                *) continue ;;
            esac
        fi
        [ -f "$repo_root/$f" ] || continue
        grep -nF -e "$marker_token" "$repo_root/$f" 2>/dev/null | sed "s|^|$f:|"
    done < <(stubs_files)
}

# A hash of the working tree under the given paths, as git would store it: the paths are staged into
# a throwaway index and write-tree prints the tree id. No commit, no ref, the real index untouched,
# ignored files left out. Two calls over an unchanged tree print the same id.
tree_hash() {
    # The temp index must not exist yet: git refuses an empty index file. It lives in the git dir, so
    # the path needs no translation on Windows.
    local gitdir idx rc
    gitdir="$(cd "$repo_root" && git rev-parse --git-dir 2>/dev/null)" || return 1
    case "$gitdir" in /*|?:*) ;; *) gitdir="$repo_root/$gitdir" ;; esac
    idx="$gitdir/index.plan-tmp.$$"
    rm -f "$idx"
    (
        cd "$repo_root" || exit 1
        GIT_INDEX_FILE="$idx" git add -A -- "$@" >/dev/null 2>&1 && GIT_INDEX_FILE="$idx" git write-tree
    )
    rc=$?
    rm -f "$idx"
    return $rc
}

suite_section_range() {
    awk '/^## Suite Runs/ { s = NR; next } s && /^## / { print s, NR - 1; e = 1; exit } END { if (s && !e) print s, NR }' "$log_file"
}

# The last entry: "- <stage> · tree <hash> · total <n> · skipped <n> · <verdict> · paths: a, b"
suite_last() {
    local range
    range="$(suite_section_range)"
    [ -n "$range" ] || return 1
    sed -n "${range% *},${range#* }p" "$log_file" | grep '^- ' | tail -1
}

# The target class of an item: the first backticked name after the ID on the header line.
item_target_class() {
    sed -n "${1}p" "$plan_file" | sed -n 's/^- \[[ xX]\] [A-Za-z]*[0-9]* · `\([^`]*\)`.*/\1/p'
}

# The task directory and its plans, from a plan, a task directory, or nothing at all. Sets task_dir
# and plans. A single plan cannot answer a question about the task it belongs to, and both `task`
# and `acceptance` ask one.
resolve_task() {
    if [ -n "$plan_file" ] && [ -d "$plan_file" ]; then
        task_dir="$(cd "$plan_file" && pwd)"
    elif [ -n "$plan_file" ]; then
        [ -f "$plan_file" ] || die "no such plan file or task directory: $plan_file"
        task_dir="$(task_dir_of "$plan_file")"
    else
        local dirs=() f d
        while IFS= read -r f; do
            d="$(task_dir_of "$f")"
            case " ${dirs[*]-} " in
                *" $d "*) ;;
                *) dirs+=("$d") ;;
            esac
        done < <(find "$repo_root_abs/docs" -maxdepth 3 -name 'plan.md' -type f \
            -not -path '*/implemented/*' 2>/dev/null | sort)
        case "${#dirs[@]}" in
            0) die "no task directory under docs/ holds a plan - name one" ;;
            1) task_dir="${dirs[0]}" ;;
            *)
                {
                    echo "docs/ holds ${#dirs[@]} tasks in flight - name one:"
                    printf '  %s\n' "${dirs[@]#"$repo_root_abs/"}"
                } >&2
                exit 2
                ;;
        esac
    fi

    plans=()
    while IFS= read -r f; do
        plans+=("$f")
    done < <(find "$task_dir" -maxdepth 2 -name 'plan.md' -type f | sort)
    [ "${#plans[@]}" -gt 0 ] || die "${task_dir#"$repo_root_abs/"} holds no plan.md" 1
}

# The scenario ids the spec's Acceptance Scenarios section numbers, one per line, in order.
spec_scenarios() {
    awk '
        { sub(/\r$/, "") }
        /^## / { in_ac = ($0 == "## Acceptance Scenarios"); next }
        in_ac && /^- \*\*AC[0-9]+:\*\*/ {
            id = $0
            sub(/^- \*\*/, "", id)
            sub(/:\*\*.*$/, "", id)
            print id
        }' "$1"
}

# The file that holds the class: the first whose basename is the class, with or without an
# extension, else the first whose text names it as a word - a pytest class or a Go test function
# lives in a file named otherwise. Only files git sees are searched, so build output and
# dependencies are left to .gitignore; docs/ is left out too, since every plan names the class.
class_file() {
    local hit
    hit="$(cd "$repo_root_abs" && git ls-files -co --exclude-standard 2>/dev/null \
        | grep -v '^docs/' | awk -v c="$1" '{ b = $0; sub(/.*\//, "", b); if (b == c || index(b, c ".") == 1) print }' \
        | sort | head -1)"
    if [ -z "$hit" ] && [ -n "$1" ]; then
        hit="$(cd "$repo_root_abs" && git ls-files -co --exclude-standard 2>/dev/null \
            | grep -v '^docs/' | sort \
            | while IFS= read -r f; do
                grep -qIw -F -e "$1" "$f" 2>/dev/null && { printf '%s\n' "$f"; break; }
            done)"
    fi
    [ -n "$hit" ] && printf '%s\n' "$repo_root_abs/$hit"
}

command="${1:-}"
[ -n "$command" ] || { usage; exit 2; }
case "$command" in
    --help|-h) usage; exit 0 ;;
esac
shift

args=()
verbose=0
marker=""
stage=""; total=""; skipped=""; verdict=""
group_filter=""
section_filter=""
while [ $# -gt 0 ]; do
    case "$1" in
        --file)    plan_file="${2:-}"; shift 2 ;;
        --log)
            [ ! -d "${2:-}" ] || die "--log takes one file"
            log_file="${2:-}"; shift 2 ;;
        --group)   group_filter="${2:-}"; shift 2 ;;
        --section) section_filter="${section_filter:+$section_filter,}${2:-}"; shift 2 ;;
        --all)     verbose=1; shift ;;
        --marker)  marker="${2:-}"; shift 2 ;;
        --stage)   stage="${2:-}"; shift 2 ;;
        --total)   total="${2:-}"; shift 2 ;;
        --skipped) skipped="${2:-}"; shift 2 ;;
        --verdict) verdict="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        # A bare plan path is accepted wherever --file is, on every subcommand. Without this the
        # ID-taking ones read it as an ID and fail with "no item docs/x.md in docs/x.md". block's
        # note is exempt: a reason may well contain a slash or end in ".md".
        *.md|*/*)
            if [ "$command" = "block" ] && [ "${#args[@]}" -lt 2 ]; then
                args+=("$1"); shift; continue
            fi
            # stub's and suite's arguments are source paths; only --file names their plan.
            if [ "$command" = "stub" ] || [ "$command" = "suite" ]; then
                args+=("$1"); shift; continue
            fi
            [ -z "$plan_file" ] || die "plan file given twice: $plan_file and $1"
            plan_file="$1"; shift ;;
        *) args+=("$1"); shift ;;
    esac
done

case "$command" in
    status)
        resolve_plan
        assert_read_whole
        awk -f "$parser" -v mode=status "$plan_file"
        ;;

    next)
        resolve_plan
        assert_read_whole
        awk -f "$parser" -v mode=next -v verbose="$verbose" \
            -v group_filter="$group_filter" -v section_filter="$section_filter" "$plan_file"
        ;;

    validate)
        resolve_plan
        resolve_log
        problems=0

        # The parser's own checks first: everything answerable from the two files' text alone. The
        # log is passed only where it exists; the parser reports its absence.
        files=("$plan_file")
        [ -f "$log_file" ] && files+=("$log_file")
        if ! awk -f "$parser" -v mode=validate -v summary=0 -v files="${#files[@]}" "${files[@]}"; then
            problems=1
        fi
        if [ ! -f "$log_file" ]; then
            echo "no plan log at ${log_file#"$repo_root/"} - the review findings and the run log live there"
            problems=1
        fi
        check_format "$plan_file" || problems=1

        # An "update:" bullet names a test that already exists - that is what distinguishes it from a
        # new scenario. One naming nothing in the tree is a plan written against remembered code.
        #
        # Plan files are excluded from the search, this one above all: it names the method itself, so
        # searching a tree that contains it would confirm every name against the very text under test.
        while IFS="$(printf '\t')" read -r id method; do
            [ -n "${method:-}" ] || continue
            if ! grep -rqI --exclude='plan.md' --exclude='plan-log.md' \
                    --exclude-dir=build --exclude-dir=.git --exclude-dir=.gradle \
                    --exclude-dir=node_modules --exclude-dir=target --exclude-dir=out \
                    -F -e "$method(" "$repo_root" 2>/dev/null; then
                echo "$id names '$method()' in an update: bullet, which exists nowhere in the repository"
                problems=1
            fi
        done < <(awk -f "$parser" -v mode=updates "$plan_file")

        if [ "$problems" -eq 0 ]; then
            IFS="$(printf '\t')" read -r n_items n_b < <(awk -f "$parser" -v mode=count "${files[@]}")
            echo "${plan_file#"$repo_root/"}: $n_items items, $n_b run-log entries, no problems"
        fi
        exit "$problems"
        ;;

    show)
        [ "${#args[@]}" -gt 0 ] || die "show needs at least one item ID"
        resolve_plan
        assert_read_whole
        first=1
        for id in "${args[@]}"; do
            range="$(item_range "$id")" || die "no item $id in ${plan_file#"$repo_root/"}" 1
            [ -n "$range" ] || die "no item $id in ${plan_file#"$repo_root/"}" 1
            [ "$first" = "0" ] && echo
            first=0
            sed -n "${range% *},${range#* }p" "$plan_file"
        done
        ;;

    tick)
        [ "${#args[@]}" -gt 0 ] || die "tick needs at least one item ID"
        resolve_plan
        assert_read_whole
        # Every ID is resolved before any is written, so a typo in the third leaves the first two
        # alone instead of half-applying a stage's batch.
        lines=()
        for id in "${args[@]}"; do
            range="$(item_range "$id")" || die "no item $id in ${plan_file#"$repo_root/"}" 1
            [ -n "$range" ] || die "no item $id in ${plan_file#"$repo_root/"}" 1
            lines+=("${range% *}")
        done
        # A green item claims its class is implemented. Where the log records the file stabilization
        # stubbed for that class and the marker is still in it, the claim is refused before anything
        # is written - the whole batch, since no ID is ticked until every one resolves.
        resolve_log
        if [ -f "$log_file" ]; then
            refused=0
            for i in "${!args[@]}"; do
                case "${args[$i]}" in
                    G[A-Z]*[0-9]*)
                        class="$(item_target_class "${lines[$i]}")"
                        [ -n "$class" ] || continue
                        left="$(stubs_remaining "$class")"
                        if [ -n "$left" ]; then
                            echo "${args[$i]}: \`$class\` still carries the stub marker:" >&2
                            printf '  %s\n' "$left" >&2
                            refused=1
                        fi
                        ;;
                esac
            done
            [ "$refused" -eq 0 ] || die "nothing ticked - implement the stub or remove its marker first" 1
        fi
        # Ticking replaces "- [ ]" with "- [x]" in place, so no line moves and the ranges resolved
        # above stay valid for the whole batch.
        for i in "${!args[@]}"; do
            line="${lines[$i]}"
            if sed -n "${line}p" "$plan_file" | grep -q '^- \[[xX]\]'; then
                echo "already ticked: ${args[$i]}"
                continue
            fi
            rewrite_plan awk -v n="$line" 'NR == n { sub(/^- \[ \]/, "- [x]") } { print }' "$plan_file"
            sed -n "${line}p" "$plan_file"
        done
        ;;

    block)
        id="${args[0]:-}"
        note="${args[1]:-}"
        [ -n "$id" ] && [ -n "$note" ] || die "block needs an item ID and a note"
        [ "${#args[@]}" -le 2 ] || die "block takes one ID and one note - quote the note"
        resolve_plan
        resolve_log
        assert_read_whole
        range="$(item_range "$id")" || die "no item $id in ${plan_file#"$repo_root/"}" 1
        [ -n "$range" ] || die "no item $id in ${plan_file#"$repo_root/"}" 1
        [ -f "$log_file" ] || die "no plan log at ${log_file#"$repo_root/"} - plan-task writes it beside the file"

        # Appended as the next RL entry at the end of the log's Run Log, which is created when absent.
        # The number comes from the parser, so the entry lands above nothing that came before it.
        b="$(awk -f "$parser" -v mode=nextblock "$plan_file" "$log_file")"
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
        entry="- **RL$(printf '%02d' "$b") (${id}):** ${note}" \
            rewrite_file "$log_file" awk -v n="$insert_at" \
                '{ print } NR == n { print ""; print ENVIRON["entry"]; print "  - Resolved:" }' "$log_file"
        echo "$id left open; recorded as RL$(printf '%02d' "$b") in ${log_file#"$repo_root/"}"
        ;;

    stub)
        # No path is a valid call: it records that stabilization stubbed nothing, as an empty section.
        resolve_plan
        resolve_log
        assert_read_whole
        [ -f "$log_file" ] || die "no plan log at ${log_file#"$repo_root/"} - plan-task writes it beside the file"
        rels=()
        for f in "${args[@]:-}"; do
            [ -n "$f" ] || continue
            [ -e "$f" ] || die "no such file: $f"
            abs="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
            case "$abs" in
                "$repo_root_abs"/*) rels+=("${abs#"$repo_root_abs/"}") ;;
                *) die "$f is outside the repository" ;;
            esac
        done
        if [ -z "$(stubs_section_range)" ]; then
            token="${marker:-stub-intent:}"
            marker_line="Marker: \`$token\`" \
                rewrite_file "$log_file" awk '{ print } END { print ""; print "## Stubs"; print ""; print ENVIRON["marker_line"]; print "" }' "$log_file"
        elif [ -n "$marker" ] && [ "$marker" != "$(stubs_marker)" ]; then
            die "the Stubs section already records marker \`$(stubs_marker)\`; --marker cannot change it"
        fi
        range="$(stubs_section_range)"
        end="${range#* }"
        for rel in "${rels[@]:-}"; do
            [ -n "$rel" ] || continue
            if stubs_files | grep -qxF "$rel"; then
                echo "already recorded: $rel"
                continue
            fi
            entry="- \`$rel\`" \
                rewrite_file "$log_file" awk -v n="$end" '{ print } NR == n { print ENVIRON["entry"] }' "$log_file"
            end=$(( end + 1 ))
            echo "recorded: $rel"
        done
        ;;

    stubs)
        resolve_plan
        resolve_log
        [ -f "$log_file" ] || die "no plan log at ${log_file#"$repo_root/"}" 1
        if [ -z "$(stubs_section_range)" ]; then
            echo "${log_file#"$repo_root/"}: no Stubs section - nothing recorded to check"
            exit 0
        fi
        left="$(stubs_remaining)"
        n_files="$(stubs_files | grep -c .)"
        if [ -n "$left" ]; then
            echo "stub marker \`$(stubs_marker)\` still present:"
            printf '  %s\n' "$left"
            exit 1
        fi
        echo "no stub marker remains in the $n_files recorded file(s)"
        exit 0
        ;;

    suite)
        sub="${args[0]:-}"
        [ "$sub" = "record" ] || [ "$sub" = "check" ] || die "suite takes record or check"
        resolve_plan
        resolve_log
        [ -f "$log_file" ] || die "no plan log at ${log_file#"$repo_root/"} - plan-task writes it beside the file"
        if [ "$sub" = "record" ]; then
            [ -n "$stage" ] && [ -n "$total" ] && [ -n "$skipped" ] && [ -n "$verdict" ] \
                || die "record needs --stage, --total, --skipped and --verdict"
            case "$verdict" in green|red) ;; *) die "--verdict is green or red" ;; esac
            [ "${#args[@]}" -gt 1 ] || die "record needs at least one path to hash"
            rels=()
            for f in "${args[@]:1}"; do
                [ -e "$f" ] || die "no such path: $f"
                abs="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
                case "$abs" in
                    "$repo_root_abs"/*) rels+=("${abs#"$repo_root_abs/"}") ;;
                    "$repo_root_abs") rels+=(".") ;;
                    *) die "$f is outside the repository" ;;
                esac
            done
            hash="$(tree_hash "${rels[@]}")" || die "could not hash the tree - is this a git repository?"
            if [ -z "$(suite_section_range)" ]; then
                rewrite_file "$log_file" awk '{ print } END { print ""; print "## Suite Runs"; print "" }' "$log_file"
            fi
            range="$(suite_section_range)"
            paths_joined="$(IFS=', '; echo "${rels[*]}")"
            entry="- $stage · tree $hash · total $total · skipped $skipped · $verdict · paths: $paths_joined" \
                rewrite_file "$log_file" awk -v n="${range#* }" '{ print } NR == n { print ENVIRON["entry"] }' "$log_file"
            echo "recorded: $stage · tree ${hash:0:12} · total $total · skipped $skipped · $verdict"
        else
            last="$(suite_last)" || die "no Suite Runs section in ${log_file#"$repo_root/"} - nothing recorded to compare" 1
            [ -n "$last" ] || die "the Suite Runs section is empty" 1
            l_stage="$(printf '%s' "$last" | sed 's/^- \(.*\) · tree .*/\1/')"
            l_hash="$(printf '%s' "$last" | sed 's/.* · tree \([0-9a-f]*\) .*/\1/')"
            l_total="$(printf '%s' "$last" | sed 's/.* · total \([0-9]*\) .*/\1/')"
            l_skipped="$(printf '%s' "$last" | sed 's/.* · skipped \([0-9]*\) .*/\1/')"
            l_verdict="$(printf '%s' "$last" | sed 's/.* · skipped [0-9]* · \([a-z]*\) .*/\1/')"
            l_paths="$(printf '%s' "$last" | sed 's/.* · paths: //')"
            rels=()
            IFS=',' read -r -a parts <<< "$l_paths"
            for p in "${parts[@]}"; do
                p="${p# }"; p="${p% }"
                [ -n "$p" ] && rels+=("$p")
            done
            now="$(tree_hash "${rels[@]}")" || die "could not hash the tree"
            if [ "$now" = "$l_hash" ]; then
                echo "unchanged since $l_stage: total $l_total, skipped $l_skipped, $l_verdict"
                exit 0
            fi
            echo "moved since $l_stage - run the suite"
            exit 1
        fi
        ;;

    task)
        # Given a plan, a task directory, or nothing at all: which plans the task holds, and whether
        # every one of them is finished. A single plan cannot answer that about the task it belongs
        # to, and archiving the directory is the decision that needs the answer.
        resolve_task
        echo "${task_dir#"$repo_root_abs/"}"
        unfinished=0
        for f in "${plans[@]}"; do
            read -r done_n total_n < <(awk -f "$parser" -v mode=items "$f" |
                awk -F'\t' '$2 == "done" { d++ } { t++ } END { print (d + 0), (t + 0) }')
            if [ "$total_n" -eq 0 ]; then
                # No IDs at all: either an empty plan or one predating the format. Both are open
                # questions, and neither is something to archive on.
                state="no items - not in plan format"
                unfinished=$(( unfinished + 1 ))
            elif [ "$done_n" -eq "$total_n" ]; then
                state="complete"
            else
                state="$(( total_n - done_n )) open"
                unfinished=$(( unfinished + 1 ))
            fi
            printf '  %-34s %3s/%-3s  %s\n' "${f#"$task_dir/"}" "$done_n" "$total_n" "$state"
        done

        # The verdict is a fact about the plans, not a decision about the directory: what an exit 0
        # authorizes is the calling skill's rule, not this script's.
        if [ "$unfinished" -eq 0 ]; then
            echo "every plan complete - nothing is open in this task"
            exit 0
        fi
        echo "$unfinished of ${#plans[@]} plans still open"
        exit 1
        ;;

    acceptance)
        # Every scenario the spec numbers, and what in the tree stands behind it: the ticked red or
        # performance steps that name it, each step's test class, and the file that class lives in.
        # The plan's traceability ends at the step line; this follows it one link further, into the
        # tree, and asks the last recorded suite run whether that tree is the one it saw.
        resolve_task
        spec="$task_dir/spec.md"
        [ -f "$spec" ] || die "no spec.md in ${task_dir#"$repo_root_abs/"} - nothing to check the plans against" 1
        scenarios="$(spec_scenarios "$spec")"
        [ -n "$scenarios" ] || die "${spec#"$repo_root_abs/"} numbers no AC scenario under '## Acceptance Scenarios'" 1

        # One record per (scenario, step): AC, plan, step id, open|done, class, file-or-empty.
        # One record per (scenario, note): AC, plan, "note", text. Collected as lines: bash 3 has
        # no associative arrays, and awk over a few dozen lines is as fast as anything.
        records=""
        unknown=""
        # Fields are joined on a unit separator: a tab is whitespace to `read`, so an empty class
        # or file would collapse and shift the fields after it.
        us="$(printf '\037')"
        for f in "${plans[@]}"; do
            rel="${f#"$task_dir/"}"
            while IFS="$us" read -r id state header; do
                case "$id" in RU*|RI*|RS*|PM*) ;; *) continue ;; esac
                acs="$(printf '%s\n' "$header" | awk '
                    {
                        if (!match($0, /scenarios:/)) exit
                        tail = substr($0, RSTART + RLENGTH)
                        cut = index(tail, " · ")
                        if (cut > 0) tail = substr(tail, 1, cut - 1)
                        while (match(tail, /AC[0-9]+/)) {
                            print substr(tail, RSTART, RLENGTH)
                            tail = substr(tail, RSTART + RLENGTH)
                        }
                    }')"
                [ -n "$acs" ] || continue
                class="$(printf '%s\n' "$header" | sed -n 's/.*test: `\([^`]*\)`.*/\1/p')"
                [ -n "$class" ] || class="$(printf '%s\n' "$header" | sed -n 's/^`\([^`]*\)`.*/\1/p')"
                file=""
                [ -n "$class" ] && file="$(class_file "$class")"
                file="${file#"$repo_root_abs/"}"
                for ac in $acs; do
                    if ! printf '%s\n' "$scenarios" | grep -qx "$ac"; then
                        unknown="$unknown$rel $id names $ac, which the spec does not carry
"
                        continue
                    fi
                    records="$records$ac$us$rel$us$id$us$state$us$class$us$file
"
                done
            done < <(awk -f "$parser" -v mode=items "$f" | awk -F'\t' -v OFS="$us" '{ print $1, $2, $8 }')

            # A coverage note is the one prose a group admits: which scenario an existing test
            # already holds, or which measurement the conventions leave unmeasured.
            # Only the note's subjects - the ids before "is held by" / "are held by" - are held by
            # it; an id the note merely mentions is not.
            while IFS= read -r line; do
                for ac in $(printf '%s\n' "$line" | awk '{
                        match($0, /^(AC[0-9]+(, AC[0-9]+)*( and AC[0-9]+)?) (is|are) (held by|a measurement)/)
                        subj = substr($0, 1, RLENGTH)
                        while (match(subj, /AC[0-9]+/)) {
                            print substr(subj, RSTART, RLENGTH)
                            subj = substr(subj, RSTART + RLENGTH)
                        }
                    }'); do
                    printf '%s\n' "$scenarios" | grep -qx "$ac" || continue
                    records="$records$ac$us$rel${us}note$us$line
"
                done
            done < <(awk '{ sub(/\r$/, "") } /^AC[0-9]+(, AC[0-9]+)*( and AC[0-9]+)? (is|are) (held by|a measurement)/' "$f")
        done

        # One row per scenario, held back until every verdict is known: the table's ID and Verdict
        # columns are padded to their widest cell, and Evidence is last, so it needs no padding.
        report=""
        problems=0
        for ac in $scenarios; do
            rows="$(printf '%s' "$records" | awk -F"$us" -v ac="$ac" '$1 == ac')"
            if [ -z "$rows" ]; then
                report="$report$ac${us}missing${us}no step names it and no coverage note holds it
"
                problems=1
                continue
            fi
            verdict="covered"
            detail=""
            while IFS="$us" read -r _ rel id state class file; do
                [ -n "$id" ] || continue
                if [ "$id" = "note" ]; then
                    detail="$detail · $state"
                    continue
                fi
                where="$rel"
                [ "$rel" = "plan.md" ] && where=""
                if [ "$state" != "done" ]; then
                    detail="$detail · $id ${where:+$where }open"
                    [ "$verdict" = "covered" ] && verdict="open"
                elif [ -z "$class" ]; then
                    detail="$detail · $id ${where:+$where }names no test class"
                    verdict="absent"
                elif [ -z "$file" ]; then
                    detail="$detail · $id \`$class\` not in the tree"
                    verdict="absent"
                else
                    detail="$detail · $id \`$class\` ($file)"
                fi
            done < <(printf '%s\n' "$rows")
            # A note alone holds a scenario without a step; a note beside steps is just a note.
            if [ "$verdict" = "covered" ] && ! printf '%s\n' "$rows" | awk -F"$us" '$3 != "note" { f = 1 } END { exit !f }'; then
                verdict="held"
            fi
            [ "$verdict" = "covered" ] || [ "$verdict" = "held" ] || problems=1
            report="$report$ac$us$verdict$us${detail# · }
"
        done

        idw=2
        vw=7
        while IFS="$us" read -r ac verdict detail; do
            [ -n "$ac" ] || continue
            [ "${#ac}" -gt "$idw" ] && idw="${#ac}"
            [ "${#verdict}" -gt "$vw" ] && vw="${#verdict}"
        done < <(printf '%s' "$report")

        echo "${task_dir#"$repo_root_abs/"} · ${spec#"$task_dir/"}: $(printf '%s\n' "$scenarios" | grep -c .) scenarios"
        echo
        printf '| %-*s | %-*s | %s |\n' "$idw" "ID" "$vw" "Verdict" "Evidence"
        printf '|%s|%s|----------|\n' \
            "$(printf '%*s' "$((idw + 2))" '' | tr ' ' '-')" "$(printf '%*s' "$((vw + 2))" '' | tr ' ' '-')"
        while IFS="$us" read -r ac verdict detail; do
            [ -n "$ac" ] || continue
            printf '| %-*s | %-*s | %s |\n' "$idw" "$ac" "$vw" "$verdict" "$detail"
        done < <(printf '%s' "$report")

        if [ -n "$unknown" ]; then
            echo
            printf '%s\n' "${unknown%
}"
            problems=1
        fi
        echo
        if [ "$problems" -eq 0 ]; then
            echo "every scenario has a test class in the tree"
            exit 0
        fi
        echo "not every scenario has a test class in the tree - see above"
        exit 1
        ;;

    *)
        die "unknown command '$command' (try --help)"
        ;;
esac
