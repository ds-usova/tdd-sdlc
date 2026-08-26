# Parses a task's spec, its design, and the design log - three files, one shape check.
#
# Strict POSIX awk - no gensub, no length(array), no third argument to match(). Checked with
# `gawk --posix`, so mawk and BSD awk serve as well as gawk.
#
# Invocation: awk -f design-parse.awk -v mode=... -v files=<n> <spec.md> [<design.md> [<design-log.md>]]
# The files are read in that order; `files` says how many were passed. open/status/range read the
# spec alone.
#
# Modes (-v mode=...):
#   validate  problems on stdout, exit 1 if any
#   open      the IDs whose Basis is must-decide, one per line
#   status    counts per basis
#   range     with -v want=<ID>: "<first line> <last line>" of that entry in the spec

function trim(s) {
    sub(/^[ \t]+/, "", s)
    sub(/[ \t]+$/, "", s)
    return s
}

# An em dash is one character to a multibyte-aware awk and three bytes to every other one. Both
# spellings are tried rather than assuming which awk is running.
function strip_dash(s) {
    s = trim(s)
    if (substr(s, 1, 1) == "\342\200\224") s = substr(s, 2)
    else if (substr(s, 1, 3) == "\342\200\224") s = substr(s, 4)
    else if (substr(s, 1, 1) == "-") s = substr(s, 2)
    return trim(s)
}

# What counts as unfilled. The same placeholder set plan.sh rejects in a given:/when:/then:.
function unfilled(v) {
    v = trim(v)
    if (v == "") return 1
    if (v == "-" || v == "\342\200\224") return 1
    if (toupper(v) == "TBD" || toupper(v) == "N/A") return 1
    return 0
}

# The number inside a D<n>, F<n>, R<n> or A<n> id, for ordering.
function idnum(id) {
    sub(/^[A-Za-z]+/, "", id)
    return id + 0
}

# The n-th cell of a table row, with surrounding bold and whitespace stripped.
function cell(line, n,    s, parts, k) {
    s = line
    sub(/^[ \t]*\|/, "", s)
    sub(/\|[ \t]*$/, "", s)
    k = split(s, parts, "|")
    if (n > k) return ""
    s = parts[n]
    gsub(/\*/, "", s)
    return trim(s)
}

# Every required heading located once, then the positions checked for monotonicity - so two swapped
# sections report as one displaced section rather than as every section after them being out of order.
function check_sections(label, have, nhave, want, nwant,    i, j, p, prev, last) {
    prev = 0; last = ""
    for (j = 1; j <= nwant; j++) {
        p = 0
        for (i = 1; i <= nhave; i++)
            if (have[i] == want[j]) p = i
        if (p == 0) { problem(label "section '" want[j] "' is missing"); continue }
        if (p < prev) problem(label "section '" want[j] "' comes before '" last "'")
        else { prev = p; last = want[j] }
    }
}

function close_entry() {
    if (cur > 0) eline[cur] = lastcontent
    cur = 0
}

function problem(msg) {
    print msg
    problems = 1
}

BEGIN {
    nent = 0; cur = 0; problems = 0; infence = 0; nrow = 0
    lastcontent = 0; seen_modules = 0; grilled = 0; nsub = 0; nsce = 0
    nreqs = 0; ntok = 0; nlogbase = 0; nconcern = 0; fileidx = 0
    nspecsec = 0; ndessec = 0; nlogsec = 0; stray_f = 0; prevfile = ""
    grill_design = 0; grill_frontend = 0; cura = 0
    if (files == "") files = 1
    nspecreq = split("## Objective,## Requirements,## Acceptance Scenarios,## Decisions", specreq, ",")
    ndesreq = split("## Context,## Proposed Solution", desreq, ",")
    nlogreq = split("## Concerns,## Findings,## Decision Bases", logreq, ",")
    ndc = split("failure modes,idempotency & retry,concurrency,recovery,data,contract compat,lifecycle,authorization,observability,limits,business invariants,stack-neutral", dconcern, ",")
    nfc = split("empty & extreme,default state,layout stability,consistency,colour system,motion,third-party ui,library reach,input & locale,person's state,reachability,stack-neutral", fconcern, ",")
    nsrc = split("ts,tsx,js,jsx,mjs,java,kt,py,go,rs,cs,rb,php,swift,scala,css,scss,html,xml,gradle,toml,sql", srcext, ",")
}

