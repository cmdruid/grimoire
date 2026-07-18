# Storage Layout Migration + `foreman` Refinement — Implementation Plan

**Status:** Design agreed; not yet implemented.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Migrate the library to a two-root storage layout — **`.agents/<skill>/` for the source-of-truth seeds** (skill-named, 1:1-owned) and **`.records/` for typed records** (type-named, contract-owned) — and land `foreman`'s refinements: verb `tune`→`calibrate`, `dev-health.sh`→`foreman-health.sh`, and template redistribution to `/feature`.

**Architecture:** Prose/skills repo, **no actual `.agents/` directories** — every path reference is prose (instructions for a host project), so all edits are string/prose changes, not file moves. The gate is `scripts/skills-lint.sh` (`fails=0`). "Tests" = the lint gate + reference-integrity greps + `install.sh --list` + the scripts' testdata.

**Reference:** the design conversation this plan implements (this session). Prior: `docs/design/2026-07-17-library-refactor.md`, `…-backlog-refinement-plan.md`.

## Global Constraints

- **Gate, every task:** `bash scripts/skills-lint.sh` → `fails=0` before each commit. WARN lines allowed.
- **Frontmatter `description:`** ≤1024 chars; quote if it contains `": "`.
- **Commits** scoped to paths touched; **no `Co-Authored-By` trailer**.
- **The two-root layout is the target** (see mapping table). Skill-named seed homes under `.agents/`; typed records under top-level `.records/`.
- **Ownership is by contract + index, not path.** With type-named record dirs, the `AGENTS.md` / index must document who stewards what (Task 7).

## The canonical path mapping (every task applies part of this)

| old path | new path | owner |
|---|---|---|
| `.agents/design/…` | `.agents/architect/…` | architect (seed) |
| `.agents/dev/docs/…` | `.agents/foreman/docs/…` | foreman (doctrine) |
| `.agents/dev/MEMORY.md` | `.agents/foreman/MEMORY.md` | foreman |
| `.agents/dev/GOTCHAS.md` | `.agents/foreman/GOTCHAS.md` | foreman |
| `.agents/dev/README.md` (home index) | `.agents/foreman/README.md` | foreman |
| `.agents/dev/plans/…` | `.records/plans/…` | feature writes |
| `.agents/dev/done/…` | `.records/done/…` | workstream writes |
| `.agents/dev/adr/…` | `.records/adr/…` | architect writes / distills |
| `.agents/dev/reports/…` | `.records/reports/…` | foreman (spikes) |
| `.agents/dev/logs/…` | `.records/logs/…` | various |
| `.agents/dev/audit/…` | **`.agents/auditor/…`** *(OPEN — see Decisions)* | auditor |
| `.agents/dev/templates/…` | *(removed — skills use their bundled `templates/`)* | — |
| `.agents/backlog/TASKS.md` | `.records/tasks.md` | backlog stewards |
| `.agents/backlog/ISSUES.md` | `.records/issues.md` | backlog stewards |
| `.agents/backlog/FEEDBACK.md` | `.records/feedback.md` | backlog stewards |
| `.agents/backlog/bugs/…` | `.records/bugs/…` | backlog stewards |
| `.agents/backlog/notes/…` | `.records/notes/…` | backlog stewards |
| `.agents/backlog/templates/…` | *(removed — backlog uses its bundled `templates/`)* | — |

**Non-path changes:**
- Verb: `/foreman tune` → `/foreman calibrate`; file `foreman/verbs/tune.md` → `calibrate.md`.
- Scripts: `foreman/scripts/dev-health.sh` → `foreman-health.sh`; `backlog/scripts/dev-health.sh` → `backlog-health.sh`.
- Templates: `plan-design.md`, `plan-implementation.md`, `roadmap.md`, `adr.md` → **`feature/templates/`**; `report.md`, `done-record.md` stay in `foreman/templates/`; `bug-report.md`/`feedback.md`/`note.md` stay in `backlog/templates/`.

