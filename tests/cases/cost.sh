#!/usr/bin/env bash
# The two cost hooks and cost.sh on the cost fixture. good/ is copied to $WORK: a git repository under
# repo/ holding docs/7-add-widget, and the session's transcripts under projects/sess-1/. The agent
# transcripts the recorder is fed sit under agents/, the cost records the report is fed under
# records/; tests/fixtures/cost/README.md lists them. The rates cache lives under $WORK too, so a run
# never touches the user's own. The report's golden is priced by pricing.json from the fixture, seeded
# into that cache, so neither the network nor the plugin's bundled table can move it.
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

FX="$TESTS_DIR/fixtures/cost"
F="$(fixture cost/good)"
fake="$(fixture cost/fakebin)"; chmod +x "$fake/curl"
fake_ok="$(fixture cost/fakebin-ok)"; chmod +x "$fake_ok/curl"
export COST_FAKE_PAGES="$FX/pages" COST_FAKE_CALLS="$WORK/curl-calls"
: > "$COST_FAKE_CALLS"   # both fakes append the URL they were asked for; calls_n counts them
export XDG_CACHE_HOME="$WORK/cache"
repo "$F/repo"
MAP="$R/scripts/hooks/map-session-to-task.sh"
REC="$R/scripts/hooks/record-agent-cost.sh"
COST="$R/scripts/cost/cost.sh"
cd "$F/repo" || exit 1
CWD="$(pwd -W 2>/dev/null || pwd)"
SUB="$F/projects/sess-1/subagents"
JSONL=docs/7-add-widget/review/cost.jsonl
MD=docs/7-add-widget/review/cost.md
SESS=.git/tdd-sdlc/sessions/sess-1

map() {
  rm -f "$SESS"
  printf '{"session_id":"sess-1","transcript_path":"%s","cwd":"%s","tool_input":{"command":%s}}' \
    "$F/projects/sess-1/session.jsonl" "$CWD" "$(printf '%s' "$1" | jq -Rs .)" | bash "$MAP"
}
mapped() { [ -f "$SESS" ] && echo mapped || echo none; }
# agent ID: puts agents/ID.jsonl, and ID.meta.json when there is one, into the session's subagents/
agent() { for f in "$FX/agents/$1".*; do cp "$f" "$SUB/agent-$(basename "$f")"; done; }
rec() {
  printf '{"session_id":"%s","agent_id":"%s","agent_type":"%s","agent_transcript_path":"%s","cwd":"%s"}' \
    "$1" "$2" "$3" "$SUB/agent-$2.jsonl" "$CWD" | bash "$REC"
}
records() { for r in "$@"; do cat "$FX/records/$r.jsonl"; done >> "$JSONL"; }
lines() { wc -l < "$JSONL" | tr -d ' '; }
mapping() { printf '%s\n%s\n%s\n%s\n%s\n' docs/7-add-widget "$F/projects/sess-1/session.jsonl" \
  2026-09-08T13:40:00Z 2026-09-08T14:40:00Z +0200 > "$SESS"; }
report_offline() { PATH="$fake:$PATH" bash "$COST" report docs/7-add-widget 2>&1 | tail -1; }
report_fetching() { PATH="$fake_ok:$PATH" bash "$COST" report docs/7-add-widget 2>&1 | tail -1; }
calls_n() { wc -l < "$COST_FAKE_CALLS" | tr -d ' '; }

# --- the mapper: which commands map a session to a task
map 'bash /x/scripts/plan/plan.sh status docs/7-add-widget/plan.md'
check "a framework call maps the session" mapped "$(mapped)"
check "the mapping has five lines" 5 "$(wc -l < "$SESS" | tr -d ' ')"
check "line 1 is the task directory" docs/7-add-widget "$(sed -n 1p "$SESS")"
for c in 'bash "C:/x y/scripts/plan/plan.sh" status docs/7-add-widget' \
         "bash 'C:/xy/plan.sh' status docs/7-add-widget" \
         $'cd x\nbash /p/plan.sh status docs/7-add-widget' \
         'FOO=1 bash /p/plan.sh status docs/7-add-widget' \
         'FOO=1 /p/plan.sh status docs/7-add-widget' \
         'echo x | plan.sh status docs/7-add-widget' \
         'cd /r && bash /p/plan.sh status docs/7-add-widget'; do
  map "$c"; check "maps: ${c//$'\n'/ }" mapped "$(mapped)"
done
map 'bash C:\plug\scripts\plan\plan.sh task docs\7-add-widget'
check "a backslash path maps" mapped "$(mapped)"
check "a backslash path is stored with slashes" docs/7-add-widget "$(sed -n 1p "$SESS")"
for c in 'vim docs/7-add-widget/plan.sh' 'cat docs/7-add-widget/cost.sh' \
         'plan.sh status docs/implemented/3-old/plan.md'; do
  map "$c"; check "does not map: $c" none "$(mapped)"
