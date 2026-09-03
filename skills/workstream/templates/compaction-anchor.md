## Workstream compaction recovery

_(The workstream instance of `/checkpoint`'s recovery-anchor convention, with stream-specific
custody rules.)_

Applies only when your context has just been compacted or summarized (you see a
compaction/continuation summary in place of the full conversation), and only to the tree your
working directory is inside (`git rev-parse --show-toplevel`):

- If `WORKSTREAM.md` exists at that tree's **top level**, you may be the session driving that
  workstream. STOP before further work, admit its immutable coordinates, invoke the effective
  `.streams/workstream.sh` with `read <stream>`, reconcile that bounded projection with Git, and
  resume only its reported action. Do not read the complete runbook or raw tracker.
- If instead a `.streams/<stream>/WORKSTREAM.md` under the top level records
  `isolation<TAB>in-place` **and** HEAD is on that stream's branch, the same applies — you are in the
  shared tree that stream holds.
- Hand-offs visible under `.streams/` from the root checkout otherwise belong to **other
  sessions'** worktrees: never read, load, or recover them.