**Record shape:** flat-list trackers are single files (`.records/tasks.md`, `.records/issues.md`, `.records/feedback.md`); multi-file stores are dirs (`.records/{bugs,notes,plans,done,adr,reports,logs}/`).

## Open decisions (resolve at review — recommendations baked in)

1. **The auditor subsystem `.agents/dev/audit/` → `.agents/auditor/` (recommended).** This wasn't in the design conversation. The audit framework (`GUIDE.md`, `rules/`, `FINDINGS.md`, `metrics.csv`, `history/`) is a cohesive body `auditor` deploys and stewards 1:1 — so a skill-named home (`.agents/auditor/`) is consistent with `architect`/`foreman`. Alternative: split config (`GUIDE`/`rules` → `.agents/auditor/`) from findings (`FINDINGS`/`metrics`/`history` → `.records/audit/`). **Plan assumes the cohesive `.agents/auditor/`; confirm or override.**
2. **Edge-case paths (1 ref each), classify per context in Task 3:** `.agents/dev/GLOSSARY.md` (→ `.agents/architect/` if it's the design glossary, else foreman index), `.agents/dev/ROADMAP.md` (→ `.records/` as a roadmap record, or `feature`), `.agents/dev/INDEX.md` (→ the Task-7 layout index), `.agents/dev/sessions` (→ `.records/sessions/` or `handoff`'s scratch). Implementer flags any it can't classify confidently.

---

## Task 1: `.agents/design/` → `.agents/architect/`

**Files:** ~14 (mostly `skills/architect/**`, plus `foreman/verbs/init.md`, `README.md`, `packs/clankshop.md`).

- [ ] **Step 1: Baseline.** `bash scripts/skills-lint.sh` → `fails=0`; `git rev-parse --short HEAD` (record BASE).
- [ ] **Step 2: Apply the mapping.** Replace `.agents/design/` → `.agents/architect/` in every file: `grep -rln '\.agents/design/' skills/ README.md AGENTS.md packs/` then edit each. This is the *artifact home* path — do NOT touch the skill name `architect`/`design` as a word, `/feature`'s own `design` verb, or bundle paths.
- [ ] **Step 3: Verify.**
```bash
grep -rn '\.agents/design/' skills/ README.md AGENTS.md packs/    # no output
grep -rc '\.agents/architect/' skills/architect | head             # present
bash skills/architect/scripts/architect-check.sh skills/architect/scripts/testdata/good >/dev/null && echo good=PASS
bash scripts/skills-lint.sh                                         # fails=0
```
- [ ] **Step 4: Commit.** `git add -A skills README.md packs/clankshop.md && git commit -m "storage: architect seed home .agents/design -> .agents/architect" -- $(git diff --cached --name-only)`

---

## Task 2: Records migration → `.records/`

**Files:** `skills/backlog/**`, plus every skill referencing `.agents/dev/{plans,done,adr,reports,logs}` (workstream, feature, foreman docs, architect, auditor, etc.).

- [ ] **Step 1: Backlog trackers → `.records/`.** Apply: `.agents/backlog/TASKS.md`→`.records/tasks.md`, `ISSUES.md`→`.records/issues.md`, `FEEDBACK.md`→`.records/feedback.md`, `.agents/backlog/bugs/`→`.records/bugs/`, `.agents/backlog/notes/`→`.records/notes/`. **Do NOT** touch `.agents/backlog/templates/` here (Task 6). Sweep `grep -rln '\.agents/backlog/\(TASKS\|ISSUES\|FEEDBACK\|bugs\|notes\)' skills/ README.md AGENTS.md packs/`.
- [ ] **Step 2: Operational records → `.records/`.** Apply: `.agents/dev/plans/`→`.records/plans/`, `done/`→`.records/done/`, `adr/`→`.records/adr/`, `reports/`→`.records/reports/`, `logs/`→`.records/logs/`. Sweep `grep -rnE '\.agents/dev/(plans|done|adr|reports|logs)' …`. **Leave** `.agents/dev/{docs,MEMORY,GOTCHAS,README,audit,templates}` (Tasks 3/4/6).
- [ ] **Step 3: Verify.**
```bash
grep -rnE '\.agents/backlog/(TASKS|ISSUES|FEEDBACK|bugs|notes)' skills/ README.md AGENTS.md packs/   # no output
grep -rnE '\.agents/dev/(plans|done|adr|reports|logs)' skills/ README.md AGENTS.md packs/            # no output
grep -rlE '\.records/(tasks|issues|feedback|bugs|notes|plans|done|adr|reports)' skills/ | head       # present
bash scripts/skills-lint.sh                                                                          # fails=0
```
- [ ] **Step 4: Commit.** `git commit -m "storage: trackers + operational records -> .records/" -- $(git diff --cached --name-only)` (stage deliberately).

