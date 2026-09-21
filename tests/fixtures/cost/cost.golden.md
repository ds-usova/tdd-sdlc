# Cost · 7-add-widget

Written by `scripts/cost/cost.sh report` at <clock> (UTC+02:00, the latest record's offset).
Re-run the script rather than edit this file.
Rates: fetched <date>.
1 line recorded before the format change is skipped.

## Cost

| agent | n | $ | % | read $ | write $ | out $ | time | model |
|-------|---|---|---|--------|---------|-------|------|-------|
| session (own turns) | 1 | $1.54 | 23% | $0.12 | $1.29 | $0.12 | 60m | claude-fable-5-1, claude-opus-5 |
| grill-design | 1 | $0.00 | 0% | $0.00 | $0.00 | $0.00 | 7m | claude-opus-5 |
| review-plan | 1 | $0.33 | 5% | $0.05 | $0.07 | $0.21 | 6m | claude-sonnet-5 |
| implement-plan-module | 3 | $4.84 | 71% | $2.89 | $0.57 | $1.38 | 30m | claude-opus-5 |
| tdd-system-red-phase-step | 2 | $0.00 | 0% | $0.00 | $0.00 | $0.00 | 5m | claude-opus-5 |
| tdd-unit-red-phase-step | 3 | $0.12 | 2% | $0.01 | $0.03 | $0.08 | 4m | claude-haiku-4-5-20251001 |
| tdd-unit-green-phase-step | 2 | $0.00 | 0% | $0.00 | $0.00 | $0.00 | 1m | claude-haiku-4-5-20251001 |
| tdd-integration-red-phase-step | 2 | $0.00 | 0% | $0.00 | $0.00 | $0.00 | 4m | claude-opus-5 |
| tdd-refactor-phase | 1 | $0.00 | 0% | $0.00 | $0.00 | $0.00 | 20s | claude-opus-5 |

- `$`: what the run would cost at API rates. On a subscription plan it is not a bill.
- `read $`: cache reads at the read multiplier (a tenth of the input rate, or less on some models),
  plus input at the input rate.
- `write $`: cache writes at 1.25× the input rate for the 5-minute TTL and 2× for the 1-hour one.
- `out $`: output at the output rate.
- `%`: the share of the task's total.
- `—`: a row priced nowhere. `*`: a sum that leaves out an unpriced agent.

## Volume

| agent | turns | input | output | cache write | cache read | peak ctx | of window |
|-------|-------|-------|--------|-------------|------------|----------|-----------|
| session (own turns) | 4 | 3k | 3k | 75k | 330k | 151k | 15% |
| grill-design | 1 | 100 | 5 | 0 | 0 | 100 | 0% |
| review-plan | 2 | 200 | 21k | 30k | 224k | 130k | 13% |
| implement-plan-module | 4 | 510k | 55k | 80k | 680k | 500k | 50% |
| tdd-system-red-phase-step | 4 | 72 | 30 | 0 | 0 | 42 | 0% |
| tdd-unit-red-phase-step | 6 | 167 | 15k | 23k | 133k | 34k | 17% |
| tdd-unit-green-phase-step | 2 | 20 | 20 | 0 | 0 | 10 | 0% |
| tdd-integration-red-phase-step | 2 | 20 | 0 | 0 | 0 | 10 | 0% |
| tdd-refactor-phase | 1 | 100 | 0 | 0 | 0 | 100 | 0% |

- `cache read`: the conversation prefix, re-read from cache on each turn, not new tokens. It grows
  with roughly the square of the turn count.
- `peak ctx`: the largest one message's input + cache write + cache read, the most context the
  agent carried at once. A type's is its largest agent's.
- `of window`: `peak ctx` against the model's context window.

| plan | agents | $ | time |
|------|--------|---|------|
| `module-a/plan.md` | 12 | $4.91 | 30m |
| `module-b/plan.md` | 1 | $0.04 | 40s |

## Task total

| $ | span |
|---|------|
| $6.82 | <dur> (15:40 → <now>) |
