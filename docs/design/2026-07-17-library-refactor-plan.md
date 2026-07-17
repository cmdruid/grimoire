# Library Refactor — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute Phase 1 of the library refactor — rename `audit`→`auditor` and `design`→`architect`, split `dev`→`foreman`+`backlog`, relocate on-disk artifact homes under `.agents/`, and make `clankshop.md` a `foreman`-consumable runbook — leaving the library gate-green at each task.

**Architecture:** This is a prose/skills repo, not a code project. Each skill is a self-contained package (`skills/<name>/SKILL.md` + `verbs/`, `docs/`, `templates/`, `scripts/`). The gate is `scripts/skills-lint.sh` (facts, not verdicts: exits 1 on any `FAIL:`). "Tests" here = the lint gate + `install.sh --list` + reference-integrity greps + each bundled script's own testdata. We use a **copy-then-retire** strategy for the `dev` split so every intermediate state is a valid, lint-green skill set.

**Tech Stack:** bash, git, markdown. No build system, no CI. Verification is `bash scripts/skills-lint.sh`.

**Reference spec:** `docs/design/2026-07-17-library-refactor.md` (committed `1770b89`).

## Global Constraints

- **Gate, every task:** `bash scripts/skills-lint.sh` must print `fails=0` before each commit. `WARN:` lines are allowed but read them.
- **Frontmatter `description:`** ≤ 1024 chars (hard), ≤ 750 aim; **quote the whole value** if it contains `": "` (strict-YAML trap the linter FAILs on).
- **Commits:** scoped to the paths touched (`git add <paths> && git commit -- <paths>`); **no `Co-Authored-By` trailer** (user rule).
- **On-disk artifact homes** are `.agents/design/` and `.agents/dev/` (spec §3.1). Home-path relocation is **Task 6** — earlier tasks leave copied `design/`/`dev/` path strings as-is and do **not** pre-migrate them, to keep task boundaries clean.
- **Authored prose files** (new `SKILL.md`, `verbs/*.md`): the plan specifies required **sections + carried disciplines + model file + the exact description string**; the implementer authors the prose against that spec and the model file (these are docs, not code — reproducing full prose verbatim here is noise). Mechanical steps (git mv, sed, lint, grep) give exact commands.
- **Final skill set (10):** `architect · auditor · backlog · chiropractor · delegate · feature · foreman · handoff · mailbox · workstream`.

## Decisions resolved from spec §10 (locked for this plan)

- **Q1 — shared scripts:** split `dev-health.sh` by concern. `foreman/scripts/dev-health.sh` keeps `inventory`/`stale-refs`/`coverage`; `backlog/scripts/dev-health.sh` keeps `debrief-scan`. `scoped-commit.sh` is **duplicated** into both `foreman/scripts/` and `backlog/scripts/` (tiny; avoids a shared-dependency seam).
- **Q2 — `upkeep` split:** `upkeep.md` → `foreman/verbs/tune.md` (drain system-signal into doctrine). Its docs-spine-health checks fold into `foreman/verbs/check.md` (glue-drift), which explicitly defers general doc-spine ergonomics to `/chiropractor`.
- **Q3 — router default:** `/foreman` with no arg = `route`.
- **Q6 — taxonomy ownership:** `TAXONOMY.md` (the capture schema) moves to `backlog/docs/TAXONOMY.md`. `foreman/docs/DEVELOPMENT.md`'s *Capture follow-ups* section **references** `/backlog`'s taxonomy instead of restating the schema.

---

## Task 1: Rename `audit` → `auditor`

**Files:**
- Rename: `skills/audit/` → `skills/auditor/` (git mv)
- Modify: `skills/auditor/SKILL.md` (frontmatter `name:`), `skills/auditor/BOOTSTRAP.md`, `packs/clankshop.md` (`skills:` line + body), `README.md` (skill inventory), plus every file with a `` `/audit` `` slash-ref (see step 3)

**Interfaces:**
- Produces: skill dir `auditor`, invoked `/auditor` with verbs `deploy`/`metrics`/`check` unchanged.

