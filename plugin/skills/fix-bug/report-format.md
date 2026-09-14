# The closing report

What a finished fix tells the user. Point at the files; restate nothing they hold.

- **Every log's Caveats first**, as [`scripts/README.md`](../../scripts/README.md)'s **The log keeps the
  record** says. Nothing when no log has the section.
- **Verdict in one line** — fixed and archived, or what is still open and where.
- **The symptom no longer reproduces**: the command from `## How it reproduces`, and one line on what it produces
  now.
- **Where to read more** — the path of `review/report.md`, then `bug.md`, and one line per module: steps landed
  out of steps written, and the attempts its log holds, as `fix.sh attempts` prints them.
- **What a reader would not expect from the files** — a struck or re-classified step, an effect no revert undid,
  a defect found and not fixed, a guardrail that failed, a manual check the suite cannot cover — each pointing at
  the `RL` entry that records it. Nothing here means the line is left out.
- **What was filed**: each backlog row by id and one clause, as [`backlog.md`](../../templates/backlog.md)'s
  **a record, not an offer** says.
- **What the conventions' finished-work list did**, one line per entry.

**A fix abandoned entirely** says what was reverted, what would not revert, and points at the logs — the
Attempts for what is ruled out, `bug-log.md`'s Run Log for the decision and what the revert left.
