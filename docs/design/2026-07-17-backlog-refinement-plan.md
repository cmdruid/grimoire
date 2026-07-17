# `backlog` Refinement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Sharpen `backlog` into a pure capture-and-curate bureau over its own `.agents/backlog/` home — rename the confusing `backlog` verb to `task` and `groom` to `curate`, add a `note` capture, re-cut the taxonomy by *subject* (project vs dev-experience), and remove all *draining* (that moves to the consuming skills, chiefly `foreman`).

**Architecture:** Prose/skills repo. The gate is `scripts/skills-lint.sh` (`fails=0`). "Tests" = the lint gate + reference-integrity greps + `install.sh --list`. This repo has **no actual `.agents/` directories** — every `.agents/dev/…` reference is prose in a skill file (instructions for a host project), so all edits are string/prose changes, not file moves.

**Reference:** the design conversation this plan implements (this session). Prior refactor spec: `docs/design/2026-07-17-library-refactor.md`.

## Global Constraints

- **Gate, every task:** `bash scripts/skills-lint.sh` → `fails=0` before each commit. WARN lines allowed.
- **Frontmatter `description:`** ≤1024 chars; **quote the whole value** if it contains `": "`.
- **Commits** scoped to the paths touched; **no `Co-Authored-By` trailer**.
- **Final home/paths:** backlog's five stores live under `.agents/backlog/`: `TASKS.md`, `ISSUES.md`, `FEEDBACK.md`, `bugs/`, `notes/`. (Was `.agents/dev/{BACKLOG,ISSUES,FEEDBACK,bugs,notes}`.)
- **Final verbs (7):** `bug`, `task`, `issue`, `feedback`, `note` (capture) · `debrief` (sweep) · `curate` (hygiene). Gone: `backlog` (→`task`), `groom` (→`curate`).
- **No draining in `backlog`.** `curate` is hygiene only (dedupe/rank/sharpen/weed). `docs/TAXONOMY.md` describes *kinds + formats* only — no "how each tracker drains."

## Locked decisions (from the design conversation)

**The taxonomy — five kinds on two axes (subject × nature):**

| kind | subject | nature | store |
|---|---|---|---|
| `note` | project | durable fact / knowledge | `.agents/backlog/notes/<slug>.md` |
| `task` | project | action to build / do | `.agents/backlog/TASKS.md` |
| `issue` | project | problem / concern / limitation | `.agents/backlog/ISSUES.md` |
| `bug` | project | reproducible code defect | `.agents/backlog/bugs/<YYYY-MM-DD>-<slug>.md` |
| `feedback` | dev-experience | any observation (skills / tooling / env) | `.agents/backlog/FEEDBACK.md` |

- **`bug` vs `issue` classifier:** a concrete **reproducible code defect → `bug`** (a report in `bugs/`); a broader or non-code project problem/concern/limitation → **`issue`** (a line in `ISSUES.md`). `bug` is the sharp reproducible subtype; `issue` is the diagnostic catch-all. An `issue` may later spawn a `task`.
- **`note` vs `feedback`:** `note` = about the **project** (facts/knowledge worth remembering); `feedback` = about the **dev experience** (skills/scripts/tooling/environment). `feedback` is now the *single* dev-experience channel (it absorbs what used to be dev-friction `issue`s).
- **`note` vs `MEMORY.md`:** `note` is lower-bar captured knowledge; `MEMORY.md` is a tiny high-bar *invariant*. `backlog` only captures notes; `foreman` promotes a note → `MEMORY.md` when warranted.
- **`debrief` de-scope:** writes **only** backlog's five stores. It no longer writes `.agents/dev/MEMORY.md` or `.agents/dev/GOTCHAS.md` (a would-be memory/gotcha is captured as a **`note`**; `foreman` promotes it). The **done-record verification is dropped** from `debrief` (a `/workstream`/`/foreman` concern) — at most a one-line pointer, never a write into `.agents/dev/`.
- **`foreman` picks up draining/promotion** in `tune`: notes → `MEMORY.md`/`GOTCHAS.md`/docs; issues/feedback → doctrine. `curate` (backlog) is hygiene, `tune` (foreman) is draining.
- **`task-record.md` relocates:** `backlog/templates/task-record.md` is the *done/shipped-record* template — it belongs to `foreman` (owns `.agents/dev/done/`), not `backlog`. Move it to `foreman/templates/` and rename to `done-record.md` (avoids confusion with the new `task` verb).

