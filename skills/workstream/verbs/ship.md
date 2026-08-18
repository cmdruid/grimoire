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
   <target> <BASE>` — threading the pre-rebase `BASE` step 1's sync captured, exactly as sync's
   step 3 requires (post-rebase, an un-threaded call reads `incoming_empty=true` on a stale axis
   and wrongly selects the skip branch). Full gate only when both `own` and `incoming` are
   build-relevant; doc-linter only when
   `own_docs_only=true`; skip entirely when only the incoming side changed or nothing did. The
   ship-specific notes on top of that matrix:
   - **The skip case is the common case at a land** — most ships land only record closures (a
     plan's status flip + its ledger line), debrief reports, and roadmap rows, so a code stream
     should **not** pay a full gate run for a sibling's markdown (the *incoming-changes* waste the
     matrix exists to kill).
   - The doc-linter-only case holds **even after a code-heavy rebase**: markdown doesn't compile,
     and the incoming code is already green on `<target>` (ISSUES W16/W8).
   - **`incoming_empty=true`** (`sync` reported "up to date", no replay): the loop's last green gate
     still holds — don't re-run anything.
3. **Advance `<target>` by ref — independent of what the root has checked out.** Read
   `workstream-git.sh land-readiness <root> <worktree> <branch> <target>` (SKILL.md -> *Helper
   scripts*):
   `ff_safe` (false ⇒ `<target>` moved; re-`sync` before advancing), `root_on_target`, `root_dirty`
   + **`root_dirty_overlapping`** (+ paths), and **`staged_uncommitted`**.
   **Staged-index guard first:** if `staged_uncommitted=true` in the worktree, STOP and resolve
   (commit or unstage the listed paths) before landing — staged-but-uncommitted entries are the
   strand signature of a `git mv` whose pathspec commit named only one half, and the gate reads the
   working tree, so nothing else catches it before the land carries it wrong. Then branch on
   `root_on_target`:
   - **`root_on_target=true`** (root is on the trunk): key on **`root_dirty_overlapping`**, not the
     bare `root_dirty` — `merge --ff-only` aborts only when a dirty path OVERLAPS the merge's
     changed set, and the coordinator-on-main model makes *disjoint* sibling WIP the common case.
     **`root_dirty_overlapping=false`** → proceed: `git -C <root> merge --ff-only <branch>` (the
     disjoint dirt is untouched). **`root_dirty_overlapping=true`** → don't attempt-then-abort:
     name the `root_dirty_overlap_paths` and ask their owner to commit or stash them. **Never**
     stage, commit, or stash a sibling's uncommitted work yourself — it isn't
     yours and the root index is shared (a stash would also sweep unrelated dirty paths). Once the overlap
     is clear, `git -C <root> merge --ff-only <branch>`. This is a *third* contention mode beyond the
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
    shipped units this lands>"`. The queue does NOT advance at ship — it advances when the PR
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
   with the host's fast doc-linter (from the worktree), not the full gate. A shipped unit's durable
   trace is a **plan close plus an optional debrief report**, under the agent-records home on
   every host. If `<agent-records>/scripts/records.sh` is executable, use it (`done` /
   `new --template <resolved>`); else file-mode stamp of `status:` / `updated:` only — do
   not write `history.tsv`. Ledger commit path only when `history.tsv` was actually written.
   - **Close each accumulated feature's plan record in place.** For **each** feature completed
     since the last ship (one under `per-stage`; possibly several under `milestone`/`per-track`)
     whose plan lives in the `plans/` store, run (in the worktree)
     `records.sh done plans/<its-plan>.md --note "shipped: <feature subjects>"` when the tool
     exists; else rewrite `status:` / `updated:` on the plan file. **Reference the feature's
     commits by subject line, NOT by sha** in the note and any narrative: Landing (step 2)
     rebases this branch *after* these records are written, which rewrites every sha but
     **preserves subjects**. Commit the flip and, when written, the ledger together:
     `git -C <worktree> add <plan> [<agent-records>/history.tsv] && git -C <worktree> commit -m
     "Record <slug> shipped" -- <plan> [<agent-records>/history.tsv]`. A feature with **no**
     plan record (a roadmap row built directly) is completed by its roadmap ledger-row
     advance below — never mint a record just to close it.
   - **A debrief report when the unit warrants narrative** — implementation surprises, follow-on
     context a future reader needs beyond the ledger line: resolve `reports.md` via the
     agent-templates rule; `records.sh new reports --template <resolved>` when the tool
     exists; else file-mode from that path. Tag it `debrief`, write findings-first, commit
     it on the branch. A routine unit needs no report.
   - **Complete the queue item's tracker line** only when that tracker file already exists:
     flip `[ ]` → `[x]` (append the completion date) and opportunistic `records.sh touch`
     (or file-mode stamp). Else record the ship in the plan close / hand-off / the
     project's own tracker layout. Do not mint a Backlog tracker.
   - If the queue is tracked in a roadmap doc, update its ledger/queue row for this stream and commit
     it on the branch too: `git -C <worktree> commit -m "Roadmap: <stream> shipped <feature>" -- <roadmap-path>`.
     (At `sync` this may additively conflict with a sibling stream's row — resolve "keep both". The
     same applies to `history.tsv` — append-only, so a sibling's ship conflicts additively; keep both
     lines.)
