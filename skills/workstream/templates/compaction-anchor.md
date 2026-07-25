## Workstream compaction recovery

Applies only when your context has just been compacted or summarized (you see a
compaction/continuation summary in place of the full conversation), and only to the tree your
working directory is inside (`git rev-parse --show-toplevel`):

- If `WORKSTREAM.md` exists at that tree's **top level**, you are the session driving that
  workstream — STOP before any further work: re-read it in full, reconcile it against the durable
  progress records it names, and only then resume from its recorded queue state.
- If instead a `.workstreams/<stream>/WORKSTREAM.md` under the top level records
  `isolation: in-place` **and** HEAD is on that stream's branch, the same applies — you are in the
  shared tree that stream holds.
- Hand-offs visible under `.workstreams/` from the root checkout otherwise belong to **other
  sessions'** worktrees: never read, load, or recover them.
