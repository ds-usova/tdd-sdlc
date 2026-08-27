#!/usr/bin/awk -f
#
# Parses a bug fix's checklist and the log beside it into one record per entry, and answers the
# query named by -v mode=.
#
# A step is "- [ ] <ID> · <kind> · <text>"; its block runs to the last line indented under it. The
# kind decides which of those lines the step owes and which it may not carry, which is what validate
# checks. "abandoned" on the header is a step struck by the level above; it is closed, not open.
#
# An attempt is "- **A1** · <phase> · <text>" under the log's "## Attempts". It owes its reasoning,
# its result, a fenced block of the runner's own output, and what it rules out - a failed approach
# recorded without its evidence is a rumour the next session has to reproduce.
#
# Two files, in order: the fix (or bug.md), then the log beside it. Steps are read from the first
# only and attempts and run-log entries from the second only; an attempt or a B entry in the first is
# reported, never read. `-v files=1` says the log is absent, which validate reports.
#
# Invoked by fix.sh, which ships beside it; see the README in the same directory.

function trim(s) {
    sub(/^[ \t]+/, "", s)
    sub(/[ \t]+$/, "", s)
    return s
}

# A value the author left unfilled. A step agent does exactly what the line says, so a dash where the
# symptom belongs is not a shorter instruction - it is no instruction.
function is_placeholder(v) {
    return v == "" || v == "-" || v == "--" || v == "\xe2\x80\x94" || v == "\xe2\x80\x93" \
        || v == "..." || v == "\xe2\x80\xa6" || v == "TBD" || v == "tbd" || v == "TODO" \
        || v == "todo" || v == "N/A" || v == "n/a" || v ~ /^<[^>]*>$/
}

function problem(text) {
    problems[++problem_count] = text
}

# "files:", "test-files:" and "evidence:" carry their value below the label rather than beside it, so
# their label line is empty by design. The label is only filled once something follows it; one that
# never gets a bullet lists nothing at all. Reported here, where the label is superseded, so problems
# stay in line order.
function flush_awaiting(   aw) {
    if (awaiting != "") {
        split(awaiting, aw, "\t")
        problem(awaiting_file ":" awaiting_line ": " aw[1] "'s \"" aw[2] ":\" lists nothing")
    }
    awaiting = ""
}

# "an inline step" reads as English; "a inline step" reads as a bug in the tool.
function a(word) {
    return (word ~ /^[aeiou]/ ? "an " : "a ") word
}

# A step ID mentioned inside a labelled line. Scanned with its own boundaries: "S3UploadTest" holds
# the characters of a step ID and is a test class, and a disabled test whose name happens to start
# that way must not be reported as a reference to a step nothing defines.
function scan_refs(who, label, text, line,   rest, id, before, after, found) {
    # A step in another file is named with that file, and cannot be resolved from here: a shared
    # stabilize step is cleared by a module's red step, and that module's red step needs the shared
    # one. Both are legitimate, and neither file holds the other's IDs. "fixes:" never crosses, so a
    # file named there is the mistake rather than the reason to stop looking.
    # Only the cross-file part of the value is exempt. A value naming a step in another file and one
    # in this file still owes the local one, and a value merely mentioning a path names no step.
    found = 0
    if (label != "fixes" && text ~ /\.md[^ ]* *\xc2\xb7/) {
        found = 1
        gsub(/[^ ,;]*\.md[^ ]* *\xc2\xb7 *[A-Za-z]+[0-9]+/, "", text)
    }
    rest = text
    while (match(rest, /[SRG][0-9]+/)) {
        id = substr(rest, RSTART, RLENGTH)
        before = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : ""
        after = substr(rest, RSTART + RLENGTH, 1)
        if (before !~ /[A-Za-z0-9]/ && after !~ /[A-Za-z0-9]/) {
            found = 1
            ref_count++
            ref_who[ref_count] = who
            ref_label[ref_count] = label
            ref_id[ref_count] = id
            ref_line[ref_count] = line
        }
        rest = substr(rest, RSTART + RLENGTH)
    }
    return found
}

