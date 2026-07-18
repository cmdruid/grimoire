# `ship`  · runs at a cadence landing point (lands the accumulated feature(s); advances the queue; keeps looping)

_`ship` fires mid-loop, so `flow.md` (the cadence + reset ritual it hands back to) is normally
already in context from the session's `load`; if you are running a standalone `ship` and it is not,
read it. `sync` (`verbs/sync.md`) is step 1 of Landing below — read that file too._

## Landing — the shared land sequence (`ship`, and `close` when WIP remains, start here)

`<target>` = the workstream's `integration-target` (Coordinates) — the trunk it ships into; never
hardcode `main`.

> **Concurrent ships are safe by design — no lock needed.** The land is a single **ff-only** ref
> advance (step 3), which git serializes and *refuses* on a non-fast-forward. So if two streams ship
> in the same window, the second is **rejected**, not merged over — it just re-`sync`s onto the
> winner's new tip and retries. Correctness never depends on timing; the reject IS the queue. (A
> serializing mutex was considered and dropped as unneeded — the real cost was wasted re-gates from
> *incoming* changes, which step 2 now avoids, not landing races.)

1. `sync` (`verbs/sync.md`) so the branch sits on `<target>`'s tip. (`sync` never saves, so there is
   nothing to skip; the reset ritual makes the one save, after the queue has advanced.)
2. **Gate by what *lands*, not by "the tree moved."** Apply `verbs/sync.md` step 3's canonical
   **gate-by-what-lands matrix** to both axes of `workstream-git.sh gate-facts <worktree> <branch>
   <target>` (full gate only when both `own` and `incoming` are build-relevant; doc-linter only when
   `own_docs_only=true`; skip entirely when only the incoming side changed or nothing did). The
   ship-specific notes on top of that matrix:
   - **The skip case is the common case at a land** — most ships land only `.agents/dev/done/` records,
     roadmap rows, and plans, so a code stream should **not** pay a full gate run for a sibling's
     markdown (the *incoming-changes* waste the matrix exists to kill).
   - The doc-linter-only case holds **even after a code-heavy rebase**: markdown doesn't compile,
     and the incoming code is already green on `<target>` (ISSUES W16/W8).
   - **`incoming_empty=true`** (`sync` reported "up to date", no replay): the loop's last green gate
     still holds — don't re-run anything.
3. **Advance `<target>` by ref — independent of what the root has checked out.** Read
   `workstream-git.sh land-readiness <root> <worktree> <branch> <target>` (SKILL.md -> *Helper
   scripts*):
   `ff_safe` (false ⇒ `<target>` moved; re-`sync` before advancing), `root_on_target`, `root_dirty`
   (+ `root_dirty_paths`). Branch on `root_on_target`:
   - **`root_on_target=true`** (root is on the trunk): check `root_dirty` first. If **`root_dirty=true`**
     (a sibling session is editing the trunk directly), `merge --ff-only` aborts the moment a dirty
     path overlaps the merge — so don't attempt-then-abort. Surface it instead: name the
     `root_dirty_paths` and ask their owner to commit or stash them. **Never** stage, commit, or stash a sibling's uncommitted work yourself — it isn't
     yours and the root index is shared (a stash would also sweep unrelated dirty paths). Once the root
     is clean, `git -C <root> merge --ff-only <branch>`. This is a *third* contention mode beyond the
     rejected-advance race below: a **dirty** trunk, not a *moved* one — and note the trunk can be both
     (clearing the dirt often means the owner *commits*, which then moves `<target>` and rejects the
     ff, sending you to re-`sync`). (The host's worktree doc → *Shared trunk is contended*.)
   - **`root_on_target=false`** (root is on another branch): `git -C <root> fetch . <branch>:<target>` — an ff-only ref
     advance (no `+` prefix; refuses a non-ff; never touches the occupied working tree). This path is
     **immune to a dirty root** — it updates only the ref, so prefer it whenever the root is off-trunk.
   If the advance is **rejected** (a sibling moved `<target>` in the window), re-`sync` and retry (the
   re-`sync` may re-surface the additive ledger conflict — resolve "keep both" and continue) — the
   reject is the contention guard, not an error. *Edge:* if `fetch` refuses because `<target>` is
   checked out in a non-root worktree, land from that checkout instead.

## In-place streams — the same Landing, plus the landing-mode tail

An in-place stream (Coordinates `isolation: in-place`) lands through the SAME sequence above, with
`<worktree>` = the root path. While the stream holds the tree, `root_on_target=false` by
construction, so for `landing: local | push`, step 3 is always the by-ref `fetch . <branch>:<target>`
path — immune to the tree's state (`landing: pr` SKIPS step 3 entirely — see its bullet). Three
additions:

- **Custody first (before anything):** `inplace-state` must report `on_stream_branch=true`. A
  parked or foreign-held tree fails the "by construction" premise above — while parked, sync's
  rebase silently no-ops and Landing step 3 would land the stream INCLUDING its `wip:` bank commit
  onto `<target>`. Parked → resume via `load` (which unparks) first; foreign → STOP and report.
- **WIP boundary (before step 1):** the stream's tree IS the root, so uncommitted work sits next to
  the land. If `inplace-state` reports `dirty=true`, STOP and resolve first (commit it, or park it
  out of the land) — never land around uncommitted custody-held work.
- **After the advance, run the recorded `landing:` tail:**
  - **`local`** — done (the worktree-stream behavior).
  - **`push`** — `git -C <root> push origin <target>`. A rejected push (the remote moved) →
    `git -C <root> fetch origin <target>:<target>` (works while custody is held — `<target>` is not
    checked out), re-`sync`, re-advance, retry the push. The reject is the contention guard, same
    doctrine as the local ff-advance.
  - **`pr`** — do NOT advance `<target>` locally. Instead: `git -C <root> push origin <branch>`,
    then `gh pr create --base <target> --head <branch> --title "<feature subject>" --body "<the
    .agents/dev/done records this lands>"`. The queue does NOT advance at ship — it advances when the PR
    merges, checked at the next `sync`/`load` (`git -C <root> fetch origin` then `git -C <root>
    log <branch>..origin/<target>` contains the merge, or `gh pr view <branch> --json state`).
    Step 3 of the ship procedure (queue advance) is deferred accordingly; record a line-start
    `Open PR: <url or branch>` line in the hand-off's Queue state (the deferred-advance marker
    `sync` checks).

