# Spec: Add Widget Creation

**Format:** 2

## Objective

Allow API clients to create widgets.

## Requirements

- **RQ01:** A client can create a widget and gets it back with its id.
- **RQ02:** A widget's name is unique under its parent.
- **RQ03:** A created widget can be read back.

## Acceptance Scenarios

- **AC01:** a widget is created
  - Given: a parent exists
  - When: the caller posts a name and a value
  - Then: the response is 200 with the new widget
  - Proves: RQ01

- **AC02:** the name is already used
  - Given: the parent already has a widget named `left-rail`
  - When: the caller posts a second `left-rail`
  - Then: the response is 409
  - Proves: RQ02

- **AC03:** the name is missing
  - Given: a parent exists
  - When: the caller posts a value and no name
  - Then: the response is 400 with `NAME_REQUIRED`
  - Proves: RQ01

- **AC04:** a created widget is read back
  - Given: a widget was created
  - When: the caller reads it by id
  - Then: the response is 200 with the same name and value
  - Proves: RQ03

- **AC05:** an unknown id is read
  - Given: no widget has id 42
  - When: the caller reads id 42
  - Then: the response is 404
  - Proves: RQ03

- **AC06:** the list stays fast
  - Given: 10,000 widgets exist
  - When: the caller lists them
  - Then: the page answers in under 300 ms
  - Proves: RQ03

## Decisions

- **DN01:** Must a widget's name be unique, and what does a duplicate return?
  - Answer: Unique per parent. A duplicate returns 409.
  - Basis: decided (user, 2026-07-30)

- **DN02:** Who may create a widget under a given parent?
  - Answer:
  - Basis: must-decide - the module has no ownership model
