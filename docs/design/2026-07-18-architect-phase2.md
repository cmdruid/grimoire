# `architect` Phase 2 — `extract` + `reconcile` — Implementation Plan

**Status:** Implemented (2026-07-18).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Give `architect` its two brownfield/maintenance verbs so it fully stewards the design layer: **`extract`** (recover a *descriptive, provisional* design draft from a codebase that has no design layer) and **`reconcile`** (the deep, semantic seed↔code drift check — the expensive counterpart to cheap `check`). Completes architect as a layer-steward: `init` (greenfield) · `extract` (brownfield) · `check` (cheap health) · `reconcile` (deep drift) · `distill`/`plan`/`brainstorm` (evolve).

**Architecture:** Prose/skills repo. Authoring two new verb files + doctrine + wiring. The gate is `scripts/skills-lint.sh` (`fails=0`). Both verbs are agent-judgment procedures (read code/seed, reason, report) — they compute no new mechanical facts beyond what `architect-check.sh` already emits.

**Reference:** the design conversation this plan implements (this session). Prior: `docs/design/2026-07-17-library-refactor.md` §8 (Phase 2 scope), `…-storage-migration-foreman.md` (the two-root layout + ownership index).

## Global Constraints

- **Gate, every task:** `bash scripts/skills-lint.sh` → `fails=0` before each commit. WARN lines allowed.
- **Frontmatter `description:`** ≤1024 chars; quote if it contains `": "`.
- **Commits** scoped to paths touched; **no `Co-Authored-By` trailer**.
- **DOCTRINE in `.agents/architect/`, DELIVERABLES in `.records/` (the load-bearing rule for this plan).** Both new verbs **read** `.agents/architect/` (the seed) + `src/` (code) and **write only to `.records/`** — `extract`'s descriptive draft and `reconcile`'s drift report are *deliverables*, not doctrine. The seed (`.agents/architect/`) is mutated **only** by the curated path (`init` / `distill` / a human editorial pass), never by `extract` or `reconcile` directly. This keeps the source-of-truth home pure.
- **`architect` never writes executable code** (standing discipline; it may *read* `src/`).

## Locked design (from the conversation)

