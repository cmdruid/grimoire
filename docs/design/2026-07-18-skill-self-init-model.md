# Skill Self-Init & Typed Edges — Model & Pilot Plan

**Status:** Implemented (2026-07-19, as of Phase 5/`0db26cf`). **Superseded in part (2026-08-08)**
by the clankshop pack design (`docs/design/2026-08-06-clankshop-pack.md`): pack **core members**
no longer carry typed edges or edge-derived seams — the pack's authored doctrine + runbook
compose them; the model's provisions **stand for standalone skills and helpers** (the portable
regime, `skills/skill-builder/docs/DOCTRINE.md` § Two regimes). Companion to
`docs/design/2026-07-18-skill-self-initialization-roadmap.md` (this doc was that roadmap's **Phase 0**
deliverable — the model the phases built). The tenet lives in `AGENTS.md` (last design-philosophy
bullet); the vocabulary + seam table live in `packs/clankshop.md`; every skill's own `## Edges` block
and (where applicable) `init`/`templates` verb are the projected reality. This doc stays as the
**historical record** of the reasoning behind those decisions — read it for *why*, the living docs for
*what's true now*.

**What this doc is.** The roadmap says *what* order to build in; this doc fixes *the model*: the
founding **tenet**, the **edge vocabulary v0**, the **self-registration/projection** mechanism, the
resolved-enough **hard parts**, and a **task-by-task plan for the Phase 1 pilot**. It deliberately
does **not** touch `AGENTS.md` — the tenet is captured *here* and promotes to doctrine only in Phase 2,
*after* the pilot proves it (roadmap invariant: *doctrine trails reality by zero*).

**Scope discipline.** Everything here is v0 and pilot-facing. Where the roadmap's open questions can be
settled cheaply on two skill shapes, this doc **decides provisionally**; where settling needs the
`/foreman` re-scope (Phase 4), it **defers explicitly** rather than guessing. Bias throughout:
**lightweight over configurable** (roadmap non-goal: *not building a rich edge/type system*).

---

## 1. The typed-edge tenet (founding principle — NOT yet in `AGENTS.md`)

> **Skills self-initialize and self-describe via typed edges; the composer wires the seams.**
> A skill stands up **its own** home and registers **its own** route into the always-loaded front-door
> doc — so the constellation works **bare**, with no composer deployed. What a skill declares about its
> place in a workflow is a set of **typed edges** (`produces` / `consumes` / `handoff`) keyed on
> **artifact/capability *types*, never on sibling names**. A composer (`/foreman`/runbook) **derives**
> the cross-skill seams by *matching* one skill's edges against another's. A skill that names its
> successor has authored a seam — the co-mingling the boundary work removed, one level up.

This is the existing boundary doctrine (*self-scoping descriptions*, *seams live in the runbook*, *glue
is content vs. mechanism*) **extended from routing to initialization**. The three prior tenets governed
what a skill's `description:` may say; this one governs what a skill's `init` may *write* and what its
edges may *name*. The through-line is identical: **independence is the means, competence the constraint**
— a skill is independent (self-standing, no sibling references) precisely so the whole set composes
*more* reliably, never less.

**Four corollaries (each a testable rule the pilot must not violate):**

