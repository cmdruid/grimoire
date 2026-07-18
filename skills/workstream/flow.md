# The flow — agent orchestration of the workstream loop

_Read this file when ENTERING the loop — `create`, `load`, or `recycle` (their verb files send you
here). It governs behavior *between* verb invocations: when to keep building, when to round-trip,
when to save, when to land. Mid-loop verbs (`sync`, `ship`, `save`) assume it is already in
context from the session's loop entry; if you are running one standalone and it is not, read it._

## Execution mode — `delegate` (default) or `manual`, chosen at create

A stream runs in one of two modes for matching *the right model to the right work*. Both pursue the
same goal; they differ in **transport**, and the mode is proposed-and-confirmed at `create` (like the
delegation route and ship cadence) and recorded in the hand-off Coordinates `mode:`.

- **`delegate`** (default) — **one resident orchestrator** (a strong main-loop model) that farms
  model-matched pieces to `/mailbox` delegates per `/delegate`'s table (see *Per-phase model routing*
  under the autonomy rule). Resets happen only at feature/heavy-context boundaries. This is the
  **autonomous-friendly** mode — the loop never needs a human to change models, so a `/loop`/cron run
  keeps moving on its own.
- **`manual`** — the **main-loop model itself changes per phase**. A feature is built as three explicit
  model-phased sessions — **PLAN -> BUILD -> SHIP** — and at each phase boundary the loop saves, then
  **parks** with an instruction to swap `/model` and `/workstream load`. The cheaper model actually
  *drives* the build (not merely executes under a strong orchestrator), and planning context is shed
  before build. The model swap is a **human `/model` action the skill cannot perform itself**, so
  `manual` is the **attended** mode — run unattended it simply parks (no progress) rather than
  proceeding on the wrong model. See *Manual mode: the phase loop* below.

Mode is orthogonal to *Ship cadence* and the *Delegation route*: a `manual` stream still has a cadence
(it governs when SHIP fires) and may still delegate **for fan-out** (parallel Explore, mechanical
sweeps) — but in `manual` mode delegation is **not** the model lever (the session model already *is*
the phase model), so `/feature build`'s per-phase model routing is off.

## The three rules

Three rules the agent runs autonomously between user touches: the **autonomy rule** (build to
completion), the **seam rule** (round-trip only at the catalogued seams), and the **reset ritual**
(how saves + debriefs sequence around a reset).

### Autonomy rule — build a feature to completion (don't stop per task)

When you build a feature (executing its plan's tasks/phases), run **all** of them, one after the
next, committing as you go. Do **not** stop after each task to ask "should I continue?" or to post a
progress summary — the user asked you to build the feature, so build it; per-task check-ins waste
their time. **Pause only at a seam** (below). When the plan is complete you enter the **reset ritual**
(`debrief` -> `ship` -> `save` -> reset) — the one place the loop deliberately pauses, **between
features, never between tasks**. If you catch yourself about to end a turn mid-plan with no blocker
and no question, that is the failure this rule exists to prevent — keep going.

**In `manual` mode, "to completion" is per *phase*.** The autonomy rule still holds *within* a phase —
run the phase's work (all of PLAN, or all of BUILD's tasks) without per-task check-ins — but the unit
you build to completion is the **phase**, not the whole feature: at each phase boundary you save and
**park** for the model swap (see *Manual mode: the phase loop*). In `delegate` mode the unit is the
whole feature, exactly as above.

