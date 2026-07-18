# `foreman migrate` — the brownfield onramp — Implementation Plan

**Status:** Design agreed; not yet implemented.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add a `migrate` verb to `foreman` — an interactive, preview-first wizard that brings an **existing (pre-grimoire or ad-hoc) project** into the current grimoire layout: locate the existing dev-meta, propose a complete old→new relocation mapping, confirm/edit, apply with `git mv` (history preserved), then scaffold the gaps and write the ownership index. A brownfield counterpart to `init`.

**Architecture:** Prose/skills repo. Authoring one new verb file + wiring it into `foreman`. The gate is `scripts/skills-lint.sh` (`fails=0`). `migrate.md` is a **procedure with human-in-the-loop checkpoints** — it does not encode a hardcoded path remap; it classifies what it finds against the **current** ownership index / taxonomy.

**Reference:** the design conversation this plan implements (this session). Prior: `docs/design/2026-07-17-storage-migration-foreman.md` (the two-root layout + ownership index this wizard targets).

## Global Constraints

- **Gate, every task:** `bash scripts/skills-lint.sh` → `fails=0` before each commit. WARN lines allowed.
- **Frontmatter `description:`** ≤1024 chars; quote if it contains `": "`.
- **Commits** scoped to paths touched; **no `Co-Authored-By` trailer**.
- **`migrate` is the highest-stakes verb** — it MOVES a project's existing content. It is **preview-first**: nothing is moved before the user approves the mapping; moves use `git mv` to preserve history; it never clobbers existing target content.
- Portable prose: name the generic concept ("the ownership index", "the trunk"), never a specific harness.

## Locked design (from the conversation)

- **`migrate` = the brownfield onramp; `init` stays greenfield.** `init` scaffolds fresh (or from a brief); `migrate` transforms what's already there. `migrate` does the **whole job** — relocate found content **and** scaffold the gaps — so a project ends fully set up (equivalent to a post-`init` state, having absorbed existing content).
- **`foreman` verbs become: `route` / `init` / `migrate` / `calibrate` / `check`.**
- **Locate = smart default, not hardcoded.** The wizard's discovery step defaults to a `dev/` directory at the repo root (the convention the host's prior projects use); if absent, it asks where the existing dev-meta lives (or advises `/foreman init` if there is none). Because it classifies *whatever it finds*, the same wizard also handles an old `.agents/dev/` (a future grimoire-version upgrade) — the `dev/` default is just the happy path, not a ceiling.
- **Index-driven mapping.** Classification targets the **current** homes via the ownership index (`.agents/README.md` / `.records/README.md`) and the capture taxonomy — so it stays correct as the layout evolves; it is not a fixed old→new table.
- **Propose-the-whole-mapping-then-confirm.** The wizard presents the *complete* old→new relocation plan in one preview for the user to edit/approve, asking targeted questions **only** on genuinely ambiguous artifacts — "basic questions," not a file-by-file interrogation.

## The classification the wizard proposes (default heuristics; all user-confirmable)

| found (under `dev/` or wherever) | → current home | kind |
|---|---|---|
| `BACKLOG.md` / a task list | `.records/tasks.md` | tasks (backlog) |
| `ISSUES.md` / friction log | `.records/issues.md` | issues |
| `FEEDBACK.md` | `.records/feedback.md` | feedback |
| `bugs/` (defect reports) | `.records/bugs/` | bugs |
| `notes/` (durable facts) | `.records/notes/` | notes |
| dev-process docs (how-we-work, DEVELOPMENT/PLANNING/WORKFLOWS…) | `.agents/foreman/docs/` | doctrine |
| `MEMORY.md` / invariants, `GOTCHAS.md` | `.agents/foreman/` | doctrine |
| design docs (vision/philosophy/architecture-of-the-product) | `.agents/architect/` | design seed |
| `plans/` (design/impl plans, roadmaps) | `.records/plans/` | plans |
| `done/` / shipped records | `.records/archive/` | archive |
| ADRs | `.records/adr/` | adr |
| audit rubric (GUIDE/rules) vs findings | `.agents/auditor/` vs `.records/audit/` | audit |
| reports, logs | `.records/reports/`, `.records/logs/` | records |
| **unrecognized** | (flag — ask the user) | ? |

The wizard proposes this mapping for what it actually finds, marks unrecognized items for a question, and lets the user override any row before anything moves.

---

## Task 1: Author `foreman/verbs/migrate.md` + wire into `foreman/SKILL.md`

**Files:**
- Create: `skills/foreman/verbs/migrate.md`
- Modify: `skills/foreman/SKILL.md` (dispatch table + description + identity line)

**Interfaces:**
- Produces: `/foreman migrate` — the brownfield onramp verb.

- [ ] **Step 1: Baseline.** `bash scripts/skills-lint.sh` → `fails=0`; record BASE (`git rev-parse --short HEAD`).

