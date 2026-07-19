# Skill Self-Initialization & Typed Edges — Roadmap

**Status:** Complete (2026-07-19). **All 8 phases done** (0–2 shipped at milestone #1 `ad84452`; 3–4
shipped at milestone #2 `1abad3c`; 5 shipped at milestone #3 `0db26cf`; 6–7 ship together at track
end) — model doc + maintainer backlog (Phase 0); `backlog` + `feature` self-init/edges/registration
pilots (Phase 1); the typed-edge tenet promoted into `AGENTS.md` + `skills-lint.sh` check 8 edge
backstop (Phase 2); the **per-skill disposition audit**
(`docs/design/2026-07-19-phase3-skill-dispositions.md`, Phase 3); the **`/foreman` re-scope**
(`docs/design/2026-07-19-phase4-foreman-rescope.md`, Phase 4); **rollout to all 9 remaining skills** —
`feature`/`architect`/`auditor`/`foreman` landed self-init + registration, all 9 landed `## Edges`,
`packs/clankshop.md` shrunk to the seams edge-matching can't derive (Phase 5); **docs & runbook
reconciled** — `derive-seams` re-run against the live tree surfaced two real deps the Phase 5 seam-table
pass hadn't folded in (`architect ↔ workstream`, `foreman ↔ auditor`), the vocabulary table promised for
"Phase 5/6" graduated into `packs/clankshop.md`, and the model/Phase 4 design docs' stale "Proposed"
status lines now point at their shipped, living-doc homes (Phase 6); **the capstone**
(`docs/design/2026-07-19-phase7-skill-builder.md`, Phase 7) — the `skill-builder` toolmaker skill now
carries the portable doctrine (`docs/DOCTRINE.md`), the lint gate, and the boundary-audit workflow;
grimoire's own `AGENTS.md` thinned to a pointer + local overrides. (Grimoire is patient-zero: phases
are tracked here + in git history, not in a `.records/` ledger — grimoire authors these skills, it
does not self-run them.)

**Goal:** Make every skill **self-initializing** and **self-describing via typed edges**, so the
constellation works **bare** — each skill registers its *own* route/workflow into `AGENTS.md` on init —
and `/foreman` becomes a **pure, optional composer/optimizer**, never a dependency. Evaluate *all*
skills against this doctrine and apply it where it fits.

**Why (the through-line):** the `/backlog` critique exposed a real seam — `/backlog` can't stand up its
own home (`/foreman init` scaffolds `.records/`) and has no passive visibility (its items surface only
when `/foreman` reads them). So the "capture bureau" is, standalone, a *write-only, invisible drawer*.
The fix isn't "add a floor"; it's **self-initialization + typed edges**: a skill creates its own home,
registers its own route/workflow into the always-loaded `AGENTS.md` (visibility by construction), and
`/foreman` optimizes rather than bootstraps. The friction found the architecture.

## Guiding invariants (carried from the boundary work — do not regress)

- **Skills stay independent.** A skill self-registers only its *own* route/workflow; it never names a
  sibling. (The boundary tenets still hold — this extends them to *init*.)
- **Seams live in the composer, derived not declared-in-leaves.** Skills emit **typed edges**
  (`produces` / `consumes` / `handoff`); `/foreman`/runbook **wire** edges into seams. A skill naming
  its successor is the co-mingling we just removed — forbidden.
- **Doctrine trails reality by zero.** The typed-edge tenet lands in `AGENTS.md` **only after** the
  first skill implements it (Phase 2), never before — no doctrine for a system that doesn't exist yet.
- **Optimization, not dependency.** `AGENTS.md` works bare; `/foreman` and `clankshop` are enrichment
  layers. Every skill must function with neither installed.

## The model (recap)

- **Skill = source of truth** for its own route/workflow (declared in the skill, as typed edges).
- **`AGENTS.md` = projection** — written by the skill's own `init` (self-registration) or by a composer
  reading the skill. A projection can drift; re-validating it against the source is `/foreman`'s job
  (*snapshot must never pose as authoritative*).
- **`/foreman`/runbook = composer/drain** — introspect installed skills, wire typed edges into seams,
  drain accumulated `AGENTS.md` entries into organized doctrine, validate drift. This is `/foreman`'s
  existing **baseline** mode, promoted from fallback to primary.