**The build itself is `/feature`'s job, when available.** If the `/feature` skill is installed, run
the plan with **`/feature build <plan>`** — its execution discipline is already worktree-aware
(mode-routed authoring — inline, `/mailbox` patch, or isolated worktree, with the main session always
the **sole writer**; artifact-free, red-first, ends at gate-green) and **hands back** here, so
`/workstream` keeps owning the reset ritual (`/feature` never ships or debriefs). **Per-phase model
routing (`delegate` mode):** `build` may dispatch each phase to a model-matched delegate via `/mailbox`, routed per the
`/delegate` skill's model-routing table. (**In `manual` mode this is off** — the BUILD session is
already on the build-model, so `build` runs inline; delegation stays available only for fan-out/grunt,
never as the model lever.) The route is **confirmed once and recorded in the hand-off**
(*Delegation route* section) so an autonomous loop never stalls re-asking it, and provider failures
(quota/limit/outage) **degrade per `/delegate`'s fallback ladder -- down to inline on the orchestrator --
rather than blocking the loop**. Delegates author read-only into a `.mailbox/` slot the orchestrator
applies and gates. The **gate stays single-location** in this worktree regardless of who authored the
change. Earlier stages map
the same way: `/feature brainstorm | design | plan` produce the queue's design/plan artifacts. When
`/feature` isn't installed, build the plan **by hand** per the host's `.agents/dev/docs/PLANNING.md` — the
loop is unchanged either way; `/feature` is the preferred *realization*, not a hard dependency. (The
seam ownership is the contract: whoever builds, `build` stops at gate-green and `/workstream` lands +
debriefs.)

### Seam rule — the only places the agent round-trips

Round-trip to the user *only* at these four seams; everything else is autonomous. Each remaining
touch is a **one-word confirm or a structured pick** — never a per-task check-in. This is the
round-trip/token payoff.

1. **Launch** (after `create` / `load`) — classify the stream state and either confirm a KNOWN next
   action or offer an AMBIGUOUS pick (see *Confident launch*).
2. **Blocker** — something you cannot resolve: surface it + ask.
3. **Genuine fork mid-build** — a decision that changes *what* gets built: ask.
4. **Feature completion** — debrief #1, then act on the stream's *Ship cadence*: at a landing point
   (`per-stage`, an agent-nominated milestone, or track end) **confirm before `ship`** (the land is the
   irreversible-ish step) and recommend a second debrief if the ship was *eventful*; **otherwise do
   not ship** — advance to the next feature (under `milestone`, first *propose* a land if this looks
   like a natural milestone). Either way, recommend a reset if context is heavy.

**`manual` mode adds phase-boundary seams.** Beyond the four above, a `manual` stream round-trips at
each **phase boundary** (PLAN->BUILD, BUILD->SHIP, SHIP->next PLAN): the loop saves and **parks** for
the `/model` swap. These are *reset* seams, not per-task check-ins — within a phase the autonomy rule is
unchanged. (`delegate` mode has only the four.)

**In-place streams add the park seam.** An in-place stream (Coordinates `isolation: in-place`)
holds the one shared tree, so an interruption that needs the tree — a trunk hotfix, another
session, a teammate's pull — is its own seam: **`park`** (save → bank WIP as a `wip:` commit →
hand the tree to the trunk; `verbs/park.md`), resume later by `load`, which unparks. Park is
save-first, same discipline as the reset ritual; a parked stream loses nothing.

### Confident launch (after create / load / recycle) — KNOWN -> confirm, AMBIGUOUS -> pick

Replaces the old "wait for direction." Classify the stream's state and act with confidence. **Gather
it token-free first:** run `workstream-git.sh stream-state <worktree> <branch> <target>` (SKILL.md ->
*Helper scripts*) — its facts ARE the KNOWN-vs-AMBIGUOUS input (`behind>0` -> sync; a clean
`ahead`/`dirty` with a `drafted_next_plan` -> next queue item; `wip_tracked` -> resume mid-feature) —
and `cheatsheet-check <worktree>`, flagging any stale orientation pointer (in-place: plus the
hand-off path — see SKILL.md *Helper scripts*). Then:

- **KNOWN** (one clear next action) -> state it + a **simple confirm**: "Next: continue Task 4
  (template refactor). Proceed?" Covers mid-feature with an obvious next task, a shipped feature with
  a defined next queue item, or main-moved -> `sync`. A baseline-verify (a host build + the host's
  gate), when warranted, is the agent's **own autonomous first step** — not a user choice.
  (Under a deferred *Ship cadence*, **several unshipped features on the branch is the expected steady
  state**, not a missed ship — continue to the next feature unless you are at a milestone or track end.)
- **AMBIGUOUS** (a real fork) -> a **sharp multiple-choice**: queue undefined/exhausted, a recorded
  blocker/open question, a contested approach, or several reasonable moves.
- **`manual` mode** (Coordinates `mode: manual`) -> the hand-off's `Phase:` IS the KNOWN next action:
  "Resume the BUILD phase (model: <build-model>). Proceed?" (On a fresh `create`, `Phase:` is the
  bootstrapped first phase — `plan`, or `build` for a plan-bound source.) **Always name the phase's
  recorded *Phase model map* model in the confirm and ask the human to be on it first** — the human owns
  the `/model` swap, and you cannot reliably introspect which model you are, so state the target rather
  than trying to detect a mismatch.

**Verify a queued item is still real before offering it *to build*.** A `.records/tasks.md` / roadmap item
can already be **shipped** — by a sibling stream, with the entry never pruned. Before presenting such an
item as buildable work (a KNOWN next-item *or* an AMBIGUOUS pick), cheaply confirm it isn't already done:
grep `.records/archive/` for the slug + glance at the code surface it names. A stale entry otherwise costs a
wasted question round-trip + an Explore dispatch before `build` discovers there is nothing to build.
(Same doctrine as `/feature plan`'s grounding gate: verify inherited/queued work is real before building it.)

After the single launch confirm, build to completion. (This is the same interaction for `create`'s
tail, `load`'s resume, and `recycle`'s relaunch — there is no separate per-verb menu.)

### Ship cadence — when the loop lands (per-stream, recorded at create)

`ship` is **expensive** (a full gate + a sync-rebase + the land sequence), so *how often* a stream
lands is a deliberate per-stream choice, **not** an automatic per-feature reflex. The cadence is
proposed-and-confirmed at `create` (like the delegation route) and recorded in the hand-off's
**`Ship cadence`** section; the autonomous loop honors it without re-asking. Three values:

- **`milestone`** (default) — land at the **track end** (queue exhausted) and at **critical milestones
  the agent nominates** along the way: a coherent, independently-valuable slice; a point a *later*
  feature or another stream depends on; or a natural integration boundary. Between milestones,
  completed features **accumulate on the branch** — each still debriefs and may trigger a reset, but
  does not ship. The agent **proposes** each mid-track land at the feature-completion seam ("Feature N
  done — natural milestone (X depends on it). Ship now, or keep accumulating?").
- **`per-track`** — land **only** when the whole queue is exhausted; never mid-track. Every feature
  accumulates and lands together. Lowest land cost; highest divergence/conflict risk and the longest
  delay before `<target>` sees the work.
- **`per-stage`** — land after **every** feature (the eager, historical behavior). Lowest divergence,
  highest land cost. Choose it when each feature must reach `<target>` promptly (a cross-stream
  dependency, a hot trunk).

**Deferring the land does NOT defer the debrief or the reset.** Route-before-loss still fires per
feature (debrief #1) and a heavy context still resets — those couple to the *reset*, not the *ship*.
Only the land is deferred; the completed feature stays on the branch and you start the next. **The
agent may re-propose a one-off override** at a seam (a `milestone` stream hitting an unplanned natural
boundary; a `per-track` stream grown risky to hold) — the recorded value governs by default, and an
override is a single confirm, not a re-config. **Holding features on the branch raises divergence**, so
an accumulating stream must **sync more proactively** as features pile up — the `land-readiness`
conflict forecast (folded into `sync`'s behind-check) earns its keep while work is held.

**Cadence governs plan/roadmap streams only.** A **template/intake stream** (`source-kind: template`) has no
queue of features to accumulate — each independent unit lands then `recycle`s, so the unit *is* the land
boundary (effectively `per-stage`). Record `per-stage` for a template stream and skip the milestone logic.

### Reset ritual — saves are coupled to the reset

**A save is justified only by imminent context loss.** The *only* saves are (1) a user manually
invoking `save`, (2) the flow's single **pre-reset checkpoint**, and (3) `park`'s custody hand-over
(in-place streams — a parked stream may next be resumed by a *different* session, so parking without
saving would strand the loop's state; `verbs/park.md`). No other verb saves — `sync` rebases +
gates and nothing else; `ship` lands + advances and nothing else. Two scenarios (Scenario A/B describe
`delegate` mode; **`manual` mode adds a third, phase-boundary reset** at every PLAN/BUILD/SHIP seam —
see *Manual mode: the phase loop*):

**Scenario A — feature-boundary reset** (a feature completed; the heavyweight path). Whether it
**lands** here is governed by the stream's *Ship cadence*:

> **at a landing point** (`per-stage`; a milestone; track end):
> `debrief` #1 -> `ship` -> *(if ship was eventful)* `debrief` #2 -> **save** -> reset -> `load`
>
> **between landing points** (`milestone`/`per-track`, not yet a milestone):
> `debrief` #1 -> advance to the next feature *on the same branch* -> *(if context is heavy)* **save**
> -> reset -> `load`   *(no ship)*

- **`debrief` #1** routes the *feature's* follow-ups; its tracker commits sit on the branch and
  **ride the eventual ship's ff-merge for free** — whether that ship is now or a later milestone.
- **`ship` — only at a landing point.** Lands **every accumulated feature** + their debrief commits,
  advances the queue past all of them, and drafts the next plan into the working tree (uncommitted — it
  persists on disk across the reset; **in `manual` mode `ship` skips this draft** — the next PLAN
  session authors it). Between landing points there is **no ship**: the completed
  feature stays on the branch and you start the next.
- **`debrief` #2 — conditional**: only if a `ship` actually ran *and* was *eventful* (see *Event-driven
  debrief*); its commits ride the *next* ship.
- **save** — the single pre-reset checkpoint (advanced queue + any drafted next plan), then **reset**.
  A reset may happen between landing points too (heavy context); the unshipped features simply remain on
  the branch for the next milestone.

**Scenario B — mid-feature reset** (context heavy or polluted; no feature finished):
> *(healthy but heavy)* **save** -> reset -> `load` -> *(if main moved)* `sync`
> *(context polluted)* reset **without** save -> `load` -> *(if main moved)* `sync`

The post-`load` `sync` does **not** save (there is no verb-save anymore); the next save is the next
pre-reset checkpoint. (Save-then-reset = checkpoint; reset-without-save = rollback to the last save.)

### Manual mode: the phase loop (only when Coordinates `mode: manual`)

In `manual` mode a feature is built as three model-phased sessions; each phase ends in the reset
ritual's **save** + a **park** for a `/model` swap. The hand-off records the current `Phase:` (`plan` |
`build` | `ship`) so `load` resumes into the right phase and reminds you of its model (from the
hand-off's *Phase model map*). The three phases, each ending `save -> park -> reset -> load`:

> **PLAN** (plan-model) — author the feature's plan: `/feature design` + `/feature plan` into
> `.records/plans/`. Then **save** (record `Phase: build`) -> **park**: "Plan ready. Switch to <build-model>
> (`/model <m>`), `/clear`, `/workstream load <stream>`."
>
> **BUILD** (build-model) — `/feature build <plan>` to gate-green, then `/backlog debrief` #1 (the
> feature's follow-ups). Then act on *Ship cadence*: **at a landing point**, **save** (`Phase: ship`)
> -> park for the ship-model swap. **Between landing points**, **save** (`Phase: plan` for the *next*
> feature) -> park for the plan-model swap. (Completed features still accumulate on the branch; only
> SHIP lands.)
>
> **SHIP** (ship-model) — `/workstream ship` (land + advance the queue), *(if eventful)* `/backlog debrief`
> #2. Under a deferred *Ship cadence* this one SHIP phase lands the **whole accumulated batch** (every
> feature built since the last ship), not just one. Then **save** (`Phase: plan`) -> park for the
> plan-model swap -> reset into the next feature's PLAN.

Two differences from `delegate` mode:
- **The phase boundary is itself a reset** (not only the feature/heavy-context boundary). A save fires
  at **every** phase boundary in `manual` mode — that is the price of swapping the driving model, and
  the hand-off + cheat sheet are what keep the re-orientation cheap.
- **SHIP does not draft the next plan.** In `delegate` mode `ship` drafts the next feature's plan into
  the working tree; in `manual` mode that authoring belongs to the next **PLAN** session (plan with the
  plan-model), so manual-mode `ship` **skips** the draft-next-plan step and PLAN starts it fresh.

If a `manual` stream is run **unattended** (no human to swap `/model`), it cannot advance past a phase
boundary — it parks there. That is correct, not a failure: `manual` is the attended mode; use
`delegate` for autonomous / `/loop` runs.

### Event-driven debrief — route before loss

Debrief fires whenever a body of context worth routing is about to be lost (**route-before-loss**). A
feature completing and an *eventful* ship are two **distinct** context-bodies, so two passes are not
redundant:

- **#1 (before `ship`)** — the *feature's* follow-ups (implementation surprises, gotchas, follow-on
  work). Commits ride the ff-merge free. **Also record a one-line delegation tally** in the hand-off's
  *What's been done* — `delegations: N` by mode (`mailbox`/`codex`/`isolated`, or `0 — all inline`) — so
  stream-wide `/delegate` adoption is **auditable at a glance** instead of vanishing into the loop. A
  **persistent 0 across the stream** is itself skill feedback (`/delegate` not firing where substantial
  delegable work existed) → route it to the skills' `.records/feedback.md`, tagged `[delegate]`. (A genuine
  all-inline stream — small tasks, tight loops — is a legitimate 0; the tally is the fact, you judge.)
  **In `manual` mode a low/0 tally is *expected*** — delegation there is fan-out-only, not the model
  lever — so do **not** route it as `[delegate]` feedback; the per-phase model swaps are the model story.
  **Forward-reference guard:** if a debrief-#1 follow-up references the feature being shipped *this*
  cycle, cite it **by intent/slug, not as a `.records/archive/<slug>.md` path link** — `ship` step 1 writes that
  record *after* debrief, so a path link is transiently dangling and the host doc-linter rejects the
  debrief commit (gated on its own, before ship). Cite the slug in prose; the record materializes at ship.
- **#2 (after `ship`, conditional)** — the *process* friction. **Recommended, not automatic:** flag
  it at the feature-completion seam ("ship was eventful — worth a second debrief?").

**Eventful ship** = `ship` required conflict resolution, hit a contention reject-and-retry, took
multiple syncs, or otherwise surfaced friction/learnings worth an `ISSUES`/`FEEDBACK`/`bug` entry. A
clean ff-merge with no conflicts -> no second debrief. **A contentious conflict band-aid makes a ship
eventful** — distinct from process friction: it's risky *code* now on the trunk. The band-aid is
captured **at the moment** of resolution (the `REVIEW(conflict):` marker + `[conflict band-aid]` ISSUES
entry from `sync`), so debrief #2 only **verifies** that capture happened (marker + entry present) — it
does not re-derive it from memory.

(Doctrine: the host's PLANNING doc says "debrief at done-when, *before* landing." The intent was always
"before the context is lost"; in a workstream that loss event is the **reset**, and `ship` precedes it —
so debrief#1-before-ship honors the doctrine while debrief#2 captures what ship itself surfaced.)
