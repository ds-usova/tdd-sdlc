# cost fixtures

`tests/cases/cost.sh` runs the two cost hooks and `cost.sh` against these.

- `good/` — copied to `$WORK` and never written to here. `repo/` is made a git repository holding `docs/7-add-widget/` with a `plan.md` and a `review/cost.jsonl` of six records (one in the pre-format shape, which the report skips). `projects/sess-1/` is the session's transcript and the `subagents/` transcripts (`a1`–`a6`) the records came from.
- `pricing.json` — the rates table seeded into the cache, stamped as fetched today, so the golden is priced by it and nothing is fetched.
- `cost.golden.md` — the report rendered from `good/`, the four records the recorder section files there (`bk`, `ws`, `rs`, `gr`, `ex`), and the four `records/` below, with the span's length and end, the rates date and the written-at timestamp replaced by placeholders. Two things beside them stand, because neither comes from the run: the span's start, which comes from the mapping, and the offset named after the timestamp, which comes from the records. `UPDATE_GOLDEN=1` rewrites it.
- `fakebin/curl` — put first on `PATH` to render offline; fails the way an unresolved host does, so the rates line names the plugin's table and the curl error. It appends each URL asked for to `$COST_FAKE_CALLS` before failing, so the case can tell a fetch that was tried and failed from one that was held back.
- `fakebin-ok/curl` — put first on `PATH` to render a successful fetch without the network: it answers the two URLs `cost.sh` fetches from `pages/`, and appends each URL asked for to `$COST_FAKE_CALLS`, so the case can see that a fetch happened once and not twice.
- `pages/` — verbatim copies of the two pages `cost.sh` fetches, `pricing.md` and `models.md`, saved once with the real curl. They are kept whole: the parser decides which page is which from the tables it finds, so a trimmed page would be a different test. 62 KB together.

## agents/

Each `<id>.jsonl` is one agent transcript the recorder hook is fed, copied to `subagents/agent-<id>.jsonl`; an `<id>.meta.json` beside it goes with it. All but `rs` are a user prompt and one assistant turn; the prompt is what varies.

| File              | What the case shows                                                                          | Check that reads it                                                        |
|-------------------|----------------------------------------------------------------------------------------------|----------------------------------------------------------------------------|
| `bk.jsonl`, `.meta.json` | the prompt cites another task's findings before its own plan; the meta file names parent `a1` | "a prompt citing another task before its own plan files under its own", "the record carries the parent from the meta file", "the record carries the plan" |
| `ws.jsonl`, `.meta.json` | the prompt names the plan by an absolute Windows path, backslashes and all; parent `a1`  | "a backslash plan path records the plan"                                   |
| `gr.jsonl`, `.meta.json` | the prompt names the task directory and no plan                                        | "a bare task directory files without a plan", "a bare task directory record has no plan" |
| `rs.jsonl`, `.meta.json` | a step under `a1` that stopped at 14:12, was resumed by a string `user` line at 14:30 and stopped again at 14:32; not one turn, but three | "a resumed agent records its wall time and its active time", "and its idle window", "a resumed agent's bar shows its idle window", "the type row's time is the running time" |
| `np.jsonl`        | the prompt names `docs/99-nope`, a task the tree does not hold                               | "a prompt naming a task the tree does not hold records nothing", "and creates no directory" |
| `ex.jsonl`        | another task's plan is cited first, the mapped task's plan second                            | "the mapped task wins over another task's plan cited first", "the other task gets no review directory" |
| `ot.jsonl`        | only another task's plan (`docs/3-old-task`) is cited                                        | "only another task's plan path files there"                                |
| `es.jsonl`        | a plain plan path, recorded with an empty session id                                         | "an empty session id records nothing"                                      |

## records/

Each `<name>.jsonl` is one cost record the case appends to `review/cost.jsonl` before rendering.

| File          | What the case shows                                                                    | Check that reads it                                                   |
|---------------|----------------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| `orph.jsonl`  | a parent id (`nosuch`) that no record carries                                          | "an orphan parent renders as its own row"                             |
| `self.jsonl`  | a record naming itself as parent                                                       | "a self parent renders as its own row"                                |
| `p2.jsonl`    | a second `implement-plan-module` on `module-a/plan.md`, after the first ended          | "a second pipeline on the same plan gets its own timeline"            |
| `tiny.jsonl`  | a 40-second agent on `module-b/plan.md`                                                | "a 40-second agent is shown in seconds"                               |
| `gap.jsonl`   | two agents of one type under `a1`, without `active` or `idle`, eight minutes apart      | "a group of two legacy lines with a gap between them draws the gap and sums the two" |
| `gr2.jsonl`   | a second `grill-design`, priced, so the row mixes priced and unpriced                  | "a row mixing a priced and an unpriced agent is starred"              |
| `rp.jsonl`    | a parentless `review-plan` on `module-a/plan.md`                                       | "a parentless review agent on a plan stays in the overview", "and is not adopted into the plan's timeline" |
| `ad.jsonl`    | a parentless `tdd-unit-green-phase-step` on `module-a/plan.md`                         | "a parentless step agent on a plan joins that plan's timeline", "and leaves the overview" |
| `unk.jsonl`   | a `grill-design` on `claude-x`, a model in no rates table                              | "the task total is starred", "the footnote names the unpriced model", "an unknown model is recorded as missing" |

The first five are in the golden; the last four are appended after it is checked.
