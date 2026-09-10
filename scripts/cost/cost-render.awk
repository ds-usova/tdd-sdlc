# Renders review/cost.jsonl, already deduplicated and flattened to TSV by cost.sh, as the tables and
# the timelines of review/cost.md. -v MODE=md writes the report, -v MODE=puml the gantt blocks.
#
# Input records, tab separated:
#   A  id  parent  started  ended  session  agent  model  input  output  cache_create_5m
#      cache_create_1h  cache_read  turns  peak_ctx  offset  seconds  plan
#   S  session  from  to  input  output  cache_create_5m  cache_create_1h  cache_read  turns
#      peak_ctx  offset  status
# -v skipped=N is the count of lines recorded before the hook wrote the newer fields.

function days(y, m, d,   era, yoe, doy, doe) {
    if (m <= 2) y = y - 1
    era = int((y >= 0 ? y : y - 399) / 400)
    yoe = y - era * 400
    doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
    doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
    return era * 146097 + doe - 719468
}

function epoch(s) {
    if (s !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/) return -1
    return days(substr(s, 1, 4) + 0, substr(s, 6, 2) + 0, substr(s, 9, 2) + 0) * 86400 \
        + substr(s, 12, 2) * 3600 + substr(s, 15, 2) * 60 + substr(s, 18, 2)
}

function hhmm(e,   r) {
    r = e % 86400
    if (r < 0) r = r + 86400
    return sprintf("%02d:%02d", int(r / 3600), int(r / 60) % 60)
}

function ftok(t) {
    if (t >= 999500) return sprintf("%.1fM", t / 1000000)
    if (t >= 1000) return sprintf("%dk", int(t / 1000 + 0.5))
    return sprintf("%d", t)
}

function mins(a, b) {
    if (a < 0 || b < 0) return 0
    return int((b - a) / 60 + 0.5)
}

# "25m" above a minute, "20s" below it.
function fdur(a, b,   d) {
    if (a < 0 || b < 0) return "0s"
    d = b - a
    if (d < 60) return sprintf("%ds", d)
    return sprintf("%dm", int(d / 60 + 0.5))
}

function ceil(x) {
    return (x == int(x)) ? int(x) : int(x) + 1
}

