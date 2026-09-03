# `migrate` — move legacy worktrees to `.streams`

Run the package-only `scripts/workstream-migrate.sh ROOT inventory` with the canonical primary
root. Review every old `.workstreams/NAME` and proposed `.streams/NAME` coordinate. Inventory
validates the complete population before creating `.streams` or its manifest. Unknown children,
symlinks, unregistered directories, nested state, destination collisions, branch disagreement,
dirt, interrupted Git, divergence, ambiguity, or any in-place member refuse without mutation. The
refusal lists every in-place name; finish or close those streams under the legacy skill first.

After explicit approval, invoke `scripts/workstream-migrate.sh ROOT apply`. The persistent manifest
binds the source set, handoff, branch tip, target boundary, destination, and registry so interrupted
moves or artifact installation resume safely. The helper uses Git's worktree move operation, mints
a fresh instance ID, writes field-free current runbook and tracker artifacts, preserves the branch,
commits, queue policy, cadence, landing policy, and feature hook, then validates each result through
ordinary named `read`. It ignores retired customization and record archives; it neither moves nor
deletes them. Rerun inventory until no legacy worktree remains. Refresh a recovery anchor
separately if the project has one.

Done when Git registers every migrated worktree below `.streams`, each admits through `read`, and
the old root is removed only if empty.
