# Plan architecture decisions

`## Architecture Decisions` is the plan's review surface for a person. It is not an implementation inventory.

Add one `###` subsection when the plan chooses any of these:

- which architectural boundary owns a new or moved responsibility;
- whether an existing responsibility is split or combined;
- where a new or redirected dependency belongs;
- which of two repository-supported placements is used.

Each subsection contains one diagram and one `**Placement:**` sentence. The diagram shows responsibilities inside
their boundaries and only the new or redirected dependencies. Add an unchanged neighbour only when the placement
cannot be judged without it. Collapse the rest of the system into a boundary, port or external-system box.

Use the module's diagram language. Name boxes by responsibility. A diagram has at most seven boxes and nine arrows.
Split a decision that exceeds either limit.

Do not list every changed class, method or file. Do not add tables. The step map carries implementation targets.

When the plan makes none of these decisions, write exactly:

`No architectural placement decisions.`
