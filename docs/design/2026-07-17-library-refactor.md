# Library refactor — sharper seams: `dev` split, `design`→`architect`, the runbook mechanism

**Date:** 2026-07-17
**Status:** Design agreed; Phase 1 not yet implemented.
**Scope:** The grimoire skill library (`skills/`, `packs/`). A structural refactor to make each
skill independent, single-identity, and joined to its neighbors by named seams.

---

## 1. Goal

Every skill should have **one clear identity, one stewarded artifact (or one clear job), and named
seams to its neighbors** — so an agent can reason about a skill in isolation and compose skills
without guessing at the contracts between them.

The current `dev` skill violates this: it is three different jobs sharing a directory (a **router**,
a **system installer/maintainer**, and a **capture bureau**), each with a different trigger moment
and a different "done." The `design` skill's name doesn't advertise its role. And the pack manifest
(`clankshop.md`) *describes* how the skills relate but nothing *consumes* that description, so the
"glue" that makes the constellation cohere never actually reaches a project.

This refactor resolves all three.

---

## 2. Guiding principles (specific to this refactor)

- **Independence with named seams.** Each skill is understandable and usable alone; where two skills
  meet, the seam is stated in both. No skill crosses another's seam.
- **Layer-steward pattern.** A recurring shape: a skill that stands up / evaluates / maintains /
  drift-corrects one *cross-cutting layer* against the code, and can do so even on a legacy repo that
  lacks the layer. `architect`, `foreman`, and `chiropractor` are all instances (see §5).
- **Mechanism vs. composition.** The *mechanism* (how to instantiate a development system) lives in a
  skill; the *composition* (which skills are in this constellation and how they relate) lives in the
  pack. The pack **calls** the skill — never the reverse (correct dependency direction).
