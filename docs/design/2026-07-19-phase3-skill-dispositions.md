# Phase 3 — Per-Skill Dispositions (the self-init / typed-edge audit)

**Status:** Complete (2026-07-19). Deliverable of **Phase 3** of
`docs/design/2026-07-18-skill-self-initialization-roadmap.md`. Drives **Phase 4** (`/foreman`
re-scope) and **Phase 5** (roll-out to the remaining skills).

**What this doc is.** A deliberate, recorded call for **each of the 10 skills**, scored against the
now-landed typed-edge tenet (`AGENTS.md`, last design-philosophy bullet) and the model
(`docs/design/2026-07-18-skill-self-init-model.md` §1 tenet, §2 edges). For each skill it fixes:
(a) whether it needs **self-init** (an idempotent home-scaffold, no `/foreman` floor) and *which*
home; (b) its **typed edges** (`produces` / `consumes` / `handoff`, types-not-siblings); (c) whether
it should **register** a route into the always-loaded front-door. `backlog` and `feature` are the
Phase 1 pilots — their edges are **confirmed** here against the vocabulary, not re-derived.

**What it is not.** It writes no `## Edges` blocks and no `verbs/init.md` files — that authoring is
**Phase 5** (roll-out). It also does not re-scope `/foreman`; the composer's edge-matching and
projection-validation are **Phase 4**. Bias throughout, per the roadmap: **lightweight over
configurable** — an all-`—` edge block and "no home" are legitimate, recorded dispositions.

---

## 1. The three evaluation axes

Each skill is scored on three independent axes. They do **not** move together — a skill can need a
rich edge block but no home (an in-place steward), or a durable home but a near-empty edge block (an
audit sink).

1. **Self-init / home.** Does the skill own a **durable** home (`.agents/<skill>/` seed and/or a
   `.records/<...>/` store) it must scaffold idempotently with **no dependency on `/foreman init`**
   (corollary 1)? A **gitignored scratch dir** (`.mailbox/`, `.sessions/`, `.workstreams/`) is *not*
   a durable home — it is ephemeral and is already lazily created on demand; it needs no self-init
   protocol.
2. **Typed edges.** `produces: T` / `consumes: T` / `handoff: T`, keyed on artifact/capability
   **types** (corollary 3, lint check 8). **Every** skill declares a `## Edges` block — an all-`—`
   block is a *stated* fact ("I'm a pure mechanism"), not an omission (model §2.3).
3. **Front-door registration.** Should the skill register a **route** into the always-loaded
   front-door so a bare reader sees it — and its captured items — with **no composer** (corollary 2)?
   The payoff is real only where the skill has a **durable route or captured items** to surface.

---

## 2. The disposition table

| skill | tier | self-init? / home | `produces` | `consumes` | `handoff` | register? |
|---|---|---|---|---|---|---|
| **backlog** *(pilot)* | operator | **yes** — `.records/` trackers | `tracker-entry` | — | — | **yes** ✅ done |
| **feature** *(pilot)* | operator | **yes** — `.agents/feature/templates/` seed | `design`, `plan`, `gate-green-code` | `design`, `plan` | `gate-green-code` | **yes** *(Phase 5)* |
| **architect** | steward | **yes** — `.agents/architect/` seed + `.records/{design-draft,reports}/` | `design`, `roadmap` | `design` *(own: distill/reconcile)* | — *(see §3)* | **yes** |
| **auditor** | sink (steward-shaped) | **yes** — `.agents/auditor/` seed + `.records/audit/` store | `audit-finding` | — | — | **yes** |
| **foreman** | steward + **composer** | **yes** — `.agents/foreman/` seed + ownership index | — *(composer writes, not a typed edge — §3)* | `tracker-entry`, `audit-finding` | — *(route = composer mechanism, Phase 4)* | **yes** *(also owns the section — §4)* |
| **chiropractor** | in-place steward | **no** — operates on the repo's own docs; no private home | — *(in-place fixes + conversational report)* | — | — | optional |
| **workstream** | operator | **no durable home** — `.workstreams/` is gitignored scratch (lazy) | — *(lands trunk state)* | `plan`, `roadmap`, `gate-green-code` | — | optional |
| **handoff** | plumbing | **no durable home** — `.sessions/` is gitignored scratch (lazy) | `handoff-doc` | `handoff-doc` *(own: save→resume)* | — *(self-chain — §3)* | optional |
| **delegate** | plumbing (mechanism) | **no** — pure router, no storage | — | — | — | **no** |
| **mailbox** | plumbing (mechanism) | **no** — `.mailbox/` is gitignored scratch (lazy) | — | — | — | **no** |

Legend: **—** = a *stated* empty edge (declared explicitly, per model §2.3), not an omission.

---

## 3. Per-skill notes (the judgment calls)

- **backlog** *(pilot, done)* — `produces: tracker-entry`, no handoff (a filed item **sits** until a
  composer drains it — the "data source, not a baton" case, model §2.1). Reference impl for the
  self-init + registration mechanism.
