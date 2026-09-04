# `repair [<stream>]` — restore Workstream-owned files

Use naked `repair` for the installed `.streams` control surface. Run the package helper with the
canonical primary and `repair`. It refreshes managed helper, ignore, and README bytes; restores an
absent default `CONFIG.md`; validates present configuration; and commits only files it changed.
Missing `history.tsv` is not data loss. An incumbent history file is left in place, unvalidated.
Never replace a present project configuration or touch `AGENTS.md`.

With `<stream>`, target only that stream. Run `repair <stream>` from the root coordinator, or only
for the current stream when already inside one. Preview and resolve its canonical root, worktree,
branch, runbook, and tracker before accepting a mechanical repair. Coordinate disagreement,
divergent copies, or ambiguous Git administration requires attended recovery; don't synthesize
intent from a branch name. An absent tracker may be reconstructed only from a bound runbook when
the branch is clean, contains no unlanded commit, and its exact Git custody is unambiguous. The
reconstructed tracker resumes fresh intake with the same instance ID. Repair copies the session
span through unchanged.

Done when the helper reports `current` and one `next_action`, or when you have stopped on a stated
custody blocker.
