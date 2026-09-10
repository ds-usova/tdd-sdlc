# Design: Add Widget Creation

**Affected Modules:** `module-a`

## Context

| What exists         | Where                   | What this change does with it |
|---------------------|-------------------------|-------------------------------|
| The parent resource | `<parent-usecase-file>` | Mirrored throughout           |

## Proposed Solution

`POST /widgets` joins the module's API contract.

#### Details

| The caller gets | When                     |
|-----------------|--------------------------|
| 409             | the name is already used |