- **feature** *(pilot)* — the canonical `handoff: gate-green-code` (build terminates expecting a
  landing step). Its `design → plan → build` is an **intra-skill** produces↔consumes chain; the
  composer must **exclude same-skill matches** from seam derivation (model §5.2). Home is the
  templates **seed** (layer 3) — a deployable-assets home does **not** make an operator a steward.
- **architect** — produces `design` (brainstorm/plan/distill) and `roadmap` (plan); consumes its own
  accreted `design` (distill/reconcile read change-records). **`handoff: —` in the core loop** — the
  seed is a *standing source* others drain, not a baton architect passes. **Two candidate handoffs
  deferred:** (1) `/architect prep` (verb file still pending — SKILL.md line 28) terminates expecting
  a rebuild → a `handoff: plan`/`roadmap` to settle when prep is authored; (2) `/architect reconcile`
  writes a drift report to `.records/reports/` — a candidate `produces: audit-finding` (coarse-shared
  with auditor) **if** a drain seam is later wanted. Keep both out of v0 (lightweight over
  configurable); revisit at Phase 5.
- **auditor** — `produces: audit-finding` (§2.2: consumed by `foreman` calibrate and a `backlog`
  drain). No handoff (findings sit until drained — same shape as backlog). Already **self-inits both
  homes** via `/auditor deploy` (`.agents/auditor/` rubric + `.records/audit/` deliverables) — the
  most conformant non-pilot; Phase 5 formalizes the `## Edges` block + registration only.
- **foreman** — the **special case**. Ordinary edges: `consumes: tracker-entry, audit-finding`
  (calibrate drains backlog + auditor). But foreman is **also the composer**: `/foreman route`
  dispatches a change to a lane, and foreman **derives** cross-skill seams and **writes/validates the
  projection**. That dispatch/derive behavior is **composer mechanism**, not an ordinary `handoff`
  edge — it is dispositioned in **Phase 4** (its own design doc). So foreman's leaf edges are just the
  two `consumes`; `produces: —` and `handoff: —` at the leaf level.
- **chiropractor** — a **steward with no private home**: it maintains the repo's *own* doc spine
  in place (read-only by default; report printed to the conversation, file output off by default).
  So **no self-init** and **all-`—` edges** — its output is in-place doc fixes, not a typed artifact
  another skill consumes. (`produces: audit-finding` for its maintainer-decision items is a *possible*
  future drain seam, but declaring it would assert a drain chiropractor does not currently perform —
  honest disposition is `—`.) It still gets a `## Edges` block stating those empties.
- **workstream** — `consumes: plan, roadmap` (queue sources) and `gate-green-code` (ship consumes
  feature's build output — the canonical seam that **validates** feature's `handoff: gate-green-code`).
  No durable home: `.workstreams/<stream>/WORKSTREAM.md` is gitignored per-stream scratch, already
  lazily created by `create`. `produces: —` / `handoff: —` — workstream is the outer loop; its ship is
  the terminal land, not a baton onward.
- **handoff** — a real **self-chain**: `produces: handoff-doc` (save) + `consumes: handoff-doc`
  (resume), the second instance (after feature) of an intra-skill produces↔consumes the composer must
  exclude from seam derivation. `handoff: —` — the doc is picked up by *resume* (or a future agent),
  not handed to another skill. No durable home (`.sessions/` is gitignored scratch, lazily created).
  **Lint note:** `handoff-doc` is used by exactly **one skill**, so lint check 8 will **WARN**
  (single-use type) — a legitimate false-positive for an intra-skill artifact; see §5.
- **delegate / mailbox** — the **pure-mechanism plumbing** tier. No storage (`.mailbox/` is gitignored
  scratch), **no typed artifact edges** (their "product" — a diff/verdict/applied patch — is ephemeral
  and consumed inline), and **no registration** (they are ambient doctrine / transport, with **no
  captured items** to surface — the exact thing registration exists for). Each still carries an
  all-`—` `## Edges` block so "mechanism, no typed artifacts" is stated, not inferred.

---

## 4. Cross-cutting findings (these feed Phases 4–5)

**F1 — Four tiers of self-init, not one.** The axis-1 answers cluster into four kinds, and the
roll-out (Phase 5) should template against the tier, not one-size-fits-all:

| tier | skills | self-init |
|---|---|---|
| **durable-home** | backlog, feature, architect, auditor, foreman | real idempotent scaffold of `.agents/`/`.records/`, **no `/foreman` floor** |
| **in-place steward** | chiropractor | **none** — maintains the repo's own layer; nothing private to scaffold |
| **scratch-only** | workstream, handoff, mailbox | **none** — gitignored ephemeral dir, already lazily created; no protocol |
| **pure mechanism** | delegate | **none** — no storage at all |