- **Three registration modes:** self-registered (organic) · foreman-composed (curated) ·
  clankshop-declared (orchestrated up front).

**What a skill self-describes — three layers:**
1. **Typed edges** (`produces`/`consumes`/`handoff`) — the mechanical wiring points. **Required.**
2. **Ideal-use examples** — self-contained *"how to use me"* route/workflow the composer and **role
   skills ingest** to understand usage. **Enrichment.**
3. **Deployable seed** — project-customizable assets (e.g. `.agents/<skill>/templates/`) plus an
   authoring verb. **Enrichment.**

Edges are the minimum; layers 2–3 are optional enrichment a role *may* ingest. **Examples stay
self-contained** — a cross-skill workflow is a seam the composer *generates* from edges, never a
hardcoded sibling reference (the route-vs-seam line, applied to examples). A deployable-assets home
(layer 3) does **not** make an operator a steward — it just means the skill has customizable files.

---

## Phases

### Phase 0 — Design & scaffolding
- Write the **design doc** for the model: typed-edge tenet (as founding principle), the edge
  vocabulary v0, the hard parts below, a task-by-task plan for the pilot.
- Stand up **`docs/BACKLOG.md`** — the "simple version" backlog for this repo's own loose ends
  (`#4`/`#5` from the body audit, and future maintainer follow-ups).
- **Deliverable:** design doc (Proposed); tenet captured in the doc, **not** in `AGENTS.md`.

### Phase 1 — Pilot: `backlog` + `feature` (two shapes, de-risk the mechanism)
Two parallel pilots covering different layers, dogfooded upfront to prove they synergize before ten
skills commit to the pattern:
- **`backlog` — Layer 1 (core mechanism).** `/backlog init` (self-creates its `.records/` home), an
  **edge declaration** (`produces`/`consumes`/`handoff`), **`AGENTS.md` self-registration** (idempotent,
  delimited section). Settles the registration mechanism + edge vocabulary.
- **`feature` — Layers 2–3 (enrichment).** A self-contained **ideal-use example** (*"how to use me,"*
  no sibling named), a deployable **`.agents/feature/templates/`** seed with baked-in defaults, and a
  **template-authoring verb**. Settles the example-declaration format + templates-as-seed.
- Resolve the hard parts *empirically on two skill shapes* before generalizing.
- **Deliverable:** self-initializing `/backlog` + `/feature`; mechanism, edge vocab, example format,
  and templates-seed pattern all settled.

### Phase 2 — Land the tenet + a lint backstop
- Promote the **self-init / typed-edge tenet** to `AGENTS.md` (doctrine now trails reality).
- Extend `scripts/skills-lint.sh`: every skill declares edges; registration is idempotent; **no skill
  names a sibling in its edges** (the co-mingling backstop, one level up).
- **Deliverable:** live doctrine + mechanical gate.

### Phase 3 — Evaluate *all* skills (the audit) — ✅ DONE (2026-07-19, unshipped)
- Assess each of the 10 skills against the doctrine → a **per-skill disposition table**: current
  init-dependency, its typed edges (`produces`/`consumes`/`handoff`), what changes, migration notes.
  Some skills already self-contained (e.g. `handoff`, `chiropractor`) may need little; the point is a
  deliberate, recorded call per skill.
- **Deliverable:** `docs/design/2026-07-19-phase3-skill-dispositions.md` — the disposition table (§2)
  + five cross-cutting findings (§4: four self-init tiers, universal edge block, registration tracks
  captured-items, `foreman` dual-role sequenced first, vocab holds) + pilot-edge confirmation and a
  lint-refinement candidate for the `handoff-doc` intra-skill single-use WARN (§5). Drives Phases 4–5.

### Phase 4 — `/foreman` re-scope (its own design doc — the biggest change) — ✅ DONE (2026-07-19, unshipped)
- `/foreman`: **bootstrapper/stamper → composer/extractor/drain.** Introspect installed skills, wire
  their typed edges into seams, drain `AGENTS.md` accumulation into organized doctrine
  (`.records/docs/foreman/…`), validate drift. `init` stops *scaffolding others' homes* (they self-init)
  and becomes *compose + organize*.
