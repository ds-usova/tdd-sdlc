#!/usr/bin/env bash
# Deterministic writer and validator for review/findings.md. See the README beside this script.
set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
parser="$script_dir/findings-parse.awk"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
temporary_files=()

remember_temporary_file() { temporary_files+=("$1"); }

cleanup_temporary_files() {
    local file
    for file in "${temporary_files[@]}"; do
        rm -f -- "$file"
    done
}

trap cleanup_temporary_files EXIT

usage() {
    cat <<'EOF'
Usage:
  findings.sh init <task-or-file> --title <title>
  findings.sh add-bug <task-or-file> --module M --summary S --given G --when W --then T
      --actual A --test TestClass#method --fix F --target PATH
  findings.sh add-critical <task-or-file> --module M --summary S
      --kind <bug|deferred-change|refactoring-candidate> --measured M --grows-because G
      --breaks-as B [--test TestClass#method] --fix F --target PATH
  findings.sh add-refactoring <task-or-file> --module M --what W --why Y
  findings.sh add-deferred <task-or-file> --module M --what W --why Y
  findings.sh add-performance <task-or-file> --module M --test T --threshold T --figure F
  findings.sh close <task-or-file> <RXnn|DXnn|PXnn> --status <done|withdrawn|wontfix> --reason R
  findings.sh close-bug <task-or-file> --test TestClass#method
      --status <done|withdrawn> --reason R
  findings.sh close-critical <task-or-file> --module M --summary S
      --status <done|withdrawn> --reason R
  findings.sh check <task-or-file>

A directory means <directory>/review/findings.md. Mutations validate before and after writing and replace
the file atomically. Exit codes: 0 done; 1 invalid finding, missing test class, or unmatched entry; 2 usage.
EOF
}

die() { echo "$1" >&2; exit "${2:-2}"; }

findings_path() {
    case "$1" in
        *.md) printf '%s\n' "$1" ;;
        *) printf '%s/review/findings.md\n' "${1%/}" ;;
    esac
}

one_line() {
    case "$2" in *$'\n'*|*$'\r'*) die "$1 must be one line" ;; esac
    [ -n "$2" ] || die "$1 must not be empty"
}

