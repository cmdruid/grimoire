# Clankshop Audit Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute `docs/design/2026-08-10-clankshop-audit-reconciliation.md` — retire the rebuild
concept from the clankshop pack, repair the role-merge's mechanical damage, unify the unstamped
posture, and restore the dropped shared disciplines.

**Architecture:** Doctrine-first cascade over one skill bundle (`skills/clankshop/`): a provably
safe mechanical batch, then the doctrine rewrite the verbs cite, then the design-verb rewrites,
then posture/disciplines, then the editorial sweep + version bump. Every task is prose/script
edits verified by the repo's own gates (shell suite, lint, targeted greps).

**Tech Stack:** Markdown skill files; bash test suite (`skills/clankshop/scripts/tests/run.sh`);
`skills/skill-builder/scripts/skills-lint.sh`; cargo workspace (one pinned-version test).

## Global Constraints

- **The owner works concurrently in this tree.** Immediately before EVERY commit: re-run
  `git status --porcelain && git log --oneline -3`; if HEAD moved since the task started, re-read
  any file you edited that also changed upstream before committing.
- **Pathspec-scoped commits only** — `git add <exact paths>` and `git commit -- <exact paths>`;
  never `git add -A`, never `commit -a`. No AI-attribution trailers (no `Co-Authored-By`).
- **Baselines that must hold after every task:** `bash skills/clankshop/scripts/tests/run.sh` →
  174 asserts + spine-scan PASS, ALL GREEN; `bash skills/skill-builder/scripts/skills-lint.sh .`
  (run from repo root) → `fails=0 warns=8`.
- **Patient-zero rule:** never run any clankshop verb against this repository's own `AGENTS.md`
  or front door; fixtures live in temp dirs only. This plan only edits files — no verb runs.
- **The design doc is the contract:** `docs/design/2026-08-10-clankshop-audit-reconciliation.md`.
  When a wording call is ambiguous, its Decisions section governs (rebuild concept fully out;
  sufficiency = fresh-agent read-test; judgment anywhere, writes need a stamped home; `seed` is
  an explicit subverb; `health` is canonical where old-architect `check` was meant).
- All paths below are repo-root-relative. Line numbers are as of `5fc6864` — verify each quoted
  `old` string before editing; if a quote doesn't match, STOP and re-read the file (the owner may
  have touched it) rather than guessing.

---

### Task 1: Mechanical batch (dead tokens with one correct fix)

**Files:**
- Modify: `skills/clankshop/verbs/docs.md`
- Modify: `skills/clankshop/verbs/design/extract.md`
- Modify: `skills/clankshop/verbs/design/reconcile.md`
- Modify: `skills/clankshop/docs/DESIGN-DOCTRINE.md`
- Modify: `skills/clankshop/verbs/design/distill.md`
- Modify: `skills/clankshop/verbs/calibrate/intake.md`
- Modify: `skills/clankshop/verbs/calibrate/doctrine.md`
- Modify: `skills/clankshop/doctrine/README.md`

**Interfaces:**
- Consumes: nothing from other tasks (safe to run first).
- Produces: a bundle free of `DOC-docs/`, prose `init`-as-verb, and prose "calibrator" tokens —
  later tasks assume these are gone.

- [ ] **Step 1: Verify the broken state (the failing "test")**

Run:
```bash
grep -rn "DOC-docs" skills/clankshop/
grep -rn '`init`' skills/clankshop/verbs/ skills/clankshop/docs/
grep -rn "calibrator" skills/clankshop/verbs/ skills/clankshop/doctrine/README.md
```
Expected: hits at exactly the lines listed in Step 2 (2 + 1 + 6 + 5 lines respectively).

- [ ] **Step 2: Apply the token fixes (exact old → new, per file)**

`skills/clankshop/verbs/docs.md`:
- line 193: `docs/DOC-docs/DOC-RUBRIC.md` → `docs/DOC-RUBRIC.md`
- line 317: `docs/DOC-docs/DOC-RUBRIC.md` → `docs/DOC-RUBRIC.md`
- line 155: `(see RUBRIC Currency)` → `(see DOC-RUBRIC Currency)`

`skills/clankshop/verbs/design/extract.md`:
- line 26: `` (`init`/`distill`/human editorial) `` → `` (`seed`/`distill`/human editorial) ``
- line 43: `` no `.handbook/design/` seed, and nothing for\n`init` migrate-mode to fold `` — replace the `` `init` `` token with `` `seed` ``
- line 53: `` `init` migrate-mode's job, not `extract`'s `` → `` `seed` migrate-mode's job, not `extract`'s ``
- line 128: `` the source material `init` reshapes into `.handbook/design/` `` → `` the source material `seed` reshapes into `.handbook/design/` ``

`skills/clankshop/verbs/design/reconcile.md`:
- line 159: `` mutated only by the curated path (`init`/`distill`/human editorial). `` → `` mutated only by the curated path (`seed`/`distill`/human editorial). ``

`skills/clankshop/docs/DESIGN-DOCTRINE.md`:
- line 216: `` | Mutated by | `init`, `distill`, human editorial **only** | `` → `` | Mutated by | `seed`, `distill`, human editorial **only** | ``
- line 223: `` `init` (compile/migrate), `distill` (collapse change-records), `` → `` `seed` (compile/migrate), `distill` (collapse change-records), ``

`skills/clankshop/verbs/design/distill.md`:
- line 10: `` external signal arrives as calibrator-routed improvement items, applied here as ordinary seed work. `` → `` external signal arrives as improvement items routed by `calibrate`, applied here as ordinary seed work. ``

`skills/clankshop/verbs/calibrate/intake.md`:
- line 5: `` the calibrator is the\nonly scanner of these sources `` — replace `the calibrator is the` with `this hat is the` (keep the line wrap sensible).

`skills/clankshop/verbs/calibrate/doctrine.md`:
- line 10: `` The calibrator judges and routes; it **never edits a `` → `` This verb judges and routes; it **never edits a ``
- line 26: `` The calibrator verifies uptake (chapter updated, stamp `` → `` The chiropractor verifies uptake (chapter updated, stamp ``

`skills/clankshop/doctrine/README.md`:
- line 134: `` reconciling it is the improvement loop's judgment call (the\ncalibrator's doctrine seam) `` — replace `(the calibrator's doctrine seam)` with `` (the doctrine seam — `/clankshop calibrate doctrine`) ``

NOTE: `brainstorm.md:71`'s `init` is NOT in this batch (its section pointer needs a judged fix —
Task 3). `scripts/tests/calibrator-test.sh` is NOT in this batch (renamed in Task 5).

