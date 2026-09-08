# Who spawns whom

<p align="center">
<img src="diagrams/agents.svg" alt="Skills spawn review agents, orchestrating agents and, for reproductions, red agents; orchestrating agents spawn step agents; step agents spawn nothing" width="900">
</p>

Four kinds of agent, read left to right.

| Kind          | Agents                                                                                     | Spawned by                                   | Spawns                         |
|---------------|--------------------------------------------------------------------------------------------|----------------------------------------------|--------------------------------|
| Skill         | `init-conventions`, `design-task`, `plan-task`, `implement-plan`, `fix-bug`, `rework`, `upgrade-deps` | the user, in the session            | review, orchestrating and reproduction agents |
| Review        | `grill-design`, `grill-frontend`, `review-plan`                                            | `design-task`, `plan-task`, `implement-plan` | nothing; they write nothing    |
| Orchestrating | `implement-plan-module`, `fix-bug-module`, `rework-module`, `upgrade-deps-module`          | the skill of the same name, one per plan or steps file, the shared one first and alone | `implement-plan-module` spawns the step agents; the three module agents spawn nothing |
| Step          | `stabilization-step`, the three red and three green `tdd-*-phase-step` agents, `tdd-refactor-phase` | `implement-plan-module`; the red agents also by any skill or pipeline with a reproduction brief; the refactor pass also by `fix-bug` and `rework` | nothing |

Two general-purpose agents carry no file of their own: the survey agent `init-conventions` runs per module, and
the agent `implement-plan-module` spawns per post-implementation section.

What each agent cost: [`cost-recording.md`](cost-recording.md).

**Escalation** spawns the same type once more, on the deciding model
([`templates/sub-agents.md`](../templates/sub-agents.md), **Budget and escalation**). It adds no edge.

*Diagram source: [`diagrams/agents.puml`](diagrams/agents.puml). Re-render with `diagrams/render.sh`.*