2. **Land** (the shared sequence above): `sync` (rebase — replays the feature + these records onto
   `<target>`'s tip; resolve any additive ledger conflict), gate only if the tree changed, then
   **advance `<target>` by ref** (Landing step 3 — `merge --ff-only` if the root is on `<target>`,
   else `fetch . <branch>:<target>`). That ref advance delivers the feature AND its records
   atomically; it is the only shared-root mutation and is independent of the root's current HEAD.
3. **Advance the queue — hand-off only** (the ledger row already rode the branch in step 1).
   **If Coordinates `source-kind: template`:** do not invent a next queue item and do not
   draft a next plan. Mark the landed unit done in the hand-off (TL;DR / What's been done).
   Leave step 5's reset ritual in place; `recycle` is the *flow's* next action after that
   ritual (`flow.md` Scenario A), not something this step calls.
   **Otherwise** (plan / roadmap / brief): in the (ignored) worktree hand-off, mark
   **all landed features** done and set the next queue item current.
   Then **draft** the next feature's implementation plan from the queue source into
   `<agent-records>/plans/` (resolve `plans.md` via the agent-templates rule;
   `records.sh new --template <resolved>` when the tool exists; else file-mode fill) —
   a working-tree draft: it rides the *next* ship; do not commit it now. Do not start the next
   feature automatically. **In `manual` mode, skip this draft** — plan-authoring belongs to the next
   PLAN session on the plan-model (`flow.md` -> *Manual mode: the phase loop*); set `Phase: plan`
   instead and PLAN starts the draft fresh.
4. The worktree and branch PERSIST — `ship` never tears down. Confirm the ff-merge carried no
   `WORKSTREAM.md`: `git -C <root> show --stat HEAD` lists no `.workstreams/...` path.
5. **`ship` does not save.** Hand back to the flow's **reset ritual** (`flow.md`, Scenario A): if the
   ship was
   *eventful* run `debrief` #2, then make the single **pre-reset `save`** (plan-bound: advanced queue + drafted next plan; template: landed unit marked done, no draft), then STOP and advise a reset before the next feature (context is heavy). The save lives
   in the ritual, not here — so a manual `/workstream ship` leaves no checkpoint behind unless a reset
   is actually imminent. (In `manual` mode the pre-reset save records `Phase: plan` and the park swaps
   to the plan-model for the next feature's PLAN — `flow.md` -> *Manual mode: the phase loop*.)