done
map 'bash /x/scripts/plan/plan.sh status docs/7-add-widget/plan.md'
first="$(sed -n 4p "$SESS")"; sleep 1
printf '{"session_id":"sess-1","transcript_path":"%s","cwd":"%s","tool_input":{"command":"cost.sh report docs/7-add-widget"}}' \
  "$F/projects/sess-1/session.jsonl" "$CWD" | bash "$MAP"
check_no_match "a later call refreshes line 4" "^$first\$" "$(sed -n 4p "$SESS")"
mapping

# --- the recorder: where an agent's cost is filed
n0=$(lines)
agent bk
rec sess-1 bk tdd-unit-green-phase-step
check "a prompt citing another task before its own plan files under its own" $((n0 + 1)) "$(lines)"
check "no directory is created for the cited task" "7-add-widget" "$(ls docs | tr '\n' ' ' | sed 's/ $//')"
check_match "the record carries the parent from the meta file" '"id":"bk","parent":"a1"' "$(tail -1 "$JSONL")"
check_match "the record carries the plan" '"plan":"docs/7-add-widget/module-a/plan.md"' "$(tail -1 "$JSONL")"

agent ws
rec sess-1 ws tdd-unit-green-phase-step
check_match "a backslash plan path records the plan" '"id":"ws".*"plan":"docs/7-add-widget/module-a/plan.md"' "$(tail -1 "$JSONL")"

agent rs
rec sess-1 rs tdd-system-red-phase-step
check_match "a resumed agent records its wall time and its active time" '"seconds":1320,"active":240,' "$(tail -1 "$JSONL")"
check_match "and its idle window, from its last turn to the resume"   '"idle":\[\["2026-09-08T14:12:00.000Z","2026-09-08T14:30:00.000Z"\]\]' "$(tail -1 "$JSONL")"

agent gr
rec sess-1 gr grill-design
check_match "a bare task directory files without a plan" '"id":"gr".*"agent":"grill-design"' "$(tail -1 "$JSONL")"
check_no_match "a bare task directory record has no plan" '"id":"gr".*"plan":' "$(tail -1 "$JSONL")"

n0=$(lines)
agent np
rec sess-1 np tdd-unit-red-phase-step
check "a prompt naming a task the tree does not hold records nothing" "$n0" "$(lines)"
check "and creates no directory" "7-add-widget" "$(ls docs | tr '\n' ' ' | sed 's/ $//')"

mkdir -p docs/3-old-task
n0=$(lines)
agent ex
rec sess-1 ex tdd-unit-red-phase-step
check "the mapped task wins over another task's plan cited first" $((n0 + 1)) "$(lines)"
check "the other task gets no review directory" no "$([ -d docs/3-old-task/review ] && echo yes || echo no)"
agent ot
rec sess-1 ot tdd-unit-red-phase-step
check "only another task's plan path files there" written \
  "$([ -f docs/3-old-task/review/cost.jsonl ] && echo written || echo none)"
rm -rf docs/3-old-task
n0=$(lines)
agent es
rec "" es tdd-unit-red-phase-step
check "an empty session id records nothing" "$n0" "$(lines)"

# --- the report: a golden rendering of a known set of records, priced by the fixture's own rates
# table, seeded into the cache as fetched today so nothing is fetched and the bundled table is not read.
records orph p2 self tiny gap
mapping
mkdir -p "$XDG_CACHE_HOME/tdd-sdlc"
jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.fetched = $now | .fetch_failed = null' \
  "$FX/pricing.json" > "$XDG_CACHE_HOME/tdd-sdlc/pricing.json"
