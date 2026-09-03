# `park` / `unpark` — transfer in-place custody

These actions apply only when `read` reports `isolation=in-place`. A linked worktree refuses them.
Before parking, save any necessary operator note, then invoke `workstream.sh ROOT park STREAM`.
Before unparking, invoke `workstream.sh ROOT unpark STREAM`, then call `read` again. The helper
requires clean tracked work, exact branch custody, and no unresolved hook before either switch.

Never carry uncommitted files across the switch, stash repository-global state, infer custody from
an ignore rule, or park a different session's stream. A foreign branch or moved coordinate is a
blocker, not permission to switch it.

Done when the expected branch holds the shared checkout and the reloaded projection agrees.
