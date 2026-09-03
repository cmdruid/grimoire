# `sync` — rebase the stream onto its target

Call `read` for the current stream worktree and stop on running/uncertain receipts or dirty tracked work.
Then invoke `workstream.sh ROOT sync STREAM`. The helper validates custody and performs no work when
the target is already an ancestor. Otherwise it rebases the stream branch onto the recorded target
without changing the target ref.

On conflict, resolve only with semantic confidence, continue or abort the Git rebase explicitly,
and record `rebase-conflict` or `semantic-conflict` when a shipment exists. Re-run sync to confirm
the resulting tips. Any candidate change invalidates earlier gate evidence; prepare will resume at
the first stale phase.

Done when the helper reports `current` or `synced`, or the unresolved conflict is stated. Sync
doesn't save or land.
