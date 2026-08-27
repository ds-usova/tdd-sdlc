#!/usr/bin/awk -f
#
# Parses a rework's checklist into one record per step and answers the query named by -v mode=.
#
# A step is "- [ ] <ID> · <kind> · <text>"; its block runs to the last line indented under it. The
# kind decides which of those lines the step owes and which it may not carry, which is what validate
# checks.
#
# Two files, in order: the steps file, then the log beside it. Steps are read from the first only and
# run-log entries from the second only; a B entry in the steps file is reported, never read, and a
# checkbox in the log is a record, not work. `-v files=1` says the log is absent, which validate
# counts and rework.sh reports with the path it looked for.
#
# Invoked by rework.sh, which ships beside it; see the README in the same directory.

function trim(s) {
    sub(/^[ \t]+/, "", s)
    sub(/[ \t]+$/, "", s)
    return s
}

# A value the author left unfilled. A step agent does exactly what the line says, so a dash where the
# scenario belongs is not a shorter instruction - it is no instruction.
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
# Reported here, where the label is superseded, so problems stay in line order.
function flush_awaiting(   aw) {
    if (awaiting != "") {
        split(awaiting, aw, "\t")
        problem(awaiting_file ":" awaiting_line ": " aw[1] "'s \"" aw[2] ":\" lists nothing")
    }
    awaiting = ""
}

# "an extract step" reads as English; "a extract step" reads as a bug in the tool.
function a(word) {
    return (word ~ /^[aeiou]/ ? "an " : "a ") word
}

# A step ends on the last non-blank line indented under it, which every rule that reads one records
# as it goes; closing the step only forgets which one is open, so a trailing blank line or a file
# boundary never lands inside a step's range.
function close_step() {
    flush_awaiting()
    cur = ""
}

# The file's own name, for a message about what sits in it.
function basename(path,   n, parts) {
    n = split(path, parts, "/")
    return parts[n]
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
}

BEGIN {
    SEP = "\xc2\xb7"            # the middot the step header separates on
    DASH = "\xe2\x80\x94"       # the em dash "abandoned" is written with
    step_count = 0
    problem_count = 0
    fenced = 0
    fence_len = 0
    in_questions = 0
    in_runlog = 0
    open_question = ""
    awaiting = ""
    last_b = 0
    b_count = 0
    b_ref_count = 0
    unclosed = 0
    fileidx = 1

    # The labels whose value is a list of bullets under them rather than text on the label line.
    lists_below["files"]      = 1
    lists_below["test-files"] = 1

    # Every labelled line a step may carry, and the kinds that take it. "*" means any kind.
    takes["files"]      = "inline extract pin stabilize"
    takes["test-files"] = "*"
    takes["runs"]       = "inline"
    takes["frozen"]     = "extract"
    takes["cover"]      = "extract"
    takes["survives"]   = "tests"
    takes["measures"]   = "tests"
    takes["proves"]     = "pin"
    takes["disables"]   = "stabilize"
    takes["needs"]      = "*"
    takes["docs"]       = "*"

    # What each kind cannot be written without. A pin edits a check or a setting, so it owes one of
    # "files:"/"test-files:" rather than either in particular; that pair is checked in END.
    requires["inline"]    = "files runs"
    requires["extract"]   = "files test-files frozen cover"
    requires["tests"]     = "test-files survives"
    requires["pin"]       = "proves"
    requires["stabilize"] = "files"

    kinds = " inline extract tests pin stabilize "
}

# A checkout with CRLF endings otherwise leaves a carriage return on the end of every line: a fence
# never closes, an empty label never reads as empty, and the file is parsed as half of itself. Git
# Bash's awk strips it already; the awks this has to run on elsewhere do not.
{ sub(/\r$/, "") }

