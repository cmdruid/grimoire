# `recycle [<source>]`  · runs in the worktree (start a fresh unit/queue in place -- keep the worktree)

_Read `flow.md` alongside this verb — `recycle` ends by re-entering the loop it governs. It also
re-applies `verbs/create.md`'s *Source resolution* and *Hand-off instantiation* procedures, so have
that file at hand._

`recycle` = re-`create` in the same slot: re-instantiate the CURRENT worktree from its recorded
template or an explicit replacement source, keeping the worktree + branch (and its warm build),
skipping `worktree add`, the re-exclude, and the cold rebuild. The sanctioned complement to the
Scope guard ("don't spawn a NEW worktree from inside a stream; DO recycle the current one").

**Argument `recycle [<source>]`:**

- *omitted* -> re-apply the stream's recorded template (next unit, same kind); valid ONLY when
  Coordinates `source-kind` is `template` — otherwise STOP ("a plan/roadmap/brief stream advances
  via `ship`, or pass a replacement source to repurpose").
- *provided* -> resolve the argument using `create.md`'s **Source resolution** (its step 3). A
  template name/path behaves as before. A plan or roadmap must resolve to a readable regular file
  (optionally with a section anchor), and that underlying file must be tracked at `HEAD`; verify
  with `git -C <worktree> ls-files --error-unmatch <path-without-anchor>`.
  Requiring a tracked plan or roadmap prevents recycle's disposable-draft cleanup
  from deleting its own new source and ensures the next session can recover the queue from Git.
  A free-text brief is not an accepted
  replacement source. Update Coordinates `source` and `source-kind` to the resolved source;
  worktree, branch, target, isolation, and landing remain fixed.

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
4. **Re-instantiate the hand-off from the resolved source.** The file you write MUST equal the
   Coordinates `this hand-off:` line (the one absolute path). On mismatch, STOP — do not
   write. Inherit of create step 6 is **not** a transclude. After the path check (cwd is
   the worktree, line 1):
   1. `<root>` = Coordinates `root checkout:` (not `pwd`).
   2. Resolve `.agents/skilldata` the same way as create (first line-start
      fixed `<root>/.agents/skilldata`).
   3. Set `HOOKS_DIR=<root>/.agents/skilldata/workstream/hooks` (absolute).
      Never a relative directory.
   4. Run this skill's `hooks.sh parse --dir "$HOOKS_DIR"` with
      `--known feature-completion --known after-eventful-ship`. `status=fail` → STOP.
      Missing hooks compile as empty; recycle never creates the hook directory.
   5. Then regenerate that file exactly as `create.md`'s **Hand-off instantiation** (step 6) does
      for the resolved kind, **but in place** (no `worktree add`, seed-plan move, or exclude re-run):
      preserve the immutable Coordinates values and update only `source`/`source-kind`; keep the
      recorded `mode`, Ship cadence, and Delegation route by default. Template mode re-embeds the
      template's durable sections and blanks TL;DR, Queue state, What's been done, and What's next.
      Plan/roadmap mode rebuilds Stream/queue and Queue state from the replacement source, starts
      its per-unit sections fresh, and records the first forward item as the launch action. Blank
      per-unit sections **before** compile so the blank list cannot eat a just-written compiled
      span. Do **not** add `## Hooks (compiled)` to that blanked list.
   6. `hooks.sh compile --dir "$HOOKS_DIR" --handoff <this hand-off:> --root <root>`
      (`--root` optional; pass it). It is a FILE WRITE, never a commit — the hand-off is ignored.
5. **Refresh the cheat sheet.** Run `workstream-git.sh cheatsheet-check <worktree>`; lift current
   orientation pointers from the resolved source, prune/fix anything stale it flags, and set
   `built-against:` to the current `git -C <worktree> rev-parse --short HEAD`.
6. **Relaunch.** Run the **Confident launch** (`flow.md`). A replacement plan/roadmap with one clear
   first item is KNOWN; an intake template with no queue is AMBIGUOUS (offer "what's the next
   unit?"). The worktree and branch persist; nothing landed or tore down.

`recycle` **does not save** (it just rewrote the hand-off) and lands nothing — it is purely the
re-create-in-the-same-slot primitive. Pair it with `ship` before changing a queue or starting the
next template unit; the abandon case is an explicit discard (step 2) then `recycle`.
