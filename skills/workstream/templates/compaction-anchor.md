## Workstream compaction recovery

Applies only when your context has just been compacted or summarized (you see a
compaction/continuation summary in place of the full conversation), and only to the current Git
top level:

- If that top level has no `WORKSTREAM.md`, this route is inert. Do not scan `.streams` or infer
  custody from a branch.
- If `WORKSTREAM.md` exists at that top level, STOP before further work. Invoke the canonical
  primary helper with `read-current <current-top-level>`, reconcile its bounded projection with
  Git, and resume only its reported action. Do not read the complete runbook or raw tracker.
- Handoffs below another checkout belong to other sessions. Never read, load, or recover them.
