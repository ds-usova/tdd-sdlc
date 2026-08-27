#!/usr/bin/awk -f
#
# Parses an upgrade's checklist and its log into one record per entry, and answers the query named
# by -v mode=.
#
# A step is "- [ ] <ID> · <kind> · <text>"; its block runs to the next step or heading, so the
# labelled lines under it stay attached. The kind decides which of those lines the step owes and
# which it may not carry, which is what validate checks.
#
# Two files, in order: the steps file, then the log beside it. Steps are read from the first only,
# attempts and run-log entries from the second only; an attempt or a run-log entry in the steps file
# is reported, never read. `-v files=1` says the log is absent, which validate reports.
#
# An attempt is "- **A1** · <step ID> · <text>" under the log's "## Attempts"; the shape is
# templates/attempts.md. A run-log entry is "- **B1 (<step ID>):** <note>" under the log's
# "## Run Log", numbered once and ascending. One whose note starts "kept back" owes a "Kept because:"
# and a "Would unblock:" line.
#
# Invoked by upgrade.sh, which ships beside it; see the README in the same directory.

function trim(s) {
    sub(/^[ \t]+/, "", s)
    sub(/[ \t]+$/, "", s)
    return s
}

# A value the author left unfilled. An agent does exactly what the line says, so a dash where the
# change belongs is not a shorter instruction - it is no instruction.
function is_placeholder(v) {
    return v == "" || v == "-" || v == "--" || v == "\xe2\x80\x94" || v == "\xe2\x80\x93" \
        || v == "..." || v == "\xe2\x80\xa6" || v == "TBD" || v == "tbd" || v == "TODO" \
        || v == "todo" || v == "N/A" || v == "n/a" || v ~ /^</
}

function problem(text) {
    problems[++problem_count] = text
}

# "files:" and "test-files:" put each path on a bullet of its own, so their label line carries no value.
# The label is only filled once a bullet follows it; one that never gets a bullet lists nothing at all.
function flush_awaiting(   aw) {
    if (awaiting != "") {
        split(awaiting, aw, "\t")
        problem(awaiting_file ":" awaiting_line ": " aw[1] "'s \"" aw[2] ":\" lists nothing")
    }
    awaiting = ""
}

function close_step() {
    flush_awaiting()
    cur = ""
}

# An unclosed fence hides every line under it in the file it opened in. Reported in every mode, not
# only validate: status, show and tick would otherwise answer confidently for a file read by half.
function close_fence() {
    if (fenced) {
        problem(fence_file ":" fence_line ": a fenced block opened here never closes")
        unclosed = 1
        if (mode != "validate") {
            print fence_file ":" fence_line ": a fenced block opened here never closes;" \
                  " everything below it was not read" > "/dev/stderr"
        }
    }
    fenced = 0
    fence_len = 0
    awaiting_evidence = ""
}

# The file's own name, as the messages name it.
function basename(path,   n, parts) {
    n = split(path, parts, "/")
    return parts[n]
}

# Everything that belongs to one file and must not leak into the next.
function reset_file() {
    fenced = 0
    fence_len = 0
    fence_char = ""
    fence_in_step = 0
    in_questions = 0
    in_attempts = 0
    in_runlog = 0
    open_question = ""
    awaiting = ""
    awaiting_evidence = ""
    cur = ""
    cur_attempt = ""
    cur_b = ""
}

BEGIN {
    SEP = "\xc2\xb7"            # the middot the step and attempt headers separate on
    step_count = 0
    attempt_count = 0
    b_count = 0
    last_b = 0
    problem_count = 0
    unclosed = 0
    fileidx = 1
    prevfile = ""
    spec_name = ""
    spec_base = ""
    reset_file()

    lists_below["files"]      = 1
    lists_below["test-files"] = 1

    # Every labelled line a step may carry, and the kinds that take it. "*" means any kind.
    takes["files"]      = "*"
    takes["test-files"] = "migrate"
    takes["guide"]      = "*"
    takes["change"]     = "migrate"
    takes["needs"]      = "*"
    takes["docs"]       = "*"

    # What each kind cannot be written without.
    requires["bump"]    = "files guide"
    requires["migrate"] = "files guide change"

    kinds = " bump migrate "

    attempt_labels   = " why result evidence ruled-out "
    attempt_requires = "why result evidence ruled-out"

    b_labels         = " Kept because Would unblock Resolved "
    kept_requires    = "Kept because|Would unblock"
}

