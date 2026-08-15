# `load <stream>`  · runs in a session rooted in the worktree · READ-ONLY

_Read `flow.md` alongside this verb — `load` re-enters the loop it governs._

> **GUARD — one session drives one stream.** If you are **already** driving a workstream this session
> (an active `WORKSTREAM.md` / Coordinates block is loaded) and `<stream>` names a **different** stream,
> **STOP** — do not juggle two streams from one session (see SKILL.md *Scope*); capture/surface the
> other work
> instead. `load` is for a **fresh** session entering a stream, or **re-entering the SAME stream** after
> a context reset (the normal path — a context reset ends the session for this purpose, so re-entry
> starts fresh with nothing loaded and passes) — never a way to pick up a second concurrent stream.
> **Note the asymmetry with `create`:** this guard deliberately **omits** `create`'s `rev-parse
> --show-toplevel` cwd test, because the loop *always* re-enters from inside the worktree — a
> cwd-under-`.workstreams/` check would falsely block every legitimate resume. Key **only** on *is a
> different stream already loaded in my context*, never on cwd.

1. Parse `<stream>` to its name. Locate the worktree by matching it against `git worktree list`
   (works from the root or any worktree of the repo), then target `<worktree>/WORKSTREAM.md`. If no
   matching worktree or no `WORKSTREAM.md` is found, run `status` and list active streams so the
   user can pick. **In-place streams own no worktree** — they never appear in `worktree list`;
   locate them the way `status` does, by scanning `<root>/.workstreams/<stream>/WORKSTREAM.md`
   directly (that file IS the hand-off to target).
2. Apply `/checkpoint`'s **Resume discipline** to `<worktree>/WORKSTREAM.md`: read it in full and
   load as context (write/move nothing — resume never consumes). Then run the START HERE guard
   from its Coordinates.
   **Worktree streams:** `git -C <worktree> rev-parse --show-toplevel` == worktree and branch
   matches — if either fails, STOP and report.
   **In-place streams** (`isolation: in-place`): the toplevel test compares to the ROOT path; the
   branch test is the CUSTODY check — run `workstream-git.sh inplace-state <root> <stream> <branch>
   <target>`: `on_stream_branch=true` → proceed; `handoff_parked=true` with `on_target=true` →
   offer **unpark** (`verbs/park.md`) as the launch's KNOWN action; anything else is foreign
   movement → STOP and report, never auto-switch.
3. **Diff the hand-off's claims against git before acting on them.** The launch facts
   (`stream-state`, step of the Confident launch) are truth for everything committed; the hand-off
   is truth only for intent. If its TL;DR/next-action contradicts git (claims work undone that
   `git -C <worktree> log` / `log <branch>..<target>` shows landed, or vice versa), **surface the
   contradiction** instead of presenting the stale claim as the plan. Two stream-state facts are
   hard stops: `rebase_in_progress=true` (an interrupted sync/ship holds the tree — diagnose/abort
   before anything else) and `nested_stray_handoff=true` (a forked save — reconcile the two copies,
   keep the Coordinates-addressed one, delete the stray).
4. Run the **Confident launch** (`flow.md`): classify the stream's state from the hand-off and
   either state the KNOWN next action with a one-word confirm, or offer an AMBIGUOUS pick. Do **not**
   "wait for direction" — act with confidence; a baseline-verify, if warranted, is your own first
   autonomous step. After the single confirm, build to completion.
