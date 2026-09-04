# `close` — tear down a resolved stream

Invoke `workstream.sh CHECKOUT close-check STREAM`. If `ahead` is nonzero or tracked work is dirty,
ask the user to ship or discard it; never infer discard and never perform generic cleanup. A
running, uncertain, awaiting-merge, or unfinalized shipment reports `lifecycle_blocked=yes` and
blocks teardown.

After the branch is fully contained in the recorded target, run:

```text
scripts/worktree-teardown.sh ROOT STREAM [--force]
```

It revalidates the sole `.streams/STREAM` coordinate against the Git worktree registry, removes
that worktree, deletes only `stream/STREAM`, and prunes stale worktree administration. Use
`--force` only after an explicit discard decision. Resolve ROOT from `read`'s `root=` (the
canonical primary).

Do not delete `.streams` control files, project configuration, records, scratch paths, or another
stream. Close creates no report or root commit.

Done when the exact worktree and branch are absent and the control surface remains intact.
