# `repair [<stream>]` — restore Workstream-owned files

Use naked `repair` for the installed `.streams` control surface. Run the package helper with the
canonical primary root and `repair`. It refreshes managed helper, ignore, and README bytes;
restores an absent default `CONFIG.md`; validates present configuration and history; and commits
only files it changed. A missing initialized `history.tsv` is possible data loss: stop and recover
it from Git. Never replace a present project configuration or touch `AGENTS.md`.

With `<stream>`, target only that stream. Run `repair <stream>` from the root coordinator, or only
for the current stream when already inside one. Preview and resolve its canonical root, worktree,
branch, runbook, and tracker before accepting a mechanical repair. Coordinate disagreement,
missing active state, divergent copies, or ambiguous Git administration requires attended
recovery; don't synthesize intent from a branch name.

Done when the helper reports `current` and one `next_action`, or when you have stopped on a stated
data-loss or topology blocker.
