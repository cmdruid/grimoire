# `recycle [<template>]`  · runs in the worktree (start a fresh unit/stream in place -- keep the worktree)

_Read `flow.md` alongside this verb — `recycle` ends by re-entering the loop it governs. It also
re-applies `verbs/create.md`'s *Source resolution* and *Hand-off instantiation* procedures, so have
that file at hand._

`recycle` = re-`create` in the same slot: re-instantiate the CURRENT worktree as a fresh stream from a template,
keeping the worktree + branch (and its warm `target/` build), skipping `worktree add`, the re-exclude,
and the cold rebuild. The sanctioned complement to the Scope guard ("don't spawn a NEW worktree from
inside a stream; DO recycle the current one").

**Argument `recycle [<template>]`:** *omitted* -> re-apply the stream's recorded template (next unit,
same kind); valid ONLY when Coordinates `source-kind` is `template` — otherwise STOP ("a
plan/roadmap/brief stream advances via `ship`, or pass a template name or path to repurpose").
*provided* -> resolve the argument using `create.md`'s **Source resolution** (its step 3): a
bare name (`debug`/`design`) resolves from the skill's OWN `templates/` base directory;
a path points to a project's `kind: workstream-template` doc. (`coordinator` is not a
create/recycle template — it is read directly on the trunk.) Repurpose the worktree from the resolved
template (update Coordinates `source`/`source-kind`; the worktree+branch identity persists -- a
recycled slot; for a clean-named stream, `close`+`create` instead and pay the rebuild).

1. **Eligibility — any worktree may recycle.** The gate is the work-guard (step 2), not `source-kind`
   (any worktree archetype may recycle; `source-kind` gates only the *arg-omitted* form above).
2. **Guard — refuse on un-dealt-with work.** Run `workstream-git.sh stream-state <worktree> <branch>
   <target>`. If `wip_tracked=true` (real uncommitted edits) **or** `ahead>0` (committed but
   unshipped), STOP: the current unit isn't resolved. Direct the user to **`ship`** it (if done) or
   discard it explicitly (a `git -C <worktree> reset --hard` / checkout is the user's call — recycle
   never destroys work silently). Do **not** key on `dirty=true`: an untracked plans draft is
   expected dirt (`drafted_next_plan`, `wip_tracked=false`). If that is the only dirt, **delete
   each path listed in `drafted_next_plan`** (comma-separated; uncommitted; recycle's job is a
   blank unit) and continue. Do not ask. Do not `rm` a guessed plans glob. Only a
   fully-shipped tree with no real WIP may recycle.

   **In-place streams** (Coordinates `isolation: in-place`): run the custody check first —
   `inplace-state` must report `on_stream_branch=true` (parked → `load`/unpark first; foreign →
   STOP). The hand-off lives at `<root>/.workstreams/<stream>/WORKSTREAM.md` (Coordinates
   `this hand-off:`), not `<worktree>/WORKSTREAM.md`; step 5's cheatsheet-check needs that path
   passed explicitly: `cheatsheet-check <root> <root>/.workstreams/<stream>/WORKSTREAM.md`.
3. **(If `<target>` moved) re-baseline.** If `behind>0`, run `sync` (`verbs/sync.md`) first so the
   fresh unit starts on
   the current trunk tip (same rebase + scoped re-gate as `sync`).
4. **Re-instantiate the hand-off from the template.** The file you write MUST equal the
   Coordinates `this hand-off:` line (the one absolute path). On mismatch, STOP — do not
   write. Then regenerate that file exactly as `create.md`'s **Hand-off instantiation**
   (step 6) does for template mode, **but in place** (no `worktree add`, no exclude re-run —
   already done): **preserve the Coordinates block verbatim** (fixed for the stream's life); if a new
   template was passed, update Coordinates `source`/`source-kind` to match; re-read the template at
   `source:` and **re-embed its durable sections** (so an evolved template propagates), keeping recorded
   `mode`/`Ship cadence`/`Delegation route` by default; and **blank the per-unit sections** (TL;DR,
   Queue state, What's been done, What's next). It is a FILE WRITE, never a commit — the hand-off is ignored.
5. **Refresh the cheat sheet.** Run `workstream-git.sh cheatsheet-check <worktree>`; lift the template's
   current orientation pointers, prune/fix anything stale it flags, and set `built-against:` to the
   current `git -C <worktree> rev-parse --short HEAD`.
6. **Relaunch.** Run the **Confident launch** (`flow.md`) into the fresh, undefined unit — for an
   intake stream that is the AMBIGUOUS path (no queue): offer the pick "what's the next unit?" The
   worktree and branch PERSIST; nothing landed or tore down.

`recycle` **does not save** (it just rewrote the hand-off) and lands nothing — it is purely the
re-create-in-the-same-slot primitive. Pair it with `ship` (finish unit A -> `ship` -> `recycle` ->
unit B); the abandon case is an explicit discard (step 2) then `recycle`.
