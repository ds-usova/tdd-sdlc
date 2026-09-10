# Fix: Charge once per request

**Format:** 2
**Affected Module:** `billing`
**Bug:** [The second call charges the account twice](bug.md)

## Steps

| #   | Kind      | What changes                  | Touches |
|-----|-----------|-------------------------------|---------|
| 1   | stabilize | Add a two-child builder       | tests   |
| 2   | red       | Reproduce the double charge   | Charger |
| 3   | green     | Guard on the request id       | Charger |

- [ ] FS01 · stabilize · Add a builder for a request with two children
  - test-files:
    - `billing/src/test/RequestBuilder.java`

- [ ] FR01 · red · A request with two children is charged twice
  - test-files:
    - `billing/src/test/ChargeTest.java`
  - reproduces: the second call charges the account twice
  - runs: `ChargeTest#chargesOnce`
  - needs: FS09

- [ ] FG01 · green · Guard on the persisted request id
  - files:
    - `billing/src/main/Charger.java`
  - fixes: FR01
  - runs: `ChargeTest#chargesOnce`
