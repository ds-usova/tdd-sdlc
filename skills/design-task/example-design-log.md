# Example Design Log — Worked Example

The log beside [`example-spec.md`](example-spec.md) and [`example-design.md`](example-design.md) — in a real repo
`docs/1-add-widget/design-log.md`. It is the train of thought behind the two: what the grill examined and how each
concern came out, every question the repository answered, and what each decision rested on. Nobody needs it to
build the feature. Anyone asking *why* opens it.

Three sections, in this order, and `design.sh validate` reads all three:

| Section            | Holds                                                                                                 |
|--------------------|-------------------------------------------------------------------------------------------------------|
| **Concerns**       | one row per concern the grill owns — every row, including the ones that came out clear — with its why |
| **Findings**       | the `assumed` and `deferred` questions: asked, answered, evidence a file                              |
| **Decision Bases** | for each `D` in the spec: the alternative, the reasoning, the files                                   |

**A Findings row is a claim, not a hedge.** Its `Evidence` column is a file — the class, the migration, the
conventions page, the ADR. A row with no file to point at is a `must-decide` wearing a disguise, and it will be
found by the grill or, more expensively, in production.

**Reading code this repository does not own is not evidence of what it does at runtime.** Where a question turns
on how a dependency behaves, its source shows what code exists, not what runs. `assumed` is available only when
something in the tree already exercises that path and what it was *observed* to produce is cited. Otherwise the
row is `deferred`, naming what would settle it.

---

# Design Log: Add Widget Creation

## Concerns

Grilled (2026-07-30): grill-design.

| Concern             | Verdict                                           | Why                                                                                        |
|---------------------|---------------------------------------------------|--------------------------------------------------------------------------------------------|
| Failure modes       | 503, nothing persisted                            | a single-row insert leaves no partial state; the parent's adapter classifies the same (F1) |
| Idempotency & retry | a retry after a success answers 409               | the name is the natural key; an idempotency key is deferred (F3)                           |
| Concurrency         | the unique index decides                          | D4 — check-then-insert would not survive a second instance                                 |
| Recovery            | nothing to recover                                | one write, one store, no second effect                                                     |
| Data                | `name` bounded at 255, matched by the column      | `<api-schema-file>` and the migration agree (F6)                                           |
| Contract compat     | additive                                          | one new path, no existing schema touched                                                   |
| Lifecycle           | deleted with its parent                           | `ON DELETE CASCADE` (F7)                                                                   |
| Authorization       | any authenticated caller                          | D7 — the module has no per-resource ownership model                                        |
| Observability       | the id, parent and name at INFO; refusals at WARN | `module-a/docs/conventions.md` (F5)                                                        |
| Limits              | no paging on the widget list                      | one person's tree, bounded by hand (F9)                                                    |
| Business invariants | one name per parent                               | D1, the only rule the user stated                                                          |
| Stack-neutral       | pass                                              | Proposed Solution names a table, a path, four statuses and no file                         |

## Findings

| #  | Question                                     | Answer                                                       | Evidence                                           |
|----|----------------------------------------------|--------------------------------------------------------------|----------------------------------------------------|
| F1 | Store unavailable mid-write?                 | 503, nothing persisted, no partial row                       | `<parent-adapter-file>`, which classifies the same |
| F2 | Parent id unknown?                           | 404, detected by the foreign key rather than a read          | `<parent-usecase-file>`, which answers 404 the same way |
| F3 | A retried create, after the first succeeded? | 409, not the first widget — deferred until a client needs it | an idempotency key, which nothing asks for yet     |
| F4 | The migration meeting existing rows?         | Nothing — it creates the table                               | `<migration-file>`, which has no `widget` history  |
| F5 | What proves a create in production?          | The id, the parent and the name at INFO; refusals at WARN    | `module-a/docs/conventions.md`                     |
| F6 | Is `name` bounded, and where?                | 255, in the schema and matched by the column, so a 400       | `<api-schema-file>`                                |
| F7 | A widget whose parent is deleted?            | Deleted with it                                              | `<migration-file>`, `ON DELETE CASCADE`            |
| F8 | A second create with the same name?          | D4                                                           | `<api-schema-file>`, whose 409 already covers it   |
| F9 | Does the widget list need paging?            | No — one person's tree                                       | `<api-schema-file>`, which has no list endpoint    |

## Decision Bases

- **D1:** The user chose unique-per-parent over globally unique, so two parents can each own a widget called
  "default". The parent resource enforces no name rule at all (`<parent-usecase-file>`), so nothing in the
  repository answered it.
- **D4:** The user chose the unique index over a check-then-insert in the use case, so the guarantee survives a
  second service instance. `<parent-adapter-file>` maps a unique violation to the same conflict type today.
- **D7:** Raised by the grill as `must-decide`: the module has no per-resource ownership model and nothing in
  `<api-schema-file>` implies one. The user confirmed ownership is out of scope until the module has an
  authorization model at all.
