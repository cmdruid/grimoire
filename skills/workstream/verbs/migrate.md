# `migrate` — move legacy worktrees to `.streams`

Run the package-only `scripts/workstream-migrate.sh ROOT inventory` with the canonical primary
root. Inventory relocates nothing: it classifies every `.workstreams/NAME` against
`.streams/NAME`, records branch and target tips, and reports `aligned`, `ahead`, `behind`, or
`diverged`. Being behind or diverged is not a refusal. Untracked files move with the worktree.
Tracked or staged work, interrupted Git, collisions, symlinks, unregistered paths, and in-place
members refuse, and the report names every blocker before it stops.

After explicit approval, invoke `scripts/workstream-migrate.sh ROOT apply`. Apply moves each
approved worktree, writes current runbook and tracker artifacts, and does not merge, rebase, reset,
or touch submodules. Ordinary `read` then reports `next_action=sync` when the target is not an
ancestor of HEAD. `/workstream sync` owns reconciliation. Rerun inventory until no legacy worktree
remains. Refresh a recovery anchor separately if the project has one.

Done when Git registers every migrated worktree below `.streams`, each admits through `read`, and
the old root is removed only if empty.
