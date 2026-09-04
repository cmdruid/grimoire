# `save [<operator-note>]` — persist session intent

Synthesize the current session (do not transcribe the chat). Elide secrets. Include last-updated
date, TL;DR, completed work and decisions, repo/stream pointers, ordered pending work, and one
load-executable next action. Write that body to a temp file. The optional argument is that next
action when the user named one; otherwise use the action you just synthesized.

```text
workstream.sh CHECKOUT session-set STREAM --body PATH --note ACTION
```

The helper replaces only the session span and sets `operator-note` to ACTION. Do not edit
`WORKSTREAM.md` directly. `operator-note` on the helper is not this verb.

Enrollment is `session=present` on a later `read`. While enrolled, refresh this same save
(1) before a deliberate reset, (2) after a completed unit, and (3) on a context-pressure warning.
Never save a polluted context. `session=empty` means no automatic refresh.

A save does not sync, ship, or authorize a ref change.

Done when the helper reports `status=saved` and `session=present`.
