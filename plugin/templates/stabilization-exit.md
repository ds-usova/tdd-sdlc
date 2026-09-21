# Stabilization Exit

What `implement-plan-module` verifies after every Stabilization section is complete.

1. Compile the module, including test sources.
2. Run its architecture-enforcement test where the conventions name one.
3. Run the pre-existing suite. Compare it with the baseline: green; total unchanged except for named deletions;
   skipped count equal to the baseline plus exactly the tests stabilization disabled. Read the skip list itself.
   Every added skip must name a step in the plan.
4. Read every stub method against the scenarios of the red step that covers it. Its intent comment exists and
   agrees with the scenarios' behaviour and error cases. Re-delegate a missing, vague or contradictory comment to
   `stabilization-step`.
5. Run `plan.sh stub <path>... --marker <token> docs/<plan>.md` with every file the reports name a stub in and the
   marker the module's code-style conventions name. Omit `--marker` for the default. Record an empty list when no
   report names a stub.

Re-delegate a failure caused by the plan to the stabilization items that own it. Apply the pipeline's unrelated
failure rule to anything else. Stage 2 starts only when every check holds.
