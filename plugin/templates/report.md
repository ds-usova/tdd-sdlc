# A task report

What a finished piece of work tells the person who opens its directory: what was done, what was measured, what
it cost, what it left open, and what a person still has to look at. Written into its own `review/report.md` by
the skill that finished the work — `implement-plan`, `fix-bug`, `rework`, `upgrade-deps` — always: a clean run
gets one too.

```
# Report: <name>

**<one line: done and archived | done, <n> open>**

## Done

| Plan               | Steps    | Suite                 |
|--------------------|----------|-----------------------|
| `module-a/plan.md` | 24 of 24 | 312 green, 2 skipped  |

Acceptance: 5 of 5 scenarios proved — [acceptance.md](acceptance.md)

## Measured

| Test                   | Threshold                 | Figure | Previous          |
|------------------------|---------------------------|--------|-------------------|
| `CreateWidgetPerfTest` | 300 ms p95 at 50 callers  | 240 ms | —                 |
| `ListWidgetsPerfTest`  | 200 ms p95 at 50 callers  | 310 ms | 180 ms · task 6   |

## Cost

$4.20 · 31 agents · 1 h 12 min — [cost.md](cost.md)

## Open

1 bug, 2 deferred changes — [findings.md](findings.md)

## Manual checks

**[ ] `<module>` — <what this check decides, in one line>**

- **Given** <the state to arrange, and where on screen>
- **When** <what the person does; "it renders" where they only look>
- **Then** <the one thing that must hold>
```

**The report links; it does not restate.** A fact with a home elsewhere — a cost line, a finding, a run-log
entry — appears here as a total, a count or a clause, and a link. The one thing it holds in full is what has no
other file: the measurements and the manual checks.

**Every section is written, and an empty one says so in a line** — `Nothing measured: the conventions say
performance is not measured`, `Nothing open`, `No manual checks`.

- **Done** — what the skill's own files count: a plan's steps landed out of steps written and its module's final
  suite figures; a fix's or a rework's steps per module; an upgrade's survey. One row per plan or module. A
  task adds the acceptance line under the table: how many of the spec's scenarios `acceptance.md` shows
  `covered` or `held`, and the link. A skill that writes no `acceptance.md` writes no line.
- **Measured** — every performance test the work ran: its test, the threshold, the figure it produced, and
  the previous figure with the work that produced it — the `report.md` of the highest-numbered directory
  under `docs/implemented/` whose **Measured** names the test, read rather than remembered; `—` where none
  does. A figure past its threshold is
  also a **Performance** row in `findings.md` ([`findings.md`](findings.md)); here it is the figure, whichever
  side of the line it fell. A rerun that lost against its previous figure gets one clause under the table, and
  nothing more.
- **Cost** — the task's total in dollars, agents and wall time, read off `cost.md`. Where `cost.sh` was refused
  or absent, the line says so.
- **Open** — the count per section of `findings.md`, and the link. Nothing more.
- **Manual checks** — what no test can see, so a person must look. Sources: what an affected module's
  conventions say its finished work leaves for a person to look at, read rather than remembered; a check a
  module agent reported that the suite cannot cover; a bump that changes runtime behaviour no test reaches. The
  block is a defect block without `Actual` and without `Fix`. **`Then` states one observable.** A check that
  needs three is three blocks. The tick rides on the heading. A manual check never blocks archiving and never
  gets a backlog row.

**Write it last, before archiving**, once `findings.md` and `cost.md` exist, so every link and every count is
read off a file. The links are relative and survive the move to `docs/implemented/`.