# A checkout with CRLF endings otherwise leaves a carriage return on every line.
{ sub(/\r$/, "") }

# The index is taken from ARGV rather than FNR == 1, which an empty file never reaches.
FILENAME != prevfile {
    close_step()
    close_fence()
    if (open_question != "") {
        problem(prevfile ":" question_line ": " open_question " has no answer")
    }
    prevfile = FILENAME
    fileidx = 0
    for (i = 1; i < ARGC; i++) if (ARGV[i] == FILENAME) fileidx = i
    if (fileidx == 1) {
        spec_name = FILENAME
        spec_base = basename(FILENAME)
    }
    reset_file()
}

# A fenced block holds the format's own example, or an attempt's evidence. The marker's length
# decides what closes it, as in Markdown itself: pasted output routinely carries a fence of its own.
/^[ \t]*```/ || /^[ \t]*~~~/ {
    fence = $0
    indented = ($0 ~ /^[ \t]/)
    sub(/^[ \t]+/, "", fence)
    char = substr(fence, 1, 1)
    if (char == "`") {
        match(fence, /^`+/)
    } else {
        match(fence, /^~+/)
    }
    if (fenced) {
        if (char == fence_char && RLENGTH == fence_len && trim(substr(fence, RLENGTH + 1)) == "") {
            fenced = 0
            fence_len = 0
            awaiting_evidence = ""
        }
    } else {
        fenced = 1
        fence_len = RLENGTH
        fence_char = char
        fence_file = FILENAME
        fence_line = FNR
        fence_in_step = (cur != "" && indented)
    }
    if (fence_in_step) {
        end_line[cur] = FNR
    }
    next
}
fenced {
    if (awaiting_evidence != "" && trim($0) != "") {
        evidence_seen[awaiting_evidence] = 1
    }
    if (fence_in_step) {
        end_line[cur] = FNR
    }
    next
}

# "evidence:" is answered by the block that follows it, not by the next block anywhere in the file.
awaiting_evidence != "" && /[^ \t]/ { awaiting_evidence = "" }

/^#/ {
    close_step()
    cur_attempt = ""
    cur_b = ""
    in_questions = ($0 ~ /^#+[ \t]+[Oo]pen [Qq]uestions?/)
    in_attempts  = ($0 ~ /^#+[ \t]+[Aa]ttempts?/)
    in_runlog    = ($0 ~ /^## Run Log/)
    if (fileidx == 1 && in_attempts) {
        problem(FILENAME ":" FNR ": '## Attempts' sits in the " spec_base " - the log beside it owns the attempts")
    }
    if (fileidx == 1 && in_runlog) {
        problem(FILENAME ":" FNR ": '## Run Log' sits in the " spec_base " - the log beside it owns the run log")
    }
    if (fileidx == 1 && $0 ~ /^#+[ \t]+[Kk]ept [Bb]ack/) {
        problem(FILENAME ":" FNR ": '## Kept back' sits in the " spec_base " - the log beside it owns the run log")
    }
    next
}

# - [ ] U01 · bump · `group:artifact` 1.0 -> 1.1
#
# At the left margin only. A checkbox indented under a step is part of that step's own text.
# In the log a checkbox is a record, not work.
fileidx != 1 && /^-[ \t]+\[[ xX]\][ \t]+/ { next }

/^-[ \t]+\[[ xX]\][ \t]+/ {
    close_step()
    cur_attempt = ""
    cur_b = ""

    line = $0
    ticked = (line ~ /\[[xX]\]/)
    sub(/^-[ \t]+\[[ xX]\][ \t]+/, "", line)

    id = ""
    if (match(line, /^[A-Za-z]+[0-9]+/)) {
        id = substr(line, RSTART, RLENGTH)
    }
    if (id == "") {
        problem(FILENAME ":" FNR ": a step with no ID")
        next
    }
    if (id in start_line) {
        problem(FILENAME ":" FNR ": duplicate ID " id " (first at line " start_line[id] ")")
        next
    }

    kind = ""
    p1 = index(line, SEP)
    if (p1 > 0) {
        rest = substr(line, p1 + length(SEP))
        p2 = index(rest, SEP)
        kind = trim(p2 > 0 ? substr(rest, 1, p2 - 1) : rest)
    }
    if (kind == "" || index(kinds, " " kind " ") == 0) {
        problem(FILENAME ":" FNR ": " id " has no recognized kind (got \"" kind "\")")
    }

    # A step given up on keeps its row; "abandoned — <why>" in the header is how it says so.
    abandoned = (index(line, "abandoned \342\200\224") > 0)

    order[++step_count] = id
    start_line[id] = FNR
    end_line[id] = FNR
    step_kind[id] = kind
    step_done[id] = ticked
    step_abandoned[id] = abandoned
    cur = id
    next
}

# - **A1** · U03 · what was tried
/^[ \t]*-[ \t]+\*\*A[0-9]+\*\*/ {
    flush_awaiting()
    cur = ""
    cur_b = ""
    line = $0
    match(line, /A[0-9]+/)
    aid = substr(line, RSTART, RLENGTH)

    if (fileidx == 1) {
        problem(FILENAME ":" FNR ": " aid " sits in the " spec_base " - the log beside it owns the attempts")
        cur_attempt = ""
        next
    }
    if (!in_attempts) {
        problem(FILENAME ":" FNR ": " aid " is written outside an \"Attempts\" section, where nothing reads it")
        cur_attempt = ""
        next
    }
    if (aid in attempt_line) {
        problem(FILENAME ":" FNR ": duplicate attempt " aid " (first at line " attempt_line[aid] ")")
        cur_attempt = ""
        next
    }

    phase = ""
    p1 = index(line, SEP)
    if (p1 > 0) {
        rest = substr(line, p1 + length(SEP))
        p2 = index(rest, SEP)
        phase = trim(p2 > 0 ? substr(rest, 1, p2 - 1) : rest)
    }
    if (phase == "") {
        problem(FILENAME ":" FNR ": " aid " names no phase - put the step ID after the " SEP)
    } else {
        attempt_phase_line[aid] = FNR
        attempt_phase[aid] = phase
    }

    attempt_order[++attempt_count] = aid
    attempt_line[aid] = FNR
    cur_attempt = aid
    next
}

# - **B3 (U03):** what happened
#
# Numbered once and ascending, so a new one is appended and never inserted above an older one. One
# outside the Run Log is reported, and still counted, so the next number never repeats it.
/^-[ \t]+\*\*B[0-9]+/ {
    flush_awaiting()
    cur = ""
    cur_attempt = ""
    cur_b = ""
    line = $0
    match(line, /B[0-9]+/)
    bid = substr(line, RSTART, RLENGTH)
    b = substr(bid, 2) + 0

    if (fileidx == 1) {
        problem(FILENAME ":" FNR ": " bid " sits in the " spec_base " - the log beside it owns the run log")
        next
    }
    if (!in_runlog) {
        problem(FILENAME ":" FNR ": " bid " sits outside '## Run Log'")
    } else if (b <= last_b) {
        # A duplicate is the same fault: it is not above the entry before it.
        problem(FILENAME ":" FNR ": " bid " is not above the entry before it - append, never insert")
    }
    if (b > last_b) last_b = b
    if (bid in b_line) {
        next
    }

    b_order[++b_count] = bid
    b_line[bid] = FNR
    if (match(line, /\([A-Za-z]+[0-9]+\)/)) {
        b_step[bid] = substr(line, RSTART + 1, RLENGTH - 2)
    } else {
        problem(FILENAME ":" FNR ": " bid " names no step - write it as **" bid " (<step ID>):**")
    }
    note = ""
    p1 = index(line, ":**")
    if (p1 > 0) {
        note = trim(substr(line, p1 + 3))
    }
    if (note ~ /^[Kk]ept back/) {
        b_kept[bid] = 1
    }
    cur_b = bid
    next
}

#   - Kept because: A1, A2, A3 / - Would unblock: … / - Resolved:
cur_b != "" && /^[ \t]+-[ \t]+[A-Za-z][A-Za-z ]*:/ {
    line = trim($0)
    sub(/^-[ \t]+/, "", line)
    colon = index(line, ":")
    name = substr(line, 1, colon - 1)
    value = trim(substr(line, colon + 1))
    if (index(b_labels, " " name " ") == 0) {
        problem(FILENAME ":" FNR ": " cur_b " carries an unknown line \"" name ":\"")
        next
    }
    bseen[cur_b "\t" name] = 1
    if (name != "Resolved" && is_placeholder(value)) {
        problem(FILENAME ":" FNR ": " cur_b "'s \"" name ":\" is empty or still a placeholder")
    }
    next
}

# - files: / - result: what happened
(cur != "" || cur_attempt != "") && /^[ \t]+-[ \t]+[A-Za-z-]+:/ {
    flush_awaiting()
    if (cur != "") {
        end_line[cur] = FNR
    }
    line = trim($0)
    sub(/^-[ \t]+/, "", line)
    colon = index(line, ":")
    name = substr(line, 1, colon - 1)
    value = trim(substr(line, colon + 1))

    if (cur_attempt != "") {
        if (index(attempt_labels, " " name " ") == 0) {
            problem(FILENAME ":" FNR ": " cur_attempt " carries an unknown line \"" name ":\"")
            next
        }
        aseen[cur_attempt "\t" name] = 1
        if (name == "evidence") {
            awaiting_evidence = cur_attempt
        } else if (is_placeholder(value)) {
            problem(FILENAME ":" FNR ": " cur_attempt "'s \"" name ":\" is empty or still a placeholder")
        }
        next
    }

    if (!(name in takes)) {
        problem(FILENAME ":" FNR ": " cur " carries an unknown line \"" name ":\"")
        next
    }
    allowed = takes[name]
    if (allowed != "*" && (step_kind[cur] in requires) && \
        index(" " allowed " ", " " step_kind[cur] " ") == 0) {
        problem(FILENAME ":" FNR ": " cur " is a " step_kind[cur] " step and cannot carry \"" name ":\"")
    }
    if (is_placeholder(value)) {
        if (value == "" && (name in lists_below)) {
            awaiting = cur "\t" name
            awaiting_line = FNR
            awaiting_file = FILENAME
        } else {
            problem(FILENAME ":" FNR ": " cur "'s \"" name ":\" is empty or still a placeholder")
        }
    }
    seen[cur "\t" name] = 1

    # A change names one guide item and one place, separated by the middot.
    if (name == "change" && index(value, SEP) == 0) {
        problem(FILENAME ":" FNR ": " cur "'s \"change:\" names no place - put where it lands after a " SEP)
    }
    # A step in another steps file is named with that file - "shared/steps.md · U01" - and cannot be
    # resolved from here, so only the bare IDs are held to this file.
    if (name == "needs") {
        rest = value
        gsub(/[^ ,;]*\.md[^ ]* *\xc2\xb7 *[A-Za-z]+[0-9]+/, "", rest)
        while (match(rest, /U[0-9]+/)) {
            referenced[cur "\t" substr(rest, RSTART, RLENGTH)] = FNR
            rest = substr(rest, RSTART + RLENGTH)
        }
    }
    next
}

#     - `path/to/A`
awaiting != "" && /^[ \t]+-[ \t]+[^ \t]/ {
    awaiting = ""
    end_line[cur] = FNR
    next
}

cur != "" && /^[ \t]+[^ \t]/ { end_line[cur] = FNR; next }

# - **Q1:** … / - A:
in_questions && /^[ \t]*-[ \t]+\*\*Q[0-9]+/ {
    if (open_question != "") {
        problem(FILENAME ":" question_line ": " open_question " has no answer")
    }
    line = $0
    match(line, /Q[0-9]+/)
    open_question = substr(line, RSTART, RLENGTH)
    question_line = FNR
    next
}
in_questions && /^[ \t]*-[ \t]+(\*\*)?A:/ {
    answer = substr($0, index($0, ":") + 1)
    sub(/^\*\*/, "", answer)
    if (trim(answer) != "") {
        open_question = ""
    }
    next
}

END {
    close_step()
    flush_awaiting()
    close_fence()

    if (open_question != "") {
        problem(FILENAME ":" question_line ": " open_question " has no answer")
    }

    for (i = 1; i <= step_count; i++) {
        id = order[i]
        k = step_kind[id]
        if (k == "" || !(k in requires)) {
            continue
        }
        n = split(requires[k], need, " ")
        for (j = 1; j <= n; j++) {
            if (!((id "\t" need[j]) in seen)) {
                problem(spec_name ":" start_line[id] ": " id " is a " k " step and owes \"" need[j] ":\"")
            }
        }
    }

    for (key in referenced) {
        split(key, part, "\t")
        if (!(part[2] in start_line)) {
            problem(spec_name ":" referenced[key] ": " part[1] " names " part[2] ", which no step defines")
        }
    }

    for (i = 1; i <= attempt_count; i++) {
        aid = attempt_order[i]
        n = split(attempt_requires, need, " ")
        for (j = 1; j <= n; j++) {
            if (!((aid "\t" need[j]) in aseen)) {
                problem(FILENAME ":" attempt_line[aid] ": " aid " owes \"" need[j] ":\"")
            }
        }
        if ((aid "\tevidence") in aseen && !(aid in evidence_seen)) {
            problem(FILENAME ":" attempt_line[aid] ": " aid "'s \"evidence:\" has no fenced output under it")
        }
        if ((aid in attempt_phase) && !(attempt_phase[aid] in start_line)) {
            problem(FILENAME ":" attempt_phase_line[aid] ": " aid " is filed under " attempt_phase[aid] \
                    ", which no step defines")
        }
    }

    for (i = 1; i <= b_count; i++) {
        bid = b_order[i]
        if ((bid in b_step) && !(b_step[bid] in start_line)) {
            problem(FILENAME ":" b_line[bid] ": " bid " names " b_step[bid] ", which no step defines")
        }
        if (bid in b_kept) {
            n = split(kept_requires, need, "|")
            for (j = 1; j <= n; j++) {
                if (!((bid "\t" need[j]) in bseen)) {
                    problem(FILENAME ":" b_line[bid] ": " bid " is kept back and owes \"" need[j] ":\"")
                }
            }
        }
    }

    # Every command asks this before trusting a read: a file whose fence never closed was parsed as
    # half of itself, and half a file answers status, show and tick as confidently as a whole one.
    if (mode == "fence") {
        exit (unclosed ? 1 : 0)
    }

    if (mode == "list") {
        for (i = 1; i <= step_count; i++) {
            id = order[i]
            state = step_done[id] ? "x" : (step_abandoned[id] ? "a" : " ")
            print id "\t" state "\t" step_kind[id] "\t" start_line[id] "\t" end_line[id]
        }
        exit 0
    }

    if (mode == "nextblock") {
        print last_b + 1
        exit 0
    }

    if (mode == "validate") {
        for (i = 1; i <= problem_count; i++) {
            print problems[i]
        }
        # A missing log is reported by upgrade.sh, which knows the path it looked for; here it only counts.
        if (problem_count == 0 && files != "1") {
            print spec_name ": " step_count (step_count == 1 ? " step, " : " steps, ") \
                  attempt_count (attempt_count == 1 ? " attempt, " : " attempts, ") \
                  b_count (b_count == 1 ? " run-log entry, " : " run-log entries, ") "no problems"
        }
        exit (problem_count > 0 || files == "1" ? 1 : 0)
    }

    print "unknown mode: " mode > "/dev/stderr"
    exit 2
}
