# A findings file

What a finished piece of work leaves open, written into its own `review/findings.md`. A person reading it learns
what they are inheriting without opening a plan or a rework file. The skill that writes one says which sections
its own kind of work may fill.

```
# Review: <name>

**<the counts by section, or that nothing is open>**

## Critical
```

**The first line is the whole file when the work is clean**: `**Nothing open.** <one clause>`. A reader who sees
it stops there. A missing file and clean work must never look the same, which is why the file is written either
way.

Sections are these five, in this order, and a section with nothing in it is left out:

| Section                   | Holds                                             | Shape                                    |
|---------------------------|---------------------------------------------------|------------------------------------------|
| **Critical**              | fix before the next task starts                   | one block per defect, in the form below  |
| **Bug**                   | real, and it can wait                             | one block per defect, in the form below  |
| **Refactoring candidate** | nothing behaves wrong, and nothing should change  | table — # · Status · module · what · why |
| **Deferred change**       | nothing is wrong, but the behaviour should differ | table — # · Status · module · what · why |
| **Manual test**           | what no test can see, so a person must look       | one block per check, in the form below   |

**A candidate and a deferred change are numbered and carry a status**, because they outlive the work that raised
them. `#` is `R1` upward for a candidate and `D1` upward for a deferred change, assigned once and never reused.
`Status` is `open`, `done · <the rework or task that closed it>`, `done · directly` where it was taken without
one, or `withdrawn · <what the measurement found>` where a later reading showed the entry did not hold. The
opening count line says how many are still open, so the first line of the file answers what is left without
reading the table, and a status changed after the file was written re-emits it.

**A refactoring candidate is a defect nobody sees yet, or the author's own deferral — never something the run
merely noticed.** An asymmetry, a naming quibble, a test that could exist, a case the current schema or
configuration makes unreachable: none of them is a row. Before writing one, ask what breaks and who notices.
**A file holding no candidates is the normal result**, and a run that files four has usually confused a list of
observations with a list of work.

**A deferred change is work the design did not ask for and the code should do anyway** — a validation the
endpoint should also apply, a state the page should also show, a message a consumer should also handle. It
changes behaviour, so a rework may not do it; it becomes a task of its own through `design-task`. The test
between the two tables is the suite: a candidate leaves every test's assertion as it is, a deferred change adds
or alters one. A row that is really a request the run merely thought of belongs in neither table.

**A defect is reported as a case, not as a description.** Whoever picks it up reproduces it before fixing it,
and a paragraph about a class does not tell them how:

```
**`<module>` — <the symptom, in one line>**

- **Given** <the state the system is in>
- **When** <what happens>
- **Then** <what should follow>
- **Actual** <what follows instead>
- **Fix** <the proposal> · `<class or file>`
```

**A defect block that is closed gains one line after `Fix`** — `- **Status** done · <the fix>`, or
`withdrawn · <what the measurement found>` where a later reading showed the defect did not hold. A block without
one is open; that is why a bug is never numbered.

**Four of those lines are observations; `Fix` is not.** `Given`, `When`, `Then` and `Actual` are what the run
saw. The fix is a proposal, and whoever picks it up implements it as written — so where this run did not
exercise the mechanism behind it, the line says `unverified` — the file-side form of a report's hypothesis,
[`sub-agents.md`](sub-agents.md)'s **Reporting back**. A design records the same distinction as `Basis:`; a
findings file without it reads a guess and a tested conclusion in one voice.

**A manual check is the same block, minus what has not happened yet.** No `Actual`, since nobody has looked, and
no `Fix`, since nothing is claimed to be wrong:

```
**[ ] `<module>` — <what this check decides, in one line>**

- **Given** <the state to arrange, and where on screen>
- **When** <what the person does; "it renders" where they only look>
- **Then** <the one thing that must hold>
```

**`Then` states one observable.** A check that needs three is three blocks — bundled into one sentence, a person
who sees two of them hold has no way to record the third failing, which is the whole reason the list exists. The
tick rides on the heading, so a half-worked list still says where it stopped.

**The module comes first** — in a defect's heading, in a check's heading, and in the first cell of a table row,
unless every entry in the section shares one module, which the section's opening line then names. Nothing is
*grouped* by module: a reader triages by what an entry costs them, and this tells them where to go once they
have.

**Write what a person hits, not the mechanism.** The class is the last thing on the line, never the sentence.

## Measured, Not Noticed

**A report's closing observation is a hypothesis, and nothing is filed as a hypothesis.** What a step agent, a
refactor pass or a review offers beyond what it actually ran — a gap it noticed, a class of case it suspects, an
inconsistency it saw in passing — records where its attention went, not what it measured. A row nobody re-checks
reads as settled work and survives the archive.

**Measure it before it becomes an entry, in one pass over the whole class the claim generalizes over**: "three
entries are missing a terminator" is answered by reading all seventy-nine, not by re-reading the three. What the
measurement contradicts is not filed; what it narrows is filed in the narrowed form.

**The entry names its measurement.** In a defect block, `Given`/`When`/`Then`/`Actual` already are it. In an `R`
or a `D` row the *why* carries it — `all 79 explanations end in a full stop; the 3 with an inner terminator hold
it inside the quoted example` — what was counted and over what, rather than what somebody noticed.

**A hypothesis nobody can settle in one pass is reported, not filed.** It stays where the run recorded it — the
plan or steps log's Run Log — and the closing report tells the user it is unmeasured and what would settle it.
It never reaches `docs/backlog.md`: a row there claims the work is correct to do.
