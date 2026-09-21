# Example Design — Worked Example

The design beside [`example-spec.md`](example-spec.md) — in a real repo `docs/1-add-widget/design.md`. The spec
says what is promised; this says how it is built, at one level above the code. The schema format and the failure
vocabulary are whatever the module's `docs/conventions.md` records (see `templates/conventions/`). What transfers
is the structure, the section order and [`stack-neutral-design.md`](../../templates/stack-neutral-design.md).
Source-backed reasoning appears in [`example-design-log.md`](example-design-log.md). Implementation placement
appears in [`templates/example-plan.md`](../../templates/example-plan.md).

---

# Design: Add Widget Creation

**Affected Modules:** `module-a`

## Proposed Solution

`POST /widgets` joins the module's API contract, taking a `CreateWidgetRequest` — `name` and `value`, both
required — and answering a `Widget` with its generated id. A widget belongs to a parent, named by `parentId`.

### Diagrams

`module-a`'s conventions name no diagram language, so these use the assumed default. There is no component
diagram: classes belong to the plan.

```plantuml
@startuml
' Uses PlantUML's bundled C4-PlantUML stdlib (angle-bracket include — no network fetch, no relative file
' path, resolved the same way regardless of where this diagram is rendered from). If a renderer's PlantUML
' version doesn't have the C4 stdlib bundled, fall back to:
' !include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml
!include <C4/C4_Container>

Person(client, "Client", "Creates widgets under a parent")
Container(moduleA, "module-a", "the service", "Owns widgets and the parents they hang from")
ContainerDb(db, "the store", "PostgreSQL", "Holds the widget table and its unique index")

Rel(client, moduleA, "POST /widgets", "HTTPS / JSON")
Rel(moduleA, db, "inserts a widget row, rejected on a duplicate name", "JDBC")
@enduml
```

**Affected Modules** lists one module, so nothing crosses between two. The diagram still answers what this change
reaches outside the module — the caller and the store — which is where every failure mode in the log's Concerns
comes from.

```plantuml
@startuml
actor Client
participant "the endpoint" as API
participant "create a widget" as Create
participant "the widget store" as Store

Client -> API : POST /widgets
API -> Create : the request

alt invalid request
    Create --> API : rejected, naming the field at fault
    API --> Client : 400 Bad Request
else unknown parent id
    Create -> Store : save
    Store --> Create : no such parent
    API --> Client : 404 Not Found
else duplicate name under that parent
    Create -> Store : save
    Store --> Create : already used
    API --> Client : 409 Conflict
else the store is unavailable
    Create -> Store : save
    Store --> Create : write failed
    API --> Client : 503 Service Unavailable
else happy path
    Create -> Store : save
    Store --> Create : the stored widget
    Create --> API : the widget
    API --> Client : 200 OK, with its id
end
@enduml
```

Five branches, five scenarios: AC01 to AC05 in the spec.

### Details

What the diagrams cannot hold: a field, an invariant, a status, the schema.

| A widget holds | Refuses                                      |
|----------------|----------------------------------------------|
| `parentId`     | a parent that does not exist                 |
| `name`         | blank, or already used under the same parent |
| `value`        | over 255 characters                          |

| The caller gets | When                        |
|-----------------|-----------------------------|
| 400             | a field is missing or blank |
| 404             | the `parentId` is unknown   |
| 409             | the name is already used    |
| 503             | the write failed            |

The `widget` table is created by a migration:

```sql
CREATE TABLE widget (
    id        BIGSERIAL PRIMARY KEY,
    parent_id BIGINT       NOT NULL REFERENCES parent (id) ON DELETE CASCADE,
    name      VARCHAR(255) NOT NULL,
    value     VARCHAR(255) NOT NULL
);

CREATE UNIQUE INDEX idx_widget_parent_name ON widget (parent_id, name);
```

The unique index is what enforces RQ02 and decides the concurrent case — DN04, one request wins — so the guarantee
holds across two service instances.
