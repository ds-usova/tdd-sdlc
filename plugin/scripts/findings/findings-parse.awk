# Parses the five sections of review/findings.md.  `validate` reports structural problems and writes
# disabled-test references to refs_file for findings.sh to resolve against git.  `summary` prints the
# canonical opening-count line after the same parse.

function trim(s) {
    sub(/^[ \t]+/, "", s)
    sub(/[ \t]+$/, "", s)
    return s
}

function problem(s) {
    print FILENAME ":" FNR ": " s
    problems++
}

function section_rank(s) {
    if (s == "Critical") return 1
    if (s == "Bug") return 2
    if (s == "Refactoring candidate") return 3
    if (s == "Deferred change") return 4
    if (s == "Performance") return 5
    return 0
}

function valid_closed_status(s, blocks) {
    if (s ~ /^done · .+$/ || s ~ /^withdrawn · .+$/) return 1
    if (!blocks && s ~ /^wontfix · .+$/) return 1
    return 0
}

function take_test_ref(v, line, resolve,    end, ref, tail) {
    if (substr(v, 1, 1) != "`") return 0
    end = index(substr(v, 2), "`")
    if (!end) return 0
    ref = substr(v, 2, end - 1)
    tail = substr(v, end + 2)
    if (tail != ", disabled") return 0
    if (ref !~ /^[A-Za-z_][A-Za-z0-9_.$]*#[A-Za-z_][A-Za-z0-9_$]*$/) return 0
    if (seen_test[ref]) problem("Test reference '" ref "' is already used by the defect block at line " seen_test[ref])
    else seen_test[ref] = line
    if (resolve && refs_file != "") print ref "\t" line >> refs_file
    return 1
}

function require_field(name) {
    if (!(name in fields)) problem(section " block beginning at line " block_line " has no " name " field")
}

function finish_block(    expected, i, n, a, status, kind) {
    if (!in_block) return

    if (section == "Bug") {
        expected = "Given When Then Actual Test Fix"
        require_field("Given"); require_field("When"); require_field("Then")
        require_field("Actual"); require_field("Test"); require_field("Fix")
        status = fields["Status"]
        if (("Test" in fields) && !take_test_ref(fields["Test"], field_line["Test"], status == ""))
            problem("Bug block beginning at line " block_line " has Test '" fields["Test"] \
                "'; expected `TestClass#method`, disabled")
        if (("Fix" in fields) && fields["Fix"] !~ / · `[^`]+`$/)
            problem("Bug block beginning at line " block_line " has no `target` after Fix")
        if (status == "") open_bug++
        else if (!valid_closed_status(status, 1)) problem("Bug block has invalid Status '" status "'")
    } else {
        expected = "Kind Measured Grows because Breaks as Fix"
        require_field("Kind"); require_field("Measured"); require_field("Grows because")
        require_field("Breaks as"); require_field("Fix")
        kind = fields["Kind"]
        status = fields["Status"]
        if (kind != "bug" && kind != "deferred change" && kind != "refactoring candidate")
            problem("Critical block has invalid Kind '" kind "'")
        if (kind == "bug") {
            expected = "Kind Measured Grows because Breaks as Test Fix"
            require_field("Test")
            if (("Test" in fields) && !take_test_ref(fields["Test"], field_line["Test"], status == ""))
                problem("Critical bug block beginning at line " block_line " has Test '" fields["Test"] \
                    "'; expected `TestClass#method`, disabled")
        } else if ("Test" in fields) {
            problem("Critical " kind " block beginning at line " block_line " must not have a Test field")
        }
        if (("Fix" in fields) && fields["Fix"] !~ / · `[^`]+`$/)
            problem("Critical block beginning at line " block_line " has no `target` after Fix")
        if (status == "") open_critical++
        else if (!valid_closed_status(status, 1)) problem("Critical block has invalid Status '" status "'")
    }

    n = split(expected, a, " ")
    # The two multi-word labels make a simple split unsuitable; compare the sequence assembled while reading.
    if (section == "Bug" && field_order != "Given|When|Then|Actual|Test|Fix" &&
            field_order != "Given|When|Then|Actual|Test|Fix|Status")
        problem("Bug block beginning at line " block_line " has fields out of order")
    if (section == "Critical") {
        if (kind == "bug") expected = "Kind|Measured|Grows because|Breaks as|Test|Fix"
        else expected = "Kind|Measured|Grows because|Breaks as|Fix"
        if (field_order != expected && field_order != expected "|Status")
            problem("Critical block beginning at line " block_line " has fields out of order")
    }

    delete fields
    delete field_line
    field_order = ""
    in_block = 0
}

function finish_section() {
    finish_block()
    if (section == "") return
    if (section_entries == 0) problem("section '" section "' has no entries")
    if (section_rank(section) >= 3) {
        if (!table_header) problem("section '" section "' has no table header")
        if (!table_separator) problem("section '" section "' has no table separator")
    }
}

function split_row(s, out,    i, c, prev, cell, n) {
    delete out
    s = trim(s)
    if (substr(s, 1, 1) == "|") s = substr(s, 2)
    if (substr(s, length(s), 1) == "|") s = substr(s, 1, length(s) - 1)
    n = 1; cell = ""; prev = ""
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "|" && prev != "\\") {
            out[n++] = trim(cell); cell = ""
        } else {
            cell = cell c
        }
        prev = c
    }
    out[n] = trim(cell)
    return n
}

function expected_prefix(s) {
    if (s == "Refactoring candidate") return "RX"
    if (s == "Deferred change") return "DX"
    return "PX"
}

function parse_table_row(line,    c, n, id, prefix, num, status) {
    n = split_row(line, c)
    if ((section == "Performance" && n != 6) || (section != "Performance" && n != 5)) {
        problem(section " row has " n " cells; expected " (section == "Performance" ? 6 : 5))
        return
    }
    id = c[1]; status = c[2]; prefix = expected_prefix(section)
    for (i = 1; i <= n; i++) {
        if (c[i] == "") problem(section " row has an empty cell")
    }
    if (c[3] !~ /^`[^`]+`$/) problem(section " row has module '" c[3] "'; expected `module`")
    if (id !~ ("^" prefix "[0-9][0-9]+$")) {
        problem(section " row has invalid ID '" id "'")
    } else {
        num = substr(id, 3) + 0
        if (num != next_id[prefix])
            problem(id " is out of sequence; expected " sprintf("%s%02d", prefix, next_id[prefix]))
        next_id[prefix] = num + 1
    }
    if (status != "open" && !valid_closed_status(status, 0))
        problem(id " has invalid Status '" status "'")
    if (status == "open") {
        if (section == "Refactoring candidate") open_refactoring++
        else if (section == "Deferred change") open_deferred++
        else open_performance++
    }
    table_rows++
}

function plural(n, one, many) { return n " " (n == 1 ? one : many) }

function canonical_summary(    s) {
    s = ""
    if (open_critical) s = plural(open_critical, "critical finding", "critical findings")
    if (open_bug) s = s (s ? ", " : "") plural(open_bug, "bug", "bugs")
    if (open_refactoring) s = s (s ? ", " : "") plural(open_refactoring,
        "refactoring candidate", "refactoring candidates")
    if (open_deferred) s = s (s ? ", " : "") plural(open_deferred, "deferred change", "deferred changes")
    if (open_performance) s = s (s ? ", " : "") plural(open_performance,
        "performance finding", "performance findings")
    if (s == "") return "**Nothing open.**"
    return "**" s " open.**"
}

BEGIN {
    next_id["RX"] = next_id["DX"] = next_id["PX"] = 1
}

{
    sub(/\r$/, "")
    if (FNR == 1 && $0 !~ /^# Review: .+/) problem("first line must be '# Review: <name>'")

    if (summary == "" && $0 ~ /^\*\*/) summary = $0

    if ($0 ~ /^## /) {
        finish_section()
        new_section = substr($0, 4)
        rank = section_rank(new_section)
        if (!rank) {
            problem("unknown section '" new_section "'")
            section = ""
            next
        }
        if (seen_section[new_section]) problem("duplicate section '" new_section "'")
        if (rank <= last_rank) problem("section '" new_section "' is out of order")
        seen_section[new_section] = 1
        last_rank = rank
        section = new_section
        section_entries = 0
        table_rows = 0
        table_header = 0
        table_separator = 0
        next
    }

    if (section == "Bug" || section == "Critical") {
        if ($0 ~ /^\*\*`[^`]+` — .+\*\*$/) {
            finish_block()
            if (section == "Critical") {
                if (seen_critical_heading[$0])
                    problem("Critical heading is already used by the block at line " seen_critical_heading[$0])
                else seen_critical_heading[$0] = FNR
            }
            in_block = 1
            block_line = FNR
            section_entries++
            next
        }
        if ($0 ~ /^- \*\*[^*]+\*\* /) {
            if (!in_block) { problem("a field appears before a " section " heading"); next }
            label = $0
            sub(/^- \*\*/, "", label)
            sub(/\*\*.*/, "", label)
            value = $0
            sub(/^- \*\*[^*]+\*\*[ \t]*/, "", value)
            if (label in fields) problem(section " block repeats " label)
            fields[label] = value
            field_line[label] = FNR
            field_order = field_order (field_order ? "|" : "") label
            next
        }
    } else if (section_rank(section) >= 3) {
        if ($0 ~ /^\|/) {
            if ($0 ~ /^\|[ \t]*#[ \t]*\|/) {
                if ((section == "Performance" && $0 != "| # | Status | module | test | threshold | figure |") ||
                        (section != "Performance" && $0 != "| # | Status | module | what | why |"))
                    problem("section '" section "' has the wrong table header")
                table_header = 1
                next
            }
            if ($0 ~ /^\|[- |]+\|[ \t]*$/) {
                if ((section == "Performance" && $0 != "|---|--------|--------|------|-----------|--------|") ||
                        (section != "Performance" && $0 != "|---|--------|--------|------|-----|"))
                    problem("section '" section "' has the wrong table separator")
                table_separator = 1
                next
            }
            parse_table_row($0)
            section_entries++
            next
        }
    }
}

END {
    finish_section()
    if (summary == "") problem("no opening count line")
    expected_summary = canonical_summary()
    if (mode != "summary") {
        if (open_critical + open_bug + open_refactoring + open_deferred + open_performance == 0) {
            if (summary !~ /^\*\*Nothing open\.\*\*/) problem("opening count is stale; expected " expected_summary)
        } else if (summary != expected_summary) {
            problem("opening count is stale; expected " expected_summary)
        }
    }
    if (mode == "summary") print expected_summary
    else if (!problems) print FILENAME ": findings are valid"
    exit(problems ? 1 : 0)
}