- **Single collection front-door.** All follow-up signal is captured through one skill (`backlog`).
  Working agents never run two collection skills. Classification that needs judgment (e.g. "is this a
  code problem or a workflow problem?") happens **downstream**, not at capture time.
- **A snapshot must never pose as authoritative.** Anything generated (the project glue) is a
  snapshot of its source + the installed skills at generation time. Stamp what it was built against;
  ship a cheap validator (`foreman check`); say "verify before trusting."

---

## 3. Target architecture (whole picture)

- **Stewards** (own a cross-cutting layer's lifecycle):
  `architect` (design seed) · `foreman` (workflow glue + change-router) · `chiropractor` (doc spine)
- **Operators** (consume the seeds, act):
  `feature` (build) · `backlog` (capture inbox) · `workstream` (ship-loop)
- **Auditor** (owns no layer; emits findings): `audit` (code quality)
- **Plumbing** (orchestration/transport): `delegate` · `mailbox` · `handoff`
- **Composition:** `packs/clankshop.md` (runbook) → drives `/foreman init`

Skill count goes from 9 to 10 (`dev` → `foreman` + `backlog`; `design` → `architect`).

---

## 4. Per-skill specifications

### 4.1 `foreman` — the integration/doctrine layer (from `dev`'s glue half)

**Identity.** The role the agent inhabits to **stand up, run, and tune the project's development
"factory."** It owns the project-specific operating manual (`dev/docs/` glue + `AGENTS.md` wiring)
that teaches an agent how the rest of the library composes *in this repo*, and it grows that manual's
competence over time. It is the runtime **change-router** and the **self-growing curation loop** —
not a capture bureau (that is `backlog`).

**Verbs:**
| verb | does |
|---|---|
| `init` | Consume a runbook (the pack's `clankshop.md` composition, or a **baseline** — introspect installed skills + name fallbacks — when installed à la carte) → instantiate this project's `dev/docs/` + `AGENTS.md` wiring. Stamp the runbook/skill versions built against. Scaffold the unified `dev/` home (including empty tracker files `backlog` will own). |
| `route` | The change-router — the runtime face of the doctrine. Classify a change (bug/patch/feature/spike/seed-altitude design) per `dev/docs/DEVELOPMENT.md` and dispatch to the lane that owns it. Default (no-arg) verb. |
| `tune` | (elevated from `upkeep`) The curation loop: drain the **system-relevant slice** of `backlog`'s captured signal into doctrine/workflow/`AGENTS.md` improvements. Low-frequency, high-judgment. This is what makes the system more competent run over run. |
| `check` | Cheap validator: flag drift between the generated glue and the current runbook / installed skills. Keeps `init`'s snapshot honest as the constellation evolves. |

**Owns:** the *mechanism* (how to instantiate any composition — pack-agnostic), the `dev/docs/`
templates, the `AGENTS.md`-wiring know-how, the change-routing policy, and the staleness-stamping.

**Consumes, does not collect:** reads `backlog`'s signal; never opens its own capture path.

### 4.2 `backlog` — the capture inbox (from `dev`'s capture half)

**Identity.** The **single collection front-door.** Owns all tracker artifacts, their formats,
grooming, and the end-of-work sweep. High-frequency, low-judgment: everything lands here uniformly,
and downstream skills (`foreman`) sift with judgment later.

**Verbs:** `bug`, `backlog`, `issue`, `feedback` (capture) · `debrief` (the end-of-work sweep that
fans out across all capture buckets) · `groom` (dedupe/rank/triage).

**Owns:** the tracker files' *content and format* (`BACKLOG.md`, `ISSUES.md`, `FEEDBACK.md`,
`bugs/`, `notes/`, `MEMORY.md`), the capture conventions, and the sweep. **Tenant** of the `dev/`
home that `foreman init` scaffolds — ownership is by skill-contract, not by subdirectory, so the
`dev/` tree stays unified and cross-references / the debrief sweep stay intact.

**No capture-time classification.** You cannot reliably tell at capture time whether a friction is a
codebase problem or a factory problem — so `backlog` does not force the cut. `foreman tune` makes it
later, with judgment.

### 4.3 `architect` — the design-seed steward (rename of `design`)

**Identity.** The role that owns the `design/` seed's **full lifecycle** — the clean, present-tense,
regenerable design that code is a build output of. A **role**-named peer to `foreman` (architect
decides *what* to build and why; foreman decides *how* it's built and runs the shop), and a
**steward** in the same family as `chiropractor` (see §5).

**Verbs (Phase 1 — unchanged from `design`):** `init`, `brainstorm`, `plan`, `distill`, `check`,
`prep`.

**Phase 2 additions (deferred — see §8):** `init` extended to **extract a design seed from code**
(for repos with no design layer); `check` extended to **design ↔ code drift**; the spec-driven /
"ralph-loop" expansion.

**Why the `blueprint` split was dropped.** `chiropractor` is *one* skill that extracts, evaluates,
maintains, and drift-corrects the doc spine — it is not split into author-docs + audit-docs. Making
`architect` one skill that does the same for the design seed is the true parallel; splitting off a
`blueprint` auditor was the un-chiropractor-like move. YAGNI and the metaphor agree. `blueprint` is
**not** a planned skill.

---

## 5. The layer-steward family

Three skills share a **method** — stand up / evaluate / maintain / correct-drift for one
cross-cutting layer against the code, usable even on a legacy repo lacking the layer:

| skill | layer stewarded | drift axis | bootstraps on a bare repo? |
|---|---|---|---|
| `architect` | design seed (`design/`) | design ↔ code | yes — extracts it (Phase 2) |
| `foreman` | workflow glue (`dev/docs/` + `AGENTS.md`) | glue ↔ installed skills | yes — `init` stands it up |
| `chiropractor` | doc spine (README/AGENTS/GLOSSARY/INDEX) | docs ↔ code | yes — its whole point |

`audit` is deliberately **not** a steward — it is a pure code-*quality* auditor that owns no layer
and emits findings. The stewards' shared method is a **future shared-doctrine opportunity** (a common
`docs/` on "steward a layer, keep it in sync with code"); not acted on in this refactor.

---

## 6. The runbook mechanism

**Problem it solves.** `clankshop.md` documents the seams, but nothing consumes them — so the glue
never flows into a project. An agent in a fresh repo has the skills but not the composition.

**Mechanism vs. composition split:**
- **`foreman` = the oven (mechanism).** How to take *a* composition and instantiate glue. Never names
  a specific skill or pack; works à la carte via a **baseline** (introspect installed skills, wire the
  recognized ones, name by-hand fallbacks for the rest).
- **`clankshop.md` = the recipe (composition).** The member list + the cross-skill seam contracts +
  the glue-workflows for this bundle. It **drives** `/foreman init`, feeding the composition. The pack
  depends on the tool, never the reverse.

**File shape (minimal disruption).** `clankshop.md` already has the right shape: frontmatter is the
machine-read install manifest (`install.sh` consumes it — untouched), the prose body is the
description. The change: **promote the body from descriptive to actionable** — from "here are the
layers" to "to stand up this constellation, run `/foreman init` and feed it this composition."

**Runbook supplies what introspection can't.** Cross-skill seams ("feature ends at gate-green") live
*between* skills, not in any one's frontmatter — so the runbook is where they must live. The baseline
handles bare installs; the runbook is enrichment.

**Snapshot discipline.** The generated glue stamps the runbook + skill versions it was built against;
`foreman check` validates drift against whichever composition drove `init`.

---

## 7. Seam catalog

| seam | contract |
|---|---|
| `backlog` ↔ `foreman` | `backlog` **captures** (single front-door, uniform); `foreman tune` **drains** the system-relevant slice into doctrine. Inbox vs. curator. |
| `foreman` ↔ `clankshop.md` | `foreman` = mechanism (oven); the pack runbook = composition (recipe). Pack **calls** foreman. |
| `foreman` ↔ `chiropractor` | `foreman` **authors** the AGENTS.md workflow-glue section; `chiropractor` **audits** the whole front-door's ergonomics. Author vs. auditor. |
| `architect` ↔ `chiropractor` | `architect`'s GLOSSARY = **domain** terms (part of the seed); `chiropractor`'s concern = a **navigational** glossary/index exists and is linked. Domain vs. navigation. |
| `architect` ↔ `feature` | `architect` authors the seed (seed altitude); `feature` builds a change against it (feature scope). Altitude seam (existing). |
| `feature` ↔ `workstream` ↔ `backlog` | `feature` ends at gate-green; `workstream` lands; `backlog debrief` captures. No skill crosses another's seam (existing). |

---

## 8. Phasing

**Phase 1 — pure structural refactor (this spec's deliverable):**
1. Split `skills/dev/` → `skills/foreman/` + `skills/backlog/`.
2. Rename `skills/design/` → `skills/architect/`.
3. Runbook mechanism: promote `clankshop.md`'s body to a consumable runbook; `foreman init` consumes it.
4. Update `install.sh`, `README.md`, `AGENTS.md`, and all cross-references.
- **Architect's verbs stay unchanged** — no new capability work mixed into the rename.

**Phase 2 — capability expansion (deferred, seams reserved in Phase 1):**
- `architect`: code → design **extraction**, and design ↔ code **drift-check** (top of the list — the
  "huge issue": projects with no design layer are hard to understand). `check` is kept scoped thin in
  Phase 1 so this lifts in cleanly.
- `architect`: spec-driven / "ralph-loop" expansion (a loop-ready spec/queue that `workstream` or a
  ralph-style runner consumes).

---

## 9. Physical migration map (Phase 1)

Current `skills/dev/` contents split as follows (final ownership of shared scripts is an open
implementation question — see §10):

**→ `skills/foreman/`**
- `SKILL.md` (rewritten: identity + verb dispatch for `init`/`route`/`tune`/`check`)
- `verbs/route.md` (moves as-is, retuned), `verbs/init.md` (reworked to consume a runbook + baseline),
  `verbs/tune.md` (from `verbs/upkeep.md`, elevated), `verbs/check.md` (new — glue-drift validator)
- `docs/{DEVELOPMENT,PLANNING,WORKFLOWS,TAXONOMY,MAINTENANCE,WORKTREES}.md` (the glue templates)
- `templates/{adr,plan-design,plan-implementation,roadmap,report}.md` (planning/system templates)
- `BOOTSTRAP.md` (reworked toward the runbook-consumption model)
- system-analysis half of `scripts/dev-health.sh`; `scripts/scoped-commit.sh` (shared — see §10)

**→ `skills/backlog/`**
- `SKILL.md` (new: identity + verb dispatch for `bug`/`backlog`/`issue`/`feedback`/`debrief`/`groom`)
- `verbs/{bug,backlog,issue,feedback,debrief}.md` (move as-is), `verbs/groom.md` (from `backlog`'s
  groom/triage sub-verbs)
- `templates/{bug-report,feedback,note,task-record}.md`
- capture/sweep half of `scripts/dev-health.sh` (`debrief-scan`); uses `scoped-commit.sh` (shared)

**Rename:** `skills/design/` → `skills/architect/` (git mv; update frontmatter `name:`, all internal
references, and `scripts/design-check.sh` naming if desired).

**Pack/docs:** `packs/clankshop.md` member list (`dev`→`foreman`+`backlog`, `design`→`architect`) +
body promoted to runbook. `install.sh` / `README.md` / `AGENTS.md` references updated.

**On-disk project artifact directory:** stays **`dev/`** (unified home) — recommended, to avoid
churning every cross-reference and the debrief sweep. (Open: whether to rename the home; default = no.)

---

## 10. Open implementation questions

1. **Shared-script ownership.** `scoped-commit.sh` (atomic pathspec commit) and `dev-health.sh`
   (fact script with both system-analysis and capture/sweep facts) are used by *both* `foreman` and
   `backlog`. Options: (a) split `dev-health.sh` by concern, each skill owning its half + a duplicated
   `scoped-commit.sh`; (b) a small shared `scripts/` location both reference; (c) `foreman` owns both
   and `backlog` calls them. Lean: (a) split the fact-script by concern; `scoped-commit.sh` is tiny
   enough to duplicate rather than create a shared-dependency seam. Decide during build.
2. **`upkeep`'s spine-health half.** `upkeep` had a "drain the trackers" half (→ `foreman tune`) and a
   "docs-system spine health" half. Lean: glue-specific drift → `foreman check`; general doc-spine
   health stays `chiropractor`. Confirm the cut during build.
3. **`route` as `foreman`'s no-arg default.** Confirm `/foreman` (no arg) = `route`, matching today's
   `/dev`.
4. **Migration for existing installs.** These are symlink-installed, user-namespaced skills; renames
   (`dev`→two, `design`→`architect`) break existing symlinks. `install.sh` `remove`/`list` must handle
   the transition; document the upgrade path.
5. **Runbook file name / location** within the mechanism (e.g. keep `clankshop.md` as the runbook vs. a
   dedicated `RUNBOOK.md` the pack points to). Current lean: the pack manifest *is* the runbook.
6. **Capture-taxonomy ownership.** The capture taxonomy (the buckets + the one-home rule) is
   conceptually `backlog`'s, but is documented today in `foreman`'s glue docs (`DEVELOPMENT.md` →
   *Capture follow-ups*, and `TAXONOMY.md` → schema). Lean: **`backlog` owns the taxonomy/schema**;
   `foreman`'s routing doc (`DEVELOPMENT.md`) *references* it rather than restating it — matching the
   author/consumer arrow used elsewhere. Decide during build which file the schema lives in.

---

## 11. Naming decisions & rationale (for future readers)

- **`foreman`** (not `playbook`/`foundry`/`forge`/`workshop`). A role the agent inhabits — stands up
  the factory, runs the line, tunes it. The role framing beats document-names because the self-growing
  facet needs an *actor*: "a foreman who fine-tunes the line," not "a document that improves itself."
  `foundry`/`forge` evoke *making* (which is `feature`/`workstream`), not *managing*; `workshop`
  collides with `workstream`.
- **`architect`** (not `blueprint` for the engine). A **role**, pairing with `foreman`: architect =
  *what/why*, foreman = *how*. Better than the artifact+role mismatch of `blueprint`+`foreman`.
- **`blueprint` — dropped entirely.** Considered as a split-off design↔code conformance auditor;
  removed by YAGNI once we saw `architect`-as-one-lifecycle-skill is the true `chiropractor` parallel.
- **`backlog`** — an artifact-name (like `mailbox`), fine alongside the role-names; the library
  already mixes both registers.

---

## 12. Non-goals

- No expansion of `architect`'s capabilities in Phase 1 (extraction, drift-check, ralph-loop are all
  Phase 2).
- No new `blueprint` skill (dropped).
- No rename of the on-disk `dev/` project directory (default; revisit only if a reason surfaces).
- No consolidation of the stewards' shared method into common doctrine yet (future opportunity).
