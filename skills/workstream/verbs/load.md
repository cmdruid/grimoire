# `load <stream>` — resume one admitted stream

Pass the checkout you are in. Invoke `read <stream>`. Reconcile that projection with
`git -C WORKTREE status --short` and the branch log. A running hook, uncertain delivery,
interrupted Git operation, dirty work not explained by the projection, or coordinate mismatch
blocks automatic continuation. Never inspect or edit `workstream.tsv`.

If `session=present`, read only the `workstream:session@1` span. Do not reconstruct identity or
policy from managed spans. If the span is empty, continue from `read` alone.

If the state and Git agree, proceed with the reported **local** `next_action` (define, build,
complete, hook, accumulate, sync, `ship-prepare`). Explicit load is not landing authority. If
`next_action` is `land` (or would mutate the primary checkout or recorded target), stop and ask.
Bare `/workstream ship` remains the landing authority.

Ask only for an ambiguous unit, semantic conflict, or landing decision.

Done when custody is admitted and local execution resumes, or one concrete mismatch is reported.

Compaction recovery is not a named load. When the current Git top level contains `WORKSTREAM.md`,
use `read-current <current-top-level>`, then the session span if `session=present`. With no
top-level runbook, recovery is inert; never search sibling worktrees for one.
