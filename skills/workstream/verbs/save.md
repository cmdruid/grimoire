# `save`  · runs in the worktree

**A save is justified by imminent — or unpredictable — context loss** (`flow.md` -> *Reset ritual*
— read it if not already in context): it exists to survive a context reset, and harness
auto-compaction (`flow.md` -> *Scenario C*) means loss can strike unannounced. The saves are: a
user invoking `save` directly, the flow's single pre-reset checkpoint, and the flow's
**feature-completion checkpoint** (fires at every feature-completion seam,
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
   2. Run `hooks.sh compiled-get --handoff <this hand-off:>` → compiled span (may be empty).
      Classify any **named next action** from the invocation and the same-turn message (`next:`
      remainder, remainder after `—`, same-turn prose that states the subsequent work; `--` is
      not a marker; politeness is not named). Workstream `save` has no path hatch. Then apply
      `/checkpoint`'s **Save discipline** (scan/elide secrets; synthesize, don't transcribe;
      absolute dates; author a single next action (named > KNOWN > best-guess)) to **compose**
      the regeneration from the bundled `templates/workstream-handoff.md` (the workstream
      hand-off shape: Coordinates + START HERE + Queue state + Loop routine). Do **not**
      recompile. Do not persist yet.
   Worktree specifics (still composing): reconcile *What's been done* against
   `git -C <worktree> log`, and **preserve the Coordinates block verbatim** (it's fixed for the stream's life).
   **Reconcile the TL;DR / next-action too, not just the done-list:** a claim like "X not yet
   done — do X next" must survive a check against `git -C <worktree> log` AND
   `git -C <worktree> log <branch>..<target>` (X may have landed on the trunk, or ridden an earlier
   ship) — a stale next-action is the one lie a resuming session acts on immediately.
   A **named** next step writes into TL;DR and *What's next* first item as **the same sentence**.
   Queue and plan do not rewrite.
   **`manual` mode, user-invoked named next:** a named next that *is* a phase change updates
   `Phase:` (that is the launch key). A named next *inside* the current phase leaves `Phase:`
   alone. If it conflicts with `Phase:` and is not itself a phase change → AMBIGUOUS; do not
   write the lie.
   **Refresh the Cheat sheet** (still composing): run `workstream-git.sh cheatsheet-check <worktree>` (in-place streams:
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
   That is the flow-triggered phase-boundary case; a user-invoked named next uses the clause above.
   **Round-trip gate (before persist; this verb, not a flow seam):**
   - Named (and load-executable) or KNOWN or flow-triggered/unprompted → persist (next paragraph).
   - **User-invoked, human-present, AMBIGUOUS** → **STOP.** Propose the recommendation first,
     then one or two alternatives, each one line + why. One pick (or a named other). Then persist
     in the pick's turn. Do not re-confirm "should I save?"
   - Named-but-vague → AMBIGUOUS, constrained by the stated intent.
   - Git/disk veto of a named action → do not write the lie; surface the contradiction;
     AMBIGUOUS; propose the real next from disk / *What's next* / queue.
   Flow-triggered saves (reset ritual, feature-completion, park, manual phase-boundary) are
   **unprompted**. Queue / `Phase:` is KNOWN when it already determines the next move. The
   recorded line is what Confident launch confirms when `stream-state` does not force otherwise
   — authority is `workstream-git.sh stream-state` / Confident launch (`flow.md`); `behind>0` →
   sync is an example, not the set. Git/disk still vetoes a lie at save.
   Persist (only the write branches above): regenerate that same path in place from the composed
   content, then run `hooks.sh compiled-put --handoff <this hand-off:>` with the saved compiled span
   (empty stdin + span present = no-op; placeholder stays).
2. It is a FILE WRITE, not a commit — the hand-off is ignored (in `info/exclude`) and must never be staged.
3. Confirm the path written and the recorded next action; also report whether the trunk
   has moved (`git -C <worktree> log <branch>..<target> --oneline`, `<target>` = Coordinates
   `integration-target`) so a landed dependency / sync-due
   surfaces at every save, not by luck. **Also resume-how** (`/workstream load <stream>`) when
   this save precedes a new session: user-invoked, pre-reset, or context-pressure that recommends
   a reset. **Omit resume-how** otherwise.
