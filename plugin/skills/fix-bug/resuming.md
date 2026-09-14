# Resuming an existing bug

Read this only where the argument is the path of an existing `bug.md`. It replaces Phase 0 and Phase 1.

**A `bug.md` under `docs/implemented/`, or one carrying a `**Closed:**` line, is not resumed.** Say so; where the
user wants it reopened, the `**Closed:**` line goes and the run continues from here.

## Read before acting

`bug.md`, every `fix.md` beside it, and the log beside each — every entry of its `## Attempts` and its
`## Run Log`. **Nothing in a `ruled-out:` line is tried again**, and an `RL` entry whose `Resolved:` is empty is a
blocker still standing.

The original `**Baseline:**` stands. Three things on disk are the run working, not a reason to stop:

| On disk                                    | Because                                             |
|--------------------------------------------|-----------------------------------------------------|
| a committed `red` test that fails          | that is the step working                            |
| tests disabled by a `stabilize` step       | the `red` step named in `disables:` has not run yet |
| uncommitted edits under the step in flight | the run was stopped inside it                       |

Uncommitted work anywhere else, and anything red no step accounts for, stops the resume and is reported.

## Where to pick up

| The logs say                                             | Do                                                                                                                                                            |
|----------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| the diagnosis holds and steps are open                   | revert what is uncommitted under the first unticked step (`fix.sh status` names it), continue at Phase 3 from that step                                       |
| a step failed three times, or a `green` left the symptom | the diagnosis is what needs work: go back to Phase 1 for a new hypothesis, log its probes as new attempts in `bug-log.md`, amend the files, stop for approval |
| an `RL` entry's `Resolved:` is empty                       | settle it — fill the line — before the step it names is picked up again                                                                                       |
| the chain of causes was disproved                        | ask whether to pick it up with a new diagnosis or abandon it                                                                                                  |
| an Open Question is unanswered                           | ask it now, write the answer in, then continue                                                                                                                |

**The revert belongs to this skill, never to an agent**, and happens before any agent is spawned. Attempt and
`RL` numbers continue from where each log stopped; nothing is renumbered.
