#!/usr/bin/awk -f
#
# Parses a plan's checklist into one record per item and answers the query named by -v mode=.
#
# An item is "- [ ] <ID> · <text>"; its block runs to the next item or heading, so a wrapped header
# and its scenario bullets stay attached. Only the header is searched for "after:", which keeps a
# scenario mentioning another item's ID from being read as a dependency.
#
# Two files, in order: the plan, then the plan log beside it. Items are read from the first only and
# review findings and run-log entries from the second only; a finding in the plan is reported, never
# read. `-v files=1` says the log is absent, which validate reports.
#
# Invoked by plan.sh, which ships beside it; see the README in the same directory.

function close_item() {
    cur = ""
    in_header = 0
}

function trim(s) {
    sub(/^[ \t]+/, "", s)
    sub(/[ \t]+$/, "", s)
    return s
}

# An unclosed fence hides every line under it in the file it opened in. validate reports it; every
# other command asks mode=fence first, or it would answer confidently for a file read by half.
function close_fence() {
    if (fenced) {
        n_stray++
        stray[n_stray] = fence_file ":" fence_line ": a fenced block opened here never closes"
        unclosed = 1
        # validate prints it with the other problems; every other command asks mode=fence first,
        # so it is the one place a second copy would not be a duplicate.
        if (mode == "fence") {
            print fence_file ":" fence_line ": a fenced block opened here never closes" > "/dev/stderr"
        }
    }
    fenced = 0
    fence_len = 0
}

# Every ID the text carries, comma-joined, in the order they appear.
function ids_in(text,   out, rest, tok) {
    out = ""
    rest = text
    while (match(rest, /[A-Za-z]+[0-9]+/)) {
        tok = substr(rest, RSTART, RLENGTH)
        out = (out == "" ? tok : out "," tok)
        rest = substr(rest, RSTART + RLENGTH)
    }
    return out
}

# The text after the first colon, trimmed. Used for "given:"/"Resolution:"-style labelled lines.
function value_after_colon(line,   pos, val) {
    pos = index(line, ":")
    if (pos == 0) {
        return ""
    }
    val = substr(line, pos + 1)
    sub(/^[ \t]+/, "", val)
    sub(/[ \t]+$/, "", val)
    return val
}

# A scenario the planner left unfilled. A step agent writes exactly what is listed, so a dash where the
# expected outcome belongs is not a shorter instruction - it is no instruction.
function is_placeholder(v) {
    return v == "" || v == "-" || v == "--" || v == "—" || v == "–" || v == "..." || v == "…" \
        || v == "TBD" || v == "tbd" || v == "TODO" || v == "todo" || v == "N/A" || v == "n/a"
}

