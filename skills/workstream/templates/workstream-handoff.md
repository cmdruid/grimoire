# <stream> — workstream hand-off

_Live save-state. Worktree-local (ignored, never merges). Rewritten by `/workstream save`._

## START HERE (before any edit or commit)
Verify you are on the right tree, using the Coordinates below:
- `git -C <worktree> rev-parse --show-toplevel` MUST equal `<worktree>`.
- `git -C <worktree> branch --show-current` MUST equal `<branch>`.
If either mismatches, **STOP** — do not edit or commit. A dispatched sub-agent cannot hold a
worktree; this must be a session rooted in the worktree. Getting it wrong corrupts `main`.

**In-place streams (`isolation: in-place`):** `<worktree>` IS the root checkout, so the toplevel
test is unchanged. The branch test is the CUSTODY check: HEAD not on `<branch>` means the stream
does not hold the tree — if Queue state says `Parked: true` and HEAD is on `<target>`, the stream
is parked (resume = unpark, `verbs/park.md`); anything else is foreign movement — STOP and report,
never auto-switch.

Discipline: every git command uses `git -C <worktree>`; every file op uses an absolute path;
the main session is the sole writer — subagents author read-only (via `/mailbox` slots or their own
isolated worktree), never editing the shared tree.

## Coordinates (worktree/root/branch/target are immutable; `source`/`source-kind` may be updated by `recycle` on repurpose)
- stream:        <stream>
- branch:        stream/<stream>
- integration-target: <branch the stream is based on AND ships into — the trunk checked out at create>
- worktree:      <abs path to .workstreams/<stream>>
- root checkout: <abs path to repo root>
- source:        <plan path, roadmap-section pointer, template path, or `(none — brief only)`>
- source-kind:   <plan | roadmap | brief | template — `template` (a `kind: workstream-template` doc) is the
                  re-appliable intake source `/workstream recycle` reloads to start a fresh unit>
- mode:          <delegate (default) | manual — execution mode (see the skill's *Execution mode*).
                  `manual` swaps the main-loop model per PLAN/BUILD/SHIP phase (attended); `delegate`
                  keeps one orchestrator + `/mailbox` delegates (autonomous).>
- isolation:     <worktree (default) | in-place — where the stream lives. `worktree`: its own
                  checkout under `.workstreams/`. `in-place`: the branch is checked out in the ONE
                  shared tree, which the stream holds (custody — `verbs/park.md`); `worktree:` above
                  then records the ROOT path.>
- landing:       <local (default) | push | pr — what `ship` does after the gate (in-place streams;
                  worktree streams record `local`). `local`: stop after the local trunk advance.
                  `push`: also push `<target>` to the remote. `pr`: push the branch + open a PR
                  instead of advancing locally; the queue advances when the PR merges.>
- id-trackers:   <OPTIONAL — omit when the host has no ID-bearing trackers. Space-separated
                  `<repo-relative-file>:<id-ERE>` pairs (e.g. `dev/ISSUES.md:E[0-9]+`) that
                  sync's post-rebase dup-ID check reads (`workstream-git.sh tracker-ids`,
                  `verbs/sync.md` step 2c). Portable-ERE rule: no `\b`.>
- this hand-off: <abs path to .workstreams/<stream>/WORKSTREAM.md>   (ignored; never merges)

## Hooks (compiled)
hooks-compiled: none @ none

feature-completion:
(empty)

after-eventful-ship:
(empty)

