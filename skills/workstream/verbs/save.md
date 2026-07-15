# `save`  · runs in the worktree

**A save is justified only by an imminent reset** (`flow.md` -> *Reset ritual* — read it if not
already in context): it exists to
survive a context reset, so the only saves are a user invoking `save` directly and the flow's single
pre-reset checkpoint. No other verb calls it.

1. Apply `/handoff`'s **Save discipline** to regenerate `<worktree>/WORKSTREAM.md` in place from its
   own template (the workstream hand-off shape: Coordinates + START HERE + Queue state + Loop
   routine), targeting that explicit path. Worktree specifics: reconcile *What's been done* against
   `git -C <worktree> log`, and **preserve the Coordinates block verbatim** (it's fixed for the stream's life).
   **Refresh the Cheat sheet:** run `workstream-git.sh cheatsheet-check <worktree>` (in-place streams:
   pass the hand-off explicitly — `cheatsheet-check <root> <root>/.workstreams/<stream>/WORKSTREAM.md`
   — since the hand-off does not sit at the tree's root); prune or fix any
   stale pointer it flags, add pointers for files the stream has since touched, and update
   `built-against:` to the current `git -C <worktree> rev-parse --short HEAD` — so the map tracks the
   code across the stream's life instead of rotting from the create-time snapshot.
   **In `manual` mode**, also set Queue-state `Phase:` to the phase being parked *into* (the one `load`
   will resume), so the pre-reset checkpoint hands the next session the right phase + model.
2. It is a FILE WRITE, not a commit — the hand-off is ignored (in `info/exclude`) and must never be staged.
3. Confirm the path written and the single next action it now records; also report whether the trunk
   has moved (`git -C <worktree> log <branch>..<target> --oneline`, `<target>` = Coordinates
   `integration-target`) so a landed dependency / sync-due
   surfaces at every save, not by luck.