# Keyed on the file name rather than FNR == 1, which an empty file never reaches - the next file would
# then be parsed under the wrong index.
FILENAME != prevfile {
    close_entry()
    prevfile = FILENAME
    fileidx = 0
    for (i = 1; i < ARGC; i++)
        if (ARGV[i] == FILENAME) fileidx = i
    section = ""
    infence = 0
}

# A file quotes its own entry format; bullets inside a fence are examples, not entries.
{
    if ($0 ~ /^[ \t]*```/) { infence = 1 - infence; next }
    if (infence) next
}

/^## / {
    close_entry()
    section = trim($0)
    if (fileidx == 1) { nspecsec++; specsect[nspecsec] = section; lastcontent = NR }
    else if (fileidx == 2) { ndessec++; dessect[ndessec] = section }
    else { nlogsec++; logsect[nlogsec] = section }
    next
}

# ---------------------------------------------------------------- the spec -----------------------

fileidx == 1 && section == "## Requirements" && /^- \*\*R[0-9]+:\*\*/ {
    rid = $0
    sub(/^- \*\*/, "", rid)
    sub(/:\*\*.*$/, "", rid)
    txt = $0
    sub(/^- \*\*R[0-9]+:\*\*[ \t]*/, "", txt)
    nreqs++
    reqid[nreqs] = rid
    reqtxt[nreqs] = trim(txt)
    lastcontent = NR
    next
}

fileidx == 1 && section == "## Acceptance Scenarios" && /^- \*\*A[0-9]+:\*\*/ {
    aid = $0
    sub(/^- \*\*/, "", aid)
    sub(/:\*\*.*$/, "", aid)
    nsce++
    sceid[nsce] = aid
    sceproves[nsce] = ""
    cura = nsce
    lastcontent = NR
    next
}

fileidx == 1 && cura > 0 && /^[ \t]*- Proves:/ {
    v = $0
    sub(/^[ \t]*- Proves:[ \t]*/, "", v)
    sceproves[cura] = trim(v)
    lastcontent = NR
    next
}

fileidx == 1 && /^- \*\*D[0-9]+:\*\*/ {
    close_entry()
    nent++
    cur = nent

    id = $0
    sub(/^- \*\*/, "", id)
    sub(/:\*\*.*$/, "", id)

    q = $0
    sub(/^- \*\*D[0-9]+:\*\*[ \t]*/, "", q)

    eid[nent] = id
    question[nent] = trim(q)
    sline[nent] = NR
    insec[nent] = section
    nans[nent] = 0
    nbasis[nent] = 0
    ans[nent] = ""
    kw[nent] = ""
    why[nent] = ""
    lastcontent = NR
    next
}

# Answer and Basis are nested under their entry, so the bullet is indented. A flat one is still read:
# the indentation is a rendering rule, and an older file must not stop parsing because of it.
fileidx == 1 && cur > 0 && /^[ \t]*- Answer:/ {
    v = $0
    sub(/^[ \t]*- Answer:[ \t]*/, "", v)
    nans[cur]++
    ans[cur] = trim(v)
    lastcontent = NR
    next
}

fileidx == 1 && cur > 0 && /^[ \t]*- Basis:/ {
    v = $0
    sub(/^[ \t]*- Basis:[ \t]*/, "", v)
    raw = trim(v)
    nbasis[cur]++

    k = ""
    if (raw ~ /^assumed/) k = "assumed"
    else if (raw ~ /^decided/) k = "decided"
    else if (raw ~ /^deferred/) k = "deferred"
    else if (raw ~ /^must-decide/) k = "must-decide"

    kw[cur] = k
    if (k == "") why[cur] = raw
    else why[cur] = strip_dash(substr(raw, length(k) + 1))
    lastcontent = NR
    next
}

# A findings table left in the spec or the design is the old shape; it belongs to the log now.
fileidx < 3 && /^\|[ \t]*F[0-9]+[ \t]*\|/ { stray_f = 1 }

# An entry extends over its own indented lines only; a top-level line that is not a bullet ends it, so
# `show` never prints the prose that follows the last entry.
fileidx == 1 && cur > 0 && /^[ \t]+[^ \t]/ { lastcontent = NR; next }
fileidx == 1 && cur > 0 && NF { close_entry() }
fileidx == 1 && NF { lastcontent = NR }

# ---------------------------------------------------------------- the design ---------------------

fileidx == 2 && /^\*\*Affected Modules:\*\*/ { seen_modules = 1 }

# The size report. A design grows with the subjects it carries, and a #### section under Proposed
# Solution is where a subject shows: the counts are printed with the verdict so the session sees the
# size on every run and splits the task before the file outgrows its reader.
fileidx == 2 && section == "## Proposed Solution" && /^#### / { nsub++ }

# A source file named under Proposed Solution is a plan-level fact wearing a design section. Backtick
# tokens and link targets alike: `Foo.java` and [Foo](../src/Foo.java) name the same file. Contract
# formats - yaml, json, proto - are not on the list: a shared schema is a design fact.
function note_source(tok,    ext, k) {
    if (tok ~ /[ \t]/) return
    sub(/#.*$/, "", tok)
    ext = tok
    if (!match(ext, /\.[A-Za-z]+$/)) return
    ext = tolower(substr(ext, RSTART + 1))
    for (k = 1; k <= nsrc; k++)
        if (ext == srcext[k] && !seentok[tok]) { seentok[tok] = 1; ntok++; toks[ntok] = tok }
}

# note_source calls match() itself, so the caller's RSTART/RLENGTH are copied out before the call.
fileidx == 2 && section == "## Proposed Solution" {
    line = $0
    while (match(line, /\]\([^)]*\)/)) {
        s = RSTART; l = RLENGTH
        note_source(substr(line, s + 2, l - 3))
        line = substr(line, s + l)
    }
    line = $0
    while (match(line, /`[^`]+`/)) {
        s = RSTART; l = RLENGTH
        note_source(substr(line, s + 1, l - 2))
        line = substr(line, s + l)
    }
}

