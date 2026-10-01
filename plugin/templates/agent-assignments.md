# Agent Assignments

How a step-carrying implementation agent's launch identifies the work assigned to it.

The `PreToolUse` hook on `Agent` prepends this header to the prompt before the agent starts:

```
Workflow: <implement-plan | fix-bug | rework | upgrade-deps | small-change>
Work file: <repository-relative path | none>
Assigned items: <space-separated item IDs | none>
Assignment basis: <the Agent call's description>
Reason: <the prompt's Reason line, on a relaunch only>
```

The hook derives the workflow, work file and item IDs from the agent type, prompt and work file. It rejects a
known implementation-agent launch when those values disagree or cannot be resolved. Do not write the header in
the prompt yourself.

For a plan step agent, pass the assigned items' `plan.sh show` output as the prompt's step context. Paste it
as it prints, not inside backticks. Outside that output, name no other item of the agent's own kind by its ID.
The hook assigns such an ID it finds in the prose. Name that item by its class or its test instead. IDs of
another kind, such as the red steps a stabilization agent must agree with, are fine. For a module
agent that owns a whole work file, name that file in the prompt. The hook assigns every item still open in it.
A reproduction brief with no checklist items records `none`.

The description states the assignment at the project's useful boundary. Use a feature, component or source
grouping for a bundle. Use `whole work file` for a module agent and `reproduction brief` for an unplanned case.

A relaunch starts its prompt with one `Reason:` line. A relaunch is any launch for work an agent already did or
tried: a step sent back to an earlier phase, a re-delegation, an escalation, a correction after a review. The
line says in one sentence, under 200 characters, what is wrong. When the work file's log holds an entry for it,
end the line with that entry's ID: `See RL11.` The hook moves the line into the header.

