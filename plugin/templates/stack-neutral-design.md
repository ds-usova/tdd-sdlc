# Stack-neutral design

Apply this boundary to every sentence, table cell and diagram label in a design artifact.

Keep what another implementation must preserve: behaviour, responsibilities, invariants, flows, endpoint paths,
wire fields, status codes, messages, stored shapes, columns and SQL semantics.

Move implementation placement and mechanism to the plan: source files, classes, methods, framework components,
hooks, style tokens, libraries and library calls.

Move a repository fact that supports a decision to `design-log.md`. Do not add a reading list to an artifact.

Check each fact by asking whether a team using another language and framework could implement it without
translating an implementation name. Remove or move every fact that fails that check.
