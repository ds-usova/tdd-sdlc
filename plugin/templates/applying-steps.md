# Applying a steps file

What every module agent of a fix, a rework and an upgrade follows around its steps. The agent's own file adds its
script's commands, its sequence and its report.

## The script

- **Name your file on every call.** The log is found beside it.
- **Read a step from the script's `show`**, never by extracting it by hand.
- **Tick a step only once you have verified it yourself.**
- **Where the script is absent or the call is refused** — by a hook or by the user at the prompt — edit the files
  directly under the same rules. Write the log's **Caveats** entry and put the case as one line in your final
  report, as [`scripts/README.md`](../scripts/README.md) says. Never stop for it.

**Run a suite in the foreground and wait for it.** Never background it.

## After every step

Run whatever the conventions require before a commit, then tick the step. Where the conventions commit, commit the
steps file with the paths that step named, as the commit policy says. Report a refusal the policy does not cover
rather than retrying.

## What is never done

- A test is never deleted or weakened to make a step green. A step disables one only where its skill's
  `applying-a-step.md` allows it.
- Nothing outside the steps is improved because it was nearby. A step never reaches past its own boundary.
- A second defect found along the way is reported, never fixed.

## A failure that is not the step's

**A failure on a code path the steps never reach, or clearly environmental, is reported with enough detail to
reproduce.** It is not a step failure. A test this run broke is never unrelated.
