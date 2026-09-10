# Fix Log: Charge once per request

**In flight:**

## Attempts

- **AT01** · FG01 · Deduplicated the charges after the fact.
  - why: the charges carried the same request id.
  - result: failed — the account was still debited twice.
  - evidence:
    ```
    expected: 1 but was: 2
    ```
  - ruled-out: cleaning up afterwards; the second charge has to be prevented.

- **AT02** · FG01 · Locked the row for the request.
  - why: the two charges came from concurrent calls.
  - result: failed — the second call ran after the lock was released.
  - evidence:
    ```
    charges=2
    ```
  - ruled-out: locking alone.
