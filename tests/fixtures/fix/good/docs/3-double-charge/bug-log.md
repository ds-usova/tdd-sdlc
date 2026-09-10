# Bug Log: The second call charges the account twice

## Attempts

- **AT01** · diagnosis · Rewrote the read so it could not return a row twice.
  - why: the count doubled exactly when a record had two active children.
  - result: failed — the duplicates survived the rewrite.
  - evidence:
    ```
    expected: 1 but was: 2
    ```
  - ruled-out: the query is not the source.
