# API Update: Add Widget Creation

| Operation       | Result                                      |
|-----------------|---------------------------------------------|
| `POST /widgets` | 200 with the widget and its generated id    |
| duplicate name  | 409; the existing widget remains unchanged  |