## Delegation route (confirmed once at create — persists across resets)
<Set at `create` (propose-and-confirm; see the skill's `create` step 6). **One of three states:**
- **a route** — the per-phase model map `/delegate` uses (its defaults, or a per-phase override like
  `implementation: <model>`). Models are opaque per-harness strings; the map itself is `/delegate`'s.
- **`inline-only`** — this stream delegates nothing (small tasks / tight loops). A *deliberate* choice,
  so a `0` delegation tally is **correct**, not a firing failure.
- **`unconfirmed`** — `create` ran unattended; defaults to inline until a human confirms. Re-confirm at
  the next human-present moment. Distinct from `inline-only`.

**Fallback policy** (provider failure is observable — handle it, don't stall): transient
(rate-limit/5xx/timeout) → bounded retry; persistent (quota/limit/unavailable/bad id) → re-route to
`<alternate, or inline>`; floor → **inline on the orchestrator** (always works); log each fallback as a
byproduct. See `/delegate` → *Failure states & durability*. The gate stays single-location in this
worktree regardless of who authored.>

## Ship cadence (confirmed once at create — persists across resets)
<Set at `create` (propose-and-confirm; see the skill's `create` step 6, and *Ship cadence* in the
skill's flow). `ship` is expensive, so this governs **how often the stream lands**. **One of three:**
- **`milestone`** (default) — land at the **track end** + at **critical milestones the agent nominates**
  (a coherent slice; a point a later feature/another stream depends on; a natural integration boundary).
  Completed features **accumulate on the branch** between milestones; the agent proposes each mid-track
  land at the feature-completion seam.
- **`per-track`** — land only when the whole queue is exhausted; everything accumulates and lands together.
- **`per-stage`** — land after every feature (eager; lowest divergence, highest land cost).

Deferring the land does **not** defer debrief or reset (those couple to the reset, not the ship). An
accumulating stream must **sync proactively** — divergence/conflict risk grows while work is held. The
agent may re-propose a one-off override at a seam; the recorded value governs by default.
**Template/intake streams** (`source-kind: template`) are inherently per-unit — `per-stage`, no milestone batching.>

## Phase model map (`manual` mode only — confirmed once at create; persists across resets)
<Set at `create` when `mode: manual` (propose-and-confirm; **omit this section in `delegate` mode** —
the *Delegation route* governs there). The default model per phase, cited by each phase-boundary park
instruction. The swap is a manual `/model` action, so any phase is overridable on the fly — this is the
reminder default, not a lock.
- PLAN:  <strong model, e.g. Opus>   — `/blueprint spec`; `/contractor plan` only when sequencing is required
- BUILD: <mid model, e.g. Sonnet>    — `/contractor build` when a contractor plan exists; otherwise the host lane walks the spec's slices + the compiled hook **Feature completion** (skip the glue command if empty)
- SHIP:  <strong model, e.g. Opus>   — `/workstream ship` (land, conflict-resolve) + the compiled hook **After eventful ship** (skip the glue command if empty; only when the ship was eventful)>

## TL;DR
<What shipped, where it stands, and the single recommended next action.>

## Stream / queue
<Plan-bound: pointer to the plan or roadmap section + its current forward queue.
Brief mode: the brief text. Unplanned: "No queue yet — define the goal in the first iteration."
Template/intake: the template's durable doctrine is embedded below (mission / governing principle / toolbox /
lessons); there is NO predefined queue — each unit is independent (the next bug, the next design).
`ship` lands a unit, then `/workstream recycle` clears this instance back to a blank unit from the template.>

## Cheat sheet (orientation map)
_A SNAPSHOT built by `create` from the plan + a read-only sweep, refreshed at `save` — orientation so
a resuming (or small-context) agent navigates this domain without re-exploring. **Verify a pointer
before trusting it**; `workstream-git.sh cheatsheet-check <worktree>` flags any that no longer resolve
at HEAD. Pointer-heavy by design (paths/IDs rot gracefully; pasted code rots silently)._
- built-against: <commit sha this map was last built/refreshed against>
- **Files / module map:** `<src/path>` — <one-line role>; key entry points + where systems register.
- **ADRs / design docs:** `<.records/adr/...>`, `<project: design docs>` — the decisions governing this domain.
- **Tests / scenarios:** `<unit-test modules>`, `<project: E2E/scenario files>` — what exercises this domain.
- **Gotchas / invariants:** the `<agent-workspace>/doctrine/core/GOTCHAS.md` traps + `.../core/INVARIANTS.md` invariants that bite here.

## Queue state
<Current feature; features shipped; **features completed-but-unshipped** (accumulated on the branch
under a deferred *Ship cadence*); queue remaining.
**`manual` mode:** also record `Phase: <plan | build | ship>` — the current phase, so `load` resumes
into it and reminds you of its model from the *Phase model map* above.
**In-place streams:** also keep a literal line `Parked: <true | false>` (line-start — the script
greps it) recording whether the tree is currently handed back to the trunk. After a `landing: pr`
ship, also keep `Open PR: <url or branch>` (line-start) until the PR merges and the deferred queue
advance runs (see `verbs/sync.md` step 0).>

## What's been done
<Shipped items; reconcile against `git -C <worktree> log` — it is the source of truth. Tag each shipped
feature with its delegation tally (debrief #1), e.g. `- <feature> — delegations: mailbox×2` or
`- <feature> — delegations: 0 (all inline)`, so `/delegate` adoption is visible across the stream.>

## What's next
<Prioritized; the immediate item must be unambiguous.>

## Pointers / open questions
<ADR / roadmap / reports this stream depends on; anything blocked on a decision or a cross-stream seam.>

## Loop routine (the flow — verbs are primitives; this orchestrates them)
Build the current feature to **completion** (autonomy rule): run all its tasks, committing as you go;
round-trip **only at a seam** — launch / blocker / genuine fork / feature-completion. **Saves are
coupled to the reset**, not to each task or verb (`sync` and `ship` do not save).
**Vocabulary guard:** in this session, "save a checkpoint" / "checkpoint this" means
**`/workstream save`** — never `/checkpoint`: this file IS the stream's checkpoint, and a
competing root `CHECKPOINT.md` corrupts the resume path (`/checkpoint` refuses here for that
reason).
The hand-off file's first heading carries its absolute path (`/checkpoint`'s
anchor-line technique). Speak that path at `save` / `load` / Recovery — not
as a prefix on ordinary status replies.

**Reset ritual** (whether Scenario A *lands* depends on *Ship cadence* above):
- **Feature complete, at a landing point (`per-stage` / a milestone / track end):** the compiled hook **Feature completion** (skip the glue command if empty)
  (#1 — routes the feature's follow-ups; its commits ride ship's ff-merge free) -> `/workstream ship`
  (lands every accumulated feature; plan-bound: advances the queue and drafts the next plan —
  except in `manual` mode, where the next PLAN session drafts it; template: no queue-advance,
  no draft — after the reset ritual, `/workstream recycle`) ->
  *(if the ship was eventful — conflicts, contention retries, multiple syncs)* the compiled hook **After eventful ship** (skip the glue command if empty; only when the ship was eventful) ->
  **`/workstream save`** (the single pre-reset checkpoint) -> reset -> `/workstream load <stream>`.
- **Feature complete, between landing points (`milestone`/`per-track`, not yet a milestone):**
  the compiled hook **Feature completion** (skip the glue command if empty) -> **`/workstream save`** (the feature-completion checkpoint — fires at
  every feature seam, reset or not) -> advance to the next feature *on the same branch* (**no
  ship**; under `milestone` first *propose* a land if this looks like a natural milestone) ->
  *(if context heavy)* reset -> `load`. Unshipped features stay on the branch for the next milestone.
- **Context heavy, mid-feature (Scenario B):** `/workstream save` -> reset -> `load` ->
  *(if `<target>` moved)* `/workstream sync` (which does **not** save).
- **Context polluted:** reset **without** save (rollback to the last save) -> `load` ->
  *(if `<target>` moved)* `sync`. (Rollback returns context to the last save; it does NOT undo
  commits — bad commits need `git reset`.)
- **Context auto-compacted (involuntary reset — Scenario C):** a compaction/continuation summary
  sits where your conversation should be -> STOP -> re-read this WORKSTREAM.md in full -> re-read
  the skill's `flow.md` -> run START HERE -> reconcile against `git log` + the durable records
  (they outrank the summary for anything committed) -> continue **without a user round-trip** if
  the next action is KNOWN. If compaction itself **failed** (refusal or out-of-room — the session
  is pinned at the limit): save if still possible, then reset / new session -> `load`.

**Between resets (autonomous):**
- Check if `<target>` moved (Coordinates integration-target): `git -C <worktree> log <branch>..<target>
  --oneline`. Non-empty -> a landing arrived (maybe a cross-stream seam); plan a `/workstream sync`
  before it piles up. **Under a deferred *Ship cadence*** (features accumulating on the branch),
  sync **more** proactively — held work widens divergence, so `sync`'s `land-readiness` conflict
  forecast matters most here.
- Capture follow-ups as the feature surfaces them (jot into *What's next* / *Pointers*); the formal
  routing is the compiled hook **Feature completion** (skip the glue command if empty) at completion (the host's PLANNING doc -> *When a plan completes*), the formal save is
  the pre-reset checkpoint.
- **`manual` mode** (Coordinates `mode: manual`): a feature is three model-phased sessions — PLAN
  (plan-model) -> BUILD (build-model) -> SHIP (ship-model) — and **every phase boundary is a save +
  park** for a `/model` swap (record the next `Phase:` before resetting). SHIP does **not** draft the
  next plan (PLAN does). Run unattended it parks at the first boundary — `manual` is attended-only.
  See the skill's *Manual mode: the phase loop*.
- **Template/intake stream** (`source-kind: template`, e.g. debug/design): a unit is done -> `ship` it, then
  `/workstream recycle` to clear this instance back to a blank unit from the template and start the next
  (worktree persists). `recycle` refuses if `wip_tracked=true` or `ahead>0` —
  `ship` or discard first. A lone `drafted_next_plan` is deleted, not a refuse. (This is the intake counterpart to a plan stream's queue-advance.)
- Stream's queue exhausted or paused -> `/workstream close`.