function close_step() {
    flush_awaiting()
    cur = ""
    cur_attempt = ""
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

BEGIN {
    SEP = "\xc2\xb7"            # the middot the step and attempt headers separate on
    step_count = 0
    attempt_count = 0
    problem_count = 0
    ref_count = 0
    fenced = 0
    fence_len = 0
    unclosed = 0
    in_questions = 0
    in_attempts = 0
    in_runlog = 0
    open_question = ""
    awaiting = ""
    awaiting_evidence = ""
    cur = ""
    cur_attempt = ""
    last_b = 0
    b_count = 0
    b_step_count = 0
    fileidx = 1
    spec_file = ""
    spec_base = ""

    # The labels whose value sits below them rather than on the label line.
    below["files"]      = 1
    below["test-files"] = 1
    below["evidence"]   = 1

    # Every labelled line a step may carry, and the kinds that take it. "*" means any kind.
    takes["files"]       = "stabilize green"
    takes["test-files"]  = "stabilize red"
    takes["runs"]        = "red green"
    takes["reproduces"]  = "red"
    takes["fixes"]       = "green"
    takes["disables"]    = "stabilize"
    takes["needs"]       = "*"
    takes["docs"]        = "*"

    # What each kind cannot be written without. A stabilize step owes one of "files:" and
    # "test-files:" rather than either in particular: preparing a stub so the red step can be
    # written is the kind's own work, and touches no production file.
    requires["stabilize"] = ""
    requires["red"]       = "test-files reproduces runs"
    requires["green"]     = "files fixes runs"

    # One ID sequence per kind, so a reader knows what a step is before reading it.
    prefix_of["stabilize"] = "S"
    prefix_of["red"]       = "R"
    prefix_of["green"]     = "G"

    kinds = " stabilize red green "

    # An attempt owes all four: why it looked right, what happened, the output, and what it rules out.
    attempt_labels = " why result evidence ruled-out "
    attempt_requires = "why result evidence ruled-out"
}

# The index is taken from ARGV rather than FNR == 1, which an empty file never reaches. Everything
# positional resets with the file; what was collected - steps, attempts, problems - carries over.
FILENAME != prevfile {
    close_step()
    close_fence()
    prevfile = FILENAME
    fileidx = 0
    for (i = 1; i < ARGC; i++) if (ARGV[i] == FILENAME) fileidx = i
    if (fileidx == 1) {
        spec_file = FILENAME
        spec_base = FILENAME
        sub(/.*[\/\\]/, "", spec_base)
    }
    in_questions = 0; in_attempts = 0; in_runlog = 0
    if (open_question != "") {
        problem(spec_file ":" question_line ": " open_question " has no answer")
        open_question = ""
    }
}

# A checkout with CRLF endings otherwise leaves a carriage return on the end of every line: a fence
# never closes, an empty label never reads as empty, and the file is parsed as half of itself. Git
# Bash's awk strips it already; the awks this has to run on elsewhere do not.
{ sub(/\r$/, "") }

# A fenced block holds the format's own example, or an attempt's evidence. Counting its bullets as
# steps would give every fix the template's phantom IDs.
#
# The marker's length decides what closes it, as in Markdown itself. Evidence is pasted output and
# routinely contains a fence of its own, and a document quoting this format nests one example inside
# another - both are unreadable to a parser that closes on the first three backticks it sees.
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
        # A longer run is content: a row of tildes underlining a line is how compilers and query
        # planners point at a column, and it appears in pasted output constantly.
        if (char == fence_char && RLENGTH == fence_len && trim(substr(fence, RLENGTH + 1)) == "") {
            fenced = 0
            fence_len = 0
            awaiting_evidence = ""
        }
    } else {
        fenced = 1
        fence_len = RLENGTH
        fence_char = char
        fence_line = FNR
        fence_file = FILENAME
        fence_in_step = (cur != "" && indented)
    }
    # A block belongs to the step above it only where it is indented under it. An unindented one is
    # the document's, and "show" would otherwise hand a step agent somebody else's code.
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
# Anything else written in between ends the claim, and the attempt is reported as having none.
awaiting_evidence != "" && /[^ \t]/ { awaiting_evidence = "" }

