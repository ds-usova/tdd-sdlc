# Spec: Add Widget Creation

**Format:** 2

## Objective

Allow API clients to create widgets.

## Requirements

- **RQ01:** A client can create a widget and gets it back with its id.
- **RQ01:** A widget's name is unique under its parent.

## Acceptance Scenarios

- **AC01:** a widget is created
  - Given: a parent exists
  - When: the caller posts a name and a value
  - Then: the response is 200 with the new widget
  - Proves: RQ01

- **AC01:** the name is already used
  - Given: the parent already has a widget named `left-rail`
  - When: the caller posts a second `left-rail`
  - Then: the response is 409
  - Proves: RQ02

## Decisions

- **DN01:** Must a widget's name be unique, and what does a duplicate return?
  - Answer: Unique per parent. A duplicate returns 409.
  - Basis: decided (user, 2026-07-30)

- **DN01:** What happens when the same widget is created twice concurrently?
  - Answer: One request wins with 200; the other returns 409.
  - Basis: decided (user, 2026-07-30)

Two entries. The gaps are Findings rows.
