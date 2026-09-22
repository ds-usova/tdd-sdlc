# REST API Update

| Operation       | Request                         | Response                         |
|-----------------|---------------------------------|----------------------------------|
| `POST /widgets` | `parentId`, `name`, `value`      | 200 with the widget and its id   |

| Status | When                              |
|--------|-----------------------------------|
| 400    | a required field is missing      |
| 404    | the parent does not exist         |
| 409    | the name is used under the parent |
| 503    | the store is unavailable          |
