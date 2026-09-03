---
kind: workstream-template
---

# Workstream coordinator guide

Use this optional guide only for a root session coordinating several streams. It is not a stream
runbook and carries no live state.

## Mission

Keep the integration target shippable while streams own iterative work. Recheck Git before every
decision because another session may move the target.

## Loop

1. Read project instructions and inspect `/workstream status`; do not read foreign stream bodies.
2. Seed a named stream only on explicit request, leaving that stream for its own session.
3. Let the owning registered worktree prepare and ship. Keep the primary checkout clean and on the
   target branch for leased synchronization, then verify both endpoints afterward.
4. Make unrelated root edits only when authorized, using path-scoped staging and the host gate.

Never use the root checkout as shared scratch, infer authority from a prepared shipment, or repair a
stream by editing its runtime files. Use the Workstream control verbs for lifecycle operations.

## Project pointers

- Front door: `<project: agent instructions>`
- Integration and gate policy: `<project: development workflow>`
- Queue sources: `<project: plans or roadmaps>`
