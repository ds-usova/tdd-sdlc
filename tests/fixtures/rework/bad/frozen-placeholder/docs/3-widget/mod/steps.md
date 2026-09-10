# Steps: mod

**Format:** 2
**Affected Module:** `mod`
**Rework:** [Widget rework](../rework.md)

## Steps

- [ ] WK01 · extract · move the parser into Parser
  - files:
    - `src/A.java`
    - `src/Parser.java`
  - test-files:
    - `test/ParserTest.java`
  - frozen: TBD
  - cover: `ParserTest`

- [x] WK02 · tests · split the parser tests
  - test-files:
    - `test/ParserTest.java`
  - survives: an empty input · `Parser`

- [ ] WK03 · pin · enforce the layering rule
  - test-files:
    - `test/ArchTest.java`
  - needs: WK02
  - proves: removing the rule fails ArchTest

- [ ] WK04 · inline · abandoned — the caller is gone
  - files:
    - `src/D.java`
  - runs: `DTest`

## Open Questions

- **OQ01:** keep the old name?
  - A: yes