/^#/ {
    close_step()
    # Forgiving about the plural: a heading typo would otherwise turn a whole check off in silence.
    # The Run Log heading is the one exception: it is matched exactly as `block` greps for it, so the
    # parser and the writer never disagree about where the entries go.
    in_questions = ($0 ~ /^#+[ \t]+[Oo]pen [Qq]uestions?/)
    in_attempts  = ($0 ~ /^#+[ \t]+[Aa]ttempts?/)
    in_runlog    = ($0 ~ /^## Run Log/)
    # The log owns both sections. Left in the spec they are the old shape, and the entries under them
    # would be read by nothing.
    if (fileidx == 1 && in_attempts) {
        problem(FILENAME ":" FNR ": '## Attempts' sits in the " spec_base " - the log beside it owns the attempts")
        in_attempts = 0
    }
    if (fileidx == 1 && in_runlog) {
        problem(FILENAME ":" FNR ": '## Run Log' sits in the " spec_base " - the log beside it owns the run log")
        in_runlog = 0
    }
    next
}

# Steps live in the fix file alone; a checkbox in the log is a record, not work.
fileidx != 1 && /^-[ \t]+\[[ xX]\][ \t]+/ { next }

# - [ ] R01 · red · what reproduces the bug
#
# At the left margin only. A checkbox indented under a step is part of that step's own text - reading
# it as a peer both invents a step nothing can tick and truncates the block "show" hands over.
/^-[ \t]+\[[ xX]\][ \t]+/ {
    close_step()

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
        structural = 1
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
        structural = 1
    }

    # A step given up on keeps its row; "abandoned —" in the header is how it says so. The marker is
    # the word and the dash together, so a step whose text mentions abandoning something stays open.
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

# - **A1** · S02 · what was tried
/^[ \t]*-[ \t]+\*\*A[0-9]+\*\*/ {
    flush_awaiting()
    cur = ""
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
        problem(FILENAME ":" FNR ": " aid " names no phase - put \"diagnosis\" or a step ID after the " SEP)
    } else if (phase != "diagnosis") {
        attempt_phase_line[aid] = FNR
        attempt_phase[aid] = phase
    }

    attempt_order[++attempt_count] = aid
    attempt_line[aid] = FNR
    cur_attempt = aid
    next
}

# A run-log entry: "- **B3 (G01):** …", numbered once and ascending, so a new one is appended and
# never inserted above an older one. One outside the Run Log is reported, and still counted, so the
# next number never repeats it. The parenthesis names what the entry is about: a step ID beside a
# fix.md, which the file has to define; "diagnosis" or a module beside a bug.md, which holds no steps.
/^-[ \t]+\*\*B[0-9]+/ {
    close_step()
    match($0, /B[0-9]+/)
    b = substr($0, RSTART + 1, RLENGTH - 1) + 0
    if (fileidx == 1) {
        problem(FILENAME ":" FNR ": B" b " sits in the " spec_base " - the log beside it owns the run log")
        next
    }
    if (!in_runlog) {
        problem(FILENAME ":" FNR ": B" b " sits outside '## Run Log'")
    } else if (b <= last_b) {
        problem(FILENAME ":" FNR ": B" b " is not above the entry before it - append, never insert")
    }
    if (b > last_b) last_b = b
    b_count++
    if (match($0, /\([^)]+\)/)) {
        subject = substr($0, RSTART + 1, RLENGTH - 2)
        if (subject ~ /^[A-Za-z]+[0-9]+$/ || spec_base != "bug.md") {
            b_step_count++
            b_step_id[b_step_count] = "B" b
            b_step_of[b_step_count] = subject
            b_step_line[b_step_count] = FNR
        }
    } else {
        problem(FILENAME ":" FNR ": B" b " names no step - write it as **B" b " (<step ID>):**")
    }
    next
}

# - files: / - result: an approach that failed
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
    # A step whose kind was not recognized is reported once, at its header. Judging its lines against
    # a kind that does not exist would bury that one line under a cascade.
    allowed = takes[name]
    if (allowed != "*" && (step_kind[cur] in requires) && \
        index(" " allowed " ", " " step_kind[cur] " ") == 0) {
        problem(FILENAME ":" FNR ": " cur " is " a(step_kind[cur]) " step and cannot carry \"" name ":\"")
    }
    empty_label = 0
    if (is_placeholder(value)) {
        empty_label = 1
        if (value == "" && (name in below)) {
            awaiting = cur "\t" name
            awaiting_line = FNR
            awaiting_file = FILENAME
        } else {
            problem(FILENAME ":" FNR ": " cur "'s \"" name ":\" is empty or still a placeholder")
        }
    } else if (name in below) {
        # The value belongs under the label, one path per bullet. A run of paths beside it is read by
        # scanning for commas, and a boundary has to be readable at a glance.
        problem(FILENAME ":" FNR ": " cur "'s \"" name ":\" carries its value on the label line" \
                " - one path per bullet under it")
    }
    if ((cur "\t" name) in seen) {
        problem(FILENAME ":" FNR ": " cur " carries \"" name ":\" twice")
    }
    seen[cur "\t" name] = 1

    if (name == "needs") {
        scan_refs(cur, name, value, FNR)
    }
    # A "fixes:" that names no step at all is the pairing missing, not prose: the label exists only
    # to name one.
    if (name == "fixes" && !scan_refs(cur, name, value, FNR) && !empty_label) {
        problem(FILENAME ":" FNR ": " cur "'s \"fixes:\" names no step")
    }
    # "disables:" carries a test name and the step that clears it. The whole value is scanned rather
    # than a phrase after a fixed wording, since the format states no wording - and a test class
    # whose name starts like a step ID is not a reference, which the scan's own boundaries settle.
    if (name == "disables" && !scan_refs(cur, name, value, FNR) && !empty_label) {
        problem(FILENAME ":" FNR ": " cur " disables a test and names no step that clears it")
    }
    next
}

