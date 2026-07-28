# Steward grammar — per-layer calibrate verbs

**Status:** Implemented (2026-07-28); routing probe 4/4. Successor to the front-door architecture's
§6 future-work note (`docs/design/2026-07-26-front-door-architecture.md`); rollout surfaces in §6
below.

**Goal:** Complete the steward role-family's shared grammar. Three skills steward one cross-cutting
layer each — `foreman` (operational), `architect` (design), `chiropractor` (docs) — but only foreman
has a feedback drain, and its `calibrate` currently drains *everything*: "doctrine / workflow /
AGENTS.md improvements" spans all three layers, and its own verb file already concedes the doc slice
("hand broad doc-tuning to the doc steward"). This doc gives each steward a layer-scoped `calibrate`
and rescopes foreman's into a classify-and-dispatch pass — each layer's signal drained by the
steward with the judgment to act on it.

**References:**
- `AGENTS.md` (this library) — names the steward family: "each stands up, evaluates, maintains, and
  drift-corrects one cross-cutting layer against the code."
- `docs/design/2026-07-26-front-door-architecture.md` §6 — the future-work note this implements.
- `packs/clankshop.md` — the seam table gaining the new drain rows.
- `docs/design/2026-07-18-skill-self-init-model.md` §2 — typed edges; `tracker-entry` is the type
  every drain consumes.

---

## 1. The grammar (descriptive, not procrustean)

The steward role-family's verbs, as they exist plus the three cells this doc fills (marked **new**):

| role verb | foreman (operational) | architect (design) | chiropractor (docs) |
|---|---|---|---|
| stand up | `setup` / `migrate` | `init` / `extract` | — (nothing to seed; in-place steward) |
| evaluate (cheap) | `check` | `check` | scan → diagnose |
| drift-correct (deep) | — (`calibrate` is the semantic pass) | `reconcile` | diagnose → adjust |
| drain feedback | `calibrate` (rescoped, §2) | **`calibrate` (new, §4)** | **`calibrate` (new, §3)** |

