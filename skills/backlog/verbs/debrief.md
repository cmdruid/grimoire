# `debrief` — route before context is lost

1. Resolve roots and require the staged engine. Gather the completed body's conversation,
   bounded git status/diff, test results, and explicit unresolved decisions. Do not run new broad
   discovery or mint a report.
2. Invoke `compile`. Zero routing blocks → file nothing and say no project debrief modules are
   configured.
3. For each concrete leftover, choose exactly one compiled stem whose project-authored body
   applies. Invoke writer commands directly (`add`, or `update` / `complete` for an existing row).
   Unroutable material stays in the conversation; do not invent a tracker.
4. Commit all changed tracker paths once with `Backlog: debrief`. Nested file operations never
   commit separately.

Done when every actionable leftover was routed once or explicitly left unrouted, and the sweep
made at most one scoped commit.