---

## Task 1: `backlog` verbs + SKILL dispatch + home relocation (backlog files only)

**Files:**
- Rename: `skills/backlog/verbs/backlog.md` → `verbs/task.md`; `skills/backlog/verbs/groom.md` → `verbs/curate.md` (git mv)
- Create: `skills/backlog/verbs/note.md`
- Modify: `skills/backlog/SKILL.md`, `skills/backlog/verbs/{task,curate,note,bug,issue,feedback}.md`
- (Do NOT touch this task: `verbs/debrief.md` → Task 3; `docs/TAXONOMY.md` → Task 2; any file outside `skills/backlog/` → Task 4.)

**Interfaces:**
- Produces: `/backlog` with verbs `bug`/`task`/`issue`/`feedback`/`note`/`debrief`/`curate`; stores under `.agents/backlog/`.

- [ ] **Step 1: Baseline.** `bash scripts/skills-lint.sh` → `fails=0`. `git log --oneline -1` (record BASE).

- [ ] **Step 2: Rename the two verb files.**
```bash
git mv skills/backlog/verbs/backlog.md skills/backlog/verbs/task.md
git mv skills/backlog/verbs/groom.md   skills/backlog/verbs/curate.md
```

- [ ] **Step 3: Rewrite `verbs/task.md`.** Retitle `# `/backlog task` — capture a task (product/feature follow-up)`. Change the store from `BACKLOG.md` → `.agents/backlog/TASKS.md` throughout. Repoint self-refs: `/backlog backlog` → `/backlog task`, `/backlog groom` → `/backlog curate`. Keep the capture procedure + the standalone-self-commit policy. Remove any "draining" framing (removing shipped/dead items is `/backlog curate` for hygiene; turning tasks into work is `/feature`/`/workstream`).

- [ ] **Step 4: Rewrite `verbs/curate.md`.** Retitle `# `/backlog curate` — keep the trackers tidy: dedupe, rank, sharpen, weed`. Frame it as **hygiene across backlog's lists, never draining**. Repoint `/backlog backlog`→`/backlog task`, `/backlog groom`→`/backlog curate`. Drop any "drain from the list" language (draining is `/foreman tune`'s). Paths → `.agents/backlog/`.