# The index is taken from ARGV rather than FNR == 1, which an empty file never reaches. Per-file
# state resets here; an unclosed fence in the first file is reported before the second is read.
FILENAME != prevfile {
    close_step()
    close_fence()
    prevfile = FILENAME
    fileidx = 0
    for (i = 1; i < ARGC; i++) if (ARGV[i] == FILENAME) fileidx = i
    in_questions = 0; in_runlog = 0
    if (open_question != "") {
        problem(question_file ":" question_line ": " open_question " has no answer")
        open_question = ""
    }
}

# A fenced block holds the format's own example, or a pasted run. Counting its bullets as steps would
# give every rework the template's phantom IDs.
#
# The marker's length decides what closes it, as in Markdown itself. Pasted output routinely contains
# a fence of its own, and a document quoting this format nests one example inside another - both are
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
        # A longer run is content: a row of tildes underlining a line is how compilers and query
        # planners point at a column, and it appears in pasted output constantly.
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
    if (fence_in_step) {
        end_line[cur] = FNR
    }
    next
}

/^#/ {
    close_step()
    # Forgiving about the plural: a heading typo would otherwise turn a whole check off in silence.
    in_questions = ($0 ~ /^#+[ \t]+[Oo]pen [Qq]uestions?/)
    # Exactly the heading block writes and looks for; a variant of it would hold entries block
    # cannot number after.
    in_runlog = ($0 ~ /^## Run Log/)
    # The steps file is what an agent reads and ticks; nothing in it is history. Both sections belong
    # to the log beside it, and one written here is the old shape.
    if (fileidx == 1 && in_runlog) {
        problem(FILENAME ":" FNR ": '## Run Log' sits in the " basename(FILENAME) " - the log beside it owns the run log")
    }
    if (fileidx == 1 && $0 ~ /^#+[ \t]+[Aa]ttempts?/) {
        problem(FILENAME ":" FNR ": '## Attempts' sits in the " basename(FILENAME) " - the log beside it owns the attempts")
    }
    next
}

# - **B3 (R02):** … - a run-log entry, numbered once and ascending, so a new one is appended and never
# inserted above an older one. At the left margin only: indented, it is text under whatever is above
# it. One outside the Run Log is reported, and still counted, so the next number never repeats it.
# In the steps file it is reported and not counted: the log's numbering is the log's alone. The step
# it names is held to the steps file, once that file has been read whole.
/^- \*\*B[0-9]+/ {
    close_step()
    match($0, /B[0-9]+/)
    b = substr($0, RSTART + 1, RLENGTH - 1) + 0
    if (fileidx == 1) {
        problem(FILENAME ":" FNR ": B" b " sits in the " basename(FILENAME) " - the log beside it owns the run log")
        next
    }
    b_count++
    if (!in_runlog) {
        problem(FILENAME ":" FNR ": B" b " sits outside '## Run Log'")
    } else if (b <= last_b) {
        problem(FILENAME ":" FNR ": B" b " is not above the entry before it - append, never insert")
    }
    if (b > last_b) last_b = b
    if (match($0, /\([A-Za-z]+[0-9]+\)/)) {
        b_ref_count++
        b_ref_id[b_ref_count] = substr($0, RSTART + 1, RLENGTH - 2)
        b_ref_b[b_ref_count] = b
        b_ref_line[b_ref_count] = FILENAME ":" FNR
    } else {
        problem(FILENAME ":" FNR ": B" b " names no step - write it as **B" b " (<step ID>):**")
    }
    next
}

# - **A1** · … - an attempt entry, which this format does not keep.
fileidx == 1 && /^[ \t]*-[ \t]+\*\*A[0-9]+\*\*/ {
    close_step()
    match($0, /A[0-9]+/)
    problem(FILENAME ":" FNR ": " substr($0, RSTART, RLENGTH) " sits in the " basename(FILENAME) " - the log beside it owns the attempts")
    next
}

# Steps live in the steps file alone; a checkbox in the log is a record, not work.
fileidx != 1 && /^-[ \t]+\[[ xX]\][ \t]+/ { next }

# - [ ] R01 · extract · what moves
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

    # A step given up on keeps its row and its box open; "abandoned — <why>" on the header is how it
    # says so. The dash is what tells the marker from a step whose text merely mentions the word.
    abandoned = (index(line, "abandoned " DASH) > 0)

    order[++step_count] = id
    start_line[id] = FNR
    end_line[id] = FNR
    step_kind[id] = kind
    step_done[id] = ticked
    step_abandoned[id] = abandoned
    cur = id
    next
}