- [ ] **Step 2: Author `skills/foreman/verbs/migrate.md`.** A preview-first, human-in-the-loop wizard. Model its structure/tone on `skills/foreman/verbs/init.md` (it reuses init's scaffold + index-write for the gap-fill). Required procedure:
  1. **Preconditions.** Resolve root + real date. Confirm the checkout is on the integration **trunk** (the shared-discipline trunk guard) and note that `migrate` MOVES existing content. If the project already has a current grimoire layout, say so and suggest `/foreman check` instead.
  2. **Locate** the existing dev-meta: default to a `dev/` directory at the repo root; if absent, ask the user where it lives (accepting a path), or — if there is none — direct them to `/foreman init` (greenfield) and stop.
  3. **Classify + build the mapping.** Walk the located tree; for each artifact, classify it against the current taxonomy + ownership index using the default heuristics (table above) — produce a **complete old→new relocation table**. Mark unrecognized artifacts as `?` for a targeted question. This is a *fact-gathering* step: propose, don't decide unilaterally.
  4. **Present + confirm (preview-first).** Show the *entire* proposed mapping in one table. Ask targeted questions **only** for the `?` rows (and any the user should sanity-check). Let the user edit/approve any row. **Nothing moves until the user approves.**
  5. **Apply.** For each approved row, `git mv <old> <new>` (preserve history); create target dirs as needed; **never overwrite** an existing target (if a collision, stop and ask). Commit scoped to the moved paths via the pathspec-atomic helper; no `Co-Authored-By`.
  6. **Scaffold the gaps + index.** For homes with no migrated content, scaffold them (reuse `init`'s scaffold of `.agents/{architect,foreman,auditor}/` + the `.records/` tree). Write/update the ownership index (`.agents/README.md` + `.records/README.md`) and stamp the version — so the project ends in a complete, `check`-valid state.
  7. **Report.** A chat summary: what moved where (the applied table), what was scaffolded, and any unrecognized artifacts left for the user to place by hand.
  - Carry the shared discipline (resolve root+date; scripts-compute-facts; commit-on-trunk + guard; pathspec-atomic scoped commit; no `Co-Authored-By`) as the other verbs do — state the migrate-specific bits (preview-first, `git mv`, no-clobber) explicitly.

- [ ] **Step 3: Wire into `skills/foreman/SKILL.md`.**
  - Add a dispatch-table row: `/foreman migrate` → `verbs/migrate.md` — "bring an existing (pre-grimoire / ad-hoc) project into the layout (locate → propose mapping → confirm → git-mv + scaffold)".
  - Update the `description:` to include `migrate` (the brownfield onramp; init=greenfield). Keep ≤1024, quoted (it contains `": "`).
  - Update the identity/verb line so the set reads `route`/`init`/`migrate`/`calibrate`/`check`, and note the init/migrate seam (greenfield vs brownfield).

- [ ] **Step 4: Verify.**
```bash
ls skills/foreman/verbs/    # migrate.md present (route/init/migrate/calibrate/check)
grep -n 'migrate' skills/foreman/SKILL.md | head    # dispatch row + description mention
bash scripts/skills-lint.sh    # fails=0 (SKILL's `verbs/migrate.md` ref resolves — no MISS; description valid length/quoting)
./install.sh --list            # 10 skills unchanged
```

- [ ] **Step 5: Commit.**
```bash
git add skills/foreman/verbs/migrate.md skills/foreman/SKILL.md
git commit -m "foreman: add migrate verb — the brownfield onramp (locate/propose/confirm/git-mv/scaffold)" -- skills/foreman/verbs/migrate.md skills/foreman/SKILL.md
```

---

## Task 2: Front-door + final verify

**Files:** `skills/foreman/BOOTSTRAP.md`, `packs/clankshop.md`, `README.md` (wherever foreman's verbs / the init story are described), `docs/design/2026-07-18-foreman-migrate.md` (mark implemented).

- [ ] **Step 1: Document the brownfield onramp.** Wherever the docs describe standing up the system (foreman's `BOOTSTRAP.md`, the `packs/clankshop.md` runbook, `README.md`'s foreman entry), add the init/migrate distinction: **`init` = greenfield** (nothing there), **`migrate` = brownfield** (an existing `dev/`/ad-hoc setup → located, mapped, confirmed, relocated, and the gaps scaffolded). Keep it concise; don't restate the whole procedure.

- [ ] **Step 2: Full verify.**
```bash
bash scripts/skills-lint.sh                                  # fails=0
grep -rn 'migrate' skills/foreman/SKILL.md packs/clankshop.md README.md | head   # documented
for v in route init migrate calibrate check; do test -f "skills/foreman/verbs/$v.md" || echo "MISSING $v"; done   # no MISSING
./install.sh --list                                          # 10 skills unchanged
```

- [ ] **Step 3: Mark implemented + commit.** Set this file's Status → `Implemented (<date +%Y-%m-%d>).`
```bash
git add skills/foreman/BOOTSTRAP.md packs/clankshop.md README.md docs/design/2026-07-18-foreman-migrate.md
git commit -m "docs: document foreman migrate (brownfield onramp)" -- $(git diff --cached --name-only)
```

---

## Self-review — coverage

| Design point | Task |
|---|---|
| `migrate` verb = locate → propose → confirm → git-mv → scaffold gaps → index | 1 |
| `dev/` smart default; index-driven; classifies what it finds | 1 (Step 2.2–2.3) |
| propose-whole-mapping-then-confirm; ambiguous-only questions | 1 (Step 2.4) |
| preview-first, `git mv` history, no-clobber | 1 (Step 2.4–2.5) |
| does the whole job (relocate + scaffold gaps + index) | 1 (Step 2.5–2.6) |
| foreman verb set route/init/migrate/calibrate/check | 1 (Step 3) |
| init=greenfield / migrate=brownfield seam, front-door | 2 |

**Watch-items:**
- `migrate.md` is the riskiest content — the safety flow (preview-first, no-clobber, `git mv`) must be unmistakable, and the classification must be *proposed* (user-confirmable), never applied blind.
- Reuse `init`'s scaffold + index-write for the gap-fill rather than re-specifying it (DRY across the two verbs).
- The default classification heuristics are a *starting proposal* — the wizard must always let the user override before moving anything.