- **`extract` produces a *descriptive, provisional* seed, not a prescriptive one.** The circularity trap (`docs/DOCTRINE.md` § Sufficiency) is explicit: a seed reverse-engineered from code is **not** proven sufficient to regenerate that code. So `extract`'s honest deliverable is a **map of what exists** (spine + per-system *apparent* contracts/seams), stamped "extracted from code — sufficiency-unproven," written to `.records/`. Turning it into a real prescriptive seed in `.agents/architect/` is a **separate hardening step** (human editorial pass + the fresh-agent read-test), reusing `init`'s migrate mode to fold the hardened draft in. `extract` does the code-reading; it does not stand up the seed.
- **`reconcile` is the deep, expensive, semantic drift check — distinct from cheap `check`.** `check` stays cheap-and-often (structural + `drift:<sys>=<pointer>` pointer-rot facts from `architect-check.sh`). `reconcile` reads the seed's contracts/specs **against the actual code** and surfaces *semantic* divergence, then **adjudicates** each: seed went stale (→ recommend a seed update / `distill`) vs. code drifted from intended design (→ flag it). `check`'s pointer facts *point `reconcile` at* the suspect systems. Detect + adjudicate, human-in-the-loop, **never silently patch, never touch code** (same discipline as `check`).
- **Verb pairing:** `extract` = one-time brownfield bootstrap (code → draft); `reconcile` = recurring maintenance (seed ↔ code truth-check). Neither overlaps `distill` (which folds the seed's own ADRs/plans) or `init` (brief/docs → seed).
- **Out of scope (deferred):** the ralph-loop / spec-driven build loop — a separate later effort.

## `.records/` homes for the deliverables (confirm exact names at review)

- `extract` → **`.records/design-draft/`** — the provisional, seed-shaped descriptive draft (spine + `src/<system>.md` drafts), each stamped provisional, plus an extraction report (systems found, apparent contracts, and the **sufficiency-gap list** — what a hardening pass must resolve).
- `reconcile` → **`.records/reports/`** (a `reconcile-<YYYY-MM-DD>.md` report) — the per-system divergence findings + adjudications. (Alternative: a dedicated `.records/reconcile/`; `.records/reports/` reuses the existing records dir — decide at review.)

---

## Task 1: Author `architect/verbs/extract.md` + doctrine + wire into SKILL

**Files:**
- Create: `skills/architect/verbs/extract.md`
- Modify: `skills/architect/docs/DOCTRINE.md` (extraction methodology + the deliverables-in-`.records/` rule), `skills/architect/SKILL.md` (verbs table + description)

**Interfaces:**
- Produces: `/architect extract` — code → provisional descriptive draft in `.records/design-draft/`.

- [ ] **Step 1: Baseline.** `bash scripts/skills-lint.sh` → `fails=0`; record BASE.

- [ ] **Step 2: Author `skills/architect/verbs/extract.md`.** Model tone/structure on `verbs/init.md` + `verbs/distill.md`. Required procedure:
  1. **Preconditions + honest framing.** State up front: `extract` recovers a **descriptive, provisional** draft from code — it does **not** produce a proven prescriptive seed (the circularity trap). Its output is a *map of what exists* to be hardened, written to `.records/design-draft/`, **not** to `.agents/architect/`. Resolve root + date.
  2. **When to use.** A codebase with **no design layer** (nothing for `init` migrate-mode to fold). If a seed already exists, point to `/architect reconcile` (check drift) instead.
  3. **Inventory the code.** Identify systems/modules (reuse `init` greenfield's code-inventory shape — one candidate `src/<system>.md` per identifiable code unit; seam graph from cross-references).
  4. **Draft the seed shape (descriptive).** For each system, draft an *apparent* contract (what the code appears to guarantee) + reference-arch pointers (`src/…:NN`), and draft the spine (VISION/PHILOSOPHY/GLOSSARY/MAP) as *inferred from code* — each file **stamped provisional** (`status: extracted — sufficiency-unproven`). Write all of it under `.records/design-draft/` (seed-shaped so it's foldable later). **Never** write into `.agents/architect/`.
  5. **Produce the sufficiency-gap report.** Alongside the draft, write the report: systems found, apparent contracts, and — critically — the **gaps** (invariants the code implies but doesn't explain, acceptance criteria that can't be inferred, anything a rebuild would have to guess). This is the honest "what hardening must resolve" list.
  6. **Hand off to hardening.** State the path to a real seed: a human editorial pass over the draft + the **fresh-agent read-test**, then fold the hardened draft into `.agents/architect/` via `/architect init` (migrate mode, with `.records/design-draft/` as the source). `extract` stops at the draft + gap report.
  7. **Report + commit.** Chat summary; scoped commit of the `.records/design-draft/` outputs (pathspec-atomic, no `Co-Authored-By`).
  - Carry the standing discipline (never write code; durability gradient; portable-methodology-here / project-content-there).

- [ ] **Step 3: Doctrine.** In `skills/architect/docs/DOCTRINE.md`, add the extraction methodology: the descriptive-vs-prescriptive distinction, the circularity/sufficiency caveat (cross-ref the existing § Sufficiency), and the **deliverables-in-`.records/`, seed-in-`.agents/architect/`** rule (extract/reconcile write only `.records/`; the seed is mutated only by init/distill/editorial).

- [ ] **Step 4: Wire into `skills/architect/SKILL.md`.** Add `extract` to the verbs table; update the `description:` (extract = brownfield onramp, descriptive/provisional, writes `.records/design-draft/`). Keep ≤1024, quoted.

- [ ] **Step 5: Verify.**
```bash
ls skills/architect/verbs/    # extract.md present
grep -niE 'provisional|descriptive|circularity|\.records/design-draft|read-test|never .*\.agents/architect' skills/architect/verbs/extract.md   # the safety/honesty framing is present
grep -n 'extract' skills/architect/SKILL.md | head
bash scripts/skills-lint.sh    # fails=0 (SKILL's verbs/extract.md ref resolves; description valid)
./install.sh --list            # 10 skills unchanged
```

- [ ] **Step 6: Commit.** `git add skills/architect/verbs/extract.md skills/architect/docs/DOCTRINE.md skills/architect/SKILL.md && git commit -m "architect: add extract verb — code -> provisional design draft in .records (brownfield onramp)" -- skills/architect/verbs/extract.md skills/architect/docs/DOCTRINE.md skills/architect/SKILL.md`

---

## Task 2: Author `architect/verbs/reconcile.md` + doctrine + wire into SKILL

**Files:**
- Create: `skills/architect/verbs/reconcile.md`
- Modify: `skills/architect/docs/DOCTRINE.md` (reconcile methodology + cheap-`check`/deep-`reconcile` split), `skills/architect/SKILL.md` (verbs table + description)

**Interfaces:**
- Consumes: `check`'s `architect-check.sh` facts (pointer-drift points reconcile at suspect systems).
- Produces: `/architect reconcile` — deep seed↔code drift report in `.records/reports/`.

- [ ] **Step 1: Author `skills/architect/verbs/reconcile.md`.** Model tone on `verbs/check.md` + `verbs/distill.md`. Required procedure:
  1. **Framing.** `reconcile` is the **deep, expensive, semantic** drift check — run occasionally, unlike cheap `check`. It reads the seed's contracts/specs against the **actual code** and finds where they've *semantically* diverged (not just pointer-rot). Detect + adjudicate; **never silently patch the seed, never touch code**.
  2. **Scope from `check` first.** Run/read `architect-check.sh` facts; its `drift:<sys>=<pointer>` and stale-baseline signals point at the systems most likely to have diverged — start there, then widen as the session budget allows.
  3. **Per-system semantic read.** For each system, read its `## Contract (BINDING)` + reference-arch against the code it points at. Find divergences: the code guarantees something the contract omits; the contract claims behavior the code no longer has; a seam the contract names that the code moved/dropped.
  4. **Adjudicate each divergence.** For each: decide which side is authoritative — **seed stale** (the code is the intended reality → recommend a seed update; if driven by accreted ADRs, recommend `/architect distill`) vs. **code drifted** (the code diverged from intended design → flag as a defect for the caller to fix). State the recommendation; do not apply it.
  5. **Write the report to `.records/`.** A `reconcile-<YYYY-MM-DD>.md` (per-system divergence + adjudication + recommendation) under `.records/reports/`. **Never** write `.agents/architect/` (the seed edits are the human's/`distill`'s to make on the recommendation).
  6. **Report + commit.** Chat summary; scoped commit of the report.
  - Note the seam vs `check` (cheap structural/pointer vs deep semantic), `distill` (folds ADRs, not code-comparison), and `/auditor` (code *quality* vs design *conformance*). Carry the standing discipline.

- [ ] **Step 2: Doctrine.** In `skills/architect/docs/DOCTRINE.md`, add the reconcile methodology + the cheap-`check`/deep-`reconcile` split (mirror the existing cheap-check / expensive-read-test framing), and that reconcile writes only `.records/`.

- [ ] **Step 3: Wire into `skills/architect/SKILL.md`.** Add `reconcile` to the verbs table; update `description:` (reconcile = deep semantic seed↔code drift, writes `.records/reports/`). Keep ≤1024, quoted.

- [ ] **Step 4: Verify.**
```bash
ls skills/architect/verbs/    # reconcile.md present
grep -niE 'semantic|adjudicat|\.records/reports|never .*(patch|code|\.agents/architect)|architect-check' skills/architect/verbs/reconcile.md   # framing present
grep -n 'reconcile' skills/architect/SKILL.md | head
bash scripts/skills-lint.sh    # fails=0
./install.sh --list            # 10 skills unchanged
```

- [ ] **Step 5: Commit.** `git add skills/architect/verbs/reconcile.md skills/architect/docs/DOCTRINE.md skills/architect/SKILL.md && git commit -m "architect: add reconcile verb — deep semantic seed<->code drift report in .records" -- skills/architect/verbs/reconcile.md skills/architect/docs/DOCTRINE.md skills/architect/SKILL.md`

---

## Task 3: Ownership index + front-door + final verify

**Files:** `skills/foreman/BOOTSTRAP.md` (§4.1 ownership index) + `foreman/verbs/init.md` (the index it generates), `packs/clankshop.md`, `README.md`, `docs/design/2026-07-18-architect-phase2.md` (status).

- [ ] **Step 1: Register architect's new `.records/` deliverable homes in the ownership index.** Add rows so the index (`.agents/README.md`/`.records/README.md` as generated by `foreman init` — spec'd in `foreman/BOOTSTRAP.md` §4.1) maps: `.records/design-draft/` → `/architect extract` (writer); `.records/reports/` reconcile reports → `/architect reconcile` (writer). Keep the steward map consistent across BOOTSTRAP §4.1, `init.md`, `packs/clankshop.md`, and `README.md`.

- [ ] **Step 2: Front-door.** Where architect's verbs are described (`README.md`, `packs/clankshop.md`), reflect the completed verb set (`init`/`extract`/`brainstorm`/`plan`/`distill`/`check`/`reconcile`/`prep`) and the layer-steward framing.

- [ ] **Step 3: Full verify + mark implemented.**
```bash
bash scripts/skills-lint.sh                                  # fails=0
for v in init extract brainstorm plan distill check reconcile; do test -f "skills/architect/verbs/$v.md" || echo "MISSING $v"; done
grep -rn 'design-draft\|reconcile' skills/foreman/BOOTSTRAP.md packs/clankshop.md README.md | head   # deliverable homes registered
./install.sh --list                                          # 10 skills unchanged
```
Set this file's Status → `Implemented (<date +%Y-%m-%d>).`

- [ ] **Step 4: Commit.** `git commit -m "docs: register architect extract/reconcile deliverable homes; front-door" -- $(git diff --cached --name-only)`

---

## Self-review — coverage

| Design point | Task |
|---|---|
| `extract` — code → provisional descriptive draft in `.records/design-draft/` | 1 |
| descriptive-vs-prescriptive + circularity caveat + hardening handoff | 1 (Step 2.1/2.6) |
| deliverables-in-`.records/`, seed-in-`.agents/architect/` rule (doctrine) | 1 (Step 3) |
| `reconcile` — deep semantic seed↔code drift report in `.records/reports/` | 2 |
| cheap-`check`/deep-`reconcile` split; adjudicate-not-autofix; never touch seed/code | 2 |
| ownership index registers the new `.records/` deliverable homes | 3 |
| front-door + final verify | 3 |

**Watch-items:**
- The honesty framing in `extract.md` is the risk: it must never let the descriptive draft masquerade as a proven seed, and must never write `.agents/architect/`. The reviewer should confirm both.
- `reconcile` must **recommend**, never apply — no seed edits, no code edits. Same class of guarantee as `check`.
- Confirm the exact `.records/` subdir names (`design-draft/`, `reports/` vs `reconcile/`) at review — they must match whatever the ownership index registers in Task 3.
- Both verbs read `.agents/architect/` + code but write only `.records/` — grep each verb to confirm no write-path into `.agents/architect/`.