- [ ] **Step 1: Baseline the gate.** Run `bash scripts/skills-lint.sh` → expect `fails=0`. Run `./install.sh --list` and note the current 9 skills. (If lint already FAILs, stop and fix that first — it must be green before refactoring.)

- [ ] **Step 2: Move the directory.** `git mv skills/audit skills/auditor`

- [ ] **Step 3: Find the reference surface.** Run `grep -rn '`/audit\b' skills/ README.md AGENTS.md packs/` and `grep -rn 'skills/audit\b' skills/ README.md` and `grep -rn '^name: audit$' skills/auditor/SKILL.md`. Record the hits — these are the edits for step 4.

- [ ] **Step 4: Update names + refs.** In `skills/auditor/SKILL.md` set `name: auditor`. Replace `` `/audit` `` → `` `/auditor` `` and `` `/audit ` `` → `` `/auditor ` `` in every file from step 3 (self-refs inside the skill, plus `delegate`, `feature`, and any others the grep surfaced). Update `skills/auditor/BOOTSTRAP.md` self-references. In `packs/clankshop.md`, change `audit` → `auditor` in the `skills:` frontmatter line and any body mention. In `README.md`, rename the inventory entry.

- [ ] **Step 5: Verify refs resolve (the "test").** Run `grep -rn '`/audit\b\|skills/audit\b' skills/ README.md AGENTS.md packs/` → **expect no output**. Run `grep -rn '^name:' skills/auditor/SKILL.md` → `name: auditor`.

- [ ] **Step 6: Run the gate.** `bash scripts/skills-lint.sh` → expect `fails=0` (a WARN about README/wiring is acceptable but should be resolved). `./install.sh --list` → shows `auditor`, no `audit`.

- [ ] **Step 7: Commit.**
```bash
git add -A skills/auditor README.md packs/clankshop.md
git status --short   # confirm skills/audit is gone (renamed), no stray paths
git commit -m "auditor: rename audit -> auditor (role-noun; four agent roles)" -- skills/auditor README.md packs/clankshop.md $(git diff --cached --name-only)
```
(If other skills were edited for `/audit` refs, include their paths in the `git add`/commit.)

---

## Task 2: Rename `design` → `architect`

**Files:**
- Rename: `skills/design/` → `skills/architect/` (git mv); `skills/architect/scripts/design-check.sh` → `architect-check.sh` (git mv)
- Modify: `skills/architect/SKILL.md` (`name:`), `skills/architect/verbs/check.md` (script path ref), `packs/clankshop.md`, `README.md`, plus every `` `/design` `` slash-ref (see step 2)

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: skill dir `architect`, invoked `/architect` with verbs `init`/`brainstorm`/`plan`/`distill`/`check`/`prep` unchanged; validator `scripts/architect-check.sh`.

- [ ] **Step 1: Move directory + script.**
```bash
git mv skills/design skills/architect
git mv skills/architect/scripts/design-check.sh skills/architect/scripts/architect-check.sh
```

- [ ] **Step 2: Find the reference surface.** `grep -rn '`/design\b' skills/ README.md AGENTS.md packs/`, `grep -rn 'design-check.sh' skills/architect`, `grep -rn '^name: design$' skills/architect/SKILL.md`. (Do **not** touch `/dev`/`/feature`/`/audit`→`/auditor` refs here — Task 1 handled auditor; `/dev` is Task 5.)

- [ ] **Step 3: Update names + refs.** Set `name: architect` in `skills/architect/SKILL.md`. Replace `` `/design` `` → `` `/architect` `` (and `` `/design <verb>` `` → `` `/architect <verb>` ``) across every file from step 2 — this includes architect's own `SKILL.md`, `verbs/*.md`, `docs/DOCTRINE.md`, `templates/{MAP,README}.md`, and peer skills (`feature`, `delegate`, `workstream`, `dev`'s files while they still exist). Update the `scripts/architect-check.sh` path ref in `verbs/check.md`. Update `packs/clankshop.md` (`skills:` line + body) and `README.md` inventory.

- [ ] **Step 4: Verify refs (the "test").** `grep -rn '`/design\b\|design-check.sh' skills/ README.md AGENTS.md packs/` → **no output**. `grep -rn '^name:' skills/architect/SKILL.md` → `name: architect`.

