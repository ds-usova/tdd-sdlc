# Parses the two published pages cost.sh fetches - the pricing page's model table and the models
# overview's comparison table - into one TSV line per model id:
#   id  input  output  cache_read  cache_write_5m  cache_write_1h  window
# Rates are dollars per million tokens, multipliers are relative to input, window is tokens or empty.
# Run as: awk -f pricing-parse.awk pricing.md models.md. Which file is which is read from the tables.
# A row it cannot read is dropped; a page with no readable table yields nothing, which cost.sh treats
# as a failed fetch.

function trim(s) {
    sub(/^[ \t]+/, "", s)
    sub(/[ \t]+$/, "", s)
    return s
}

# The cells of a markdown table row, without the outer pipes.
function cells(line, arr,   s, k) {
    s = line
    sub(/^[ \t]*\|/, "", s)
    sub(/\|[ \t]*$/, "", s)
    k = split(s, arr, "|")
    for (i = 1; i <= k; i++) arr[i] = trim(arr[i])
    return k
}

# "Claude Opus 4.1 ([retired ...](...))" -> "Claude Opus 4.1".
function model_name(cell,   s) {
    s = cell
    sub(/ *\(.*$/, "", s)
    gsub(/[*`]/, "", s)
    return trim(s)
}

# "Claude Opus 4.1" -> "claude-opus-4-1".
function derived_id(name,   s) {
    s = tolower(name)
    gsub(/[. ]+/, "-", s)
    return s
}

# "$12.50 / MTok1" -> 12.50. Empty where no dollar figure is in the cell.
function dollars(cell,   s) {
    s = cell
    if (match(s, /\$[0-9]+(\.[0-9]+)?/) == 0) return ""
    return substr(s, RSTART + 1, RLENGTH - 1)
}

# "1M tokens" -> 1000000, "200K tokens" -> 200000.
function window_of(cell,   s, v) {
    s = cell
    if (match(s, /[0-9]+(\.[0-9]+)?[ ]*[MK]/) == 0) return ""
    v = substr(s, RSTART, RLENGTH)
    if (v ~ /M/) return int(v + 0) * 1000000
    return int(v + 0) * 1000
}

function backticked(cell,   s) {
    s = cell
    if (match(s, /`[^`]+`/) == 0) return ""
    return substr(s, RSTART + 1, RLENGTH - 2)
}

# ---- the pricing table: a header naming "Base input" starts it, the next line is the rule, then rows

/^[ \t]*\|/ && tolower($0) ~ /base input/ {
    k = cells($0, h)
    ci = co = c5 = c1 = ch = 0
    for (i = 1; i <= k; i++) {
        l = tolower(h[i])
        if (l ~ /base input/) ci = i
        else if (l ~ /5m cache write/) c5 = i
        else if (l ~ /1h cache write/) c1 = i
        else if (l ~ /cache hit/) ch = i
        else if (l ~ /^output/) co = i
    }
    in_pricing = (ci && co) ? 1 : 0
    pricing_rule = 1
    next
}

in_pricing && /^[ \t]*\|/ {
    if (pricing_rule) { pricing_rule = 0; next }
    k = cells($0, c)
    name = model_name(c[1])
    inp = dollars(c[ci]); out = dollars(c[co])
    if (name == "" || inp == "" || out == "" || inp + 0 == 0) next
    pn++
    pname[pn] = name; pin[pn] = inp + 0; pout[pn] = out + 0
    pcr[pn] = (ch && dollars(c[ch]) != "") ? dollars(c[ch]) / pin[pn] : ""
    pc5[pn] = (c5 && dollars(c[c5]) != "") ? dollars(c[c5]) / pin[pn] : ""
    pc1[pn] = (c1 && dollars(c[c1]) != "") ? dollars(c[c1]) / pin[pn] : ""
    next
}

in_pricing && !/^[ \t]*\|/ { in_pricing = 0 }

# ---- the models table: the header names the models, three rows carry the id, the alias, the window

/^[ \t]*\|/ && $0 ~ /Claude/ && tolower($0) ~ /feature/ {
    mk = cells($0, mh)
    for (i = 2; i <= mk; i++) mname[i] = model_name(mh[i])
    in_models = 1
    next
}

in_models && /^[ \t]*\|/ {
    k = cells($0, c)
    l = tolower(c[1])
    if (l ~ /claude api id/) for (i = 2; i <= k; i++) mid[mname[i]] = backticked(c[i])
    else if (l ~ /claude api alias/) for (i = 2; i <= k; i++) malias[mname[i]] = backticked(c[i])
    else if (l ~ /context window/) for (i = 2; i <= k; i++) mwin[mname[i]] = window_of(c[i])
    next
}

in_models && !/^[ \t]*\|/ { in_models = 0 }

END {
    for (i = 1; i <= pn; i++) {
        name = pname[i]
        id = (name in mid && mid[name] != "") ? mid[name] : derived_id(name)
        win = (name in mwin) ? mwin[name] : ""
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, pin[i], pout[i], pcr[i], pc5[i], pc1[i], win
        if ((name in malias) && malias[name] != "" && malias[name] != id)
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", malias[name], pin[i], pout[i], pcr[i], pc5[i], pc1[i], win
    }
}
