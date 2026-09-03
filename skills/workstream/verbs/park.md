# `park` / `unpark` — transfer in-place custody

These actions apply only when `read` reports `isolation=in-place`. A linked worktree refuses them.
Before parking, save any necessary operator note, require clean tracked work and no running or
uncertain receipt, then switch the shared checkout from the stream branch to its recorded target.
Before unparking, require the shared checkout to be clean and still on that target, then switch to
the recorded stream branch and call `read` again.

Never carry uncommitted files across the switch, stash repository-global state, infer custody from
an ignore rule, or park a different session's stream. A foreign branch or moved coordinate is a
blocker, not permission to switch it.

Done when the expected branch holds the shared checkout and the reloaded projection agrees.