1. **Self-init, no floor.** Every skill can create its own `.records/`/`.agents/` home; none depends on
   `/foreman init` having scaffolded it first. (This is the `/backlog` friction that started the
   roadmap: a "capture bureau" that can't build its own drawer.)
2. **Visibility by construction.** A skill registers its route into the **always-loaded** front-door
   doc, so its existence and its captured items surface **without** a composer reading it. (The second
   `/backlog` friction: *write-only, invisible drawer*.)
3. **Edges name types, not siblings.** `produces: plan` / `consumes: plan` — never `handoff: /feature`.
   The type namespace is shared; the sibling namespace is invisible to a leaf.
4. **Optimization, not dependency.** The bare experience (self-init + registration) is complete on its
   own; `/foreman` and `clankshop` *enrich* (curate arrangement, derive seams, drain accumulation) but
   are never required for a skill to **function**.

---

## 2. Edge vocabulary v0

### 2.1 The three edge kinds

An **edge** is a one-line declaration on a skill, of the form `<kind>: <type> [— <note>]`. Three kinds,
distinguished by **control-flow strength**:

| kind | means | composer reads it as |
|---|---|---|
| `produces: T` | "I emit an artifact/state of type `T`." | a **data source** for `T` |
| `consumes: T` | "I read/act on an artifact/state of type `T` as input." | a **data sink** for `T` |
| `handoff: T` | "I *terminate* in a state that expects a successor; the baton I pass is of type `T`." | a **control-flow seam** — pair with a `consumes: T` |

`handoff` is the strong edge: it asserts *control naturally continues*. `produces` is weak: a durable
output that a consumer **may** pick up, but from which this skill does **not** itself hand control.
Concretely: `/feature build` **`produces: gate-green-code`** and **`handoff: gate-green-code`** (it ends
expecting a landing step); `/backlog task` **`produces: tracker-entry`** but does **not** hand off — a
filed task sits until something drains it, so it is a data source, not a baton. The distinction is what
lets the composer draw a **workflow arrow** (handoff↔consumes) versus a mere **dependency line**
(produces↔consumes).

**The matching rule the composer runs** (Phase 4 implements it; stated here so the edges are authored
against a real consumer):

- `handoff: T` on skill A **+** `consumes: T` on skill B → a **seam** "A → B" (control flows A to B).
- `produces: T` on A **+** `consumes: T` on B → a **dependency** "B reads A's `T`" (no implied control).
- Unmatched edges are **legal and expected** — a `produces: T` with no consumer is a leaf output; a
  `consumes: T` with no producer means the input comes from outside the skill set (a human, the repo).
  Nothing errors; the composer just draws fewer arrows.

Crucially, **A and B never appear in each other's declarations** — the composer supplies both names by
matching on `T`. This is the tenet's corollary 3 made mechanical.

### 2.2 Typed artifacts: an open, string-typed vocabulary

Types are **plain strings**, matched by **equality**. There is **no central registry a skill must
import** (that would reintroduce a floor). The vocabulary is:

- **Open** — a skill may emit a new type string; it simply matches nothing until some consumer names the
  same string. New types cost nothing and break nothing.
- **Documented, not enforced** — the *known* types live in the runbook (`packs/clankshop.md`) as a
  reference table the composer and human consult, and the lint (Phase 2) can WARN on a type used by
  exactly one skill (a likely typo or an orphan), but it never FAILs on an unknown type. Facts, not
  verdicts.
- **Coarse-grained on purpose** — prefer `plan` over `feature-plan-v2`. A handful of broad types that
  many skills share beats a precise-but-lonely type per skill. If two producers emit subtly different
  `plan`s, that is the composer's disambiguation problem to note, not a reason to fork the type.

**Starter vocabulary (v0, derived from grimoire's current skills — a *reference*, not a schema):**

| type | produced by (illustrative) | consumed by (illustrative) |
|---|---|---|
| `tracker-entry` | `backlog` (task/bug/issue/note/feedback) | `foreman` (calibrate/route), `backlog` (curate) |
| `design` | `feature` (design), `architect` (brainstorm/plan) | `feature` (plan) |
| `plan` | `feature` (plan) | `feature` (build), `workstream` (queue source) |
| `gate-green-code` | `feature` (build) | `workstream` (ship) |
| `roadmap` | `architect` (plan) | `workstream` (queue source) |
| `handoff-doc` | `handoff` (save) | `handoff` (resume) |
| `audit-finding` | `auditor` | `backlog` (drain), `foreman` (calibrate) |

This table is **illustrative wiring the composer would derive**, listed here so Phase 1's two pilots
declare edges that actually match something. It is **not** a contract every skill must fill, and it does
**not** get authored into any leaf — it graduates into `clankshop.md`'s reference in Phase 5/6.

### 2.3 Where edges are declared

**Decision (v0): a dedicated `## Edges` section in the skill's `SKILL.md` body**, not the frontmatter
`description:`.

Rationale: the `description:` is the **routing surface** (harness-selected, ≤1024 chars, self-scoping) —
loading edge plumbing into it would bloat the one field the boundary work just fought to keep lean, and
edges are read by the **composer**, not the router. A delimited body section keeps the two surfaces
separate: `description:` routes; `## Edges` wires. Format:

```markdown
## Edges
<!-- edges:backlog -->
- produces: tracker-entry — task/bug/issue/note/feedback rows under .records/
- handoff: — (none; filed items are drained by a composer, not handed off)
- consumes: — (none; capture is a front-door, inputs come from the human/work)
<!-- /edges:backlog -->
```

The `<!-- edges:<name> -->` delimiters make the block **machine-findable** (the composer and the lint
parse between them) and **idempotently rewritable** by the skill's own maintenance. An empty edge kind
is declared explicitly (`handoff: —`) rather than omitted, so "no handoff" is a *stated* fact, not a
gap.

---

## 3. Self-registration: the `AGENTS.md` projection

### 3.1 The projection model

- **The skill is the source of truth** for its own route + edges (in `SKILL.md`).
- **The front-door doc is a *projection*** — a regenerable snapshot written by the skill's `init`
  (self-registration) or by a composer reading the skill. Per *a snapshot must never pose as
  authoritative*, the projection is **pointer-heavy, stamped, and re-validatable**: it points at the
  skill, records what it was built against, and a composer can rebuild it wholesale from source.
- **The composer validates drift** — `/foreman check` (later) re-derives the projection from installed
  skills and flags where the written projection disagrees. This is `/foreman`'s existing *baseline* job,
  promoted to primary (roadmap §"The model").

### 3.2 Registration target

**Decision (v0): a single delimited section *inside* the always-loaded front-door doc**, not a separate
included file.

The whole point of registration is **visibility without a composer** (corollary 2). That only holds if
the projection lands where the harness already loads it. In grimoire that is `AGENTS.md` (imported by
`CLAUDE.md`); in a consuming project it is whatever the harness auto-loads (`AGENTS.md`/`CLAUDE.md`). A
separate `ROUTES.md` would need an `@include` line to be visible — more invasive wiring for `init` to
add, and a second thing that can rot. So v0 writes into a **`## Skill routes (self-registered)`**
section of the front-door doc, delimited per-skill. **Graduation path:** if that section grows
unwieldy, the composer's drain job (Phase 4) may hoist it into an included file — that is an
*optimization the composer owns*, not a v0 requirement.

> **Grimoire-local caveat (patient-zero).** Grimoire's own `AGENTS.md` is *authored library doctrine*,
> not a consuming project's scaffold — we do **not** want self-registration blocks accreting in it. For
> the pilot, the registration **target is parameterized**: the skill writes to a **project front-door
> path it is told/discovers**, and the pilot exercises it against a **throwaway fixture front-door**
> (a temp `AGENTS.md` under the scratchpad or a `packs/` sample), never grimoire's real `AGENTS.md`.
> Grimoire is where the *mechanism* is built and tested; it is not itself a self-registering deployment.

### 3.3 The block format v0

```markdown
## Skill routes (self-registered)
<!-- skill:backlog BEGIN built-against:<skill-sha-or-version> -->
### /backlog — capture bureau
Route: file/sweep/curate follow-ups into `.records/` trackers. `/backlog task|bug|issue|note|feedback|debrief|curate`.
Edges: produces `tracker-entry`.
<!-- skill:backlog END -->
```

Properties:
- **Delimited + stamped** — `skill:<name> BEGIN … END` bounds the block; `built-against:` stamps the
  source version it was projected from (the validator compares).
- **Pointer-heavy** — it names the skill and its verbs; it does **not** paste the skill's prose (which
  would rot silently). The route line is a *one-line projection*, regenerable from `description:`.
- **Edge summary only** — the authoritative edges live in `SKILL.md § Edges`; the block carries a
  compact echo so a bare reader sees the wiring without opening the skill.

### 3.4 Idempotency + the skill ↔ foreman write protocol

The precise, idempotent contract (roadmap open question *skill-vs-foreman write protocol*), **decided
for v0**:

- **Content vs. arrangement split** — the **skill owns the bytes between its own `skill:<name>`
  delimiters** (its route + edge echo, the source projection); the **composer owns everything *around*
  the blocks** — the section header, the ordering of blocks, and any *derived* seam annotations it adds
  between them. Neither writes the other's region. (This mirrors the boundary work's *glue content vs.
  mechanism* split, applied to the projection.)