- **Deliverable:** `docs/design/2026-07-19-phase4-foreman-rescope.md` — skill discovery (a named gap,
  now fixed), the per-skill `init` dispatch table (self-init vs. a marked, temporary legacy fallback),
  the edge-matching seam-derivation algorithm + its `foreman-health.sh derive-seams`/`check-projection`
  implementation, the seam-annotation on-disk format + section-ownership contract, and the seed-vs-record
  settlement (doctrine stays a seed; a new `.records/logs/foreman-calibrate.md` records calibration
  runs). Implemented in `skills/foreman/{BOOTSTRAP.md,SKILL.md,verbs/{init,check,calibrate}.md,
  scripts/foreman-health.sh}`; `/foreman route` and `verbs/migrate.md` deliberately untouched (§5, §6 of
  the design doc). Gate green (`fails=0 warns=13`, matching the pre-existing baseline).

### Phase 5 — Roll out to the remaining skills — ✅ DONE (2026-07-19, unshipped)
- Apply self-init + edges per the Phase 3 dispositions; wire `/foreman`-as-composer; **shrink
  `clankshop`** to the seams edge-matching can't derive (its stated "enrichment baseline can't derive").
- **Deliverable:** all skills self-initializing; `/foreman` composing; runbook slimmed. Landed:
  `feature`/`architect`/`auditor` each gained `## Edges` + a self-registering `init`/`templates` verb
  (own `register-route.sh` copy); `foreman` gained `## Edges` + its own leaf `skill:foreman`
  registration (step 8 of `init`, distinct from its composer role deriving seams around every block);
  the remaining 5 skills (`chiropractor`, `workstream`, `handoff`, `delegate`, `mailbox`) gained
  `## Edges` per F1/F2 (mostly all-`—`; `handoff`'s is a real self-chain). `packs/clankshop.md`'s seam
  table now tags which rows `derive-seams` confirms mechanically (2 of 9: `backlog↔foreman`,
  `architect↔feature`/`feature↔workstream`) vs. which stay hand-authored (6 of 9 — altitude/scope
  splits with no shared type, by design). `skills-lint.sh` `fails=0 warns=11` (down from the 13
  baseline — two orphan WARNs resolved as real consumers wired; `derive-seams` now draws its first live
  `seam:`, `feature -> workstream (gate-green-code)`). Filed **BL-6** (register-route.sh now duplicated
  5×, keep the write-protocol in sync) and **BL-7** (`built-against: git rev-parse HEAD` collapses to
  one value across a monorepo skills-root — advisory, deferred).

### Phase 6 — Reconcile docs & runbook — ✅ DONE (2026-07-19, unshipped)
- `clankshop`, `README`, the ownership index, and `AGENTS.md` reflect the new model; distill the
  accreted design docs (this roadmap + the two design docs) into clean present-tense doctrine.
- **Deliverable:** coherent doctrine, no drift. **README/AGENTS.md were already accurate** (Phases 2/5
  kept them current as they landed — no drift found, no edits needed). **`packs/clankshop.md`** needed
  real reshaping: a live re-run of `derive-seams` against the installed skills found two mechanically-
  derivable rows the Phase 5 pass hadn't captured (`architect ↔ workstream` via `roadmap`, `foreman ↔
  auditor` via `audit-finding`) — added, and the seam table's own summary count corrected (4 of 11 rows
  now derived, not 2 of 9). Graduated the model doc's §2.2 "starter vocabulary" table into a **`##
  Typed edge vocabulary (reference)`** section in `clankshop.md`, as that doc had earmarked for
  "Phase 5/6" but Phase 5 didn't do. Updated the model doc's and the Phase 4 doc's stale `Status:
  Proposed` headers to point at where the doctrine now actually lives (both are fully implemented) —
  they stay as historical records of the reasoning, not live doctrine. Re-verified `skills-lint.sh
  fails=0 warns=11` (unchanged) and `derive-seams`/`check-projection` (fixture-tested) after the edits —
  clean. Filed **BL-8** (an incidental, out-of-scope find: an unrelated earlier design doc's own
  "Phase 2 deferred" status line is now partly stale). **No skill/script code changed** — pure doc
  reconciliation, so only the fast doc-linter path applied.

### Phase 7 (capstone) — Distill the doctrine into a portable `skill-builder` steward — ✅ DONE (2026-07-19)
The library stewards design (`architect`), workflow (`foreman`), docs (`chiropractor`), and code
(`auditor`) — but **nothing stewards the skills themselves.** The boundary audit built this session is
homeless by design (*"a toolmaker workflow, not a `/foreman` verb"*). `skill-builder` is that missing
steward: it **consolidates** `scripts/skills-lint.sh` (the gate), `docs/boundary-audit.md` (the audit
workflow), new-skill **scaffolding**, and the **authoring doctrine** (boundary tenets + the three
layers + self-init/edges + *name-your-floor*). Verbs: `new` (scaffold), `check`/alias `audit`
(boundary + layers + edges + lint), `calibrate`.
- **Portable, and the doctrine's new home.** `skills/skill-builder/docs/DOCTRINE.md` carries the
  generalizable design philosophy (moved from `AGENTS.md`, generalized to name no grimoire-specific
  path); grimoire's `AGENTS.md` thins to a pointer + two local overrides (the feedback-channel choice,
  the patient-zero caveat) — the public-doctrine + private-override shape.
- **Disposition:** in-place-steward tier (Phase 3 F1) — no durable home, all-`—` `## Edges`,
  registration optional/not implemented v1 — the same call `chiropractor` got, for the same reason (a
  steward with nothing private to scaffold).
- **Deliverable:** `docs/design/2026-07-19-phase7-skill-builder.md` (the disposition + build record);
  `skills/skill-builder/` (`SKILL.md`, `docs/{DOCTRINE,BOUNDARY-AUDIT}.md`,
  `scripts/skills-lint.sh` moved from the repo root, `verbs/{new,check,calibrate}.md`); `AGENTS.md` /
  `README.md` / `docs/boundary-audit.md` (now a pointer + grimoire's own routing-probe run log) /
  `packs/clankshop.md` (one orientation note — `skill-builder` stays outside the pack's manifest)
  reconciled to point at it. **Not folded in:** collapsing the five skills' duplicated
  `register-route.sh` copies (BL-6) and the `built-against` monorepo-collision fix (BL-7) — both real,
  both now have a concrete future owner (`skill-builder new`/`check`), neither built this phase
  (scope discipline, not an oversight).

---

## Open questions (resolve as we go — do not block Phase 0)

- **Edge vocabulary granularity.** Lightweight tags (`produces:`/`consumes:`/`handoff:`) vs. something
  richer. Bias: lightweight — a full type system is over-engineering.
- **Registration target.** A delimited section *inside* `AGENTS.md`, or an included `ROUTES`-style file
  `AGENTS.md` references (keeps hand-authored doctrine clean).
- **Skill-vs-foreman write protocol.** Skill registers if absent; `/foreman` may reorganize; re-init
  respects foreman's layout. Needs a precise, idempotent contract.
- **Seed vs. record for drained doctrine.** `.records/docs/foreman/…` (record, grows with the code) vs.
  `.agents/foreman/` (seed, hand-curated). The roadmap leans record; settle it in Phase 4.
- **Migration model.** Lazy self-registration (on first invocation) vs. a one-time sweep. Bias: lazy —
  a skill registers when first relevant; unused skills stay out of `AGENTS.md`.

## Sequencing & dependencies

- **Phases 0 → 1 → 2 are the critical path** and gate everything: the pilot proves the mechanism
  *before* the tenet lands or any rollout begins.
- **Phase 3** (evaluate) can begin once Phase 1 settles the pattern; it feeds Phases 4–5.
- **Phase 4** (`/foreman`) is the critical path for the *"with foreman"* experience — but the **bare**
  experience (self-init + `AGENTS.md` registration) is fully working after Phase 2, independent of it.
- Each phase ends `skills-lint` green and is independently reviewable.

## Non-goals

- Not building a rich edge/type system — lightweight tags only.
- Not making `AGENTS.md` registration mandatory to *use* a skill inline — a skill still works if never
  registered; registration is what makes it *visible/routable*, not what makes it *function*.
- Not touching consuming-project deployments until the model is proven here (grimoire is patient-zero).
