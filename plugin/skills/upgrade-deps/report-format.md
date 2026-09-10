# The closing report

What a finished upgrade tells the user, once phase 4 is done.

- **Every log's Caveats first**, as [`scripts/README.md`](../../scripts/README.md)'s **The log keeps the
  record** says. Nothing when no log has the section.
- **The survey after the run**: every row's `Status`, so what moved and what did not is one table.
- **What listed versions and vulnerabilities**, and where the conventions were silent, what the stack could
  offer — a versions plugin, an audit command, a CVE scanner — as an option, not a recommendation made.
- Each step, its kind, the versions it moved between, and the files it touched.
- **Every kept-back change**, from the logs' Run Log — what the guide asked, what was tried, what would unblock
  it.
- **Every abandoned step**, and the version it left in place.
- **Every vulnerability still open**, and why: not offered, kept back, no fix released.
- **Every deprecation a guide announced that this run left in the code.**
- Every test that asserted the old behaviour, and what the user decided.
- **What was filed**: each backlog row by id and one clause, as [`backlog.md`](../../templates/backlog.md)'s
  **a record, not an offer** says.
- **What the conventions' finished-work list did**, per entry.
