# `status` — list admitted streams without entering them

Resolve the canonical primary root and invoke `workstream.sh ROOT list`. The helper examines only
immediate registered `.streams` runtime worktrees, validates each runbook/tracker/Git coordinate,
and emits compact identity, phase, and next-action facts. It never emits hook bodies or raw tracker
rows.

Report malformed or unregistered children as blockers; don't read them approximately. Don't load,
repair, reconfigure, or mutate a stream as a side effect.

Done when the bounded list or one admission error is reported.
