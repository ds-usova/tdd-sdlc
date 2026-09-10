# Upgrade Log: module-a, the test stack moves one minor

## Attempts

- **AT01** · UP03 · Renamed the key in place without the guide's builder.
  - why: the release notes only mentioned the key.
  - result: failed — the context did not start.
  - evidence:
    ```
    Caused by: java.lang.IllegalStateException: no acknowledgment mode
    ```
  - ruled-out: the rename alone; the constructor is gone too.

## Run Log

- **RL01 (UP03):** the guide's builder needs a decision on the ack timeout
  - Resolved: use the default

```
unclosed