---

## Task 3: foreman doctrine home `.agents/dev/{docs,MEMORY,GOTCHAS,README}` → `.agents/foreman/`

**Files:** `skills/foreman/**`, plus any skill referencing foreman's doctrine paths.

- [ ] **Step 1: Apply the mapping.** `.agents/dev/docs/`→`.agents/foreman/docs/`, `.agents/dev/MEMORY.md`→`.agents/foreman/MEMORY.md`, `.agents/dev/GOTCHAS.md`→`.agents/foreman/GOTCHAS.md`, `.agents/dev/README.md`→`.agents/foreman/README.md`. Sweep `grep -rnE '\.agents/dev/(docs|MEMORY|GOTCHAS|README)' …`.
- [ ] **Step 2: Edge cases (Decisions #2).** Classify `.agents/dev/{GLOSSARY,INDEX,ROADMAP}.md`, `.agents/dev/sessions` per context; flag any unclear.
- [ ] **Step 3: Verify — and confirm the dev/ split is complete except audit/templates.**
```bash
grep -rnE '\.agents/dev/(docs|MEMORY|GOTCHAS|README)' skills/ README.md AGENTS.md packs/   # no output
grep -rn '\.agents/dev/' skills/ README.md AGENTS.md packs/ | grep -vE '\.agents/dev/(audit|templates)'   # empty (only audit/templates remain, for Tasks 4/6)
bash scripts/skills-lint.sh                                                                 # fails=0
```
- [ ] **Step 4: Commit.** `git commit -m "storage: foreman doctrine home .agents/dev -> .agents/foreman" -- $(git diff --cached --name-only)`

---

## Task 4: auditor subsystem `.agents/dev/audit/` → `.agents/auditor/`

*(Contingent on Decision #1. If overridden to a split, adjust.)*

**Files:** `skills/auditor/{SKILL.md,BOOTSTRAP.md}` (the 21 refs) + any cross-refs.

- [ ] **Step 1: Apply.** `.agents/dev/audit/` → `.agents/auditor/` across `skills/auditor/**` and anywhere else it appears. Update `auditor`'s BOOTSTRAP/SKILL to describe its home as `.agents/auditor/`.
- [ ] **Step 2: Verify.**
```bash
grep -rn '\.agents/dev/audit' skills/ README.md AGENTS.md packs/   # no output
grep -rn '\.agents/dev/' skills/ README.md AGENTS.md packs/ | grep -v '\.agents/dev/templates'   # empty (only templates remain, Task 6)
bash scripts/skills-lint.sh                                        # fails=0
```
- [ ] **Step 3: Commit.** `git commit -m "storage: auditor subsystem .agents/dev/audit -> .agents/auditor" -- skills/auditor $(git diff --cached --name-only)`

---

## Task 5: foreman verb `tune`→`calibrate` + script renames

**Files:** `foreman/verbs/tune.md`→`calibrate.md`, `foreman/SKILL.md`, `foreman/scripts/dev-health.sh`→`foreman-health.sh`, `backlog/scripts/dev-health.sh`→`backlog-health.sh`, + every `/foreman tune` and `dev-health` reference repo-wide.

- [ ] **Step 1: Rename the verb file + rewrite.** `git mv skills/foreman/verbs/tune.md skills/foreman/verbs/calibrate.md`. Rewrite it as `/foreman calibrate` — lean into the function: **consume the dev-experience signal (`.records/feedback`, plus issues/notes) and calibrate foreman's own docs + `AGENTS.md`; promote durable notes → `MEMORY.md`/`GOTCHAS.md`.** Keep the commit discipline. (Same procedure content, renamed + sharpened.)
- [ ] **Step 2: Update `foreman/SKILL.md`.** Dispatch table + description: `route`/`init`/`calibrate`/`check` (calibrate replaces tune). Update the identity line ("stand up, run, calibrate").
- [ ] **Step 3: Repoint `/foreman tune` → `/foreman calibrate` repo-wide.** `grep -rn '/foreman tune\|`tune`' skills/ README.md AGENTS.md packs/` — replace each (20 files; includes backlog's verbs/SKILL/TAXONOMY and foreman's docs). Watch for the bare word `tune` used as the verb (not the English word).
- [ ] **Step 4: Rename the scripts + repoint.** `git mv skills/foreman/scripts/dev-health.sh skills/foreman/scripts/foreman-health.sh`; `git mv skills/backlog/scripts/dev-health.sh skills/backlog/scripts/backlog-health.sh`. Update every `dev-health.sh` reference (7 files) to the new name. Update the scripts' internal home-scan paths to the new layout (`foreman-health.sh` scans `.agents/foreman/`; `backlog-health.sh` scans `.records/`). `bash -n` both.
- [ ] **Step 5: Verify.**
```bash
grep -rn '/foreman tune' skills/ README.md AGENTS.md packs/   # no output
grep -rn 'dev-health' skills/                                  # no output
ls skills/foreman/verbs/                                       # calibrate.md, no tune.md
test -f skills/foreman/scripts/foreman-health.sh && test -f skills/backlog/scripts/backlog-health.sh && echo scripts-ok
bash -n skills/foreman/scripts/foreman-health.sh && bash -n skills/backlog/scripts/backlog-health.sh
bash scripts/skills-lint.sh                                    # fails=0
```
- [ ] **Step 6: Commit.** `git commit -m "foreman: tune -> calibrate (verb + fn); dev-health -> foreman-health/backlog-health" -- $(git diff --cached --name-only)`

---

## Task 6: Template redistribution

**Files:** create `skills/feature/templates/`; git mv four templates; update refs in `feature/SKILL.md`, `foreman/**`, `workstream/**`, and drop the deployed `.agents/*/templates/` paths.

- [ ] **Step 1: Move planning/design templates to `/feature`.**
```bash
mkdir -p skills/feature/templates
git mv skills/foreman/templates/plan-design.md        skills/feature/templates/plan-design.md
git mv skills/foreman/templates/plan-implementation.md skills/feature/templates/plan-implementation.md
git mv skills/foreman/templates/roadmap.md            skills/feature/templates/roadmap.md
git mv skills/foreman/templates/adr.md                skills/feature/templates/adr.md
```
`report.md` and `done-record.md` stay in `skills/foreman/templates/`. (`adr` → feature per "sole consumer"; confirm at review if you'd rather it go to architect.)
- [ ] **Step 2: Repoint template refs to the owning skill's bundle.** In `feature/SKILL.md`, the `.agents/dev/templates/plan-*` / `roadmap` / `adr` refs → feature's own `templates/…`. Drop the deployed `.agents/dev/templates/` and `.agents/backlog/templates/` paths everywhere — a skill uses its **bundled** `templates/<x>.md`, not a deployed copy. `grep -rnE '\.agents/(dev|backlog)/templates' skills/` → fix each.
- [ ] **Step 3: Verify.**
```bash
grep -rnE '\.agents/(dev|backlog)/templates' skills/ README.md AGENTS.md packs/   # no output
ls skills/feature/templates/     # adr, plan-design, plan-implementation, roadmap
grep -rn 'templates/plan-\|templates/roadmap\|templates/adr' skills/feature      # feature refs its own bundle
bash scripts/skills-lint.sh                                                       # fails=0 (feature's intra-skill template refs resolve)
```
- [ ] **Step 4: Commit.** `git commit -m "templates: plan-*/roadmap/adr -> feature bundle; drop deployed template paths" -- $(git diff --cached --name-only)`

---

## Task 7: Index + scaffold + front-door

**Files:** `foreman/verbs/init.md`, `foreman/BOOTSTRAP.md`, `packs/clankshop.md`, `README.md`, `AGENTS.md`.

- [ ] **Step 1: `foreman init` / `BOOTSTRAP` scaffold the two-root layout.** Update the scaffold + directory manifest to stand up `.agents/{architect,foreman,auditor}/` (seed homes) + `.records/{tasks.md,issues.md,feedback.md,bugs/,notes/,plans/,done/,adr/,reports/,logs/}` (typed records). Ensure the BOOTSTRAP `docs/` manifest names only files `foreman` actually bundles (lint check #3).
- [ ] **Step 2: Generate the layout index (the load-bearing piece).** `foreman init` writes an index that maps **content → location → steward** — e.g. a top-level `AGENTS.md` pointer block and/or `.records/README.md` + `.agents/README.md`. Since paths no longer encode ownership, this index is required: "tasks/issues/feedback/bugs/notes → `.records/…`, stewarded by `/backlog`; plans → `.records/plans/` (feature); design seed → `.agents/architect/`; doctrine → `.agents/foreman/`; audit → `.agents/auditor/`."
- [ ] **Step 3: Runbook documents the canonical layout.** In `packs/clankshop.md`, add the two-root layout + ownership map as the composition `foreman init` instantiates (extends the existing seam catalog).
- [ ] **Step 4: README/AGENTS.** Reflect the two-root layout + the ownership map.
- [ ] **Step 5: Verify.** `bash scripts/skills-lint.sh` → `fails=0`; the BOOTSTRAP manifest validates; the layout + ownership map appear in the index/runbook.
- [ ] **Step 6: Commit.** `git commit -m "foreman: scaffold two-root layout + ownership index; runbook + front-door" -- $(git diff --cached --name-only)`

---

## Task 8: Final verification + mark implemented

- [ ] **Step 1: Full green suite.**
```bash
bash scripts/skills-lint.sh                                                                     # fails=0
grep -rn '\.agents/design/\|\.agents/backlog/\|\.agents/dev/' skills/ README.md AGENTS.md packs/  # no output (all migrated)
grep -rn '/foreman tune\|dev-health' skills/ README.md AGENTS.md packs/                          # no output
grep -rnE '\.agents/(dev|backlog)/templates' skills/                                             # no output
ls skills/foreman/verbs/ | grep -q '^calibrate.md$' && echo calibrate-ok
./install.sh --list                                                                             # 10 skills unchanged
```
- [ ] **Step 2: Mark the plan implemented.** Set this file's Status → `Implemented (<date +%Y-%m-%d>).`
- [ ] **Step 3: Commit.** `git commit -m "docs: mark storage-migration + foreman-refinement implemented" -- docs/design/2026-07-17-storage-migration-foreman.md`

---

## Self-review — coverage

| Change | Task |
|---|---|
| `.agents/design/` → `.agents/architect/` | 1 |
| backlog trackers + operational records → `.records/` | 2 |
| foreman doctrine → `.agents/foreman/` | 3 |
| auditor subsystem → `.agents/auditor/` (Decision #1) | 4 |
| `tune`→`calibrate` + script renames | 5 |
| template redistribution → `/feature` | 6 |
| index + scaffold + front-door | 7 |
| final verify | 8 |

**Watch-items:**
- Tasks 1–4 partition the old paths (`design/`, `backlog/*`, `dev/{docs,mem,gotchas}`, `dev/{plans,done,adr,reports,logs}`, `dev/audit`); each leaves interim inconsistency but is gate-green. Task-N reviewers shouldn't flag not-yet-migrated paths owned by a later task.
- The `.records/tasks.md` vs `.records/tasks/` shape (flat file vs dir) — plan uses flat files for lists, dirs for stores; adjust if you prefer uniform dirs.
- Ownership is now index-encoded, not path-encoded — Task 7's index is not optional.
- The `$(git diff --cached --name-only)` commit idiom commits everything staged — stage deliberately.