**Symmetry is adopted only where a cell is genuinely missing.** Chiropractor legitimately has no
stand-up verb (it audits the repo's own docs in place); foreman legitimately has no separate deep
drift-correct (its semantic pass *is* calibrate). The three drains are the real gap: today,
doc-flavored and design-flavored signal either dead-ends in foreman's over-broad calibrate or never
drains at all.

## 2. Foreman `calibrate` rescoped — classify, drain own slice, dispatch the rest

Foreman wears two hats; this rescope uses both deliberately:

- **Steward hat:** drain the **operational-layer** slice itself — routing rules, workflow doctrine,
  the front-door wiring/table, MEMORY/GOTCHAS promotions. Unchanged mechanics (quiet-tree guard,
  inventory, pattern threshold, scoped commit, pass log).
- **Composer hat (the F4 exception):** for each harvested entry that is **doc-layer** (front-door
  bloat, navigation friction, a doc that keeps being reached for and isn't wired) or
  **design-layer** (a seed spec that keeps misleading builds, a philosophy/contract complaint),
  **classify and dispatch** to the owning steward's calibrate rather than acting on it. Dispatch is
  composer mechanism — same as `route` — so it names lanes via the deployed composition
  (runbook/ownership index), never hardcoded siblings in the verb prose beyond the existing
  companion-skill conventions.

The classification is three-way by *what the fix would edit*: operational doctrine → foreman;
the doc spine's form → the doc steward; the design seed's content → the design steward. Mixed
entries split; unclassifiable entries stay with foreman (the default owner, as today).

## 3. Chiropractor `calibrate` — drain doc-flavored signal (portability preserved)

New verb: harvest captured dev-experience signal *about the docs* — "the front door is bloated,"
"I couldn't find X," "doc Y keeps contradicting Z" — and turn it into the scan → diagnose → adjust
flow's inputs: each signal entry becomes a targeted diagnosis (which dimension does it indict?),
then a normal adjust with the usual confirmation gate.

**The portability constraint is hard and shapes the design:**

- **Input edge is optional.** If a `tracker-entry` source exists (a feedback/issues tracker the
  repo's own front door names), drain it; else accept signal handed inline in the invocation; else
  report "no captured signal found" and fall back to a plain audit. A repo with no trackers loses
  nothing.
- **Self-containment holds.** Chiropractor still names no other skill and assumes no deployment.
  Its verb prose speaks of "a feedback tracker the repo's front door names," never a specific
  skill's store. It consumes the **type** `tracker-entry` (its `## Edges` block gains a `tracker-entry` consumes (optionality stated in the prose after the type token — an annotation inside the token would break mechanical seam derivation)), and edge-matching derives the dep mechanically.
- **Structural change:** chiropractor gains a thin verb dispatch for the first time (`audit`
  default = today's flow; `calibrate` = the drain). The SKILL.md stays one file; calibrate's
  procedure is a section, not a separate verb file, until the skill earns more verbs.

## 4. Architect `calibrate` — drain design-flavored signal (distinct from `distill`)

New verb: harvest the signal slice *about the seed* — a spec that repeatedly misleads builds, a
contract complaint, a "this tenet fights reality" observation — and fold it into targeted seed
edits (or route big items to a brainstorm/plan pass).

**`calibrate` ≠ `distill`, kept sharp:** `distill` compacts the seed's *own accretion* (ADRs/plans
already in the record stores) into clean present-tense specs; `calibrate` folds *external signal*
(tracker entries about dev experience with the seed) into it. One compresses inward, the other
absorbs inward. The verb file states this seam in one line and otherwise reuses distill's editing
discipline (hand-edit, never bulk; seed stays regenerable).

Edges: architect's `## Edges` gains `consumes: tracker-entry` alongside its existing `design`
consumption.

## 5. Cross-skill wiring (runbook, not leaves)

- **Vocabulary:** `tracker-entry` gains two consumers — no new types. `derive-seams` reports the
  new deps mechanically; the vocabulary table regenerates.
- **New/changed seam rows in `packs/clankshop.md`:**
  - `backlog ↔ chiropractor` — capture vs. doc-drain (**dep**: chiropractor reads `tracker-entry`,
    optional).
  - `backlog ↔ architect` — capture vs. design-drain (**dep**: architect reads `tracker-entry`).
  - `foreman ↔ chiropractor` — existing row gains the drain split: foreman classifies + dispatches
    the doc slice; chiropractor drains it (affordance/fidelity wording unchanged).
  - `architect ↔ foreman` — existing altitude row gains the same drain-split sentence.
- **Routing surface (the known risk):** three descriptions will carry "calibrate"-flavored
  language. Self-scoping must carry the layer — *workflow/doctrine* vs. *doc-spine* vs.
  *design-seed* — and the rollout's acceptance gate is a routing probe over at least these pairs:
  "fold this feedback into the docs" (→ doc steward), "the design keeps misleading us, fix the
  spec" (→ design steward), "calibrate the dev system" (→ foreman), "the workflow keeps tripping
  me" (→ foreman). A mis-route fails the gate; the fix is sharper self-scope, never a
  cross-reference.

## 6. Rollout surfaces

1. **`skills/chiropractor/`** — SKILL.md gains the thin dispatch (audit default | calibrate) + the
   calibrate section + the edges change. Description gains layer-scoped drain language.
2. **`skills/architect/`** — new `verbs/calibrate.md` + SKILL.md dispatch row + edges change +
   description language. One distill-vs-calibrate seam line in both verb files' headers.
3. **`skills/foreman/verbs/calibrate.md`** — the rescope: step 3 gains the three-way
   classification; a dispatch step replaces the current blanket "hand broad doc-tuning" pointer.
4. **`packs/clankshop.md`** — the seam rows (§5) + vocabulary-table regeneration note.
5. **Gate** — `skills-lint.sh` `fails=0`; `derive-seams` re-run confirms the two new deps; the §5
   routing probe (fresh subagent, descriptions only) passes 4/4.

## 7. Alternatives considered

- **One central drain (status quo):** foreman calibrates everything. Rejected: foreman lacks the
  doc-form and seed-content judgment its dispatch targets have, and its verb file already punts the
  doc slice.
- **A fourth "drain" skill:** a dedicated feedback-router. Rejected: pure indirection — the
  classify step is composer work foreman already does for changes; a new skill adds a tier-1 hop
  and a routing surface for no payload.
- **Full verb-set symmetry (every steward gets every verb):** rejected as procrustean — see §1;
  empty cells are stated, not filled.
