# `migrate` — move legacy worktrees to `.streams`

Run the package helper with `migrate inventory` from the canonical primary root. Review every old
`.workstreams/NAME` and proposed `.streams/NAME` coordinate. Unknown children, symlinks,
unregistered directories, nested state, destination collisions, branch disagreement, dirty active
uncertainty, or mixed roots refuse.

After explicit approval, invoke `migrate apply`. The helper uses Git's worktree move operation,
mints a fresh instance ID, writes the composed runbook and tracker, preserves the branch and
worktree contents, and seeds counters above same-name history. It ignores retired customization
and record archives; it neither moves nor deletes them. Rerun inventory until no legacy worktree
remains. Refresh a recovery anchor separately if the project has one.

Done when Git registers every migrated worktree below `.streams`, each admits through `read`, and
the old root is removed only if empty.
