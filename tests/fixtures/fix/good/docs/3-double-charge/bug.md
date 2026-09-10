# Bug: The second call charges the account twice

**Format:** 2
**Affected Modules:** `billing`
**Source:** the request
**Baseline:** abc123, billing: 40 tests, 0 skipped

## What happens

- **Given** a request with two children
- **When** it is charged
- **Then** one charge is made
- **Actual** two charges are made
