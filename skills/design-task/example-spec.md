# Example Spec — Worked Example

This is a complete worked example of a spec produced by the `design-task` skill — in a real repo this file would
live at `docs/1-add-widget/spec.md`, beside the `design.md` that says how it is built, the `design-log.md` the
grill fills, and the `plan.md` written from all three. It is illustrated with a `Widget` feature purely for
concreteness. What transfers is the structure: the sections, their order, and the entry formats.

**The spec is the page the user signs.** What the change promises, the behaviour that proves each promise, and
the calls the user made. No table, no endpoint, no diagram — those are [`example-design.md`](example-design.md).
Every reason behind a decision is [`example-design-log.md`](example-design-log.md), under the same number.

**Decisions is short on purpose.** Three entries, because three questions needed the user. Each is the question,
the answer and who chose. An entry still awaiting the user has the same three lines with an empty `Answer:` and a
`Basis: must-decide — [what the repository does not say]`; **D7** shows what one looks like once it has been
answered.

---

# Spec: Add Widget Creation

## Objective

Allow API clients to create widgets. A widget has a name and a value; it is validated, persisted, and returned
with its generated id. It belongs to a parent resource, which must exist.

## Requirements

- **R1:** A client can create a widget under an existing parent and gets it back with its id.
- **R2:** A widget's name is unique under its parent.
- **R3:** A request the service cannot honour is refused with a status that says why, and nothing is stored.

## Acceptance Scenarios

One per branch of the design's flow diagram; one entry point. Each names the requirement it proves.

- **A1:** a widget is created
  - Given: a parent exists, and it has no widget named `left-rail`
  - When: the caller posts `parentId`, `name: left-rail` and a value
  - Then: the response is 200 with the new widget and its generated id, and the widget is stored under that parent
  - Proves: R1

- **A2:** a required field is missing
  - Given: a parent exists
  - When: the caller posts a blank `name`
  - Then: the response is 400 naming `name`, and nothing is stored
  - Proves: R3

- **A3:** the parent does not exist
  - Given: no parent with the posted `parentId`
  - When: the caller posts an otherwise valid widget
  - Then: the response is 404, and nothing is stored
  - Proves: R3

- **A4:** the name is already used under that parent
  - Given: the parent already has a widget named `left-rail`
  - When: the caller posts a second widget named `left-rail` under it
  - Then: the response is 409, and the first widget is unchanged
  - Proves: R2, R3

- **A5:** the store is unavailable
  - Given: a parent exists, and the store refuses writes
  - When: the caller posts a valid widget
  - Then: the response is 503, and the caller can retry the same request
  - Proves: R3

## Decisions

The user's calls, and the ones still waiting for them. Question, answer, who chose and when. Why — the alternative
and the files — is the log's **Decision Bases**, under the same number.

- **D1:** Must a widget's name be unique, and what does a duplicate return?
  - Answer: Unique per parent. A duplicate returns 409.
  - Basis: decided (user, 2026-07-30)

- **D4:** What happens when the same widget is created twice concurrently?
  - Answer: One request wins with 200; the other returns the same 409 a sequential duplicate returns.
  - Basis: decided (user, 2026-07-30)

- **D7:** Who may create a widget under a given parent?
  - Answer: Any authenticated caller. The endpoint does not check that the caller owns the parent.
  - Basis: decided (user, 2026-07-30)

Three entries, numbered D1, D4 and D7. The gaps are the questions that turned out to be Findings rows — a number is
assigned once and never reused, so a spec's entries are rarely consecutive.
