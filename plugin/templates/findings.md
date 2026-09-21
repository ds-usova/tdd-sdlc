# A findings file

What a finished piece of work found on the way and leaves open, written into its own `review/findings.md`. The
skill that writes one says which sections its own kind of work may fill.

Create and update this file with the [findings writer](../scripts/findings/README.md). If it cannot run, follow
the fallback in [`scripts/README.md`](../scripts/README.md).

```
# Review: <name>

**<the counts by section, or that nothing is open>**

## Critical
```

**The first line is the whole file when the work is clean**: `**Nothing open.** <one clause>`. The file is
written either way.

Sections are these five, in this order, and a section with nothing in it is left out:

| Section                   | Holds                                             | Shape                                           |
|---------------------------|---------------------------------------------------|-------------------------------------------------|
| **Critical**              | a risk that grows with every task landed on top   | one block per entry, in the form below          |
| **Bug**                   | real, reproduced, and it can wait                 | one block per defect, in the form below         |
| **Refactoring candidate** | nothing behaves wrong, and nothing should change  | # · Status · module · what · why                |
| **Deferred change**       | nothing is wrong, but the behaviour should differ | # · Status · module · what · why                |
| **Performance**           | a measured figure past its threshold              | # · Status · module · test · threshold · figure |

A check a person still has to make is not a finding. It is a **Manual checks** block in the report
([`report.md`](report.md)).

**Who may file what.**

- A bug: any agent, once it is reproduced.
- A refactoring candidate: the refactor pass, which read the whole diff, or the user. Never a step agent.
- A deferred change: the run, or a decision the user made mid-run.
- A performance row: the run, from the figures its pipelines or module agents measured, and nothing else.
- A critical entry: whoever measured it.

**A candidate, a deferred change and a performance row are numbered and carry a status.** `#` is `RX01` upward
for a candidate, `DX01` upward for a deferred change and `PX01` upward for a performance row, assigned once and
never reused.
`Status` is `open`, `done · <the rework or task that closed it>`, `done · directly` where it was taken without
one, `withdrawn · <what the measurement found>` where a later reading showed the entry did not hold, or
`wontfix · <why>` where the entry holds and the user decided against it. A `wontfix` closes the entry. Its
backlog row is removed like any other closed row. The opening count line says how many are still open; a status
changed after the file was written re-emits it.

**A refactoring candidate is a defect nobody sees yet, or the author's own deferral — never something the run
merely noticed.** An asymmetry, a naming quibble, a test that could exist, a case the current schema or
configuration makes unreachable: none of them is a row. Before writing one, ask what breaks and who notices.
**A file holding no candidates is the normal result.**

**A deferred change is work the design did not ask for and the code should do anyway** — a validation the
endpoint should also apply, a state the page should also show, a message a consumer should also handle. It
changes behaviour, so a rework may not do it; it becomes a task of its own through `design-task`. The test
between the two tables is the suite: a candidate leaves every test's assertion as it is, a deferred change adds
or alters one. A row that is really a request the run merely thought of belongs in neither table.

**A performance row is a figure past its threshold**, and nothing else: the test, the threshold it carries and
the figure the run measured — the same figure the report's **Measured** table shows. No *why*. It is closed by
the run that measures the test under its threshold, which sets `done · <that run> <n>` — `done · task 9`,
`done · fix 4` — as [`backlog.md`](backlog.md) says.

**A bug is filed only once it is reproduced as a disabled test**, the way [`reproducing.md`](reproducing.md)
says. The block names that test. A defect nobody could reproduce is not a block.

```
**`<module>` — <the symptom, in one line>**

- **Given** <the state the system is in>
- **When** <what happens>
- **Then** <what should follow>
- **Actual** <what follows instead>
- **Test** `<TestClass#method>`, disabled
- **Fix** <the proposal> · `<class or file>`
```

**A critical entry is a bug, a deferred change or a refactoring candidate whose cost grows with every task
landed on top** — duplicated data, a contract two modules read differently, an invariant nothing enforces, one
block copied into ten files and this task added to all ten. It is the one place a refactoring candidate may
carry a severity. The block:

```
**`<module>` — <the risk, in one line>**

- **Kind** bug | deferred change | refactoring candidate
- **Measured** <what was counted, over what — "11 tables hold `customer_name`; 3 spellings">
- **Grows because** <what every task landed on top adds>
- **Breaks as** <what a person will hit, and when>
- **Test** `<TestClass#method>`, disabled — only where Kind is bug
- **Fix** <the proposal> · `<class or file>`
```

A critical entry is closed like a bug block: a `Status` line after `Fix`. Its backlog row is a `BC`.

**A defect block that is closed gains one line after `Fix`** — `- **Status** done · <the fix>`, or
`withdrawn · <what the measurement found>` where a later reading showed the defect did not hold. A block without
one is open. A bug is never numbered.

**In scope but unplanned is not a finding.** Where a requirement of this task covers it, it goes back into
the plan (`implement-plan-module`, **A scope gap is not a finding**). Only what no requirement covers is filed here.

**Four of those lines are observations; `Fix` is not.** `Given`, `When`, `Then` and `Actual` are what the run
saw. The fix is a proposal. Where this run did not exercise the mechanism behind it, the line says `unverified`
— the file-side form of a report's hypothesis, [`sub-agents.md`](sub-agents.md)'s **Reporting back**.

**The module comes first** — in a defect's heading and in the first cell of a table row,
unless every entry in the section shares one module, which the section's opening line then names. Nothing is
*grouped* by module.

**Write what a person hits, not the mechanism.** The class is the last thing on the line, never the sentence.

## Measured, Not Noticed

**A report's closing observation is a hypothesis, and nothing is filed as a hypothesis.** What a step agent, a
refactor pass or a review offers beyond what it actually ran — a gap it noticed, a class of case it suspects, an
inconsistency it saw in passing — is a hypothesis.

**Measure it before it becomes an entry, in one pass over the whole class the claim generalizes over**: "three
entries are missing a terminator" is answered by reading all seventy-nine, not by re-reading the three. What the
measurement contradicts is not filed; what it narrows is filed in the narrowed form.

**The entry names its measurement.** In a defect block, `Given`/`When`/`Then`/`Actual` already are it. In an `RX`
or a `DX` row the *why* carries it — `all 79 explanations end in a full stop; the 3 with an inner terminator hold
it inside the quoted example` — what was counted and over what, rather than what somebody noticed.

**A hypothesis nobody can settle in one pass is reported, not filed.** It stays where the run recorded it — the
plan or steps log's Run Log — and the closing report tells the user it is unmeasured and what would settle it.
It never reaches `docs/backlog.md`.