- [ ] **Step 5: Author `verbs/note.md` (new).** Model structure on `verbs/feedback.md`. It captures a **durable project fact/knowledge** → `.agents/backlog/notes/<slug>.md` (from `templates/note.md`). State its kind vs. siblings: *about the project* (not the dev experience — that's `/backlog feedback`); a **fact/knowledge**, not an actionable follow-up (`task`/`issue`/`bug`); lower-bar than a `MEMORY.md` invariant (which `/foreman` promotes to). Carry the standalone-self-commit policy. Frontmatter store-dir rule: a `notes/` file needs the `templates/note.md` frontmatter (the gate rejects a store-dir file without it).

- [ ] **Step 6: Rewrite `verbs/issue.md`.** Recategorize: `issue` is now a **project** problem/concern/limitation (NOT dev-experience friction). Add the `bug` vs `issue` classifier (reproducible code defect → `/backlog bug`; broader/non-code project problem → `issue`). Update the "Do NOT use for…" cross-refs: dev-experience observations now go to `/backlog feedback`; a fact → `/backlog note`; a thing to build → `/backlog task`. Store `.agents/backlog/ISSUES.md`.

- [ ] **Step 7: Update `verbs/bug.md` and `verbs/feedback.md` cross-refs.**
  - `bug.md`: repoint `/backlog backlog`→`/backlog task`; the linked actionable item is a `TASKS.md` line or an `ISSUES.md` entry; store `.agents/backlog/bugs/`. Add `/backlog note`/`issue` to the "not this verb" list as relevant.
  - `feedback.md`: reframe as the **single dev-experience channel** (skills/scripts/tooling/environment — observations, praise, concerns, and the frictions that used to be `issue`s). Point project-subject captures elsewhere (`note`/`issue`/`task`/`bug`). Repoint verb names; store `.agents/backlog/FEEDBACK.md`.

- [ ] **Step 8: Rewrite `SKILL.md`.**
  - Frontmatter `description:` (quoted; ≤1024): the seven verbs, the five-kind subject-based taxonomy, `.agents/backlog/` home, "captures uniformly, never drains — `/foreman` drains."
  - Verb-dispatch table: 7 rows (`bug`/`task`/`issue`/`feedback`/`note`/`debrief`/`curate`) with the correct stores under `.agents/backlog/`. Keep "no default lane."
  - Prose: update the capture-commit policy verb names; `curate` = hygiene (not draining); the scope-boundary + companion-skills sections (feedback=dev-experience, issue=project, draining is `/foreman`). All paths `.agents/dev/`→`.agents/backlog/` **for backlog's own stores** (leave a reference like `.agents/dev/docs/DEVELOPMENT.md` — that's foreman's home, unchanged).

- [ ] **Step 9: Verify.**
```bash
grep -rn '/backlog backlog\|/backlog groom' skills/backlog/                 # no output
grep -rnE '\.agents/dev/(BACKLOG|ISSUES|FEEDBACK|bugs|notes|TASKS)' skills/backlog/  # no output (backlog stores now .agents/backlog/)
ls skills/backlog/verbs/                                                    # task.md curate.md note.md bug.md issue.md feedback.md debrief.md (no backlog.md/groom.md)
bash scripts/skills-lint.sh                                                 # fails=0 (no MISS: SKILL dispatch names verbs/{task,curate,note,...}.md which exist)
```

- [ ] **Step 10: Commit.**
```bash
git add -A skills/backlog
git commit -m "backlog: rename verbs (task, curate), add note, recategorize issue, home -> .agents/backlog" -- skills/backlog
```

---

## Task 2: Rewrite `docs/TAXONOMY.md` — capture schema only

**Files:** Modify `skills/backlog/docs/TAXONOMY.md`

**Interfaces:** Consumes the verb set from Task 1. Produces the canonical capture schema the verbs defer to.

- [ ] **Step 1: Rewrite to the five-kind schema.** Present the taxonomy table (kind · subject · nature · store) from Locked Decisions. For each kind: what it is, the `bug`/`issue` classifier, `note` vs `feedback` (subject cut), `note` vs `MEMORY.md` (bar), the store path (`.agents/backlog/…`), and its **format** + store-dir **frontmatter** rules (for `bugs/` and `notes/` files). 

- [ ] **Step 2: Strip all draining.** Remove any "how each tracker drains / its drain" content — the schema is *capture* only. Where draining was described, replace with a one-line pointer that draining is the consumer's job (`/foreman tune` for issues/feedback/note-promotion; `/feature`/`/workstream` for tasks). Do NOT restate foreman's procedures here.

- [ ] **Step 3: Verify.**
```bash
grep -niE '\bdrain' skills/backlog/docs/TAXONOMY.md        # only pointer-lines to /foreman etc., no drain *procedures*
grep -rnE '\.agents/dev/(BACKLOG|ISSUES|FEEDBACK|bugs|notes|TASKS)' skills/backlog/docs/TAXONOMY.md  # no output
bash scripts/skills-lint.sh                                # fails=0
```

- [ ] **Step 4: Commit.**
```bash
git add skills/backlog/docs/TAXONOMY.md
git commit -m "backlog: TAXONOMY -> five-kind capture schema (subject-based), no drains" -- skills/backlog/docs/TAXONOMY.md
```

---

## Task 3: De-scope `verbs/debrief.md`

**Files:** Modify `skills/backlog/verbs/debrief.md`

**Interfaces:** Consumes the verb set + taxonomy (Tasks 1–2). Produces a sweep that writes only backlog's five stores.

- [ ] **Step 1: Restrict the routing targets.** `debrief` fans out to backlog's capture verbs only: `/backlog task | issue | bug | feedback | note`. Update the routed-buckets list and all store paths to `.agents/backlog/{TASKS,ISSUES,FEEDBACK,bugs,notes}`. Repoint `/backlog backlog`→`/backlog task`, `/backlog groom`→`/backlog curate`.

- [ ] **Step 2: Remove the cross-home writes.** Delete the routing to `.agents/dev/MEMORY.md` and to `.agents/dev/GOTCHAS.md`. Replace with: a would-be **invariant or gotcha is captured as a `/backlog note`** (project fact/knowledge); `/foreman` promotes notes → `MEMORY.md`/`GOTCHAS.md` during `tune`. `debrief` never writes under `.agents/dev/`.

- [ ] **Step 3: Drop the done-record verification.** Remove the step that verifies/points at `.agents/dev/done/` (the `debrief-scan` `recent_done:` check and the "verify the shipped-record exists" step). At most leave a one-line note that recording what shipped is `/workstream`'s land step / `/foreman`'s job — **no write, no `.agents/dev/` path**. (If `scripts/dev-health.sh debrief-scan` still emits `recent_done:`, that's fine — just don't act on it here.)

- [ ] **Step 4: Verify.**
```bash
grep -nE '\.agents/dev/(MEMORY|GOTCHAS|done)' skills/backlog/verbs/debrief.md   # no output
grep -n '/backlog backlog\|/backlog groom' skills/backlog/verbs/debrief.md      # no output
grep -n 'MEMORY\|GOTCHAS' skills/backlog/verbs/debrief.md                       # only "capture as a note; /foreman promotes" mentions, no write targets
bash scripts/skills-lint.sh                                                      # fails=0
```

- [ ] **Step 5: Commit.**
```bash
git add skills/backlog/verbs/debrief.md
git commit -m "backlog: debrief writes only backlog stores; MEMORY/GOTCHAS via note+foreman; drop done-check" -- skills/backlog/verbs/debrief.md
```

---

## Task 4: Ripple — `foreman` / `feature` / `workstream` / `auditor` + `task-record` relocation

**Files:** Modify `skills/foreman/{docs/DEVELOPMENT.md,docs/MAINTENANCE.md,docs/PLANNING.md,docs/WORKFLOWS.md,verbs/tune.md,verbs/check.md,scripts/dev-health.sh,templates/report.md,BOOTSTRAP.md}`, `skills/workstream/{SKILL.md,flow.md,verbs/create.md,verbs/sync.md}`, `skills/auditor/BOOTSTRAP.md`, `skills/feature/SKILL.md` (as greps find). Relocate `skills/backlog/templates/task-record.md` → `skills/foreman/templates/done-record.md`.

**Interfaces:** Consumes backlog's final verbs/paths. Produces a consistent library.

- [ ] **Step 1: Repoint verb names repo-wide (outside backlog).** `grep -rn '/backlog backlog\|/backlog groom' skills/ README.md AGENTS.md packs/` → replace `/backlog backlog`→`/backlog task`, `/backlog groom`→`/backlog curate`. In `foreman` (`docs/*`, `verbs/{tune,check}.md`), the `/backlog groom` references describe backlog as the list-tidy owner — keep that meaning but rename to `curate`, and ensure the *draining* attribution reads correctly (curate = hygiene; `tune` = draining).

- [ ] **Step 2: Repoint tracker paths repo-wide (outside backlog).** `grep -rnE '\.agents/dev/(BACKLOG|ISSUES|FEEDBACK|bugs|notes)' skills/ README.md AGENTS.md packs/` → `.agents/backlog/…`, and `.agents/dev/BACKLOG.md` → `.agents/backlog/TASKS.md` specifically. **Leave** `.agents/dev/{docs,done,MEMORY.md,GOTCHAS.md,audit}` (foreman/workstream/auditor homes — unchanged). Touches `foreman/docs/*`, `foreman/scripts/dev-health.sh`, `workstream/*`, `auditor/BOOTSTRAP.md`, `foreman/templates/report.md`.

- [ ] **Step 3: `foreman tune` gains note-promotion.** In `skills/foreman/verbs/tune.md`, add that `tune` promotes backlog **`notes`** → `.agents/dev/MEMORY.md` / `.agents/dev/GOTCHAS.md` / docs when warranted (the promotion `debrief` no longer does), alongside its existing draining of issues/feedback → doctrine. Update the `/backlog groom`→`/backlog curate` references and keep the seam crisp: `curate` = list hygiene (backlog); `tune` = draining + promotion (foreman).

- [ ] **Step 4: Relocate the done-record template.**
```bash
git mv skills/backlog/templates/task-record.md skills/foreman/templates/done-record.md
```
Then `grep -rn 'task-record\.md\|task-record' skills/` and update every reference (foreman's `done/` writers, MAINTENANCE.md, workstream ship) to `templates/done-record.md`. Confirm no `backlog/*` file still references it.

- [ ] **Step 5: Verify.**
```bash
grep -rn '/backlog backlog\|/backlog groom' skills/ README.md AGENTS.md packs/     # no output
grep -rnE '\.agents/dev/(BACKLOG|ISSUES|FEEDBACK|bugs|notes)' skills/ README.md AGENTS.md packs/  # no output (all -> .agents/backlog)
grep -rn 'task-record' skills/                                                     # no output (now done-record.md)
grep -rn 'backlog/templates/task-record\|templates/task-record.md' skills/         # no output
bash scripts/skills-lint.sh                                                         # fails=0 (foreman BOOTSTRAP manifest still valid; done-record.md exists where named)
```

- [ ] **Step 6: Commit.**
```bash
git add -A skills
git commit -m "ripple: repoint backlog verbs/paths across foreman/workstream/auditor; tune promotes notes; done-record template -> foreman" -- $(git diff --cached --name-only)
```

---

## Task 5: Front-door + final verification

**Files:** Modify `README.md`, `AGENTS.md` (only if they name backlog's verbs/paths), `docs/design/2026-07-17-backlog-refinement-plan.md` (mark complete).

- [ ] **Step 1: Front-door.** `grep -rn 'backlog' README.md AGENTS.md` — if the inventory/prose names the old `backlog`/`groom` verbs or `.agents/dev/` trackers for backlog, update to the seven verbs / `.agents/backlog/`. Keep it accurate; don't invent.

- [ ] **Step 2: Full green verification.**
```bash
bash scripts/skills-lint.sh                       # fails=0
grep -rn '/backlog backlog\|/backlog groom' skills/ README.md AGENTS.md packs/           # no output
grep -rnE '\.agents/dev/(BACKLOG|ISSUES|FEEDBACK|bugs|notes)' skills/ README.md AGENTS.md packs/  # no output
grep -rn 'task-record' skills/                    # no output
for v in bug task issue feedback note debrief curate; do test -f "skills/backlog/verbs/$v.md" || echo "MISSING verb: $v"; done   # no MISSING
test ! -f skills/backlog/verbs/backlog.md && test ! -f skills/backlog/verbs/groom.md && echo "old verbs gone"
./install.sh --list                               # 10 skills unchanged
```

- [ ] **Step 3: Commit.**
```bash
git add README.md AGENTS.md docs/design/2026-07-17-backlog-refinement-plan.md
git commit -m "docs: front-door for backlog refinement (task/curate/note, .agents/backlog)" -- README.md AGENTS.md docs/design/2026-07-17-backlog-refinement-plan.md
```

---

## Self-review — coverage

| Change | Task |
|---|---|
| verb `backlog`→`task` (+ `BACKLOG.md`→`TASKS.md`) | 1 |
| verb `groom`→`curate` (hygiene, no drain) | 1 |
| new `note` capture (project fact → `notes/`) | 1 |
| `issue` recategorized (project problem; bug/issue classifier) | 1 |
| `feedback` = single dev-experience channel | 1 |
| `SKILL.md` dispatch + prose (7 verbs, no drain) | 1 |
| home `.agents/dev/`→`.agents/backlog/` (backlog files) | 1 |
| `TAXONOMY.md` five-kind capture schema, no drains | 2 |
| `debrief` writes only backlog stores; no MEMORY/GOTCHAS/done | 3 |
| `foreman tune` gains note-promotion; keeps draining | 4 |
| ripple: verb + path refs across foreman/feature/workstream/auditor | 4 |
| `task-record.md` → `foreman/templates/done-record.md` | 4 |
| front-door + full green | 5 |

**Watch-items for the executor:**
- Task 1 is the largest (verbs + SKILL + home for backlog). The `note` verb (Step 5) and the `issue` recategorization (Step 6) carry the most judgment — diff the taxonomy prose against the Locked-decisions table.
- Tasks 1–3 leave `foreman`/`feature`/`workstream` still pointing at `.agents/dev/{trackers}` and the old verb names until Task 4 — that interim inconsistency is expected; a Task 1–3 reviewer should not flag out-of-`backlog` files.
- The `git commit -- $(git diff --cached --name-only)` idiom in Task 4 commits everything staged — stage deliberately (scoped `git add`).
