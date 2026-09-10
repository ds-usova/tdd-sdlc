# Upgrade: module-a, the test stack moves one minor

**Format:** 2
**Affected Modules:** `module-a`
**Source:** the request
**Baseline:** abc1234
**Surveyed with:** manifest + registry
**Policy:** open — chosen in Phase 2

## Survey

| Dependency | Current | Newest | Target | Vulnerabilities | Guide | Status |
|------------|---------|--------|--------|-----------------|-------|--------|

## Steps

- [ ] UP01 · bump · `org.assertj:assertj-core` 3.24.2 -> 3.26.3
  - files:
    - `gradle/libs.versions.toml`
  - guide: https://example.org/notes/3.26.3 — nothing breaking

- [x] UP02 · bump · `@types/node` 20.11.0 -> 20.14.2
  - files:
    - `package.json`
  - guide: none found

- [ ] UP03 · migrate · `org.springframework.boot` 3.2.5 -> 3.3.2
  - files:
    - `gradle/libs.versions.toml`
    - `src/main/resources/application.yml`
  - test-files:
    - `src/test/java/KafkaConfigTest.java`
  - guide: https://example.org/boot-3.3
  - change: `ack-mode` moves under `acknowledgment` · application.yml
  - needs: UP77

- [ ] UP04 · bump · `left-pad` 1.0 -> 1.3 abandoned — dropped from the manifest instead
  - files:
    - `package.json`
  - guide: none found

## Open Questions

- **OQ01:** keep the old ack-mode key as an alias?
  - A: no