# ---------------------------------------------------------------- the log ------------------------

fileidx == 3 && section == "## Concerns" && /Grilled \(/ {
    grilled = 1
    if ($0 ~ /grill-design/) grill_design = 1
    if ($0 ~ /grill-frontend/) grill_frontend = 1
}

fileidx == 3 && section == "## Concerns" && /^\|/ {
    c = tolower(cell($0, 1))
    if (c == "" || c == "concern" || c ~ /^:?-+:?$/) next
    nconcern++
    cname[nconcern] = c
    cverdict[nconcern] = cell($0, 2)
    cwhy[nconcern] = cell($0, 3)
    next
}

fileidx == 3 && section == "## Findings" && /^\|[ \t]*F[0-9]+[ \t]*\|/ {
    nrow++
    rowid[nrow] = cell($0, 1)
    rowq[nrow] = cell($0, 2)
    rowa[nrow] = cell($0, 3)
    rowe[nrow] = cell($0, 4)
    next
}

fileidx == 3 && section == "## Decision Bases" && /^- \*\*D[0-9]+:\*\*/ {
    id = $0
    sub(/^- \*\*/, "", id)
    sub(/:\*\*.*$/, "", id)
    txt = $0
    sub(/^- \*\*D[0-9]+:\*\*[ \t]*/, "", txt)
    nlogbase++
    baseid[nlogbase] = id
    basetxt[nlogbase] = trim(txt)
    next
}

END {
    close_entry()

    if (mode == "range") {
        for (i = 1; i <= nent; i++)
            if (eid[i] == want) { print sline[i] " " eline[i]; exit 0 }
        exit 1
    }

    if (mode == "open") {
        for (i = 1; i <= nent; i++)
            if (kw[i] == "must-decide") print eid[i] "\t" question[i]
        exit 0
    }

    if (mode == "status") {
        for (i = 1; i <= nent; i++) {
            k = (kw[i] == "" ? "unrecognized" : kw[i])
            count[k]++
        }
        n = split("assumed,decided,deferred,must-decide,unrecognized", order, ",")
        for (i = 1; i <= n; i++)
            if (count[order[i]] > 0) print order[i] "\t" count[order[i]]
        print "total\t" nent
        exit 0
    }

    # ------------------------------------------------------------ validate: the spec -------------

    check_sections("spec: ", specsect, nspecsec, specreq, nspecreq)
    for (i = 1; i <= nspecsec; i++)
        if (specsect[i] == "## Design Findings")
            problem("spec: section '## Design Findings' belongs to the design log now, as '## Findings'")
    if (stray_f)
        problem("an F<n> table row sits in the spec or the design - findings rows live in the design log")

    # Requirements and the scenarios that prove them. A requirement nothing proves is a promise with
    # no test behind it; a scenario proving nothing is behaviour nobody asked for.
    if (nreqs == 0)
        problem("spec: the Requirements section lists no R<n> line - every change promises at least one thing")
    for (i = 1; i <= nreqs; i++) {
        if (seenr[reqid[i]]) problem("spec: " reqid[i] " is defined twice")
        seenr[reqid[i]] = 1
        if (unfilled(reqtxt[i])) problem("spec: " reqid[i] " states nothing")
    }
    for (i = 1; i <= nsce; i++) {
        if (seena[sceid[i]]) problem("spec: " sceid[i] " is defined twice")
        seena[sceid[i]] = 1
        if (unfilled(sceproves[i])) { problem("spec: " sceid[i] " has no 'Proves:' line naming the R it proves"); continue }
        p = sceproves[i]
        gsub(/,/, " ", p)
        n = split(p, ids, /[ \t]+/)
        for (k = 1; k <= n; k++) {
            if (ids[k] == "") continue
            if (ids[k] !~ /^R[0-9]+$/) { problem("spec: " sceid[i] " proves '" ids[k] "', which is not an R<n>"); continue }
            if (!seenr[ids[k]]) problem("spec: " sceid[i] " proves " ids[k] ", which the Requirements section does not define")
            proven[ids[k]] = 1
        }
    }
    for (i = 1; i <= nreqs; i++)
        if (!proven[reqid[i]]) problem("spec: " reqid[i] " is proved by no scenario")

    if (nent == 0)
        problem("spec: the Decisions section records no D<n> entry - every change makes at least one call")

    for (i = 1; i <= nent; i++) {
        if (seen[eid[i]]) problem("spec: " eid[i] " is defined twice")
        seen[eid[i]] = 1

        if (insec[i] != "## Decisions")
            problem("spec: " eid[i] " sits under '" insec[i] "' - entries belong in the Decisions section")

        if (unfilled(question[i]))
            problem("spec: " eid[i] " states no question")

        if (nbasis[i] == 0) { problem("spec: " eid[i] " has no 'Basis:' line"); continue }
        if (nbasis[i] > 1) problem("spec: " eid[i] " has " nbasis[i] " 'Basis:' lines")
        if (nans[i] == 0) { problem("spec: " eid[i] " has no 'Answer:' line"); continue }
        if (nans[i] > 1) problem("spec: " eid[i] " has " nans[i] " 'Answer:' lines")

        if (kw[i] == "") {
            problem("spec: " eid[i] " has an unrecognized Basis - one of decided, must-decide")
            continue
        }

        # A decided entry owes who and when; a must-decide owes what the repository does not say.
        # The reasoning and the files behind a decision are the log's, under the same id.
        if (unfilled(why[i]))
            problem("spec: " eid[i] " is '" kw[i] "' with nothing after it - who chose and when, or what is missing")

        if (kw[i] == "must-decide" && !unfilled(ans[i]))
            problem("spec: " eid[i] " is must-decide but carries an Answer - settle the Basis or clear the Answer")
        if (kw[i] != "must-decide" && unfilled(ans[i]))
            problem("spec: " eid[i] " is '" kw[i] "' with no Answer")

        # Decisions is what the user reads: the calls they made, and the ones waiting for them. A question the
        # repository settles was still asked, and its record is a Findings row in the log.
        if (kw[i] == "assumed" || kw[i] == "deferred")
            problem("spec: " eid[i] " is '" kw[i] "' - only decided and must-decide are entries, the rest are Findings rows in the design log")
    }

    # ------------------------------------------------------------ validate: the design -----------

    if (files < 2) {
        problem("no design.md beside the spec")
        exit 1
    }

    if (!seen_modules)
        problem("design: no '**Affected Modules:**' line - it belongs at the very top, under the title")
    check_sections("design: ", dessect, ndessec, desreq, ndesreq)

    # Proposed Solution is stack-neutral: a source file named there is the plan's fact.
    for (i = 1; i <= ntok; i++)
        problem("design: Proposed Solution names a source file, `" toks[i] "` - a design reads the same in any language; move it to Context or the plan")

    # ------------------------------------------------------------ validate: the log --------------

    if (files < 3) {
        problem("no design-log.md beside the spec - the grill has not run")
        exit 1
    }

    check_sections("design log: ", logsect, nlogsec, logreq, nlogreq)

    if (!grilled)
        problem("design log: Concerns carries no 'Grilled (<date>): <grill>' line - the grill has not run")
    else if (!grill_design && !grill_frontend)
        problem("design log: the Grilled line names neither grill-design nor grill-frontend")

    # Every concern a named grill owns gets a row, verdict and reason - a concern with no row is one
    # nobody can tell was examined.
    for (i = 1; i <= nconcern; i++) {
        if (seenc[cname[i]]) problem("design log: concern '" cname[i] "' has two rows")
        seenc[cname[i]] = 1
        if (unfilled(cverdict[i])) problem("design log: concern '" cname[i] "' has no verdict")
        if (unfilled(cwhy[i])) problem("design log: concern '" cname[i] "' has a verdict with no why")
    }
    if (grill_design)
        for (k = 1; k <= ndc; k++)
            if (!seenc[dconcern[k]]) problem("design log: grill-design ran but Concerns has no '" dconcern[k] "' row")
    if (grill_frontend)
        for (k = 1; k <= nfc; k++)
            if (!seenc[fconcern[k]]) problem("design log: grill-frontend ran but Concerns has no '" fconcern[k] "' row")

    for (i = 1; i <= nrow; i++) {
        if (seenrow[rowid[i]]) problem("design log: " rowid[i] " is defined twice")
        seenrow[rowid[i]] = 1
        if (unfilled(rowq[i]) || unfilled(rowa[i]) || unfilled(rowe[i]))
            problem("design log: " rowid[i] " leaves a cell empty - question, answer and evidence are all owed")
    }

    # Findings numbers are assigned once and never reused, so the table is read in ascending order. A row
    # inserted above a higher-numbered one is the edit that anchored on the wrong line.
    for (i = 2; i <= nrow; i++)
        if (idnum(rowid[i]) < idnum(rowid[i - 1]))
            problem("design log: " rowid[i] " comes after " rowid[i - 1] " - findings rows keep ascending order")

    # Every decision's reasoning - the alternatives, the files it rests on - lives in the log under the
    # same id, and only there.
    for (i = 1; i <= nlogbase; i++) {
        if (seenb[baseid[i]]) problem("design log: " baseid[i] " has two Decision Bases entries")
        seenb[baseid[i]] = 1
        if (!seen[baseid[i]]) problem("design log: Decision Bases names " baseid[i] ", which the spec does not define")
        if (unfilled(basetxt[i])) problem("design log: " baseid[i] " has a Decision Bases entry with nothing in it")
    }
    for (i = 1; i <= nent; i++)
        if (kw[i] == "decided" && !seenb[eid[i]])
            problem("design log: " eid[i] " is decided but Decision Bases has no entry for it - say what it rested on")

    if (!problems) print nreqs " requirements, " nsce " scenarios, " nent " decisions, " nsub " solution sections, " nconcern " concerns, " nrow " findings, no problems"
    exit problems
}