- [ ] **Step 3: Verify the fixed state**

Run:
```bash
grep -rn "DOC-docs" skills/clankshop/                             # expect: empty
grep -rn '`init`' skills/clankshop/verbs/ skills/clankshop/docs/  # expect: only verbs/design/brainstorm.md:71
grep -rn "calibrator" skills/clankshop/verbs/ skills/clankshop/doctrine/README.md  # expect: empty
```

- [ ] **Step 4: Run the gates**

Run: `bash skills/clankshop/scripts/tests/run.sh && bash skills/skill-builder/scripts/skills-lint.sh .`
Expected: ALL GREEN (174 + spine-scan PASS); `fails=0 warns=8`.

- [ ] **Step 5: Commit (re-ground on HEAD first — see Global Constraints)**

```bash
git add skills/clankshop/verbs/docs.md skills/clankshop/verbs/design/extract.md \
  skills/clankshop/verbs/design/reconcile.md skills/clankshop/docs/DESIGN-DOCTRINE.md \
  skills/clankshop/verbs/design/distill.md skills/clankshop/verbs/calibrate/intake.md \
  skills/clankshop/verbs/calibrate/doctrine.md skills/clankshop/doctrine/README.md
git commit -m "clankshop(reconcile): mechanical batch -- DOC-docs double-sed paths, init-as-verb tokens (two renames stale), calibrator persona tokens; provably-safe fixes from the merge audit, batch-approved" \
  -- skills/clankshop/verbs/docs.md skills/clankshop/verbs/design/extract.md \
  skills/clankshop/verbs/design/reconcile.md skills/clankshop/docs/DESIGN-DOCTRINE.md \
  skills/clankshop/verbs/design/distill.md skills/clankshop/verbs/calibrate/intake.md \
  skills/clankshop/verbs/calibrate/doctrine.md skills/clankshop/doctrine/README.md
```

---

### Task 2: Doctrine reframe (DESIGN-DOCTRINE rewrite, script rename, rubric retitle)

**Files:**
- Rename: `skills/clankshop/scripts/architect-check.sh` → `skills/clankshop/scripts/design-check.sh`
- Modify: `skills/clankshop/docs/DESIGN-DOCTRINE.md`
- Modify: `skills/clankshop/docs/DOC-RUBRIC.md` (lines 1–3 only)