# The module a plan belongs to: docs/7-x/module-a/plan.md is module-a, docs/7-x/plan.md is nothing.
function module_of(p,   s, i) {
    if (p == "") return ""
    s = p
    sub(/^docs\/[0-9]+-[^\/]+\//, "", s)
    i = index(s, "/")
    if (i == 0) return ""
    return substr(s, 1, i - 1)
}

# The plan as the task names it: module-a/plan.md.
function plan_of(p,   s) {
    s = p
    sub(/^docs\/[0-9]+-[^\/]+\//, "", s)
    return s
}

# A label may carry a multibyte character - the group row's ×. An awk that counts bytes pads such a
# label one column short, so the columns are counted here: a byte in 0x80..0xBF continues a
# character rather than starting one, and an awk that already counts characters finds none.
function vlen(s,   t, c) {
    t = s
    c = gsub(/[\200-\277]/, "", t)
    return length(s) - c
}

function pad(s, w,   r) {
    r = s
    while (vlen(r) < w) r = r " "
    return r
}

function commas(s) {
    gsub(/,/, ", ", s)
    return s
}

BEGIN {
    FS = "\t"
    n = 0
    sn = 0
}

$1 == "A" {
    n++
    aid[n] = $2; apar[n] = $3; idset[$2] = 1
    ast[n] = epoch($4); aen[n] = epoch($5)
    asess[n] = $6; atyp[n] = $7; amod[n] = $8
    ain[n] = $9 + 0; aout[n] = $10 + 0; acc5[n] = $11 + 0; acc1[n] = $12 + 0; acr[n] = $13 + 0
    aturn[n] = $14 + 0; apeak[n] = $15 + 0; aoff[n] = $16
    atok[n] = ain[n] + aout[n] + acc5[n] + acc1[n] + acr[n]
    asec[n] = $17 + 0; apl[n] = $18
    if (atyp[n] == "implement-plan-module") kind_task = 1
    if (atyp[n] == "fix-bug-module") kind_fix = 1
    if (atyp[n] == "rework-module") kind_rework = 1
    if (atyp[n] == "upgrade-deps-module") kind_upgrade = 1
}

$1 == "S" {
    sn++
    sid[sn] = $2; sfrom[sn] = epoch($3); sto[sn] = epoch($4)
    sinp[sn] = $5 + 0; soutp[sn] = $6 + 0; scc5[sn] = $7 + 0; scc1[sn] = $8 + 0; scr[sn] = $9 + 0
    sturn[sn] = $10 + 0; speak[sn] = $11 + 0; soff[sn] = $12
    stok[sn] = sinp[sn] + soutp[sn] + scc5[sn] + scc1[sn] + scr[sn]
    sstat[sn] = $13
}

# ---------------------------------------------------------------- rows of one timeline

function rows_reset() {
    split("", rlabel); split("", rst); split("", ren); split("", rtok)
    split("", rind); split("", rleaf)
    rn = 0
}

function addrow(label, st, en, tok, ind, leaf) {
    rn++
    rlabel[rn] = label; rst[rn] = st; ren[rn] = en; rtok[rn] = tok
    rind[rn] = ind; rleaf[rn] = leaf
}

# Agents of one type under one parent are grouped (docs/cost-recording.md). `withmod` puts the plan's
# module in the label, which the overview needs and a plan's own timeline does not.
function group_rows(list, count, ind, withmod,
                    i, j, k, m, mi, key, gn, gc, gs, ge, gt, glabel, gmem, at, ord, tmp) {
    gn = 0
    for (i = 1; i <= count; i++) {
        j = list[i]
        m = withmod ? module_of(apl[j]) : ""
        key = atyp[j] "|" apar[j] "|" m
        if (!(key in at)) {
            gn++
            at[key] = gn
            glabel[gn] = atyp[j] (m == "" ? "" : " " m)
            gc[gn] = 0; gs[gn] = ast[j]; ge[gn] = aen[j]; gt[gn] = 0
        }
        k = at[key]
        gc[k]++
        gmem[k "," gc[k]] = j
        if (ast[j] < gs[k]) gs[k] = ast[j]
        if (aen[j] > ge[k]) ge[k] = aen[j]
        gt[k] += atok[j]
    }
    for (i = 1; i <= gn; i++) ord[i] = i
    for (i = 2; i <= gn; i++) {
        tmp = ord[i]; j = i - 1
        while (j >= 1 && gs[ord[j]] > gs[tmp]) { ord[j + 1] = ord[j]; j-- }
        ord[j + 1] = tmp
    }
    for (i = 1; i <= gn; i++) {
        k = ord[i]
        for (mi = 2; mi <= gc[k]; mi++) {
            tmp = gmem[k "," mi]; j = mi - 1
            while (j >= 1 && ast[gmem[k "," j]] > ast[tmp]) { gmem[k "," (j + 1)] = gmem[k "," j]; j-- }
            gmem[k "," (j + 1)] = tmp
        }
        if (gc[k] == 1) {
            j = gmem[k ",1"]
            addrow(glabel[k], ast[j], aen[j], atok[j], ind, 1)
        } else {
            addrow(glabel[k] " \303\227" gc[k], gs[k], ge[k], gt[k], ind, 0)
            for (mi = 1; mi <= gc[k]; mi++) {
                j = gmem[k "," mi]
                addrow("#" mi, ast[j], aen[j], atok[j], ind + 1, 1)
            }
        }
    }
}

# ---------------------------------------------------------------- drawing

function draw(title,   i, t0, t1, span, m, w, c, k, axis, line, sc, ec, ind, label, steps) {
    if (rn == 0) return
    t0 = rst[1]; t1 = ren[1]
    for (i = 1; i <= rn; i++) {
        if (rst[i] < t0) t0 = rst[i]
        if (ren[i] > t1) t1 = ren[i]
    }
    span = (t1 - t0) / 60
    if (span < 0.05) span = 0.05
    split("0.05 0.1 0.25 0.5 1 2 5 10 15 20 30 60 120 240 480 960 1920", steps, " ")
    for (i = 1; i <= 17; i++) { m = steps[i] + 0; if (ceil(span / m) <= 40) break }
    w = ceil(span / m)
    if (w < 1) w = 1

    axis = ""
    for (c = 0; c + 5 <= w; c += 10) {
        while (length(axis) < c) axis = axis " "
        axis = axis hhmm(t0 + c * m * 60)
    }
    while (length(axis) < w) axis = axis " "
    print title
    printf "%s %-5s  %-5s  %s%6s %7s\n", pad("agent", 36), "start", "end", axis, "time", "tokens"
    for (i = 1; i <= rn; i++) {
        sc = int((rst[i] - t0) / (m * 60))
        ec = ceil((ren[i] - t0) / (m * 60))
        if (ec <= sc) ec = sc + 1
        if (ec > w) ec = w
        line = ""
        for (c = 0; c < w; c++) line = line ((c >= sc && c < ec) ? "\342\226\210" : "\302\267")
        ind = ""
        for (k = 0; k < rind[i]; k++) ind = ind "  "
        label = ind rlabel[i]
        printf "%s %-5s  %-5s  %s%6s %7s\n", pad(label, 36), hhmm(rst[i]), hhmm(ren[i]), line,
            fdur(rst[i], ren[i]), ftok(rtok[i])
    }
}

# One gantt block per timeline; a day on its scale is a minute of wall time.
function draw_puml(title,   i, t0, label, group, seen, key, k, st, len) {
    if (rn == 0) return
    t0 = rst[1]
    for (i = 1; i <= rn; i++) if (rst[i] < t0) t0 = rst[i]
    print "@startgantt"
    print "' one day on this scale is one minute of wall time"
    print "title " title
    for (i = 1; i <= rn; i++) {
        if (!rleaf[i]) {
            group = rlabel[i]
            sub(/ \303\227[0-9]+$/, "", group)
            continue
        }
        label = rlabel[i]
        if (label ~ /^#/) label = group " " label
        key = label
        k = 1
        while (key in seen) { k++; key = label " (" k ")" }
        seen[key] = 1
        st = int((rst[i] - t0) / 60)
        len = mins(rst[i], ren[i])
        if (len < 1) len = 1
        print "[" key "] lasts " len " days"
        print "[" key "] starts " st " days after start"
    }
    print "@endgantt"
}

function emit(title) {
    if (MODE == "puml") draw_puml(title); else draw(title)
}

# ---------------------------------------------------------------- timelines

function overview(   i, list, count, title) {
    rows_reset()
    for (i = 1; i <= sn; i++) {
        if (sstat[i] != "ok") continue
        addrow("session (own turns)", sfrom[i], sto[i], stok[i], 0, 1)
    }
    count = 0
    for (i = 1; i <= n; i++) {
        if (atyp[i] ~ /^(implement-plan|fix-bug|rework|upgrade-deps)-module$/ || (apar[i] == "" && !adopted[i])) {
            count++
            list[count] = i
        }
    }
    group_rows(list, count, 0, 1)
    if (kind_fix) title = "fix " task
    else if (kind_rework) title = "rework " task
    else if (kind_upgrade) title = "upgrade " task
    else title = "task " task " \302\267 overview"
    emit(title)
}

# The pipeline an agent with no known parent joins: the one for its plan that had started last when
# the agent started, else the first for that plan. 0 where no pipeline has its plan.
function adopter(j,   i, best) {
    best = 0
    if (apl[j] == "" || atyp[j] ~ /-module$/) return 0
    if (apar[j] != "" && apar[j] != aid[j] && (apar[j] in idset)) return 0
    for (i = 1; i <= n; i++) {
        if (atyp[i] != "implement-plan-module" || apl[i] != apl[j]) continue
        if (best == 0) { best = i; continue }
        if (ast[i] <= ast[j] && (ast[best] > ast[j] || ast[i] > ast[best])) best = i
    }
    return best
}

# Every agent below one pipeline, however deep, by parent, plus the parentless ones it adopts.
function descendants(root, list,   i, changed, mark, count) {
    mark[aid[root]] = 1
    for (i = 1; i <= n; i++) if (i != root && adopter(i) == root) mark[aid[i]] = 1
    changed = 1
    while (changed) {
        changed = 0
        for (i = 1; i <= n; i++) {
            if (i == root) continue
            if (apar[i] != "" && (apar[i] in mark) && !(aid[i] in mark)) {
                mark[aid[i]] = 1
                changed = 1
            }
        }
    }
    count = 0
    for (i = 1; i <= n; i++) {
        if (i == root) continue
        if (aid[i] in mark) { count++; list[count] = i }
    }
    return count
}

function one_plan(i, nth,   list, count) {
    rows_reset()
    addrow(atyp[i], ast[i], aen[i], atok[i], 0, 1)
    count = descendants(i, list)
    group_rows(list, count, 1, 0)
    emit(plan_of(apl[i]) (nth > 1 ? " (" nth ")" : ""))
}

# ---------------------------------------------------------------- tables

function order_by(starts, cnt, ord,   i, j, tmp) {
    for (i = 1; i <= cnt; i++) ord[i] = i
    for (i = 2; i <= cnt; i++) {
        tmp = ord[i]; j = i - 1
        while (j >= 1 && starts[ord[j]] > starts[tmp]) { ord[j + 1] = ord[j]; j-- }
        ord[j + 1] = tmp
    }
}

function session_table(s,
                       i, k, key, tn, tk, tc, tt, tmin, tmax, tmod, tbig, idx, ord,
                       pn, pk, pc, pt, pmin, pmax, pord) {
    print ""
    print "## Session `" sid[s] "`"
    print ""
    print "| agent | n | tokens | time | model | largest |"
    print "|-------|---|--------|------|-------|---------|"
    if (sstat[s] == "ok")
        printf "| session (own turns) | 1 | %s | %s | | |\n", ftok(stok[s]), fdur(sfrom[s], sto[s])
    else
        print "| session (own turns) | 1 | unavailable | unavailable | | |"

    tn = 0
    for (i = 1; i <= n; i++) {
        if (asess[i] != sid[s]) continue
        key = atyp[i]
        if (!(key in idx)) {
            tn++; idx[key] = tn; tk[tn] = key
            tc[tn] = 0; tt[tn] = 0; tmin[tn] = ast[i]; tmax[tn] = aen[i]; tmod[tn] = ""; tbig[tn] = 0
        }
        k = idx[key]
        tc[k]++
        tt[k] += atok[i]
        if (ast[i] < tmin[k]) tmin[k] = ast[i]
        if (aen[i] > tmax[k]) tmax[k] = aen[i]
        if (atok[i] > tbig[k]) tbig[k] = atok[i]
        if (amod[i] != "" && index("," tmod[k] ",", "," amod[i] ",") == 0)
            tmod[k] = (tmod[k] == "" ? amod[i] : tmod[k] "," amod[i])
    }
    order_by(tmin, tn, ord)
    for (i = 1; i <= tn; i++) {
        k = ord[i]
        printf "| %s | %d | %s | %s | %s | %s |\n", tk[k], tc[k], ftok(tt[k]),
            fdur(tmin[k], tmax[k]), commas(tmod[k]), ftok(tbig[k])
    }

    split("", idx)
    pn = 0
    for (i = 1; i <= n; i++) {
        if (asess[i] != sid[s] || apl[i] == "") continue
        key = apl[i]
        if (!(key in idx)) {
            pn++; idx[key] = pn; pk[pn] = key
            pc[pn] = 0; pt[pn] = 0; pmin[pn] = ast[i]; pmax[pn] = aen[i]
        }
        k = idx[key]
        pc[k]++; pt[k] += atok[i]
        if (ast[i] < pmin[k]) pmin[k] = ast[i]
        if (aen[i] > pmax[k]) pmax[k] = aen[i]
    }
    if (pn > 0) {
        print ""
        print "| plan | agents | tokens | time |"
        print "|------|--------|--------|------|"
        order_by(pmin, pn, pord)
        for (i = 1; i <= pn; i++) {
            k = pord[i]
            printf "| `%s` | %d | %s | %s |\n", plan_of(pk[k]), pc[k], ftok(pt[k]), fdur(pmin[k], pmax[k])
        }
    }
}

function total(   i, tok, first, nowe) {
    tok = 0
    first = -1
    for (i = 1; i <= n; i++) {
        tok += atok[i]
        if (first < 0 || ast[i] < first) first = ast[i]
    }
    for (i = 1; i <= sn; i++) {
        if (sstat[i] != "ok") continue
        tok += stok[i]
        if (first < 0 || sfrom[i] < first) first = sfrom[i]
    }
    nowe = epoch(now)
    if (first < 0) first = nowe
    print ""
    print "## Task total"
    print ""
    print "| tokens | span |"
    print "|--------|------|"
    printf "| %s | %s (%s → %s) |\n", ftok(tok), fdur(first, nowe), hhmm(first), hhmm(nowe)
}

function plan_blocks(   i, seenp) {
    for (i = 1; i <= n; i++) {
        if (atyp[i] != "implement-plan-module" || apl[i] == "") continue
        seenp[apl[i]]++
        if (MODE != "puml") print "```"
        one_plan(i, seenp[apl[i]])
        if (MODE != "puml") print "```"
        print ""
    }
}

# Parentless step agents a pipeline adopts are marked before the overview is drawn.
function mark_adopted(   j) {
    for (j = 1; j <= n; j++) if (adopter(j) > 0) adopted[j] = 1
}

END {
    mark_adopted()
    if (MODE == "puml") {
        overview()
        print ""
        plan_blocks()
        exit 0
    }
    print "# Cost · " task
    print ""
    print "Written by `scripts/cost/cost.sh report` from `review/cost.jsonl` at " now ". Times are UTC."
    print "Re-run the script rather than edit this file. What each number is: `docs/cost-recording.md`."
    if (skipped + 0 > 0)
        printf "%d line%s recorded before the format change %s skipped.\n", skipped,
            (skipped + 0 == 1 ? "" : "s"), (skipped + 0 == 1 ? "is" : "are")
    for (i = 1; i <= sn; i++) session_table(i)
    total()
    print ""
    print "## Timelines"
    print ""
    print "```"
    overview()
    print "```"
    print ""
    plan_blocks()
}
