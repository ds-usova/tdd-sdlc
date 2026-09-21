# Design: Add Widget Creation

**Affected Modules:** `module-a`

## Proposed Solution

`POST /widgets` joins the module's API contract.

#### Details

| The caller gets | When                     |
|-----------------|--------------------------|
| 409             | the name is already used |
