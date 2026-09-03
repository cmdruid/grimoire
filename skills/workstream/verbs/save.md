# `save [<operator-note>]` — preserve semantic intent

Use save only before a context reset or custody transfer when Git and helper state don't capture a
needed semantic fact. Resolve the current registered stream worktree and call:

```text
workstream.sh ROOT operator-note STREAM NOTE
```

Use `-` to clear the note. Keep it a bounded single line: the next decision, unresolved semantic
constraint, or reason execution is paused. Don't copy diffs, commit lists, tracker facts, test
output, hook bodies, or a task diary. The helper atomically changes only the operator-note span;
the runbook contract hash and tracker remain unchanged. An identical save is a no-op.

Done when the helper reports `saved` or `unchanged`. A save doesn't sync, ship, or authorize a ref
change.
