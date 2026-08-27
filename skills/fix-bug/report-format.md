# The closing report

What a finished fix tells the user. Short: the files hold the detail, and the report points at them rather than
restating them.

- **Verdict in one line** — fixed and archived, or what is still open and where.
- **The symptom no longer reproduces**: the command from `## How it reproduces`, and one line on what it produces
  now.
- **Where to read more** — the path of `bug.md`, and one line per module: steps landed out of steps written, and
  the attempts its log holds, as `fix.sh attempts` prints them.
- **What a reader would not expect from the files** — a struck or re-classified step, an effect no revert undid,
  a defect found and not fixed, a guardrail that failed, a manual check the suite cannot cover — each pointing at
  the `B` entry that records it. Nothing here means the line is left out.
- **What the conventions' finished-work list did**, one line per entry.

**A fix abandoned entirely** says what was reverted, what would not revert, and points at the logs — the
Attempts for what is ruled out, `bug-log.md`'s Run Log for the decision and what the revert left.