- [ ] **Step 5: Run the validator against its testdata.**
```bash
bash skills/architect/scripts/architect-check.sh skills/architect/scripts/testdata/good   # expect: clean / pass
bash skills/architect/scripts/architect-check.sh skills/architect/scripts/testdata/broken # expect: FAIL/WARN lines
```
Expected: `good/` passes, `broken/` reports issues (proves the renamed script still runs).

- [ ] **Step 6: Gate.** `bash scripts/skills-lint.sh` → `fails=0`. `./install.sh --list` → shows `architect`, no `design`.

- [ ] **Step 7: Commit.**
```bash
git add -A skills/architect README.md packs/clankshop.md $(git diff --name-only skills)
git commit -m "architect: rename design -> architect (role-noun, pairs with foreman)" -- $(git diff --cached --name-only)
```

---

## Task 3: Create `foreman` (copy from `dev`; `dev` stays intact)

**Files:**
- Create: `skills/foreman/SKILL.md`, `skills/foreman/verbs/{route,init,tune,check}.md`, `skills/foreman/docs/{DEVELOPMENT,PLANNING,WORKFLOWS,MAINTENANCE,WORKTREES}.md`, `skills/foreman/templates/{adr,plan-design,plan-implementation,roadmap,report}.md`, `skills/foreman/scripts/{dev-health.sh,scoped-commit.sh}`, `skills/foreman/BOOTSTRAP.md`
- Source (copied, not moved): `skills/dev/...`

**Interfaces:**
- Produces: skill `foreman`; `/foreman` (no-arg = `route`) with verbs `init`/`route`/`tune`/`check`. `foreman/scripts/dev-health.sh` exposes `inventory`/`stale-refs`/`coverage`. Owns `docs/DEVELOPMENT.md` (routing decision-walk), `docs/PLANNING.md`, `docs/WORKFLOWS.md`.

- [ ] **Step 1: Scaffold + copy foreman's share.**
```bash
mkdir -p skills/foreman/{verbs,docs,templates,scripts}
cp skills/dev/verbs/route.md skills/foreman/verbs/route.md
cp skills/dev/verbs/init.md  skills/foreman/verbs/init.md
cp skills/dev/verbs/upkeep.md skills/foreman/verbs/tune.md
cp skills/dev/docs/{DEVELOPMENT,PLANNING,WORKFLOWS,MAINTENANCE,WORKTREES}.md skills/foreman/docs/
cp skills/dev/templates/{adr,plan-design,plan-implementation,roadmap,report}.md skills/foreman/templates/
cp skills/dev/scripts/scoped-commit.sh skills/foreman/scripts/
cp skills/dev/scripts/dev-health.sh skills/foreman/scripts/
cp skills/dev/BOOTSTRAP.md skills/foreman/BOOTSTRAP.md
```
(TAXONOMY.md is **not** copied here — it goes to `backlog` in Task 4.)

- [ ] **Step 2: Trim `foreman/scripts/dev-health.sh` to foreman's facts.** Remove the `debrief-scan` subcommand/branch (that goes to backlog); keep `inventory`, `stale-refs`, `coverage`. Verify syntax: `bash -n skills/foreman/scripts/dev-health.sh` → no output.

