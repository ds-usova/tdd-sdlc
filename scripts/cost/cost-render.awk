# Renders review/cost.jsonl, already deduplicated, priced and flattened to TSV by cost.sh, as the
# tables and the timelines of review/cost.md. -v MODE=md writes the report, -v MODE=puml the gantt
# blocks. It does no pricing: the dollar fields arrive computed, empty where the model is priced
# nowhere.
#
# Input records, tab separated:
#   A  id  parent  started  ended  session  agent  model  input  output  cache_create_5m
#      cache_create_1h  cache_read  turns  peak_ctx  offset  usd_read  usd_write  usd_out  window
#      seconds  plan
#   S  session  from  to  input  output  cache_create_5m  cache_create_1h  cache_read  turns
#      peak_ctx  offset  usd_read  usd_write  usd_out  window  model  status
# An S record whose status is not `ok` carries empty fields between session and status.
# -v skipped=N is the count of lines recorded before the hook wrote the newer fields.
# -v rates="..." is the sentence naming where the rates came from.

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

# Clock times are rendered in the report's one offset, `off` seconds east of UTC, chosen in END.
function hhmm(e,   r) {
    r = (e + off) % 86400
    if (r < 0) r = r + 86400
    return sprintf("%02d:%02d", int(r / 3600), int(r / 60) % 60)
}

# "2026-09-10 01:06:51" in the report's offset.
function fstamp(e,   z, era, doe, yoe, y, doy, mp, d, m, r) {
    e = e + off
    z = int(e / 86400)
    if (e < 0 && z * 86400 != e) z--
    r = e - z * 86400
    z += 719468
    era = int((z >= 0 ? z : z - 146096) / 146097)
    doe = z - era * 146097
    yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365)
    y = yoe + era * 400
    doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100))
    mp = int((5 * doy + 2) / 153)
    d = doy - int((153 * mp + 2) / 5) + 1
    m = mp < 10 ? mp + 3 : mp - 9
    if (m <= 2) y++
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", y, m, d, int(r / 3600), int(r / 60) % 60, r % 60)
}

# "+0200" -> 7200; anything else -> "".
function offset_secs(o) {
    if (o !~ /^[+-][0-9][0-9][0-9][0-9]$/) return ""
    return (substr(o, 1, 1) == "-" ? -1 : 1) * (substr(o, 2, 2) * 3600 + substr(o, 4, 2) * 60)
}

# "+0200" -> "UTC+02:00".
function offset_name(o) {
    return "UTC" substr(o, 1, 3) ":" substr(o, 4, 2)
}

# One offset per report: the session record with the latest window end, since the report's own call
# has just rewritten its mapping; else the agent record with the latest end; else UTC. Sets `off` and
# `off_name`.
function pick_offset(   i, best, cand) {
    off = 0; off_name = ""
    best = -1; cand = ""
    for (i = 1; i <= sn; i++) {
        if (sstat[i] != "ok" || offset_secs(soff[i]) == "") continue
        if (sto[i] > best) { best = sto[i]; cand = soff[i] }
    }
    if (cand == "") {
        best = -1
        for (i = 1; i <= n; i++) {
            if (offset_secs(aoff[i]) == "") continue
            if (aen[i] > best) { best = aen[i]; cand = aoff[i] }
        }
    }
    if (cand == "") return
    off = offset_secs(cand)
    off_name = offset_name(cand)
}

function ftok(t) {
    if (t >= 999500) return sprintf("%.1fM", t / 1000000)
    if (t >= 1000) return sprintf("%dk", int(t / 1000 + 0.5))
    return sprintf("%d", t)
}

# "$10.88"; an unpriced amount, carried as the empty string, is a dash. A row that mixes priced and
# unpriced agents shows the priced sum with `*`: the same mark, and the same unit, as the task total's.
function fusd(u, starred) {
    if (u == "") return "\342\200\224"
    return sprintf("$%.2f%s", u, starred ? "*" : "")
}

# A row's dollars: the priced sum, an empty string when nothing in it is priced.
function row_usd(sum, priced) {
    return priced ? sum : ""
}

function fpct(u, total) {
    if (u == "" || total <= 0) return "\342\200\224"
    return sprintf("%d%%", int(u / total * 100 + 0.5))
}