**F2 — The `## Edges` block is universal; content is not.** All 10 get a block (so "no edges" is a
stated fact). Plumbing (delegate, mailbox) = all-`—`. `handoff` and `feature` carry **intra-skill
chains** (handoff-doc; design→plan→build) that the composer **must exclude** from seam derivation —
this is now a **two-instance** rule, not a feature-only footnote (model §5.2 generalizes).

**F3 — Registration tracks *captured items / durable routes*, not mere existence.** Register the
durable-home + steward skills (backlog ✅, feature, architect, auditor, foreman). Make registration
**optional** for scratch-only skills (workstream, handoff) and **skip it** for pure-mechanism plumbing
(delegate, mailbox): registration's payoff (corollary 2) is *surfacing captured items to a bare
reader*, and a transport mechanism has none. Registering pure mechanisms would only **bloat** the
front-door section the tenet fought to keep lean.

**F4 — `foreman` is dual-role and must be sequenced first in Phase 5.** It self-registers its **own**
block *and*, as composer, **owns the surrounding `## Skill routes` section** (arrangement + derived
seam annotations) per the content-vs-arrangement split (model §3.4). Its leaf edges are trivial
(`consumes: tracker-entry, audit-finding`); its real behavior — route dispatch, edge-matching seam
derivation, projection validation — is **Phase 4**. Phase 5 must not author foreman's registration
until Phase 4 fixes how the composer and the leaf share that section.

**F5 — The starter vocabulary (§2.2) holds; no new types needed.** Every edge above types to an
existing string: `tracker-entry`, `design`, `plan`, `gate-green-code`, `roadmap`, `handoff-doc`,
`audit-finding`. The vocab is coarse and shared as intended — **no skill needed a bespoke type.** The
two candidate additions (architect's reconcile-report, chiropractor's doc-findings) both **coarse-map
to `audit-finding`** rather than forking a new type, and both are deferred.

---

## 5. Pilot-edge confirmation + a lint follow-up

**Pilot edges confirmed against the vocabulary (roadmap §5.3 acceptance, re-checked):**

- `backlog.produces: tracker-entry` → matched by `foreman.consumes: tracker-entry` ✓ (a dependency).
- `feature.handoff: gate-green-code` → matched by `workstream.consumes: gate-green-code` ✓ (a
  **seam** — control flows feature → workstream, the roadmap's canonical example).
- `feature.produces: design` / `consumes: design, plan` → `architect` co-produces `design`;
  `workstream` co-consumes `plan`. The vocab stays coarse/shared; **no pilot edge is an orphan.**

**Post-Phase-3 type pairing (what the composer would match after Phase 5 authors these blocks):**

| type | producers | consumers | status |
|---|---|---|---|
| `tracker-entry` | backlog | foreman | paired |
| `design` | feature, architect | feature *(own)* | paired |
| `plan` | feature | feature *(own)*, workstream | paired |
| `gate-green-code` | feature | workstream | **seam** (handoff) |
| `roadmap` | architect | workstream | paired |
| `audit-finding` | auditor | foreman *(+ backlog drain)* | paired |
| `handoff-doc` | handoff | handoff *(own)* | **single-skill** → lint WARN |

**Lint follow-up (BL candidate).** `handoff-doc` is produced and consumed by the **same** skill, so
`skills-lint.sh` check 8 will emit a **single-use WARN** — a legitimate false-positive for an
intra-skill artifact (distinct from the *rollout* orphan-WARNs that resolve once Phase 5 wires
consumers). Options for Phase 5: (a) accept the WARN as a known intra-skill case; (b) refine check 8
to count producer-vs-consumer *skills* separately so a same-skill produce↔consume pair does not read
as single-use. Recommend **(b)** — it also cleanly handles feature's internal chain. File against
`docs/BACKLOG.md`.

---

## 6. What this unblocks

- **Phase 4 (`/foreman` re-scope)** inherits F4: foreman's leaf edges (`consumes: tracker-entry,
  audit-finding`) are fixed here; the composer's edge-matching seam derivation, the route-dispatch
  model, and the projection-validation / section-ownership contract are Phase 4's to build against
  the §5 pairing table.
- **Phase 5 (roll-out)** inherits F1 (tier-templated self-init), F2 (universal edge block +
  intra-skill exclusion), F3 (register durable-home/steward skills; skip pure mechanisms), and the
  per-skill `produces/consumes/handoff` rows of §2 as the exact blocks to author — foreman **last**
  after Phase 4, `auditor` **cheapest** (homes already self-init).

## References
- `docs/design/2026-07-18-skill-self-initialization-roadmap.md` — the 8-phase queue (Phase 3 = this).
- `docs/design/2026-07-18-skill-self-init-model.md` — §1 tenet, §2 edge vocab, §3 registration.
- `docs/design/2026-07-18-phase1-pilot-acceptance.md` — the pilot edges confirmed in §5.
- `AGENTS.md` — the typed-edge tenet (landed Phase 2); the scoring rubric this audit applied.
- `scripts/skills-lint.sh` check 8 — the edge-block backstop; §5 files a refinement candidate.
