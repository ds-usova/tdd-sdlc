# The closing report

What a finished rework tells the user, once phase 4 is done. The logs' Run Logs are its source: every line below
that names a step's deviation is a `B` entry there first.

- **What is left where this rework came from**, in one line: `<that file> — 1 of 4 open (R1)`. It costs one read
  of that file. A stale line here binds nothing.
- Each step, its kind, and the files it touched.
- **The mutation results of every step that ran one** — what was broken, and which test or check caught it. A
  target that stayed green under mutation is a finding, not a footnote, and has its `B` entry. A `pin` that only
  dropped something ran none, and says so.
- **Every hunk an `inline` or `tests` step made to a test file**, so a mechanical change that was really an
  assertion change is visible, and so is an assertion a `tests` step quietly dropped while the scenario name
  survived.
- Steps re-classified or abandoned, and why — the `abandoned — <why>` headers and their `B` entries.
- Defects found and not fixed — each a `B` entry.
- **Every `B` entry still without a `Resolved:`**, and what it waits on.
- **What the conventions' finished-work list did**, per entry — the pages rewritten from the `docs:` lines, and
  any page a step named that the pass left alone.
