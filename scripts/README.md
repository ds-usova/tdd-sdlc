# The scripts

One script per file format the plugin writes, each in its own directory with a README beside it: `design/`,
`plan/`, `fix/`, `rework/`, `upgrade/`. A skill names the one it uses, and every module agent that skill spawns
uses the same one.

## What they are for

Each one reads, validates and edits a file the skill would otherwise read and edit by hand. `validate` catches a
malformed file before anything runs on it — a duplicate ID, a dependency nothing defines, a placeholder left in a
scenario. `next` computes what the `after:` lines allow to be spawned. `tick` and `block` keep every checkbox
consistent with what the suite actually proved. `settled` proves a design has no open decision. None of them
does anything the model cannot do by reading the file; what they add is that the answer is mechanical, the same
every time, and never skipped because a long run was tired of it.

## When one cannot run

Whoever installs the plugin allows the scripts in their own permission settings — each README's **Portability**
section gives the rule. A call can fail to run for two reasons, told apart by what it printed:

- **The call was refused** — by a permission hook whose allow rules do not name the script, or by the user
  declining the permission prompt by hand. Either is the operator's call, by accident or by choice, and not
  running a plugin's scripts on one's own machine is a legitimate choice. Never re-run a declined call to see
  whether the answer changes.
- **The script is absent.** An incomplete install.

Either way the skill continues: every check a script answers is answered by reading the file, every tick is an
edit to the checkbox, under the same rules the script would apply. The run completes with fewer guardrails and
no mechanical sanity check, and that is the whole difference.

**What the skill owes the user is to say so, once, where it can be heard.** The first call that fails is made by
the skill in the session, before any agent is spawned, and the skill tells the user in this shape:

- which script, and whether it was refused or is absent — quoting a hook refusal's own wording, since that
  names the rule to add; a declined prompt has no wording, so name the rule from the script's README instead;
- what the scripts would have checked for this run, in one or two lines from the section above;
- that the run continues without those checks, and how — which file edits stand in for which calls;
- that allowing it is one edit or one accepted prompt, and nothing has to be restarted for it.

Then it goes on. It does not stop and it does not ask: the user answers by adding the rule or by letting it run.

**A module agent has no user to tell.** Its report arrives when it has finished, so it never stops for this
either. It names the case it hit as one line in the first section of its final report — which call, refused or
absent, and that every tick from there on was made by hand against the suite's figures. That line is the
record; the skill that spawned it already said the rest.