- [ ] **Step 3: Rewrite the copied `tune.md`.** Retarget `upkeep`→`tune`: the verb is now "drain the system-relevant slice of `/backlog`'s signal into doctrine/workflow/AGENTS.md improvements" (spec §4.1). Keep the drift+drain mechanics; drop the tracker-drain-only framing (that's `/backlog groom` now). Replace internal `/dev upkeep` self-refs with `/foreman tune`; `/dev` capture refs → `/backlog …`.

- [ ] **Step 4: Author `foreman/verbs/check.md` (new).** Cheap validator: flag drift between the generated glue (`.agents/dev/docs` + AGENTS.md wiring) and the current runbook / installed skills. Fold in `upkeep`'s docs-spine-health checks, and **explicitly defer** general doc-spine ergonomics to `/chiropractor` (spec §7 seam). Model structure on an existing short verb file (e.g. `skills/architect/verbs/check.md`).

- [ ] **Step 5: Author `foreman/SKILL.md`.** Thin router. Required content, modeled on `skills/dev/SKILL.md`:
  - Frontmatter `name: foreman` + `description:` (quoted; ≤1024). Draft: identity = "stand up, run, and tune the project's development factory"; verbs `init`/`route`/`tune`/`check`; "the change-router + self-growing curation loop; not the capture bureau (that's `/backlog`)."
  - Verb-dispatch table for `init`/`route`/`tune`/`check` (no-arg → `route`).
  - The **shared-discipline block** carried verbatim-in-spirit from `dev/SKILL.md` (resolve root+date; scripts compute facts, prose decides; commit on trunk not a work branch; pathspec-atomic `scoped-commit.sh`). Keep the capture-commit policy **only** as it applies to foreman's own writes; capture-verb commit policy moves to `backlog`.
  - `docs/DEVELOPMENT.md`'s *Capture follow-ups* section: reference `/backlog`'s taxonomy rather than restating it (Decision Q6).

- [ ] **Step 6: Verify intra-skill refs resolve.** `bash scripts/skills-lint.sh` → `fails=0`. Confirm no `MISS` for foreman: every `` `verbs/…` ``/`` `docs/…` ``/`` `scripts/…` `` path named in `foreman/*.md` exists in `skills/foreman/`. (`dev/` is still intact and independently valid.)

- [ ] **Step 7: Confirm coexistence.** `./install.sh --list` → shows **both** `foreman` and `dev` (plus architect, auditor…). This is the intended interim state.

- [ ] **Step 8: Commit.**
```bash
git add skills/foreman
git commit -m "foreman: scaffold from dev (init/route/tune/check); dev retained for now" -- skills/foreman
```

---

## Task 4: Create `backlog` (copy from `dev`; `dev` stays intact)

**Files:**
- Create: `skills/backlog/SKILL.md`, `skills/backlog/verbs/{bug,backlog,issue,feedback,debrief,groom}.md`, `skills/backlog/docs/TAXONOMY.md`, `skills/backlog/templates/{bug-report,feedback,note,task-record}.md`, `skills/backlog/scripts/{dev-health.sh,scoped-commit.sh}`

**Interfaces:**
- Consumes: references `/foreman tune` (created Task 3) as the downstream drainer.
- Produces: skill `backlog`; verbs `bug`/`backlog`/`issue`/`feedback`/`debrief`/`groom`. Owns `docs/TAXONOMY.md` (capture schema). `backlog/scripts/dev-health.sh` exposes `debrief-scan`.

- [ ] **Step 1: Scaffold + copy backlog's share.**
```bash
mkdir -p skills/backlog/{verbs,docs,templates,scripts}
cp skills/dev/verbs/{bug,backlog,issue,feedback,debrief}.md skills/backlog/verbs/
cp skills/dev/docs/TAXONOMY.md skills/backlog/docs/TAXONOMY.md
cp skills/dev/templates/{bug-report,feedback,note,task-record}.md skills/backlog/templates/
cp skills/dev/scripts/scoped-commit.sh skills/backlog/scripts/
cp skills/dev/scripts/dev-health.sh skills/backlog/scripts/
```

- [ ] **Step 2: Trim `backlog/scripts/dev-health.sh` to `debrief-scan` only.** Remove `inventory`/`stale-refs`/`coverage` branches (those are foreman's). `bash -n skills/backlog/scripts/dev-health.sh` → no output.

- [ ] **Step 3: Extract `backlog/verbs/groom.md`.** Move the groom/triage sub-mode out of `backlog/verbs/backlog.md` into its own `groom.md` (dedupe/rank/triage the list); leave capture in `backlog.md`. Cross-link them.

- [ ] **Step 4: Rewrite copied verbs' cross-refs.** In all `backlog/verbs/*.md`, replace `/dev bug|backlog|issue|feedback|debrief` self-refs → `/backlog …`; `/dev upkeep` → `/foreman tune`; keep `/foreman`/`/workstream`/`/architect` peer refs. `debrief.md`: the shipped-record verification still points at the `/workstream` land step / `/foreman` (not the removed `/dev upkeep`).

- [ ] **Step 5: Author `backlog/SKILL.md`.** Thin router modeled on `dev/SKILL.md`:
  - `name: backlog` + quoted `description:` (single collection front-door; verbs `bug`/`backlog`/`issue`/`feedback`/`debrief`/`groom`; captures uniformly, `/foreman` sifts downstream).
  - Verb-dispatch table.
  - The **capture-commit policy** (standalone capture → own scoped commit + gate; inside a sweep → write-only, `debrief` makes the single commit) — this discipline moves here from `dev/SKILL.md`. Carry the trunk-branch guard + `scoped-commit.sh` rule.

- [ ] **Step 6: Gate + coexistence.** `bash scripts/skills-lint.sh` → `fails=0`. `./install.sh --list` → shows `backlog`, `foreman`, **and** `dev`.

- [ ] **Step 7: Commit.**
```bash
git add skills/backlog
git commit -m "backlog: scaffold capture inbox from dev (owns trackers + taxonomy + debrief)" -- skills/backlog
```

---

## Task 5: Retire `dev` (the flip)

**Files:**
- Delete: `skills/dev/`
- Modify: `scripts/skills-lint.sh` (check #3 `dev`→`foreman`), `packs/clankshop.md`, `README.md`, plus every remaining `` `/dev` `` slash-ref across `skills/` + `AGENTS.md`

**Interfaces:**
- Consumes: `foreman` (Task 3) + `backlog` (Task 4) must exist and be green.

- [ ] **Step 1: Find remaining `/dev` refs.** `grep -rn '`/dev\b' skills/ README.md AGENTS.md packs/ | grep -v 'skills/dev/'` — the surface in *other* skills (workstream, feature, architect, delegate, handoff) + pack + AGENTS.

- [ ] **Step 2: Repoint them.** Route each per the split: `/dev` (router) → `/foreman`; `/dev route` → `/foreman route`; `/dev init` → `/foreman init`; `/dev upkeep` → `/foreman tune`; `/dev bug|backlog|issue|feedback|debrief` → `/backlog …`. (Use the spec's §4.1/§4.2 verb ownership as the map.)

- [ ] **Step 3: Update the linter's baked-in `dev` knowledge.** In `scripts/skills-lint.sh` check #3, change `bs="$skills_dir/dev/BOOTSTRAP.md"` → `foreman/BOOTSTRAP.md` and the `dev/docs/$doc` existence check → `foreman/docs/$doc`. In check #6, remove the now-dead `dev debrief|dev bug|…` entries from `known_generic` (foreman/backlog are real dirs now, so `/foreman …` and `/backlog …` pass via the dir check). `bash -n scripts/skills-lint.sh` → clean.

- [ ] **Step 4: Update pack + README.** In `packs/clankshop.md` `skills:` line, replace `dev` with `foreman backlog`. In `README.md`, replace the `dev` inventory entry with `foreman` + `backlog`.

- [ ] **Step 5: Delete `dev`.** `git rm -r skills/dev`

- [ ] **Step 6: Verify (the "test").**
```bash
grep -rn '`/dev\b' skills/ README.md AGENTS.md packs/   # expect: no output
./install.sh --list                                      # expect: no dev; foreman + backlog present
bash scripts/skills-lint.sh                              # expect: fails=0, and no `/dev` XREF warns
```

- [ ] **Step 7: Commit.**
```bash
git add -A skills scripts/skills-lint.sh README.md packs/clankshop.md AGENTS.md
git commit -m "dev: retire -> foreman + backlog; repoint refs; move lint gate to foreman" -- $(git diff --cached --name-only)
```

---

## Task 6: Relocate on-disk homes under `.agents/`

**Files:** every skill referencing the on-disk homes — `architect`, `foreman`, `backlog`, `feature`, `workstream` (SKILL + `flow.md` + `verbs/*` + `templates/*`), `handoff`, `chiropractor` (`SKILL.md` + `scripts/spine-scan.sh`), and `auditor/BOOTSTRAP.md`.

**Interfaces:**
- Produces: all skills read/write `.agents/design/` and `.agents/dev/`; `foreman`'s glue records the chosen root (pointer, per spec §3.1) so nothing hardcodes it downstream.

- [ ] **Step 1: Enumerate home-path refs.** `grep -rnE '(^|[^./A-Za-z])(design|dev)/(docs|BACKLOG|ISSUES|FEEDBACK|bugs|notes|done|MEMORY|PHILOSOPHY|VISION|MAP|GLOSSARY|README)' skills/` → the edit list.

- [ ] **Step 2: Rewrite the homes.** Replace project-artifact `design/…` → `.agents/design/…` and `dev/…` → `.agents/dev/…` across those files. **Do not** touch: bundle-resource paths (`scripts/…`, `verbs/…`, `templates/…`, `docs/…` inside a skill), `skills/…` package paths, or the word "design"/"dev" as prose. Only the *project home* prefixes change.

- [ ] **Step 3: Add the recorded-root note to `foreman`.** In `foreman/verbs/init.md`, state that `init` scaffolds `.agents/dev/` (and that `architect` uses `.agents/design/`), records the root in the glue, and that agents read the recorded location — not a hardcoded path.

- [ ] **Step 4: Update script defaults + testdata if any.** If `spine-scan.sh` / `dev-health.sh` default to `dev/` or `design/`, update to `.agents/…`. Re-run `bash skills/architect/scripts/architect-check.sh skills/architect/scripts/testdata/good` → still passes (testdata dirs are self-contained, unaffected).

- [ ] **Step 5: Verify.** `grep -rnE '(^|[^./A-Za-z-])(design|dev)/(docs|BACKLOG|ISSUES|FEEDBACK|bugs|notes|done|MEMORY)' skills/` → **no output** (no bare project homes remain). `bash scripts/skills-lint.sh` → `fails=0`.

- [ ] **Step 6: Commit.**
```bash
git add -A skills
git commit -m "storage: relocate on-disk homes under .agents/{design,dev} (spec §3.1)" -- $(git diff --cached --name-only)
```

---

## Task 7: Make `clankshop.md` a `foreman`-consumable runbook

**Files:**
- Modify: `packs/clankshop.md` (body → actionable runbook), `skills/foreman/verbs/init.md` (consume runbook + baseline), `skills/foreman/BOOTSTRAP.md` (align with runbook-consumption)

**Interfaces:**
- Consumes: `foreman init`, `.agents/` homes (Task 6).
- Produces: `foreman init` that reads the pack runbook (or falls back to a baseline introspection of installed skills) to instantiate the glue.

- [ ] **Step 1: Promote the pack body.** In `packs/clankshop.md`, keep the frontmatter `skills:` manifest **unchanged** (install.sh parses it — do not break it). Rewrite the prose body from descriptive to actionable: "to stand up this constellation, run `/foreman init`, which consumes this composition — members + the cross-skill seam contracts + the glue-workflows." Include the seam catalog (spec §7) as the composition foreman instantiates.

- [ ] **Step 2: Rework `foreman/verbs/init.md`.** `init` now: (a) if a pack runbook is present, consume it as the composition; (b) else **baseline** — introspect installed skills, wire the recognized ones, name by-hand fallbacks for the rest; (c) instantiate `.agents/dev/docs` + AGENTS.md wiring; (d) **stamp** the runbook/skill versions built against (snapshot doctrine). Reference `foreman check` as the drift validator.

- [ ] **Step 3: Align `foreman/BOOTSTRAP.md`.** Point it at the runbook-consumption model rather than the old standalone `dev` bootstrap. Ensure any `docs/`/`templates/` manifest lines it carries name files that exist in `skills/foreman/` (linter check #3 now validates this against `foreman/`).

- [ ] **Step 4: Verify install.sh still parses the pack.**
```bash
./install.sh --pack clankshop --target /tmp/grimoire-check --list 2>/dev/null || \
  ./install.sh --pack clankshop --target /tmp/grimoire-check   # dry target
ls -l /tmp/grimoire-check                                       # symlinks for the 10 members
./install.sh --remove --target /tmp/grimoire-check architect auditor backlog chiropractor delegate feature foreman handoff mailbox workstream
rm -rf /tmp/grimoire-check
```
Expected: the pack manifest still yields the 10 members (frontmatter untouched).

- [ ] **Step 5: Gate.** `bash scripts/skills-lint.sh` → `fails=0` (check #3 now validates `foreman/BOOTSTRAP.md` against the `foreman/` bundle).

- [ ] **Step 6: Commit.**
```bash
git add packs/clankshop.md skills/foreman/verbs/init.md skills/foreman/BOOTSTRAP.md
git commit -m "runbook: clankshop.md drives /foreman init (mechanism vs composition)" -- packs/clankshop.md skills/foreman
```

---

## Task 8: Front-door + final integration

**Files:**
- Modify: `README.md` (inventory, layers, `.agents/` note), `AGENTS.md` (four roles + seams), `docs/design/2026-07-17-library-refactor.md` (Status)

**Interfaces:**
- Consumes: all prior tasks complete and green.

- [ ] **Step 1: README.** Update the skill inventory to the final 10, reflect the four-role framing (Architect · Foreman · Chiropractor · Auditor), the `dev`→`foreman`+`backlog` split, and the `.agents/` storage convention. Ensure every skill is `` `mentioned` `` (linter check #4 WARN).

- [ ] **Step 2: AGENTS.md.** Update any references to the old skill set; state the four agent roles and the layer-steward / operator / auditor / plumbing grouping (spec §3). Keep the design-philosophy doctrine intact.

- [ ] **Step 3: Mark the spec implemented.** In `docs/design/2026-07-17-library-refactor.md`, change `**Status:** Design agreed; Phase 1 not yet implemented.` → `**Status:** Phase 1 implemented (<date from `date +%Y-%m-%d`>). Phase 2 deferred.`

- [ ] **Step 4: Full green verification (the "test").**
```bash
bash scripts/skills-lint.sh          # fails=0
./install.sh --list                  # exactly the 10 skills, no audit/design/dev
grep -rn '`/\(dev\|design\|audit\)\b' skills/ README.md AGENTS.md packs/   # no output
for s in architect foreman backlog auditor chiropractor delegate feature handoff mailbox workstream; do
  test -f "skills/$s/SKILL.md" && grep -q "^name: $s$" "skills/$s/SKILL.md" || echo "BAD: $s"
done   # no BAD lines
```

- [ ] **Step 5: Commit.**
```bash
git add README.md AGENTS.md docs/design/2026-07-17-library-refactor.md
git commit -m "docs: front-door for the refactored library (four roles, .agents/, foreman+backlog)" -- README.md AGENTS.md docs/design/2026-07-17-library-refactor.md
```

---

## Self-review — spec coverage

| Spec item | Task |
|---|---|
| §4.1 `foreman` (init/route/tune/check) | 3, 7 |
| §4.2 `backlog` (capture + debrief + groom) | 4 |
| §4.3 `architect` (rename; verbs unchanged) | 2 |
| §3 `audit`→`auditor` (four roles) | 1 |
| §3.1 `.agents/` storage root | 6 |
| §6 runbook mechanism (mechanism vs composition) | 7 |
| §5 layer-steward `check` seam (foreman ↔ chiropractor) | 3 (step 4) |
| §7 seam catalog (backlog↔foreman, taxonomy ownership) | 3, 4 |
| §10 Q1/Q2/Q3/Q6 resolutions | Decisions block; 3, 4 |
| Linter's baked-in `dev` knowledge | 5 (step 3) |
| Front-door (README/AGENTS) | 8 |

**Deferred (Phase 2, not in this plan):** architect code→design extraction + drift-check; ralph-loop expansion; `.sessions`/`.workstreams` migration under `.agents/`; stewards' shared-doctrine consolidation.

**Gaps / watch-items for the executor:**
- Task 3 Step 5 and Task 4 Step 5 author the two routers — the riskiest prose. Diff them against `dev/SKILL.md` to confirm the shared-discipline block split correctly (foreman keeps commit-on-trunk + scoped-commit; backlog keeps the capture-commit policy).
- The `git commit -- $(git diff --cached --name-only)` idiom in Tasks 1/2/5 commits everything staged; stage deliberately (scoped `git add`) so unrelated files don't ride along.