#     - `path/to/A`
awaiting != "" && /^[ \t]+-[ \t]+[^ \t]/ {
    awaiting = ""
    if (cur != "") {
        end_line[cur] = FNR
    }
    next
}

cur != "" && /^[ \t]+[^ \t]/ { end_line[cur] = FNR; next }

# An unindented line that is none of the above is the document's again, and everything after it
# belongs to nobody. Without this a note written between the last step and the next heading is handed
# to a step agent as part of its step.
cur != "" && /^[^ \t]/ { close_step() }

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
in_questions && /^[ \t]*-[ \t]+(A:|\*\*A:\*\*)/ {
    answer = substr($0, index($0, ":") + 1)
    sub(/^\*\*/, "", answer)
    if (trim(answer) != "") {
        open_question = ""
    }
    next
}

END {
    close_step()
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
                problem(spec_file ":" start_line[id] ": " id " is " a(k) " step and owes \"" need[j] ":\"")
            }
        }
        if (k == "stabilize" && !((id "\tfiles") in seen) && !((id "\ttest-files") in seen)) {
            problem(spec_file ":" start_line[id] ": " id " names neither \"files:\" nor \"test-files:\"" \
                    " - a stabilize step that touches nothing stabilizes nothing")
        }
        match(id, /^[A-Za-z]+/)
        if (substr(id, 1, RLENGTH) != prefix_of[k]) {
            problem(spec_file ":" start_line[id] ": " id " is " a(k) " step, whose ID is " \
                    prefix_of[k] " and a number")
        }
    }

    for (i = 1; i <= ref_count; i++) {
        if (!(ref_id[i] in start_line)) {
            problem(spec_file ":" ref_line[i] ": " ref_who[i] " names " ref_id[i] \
                    ", which this file defines no step for - a step in another file is named with it")
            continue
        }
        if (ref_label[i] != "fixes") {
            continue
        }
        if (ref_id[i] == ref_who[i]) {
            problem(spec_file ":" ref_line[i] ": " ref_who[i] " names itself as the step it fixes")
        } else if (step_kind[ref_id[i]] == "red") {
            fixed[ref_id[i]] = 1
        } else if (step_kind[ref_id[i]] in requires) {
            problem(spec_file ":" ref_line[i] ": " ref_who[i] " fixes " ref_id[i] ", which is " \
                    a(step_kind[ref_id[i]]) " step rather than a reproduction")
        }
    }

    # A file with a duplicate ID or an unrecognized kind is judged no further: the pairing it appears
    # to be missing is usually the one the reported mistake took away, and reporting both blames the
    # wrong step. A red step struck as abandoned owes no green one: it was given up on, not dropped.
    for (i = 1; i <= step_count && !structural; i++) {
        id = order[i]
        if (step_kind[id] == "red" && !(id in fixed) && !step_abandoned[id]) {
            problem(spec_file ":" start_line[id] ": " id " reproduces the bug and no green step fixes it")
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
                    ", which is neither \"diagnosis\" nor a step the fix file defines")
        }
    }

    for (i = 1; i <= b_step_count; i++) {
        if (!(b_step_of[i] in start_line)) {
            problem(FILENAME ":" b_step_line[i] ": " b_step_id[i] " names " b_step_of[i] \
                    ", which no step defines")
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
            print id "\t" (step_done[id] ? "x" : (step_abandoned[id] ? "a" : " ")) "\t" step_kind[id] "\t" \
                  start_line[id] "\t" end_line[id]
        }
        exit 0
    }

    # One attempt ID per line, in log order, for the summary line fix.sh attempts prints.
    if (mode == "attempts") {
        for (i = 1; i <= attempt_count; i++) {
            print attempt_order[i]
        }
        exit 0
    }

    if (mode == "nextblock") {
        print last_b + 1
        exit 0
    }

    if (mode == "validate") {
        # A fix file with no steps is almost always the wrong path, and "no problems" would be the
        # last thing such a reader needs to hear. bug.md holds no steps by design, and a log with no
        # attempts is a run that failed at nothing.
        if (step_count == 0 && spec_file !~ /bug\.md$/) {
            problem(spec_file ": no steps - is this a fix file?")
        }
        for (i = 1; i <= problem_count; i++) {
            print problems[i]
        }
        # A missing log is reported by fix.sh, which knows the path it looked for; here it only counts.
        if (files == "1") {
            problem_count++
        }
        if (problem_count == 0) {
            print spec_file ": " step_count (step_count == 1 ? " step, " : " steps, ") \
                  attempt_count (attempt_count == 1 ? " attempt, " : " attempts, ") \
                  b_count (b_count == 1 ? " run-log entry, " : " run-log entries, ") "no problems"
        }
        exit (problem_count > 0 ? 1 : 0)
    }
}
