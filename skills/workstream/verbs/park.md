# `park` / `unpark`  · in-place streams only · custody hand-over

An **in-place** stream (Coordinates `isolation: in-place`) holds the ONE shared tree. `park`
returns the tree to the trunk without losing stream state; `unpark` takes it back. Interruptions
(a trunk hotfix, another session needing the tree, a teammate's pull) are a first-class seam —
same rank as the reset ritual (`flow.md`). A worktree stream never parks: its tree is private.

## `park`

1. **Custody check:** `workstream-git.sh inplace-state <root> <stream> <branch> <target>` —
   `on_stream_branch` must be `true` (you can only park what you hold); `false` → STOP and report.
2. **Save first** (an interruption is a seam): apply `verbs/save.md` so the hand-off records where
   the stream stopped and what resumes it.
3. **Bank WIP as a commit, not a stash:** if `dirty=true` (from step 1's `inplace-state` read),
   `git -C <root> add -A && git -C <root> commit -m "wip: park <stream>"`. A stash is invisible and
   fragile; a branch commit survives anything and is soft-reset on unpark. (This is the ONE
   sanctioned `add -A`: custody means everything dirty in the tree is the stream's own.)
4. **Hand the tree back:** `git -C <root> switch <target>`.
5. **Record it:** set `Parked: true` in the hand-off's Queue state. Report: parked; tree on
   `<target>`; resume with `/workstream load <stream>` (which unparks).

## `unpark`

Runs standalone, or implied by `load` of a parked stream (its custody check routes here).

1. **Foreign-dirt check:** if `git -C <root> status --porcelain` is non-empty while parked on the
   trunk, STOP — that dirt is someone else's uncommitted work (the stream's own WIP always rides
   its branch); switching would entangle it. Report and let the human resolve.
2. **Gather custody facts:** `workstream-git.sh inplace-state <root> <stream> <branch> <target>`
   (`top_wip` reads the branch ref, so this may run before the switch).
3. **Take the tree:** `git -C <root> switch <branch>`.
4. **Restore WIP:** if step 2 reported `top_wip=true`, `git -C <root> reset --soft HEAD~1`
   — the parked WIP returns to the tree uncommitted, exactly as left. Soft-reset ONLY a `wip:`
   commit — never a real commit.
5. **Record it:** set `Parked: false` in the hand-off's Queue state, then continue per the
   hand-off's next action (a fresh session continues into the Confident launch, `flow.md`).

Neither verb gates, lands, or debriefs — custody transfer only. `park` is save-first by
construction (step 2); a parked stream loses nothing.