check_match "a fresh cache holding every model is not fetched again" "^Rates: fetched $(date -u +%Y-%m-%d)\.$" "$(report_offline)"
# Three values carry the moment of the run and are replaced before the comparison: the task total
# span's length and end, which runs to now while the task is open, though its start stands; the rates
# line's date; the written-at line's timestamp. Only the timestamp goes: the offset named beside it is
# the one the records carry, not the machine's, so it stands and the golden pins it.
sed -E 's/^(\| \$[0-9.]+\*? \| )[^(]*\(15:40 → [0-9:]+\) \|$/\1<dur> (15:40 → <now>) |/
        s/^Rates: fetched .*/Rates: fetched <date>./
        s/^(Written by .* at )[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]+ \(/\1<clock> (/' "$MD" > "$WORK/cost.md"
check_golden "the report matches the golden rendering" "$FX/cost.golden.md" "$WORK/cost.md"
check_match "an orphan parent renders as a row one level in" \
  '^  tdd-refactor-phase +16:30 +16:30 ' "$(cat "$MD")"
check_match "a self parent renders as a row one level in" \
  '^  tdd-system-red-phase-step +16:22 +16:23 ' "$(cat "$MD")"
check_match "a second pipeline on the same plan gets its own timeline" '^module-a/plan.md \(2\)$' "$(cat "$MD")"
check_match "a resumed agent's bar shows its idle window and its time is the active part"   '^  tdd-system-red-phase-step +16:10 +16:32 +·██(░){18}██·· +4m ' "$(cat "$MD")"
check_match "the type row's time is the running time, an idle window left out"   '^\| tdd-system-red-phase-step \| 2 \| .* \| 5m \| ' "$(cat "$MD")"
check_match "a group of two legacy lines with a gap between them draws the gap and sums the two"   '^  tdd-integration-red-phase-step ×2 +16:20 +16:32 .*██(░){8}██.* +4m ' "$(cat "$MD")"
check_match "a 40-second agent is shown in seconds" '`module-b/plan.md` \| 1 \| \$[0-9.]* \| 40s' "$(cat "$MD")"
check_match "the task total is not starred when every agent is priced" '^\| \$[0-9.]+ \| [0-9]+m \(' "$(cat "$MD")"

# --- overview labels stay in the fixed 36-column label field when a module name is long
records long
report_offline > /dev/null
check_match "a long overview label is middle-elided to the fixed 36-column field" \
  '^implement-plan-mo…pplication-backend [0-9]{2}:[0-9]{2}  [0-9]{2}:[0-9]{2} ' "$(cat "$MD")"

# --- the report, offline with no cache: the plugin's own table, saying so
rm -rf "$XDG_CACHE_HOME"
check_match "offline, the rates line names the plugin's table and the curl error" \
  "^Rates: the plugin's table, dated .*\(fetching current rates failed: curl: \(6\)" "$(report_offline)"

# --- the report: a model in no table
records gr2 unk rp ad
report_offline > /dev/null
check_match "a parentless step agent on a plan joins that plan's timeline" \
  '^  tdd-unit-green-phase-step +16:24 +16:25 ' "$(cat "$MD")"
check_no_match "and leaves the overview" '^tdd-unit-green-phase-step ' "$(cat "$MD")"
check_match "a parentless review agent on a plan stays in the overview" '^review-plan module-a +16:24 +16:26 ' "$(cat "$MD")"
check_no_match "and is not adopted into the plan's timeline" '^  review-plan' "$(cat "$MD")"
check_match "a row mixing a priced and an unpriced agent is starred" \
  '^\| grill-design \| 3 \| \$[0-9.]+\* \| [0-9]+% \| \$[0-9.]+\* ' "$(cat "$MD")"
check_match "the task total is starred" '^\| \$[0-9.]+\* \| ' "$(cat "$MD")"
check_match "the footnote names the unpriced model" '^\* excludes 1 unpriced agent \(claude-x\)$' "$(cat "$MD")"

# --- the rates cache: when a fetch is tried again
cache="$XDG_CACHE_HOME/tdd-sdlc/pricing.json"
check "a failed fetch is stamped in the cache" "1" "$(jq -r 'if .fetch_failed then 1 else 0 end' "$cache")"
jq --arg f 2026-08-01T00:00:00Z '.fetched = $f | .fetch_failed = null' "$cache" > "$cache.t" && mv "$cache.t" "$cache"
# The rates line reads the same whether a fetch was tried or held back, so the fake's call log is what
# tells the two apart.
n0="$(calls_n)"
check_match "a stale cache is retried, fails, and stands, saying so" \
  '^Rates: cached copy from 2026-08-01 \(fetching current rates failed: curl' "$(report_offline)"
check "the stale cache was in fact retried, once" $((n0 + 1)) "$(calls_n)"
check_match "a failure within a day leaves the same line" \
  '^Rates: cached copy from 2026-08-01 \(fetching current rates failed: curl' "$(report_offline)"
check "and that failure is not retried" $((n0 + 1)) "$(calls_n)"
jq --arg f "2026-08-01T00:00:00Z old failure" '.fetched = null | .fetch_failed = $f' "$cache" > "$cache.t" && mv "$cache.t" "$cache"
before="$(jq -r '.fetch_failed' "$cache")"
report_offline > /dev/null
check_no_match "a cache that only ever failed, 40 days old, is retried" "^$before\$" "$(jq -r '.fetch_failed' "$cache")"

# --- a fetch that succeeds: the two pages come from the fixture, so the network is never asked.
# The fetch is made once and not again the same day.
rm -rf "$XDG_CACHE_HOME"; : > "$COST_FAKE_CALLS"
one="$(report_fetching)"
stamp1="$(jq -r '.fetched // .fetch_failed' "$cache")"
calls1="$(sed 's@.*/@@' "$COST_FAKE_CALLS" | tr '\n' ' ')"
two="$(report_fetching)"
stamp2="$(jq -r '.fetched // .fetch_failed' "$cache")"
check "the rates line says fetched today" "Rates: fetched $(date -u +%Y-%m-%d)." "$one"
check "the fetch read the fixture's pages, never the network" "pricing.md overview.md " "$calls1"
check "a second run the same day does not fetch again" "$stamp1" "$stamp2"
check "and asks for no page the second time" "$calls1" "$(sed 's@.*/@@' "$COST_FAKE_CALLS" | tr '\n' ' ')"
check "and prints the same rates line" "$one" "$two"
check_match "an unknown model is recorded as missing" '"missing"' "$(jq -c '.models["claude-x"]' "$cache")"

finish
