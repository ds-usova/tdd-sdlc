# Example Plan Log — Worked Example

The `plan-log.md` beside [`example-plan.md`](example-plan.md): what the review found and what the run recorded.
Nothing in it binds a step. The plan carries every fix a finding produced; this file is the record that it was
raised, and what happened while the plan ran. It is shown as it stands after the run, while the plan beside it
is shown as written — so its **Run Log** names ticks the example plan does not yet carry. In a real task the
two files sit beside each other under one name each, which is how `plan.sh validate` finds the log; these two
carry distinct names, so validating the example takes `--log example-plan-log.md`.

---

# Plan Log: Add Widget Creation

## Review Findings

- **F1:** `RI02`'s error-mapping scenarios cover 404 and 409, but `WidgetControllerTest` must also assert the 503
  the design maps `PersistenceFailedException` to — no scenario covers it at any layer.
  - Resolution: mechanical
  - Action: applied — added the scenario to `RI02`.

- **F2:** `GI02` names `after: GU01`, but `WidgetControllerTest` mocks `CreateWidgetPort`, so the use case is
  never on its execution path.
  - Resolution: mechanical
  - Action: applied — `GI02` now reads `after: GU03` only.

## Run Log

- **B1 (RI01):** `WidgetRepositoryAdapterTest` cannot start the containerized database on this machine — the
  container runtime is not running. Left open; every other red item is ticked.
  - Resolved: runtime started, `RI01` re-run and ticked (2026-08-02).

- **B2 (RU03):** `WidgetUtilsTest.whenOptionalFieldIsNull_thenNullIsPreserved()` passed in the red phase: the
  existing `toRest()` already passes a null through, and the step's scenario only pins it. The assertion is real
  — it fails if the mapper substitutes a default — so `GU03` verifies it rather than implements it.
