# `anchor [status|install|refresh|remove] [<front-door>]` — manage recovery discovery

The default action is read-only `status`, and the default front door is the root `AGENTS.md`.
Invoke the package helper with the canonical primary root and the same arguments. Report its
`current`, `absent`, `drifted`, `conflict`, or `error` classification.

`install`, `refresh`, and `remove` authorize only the bounded
`workstream:recovery-anchor@1` extent. Show the target and prior classification, run the requested
transition, and preserve all surrounding prose. A duplicate, nested, malformed, symlinked, or
concurrently changed extent refuses. Setup, repair, create, and load never call this verb
implicitly.

The installed route remains current-worktree-only: a top-level runbook activates `read-current`;
without one it stays inert and never searches sibling stream worktrees.

Done when a follow-up `status` reports the requested state. Commit the front-door change only when
the caller's repository policy authorizes it.