**Interfaces:**
- Consumes: Task 1's `init`→`seed` fixes in DESIGN-DOCTRINE (lines 216/223 already read `seed`).
- Produces: `scripts/design-check.sh` (same behavior, new name) — Task 3's command fixes point at
  it; a DESIGN-DOCTRINE with no rebuild/prep/keystone content and `health` as the cheap-check
  name — Task 3's verb rewrites cite its § headings (`§ The seam`, `§ Sufficiency, and its
  circularity`, `§ Cheap health, deep reconcile`, `§ Extraction`, `§ Deliverables in .records/`).

- [ ] **Step 1: Rename the script**

```bash
git mv skills/clankshop/scripts/architect-check.sh skills/clankshop/scripts/design-check.sh
grep -n "architect" skills/clankshop/scripts/design-check.sh
```
Update every self-naming hit the grep shows (header comment, usage line) from
`architect-check.sh` to `design-check.sh`; leave anything that isn't the script's own name.

- [ ] **Step 2: DESIGN-DOCTRINE — preamble + temporal table (rebuild framing out)**

In `skills/clankshop/docs/DESIGN-DOCTRINE.md`:

Replace lines 3–5:
```markdown
This is the portable methodology every verb links to. It encodes the founding
design spec as durable doctrine;
project-specific content (a project's actual `.handbook/design/` folder) never lives here.
```
with:
```markdown
This is the portable methodology the `design` verbs link to. It states the seed method as
durable doctrine; project-specific content (a project's actual `.handbook/design/` folder) never
lives here.
```

In the "Two temporal kinds of doc" table (line 15), replace the "Good for" row:
```markdown
| Good for | building *forward*, incrementally | *regenerating* from a clean seed |
```
with:
```markdown
| Good for | building *forward*, incrementally | knowing how it *is* — whole, scar-free |
```

- [ ] **Step 3: DESIGN-DOCTRINE — durability gradient (compile metaphor out, art re-wrapped)**

Replace the annotation column of the code fence (lines 34–40) so the right-hand callout fits.
The fence becomes:
```
MOST DURABLE   .handbook/design/VISION.md        — what the product IS (north star)
   ▲           .handbook/design/PHILOSOPHY.md    — core ideals ("seeds are sacred")
   │           .handbook/design/GLOSSARY.md      — shared vocabulary
   │           .handbook/design/MAP.md           — system index + seam graph
   │           (the four above: the required spine, presence-checked by `design health`)
   │           .handbook/design/src/<system>.md  · CONTRACT tier — binding invariants, behavior, seams
   ▼                                             · REFERENCE-ARCH — current shape, DISPOSABLE (a snapshot)
LEAST DURABLE
```

Replace the first two bullets under the fence (lines 43–50):
```markdown
- **Spine at `.handbook/design/` root** is the "constitution" that *governs* the compile (like a repo's
  README/LICENSE/config). It is not itself compiled to code, and it is **required, not
  optional** — `/clankshop design health` fails if `VISION`, `PHILOSOPHY`, `GLOSSARY`, or `MAP` is missing.
  The spine is what makes radical change *safe*: you can rewrite everything about one system
  without renegotiating a durable tenet like "seeds are sacred."
- **`.handbook/design/src/`** holds the compilable source specs, roughly 1:1 with code units. The compile
  metaphor is exact: `.handbook/design/src/<system>.md` is to `src/<code>` as a source file is to its build
  artifact — the spec is the durable input, the code is the disposable output regenerated from it.
```
with:
```markdown
- **Spine at `.handbook/design/` root** is the "constitution" that governs everything below it
  (like a repo's README/LICENSE/config), and it is **required, not optional** —
  `/clankshop design health` fails if `VISION`, `PHILOSOPHY`, `GLOSSARY`, or `MAP` is missing.
  The spine is what makes radical change *safe*: you can rewrite everything about one system
  without renegotiating a durable tenet like "seeds are sacred."
- **`.handbook/design/src/`** holds the per-system specs, roughly 1:1 with code units:
  `.handbook/design/src/<system>.md` is the standing statement of what `src/<code>` must be —
  the spec is the durable truth the code is held to.
```

- [ ] **Step 4: DESIGN-DOCTRINE — two-tier spec ("a rebuild" → "an implementer")**

In the "The two-tier system spec" section (lines 55–75), apply these replacements:
- `This is law: a rebuild reads the contract — including its\n  seams — as a binding requirement.` → `This is law: an implementer reads the contract — including its\n  seams — as a binding requirement.`
- `smuggle old design into a\n  rebuild. Nothing a rebuild is *required* to honor lives in the disposable tier.` → `smuggle old design into new\n  work. Nothing an implementation is *required* to honor lives in the disposable tier.`
- `explicitly\n  stamped "current best guess; a rebuild MAY discard this."` → `explicitly\n  stamped "current best guess — not binding."`
- `so `distill` can work incrementally and `check` can compute distill-debt from clean,` → `so `distill` can work incrementally and `health` can compute distill-debt from clean,`
- `A contracts-only seed (no reference architecture) was considered and rejected: it under-specifies,\nand agents re-litigate settled architecture on every rebuild. The two-tier seed gives a rebuild an\norienting snapshot (the reference-arch, a starting hint) while keeping every binding constraint —\nseams included — in the contract tier, where a rebuild cannot accidentally skip it.` → `A contracts-only seed (no reference architecture) was considered and rejected: it under-specifies,\nand agents re-litigate settled architecture on every change. The two-tier seed gives new work an\norienting snapshot (the reference-arch, a starting hint) while keeping every binding constraint —\nseams included — in the contract tier, where an implementer cannot accidentally skip it.`

- [ ] **Step 5: DESIGN-DOCTRINE — delete § The keystone wholly**

Delete lines 77–99 inclusive (`## The keystone: deletion is the context-hygiene mechanism`
through the `(Forward reference: … Plan B, hands to `/feature`.)` paragraph, including the blank
line separating it from `## The seam`).

- [ ] **Step 6: DESIGN-DOCTRINE — § The seam ("the skill" → the verb family; regenerate out)**

In `## The seam — altitude, not medium`:
- `not the reason the skill exists. Don't define `/clankshop design` by what it refuses to touch —` → `not the reason the verb family exists. Don't define `/clankshop design` by what it refuses to touch —`
- `mutate **the seed itself** (the foundation you later regenerate code\n> from).` → `mutate **the seed itself** (the foundation code is built against).`

- [ ] **Step 7: DESIGN-DOCTRINE — § Sufficiency rewritten (read-test framing)**

Replace the entire `## Sufficiency, and its circularity` section (lines 126–146) with:
```markdown
## Sufficiency, and its circularity

"Does this spec say enough?" has no cheap proof. The structural checks (`health`) can prove a
contract present and its pointers live — they cannot prove the contract *says enough to act on*.
The semantic gate is the **fresh-agent read-test**: hand an agent *only* the spec — no ADR
access, no chat history, no author-remembers context — and confirm it can act on it correctly,
without guessing. Run it occasionally, the way you run `reconcile`; it is the expensive proof
the cheap checks cannot substitute for.

There is a trap to respect: a spec traced off working code *looks* sufficient because the code
answered every question — but **observation is not decided intent**. A draft recovered from code
(§ Extraction) proves reverse-engineering skill, never that the standing spec says enough on its
own. Only a human deciding what the design *should* guarantee breaks that circle; every place a
code-traced draft would have to guess is a sufficiency gap to resolve, never a blank to fill
from the implementation.
```

- [ ] **Step 8: DESIGN-DOCTRINE — § Cheap health, deep reconcile**

In the section currently headed `## Cheap `check`, deep `reconcile`` (lines 148–167):
- Heading → `## Cheap `health`, deep `reconcile``
- Table column header `| | **`check`** | **`reconcile`** |` → `| | **`health`** | **`reconcile`** |`
- `| How | a read-only fact script (`architect-check.sh`) |` → `| How | a read-only fact script (`design-check.sh`) |`
- ``check` is necessary but not sufficient` → ``health` is necessary but not sufficient`
- `aimed by `check`'s cheap facts` → `aimed by `health`'s cheap facts`
- Re-wrap any line the edits leave over ~98 chars.

- [ ] **Step 9: DESIGN-DOCTRINE — § Extraction + § Deliverables (rebuild vocabulary out)**

In `## Extraction — the brownfield onramp`:
- `a seed reverse-engineered\nfrom code and then used to regenerate that code proves only reverse-engineering skill — never that\nthe *standing seed was sufficient on its own*.` → `a spec reverse-engineered\nfrom code proves only reverse-engineering skill — never that the *standing seed says enough on\nits own*.`
- `and everything a rebuild would have to\n  guess.` → `and everything an agent acting on the spec would have to\n  guess.`

In `## Deliverables in .records/, seed in .handbook/design/`:
- `This is\nthe same source-vs-record split `auditor` and `foreman` run — the rubric/seed is durable and curated;` → `This is\nthe same source-vs-record split `/auditor` and the foreman hat run — the rubric/seed is durable and curated;`

Then re-wrap the merge's overrun lines throughout the file (target ~98 cols): check lines that
grep as over-long via `awk 'length > 98 {print FILENAME":"FNR}' skills/clankshop/docs/DESIGN-DOCTRINE.md`
and re-wrap those inside sections this task already touched (leave untouched sections alone).

- [ ] **Step 10: DOC-RUBRIC retitle (lines 1–3 only)**

In `skills/clankshop/docs/DOC-RUBRIC.md`:
- line 1: `# Chiropractor Rubric -- 12-Dimension Reference` → `# The doc rubric -- the 12-dimension spine reference`
- line 3: replace the sentence `This document is the scoring reference for the `chiropractor` diagnosis.` with `This document is the scoring reference for the `/clankshop docs` diagnosis.`
Body stays byte-identical (its `--` dash convention included — deliberately out of scope).

- [ ] **Step 11: Verify**

```bash
grep -inE "rebuild|regenerat|prep\b|clear run|build run|keystone" skills/clankshop/docs/DESIGN-DOCTRINE.md   # expect: empty
grep -rn "architect-check" skills/clankshop/ --include='*.sh' --include='*.md'                                # expect: only verbs/design/seed.md (fixed in Task 3)
bash skills/clankshop/scripts/tests/run.sh && bash skills/skill-builder/scripts/skills-lint.sh .
```
Expected: greps as annotated; suite ALL GREEN; lint `fails=0 warns=8`.

- [ ] **Step 12: Commit (re-ground on HEAD first)**

```bash
git add skills/clankshop/scripts/design-check.sh skills/clankshop/docs/DESIGN-DOCTRINE.md skills/clankshop/docs/DOC-RUBRIC.md
git commit -m "clankshop(reconcile): doctrine reframe -- rebuild concept retired (keystone section removed; sufficiency reframed to the fresh-agent read-test; observation is not decided intent), health canonical for the cheap check, architect-check.sh renamed design-check.sh, DOC-RUBRIC retitled to the face's framing" \
  -- skills/clankshop/scripts/architect-check.sh skills/clankshop/scripts/design-check.sh \
  skills/clankshop/docs/DESIGN-DOCTRINE.md skills/clankshop/docs/DOC-RUBRIC.md
```

---

### Task 3: Design verbs (seed/plan/reconcile rewrites; extract/brainstorm/distill/health touch-ups; hat; templates; router row)

**Files:**
- Modify: `skills/clankshop/SKILL.md` (router row only)
- Modify: `skills/clankshop/roles/architect.md`
- Modify: `skills/clankshop/verbs/design/seed.md`
- Modify: `skills/clankshop/verbs/design/plan.md`
- Modify: `skills/clankshop/verbs/design/reconcile.md`
- Modify: `skills/clankshop/verbs/design/extract.md`
- Modify: `skills/clankshop/verbs/design/brainstorm.md`
- Modify: `skills/clankshop/verbs/design/distill.md`
- Modify: `skills/clankshop/verbs/design/health.md`
- Modify: `skills/clankshop/templates/design/MAP.md`
- Modify: `skills/clankshop/templates/design/system-spec.md`
- Modify: `skills/clankshop/templates/design/README.md`

**Interfaces:**
- Consumes: `scripts/design-check.sh` (Task 2's rename); DESIGN-DOCTRINE's post-reframe headings
  (`§ Sufficiency, and its circularity` and `§ Cheap health, deep reconcile` exist; `§ The
  keystone` does not).
- Produces: the router row later tasks and probes read: subverbs
  `seed · brainstorm · plan · extract · distill · reconcile · health`, no `prep`, bare `design`
  = `seed`'s alias.

- [ ] **Step 1: Router row (SKILL.md line 37)**

Replace the `design` row of the verb table:
```markdown
| `design [<verb>]` | architect | seed-altitude design. Bare = seed work (bootstrap/migrate the design chapter, `verbs/design/seed.md`); subverbs `brainstorm` · `plan` · `extract` · `distill` · `reconcile` · `health` (`verbs/design/`); `prep` pending (method: `docs/DESIGN-DOCTRINE.md`) |
```
with:
```markdown
| `design [<verb>]` | architect | seed-altitude design. Subverbs `seed` (bare `design` is its alias; bootstrap/migrate the design chapter) · `brainstorm` · `plan` · `extract` · `distill` · `reconcile` · `health` (seed completeness/drift facts) (`verbs/design/`; method: `docs/DESIGN-DOCTRINE.md`) |
```

- [ ] **Step 2: Architect hat (identity reframe; prep out)**

In `skills/clankshop/roles/architect.md`:
- Replace lines 3–5:
```markdown
You are the **design authority** for this project: the steward of its `.handbook/design/`
**seed** — the clean, present-tense, regenerable source of truth that code is the disposable
build output of — and of the design records (`.records/design/`).
```
with:
```markdown
You are the **design authority** for this project: the steward of its `.handbook/design/`
**seed** — the clean, present-tense source of truth the project builds against — and of the
design records (`.records/design/`).
```
- Line 13: `` (reconnaissance for\n  `health`, `reconcile`, `prep`); you never edit it. `` → `` (reconnaissance for\n  `health`, `reconcile`, `extract`); you never edit it. ``

- [ ] **Step 3: seed.md — self-name sweep, posture note, Step 7 deletion, command fix**

In `skills/clankshop/verbs/design/seed.md`:

3a. **Self-name sweep.** Everywhere the prose uses `` `setup` `` to name THIS verb, replace with
`` `seed` `` ("the setup report" → "the seed report"). Affected lines (verify each):
12, 15, 32, 85, 99, 115, 132–136, 140–145, 147 region ("`setup` exists to close",
"`setup` performs it directly"), 158, 169–176 ("`setup` edits it directly", "`setup` does
**not** edit it"), 188–202 ("`setup` is not done until", "that's `setup` unfinished, not `setup`
done", "`setup`'s final report"), 246 ("Close `setup` with"). Do NOT touch `git init`-style
uses (none exist in this file) or references to the face's `/clankshop setup` (none remain once
Step 7 is deleted).

3b. **Posture note.** Insert after the mode-list paragraph (after line 16's "Both modes end the
same way…" sentence), as its own paragraph:
```markdown
This verb writes the deployed layout (`.handbook/design/`). On an unstamped root — no
installation block — report what is missing, point at `/clankshop setup` / `migrate`, and write
nothing: the face owns bootstrap, and there is no pre-stamp write license here. Judgment
(mode detection, advice on the material found) runs anywhere.
```

3c. **Command fix (line 185):**
`bash <skill-dir>/scripts/clankshop design-check.sh <project>/.handbook/design [<repo-root>]` →
`bash <skill-dir>/scripts/design-check.sh <project>/.handbook/design [<repo-root>]`
And line 193: `` Both are `architect-check.sh`'s exit-1 conditions `` → `` Both are `design-check.sh`'s exit-1 conditions ``

3d. **Delete Step 7 wholly** (lines 205–243: the `## 7. Register the front-door route
(self-registration)` heading through the end of its numbered list, including the door-block
fenced example). The `## Report` section moves up to follow `## 6.` directly.

3e. **Report tail (former lines 249–250):** delete the clause
`` and the front-door\nregistration result (Step 7): `appended`/`replaced`/`malformed` + the `built-against` stamp `` —
the sentence ends at `…plus a list of what's advisory-outstanding.`

- [ ] **Step 4: plan.md — prep out, seam re-anchored**

In `skills/clankshop/verbs/design/plan.md`:

4a. Line 5–6: `which specs get revised, which systems get\nprepped/regenerated, and in what order` → `which specs get revised, which systems' code\nfollows, and in what order`

4b. Line 14: `(The altitude seam is the runbook's — `skills/clankshop/PACK.md`.)` →
`(The altitude seam is `docs/DESIGN-DOCTRINE.md` § The seam's.)`

4c. Replace the second bullet of "What this verb references but does not perform" (lines 29–39,
including the trailing no-op-prep sentence) with:
```markdown
- **Build work** (`plan` only *references* this): for each system whose code must change once
  its spec is settled, an ordinary `/feature` cycle (`plan` → `build`) executes the change
  against the revised seed. `plan` names *that this step exists and in what order it runs*, and
  stops there — it does not write the feature plan and does not touch code.
```

4d. Line 54: `(§4 of `verbs/design/brainstorm.md`)` → `(Procedure step 4 of `verbs/design/brainstorm.md`)`

4e. Replace Step 4 (lines 64–70) with:
```markdown
4. **Sequence the build work.** For each system whose *code* will need to change once its spec
   is settled, record the reference — "system X: spec revision → `/feature`" — not an executed
   step; a system whose change stays inside the seed is tagged "spec revision only." Sequence
   across systems by their `MAP.md` dependency order: a system other systems depend on generally
   lands before its dependents, so a dependent's build lands against an already-settled seam.
```

4f. Line 81–82: `(`<project: .records/plans/<date>-<slug>.md, indexed\n     from ROADMAP.md>`; conventions vary)` → `(commonly `.records/plans/<date>-<slug>.md`, indexed\n     from the project's roadmap; conventions vary)`

4g. Line 89: `since the next `/clankshop design prep` invocation needs to find this document.` →
`since whoever walks the sequence needs to find this document.`

4h. Line 91–92: `` `plan` doesn't invoke\n`/clankshop design prep`, doesn't invoke `/feature`, and doesn't touch code. `` → `` `plan` doesn't invoke\n`/feature` and doesn't touch code. ``

4i. Report (lines 99–101): `the ordered prep/build reference list\n(Step 4) — each item tagged with its recommended mode (prep replace / prep extend / straight to\n`/feature`, or none needed),` → `the ordered build-work reference list\n(Step 4) — each item tagged *spec revision only* or *spec + build work → `/feature`*,`

- [ ] **Step 5: reconcile.md — health sweep, command fix, seam rows**

In `skills/clankshop/verbs/design/reconcile.md`, replace old-architect `check` with `health`
(these are ALL the instances; the file's `/clankshop check` never appears today):
- line 5 (×2): `` `check`'s deep counterpart. Where `check` runs cheaply and often `` → `` `health`'s deep counterpart. Where `health` runs cheaply and often ``
- line 9: `§ Cheap `check`, deep `reconcile`` → `§ Cheap `health`, deep `reconcile``
- line 28: `before trusting the seed for a rebuild` → `before trusting the seed`
- line 29: `not on every commit the way you run `check`.` → `not on every commit the way you run `health`.`
- line 41 heading: `## 2. Scope from `check` first — don't re-derive its structural facts` → `## 2. Scope from `health` first — don't re-derive its structural facts`
- line 43: `Run (or read a recent run of) `check`'s fact script` → `Run (or read a recent run of) `health`'s fact script`
- line 46 command: `bash <skill-dir>/scripts/clankshop design-check.sh <project>/.handbook/design [<repo-root>]` → `bash <skill-dir>/scripts/design-check.sh <project>/.handbook/design [<repo-root>]`
- line 62: `A\nsystem `check` reports clean is not proven semantically conformant` → `A\nsystem `health` reports clean is not proven semantically conformant`
- line 119–120: `and the `check` baseline it\n  scoped from (Step 2)` → `and the `health` baseline it\n  scoped from (Step 2)`
- line 161: `the report is stamped with the\n  HEAD and `check` baseline it was built against` → `…HEAD and `health` baseline it was built against`
- Replace the seam table's first bullet (lines 141–144) with TWO bullets:
```markdown
- **vs `health`** — `health` is the cheap, frequent, *structural* gate (does a pointer resolve, is a
  contract present); `reconcile` is the deep, occasional, *semantic* read (does the contract still
  *mean* what the code does). `reconcile` consumes `health`'s facts to aim itself; it does not
  replace them.
- **vs `/clankshop check`** — the face's `check` validates the *assembly* (stamps, projections,
  registrations); it never reads the seed's content. Different fact namespace, different question.
```

- [ ] **Step 6: extract.md — reframe + posture + seed-name**

In `skills/clankshop/verbs/design/extract.md`:
- line 12: `— not a proven, binding seed a rebuild could regenerate that code from.` → `— not a proven, binding seed.`
- lines 14–16: `a seed reverse-engineered from code and then used to rebuild that code proves only\nreverse-engineering skill, never that the *standing seed was sufficient on its own*.` → `a spec reverse-engineered from code proves only\nreverse-engineering skill, never that the *standing seed says enough on its own*.`
- line 58: `Reuse `setup` greenfield's code-inventory shape` → `Reuse `seed` greenfield's code-inventory shape`
- line 100–101: `the gap report says "here is what a rebuild would have\nto guess."` → `the gap report says "here is what an agent acting on this spec\nwould have to guess."`
- line 104–105: `so a rebuild\n  can't know whether it is sacred or incidental.` → `so a later implementer\n  can't know whether it is sacred or incidental.`
- line 106–107: `so the\n  "does the rebuild pass?" question has no answer yet.` → `so the\n  "does the implementation pass?" question has no answer yet.`
- line 108: `**Anything a rebuild would guess**` → `**Anything an implementer would guess**`
- Insert a posture paragraph after the three hard rules (after line 29), as its own paragraph:
```markdown
This verb writes the deployed layout (`.records/design/draft/`). On an unstamped root — no
installation block — report what is missing, point at `/clankshop setup` / `migrate`, and write
nothing; the inventory-and-judge half (Steps 1–3's reading) runs anywhere.
```
- Check the file for any remaining `rebuild` token afterward: `grep -n rebuild skills/clankshop/verbs/design/extract.md` — rewrite any survivor in the same "implementer / acting on the spec" register.

- [ ] **Step 7: brainstorm.md, distill.md, health.md touch-ups**

`skills/clankshop/verbs/design/brainstorm.md`:
- line 18: `(The altitude seam itself is the runbook's — `skills/clankshop/PACK.md` + `docs/DESIGN-DOCTRINE.md`.)` → `(The altitude seam is `docs/DESIGN-DOCTRINE.md` § The seam's.)`
- line 71: `same as `init`'s Step 5` → `same as `seed`'s Step 5` — first CONFIRM the referent:
  read the sentence; it cites the doc-edits-direct discipline, which is `seed.md` `## 5. Update
  project wiring` ("Document → seed edits it directly"). If after reading you judge the referent
  is actually seed's §4 (consuming spent inputs), cite that instead — pick whichever section the
  sentence's "document edit, performed directly" claim actually matches.
- line 85: `doesn't validate the change against `check`` → `doesn't validate the change against `health``

`skills/clankshop/verbs/design/distill.md`:
- line 18: `not triggered\nautomatically by `check`'s distill-debt signal` → `not triggered\nautomatically by `health`'s distill-debt signal`
- line 60: `the same way `check`'s `drift:<sys>` flags one mechanically after the fact.` → `the same way `health`'s `drift:<sys>` flags one mechanically after the fact.`

`skills/clankshop/verbs/design/health.md`:
- line 11 command: `bash <skill-dir>/scripts/clankshop design-check.sh <project>/.handbook/design [<repo-root>]` → `bash <skill-dir>/scripts/design-check.sh <project>/.handbook/design [<repo-root>]`
- line 26: `— **no contract = not rebuildable** |` → `— **no contract = nothing binding to build against** |`
- line 42–44: `a rebuild has no constitution, or no binding contract, to work from.` → `there is no constitution, or no binding contract, for anything downstream to build against.`
- line 51–53: `whether a spec that passes every check is\nactually *sufficient to rebuild from*:` → `whether a spec that passes every check\nactually *says enough to act on*:`
- line 53–54: `while\nstill omitting the one invariant that made the old system work. Passing `check` is a floor, not a\nverdict of sufficiency.` → `while\nstill omitting the one invariant that made the system work. Passing `health` is a floor, not a\nverdict of sufficiency.`
- line 59–61: `` `check` is what you run cheaply and often; the read-test is the\nexpensive, occasional proof that the seed actually holds up. See `docs/DESIGN-DOCTRINE.md` § Sufficiency,\nand its circularity for why a rebuild that reverse-engineers gaps out of the old code doesn't\ncount as evidence either. `` → `` `health` is what you run cheaply and often; the read-test is the\nexpensive, occasional proof that the seed actually holds up. See `docs/DESIGN-DOCTRINE.md`\n§ Sufficiency, and its circularity for why a code-traced draft doesn't count as evidence either. ``

- [ ] **Step 8: Templates**

- `skills/clankshop/templates/design/MAP.md` line 3: `The system index and seam graph — the input `/clankshop design prep` and `/clankshop design plan` read to scope work.` → `The system index and seam graph — the input `/clankshop design plan` reads to scope work.`
- `skills/clankshop/templates/design/system-spec.md` line 16: replace the acceptance placeholder line's text `rebuild must pass; `check` flags a spec whose acceptance is still a placeholder` → `the implementation must pass; `design health` flags a spec whose acceptance is still a placeholder` (keep the surrounding `<…>` placeholder markers intact).
- `skills/clankshop/templates/design/README.md` line 21: replace `the compilable per-system
  specs` with `the per-system specs` (the compile metaphor leaves with the rebuild concept) and
  re-wrap so the line lands under ~98 chars, e.g.:
```markdown
`/clankshop design health` fails if any is missing.
`.handbook/design/src/` holds the per-system specs,
```
(preserve the rest of the sentence exactly; only the token and the wrap change).

- [ ] **Step 9: Verify**

```bash
grep -rnE "\bprep\b" skills/clankshop/ --include='*.md' | grep -v "docs/design"        # expect: empty
grep -rniE "rebuild|regenerat|compilable" skills/clankshop/verbs/ skills/clankshop/roles/ skills/clankshop/templates/  # expect: empty
grep -rn "clankshop design-check" skills/clankshop/                                    # expect: empty
grep -rn '`setup`' skills/clankshop/verbs/design/                                      # expect: empty
bash skills/clankshop/scripts/tests/run.sh && bash skills/skill-builder/scripts/skills-lint.sh .
```
Expected: greps as annotated; suite ALL GREEN; lint `fails=0 warns=8`.

- [ ] **Step 10: Commit (re-ground on HEAD first)**

```bash
git add skills/clankshop/SKILL.md skills/clankshop/roles/architect.md skills/clankshop/verbs/design/ skills/clankshop/templates/design/
git commit -m "clankshop(reconcile): design verbs -- seed sheds its setup self-name, pre-stamp registration (old Step 7) deleted, plan re-anchored on the design->feature seam (prep out), reconcile/distill/brainstorm/health speak health for the cheap check, hat identity reframed, templates follow; seed admitted as an explicit subverb in the router" \
  -- skills/clankshop/SKILL.md skills/clankshop/roles/architect.md skills/clankshop/verbs/design/ skills/clankshop/templates/design/
```

---

### Task 4: Posture + shared disciplines

**Files:**
- Modify: `skills/clankshop/SKILL.md` (shared-discipline block)
- Modify: `skills/clankshop/verbs/route.md`
- Modify: `skills/clankshop/verbs/verify/tend.md`
- Modify: `skills/clankshop/verbs/verify/judge.md`
- Modify: `skills/clankshop/verbs/calibrate/intake.md`
- Modify: `skills/clankshop/roles/chiropractor.md`

**Interfaces:**
- Consumes: the router table as Task 3 left it (the block inserts after the dispatch-rule
  paragraph, before the table).
- Produces: the phrase "judgment runs anywhere; writes need a home" as the posture's canonical
  statement — verb files reference the behavior, never restate the rule in full.

- [ ] **Step 1: SKILL.md shared-discipline block**

Insert into the `## Verbs and hats — the two-layer contract` section, immediately after the
dispatch-rule paragraph (after line 30's `…`ask` is the one route that\naddresses a hat
directly.`) and before the verb table:
```markdown
**Shared discipline (every verb, hatted or not):** resolve the project root first — a project
directory the conversation references, else the working directory, else ask — and use
project-relative paths from it. Get the real date with `date +%Y-%m-%d`; never guess it. Verbs
that write into the deployed layout (`.handbook/`, `.records/`) need a stamped root: absent the
installation block, report what's missing, point at `setup`/`migrate`, and write nothing —
**judgment runs anywhere; writes need a home.**
```

- [ ] **Step 2: route.md unstamped paragraph**

Replace lines 15–17:
```markdown
**On an unstamped root** (no installation block), foreman is **read-only**: emit `unstamped`,
point at the clankshop onramps (`setup` / `migrate`), and stop — foreman no longer stands systems
up, and `/clankshop route init` does not exist.
```
with:
```markdown
**On an unstamped root** (no installation block) there is no deployed walk to read: classify by
the pack doctrine's own chapter (`doctrine/rules/ROUTING.md`) and say you did, but write no
rulebook and no log — the onramps (`setup` / `migrate`) stand the system up, and
`/clankshop route init` does not exist. Judgment runs anywhere; writes need a home.
```

- [ ] **Step 3: verify verbs**

`skills/clankshop/verbs/verify/tend.md`:
- line 27: replace the clause `or on an unstamped root (read-only: emit `unstamped`, point at the onramps).` with `on an unstamped root, judgment still runs — advise and specify freely; chapter writes wait (point at the onramps).`
- line 31: replace `**Resolve root**; confirm the root is stamped and `.handbook/testing/` exists (absent → that's a deploy gap; point at the pack onramps, don't scaffold here).` with `**Resolve root.** Tending writes `.handbook/testing/`: unstamped or chapter-less → report the gap, point at the pack onramps, and write nothing — advise freely, scaffold never.`
- line 22: at the first bare `` `judge` `` reference, spell the full route once: `` `judge` `` → `` `judge` (`/clankshop verify judge`) ``

`skills/clankshop/verbs/verify/judge.md`:
- line 29: replace `On an unstamped root: read-only — emit `unstamped`, point at the onramps.` with `Judgment needs no installation — a defect-vs-flake call reads the evidence anywhere; only the chapter writes it earns (via `tend`) wait for a stamped root.`
- line 12: at the FIRST bare `` `tend` `` reference, spell the full route once: `` tend `` → `` `tend` (`/clankshop verify tend`) `` — later bare uses may stand once the route is established.

- [ ] **Step 4: intake.md posture + promotion-bar hook**

`skills/clankshop/verbs/calibrate/intake.md`:
- line 31: replace `**Resolve root; confirm stamped** (else refuse: `unstamped`, point at the onramps).` with `**Resolve root; confirm stamped.** The loop drains the deployed stores — on an unstamped root there is nothing to drain: report that, point at the onramps, and write nothing.`
- In step 3 (the "Claim, then dispatch" item), append a final sub-bullet after the dispatch
  bullet (the one ending `…as ordinary work through the ordinary lanes.`):
```markdown
   - An item that crosses the promotion bar — a *decision*, *sign-off*, *ambiguity*, or *access*
     need only the human can resolve — is handed to `/backlog promote` instead of an owning
     hat; it stays claimed until the ticket resolves, like any other work.
```

- [ ] **Step 5: chiropractor hat — no-seat line**

In `skills/clankshop/roles/chiropractor.md`, insert a bullet in `## Standing judgments`, after
the "You are the only scanner…" bullet (line 13–16):
```markdown
- **No seat, no chapters.** This hat keeps no records store and no seat of its own; the loop's
  books (claims, `processed:` stamps, run-log lines) live in the stores the record schema
  already defines.
```

- [ ] **Step 6: Verify**

```bash
grep -rn 'emit `unstamped`' skills/clankshop/verbs/   # expect: empty
grep -rn "date +%Y-%m-%d" skills/clankshop/SKILL.md   # expect: 1 hit
bash skills/clankshop/scripts/tests/run.sh && bash skills/skill-builder/scripts/skills-lint.sh .
```
Expected: greps as annotated; suite ALL GREEN; lint `fails=0 warns=8`.

- [ ] **Step 7: Commit (re-ground on HEAD first)**

```bash
git add skills/clankshop/SKILL.md skills/clankshop/verbs/route.md skills/clankshop/verbs/verify/ skills/clankshop/verbs/calibrate/intake.md skills/clankshop/roles/chiropractor.md
git commit -m "clankshop(reconcile): posture + disciplines -- judgment-anywhere/writes-need-a-home stated once in SKILL.md and applied to route/verify/intake (refusals become report-and-point, judgment keeps running), real-date + root-ladder discipline restored, intake regains the promotion-bar hook, chiropractor hat states no-seat" \
  -- skills/clankshop/SKILL.md skills/clankshop/verbs/route.md skills/clankshop/verbs/verify/ \
  skills/clankshop/verbs/calibrate/intake.md skills/clankshop/roles/chiropractor.md
```

---

### Task 5: Editorial sweep + version bump

**Files:**
- Modify: `skills/clankshop/verbs/verify/tend.md`
- Modify: `skills/clankshop/verbs/calibrate/intake.md`
- Modify: `skills/clankshop/verbs/docs.md`
- Modify: `skills/clankshop/verbs/check.md`
- Modify: `skills/clankshop/doctrine/README.md`
- Modify: `skills/clankshop/templates/doc-drift.md`
- Rename: `skills/clankshop/scripts/tests/calibrator-test.sh` → `skills/clankshop/scripts/tests/calibrate-test.sh`
- Modify: `skills/clankshop/scripts/tests/run.sh`
- Modify: `skills/clankshop/PACK.md`
- Modify: `crates/grimoire-pack/tests/clankshop.rs`

**Interfaces:**
- Consumes: all prior tasks landed (this is the final pass).
- Produces: pack `version: 1.1.0`; the crate test pins the same string.

- [ ] **Step 1: Editorial nits**

- `skills/clankshop/verbs/verify/tend.md` line ~43: in the sentence containing `rulebook steward rather than editing another role's chapter.`, replace that fragment with `rulebook steward — raise it via `/clankshop route` — rather than editing another hat's chapter.`
- `skills/clankshop/verbs/calibrate/intake.md` lines 42–46: replace the dispatch parenthetical
```markdown
(a routing gap → the rulebook steward; a gate/playbook gap → the verification role; a
     seed divergence → the design role; a doc-form finding → the docs-quality role; a record
     format concern → the records instrument's steward)
```
with:
```markdown
(a routing gap → the foreman hat; a gate/playbook gap → the guardian hat; a
     seed divergence → the architect hat; a doc-form finding → the chiropractor's `docs` verb; a
     record format concern → the records instrument)
```
- `skills/clankshop/verbs/docs.md` line 315: `- **A role of the pack, still spine-generic.**` → `- **A verb of the pack face, still spine-generic.**`
- `skills/clankshop/verbs/check.md` line 53: `` `seats` (each role's seat present for installed roles that need one); `` → `` `seats` (each seat present for installed members that need one); ``
- `skills/clankshop/doctrine/README.md` team-roster table: add one row after the helper row (line 44):
```markdown
| **helper (optional)** | `bug` / `task` | capture aliases | one-word proxies for the records instrument's bug/task capture; installed opt-in |
```
- `skills/clankshop/templates/doc-drift.md` line 5: `a calibrate signal entry ID` → `an improvement-item ID from `calibrate``

- [ ] **Step 2: Test-harness rename**

```bash
git mv skills/clankshop/scripts/tests/calibrator-test.sh skills/clankshop/scripts/tests/calibrate-test.sh
```
In `skills/clankshop/scripts/tests/run.sh` line 8, replace `calibrator-test.sh` with
`calibrate-test.sh`. Then check the renamed file's own self-references:
`grep -n "calibrator" skills/clankshop/scripts/tests/calibrate-test.sh` — update its header/echo
labels (`calibrator:` → `calibrate:`) so the suite output stays self-describing; do NOT change
any fixture content strings the asserts compare against unless the assert and the fixture change
together.

- [ ] **Step 3: Version bump**

- `skills/clankshop/PACK.md` line 3: `version: 1.0.0` → `version: 1.1.0`
- `crates/grimoire-pack/tests/clankshop.rs` line 24: `assert_eq!(clank.manifest.version.to_string(), "1.0.0");` → `assert_eq!(clank.manifest.version.to_string(), "1.1.0");`

- [ ] **Step 4: Full verification (all gates)**

```bash
bash skills/clankshop/scripts/tests/run.sh
bash skills/skill-builder/scripts/skills-lint.sh .
cargo test --workspace
bash skills/skill-builder/scripts/register-route-drift.sh .
grep -rn "/architect\|/foreman\|/guardian\|/calibrator\|/chiropractor" skills/ README.md AGENTS.md | grep -v "roles/" | grep -v "docs/design/" | grep -v "skills-lint.sh"
```
Expected: suite ALL GREEN (174 asserts + spine-scan PASS — same counts, the calibrate-test
rename must not change assert totals); lint `fails=0 warns=8`; cargo 36 green; drift
`checked=3 drift=0`; persona grep empty.

- [ ] **Step 5: Routing probe re-run**

Dispatch a fresh subagent with ONLY the updated `SKILL.md` description + verb table (copy them
into the prompt; forbid file access) and the ten intent phrases from the audit
(`.scratch/clankshop-merge-audit.md`, Behavioral probes section). Expected: 10/10 routed, and
"validate that our design docs are complete" now resolves to `design health` (the new gloss).
A remaining mis-route is a finding to report to the owner, not something to silently fix.

- [ ] **Step 6: Commit (re-ground on HEAD first)**

```bash
git add skills/clankshop/verbs/verify/tend.md skills/clankshop/verbs/calibrate/intake.md \
  skills/clankshop/verbs/docs.md skills/clankshop/verbs/check.md skills/clankshop/doctrine/README.md \
  skills/clankshop/templates/doc-drift.md skills/clankshop/scripts/tests/run.sh \
  skills/clankshop/scripts/tests/calibrate-test.sh skills/clankshop/PACK.md \
  crates/grimoire-pack/tests/clankshop.rs
git commit -m "clankshop(reconcile): editorial sweep + version -- dispatch targets speak hats/members, roster lists the optional proxies, calibrator-test renamed calibrate-test, residual role-as-actor phrasing cleaned; pack 1.1.0 (content reshape visible to installs) with the crate pin following" \
  -- skills/clankshop/verbs/verify/tend.md skills/clankshop/verbs/calibrate/intake.md \
  skills/clankshop/verbs/docs.md skills/clankshop/verbs/check.md skills/clankshop/doctrine/README.md \
  skills/clankshop/templates/doc-drift.md skills/clankshop/scripts/tests/run.sh \
  skills/clankshop/scripts/tests/calibrator-test.sh skills/clankshop/scripts/tests/calibrate-test.sh \
  skills/clankshop/PACK.md crates/grimoire-pack/tests/clankshop.rs
```

- [ ] **Step 7: Close-out**

Mark the design doc's status line executed:
`docs/design/2026-08-10-clankshop-audit-reconciliation.md` line 3,
`**Status: proposed** (brainstormed with the owner 2026-08-10; decisions below are owner-ratified).`
→ `**Status: executed 2026-08-10** (owner-approved; see the reconciliation plan beside this doc).`
Commit it pathspec-scoped:
```bash
git add docs/design/2026-08-10-clankshop-audit-reconciliation.md
git commit -m "clankshop(reconcile): design doc marked executed" -- docs/design/2026-08-10-clankshop-audit-reconciliation.md
```
Then report to the owner: all five tasks landed, the gate results, the probe outcome, and that
the live deployment test (greenfield + brownfield, per the hand-off) is now unblocked.