- **`init` is idempotent** — writing the block is: *if my `skill:<name>` delimiters are absent, append a
  fresh block inside the section (creating the section if needed); if present, replace only the bytes
  between them.* Everything outside the skill's own delimiters is preserved verbatim. Re-running `init`
  any number of times converges to the same file (modulo a refreshed `built-against:` stamp).
- **Composer may reorganize, never orphan** — `/foreman` may reorder blocks, regroup them under derived
  headings, and interleave seam annotations, but **must preserve each `skill:<name>` delimiter pair** so
  the skill's own re-init stays non-destructive. A composer that removed a skill's delimiters would
  break that skill's idempotency — forbidden.
- **Conflict resolution** — if a skill's `init` finds its block present but *malformed* (delimiters
  broken, e.g. a hand-edit), it does **not** guess: it reports the malformation and leaves the file
  untouched (safe-by-default — never silently clobber authored content). The human or the composer
  repairs it.

---

## 4. The hard parts (open questions → v0 disposition)

The roadmap parks five open questions. Their v0 disposition:

| open question | v0 decision | settled where |
|---|---|---|
| **Edge granularity** | Lightweight string tags, three kinds, open vocabulary, equality-matched (§2). | **here** |
| **Registration target** | Delimited section in the always-loaded front-door doc; graduate to an included file only if the composer's drain warrants (§3.2). | **here (v0)**; may revisit Phase 4 |
| **Skill↔foreman write protocol** | Content-vs-arrangement split; skill owns its delimited block, composer owns arrangement; idempotent replace-between-delimiters (§3.4). | **here (v0)**; hardened Phase 4 |
| **Seed vs. record for drained doctrine** | *Deferred to Phase 4* — needs the `/foreman` re-scope to settle. Roadmap leans **record** (`.records/docs/foreman/…`, grows with code); this doc does not pre-commit. | **Phase 4** |
| **Migration model (lazy vs. sweep)** | **Lazy** — a skill self-registers on `init`/first relevant invocation; no global sweep. A composer *may* run an eager sweep as an optimization for a deployed project. | **here (v0)** |