safe_code_span() {
    one_line "$1" "$2"
    case "$2" in *\`*) die "$1 must not contain a backtick" ;; esac
}

safe_heading_text() {
    one_line "$1" "$2"
    case "$2" in *'**'*) die "$1 must not contain '**'" ;; esac
}

need() { [ -n "$2" ] || die "missing $1"; one_line "$1" "$2"; }

test_class_exists() {
    local ref="$1" class hit
    class="${ref%%#*}"
    class="${class##*.}"
    class="${class%%\$*}"
    hit="$(cd "$repo_root" && git ls-files -co --exclude-standard 2>/dev/null |
        grep -v '^docs/' |
        awk -v c="$class" '{ b = $0; sub(/.*\//, "", b); if (b == c || index(b, c ".") == 1) print }' |
        sort | head -1)"
    if [ -z "$hit" ] && [ -n "$class" ]; then
        hit="$(cd "$repo_root" && git ls-files -co --exclude-standard 2>/dev/null |
            grep -v '^docs/' | sort |
            while IFS= read -r f; do
                grep -qIw -F -e "$class" "$f" 2>/dev/null && { printf '%s\n' "$f"; break; }
            done)"
    fi
    [ -n "$hit" ]
}

check_test_ref() {
    local ref="$1"
    [[ "$ref" =~ ^[A-Za-z_][A-Za-z0-9_.$]*#[A-Za-z_][A-Za-z0-9_$]*$ ]] ||
        die "--test must have the form TestClass#method, not '$ref'" 1
    [ "$ref" != none ] || die "--test must name a disabled reproduction, not none" 1
    test_class_exists "$ref" || die "--test names '$ref', but no non-ignored ${ref%%#*} class exists outside docs/" 1
}

validate_file() {
    local file="$1" refs failed=0 ref line
    [ -f "$file" ] || die "no findings file at $file" 1
    refs="${file}.findings-refs.$$"
    remember_temporary_file "$refs"
    : > "$refs" || die "cannot create a temporary file beside $file" 1
    awk -v mode=validate -v refs_file="$refs" -f "$parser" "$file" || failed=1
    while IFS=$'\t' read -r ref line; do
        [ -n "$ref" ] || continue
        if ! test_class_exists "$ref"; then
            echo "$file:$line: Test names '$ref', but no non-ignored ${ref%%#*} class exists outside docs/"
            failed=1
        fi
    done < "$refs"
    rm -f "$refs"
    return "$failed"
}

escape_table() { printf '%s' "$1" | sed 's/|/\\|/g'; }

section_rank() {
    case "$1" in
        Critical) echo 1 ;; Bug) echo 2 ;; "Refactoring candidate") echo 3 ;;
        "Deferred change") echo 4 ;; Performance) echo 5 ;; *) echo 99 ;;
    esac
}

# Adds a fragment to a section, or creates that section before the first later one. `table` says the fragment
# is one row and supplies the canonical header when the section is new.
insert_fragment() {
    local source="$1" output="$2" section="$3" fragment="$4" kind="$5" rank
    rank="$(section_rank "$section")"
    awk -v target="$section" -v target_rank="$rank" -v fragment="$fragment" -v kind="$kind" '
        function rank(s) {
            if (s == "Critical") return 1; if (s == "Bug") return 2
            if (s == "Refactoring candidate") return 3; if (s == "Deferred change") return 4
            if (s == "Performance") return 5; return 99
        }
        function copy_fragment(    x) { while ((getline x < fragment) > 0) print x; close(fragment) }
        function new_section() {
            print ""; print "## " target; print ""
            if (kind == "table") {
                if (target == "Performance") {
                    print "| # | Status | module | test | threshold | figure |"
                    print "|---|--------|--------|------|-----------|--------|"
                } else {
                    print "| # | Status | module | what | why |"
                    print "|---|--------|--------|------|-----|"
                }
            }
            copy_fragment(); emitted = 1
        }
        /^## / {
            heading = substr($0, 4)
            if (inside && !emitted) { print ""; copy_fragment(); emitted = 1 }
            inside = (heading == target)
            if (!emitted && !inside && rank(heading) > target_rank) new_section()
        }
        { print }
        END {
            if (inside && !emitted) { print ""; copy_fragment(); emitted = 1 }
            if (!emitted) new_section()
        }
    ' "$source" > "$output"
}

refresh_summary() {
    local source="$1" output="$2" summary
    summary="$(awk -v mode=summary -f "$parser" "$source")" || return 1
    awk -v summary="$summary" '
        !done && /^\*\*/ { print summary; done=1; next }
        { print }
    ' "$source" > "$output"
}

commit_candidate() {
    local file="$1" candidate="$2" refreshed="${file}.findings-refresh.$$"
    remember_temporary_file "$candidate"
    remember_temporary_file "$refreshed"
    if ! refresh_summary "$candidate" "$refreshed"; then
        rm -f "$candidate" "$refreshed"
        die "generated findings are invalid; $file was not changed" 1
    fi
    rm -f "$candidate"
    if ! validate_file "$refreshed" >/dev/null; then
        validate_file "$refreshed" >&2 || true
        rm -f "$refreshed"
        die "generated findings are invalid; $file was not changed" 1
    fi
    mv "$refreshed" "$file" || { rm -f "$refreshed"; die "could not replace $file" 1; }
}

next_id() {
    local file="$1" prefix="$2" max
    max="$(sed -n "s/^|[[:space:]]*${prefix}\([0-9][0-9]*\)[[:space:]]*|.*/\1/p" "$file" |
        awk 'BEGIN { m=0 } { if ($1+0 > m) m=$1+0 } END { print m+1 }')"
    printf '%s%02d\n' "$prefix" "$max"
}

validate_existing() { validate_file "$1" >/dev/null || { validate_file "$1" >&2 || true; exit 1; }; }

cmd_init() {
    [ $# -ge 1 ] || die "init needs a task directory or findings file"
    local file title="" path="$1"; shift
    while [ $# -gt 0 ]; do
        case "$1" in --title) [ $# -ge 2 ] || die "--title needs a value"; title="$2"; shift 2 ;;
            *) die "unknown init argument: $1" ;; esac
    done
    need --title "$title"
    file="$(findings_path "$path")"
    [ ! -e "$file" ] || die "$file already exists" 1
    mkdir -p "$(dirname "$file")" || die "could not create $(dirname "$file")" 1
    local tmp="${file}.findings-tmp.$$"
    remember_temporary_file "$tmp"
    printf '# Review: %s\n\n**Nothing open.**\n' "$title" > "$tmp" || die "could not write $tmp" 1
    validate_file "$tmp" >/dev/null || { rm -f "$tmp"; die "could not create a valid findings file" 1; }
    mv "$tmp" "$file" || { rm -f "$tmp"; die "could not create $file" 1; }
    echo "created: ${file#"$repo_root/"}"
}

parse_add_options() {
    module="" summary_text="" given="" when_text="" then_text="" actual="" test_ref="" fix="" target_path=""
    kind_value="" measured="" grows="" breaks="" what="" why="" threshold="" figure=""
    while [ $# -gt 0 ]; do
        [ $# -ge 2 ] || die "$1 needs a value"
        case "$1" in
            --module) module="$2" ;; --summary) summary_text="$2" ;; --given) given="$2" ;;
            --when) when_text="$2" ;; --then) then_text="$2" ;; --actual) actual="$2" ;;
            --test) test_ref="$2" ;; --fix) fix="$2" ;; --target) target_path="$2" ;;
            --kind) kind_value="$2" ;; --measured) measured="$2" ;; --grows-because) grows="$2" ;;
            --breaks-as) breaks="$2" ;; --what) what="$2" ;; --why) why="$2" ;;
            --threshold) threshold="$2" ;; --figure) figure="$2" ;; *) die "unknown option: $1" ;;
        esac
        shift 2
    done
}

add_fragment() {
    local file="$1" section="$2" fragment="$3" kind="$4" candidate="${file}.findings-tmp.$$"
    validate_existing "$file"
    insert_fragment "$file" "$candidate" "$section" "$fragment" "$kind" || {
        rm -f "$candidate"; die "could not build findings update" 1; }
    commit_candidate "$file" "$candidate"
}

cmd_add_bug() {
    [ $# -ge 1 ] || die "add-bug needs a task directory or findings file"
    local file path="$1" fragment; shift; parse_add_options "$@"
    need --module "$module"; need --summary "$summary_text"; need --given "$given"; need --when "$when_text"
    need --then "$then_text"; need --actual "$actual"; need --test "$test_ref"
    need --fix "$fix"; need --target "$target_path"
    safe_code_span --module "$module"; safe_heading_text --summary "$summary_text"
    safe_code_span --target "$target_path"
    check_test_ref "$test_ref"
    file="$(findings_path "$path")"; validate_existing "$file"; fragment="${file}.findings-fragment.$$"
    remember_temporary_file "$fragment"
    cat > "$fragment" <<EOF
**\`$module\` — $summary_text**

- **Given** $given
- **When** $when_text
- **Then** $then_text
- **Actual** $actual
- **Test** \`$test_ref\`, disabled
- **Fix** $fix · \`$target_path\`
EOF
    add_fragment "$file" Bug "$fragment" block; rm -f "$fragment"
    echo "added bug: $test_ref"
}

cmd_add_critical() {
    [ $# -ge 1 ] || die "add-critical needs a task directory or findings file"
    local file path="$1" fragment kind_render; shift; parse_add_options "$@"
    need --module "$module"; need --summary "$summary_text"; need --kind "$kind_value"; need --measured "$measured"
    need --grows-because "$grows"; need --breaks-as "$breaks"; need --fix "$fix"; need --target "$target_path"
    safe_code_span --module "$module"; safe_heading_text --summary "$summary_text"
    safe_code_span --target "$target_path"
    case "$kind_value" in
        bug) kind_render=bug; need --test "$test_ref"; check_test_ref "$test_ref" ;;
        deferred-change|"deferred change")
            kind_render="deferred change"
            [ -z "$test_ref" ] || die "--test is only valid for a critical bug"
            ;;
        refactoring-candidate|"refactoring candidate")
            kind_render="refactoring candidate"
            [ -z "$test_ref" ] || die "--test is only valid for a critical bug"
            ;;
        *) die "--kind must be bug, deferred-change, or refactoring-candidate" ;;
    esac
    file="$(findings_path "$path")"; validate_existing "$file"; fragment="${file}.findings-fragment.$$"
    remember_temporary_file "$fragment"
    {
        printf '**`%s` — %s**\n\n' "$module" "$summary_text"
        printf '%s\n' "- **Kind** $kind_render" "- **Measured** $measured"
        printf '%s\n' "- **Grows because** $grows" "- **Breaks as** $breaks"
        [ "$kind_render" != bug ] || printf '%s\n' "- **Test** \`$test_ref\`, disabled"
        printf '%s\n' "- **Fix** $fix · \`$target_path\`"
    } > "$fragment"
    add_fragment "$file" Critical "$fragment" block; rm -f "$fragment"
    echo "added critical finding"
}

cmd_add_table() {
    local command="$1" path="$2"; shift 2
    local file section prefix id fragment row_module row_a row_b row_c=""
    parse_add_options "$@"; need --module "$module"; safe_code_span --module "$module"
    case "$command" in
        add-refactoring)
            section="Refactoring candidate"; prefix=RX
            need --what "$what"; need --why "$why"; row_a="$what"; row_b="$why"
            ;;
        add-deferred)
            section="Deferred change"; prefix=DX
            need --what "$what"; need --why "$why"; row_a="$what"; row_b="$why"
            ;;
        add-performance)
            section=Performance; prefix=PX
            need --test "$test_ref"; need --threshold "$threshold"; need --figure "$figure"
            row_a="$test_ref"; row_b="$threshold"; row_c="$figure"
            ;;
    esac
    file="$(findings_path "$path")"; validate_existing "$file"; id="$(next_id "$file" "$prefix")"
    fragment="${file}.findings-fragment.$$"
    row_module="$(escape_table "$module")"; row_a="$(escape_table "$row_a")"
    row_b="$(escape_table "$row_b")"
    remember_temporary_file "$fragment"
    if [ "$section" = Performance ]; then
        row_c="$(escape_table "$row_c")"
        printf '| %s | open | `%s` | %s | %s | %s |\n' "$id" "$row_module" "$row_a" "$row_b" "$row_c" > "$fragment"
    else
        printf '| %s | open | `%s` | %s | %s |\n' "$id" "$row_module" "$row_a" "$row_b" > "$fragment"
    fi
    add_fragment "$file" "$section" "$fragment" table; rm -f "$fragment"
    echo "added: $id"
}

closed_status() {
    local for_block="$1" status="$2" reason="$3"
    need --status "$status"; need --reason "$reason"
    case "$status" in
        done|withdrawn) printf '%s · %s\n' "$status" "$reason" ;;
        wontfix) [ "$for_block" = 0 ] || die "close-bug does not accept wontfix"; printf 'wontfix · %s\n' "$reason" ;;
        *)
            if [ "$for_block" = 1 ]; then die "--status must be done or withdrawn"
            else die "--status must be done, withdrawn, or wontfix"; fi
            ;;
    esac
}

parse_close_options() {
    status_value=""; reason=""; test_ref=""
    while [ $# -gt 0 ]; do
        [ $# -ge 2 ] || die "$1 needs a value"
        case "$1" in
            --status) status_value="$2" ;; --reason) reason="$2" ;; --test) test_ref="$2" ;;
            *) die "unknown option: $1" ;;
        esac
        shift 2
    done
}

cmd_close() {
    [ $# -ge 2 ] || die "close needs a task/file and RXnn, DXnn, or PXnn"
    local file path="$1" id="$2" candidate status status_file matches; shift 2; parse_close_options "$@"
    [[ "$id" =~ ^(RX|DX|PX)[0-9][0-9]+$ ]] || die "close needs an RXnn, DXnn, or PXnn ID"
    status="$(escape_table "$(closed_status 0 "$status_value" "$reason")")"
    file="$(findings_path "$path")"; validate_existing "$file"
    matches="$(grep -Ec "^\|[[:space:]]*$id[[:space:]]*\|" "$file" || true)"
    [ "$matches" -eq 1 ] || die "found $matches rows named $id; nothing changed" 1
    grep -Eq "^\|[[:space:]]*$id[[:space:]]*\|[[:space:]]*open[[:space:]]*\|" "$file" || die "$id is already closed" 1
    candidate="${file}.findings-tmp.$$"
    status_file="${file}.findings-status.$$"
    remember_temporary_file "$candidate"
    remember_temporary_file "$status_file"
    printf '%s\n' "$status" > "$status_file" || die "could not build the status update" 1
    awk -v id="$id" -v status_file="$status_file" '
        BEGIN { getline status < status_file; close(status_file) }
        $0 ~ "^\\|[[:space:]]*" id "[[:space:]]*\\|" {
            match($0, /^\|[[:space:]]*[^|]+[[:space:]]*\|[[:space:]]*open[[:space:]]*\|/)
            print "| " id " | " status " |" substr($0, RSTART + RLENGTH)
            next
        }
        { print }
    ' "$file" > "$candidate"
    rm -f "$status_file"
    commit_candidate "$file" "$candidate"; echo "closed: $id"
}

cmd_close_bug() {
    [ $# -ge 1 ] || die "close-bug needs a task directory or findings file"
    local file path="$1" candidate status matches; shift; parse_close_options "$@"
    need --test "$test_ref"; status="$(closed_status 1 "$status_value" "$reason")"
    file="$(findings_path "$path")"; validate_existing "$file"
    matches="$(grep -Fc -- "- **Test** \`$test_ref\`, disabled" "$file" || true)"
    [ "$matches" -eq 1 ] || die "found $matches open or closed blocks for test $test_ref; nothing changed" 1
    # The parser guarantees Status, when present, is after Fix. Limit the match to a block and refuse a closed one.
    awk -v test="$test_ref" '
        /^\*\*`[^`]+` — / { if (found && closed) exit 3; found=0; closed=0 }
        $0 == "- **Test** `" test "`, disabled" { found=1 }
        found && /^- \*\*Status\*\*/ { closed=1 }
        END { if (found && closed) exit 3 }
    ' "$file" || die "the block for $test_ref is already closed" 1
    candidate="${file}.findings-tmp.$$"
    remember_temporary_file "$candidate"
    awk -v test="$test_ref" -v status="$status" '
        /^\*\*`[^`]+` — / { selected=0 }
        $0 == "- **Test** `" test "`, disabled" { selected=1 }
        { print }
        selected && /^- \*\*Fix\*\*/ { print "- **Status** " status; selected=0 }
    ' "$file" > "$candidate"
    commit_candidate "$file" "$candidate"; echo "closed bug: $test_ref"
}

cmd_close_critical() {
    [ $# -ge 1 ] || die "close-critical needs a task directory or findings file"
    local file path="$1" candidate status matches open heading; shift
    module=""; summary_text=""; status_value=""; reason=""
    while [ $# -gt 0 ]; do
        [ $# -ge 2 ] || die "$1 needs a value"
        case "$1" in
            --module) module="$2" ;; --summary) summary_text="$2" ;;
            --status) status_value="$2" ;; --reason) reason="$2" ;;
            *) die "unknown option: $1" ;;
        esac
        shift 2
    done
    need --module "$module"; need --summary "$summary_text"
    safe_code_span --module "$module"; safe_heading_text --summary "$summary_text"
    status="$(closed_status 1 "$status_value" "$reason")"
    file="$(findings_path "$path")"; validate_existing "$file"
    heading="**\`$module\` — $summary_text**"
    read -r matches open < <(awk -v target="$heading" '
        function finish() { if (selected && !closed) open++ }
        /^## / { finish(); selected=0; in_critical=($0 == "## Critical"); next }
        in_critical && /^\*\*`[^`]+` — / {
            finish(); selected=($0 == target); closed=0; if (selected) matches++; next
        }
        selected && /^- \*\*Status\*\*/ { closed=1 }
        END { finish(); print matches+0, open+0 }
    ' "$file")
    [ "$matches" -eq 1 ] || die "found $matches Critical blocks for '$module — $summary_text'; nothing changed" 1
    [ "$open" -eq 1 ] || die "the Critical block for '$module — $summary_text' is already closed" 1
    candidate="${file}.findings-tmp.$$"
    remember_temporary_file "$candidate"
    awk -v target="$heading" -v status="$status" '
        /^## / { selected=0; in_critical=($0 == "## Critical") }
        in_critical && /^\*\*`[^`]+` — / { selected=($0 == target) }
        { print }
        selected && /^- \*\*Fix\*\*/ { print "- **Status** " status; selected=0 }
    ' "$file" > "$candidate"
    commit_candidate "$file" "$candidate"
    echo "closed critical: $module — $summary_text"
}

[ $# -gt 0 ] || { usage; exit 2; }
command="$1"; shift
case "$command" in
    init) cmd_init "$@" ;;
    add-bug) cmd_add_bug "$@" ;;
    add-critical) cmd_add_critical "$@" ;;
    add-refactoring|add-deferred|add-performance)
        [ $# -ge 1 ] || die "$command needs a task directory or findings file"
        cmd_add_table "$command" "$@"
        ;;
    close) cmd_close "$@" ;;
    close-bug) cmd_close_bug "$@" ;;
    close-critical) cmd_close_critical "$@" ;;
    check)
        [ $# -eq 1 ] || die "check needs exactly one task directory or findings file"
        validate_file "$(findings_path "$1")"
        ;;
    -h|--help|help) usage ;;
    *) usage >&2; die "unknown command: $command" ;;
esac
