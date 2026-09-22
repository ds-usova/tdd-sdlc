# Design Log: Add Widget Creation

## Concerns

Grilled (2026-07-30): grill-design.

| Concern             | Verdict                    | Why                                 |
|---------------------|----------------------------|-------------------------------------|
| Failure modes       | 503, nothing persisted     | a single-row insert (DF01)          |
| Idempotency & retry | a retry answers 409        | the name is the natural key         |
| Concurrency         | the unique index decides   | DN04                                |
| Recovery            | nothing to recover         | one write, one store                |
| Data                | `name` bounded at 255      | the schema and the column agree     |
| Contract compat     | additive                   | one new path                        |
| Lifecycle           | deleted with its parent    | `ON DELETE CASCADE`                 |
| Authorization       | any authenticated caller   | no per-resource ownership model     |
| Observability       | the id and name at INFO    | `module-a/docs/conventions.md`      |
| Limits              | no paging                  | one person's tree                   |
| Business invariants | one name per parent        | DN01                                |
| Stack-neutral       | pass                       | the API artifact names no source file |

## Findings

| #    | Question                     | Answer                 | Evidence                |
|------|------------------------------|------------------------|-------------------------|
| DF01 | Store unavailable mid-write? | 503, nothing persisted | `<parent-adapter-file>` |
| DF02 | Parent id unknown?           | 404, by the foreign key | `<parent-usecase-file>` |

## Decision Bases

- **DN01:** The user chose unique-per-parent over globally unique.
- **DN04:** The user chose the unique index over a check-then-insert.