# - files: `path/to/A`
cur != "" && /^[ \t]+-[ \t]+[A-Za-z-]+:/ {
    flush_awaiting()
    end_line[cur] = FNR
    line = trim($0)
    sub(/^-[ \t]+/, "", line)
    colon = index(line, ":")
    name = substr(line, 1, colon - 1)
    value = trim(substr(line, colon + 1))

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

    if (name == "survives" && index(value, SEP) == 0) {
        problem(FILENAME ":" FNR ": " cur "'s \"survives:\" names no tier - put what it runs against after a " SEP)
    }
    # A step in another steps file is named with that file - "shared/steps.md · R01" - and cannot be
    # resolved from here, so only the bare IDs are held to this file. A value merely mentioning a
    # path names no step.
    if (name == "needs" || name == "disables") {
        rest = value
        gsub(/[^ ,;]*\.md[^ ]* *\xc2\xb7 *[A-Za-z]+[0-9]+/, "", rest)
        while (match(rest, /R[0-9]+/)) {
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

# An unindented line that is none of the above is the document's again, and everything after it
# belongs to nobody. Without this a note written between the last step and the next heading is handed
# to a step agent as part of its step.
cur != "" && /^[^ \t]/ { close_step() }

# - **Q1:** … / - A:
in_questions && /^[ \t]*-[ \t]+\*\*Q[0-9]+/ {
    if (open_question != "") {
        problem(question_file ":" question_line ": " open_question " has no answer")
    }
    line = $0
    match(line, /Q[0-9]+/)
    open_question = substr(line, RSTART, RLENGTH)
    question_line = FNR
    question_file = FILENAME
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
        problem(question_file ":" question_line ": " open_question " has no answer")
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
                problem(ARGV[1] ":" start_line[id] ": " id " is " a(k) " step and owes \"" need[j] ":\"")
            }
        }
        if (k == "pin" && !((id "\tfiles") in seen) && !((id "\ttest-files") in seen)) {
            problem(ARGV[1] ":" start_line[id] ": " id " is a pin step and owes \"files:\" or \"test-files:\"")
        }
    }

    for (key in referenced) {
        split(key, part, "\t")
        if (!(part[2] in start_line)) {
            problem(ARGV[1] ":" referenced[key] ": " part[1] " names " part[2] ", which no step defines")
        }
    }

    for (i = 1; i <= b_ref_count; i++) {
        if (!(b_ref_id[i] in start_line)) {
            problem(b_ref_line[i] ": B" b_ref_b[i] " names " b_ref_id[i] ", which no step defines")
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

    # The next B number. Entries are counted wherever they sit in the log, so a misplaced one is
    # never repeated by the one that follows it.
    if (mode == "nextblock") {
        print last_b + 1
        exit 0
    }

    if (mode == "validate") {
        for (i = 1; i <= problem_count; i++) {
            print problems[i]
        }
        # A missing log is reported by rework.sh, which knows the path it looked for; here it only
        # counts against the verdict.
        if (files == "1") {
            problem_count++
        }
        # A rework.md above several modules holds no steps by design, so zero is a count, not a fault.
        if (problem_count == 0) {
            print ARGV[1] ": " step_count (step_count == 1 ? " step, " : " steps, ") \
                  b_count (b_count == 1 ? " run-log entry, " : " run-log entries, ") "no problems"
        }
        exit (problem_count > 0 ? 1 : 0)
    }
}
