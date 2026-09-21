# Design: Add Widget Creation


## Implementation Notes

| Note                | File         |
|---------------------|--------------|
| Implementation note | `widget.cpp` |

## Proposed Solution

`POST /widgets` joins the module's API contract.

#### Details

| The caller gets | When                     |
|-----------------|--------------------------|
| 409             | the name is already used |