# Peak context against the window: "31%", or a dash without a window.
function fwin(peak, win) {
    if (win == "" || win + 0 <= 0) return "\342\200\224"
    return sprintf("%d%%", int(peak / win * 100 + 0.5))
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

function rpad(s, w,   r) {
    r = s
    while (vlen(r) < w) r = " " r
    return r
}

function commas(s) {
    gsub(/,/, ", ", s)
    return s
}

# Adds a model to a comma-joined list once.
function add_model(list, m) {
    if (m == "" || index("," list ",", "," m ",") > 0) return list
    return (list == "" ? m : list "," m)
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
    apriced[n] = ($17 != "")
    aur[n] = $17 + 0; auw[n] = $18 + 0; auo[n] = $19 + 0; awin[n] = $20
    ausd[n] = apriced[n] ? aur[n] + auw[n] + auo[n] : ""
    asec[n] = $21 + 0; apl[n] = $22
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
    spriced[sn] = ($13 != "")
    sur[sn] = $13 + 0; suw[sn] = $14 + 0; suo[sn] = $15 + 0; swin[sn] = $16; smod[sn] = $17
    susd[sn] = spriced[sn] ? sur[sn] + suw[sn] + suo[sn] : ""
    sstat[sn] = $18
}

# ---------------------------------------------------------------- rows of one timeline

function rows_reset() {
    split("", rlabel); split("", rst); split("", ren); split("", rusd); split("", rpeak); split("", rstar)
    split("", rind); split("", rleaf)
    rn = 0
}

function addrow(label, st, en, usd, peak, star, ind, leaf) {
    rn++
    rlabel[rn] = label; rst[rn] = st; ren[rn] = en; rusd[rn] = usd; rpeak[rn] = peak; rstar[rn] = star
    rind[rn] = ind; rleaf[rn] = leaf
}

# Agents of one type under one parent are grouped (docs/cost-recording.md). `withmod` puts the plan's
# module in the label, which the overview needs and a plan's own timeline does not. A group's dollars
# are its priced members' sum, starred when a member is unpriced; its peak context is the members' largest.
function group_rows(list, count, ind, withmod,
                    i, j, k, m, mi, key, gn, gc, gs, ge, gu, gp, gnp, gpr, glabel, gmem, at, ord, tmp) {
    gn = 0
    for (i = 1; i <= count; i++) {
        j = list[i]
        m = withmod ? module_of(apl[j]) : ""
        key = atyp[j] "|" apar[j] "|" m
        if (!(key in at)) {
            gn++
            at[key] = gn
            glabel[gn] = atyp[j] (m == "" ? "" : " " m)
            gc[gn] = 0; gs[gn] = ast[j]; ge[gn] = aen[j]; gu[gn] = 0; gp[gn] = 0; gnp[gn] = 0; gpr[gn] = 0
        }
        k = at[key]
        gc[k]++
        gmem[k "," gc[k]] = j
        if (ast[j] < gs[k]) gs[k] = ast[j]
        if (aen[j] > ge[k]) ge[k] = aen[j]
        if (apriced[j]) { gu[k] += ausd[j]; gpr[k] = 1 } else gnp[k] = 1
        if (apeak[j] > gp[k]) gp[k] = apeak[j]
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
            addrow(glabel[k], ast[j], aen[j], ausd[j], apeak[j], 0, ind, 1)
        } else {
            addrow(glabel[k] " \303\227" gc[k], gs[k], ge[k], row_usd(gu[k], gpr[k]), gp[k], gnp[k] && gpr[k], ind, 0)
            for (mi = 1; mi <= gc[k]; mi++) {
                j = gmem[k "," mi]
                addrow("#" mi, ast[j], aen[j], ausd[j], apeak[j], 0, ind + 1, 1)
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
    printf "%s %-5s  %-5s  %s%6s %s %s\n", pad("agent", 36), "start", "end", axis, "time",
        rpad("$", 8), rpad("peak ctx", 9)
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
        printf "%s %-5s  %-5s  %s%6s %s %s\n", pad(label, 36), hhmm(rst[i]), hhmm(ren[i]), line,
            fdur(rst[i], ren[i]), rpad(fusd(rusd[i], rstar[i]), 8), rpad(ftok(rpeak[i]), 9)
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

# "session (own turns)", with the session named when the task saw more than one.
function session_label(s) {
    if (sn == 1) return "session (own turns)"
    return "session " substr(sid[s], 1, 8) " (own turns)"
}

# ---------------------------------------------------------------- timelines

function overview(   i, list, count, title) {
    rows_reset()
    for (i = 1; i <= sn; i++) {
        if (sstat[i] != "ok") continue
        addrow(session_label(i), sfrom[i], sto[i], susd[i], speak[i], 0, 0, 1)
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
    addrow(atyp[i], ast[i], aen[i], ausd[i], apeak[i], 0, 0, 1)
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

# The task's total dollars over the priced agents and sessions, and the unpriced models comma-joined
# into `unpriced_models` with the count of unpriced agents and sessions in `unpriced_rows`.
function task_total(   i, t) {
    t = 0
    unpriced_rows = 0; unpriced_models = ""
    for (i = 1; i <= n; i++) {
        if (apriced[i]) t += ausd[i]
        else { unpriced_rows++; unpriced_models = add_model(unpriced_models, amod[i]) }
    }
    for (i = 1; i <= sn; i++) {
        if (sstat[i] != "ok") continue
        if (spriced[i]) t += susd[i]
        else { unpriced_rows++; unpriced_models = add_model(unpriced_models, smod[i]) }
    }
    return t
}

# One type per row across the task: count, dollars, counts, span, models. Sets tn and the t* arrays.
function type_rows(   i, k, key, idx) {
    tn = 0
    for (i = 1; i <= n; i++) {
        key = atyp[i]
        if (!(key in idx)) {
            tn++; idx[key] = tn; tk[tn] = key
            tc[tn] = 0; tur[tn] = 0; tuw[tn] = 0; tuo[tn] = 0; tnp[tn] = 0; tpr[tn] = 0
            tin[tn] = 0; tout[tn] = 0; tcw[tn] = 0; tcr[tn] = 0; tturn[tn] = 0; tpeak[tn] = 0; twin[tn] = ""
            tmin[tn] = ast[i]; tmax[tn] = aen[i]; tmod[tn] = ""
        }
        k = idx[key]
        tc[k]++
        if (apriced[i]) { tur[k] += aur[i]; tuw[k] += auw[i]; tuo[k] += auo[i]; tpr[k] = 1 } else tnp[k] = 1
        tin[k] += ain[i]; tout[k] += aout[i]; tcw[k] += acc5[i] + acc1[i]; tcr[k] += acr[i]
        tturn[k] += aturn[i]
        if (apeak[i] >= tpeak[k]) { tpeak[k] = apeak[i]; twin[k] = awin[i] }
        if (ast[i] < tmin[k]) tmin[k] = ast[i]
        if (aen[i] > tmax[k]) tmax[k] = aen[i]
        tmod[k] = add_model(tmod[k], amod[i])
    }
    order_by(tmin, tn, tord)
}

function cost_table(total,   i, k, u, st) {
    print ""
    print "## Cost"
    print ""
    print "| agent | n | $ | % | read $ | write $ | out $ | time | model |"
    print "|-------|---|---|---|--------|---------|-------|------|-------|"
    for (i = 1; i <= sn; i++) {
        if (sstat[i] == "ok")
            printf "| %s | 1 | %s | %s | %s | %s | %s | %s | %s |\n", session_label(i),
                fusd(susd[i]), fpct(susd[i], total),
                fusd(spriced[i] ? sur[i] : ""), fusd(spriced[i] ? suw[i] : ""),
                fusd(spriced[i] ? suo[i] : ""), fdur(sfrom[i], sto[i]), commas(smod[i])
        else
            printf "| %s | 1 | unavailable | | | | | unavailable | |\n", session_label(i)
    }
    for (i = 1; i <= tn; i++) {
        k = tord[i]
        u = row_usd(tur[k] + tuw[k] + tuo[k], tpr[k])
        st = tnp[k] && tpr[k]
        printf "| %s | %d | %s | %s | %s | %s | %s | %s | %s |\n", tk[k], tc[k],
            fusd(u, st), fpct(u, total),
            fusd(row_usd(tur[k], tpr[k]), st), fusd(row_usd(tuw[k], tpr[k]), st),
            fusd(row_usd(tuo[k], tpr[k]), st), fdur(tmin[k], tmax[k]), commas(tmod[k])
    }
    print ""
    print "`$` is what the run would cost at API rates: input at the model's input rate, cache reads at"
    print "the read multiplier (a tenth of it, or less on some models), cache writes at 1.25× for the"
    print "5-minute TTL and 2× for the 1-hour one, output at the output rate. On a subscription plan it"
    print "is not a bill. `read $` includes input, a few tokens per turn. `%` is the share of the task's"
    print "total. A `—` is a row priced nowhere; a `*` is a row with an unpriced agent left out of its"
    print "sum. The header says where the rates come from."
}

function volume_table(   i, k) {
    print ""
    print "## Volume"
    print ""
    print "| agent | turns | input | output | cache write | cache read | peak ctx | of window |"
    print "|-------|-------|-------|--------|-------------|------------|----------|-----------|"
    for (i = 1; i <= sn; i++) {
        if (sstat[i] == "ok")
            printf "| %s | %d | %s | %s | %s | %s | %s | %s |\n", session_label(i), sturn[i],
                ftok(sinp[i]), ftok(soutp[i]), ftok(scc5[i] + scc1[i]), ftok(scr[i]),
                ftok(speak[i]), fwin(speak[i], swin[i])
        else
            printf "| %s | unavailable | | | | | | |\n", session_label(i)
    }
    for (i = 1; i <= tn; i++) {
        k = tord[i]
        printf "| %s | %d | %s | %s | %s | %s | %s | %s |\n", tk[k], tturn[k],
            ftok(tin[k]), ftok(tout[k]), ftok(tcw[k]), ftok(tcr[k]), ftok(tpeak[k]), fwin(tpeak[k], twin[k])
    }
    print ""
    print "`cache read` is not new tokens: it is the conversation prefix, re-read from cache on each turn."
    print "It grows with roughly the square of the turn count. `peak ctx` is the largest one message's"
    print "input + cache write + cache read: the most context the agent carried at once. `of window` is"
    print "that against the model's context window. A type's `peak ctx` is its largest agent's."
}

function plan_table(   i, k, key, pn, pk, pc, pu, pnp, ppr, pmin, pmax, idx, pord) {
    pn = 0
    for (i = 1; i <= n; i++) {
        if (apl[i] == "") continue
        key = apl[i]
        if (!(key in idx)) {
            pn++; idx[key] = pn; pk[pn] = key
            pc[pn] = 0; pu[pn] = 0; pnp[pn] = 0; ppr[pn] = 0; pmin[pn] = ast[i]; pmax[pn] = aen[i]
        }
        k = idx[key]
        pc[k]++
        if (apriced[i]) { pu[k] += ausd[i]; ppr[k] = 1 } else pnp[k] = 1
        if (ast[i] < pmin[k]) pmin[k] = ast[i]
        if (aen[i] > pmax[k]) pmax[k] = aen[i]
    }
    if (pn == 0) return
    print ""
    print "| plan | agents | $ | time |"
    print "|------|--------|---|------|"
    order_by(pmin, pn, pord)
    for (i = 1; i <= pn; i++) {
        k = pord[i]
        printf "| `%s` | %d | %s | %s |\n", plan_of(pk[k]), pc[k],
            fusd(row_usd(pu[k], ppr[k]), pnp[k] && ppr[k]), fdur(pmin[k], pmax[k])
    }
}

function total_table(total,   i, first, nowe) {
    first = -1
    for (i = 1; i <= n; i++) if (first < 0 || ast[i] < first) first = ast[i]
    for (i = 1; i <= sn; i++) {
        if (sstat[i] != "ok") continue
        if (first < 0 || sfrom[i] < first) first = sfrom[i]
    }
    nowe = epoch(now)
    if (first < 0) first = nowe
    print ""
    print "## Task total"
    print ""
    print "| $ | span |"
    print "|---|------|"
    printf "| %s | %s (%s → %s) |\n", fusd(total, unpriced_rows > 0),
        fdur(first, nowe), hhmm(first), hhmm(nowe)
    if (unpriced_rows > 0)
        printf "\n* excludes %d unpriced agent%s (%s)\n", unpriced_rows, (unpriced_rows == 1 ? "" : "s"),
            commas(unpriced_models)
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
    pick_offset()
    if (MODE == "puml") {
        overview()
        print ""
        plan_blocks()
        exit 0
    }
    total = task_total()
    type_rows()
    print "# Cost · " task
    print ""
    printf "Written by `scripts/cost/cost.sh report` from `review/cost.jsonl` at %s. Times are %s.\n",
        fstamp(epoch(now)),
        (off_name == "" ? "UTC: no offset recorded" : off_name ", the offset of the latest record")
    print "Re-run the script rather than edit this file. What each number is: `docs/cost-recording.md`."
    if (rates != "") print rates
    if (skipped + 0 > 0)
        printf "%d line%s recorded before the format change %s skipped.\n", skipped,
            (skipped + 0 == 1 ? "" : "s"), (skipped + 0 == 1 ? "is" : "are")
    cost_table(total)
    volume_table()
    plan_table()
    total_table(total)
    print ""
    print "## Timelines"
    print ""
    print "```"
    overview()
    print "```"
    print ""
    plan_blocks()
}
