# `load <stream>` — resume one admitted stream

Resolve the canonical primary root without reading sibling handoffs. The named stream must be the
registered worktree at `<root>/.streams/<stream>`. Invoke the effective helper
with `read <stream>`. It must validate the Git worktree registry, root/worktree/branch/target,
instance ID, runbook contract, tracker schema, and any pending transaction before returning the
bounded purpose, note, state, and one `next_action`.

Reconcile that projection with `git -C WORKTREE status --short` and the branch log. A running hook,
uncertain delivery, interrupted Git operation, dirty work not explained by the projection, or
coordinate mismatch blocks automatic continuation. Never inspect or edit `workstream.tsv`.

If the state and Git agree, proceed with the reported action. The explicit load invocation is
authority for that known local action, not for target/remote mutation. Ask only for an ambiguous
unit, semantic conflict, or landing decision.

Done when custody is admitted and execution resumes, or one concrete mismatch is reported.