**One hard part the roadmap under-states — the grimoire-vs-deployment split (§3.2 caveat).** The
mechanism is *built and tested* in grimoire, but grimoire's `AGENTS.md` is authored doctrine that must
**not** accrete self-registration blocks. So every pilot verb takes the **front-door path as a
parameter** and is exercised against a **fixture**, never grimoire's real front-door. This keeps
patient-zero honest: we prove the mechanism without polluting the library's own doctrine.

---

## 5. Pilot task plan (Phase 1)

Two pilots, **different skill shapes**, run in parallel to prove the pattern before ten skills adopt it.
Pilot A settles the **core mechanism** (self-init home + edges + registration); Pilot B settles the
**enrichment layers** (ideal-use example + deployable templates seed). Each ends `skills-lint` green and
is independently reviewable.

### 5.1 Pilot A — `backlog`, Layer 1 (core mechanism)

**Why backlog:** it *is* the friction that started the roadmap (can't build its own home; invisible).
Fixing it end-to-end validates every core piece.

- [ ] **A1 — `verbs/init.md` + `/backlog init` (self-creates its home).** Idempotently scaffold the
  `.records/` trackers backlog owns (`tasks.md`, `bugs/`, `issues.md`, `feedback.md`, `notes/`) per
  `docs/TAXONOMY.md`, with headers/placeholders. Idempotent: re-running `init` on an existing home is a
  no-op (never clobbers filed entries). **No dependency on `/foreman init`.**
- [ ] **A2 — `## Edges` section in `backlog/SKILL.md`** (per §2.3 format, delimited). Edges:
  `produces: tracker-entry`; `handoff: —`; `consumes: —`. This is the first real edge declaration —
  it settles the on-disk format.
- [ ] **A3 — `AGENTS.md` self-registration in `init`** (per §3, against a **parameterized front-door
  path**, exercised on a **fixture** — §3.2 caveat). Writes the delimited `skill:backlog` block into the
  `## Skill routes (self-registered)` section; idempotent replace-between-delimiters; stamps
  `built-against:`.
- [ ] **A4 — prove idempotency + independence.** On the fixture: `init` from empty → creates home +
  section + block; `init` again → byte-identical (modulo stamp); a hand-added second skill's block
  survives backlog's re-init untouched. Record the transcript in the pilot's test notes.

**Settles:** the registration mechanism, the edge on-disk format + vocabulary, the idempotent write
protocol, and self-init-without-a-floor.

### 5.2 Pilot B — `feature`, Layers 2–3 (enrichment)

**Why feature:** it is the richest operator (four stages, host-tuned templates), so it exercises the
*enrichment* layers a role skill would ingest — the ideal-use example and the deployable seed.

- [ ] **B1 — self-contained ideal-use example** (Layer 2). A *"how to use me"* worked example in
  `feature`'s SKILL.md (or a linked doc), **naming no sibling** — it shows `brainstorm → design → plan →
  build` as *feature's own* arc, and where a next step *would* continue it is expressed as an **edge
  type** (`handoff: gate-green-code`), not a sibling name. Settles the **example-declaration format**
  (the route-vs-seam line applied to examples: examples stay self-contained; the composer generates the
  cross-skill workflow from edges).
- [ ] **B2 — `## Edges` section in `feature/SKILL.md`.** Edges: `produces: design, plan,
  gate-green-code`; `handoff: gate-green-code`; `consumes: design, plan` (its own stages chain). Note the
  intra-skill produces↔consumes (design→plan→build) — the composer should *not* draw external seams for
  a skill's internal stage chain; the pilot checks that same-skill edges are excluded from seam
  derivation.
- [ ] **B3 — deployable `.agents/feature/templates/` seed** (Layer 3). A project-customizable templates
  home with baked-in defaults (the design/plan/brief templates feature already carries under
  `skills/feature/templates/`, recast as a **deployable seed** a project can override). Settles
  **templates-as-seed**: a deployable-assets home does **not** make `feature` a steward (roadmap §"The
  model") — it just means the skill ships customizable files.
- [ ] **B4 — template-authoring verb.** A verb that stands up / edits the `.agents/feature/templates/`
  seed in a project (the authoring entry point for Layer 3). Scope it minimally — v0 just scaffolds the
  seed from the baked defaults; richer authoring can wait.

**Settles:** the ideal-use example format (self-contained, edge-typed continuation), templates-as-seed,
and the operator-with-assets-is-still-not-a-steward line.

### 5.3 Cross-pilot acceptance (what Phase 1 must show before Phase 2)

- [ ] Both skills self-init their homes with **no `/foreman`** present (bare-install proof).
- [ ] Both declare `## Edges`; the **starter vocabulary strings match** where the table (§2.2) predicts
  (`feature.handoff: gate-green-code` has a consumer in the vocab; `backlog.produces: tracker-entry`
  has one).
- [ ] Registration is **idempotent** and **non-destructive** to sibling blocks (Pilot A4).
- [ ] **No leaf names a sibling** — grep the two skills' edges + example for a `/name` or a sibling
  slug; zero hits. (This is the invariant Phase 2's lint will enforce mechanically.)
- [ ] `bash scripts/skills-lint.sh` → `fails=0` throughout.

Only once these hold does the tenet promote to `AGENTS.md` (Phase 2) and the lint gain the edge/no-
sibling checks — *doctrine trailing reality by zero*.

---

## 6. What Phase 0 does **not** do

- **Does not touch `AGENTS.md`.** The tenet lives in §1 of this doc until Phase 2.
- **Does not build any verb.** `/backlog init`, `feature`'s example/seed/verb are Phase 1 — this doc
  only *specifies* them.
- **Does not re-scope `/foreman`.** That is Phase 4 with its own design doc; §4 defers the seed-vs-
  record question to it.
- **Does not settle the deployed-project rollout.** Grimoire is patient-zero; consuming-project
  deployment is out of scope until the model is proven here (roadmap non-goal).

## References

- `docs/design/2026-07-18-skill-self-initialization-roadmap.md` — the 8-phase queue this serves.
- `docs/design/2026-07-18-skill-boundaries-and-glue-ownership.md` — the boundary tenets this extends.
- `docs/boundary-audit.md` — the maintainer audit workflow + routing-probe gate (Phase 7's future home).
- `packs/clankshop.md` — the runbook/composer that will host the derived seam map + type reference.
- `docs/BACKLOG.md` — this repo's maintainer backlog (stood up alongside this doc).