# Every `someMethod(` named in a line, recorded against the item it sits under. Only called for
# "update:" bullets, which by definition name a test that already exists.
function scan_methods(line,   rest, tok, key) {
    rest = line
    while (match(rest, /`[A-Za-z_][A-Za-z0-9_]*\(/)) {
        tok = substr(rest, RSTART + 1, RLENGTH - 2)
        rest = substr(rest, RSTART + RLENGTH)
        key = cur "\t" tok
        if (key in upd_seen) {
            continue
        }
        upd_seen[key] = 1
        n_upd++
        upd_id[n_upd] = cur
        upd_m[n_upd] = tok
    }
}

# The dependency list of a header: everything from "after:" up to the next " · " field, or the end.
function deps_of(text,   tail, cut) {
    if (!match(text, /after:/)) {
        return ""
    }
    tail = substr(text, RSTART + RLENGTH)
    cut = index(tail, " · ")
    if (cut > 0) {
        tail = substr(tail, 1, cut - 1)
    }
    return ids_in(tail)
}

# The plan's fixed shape, from the plan-task skill's Plan Structure: its sections, the step map's groups,
# and each group's sections, each list in the order the plan must follow. Post-Implementation Steps has
# no fixed list: after Performance, its sections come from the conventions.
function shape_init() {
    n_top = split("Architecture Decisions|Step-by-Step Implementation Map (To-Do List)|Open Questions", top_name, "|")
    n_grp = split("Stabilization|Red Phase|Green Phase|Post-Implementation Steps", grp_name, "|")
    sec_list["Stabilization"] = "API Contract|Database|Interface-First / Build Stabilization|Closing item"
    sec_list["Red Phase"] = "TDD Unit Red Phase|TDD Integration Red Phase|TDD System Test Red Phase"
    sec_list["Green Phase"] = "TDD Unit Green Phase|TDD Integration Green Phase|TDD System Test Green Phase"
    home["RU"] = "TDD Unit Red Phase"; home["RI"] = "TDD Integration Red Phase"
    home["RS"] = "TDD System Test Red Phase"; home["GU"] = "TDD Unit Green Phase"
    home["GI"] = "TDD Integration Green Phase"; home["GS"] = "TDD System Test Green Phase"
}

# The position of name in a "|"-joined list, or 0.
function pos_in(list, name,    parts, k, np) {
    np = split(list, parts, "|")
    for (k = 1; k <= np; k++) {
        if (parts[k] == name) return k
    }
    return 0
}

function shape_problem(text) {
    n_shape++
    shape[n_shape] = text
}

# One heading of the plan, checked against the fixed shape as it is read.
function shape_heading(line,    name, p, list, k) {
    if (line ~ /^## /) {
        name = substr(line, 4)
        top_seen_any = 1
        in_map = (name == top_name[2])
        shape_group = ""
        p = 0
        for (k = 1; k <= n_top; k++) if (top_name[k] == name) p = k
        # A log section in the plan is reported as a stray already.
        if (name == "Review Findings" || name == "Run Log" || name ~ /Blockers/) {
            return
        }
        if (p == 0) {
            shape_problem("'## " name "' (line " FNR ") is not a plan section - the plan has " \
                top_name[1] ", " top_name[2] " and " top_name[3])
        } else if (p < last_top) {
            shape_problem("'## " name "' (line " FNR ") comes after '## " top_name[last_top] "' - keep the order " \
                top_name[1] ", " top_name[2] ", " top_name[3])
        } else {
            top_found[p] = 1
            last_top = p
        }
    } else if (line ~ /^### / && in_map) {
        name = substr(line, 5)
        p = 0
        for (k = 1; k <= n_grp; k++) if (grp_name[k] == name) p = k
        shape_group = name
        last_sec = 0
        if (p == 0) {
            shape_problem("'### " name "' (line " FNR ") is not a step-map group - use Stabilization, Red Phase, " \
                "Green Phase, Post-Implementation Steps")
            shape_group = ""
        } else if (p < last_grp) {
            shape_problem("'### " name "' (line " FNR ") comes after '### " grp_name[last_grp] "' - the groups run " \
                "Stabilization, Red Phase, Green Phase, Post-Implementation Steps")
        } else {
            last_grp = p
        }
    } else if (line ~ /^#### / && in_map && (shape_group in sec_list) && line != "#### Performance") {
        # A misplaced Performance section has its own report.
        name = substr(line, 6)
        list = sec_list[shape_group]
        p = pos_in(list, name)
        if (p == 0) {
            gsub(/\|/, ", ", list)
            shape_problem("'#### " name "' (line " FNR ") is not a section of " shape_group " - use " list)
        } else if (p < last_sec) {
            gsub(/\|/, ", ", list)
            shape_problem("'#### " name "' (line " FNR ") is out of order under " shape_group " - the order is " list)
        } else {
            last_sec = p
        }
    }
}

BEGIN {
    shape_init()
    if (mode == "") {
        mode = "items"
    }
    n = 0
    fileidx = 1
}

# The index is taken from ARGV rather than FNR == 1, which an empty file never reaches.
FILENAME != prevfile {
    close_item()
    close_fence()
    prevfile = FILENAME
    fileidx = 0
    for (i = 1; i < ARGC; i++) if (ARGV[i] == FILENAME) fileidx = i
    in_update = 0; in_findings = 0; in_runlog = 0; cur_f = ""; group = ""; section = ""
    base = FILENAME
    sub(/.*\//, "", base)
}

# A checkout with CRLF endings otherwise leaves a carriage return on the end of every line: a fence
# never closes, an empty label never reads as empty, and the file is parsed as half of itself. Git
# Bash's awk strips it already; the awks this has to run on elsewhere do not.
{ sub(/\r$/, "") }

# The header lines above the plan's first section.
fileidx == 1 && !top_seen_any && /^\*\*Affected Modules:\*\*[ ]*[^ ]/ { has_modules = 1 }
fileidx == 1 && !top_seen_any && /^\*\*Spec:\*\*[ ]*\[[^]]+\]\([^)]+\)/ { has_spec = 1 }

# A plan quotes its own step format in fenced examples; those bullets are illustrations, not work.
#
# The marker's length decides what closes it, as in Markdown itself. A document quoting this format
# nests one example inside another, and pasted output routinely carries a fence of its own - both are
# unreadable to a parser that closes on the first three backticks it sees.
/^[ \t]*```/ || /^[ \t]*~~~/ {
    fence = $0
    indented = ($0 ~ /^[ \t]/)
    sub(/^[ \t]+/, "", fence)
    char = substr(fence, 1, 1)
    # A regex literal in an expression is a match against $0, so each one has to sit in match()'s own
    # argument position rather than be chosen between beforehand.
    if (char == "`") {
        match(fence, /^`+/)
    } else {
        match(fence, /^~+/)
    }
    if (fenced) {
        # Closed only by the same character, at exactly the opening length, carrying no info string.
        # A longer run is content: a row of tildes underlining a line is how compilers point at a
        # column, and it appears in pasted output constantly.
        if (char == fence_char && RLENGTH == fence_len && trim(substr(fence, RLENGTH + 1)) == "") {
            fenced = 0
            fence_len = 0
        }
    } else {
        fenced = 1
        fence_len = RLENGTH
        fence_char = char
        fence_line = FNR
        fence_file = FILENAME
        fence_in_item = (cur != "" && indented)
    }
    # A block belongs to the item above it only where it is indented under it. An unindented one is
    # the document's, and "show" would otherwise hand a step agent somebody else's example.
    if (fence_in_item) {
        end[cur] = NR
    }
    next
}
fenced {
    if (fence_in_item) {
        end[cur] = NR
    }
    next
}

/^#+ / {
    close_item()
    in_update = 0
    cur_f = ""
    in_findings = ($0 ~ /^## Review Findings$/)
    in_runlog = ($0 ~ /^## Run Log$/)
    if (fileidx == 1 && in_findings) {
        n_stray++
        stray[n_stray] = FILENAME ":" FNR ": '## Review Findings' sits in the " base " - the log beside it owns the findings"
    }
    if (fileidx == 1 && in_runlog) {
        n_stray++
        stray[n_stray] = FILENAME ":" FNR ": '## Run Log' sits in the " base " - the log beside it owns the run log"
    }
    if (fileidx == 1 && $0 ~ /^##+ .*Blockers/) {
        n_stray++
        stray[n_stray] = FILENAME ":" FNR ": a Blockers heading sits in the " base " - the section is '## Open Questions'; blockers go to the log beside it"
    }
    if (fileidx == 1) {
        shape_heading($0)
    }
    if ($0 ~ /^### /) {
        group = substr($0, 5)
        section = ""
        # Position in the plan, which is the order the groups run in. Headings outside the step map
        # are numbered too and never compared, because no checklist item sits under them.
        if (!(group in group_pos)) {
            group_pos[group] = ++n_groups
        }
    } else if ($0 ~ /^#### /) {
        section = substr($0, 6)
        # The Performance section measures a finished feature, so it is the first section of the
        # last group; validate reports one that is anywhere else.
        n_sections_in[group]++
        if (section == "Performance" && (group != "Post-Implementation Steps" || n_sections_in[group] != 1)) {
            n_perf_bad++
            perf_bad[n_perf_bad] = "the Performance section (line " FNR ") sits under '" group "' as section " \
                n_sections_in[group] " - it is the first section of Post-Implementation Steps"
        }
    }
    next
}

# A review finding: "- **RF01:** …", followed by its Resolution and Action lines.
fileidx == 1 && /^- \*\*RF[0-9]+:\*\*/ {
    # Under a findings heading the heading was already reported; a finding elsewhere is its own report.
    if (!in_findings) {
        n_stray++
        stray[n_stray] = FILENAME ":" FNR ": " substr($0, 5, index($0, ":") - 5) " sits in the " base " - the log beside it owns the findings"
    }
    next
}

# A run-log entry in the plan is the old shape, whatever heading it sits under.
fileidx == 1 && /^- \*\*RL[0-9]+/ {
    match($0, /RL[0-9]+/)
    n_stray++
    stray[n_stray] = FILENAME ":" FNR ": " substr($0, RSTART, RLENGTH) " sits in the " base " - the log beside it owns the run log"
    next
}

in_findings && /^- \*\*RF[0-9]+:\*\*/ {
    match($0, /RF[0-9]+/)
    cur_f = substr($0, RSTART, RLENGTH)
    n_f++
    f_order[n_f] = cur_f
    f_line[cur_f] = FNR
    next
}

# A run-log entry: "- **RL03 (GU07):** …", numbered once and ascending, so a new one is appended
# and never inserted above an older one. One outside the Run Log is reported, and still counted,
# so the next number never repeats it.
fileidx != 1 && /^- \*\*RL[0-9]+/ {
    match($0, /RL[0-9]+/)
    b = substr($0, RSTART + 2, RLENGTH - 2) + 0
    n_b++
    if (!in_runlog) {
        n_stray++
        stray[n_stray] = FILENAME ":" FNR ": RL" sprintf("%02d", b) " sits outside '## Run Log'"
    } else if (b <= last_b) {
        n_stray++
        stray[n_stray] = FILENAME ":" FNR ": RL" sprintf("%02d", b) " is not above the entry before it - append, never insert"
    }
    if (b > last_b) last_b = b
    # The item it names is checked at END, once the plan's items are all known.
    if (match($0, /\(([A-Za-z]+[0-9]+)\)/)) {
        n_bref++
        bref_id[n_bref] = substr($0, RSTART + 1, RLENGTH - 2)
        bref_where[n_bref] = FILENAME ":" FNR ": RL" sprintf("%02d", b)
    } else {
        n_stray++
        stray[n_stray] = FILENAME ":" FNR ": RL" sprintf("%02d", b) " names no item - write it as **B" b " (<item ID>):**"
    }
    next
}

# Items live in the plan alone; a checkbox in the log is a record, not work.
fileidx != 1 && /^- \[[ xX]\] / { next }

in_findings && cur_f != "" && /^[ \t]*- Resolution:/ {
    f_res[cur_f] = value_after_colon($0)
    next
}

in_findings && cur_f != "" && /^[ \t]*- Action:/ {
    f_act[cur_f] = value_after_colon($0)
    next
}

in_findings && cur_f != "" && /^[ \t]*- Escalated:/ {
    f_esc[cur_f] = value_after_colon($0)
    next
}

/^- \[[ xX]\] / {
    close_item()
    in_update = 0
    rest = substr($0, 7)
    if (!match(rest, /^[A-Za-z]+[0-9]+/)) {
        n_unidentified++
        unidentified[n_unidentified] = NR ": " substr($0, 1, 70)
        next
    }
    cur = substr(rest, 1, RLENGTH)
    title = substr(rest, RLENGTH + 1)
    sub(/^[ ]*·[ ]*/, "", title)

    if (cur in seen) {
        n_dup++
        dup[n_dup] = cur " (lines " start[cur] " and " NR ")"
    }
    seen[cur] = 1
    n++
    order[n] = cur
    status[cur] = (substr($0, 4, 1) == " " ? "open" : "done")
    group_of[cur] = group
    section_of[cur] = section
    start[cur] = NR
    end[cur] = NR
    header[cur] = title
    in_header = 1
    next
}

# A wrapped header line: indented, not a sub-bullet, not blank.
in_header && /^[ \t]+[^ \t-]/ {
    line = $0
    sub(/^[ \t]+/, "", line)
    header[cur] = header[cur] " " line
    end[cur] = NR
    next
}

# A scenario line inside an item, as a bullet ("- given: …") or a continuation ("  when: …").
cur != "" && /^[ \t]*-?[ \t]*(given|when|then):/ {
    in_header = 0
    in_update = 0
    end[cur] = NR
    scenario_line = $0
    sub(/^[ \t]*-?[ \t]*/, "", scenario_line)
    scenario_label = substr(scenario_line, 1, index(scenario_line, ":") - 1)
    if (is_placeholder(value_after_colon(scenario_line))) {
        n_placeholder++
        placeholder[n_placeholder] = cur " leaves \"" scenario_label ":\" empty at line " NR
    }
    next
}

# A performance step's threshold, copied from the spec. Recorded so validate can ask for it.
cur != "" && /^[ \t]*-?[ \t]*threshold:/ {
    in_header = 0
    in_update = 0
    end[cur] = NR
    has_threshold[cur] = 1
    if (is_placeholder(value_after_colon($0))) {
        n_placeholder++
        placeholder[n_placeholder] = cur " leaves \"threshold:\" empty at line " NR
    }
    next
}

# An "update:" bullet names tests that already exist; it may wrap over several lines.
cur != "" && /^[ \t]*-[ \t]*update:/ {
    in_header = 0
    in_update = 1
    end[cur] = NR
    scan_methods($0)
    next
}

in_update && /^[ \t]+[^ \t-]/ {
    end[cur] = NR
    scan_methods($0)
    next
}

# The item's last line is the last non-blank line it consumed, never the line before the next
# item: a file without a trailing newline still ends its last item where it ends.
{
    in_update = 0
    in_header = 0
    if (cur != "" && NF) {
        end[cur] = NR
    }
}

END {
    close_item()
    close_fence()
    if (mode == "fence") {
        exit (unclosed ? 1 : 0)
    }
    for (i = 1; i <= n; i++) {
        id = order[i]
        if (end[id] == "" || end[id] < start[id]) {
            end[id] = start[id]
        }
        deps[id] = deps_of(header[id])
    }

    if (mode == "items") {
        emit_items()
    } else if (mode == "range") {
        emit_range()
    } else if (mode == "status") {
        emit_status()
    } else if (mode == "next") {
        emit_next()
    } else if (mode == "validate") {
        emit_validate()
    } else if (mode == "updates") {
        emit_updates()
    } else if (mode == "count") {
        print n "\t" n_b + 0
    } else if (mode == "nextblock") {
        print last_b + 1
    } else {
        print "unknown mode: " mode > "/dev/stderr"
        exit 2
    }
}

function emit_items(   i, id) {
    for (i = 1; i <= n; i++) {
        id = order[i]
        print id "\t" status[id] "\t" group_of[id] "\t" section_of[id] "\t" \
              start[id] "\t" end[id] "\t" deps[id] "\t" header[id]
    }
}

function emit_range(   ) {
    if (!(want in seen)) {
        exit 1
    }
    print start[want] " " end[want]
}

function emit_status(   i, id, g, total, done, groups, ng, open_ids) {
    ng = 0
    for (i = 1; i <= n; i++) {
        id = order[i]
        g = (group_of[id] == "" ? "(ungrouped)" : group_of[id])
        if (!(g in g_total)) {
            ng++
            g_order[ng] = g
            g_total[g] = 0
            g_done[g] = 0
            g_open[g] = ""
        }
        g_total[g]++
        total++
        if (status[id] == "done") {
            g_done[g]++
            done++
        } else {
            g_open[g] = (g_open[g] == "" ? id : g_open[g] ", " id)
        }
    }
    for (i = 1; i <= ng; i++) {
        g = g_order[i]
        if (g_open[g] == "") {
            printf "%-28s %3d/%d\n", g, g_done[g], g_total[g]
        } else {
            printf "%-28s %3d/%-4d open: %s\n", g, g_done[g], g_total[g], g_open[g]
        }
    }
    printf "%-28s %3d/%d\n", "TOTAL", done, total
}

# Longest chain of still-open work starting at id, counting id itself.
function rank(id,   i, c, best, r) {
    if (id in rank_memo) {
        return rank_memo[id]
    }
    rank_memo[id] = 1
    best = 0
    for (i = 1; i <= n; i++) {
        c = order[i]
        if (status[c] == "done") {
            continue
        }
        if (("," deps[c] ",") ~ ("," id ",")) {
            r = rank(c)
            if (r > best) {
                best = r
            }
        }
    }
    rank_memo[id] = best + 1
    return rank_memo[id]
}

# Case-insensitive substring, so --group red reaches "Red Phase" without quoting the whole heading.
function has(haystack, needle) {
    return index(tolower(haystack), tolower(needle)) > 0
}

# Whether an item falls inside the scope the caller asked for. A run limited to one phase must not be
# handed the next phase's work when its own finishes, and the caller is the only one who knows.
function in_scope(id,   i, nsec, sec) {
    if (group_filter != "" && !has(group_of[id], group_filter)) {
        return 0
    }
    if (section_filter != "") {
        nsec = split(section_filter, sec, ",")
        for (i = 1; i <= nsec; i++) {
            if (sec[i] != "" && has(section_of[id], sec[i])) {
                return 1
            }
        }
        return 0
    }
    return 1
}

function check_scope(   i, id, g, seen_g, names, count) {
    count = 0
    names = ""
    for (i = 1; i <= n; i++) {
        g = group_of[order[i]]
        if (group_filter != "" && has(g, group_filter) && !(g in seen_g)) {
            seen_g[g] = 1
            count++
            names = (names == "" ? g : names ", " g)
        }
    }
    if (group_filter != "" && count == 0) {
        print "no group matching '" group_filter "' in this plan" > "/dev/stderr"
        exit 2
    }
    if (count > 1) {
        print "'" group_filter "' matches " count " groups - narrow it: " names > "/dev/stderr"
        exit 2
    }
    count = 0
    for (i = 1; i <= n; i++) {
        if (in_scope(order[i])) {
            count++
        }
    }
    if (count == 0) {
        print "no item is in scope" > "/dev/stderr"
        exit 2
    }
}

function emit_next(   i, id, j, d, nd, ready, blocked_by, k, tmp, stage) {
    check_scope()
    # Groups run in the order the plan lists them, so only the earliest one still holding open work
    # is schedulable - an item in a later group is not eligible just because it has no dependencies.
    stage = ""
    for (i = 1; i <= n; i++) {
        if (status[order[i]] != "done" && in_scope(order[i])) {
            stage = group_of[order[i]]
            break
        }
    }
    if (stage == "") {
        print "every item in scope is ticked"
        return
    }
    print "group: " stage

    for (i = 1; i <= n; i++) {
        id = order[i]
        if (status[id] == "done" || group_of[id] != stage || !in_scope(id)) {
            continue
        }
        nd = split(deps[id], d, ",")
        ready = 1
        blocked_by = ""
        for (j = 1; j <= nd; j++) {
            if (d[j] == "") {
                continue
            }
            if (!(d[j] in seen) || status[d[j]] != "done") {
                ready = 0
                blocked_by = (blocked_by == "" ? d[j] : blocked_by ", " d[j])
            }
        }
        if (ready) {
            k++
            elig[k] = id
        } else {
            waiting[id] = blocked_by
        }
    }
    if (k == 0) {
        print "nothing eligible - every open item in this group waits on another"
    }
    # Longest remaining chain first: with a parallelism cap, spawning a shorter branch
    # ahead of the critical path costs a whole wave.
    for (i = 1; i <= k; i++) {
        for (j = i + 1; j <= k; j++) {
            if (rank(elig[j]) > rank(elig[i])) {
                tmp = elig[i]
                elig[i] = elig[j]
                elig[j] = tmp
            }
        }
    }
    for (i = 1; i <= k; i++) {
        printf "%-6s depth %-3d %s\n", elig[i], rank(elig[i]), header[elig[i]]
    }
    if (verbose == "1") {
        for (i = 1; i <= n; i++) {
            id = order[i]
            if (id in waiting && in_scope(id)) {
                printf "  (waiting) %-6s after %s\n", id, waiting[id]
            }
        }
    }
}

# The loop as it reads in the plan: "GU01 after GU03 after GU02 after GU01".
function render_cycle(back_to,   i, from, out) {
    from = 0
    for (i = 1; i <= depth_i; i++) {
        if (path[i] == back_to) {
            from = i
            break
        }
    }
    if (from == 0) {
        return back_to
    }
    out = path[from]
    for (i = from + 1; i <= depth_i; i++) {
        out = out " after " path[i]
    }
    return out " after " back_to
}

# Depth-first cycle search; colour 1 is on the current path, 2 is finished.
function visit(id,   i, c, nd, d, j) {
    colour[id] = 1
    path[++depth_i] = id
    nd = split(deps[id], d, ",")
    for (j = 1; j <= nd; j++) {
        c = d[j]
        if (c == "" || !(c in seen)) {
            continue
        }
        if (colour[c] == 1) {
            cycle_found = cycle_found "\n  " render_cycle(c)
        } else if (colour[c] != 2) {
            visit(c)
        }
    }
    colour[id] = 2
    depth_i--
}

function emit_updates(   i) {
    for (i = 1; i <= n_upd; i++) {
        # A ticked item's update: bullets describe work that already happened, and the rename or
        # deletion they asked for is why the method is gone. Only an open item's can be checked
        # against the tree.
        if (status[upd_id[i]] == "done") {
            continue
        }
        print upd_id[i] "\t" upd_m[i]
    }
}

# A field of a step line, from its "name:" up to the next field, trimmed.
function field_of(h, name,    seg) {
    seg = substr(h, index(h, name) + length(name))
    if (index(seg, "·")) {
        seg = substr(seg, 1, index(seg, "·") - 1)
    }
    gsub(/^[ ]+|[ ]+$/, "", seg)
    return seg
}

# Backticked entries separated by commas: what a step line names as code.
function is_code_list(seg) {
    return seg ~ /^`[^`]+`([ ]*,[ ]*`[^`]+`)*$/
}

# The first backticked token of a step line after its ID: the target class, or a system step's test class.
function first_code(h) {
    return match(h, /`[^`]+`/) ? substr(h, RSTART + 1, RLENGTH - 2) : ""
}

function test_of(h) {
    return match(h, /test:[ ]*`[^`]+`/) ? substr(h, RSTART, RLENGTH) : ""
}

# The plan's shape: its sections and header lines, where each step sits, the red and green steps pairing one
# to one, and a green step waiting only on green steps. Returns how many problems it printed.
function emit_shape(   i, k, id, pre, count, nd, d, j, r_key, g_key, key_of) {
    count = 0
    for (i = 1; i <= n_shape; i++) {
        print shape[i]
        count++
    }
    for (k = 1; k <= n_top; k++) {
        if (!(k in top_found)) {
            print "no '## " top_name[k] "' section - the plan has " top_name[1] ", " top_name[2] " and " top_name[3]
            count++
        }
    }
    if (!has_modules) {
        print "no **Affected Modules:** line above the first section"
        count++
    }
    if (!has_spec) {
        print "no **Spec:** line linking the task's spec above the first section - write '**Spec:** [<task>](spec.md)'"
        count++
    }
    for (i = 1; i <= n; i++) {
        id = order[i]
        pre = substr(id, 1, 2)
        if ((pre in home) && section_of[id] != home[pre]) {
            print id " sits under '" group_of[id] " / " section_of[id] "' - it belongs under " home[pre]
            count++
        } else if (pre == "ST" && group_of[id] != "Stabilization") {
            print id " sits under '" group_of[id] "' - it belongs under Stabilization"
            count++
        } else if (pre == "PI" && group_of[id] != "Post-Implementation Steps") {
            print id " sits under '" group_of[id] "' - it belongs under Post-Implementation Steps"
            count++
        }
        if (pre ~ /^[RG][UIS]$/) {
            key_of[id] = substr(pre, 2, 1) "|" first_code(header[id]) "|" (pre ~ /S$/ ? "" : test_of(header[id]))
            if (substr(pre, 1, 1) == "R") r_key[key_of[id]] = id
            else g_key[key_of[id]] = id
        }
        if (pre ~ /^G[UIS]$/) {
            nd = split(deps[id], d, ",")
            for (j = 1; j <= nd; j++) {
                if (d[j] != "" && d[j] !~ /^G[UIS][0-9]+$/) {
                    print id "'s after: names " d[j] " - a green step waits only on green steps"
                    count++
                }
            }
        }
    }
    for (i = 1; i <= n; i++) {
        id = order[i]
        if (!(id in key_of)) {
            continue
        }
        if (substr(id, 1, 1) == "R" && !(key_of[id] in g_key)) {
            print id " has no green step with the same target and test class"
            count++
        } else if (substr(id, 1, 1) == "G" && !(key_of[id] in r_key)) {
            print id " has no red step with the same target and test class"
            count++
        }
    }
    return count
}

function emit_validate(   i, id, j, d, nd, m, problems) {
    problems = 0
    for (i = 1; i <= n_dup; i++) {
        print "duplicate ID: " dup[i]
        problems++
    }
    for (i = 1; i <= n_unidentified; i++) {
        print "checklist item without an ID at line " unidentified[i]
        problems++
    }
    for (i = 1; i <= n_placeholder; i++) {
        print placeholder[i]
        problems++
    }
    for (i = 1; i <= n_stray; i++) {
        print stray[i]
        problems++
    }
    for (i = 1; i <= n_bref; i++) {
        if (!(bref_id[i] in seen)) {
            print bref_where[i] " names " bref_id[i] ", which no item defines"
            problems++
        }
    }
    # A missing log is reported by plan.sh, which knows the path it looked for; here it only counts.
    if (files == "1") {
        problems++
    }
    for (i = 1; i <= n_f; i++) {
        id = f_order[i]
        if (f_res[id] == "") {
            print id " (line " f_line[id] ") has no 'Resolution:' line - mechanical or decision"
            problems++
        } else if (f_res[id] != "mechanical" && f_res[id] != "decision") {
            print id " has Resolution: '" f_res[id] "' - must be mechanical or decision"
            problems++
        } else if (f_res[id] == "mechanical" && f_act[id] == "" && f_esc[id] == "") {
            print id " is mechanical but its 'Action:' is empty - apply it and record what changed"
            problems++
        }
    }
    for (i = 1; i <= n; i++) {
        id = order[i]
        nd = split(deps[id], d, ",")
        for (j = 1; j <= nd; j++) {
            if (d[j] == "") {
                continue
            }
            if (!(d[j] in seen)) {
                print id " depends on " d[j] ", which no item defines"
                problems++
            # A group runs to completion before the next one starts, so an edge into a later group
            # can never resolve: the item waits for work its own stage has already ruled out.
            } else if (group_of[id] in group_pos && group_of[d[j]] in group_pos \
                    && group_pos[group_of[id]] < group_pos[group_of[d[j]]]) {
                print id " (" group_of[id] ") depends on " d[j] " (" group_of[d[j]] "), which runs later"
                problems++
            }
        }
    }
    for (i = 1; i <= n; i++) {
        if (colour[order[i]] != 2) {
            visit(order[i])
        }
    }
    if (cycle_found != "") {
        print "circular dependencies:" cycle_found
        problems++
    }
    # A red step names what it tests as code: each covers: entry a backticked method signature or entry
    # point, each mocks: entry a backticked name. Prose there hands the step agent a description instead of
    # a target. PM items are checked below.
    for (i = 1; i <= n; i++) {
        id = order[i]
        if (substr(id, 1, 2) == "PM") {
            continue
        }
        if (header[id] !~ /covers:/) {
            if (id ~ /^R[UIS][0-9]+$/) {
                print id " has no 'covers:' - name the method signatures or the entry point it tests"
                problems++
            }
        } else if (!is_code_list(field_of(header[id], "covers:"))) {
            print id "'s covers: is not a list of backticked entries - write 'covers: `method()`, `other()`' or the entry point in backticks"
            problems++
        }
        if (header[id] ~ /mocks:/) {
            m = field_of(header[id], "mocks:")
            if (m != "none" && m != "`none`" && !is_code_list(m)) {
                print id "'s mocks: is not 'none' or a list of backticked names - write 'mocks: `Collaborator`'"
                problems++
            }
        }
    }
    problems += emit_shape()
    # A performance step: PM items only under Post-Implementation Steps / Performance, which comes
    # first in its group; each with a threshold and the spec scenarios it measures.
    for (i = 1; i <= n_perf_bad; i++) {
        print perf_bad[i]
        problems++
    }
    for (i = 1; i <= n; i++) {
        id = order[i]
        if (substr(id, 1, 2) == "PM") {
            if (section_of[id] != "Performance") {
                print id " sits under '" group_of[id] " / " section_of[id] \
                      "' - a performance step belongs under Performance"
                problems++
            }
            if (header[id] !~ /covers:[ ]*`[^`]+`/) {
                print id " names no entry point - write 'covers: `<entry point>`' on the step line"
                problems++
            }
            # A rerun takes its threshold from the test in the tree and lists no scenario.
            if (header[id] ~ /·[ ]*rerun([ ]|$)/) {
                if (id in has_threshold) {
                    print id " is a rerun and carries a 'threshold:' line - the test in the tree owns the threshold"
                    problems++
                }
            } else {
                if (!(id in has_threshold)) {
                    print id " has no 'threshold:' line - copy the figure, its unit and the load from the spec"
                    problems++
                }
                if (header[id] !~ /scenarios:[ ]*AC[0-9]+/) {
                    print id " names no spec scenario - write 'scenarios: AC<nn>' on the step line"
                    problems++
                }
            }
        } else if (section_of[id] == "Performance") {
            print id " sits under Performance - only PM items belong there"
            problems++
        }
    }
    if (problems == 0) {
        # plan.sh has its own checks to add and owns the verdict when it passes summary=0.
        if (summary != "0") {
            print n " items, no problems"
        }
    } else {
        exit 1
    }
}
