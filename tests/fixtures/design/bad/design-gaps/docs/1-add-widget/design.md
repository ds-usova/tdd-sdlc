# Design: Add Widget Creation


## Context

| What exists         | Where                   | What this change does with it |
|---------------------|-------------------------|-------------------------------|
| The parent resource | `<parent-usecase-file>` | Mirrored throughout           |

## Proposed Solution

`POST /widgets` is handled by `WidgetController.java`.

#### Details

| The caller gets | When                     |
|-----------------|--------------------------|
| 409             | the name is already used |
