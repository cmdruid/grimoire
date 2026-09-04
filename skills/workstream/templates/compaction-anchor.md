## Workstream compaction recovery

Applies only when your context has just been compacted or summarized (you see a
compaction/continuation summary in place of the full conversation), and only to the current Git
top level:

- If that top level has no `WORKSTREAM.md`, this route is inert. Do not scan `.streams` or infer
  custody from a branch.
- If `WORKSTREAM.md` exists at that top level, STOP before further work. Invoke the helper with
  `read-current <current-top-level>` (pass that checkout; it resolves the primary). Reconcile the
  bounded projection with Git. If `session=present`, read only the `workstream:session@1` span.
  Do not reconstruct identity or policy from managed spans, and do not read the raw tracker.
  Resume only the reported local `next_action`. If it is `land` or would mutate the primary or
  target, stop and ask.
- Handoffs below another checkout belong to other sessions. Never read, load, or recover them.