## The ship procedure

`ship` fires at a *Ship cadence* landing point (`per-stage`: every feature; `milestone`: an
agent-nominated boundary + track end; `per-track`: track end only), so it may land **one feature or
several accumulated since the last ship** — the steps below loop over *all* of them. (A manual
`/workstream ship` always lands now regardless of cadence — that is the deliberate-override path.)

A stream's own shipping records ride **on the branch** and reach `<target>` (Coordinates
`integration-target`) only through the by-ref advance (Landing step 3) — the single operation that
touches the shared root, and it fails safe (a rejected advance just means re-sync and retry),
independent of what the root has checked out. Never hand-commit these records to the root.

1. **Commit the shipping records on the branch — BEFORE landing.** These are doc-only, so gate them
   with the host's fast doc-linter (from the worktree), not the full gate:
   - **A record per accumulated feature.** For **each** feature completed since the last ship (one under
     `per-stage`; possibly several under `milestone`/`per-track`), write `.agents/dev/done/<YYYY-MM-DD>-<slug>.md`
     (add a `-N` suffix if a same-day record for that slug exists). **Reference the feature's commits by
     subject line, NOT by sha:** Landing (step 2) rebases this branch *after* this record is written,
     which rewrites every sha but **preserves subjects** — a sha-cited record would strand dead refs and
     need a correction commit (worse under deferred cadence: many records, and contention can force
     *several* rebases per ship; subject-refs survived two contention rebases with zero fixups). **Open
     each with the `type: done-record` frontmatter block** (`type`/`status: shipped`/`updated`), from
     `.agents/dev/templates/done-record.md` -- the doc-linter gate rejects a `.agents/dev/done/` file without it (schema:
     the done-record template `/foreman` owns, `foreman/templates/done-record.md` -- a done-record
     is a foreman artifact, not a capture kind, so it's not in `/backlog`'s TAXONOMY.md). Then `git -C <worktree> add .agents/dev/done/<f> && git -C <worktree> commit -m "Record <slug> shipped" -- .agents/dev/done/<f>`.
   - If the feature had its own implementation plan, archive it in one atomic commit:
     `git -C <worktree> mv .agents/dev/plans/<feature-plan> .agents/dev/plans/archive/ && git -C <worktree> commit -m "Archive <feature-plan>" -- .agents/dev/plans/<feature-plan> .agents/dev/plans/archive/<feature-plan>`.
   - If the queue is tracked in a roadmap doc, update its ledger/queue row for this stream and commit
     it on the branch too: `git -C <worktree> commit -m "Roadmap: <stream> shipped <feature>" -- <roadmap-path>`.
     (At `sync` this may additively conflict with a sibling stream's row — resolve "keep both".)
2. **Land** (the shared sequence above): `sync` (rebase — replays the feature + these records onto
   `<target>`'s tip; resolve any additive ledger conflict), gate only if the tree changed, then
   **advance `<target>` by ref** (Landing step 3 — `merge --ff-only` if the root is on `<target>`,
   else `fetch . <branch>:<target>`). That ref advance delivers the feature AND its records
   atomically; it is the only shared-root mutation and is independent of the root's current HEAD.
3. **Advance the queue — hand-off only** (the ledger row already rode the branch in step 1): in the
   (ignored) worktree hand-off, mark **all landed features** done and set the next queue item current.
   Then **draft** the next feature's implementation plan from the queue source into `.agents/dev/plans/` (a
   working-tree draft — it rides the *next* ship; do not commit it now). Do not start the next
   feature automatically. **In `manual` mode, skip this draft** — plan-authoring belongs to the next
   PLAN session on the plan-model (`flow.md` -> *Manual mode: the phase loop*); set `Phase: plan`
   instead and PLAN starts the draft fresh.
4. The worktree and branch PERSIST — `ship` never tears down. Confirm the ff-merge carried no
   `WORKSTREAM.md`: `git -C <root> show --stat HEAD` lists no `.workstreams/...` path.
5. **`ship` does not save.** Hand back to the flow's **reset ritual** (`flow.md`, Scenario A): if the
   ship was
   *eventful* run `debrief` #2, then make the single **pre-reset `save`** (advanced queue + drafted
   next plan), then STOP and advise a reset before the next feature (context is heavy). The save lives
   in the ritual, not here — so a manual `/workstream ship` leaves no checkpoint behind unless a reset
   is actually imminent. (In `manual` mode the pre-reset save records `Phase: plan` and the park swaps
   to the plan-model for the next feature's PLAN — `flow.md` -> *Manual mode: the phase loop*.)
