# `save`  · runs in the worktree

**A save is justified by imminent — or unpredictable — context loss** (`flow.md` -> *Reset ritual*
— read it if not already in context): it exists to survive a context reset, and harness
auto-compaction (`flow.md` -> *Scenario C*) means loss can strike unannounced. The saves are: a
user invoking `save` directly, the flow's single pre-reset checkpoint, and the flow's
**feature-completion checkpoint** (fires at every feature-completion seam alongside debrief #1,
reset or not — bounding the hand-off's staleness to one in-flight feature). No other verb calls it.

1. **Verify the target path first:** the file you are about to write MUST equal the Coordinates
   `this hand-off:` line (the one absolute path — for a worktree stream that is
   `<worktree>/WORKSTREAM.md`; `.workstreams/<stream>/…` is only its ROOT-relative address). On
   mismatch, STOP — do not write: resolving the relative address against the worktree mints a stray
   nested `.workstreams/` copy, and the next `load` reads the canonical (now stale) file instead
   (observed: a save silently forked the hand-off this way and even rewrote the Coordinates line to
   the doubled path). The write path is Coordinates `this hand-off:` — in-place that is
   `<root>/.workstreams/<stream>/WORKSTREAM.md`. Never write `<root>/WORKSTREAM.md`.
   Then:
   1. Path check above unchanged.
   2. `hooks.sh compiled-get --handoff <this hand-off:>` → span (may be empty).
   3. Apply `/checkpoint`'s **Save discipline** (scan/elide secrets; synthesize, don't transcribe;
      absolute dates) to regenerate that same path in place from the bundled
      `templates/workstream-handoff.md` (the workstream hand-off shape: Coordinates + START HERE + Queue state + Loop
      routine). Do **not** recompile.
   4. `hooks.sh compiled-put --handoff <this hand-off:>` with the saved span
      (empty stdin + span present = no-op; placeholder stays).
   Worktree specifics: reconcile *What's been done* against
   `git -C <worktree> log`, and **preserve the Coordinates block verbatim** (it's fixed for the stream's life).
   **Reconcile the TL;DR / next-action too, not just the done-list:** a claim like "X not yet
   done — do X next" must survive a check against `git -C <worktree> log` AND
   `git -C <worktree> log <branch>..<target>` (X may have landed on the trunk, or ridden an earlier
   ship) — a stale next-action is the one lie a resuming session acts on immediately.
   **Refresh the Cheat sheet:** run `workstream-git.sh cheatsheet-check <worktree>` (in-place streams:
   pass the hand-off explicitly — `cheatsheet-check <root> <root>/.workstreams/<stream>/WORKSTREAM.md`
   — since the hand-off does not sit at the tree's root); prune or fix any
   stale pointer it flags, add pointers for files the stream has since touched, and update
   `built-against:` to the current `git -C <worktree> rev-parse --short HEAD` — so the map tracks the
   code across the stream's life instead of rotting from the create-time snapshot. Name cheat-sheet
   files by **repo-relative path**, never bare basename (`cheatsheet-check` resolves pointers against
   paths at HEAD, so a bare `foo.ron` flags stale even when the file exists — and repo-relative
   pointers stay clickable).
   **In `manual` mode**, also set Queue-state `Phase:` to the phase being parked *into* (the one `load`
   will resume), so the pre-reset checkpoint hands the next session the right phase + model.
2. It is a FILE WRITE, not a commit — the hand-off is ignored (in `info/exclude`) and must never be staged.
3. Confirm the path written and the single next action it now records; also report whether the trunk
   has moved (`git -C <worktree> log <branch>..<target> --oneline`, `<target>` = Coordinates
   `integration-target`) so a landed dependency / sync-due
   surfaces at every save, not by luck.
