# Clankshop pack — the checked migration manifest

**Status:** live working inventory (2026-08-07, derived at plan head `b9b7d4d`). The
search-derived, item-checked enumeration of every live surface the clankshop restructure touches
(plan Task 0.7; pack §8 Phase 0). **This manifest is the authoritative enumeration:** later tasks
execute *their* rows; a touched surface with no row is a plan bug surfaced here. Rows are checked
off by the task that executes them.

**How it was built, and how to re-verify.** Each term family below was swept with
`grep -rlE '<pattern>' skills/ packs/ README.md AGENTS.md install.sh` (the pack's own new
`skills/clankshop/` excluded — it is the destination, not a migration surface). Every file a
sweep hit appears in **exactly one row per surface** (a file hosting several distinct surfaces —
e.g. a SKILL.md with tracker paths *and* an edges block — gets one row per surface, each with
exactly one disposition and one receiving task). Re-running the sweeps after Phase 5 must find
every hit either gone or in an explicitly-retained row.

**Sweep registry** (term families, per plan Task 0.7): `\.agents/foreman` · `MEMORY\.md` ·
`BOOTSTRAP` · `TAXONOMY` · `derive-seams` · `check-projection` · `packs/clankshop` · `calibrate` ·
`done-record` · `design-draft` · `\.records/archive` · `foreman (setup|init|migrate|check)` ·
`tracker-entry` · `<!-- edges:` · `typed[- ]edge` · `open vocabulary` · `Edges:` (route-block
lines) · `PLANNING\.md` · `ROUTING\.md` · `records-root` · `doc-linter`. The `open vocabulary`
sweep returned **zero hits on active surfaces** (the term lives only in design docs) — no rows.
The `doc-linter` sweep confirms **no linter implementation exists in this library** — every hit
is prose to re-point at the deployed check chain (each file's own conformance task carries it).

**Historical exclusion (design-docs-are-historical):** `docs/design/*` and `docs/BACKLOG.md`
legitimately retain every retired term (verified: 8 files hit `derive-seams` alone) and are
**excluded** from disposition — except the three superseded design docs receiving status lines
(Task 4.5) and the two contract docs + plan, which this restructure executes.

---

## Phase 0/1 — the installer ↔ lock seam

- [x] `install.sh` ↔ `packs/clankshop.md` frontmatter — the manifest/lock seam: lock format
  (pack-version / layout / core / helpers / optional) landed → **Task 0.6 (done, `b9b7d4d`)**
- [ ] `install.sh` — `--pack` becomes transactional against the lock (presence, collision, helper
  ranges; abort/rollback) → Task 1.7

## Phase 2 — backlog (the records instrument; re-framing only, NO rename)

- [x] `skills/backlog/SKILL.md` — tracker store paths (`.records/` flat → `.records/trackers/`)
  + verb table gains `done` + escalation family → Task 2.1
- [x] `skills/backlog/verbs/{task,bug,issue,note,feedback}.md` — store paths, trunk-side ID
  allocation discipline, lazy-`init` call on unstamped roots → Task 2.1
- [x] `skills/backlog/verbs/init.md` — door registration rewritten to the pack-style block
  (today: path-SHA stamp + `Edges:` body, lines 48/85) → Task 2.1
- [x] `skills/backlog/scripts/scaffold-records.sh` — hardcodes old flat store paths; rewrite to
  `.records/trackers/` + ID-aware shapes → Task 2.1
- [x] `skills/backlog/scripts/backlog-health.sh` — hardcodes old flat store paths; rewrite +
  absorb foreman-health `inventory`'s tracker-size facts → Task 2.1
- [x] `skills/backlog/templates/{bug-report,note}.md` — store-dir frontmatter gains `id:` →
  Task 2.1
- [x] `skills/foreman/templates/done-record.md` — **copied** to
  `skills/backlog/templates/done-record.md` (backlog is the `done/` steward); the foreman copy
  stays until Task 3.2 (live `workstream/verbs/ship.md:107` still references it) → Task 2.1
- [x] `skills/backlog/verbs/curate.md` — ID stamping, duplicate-ID repair with aliases, ticket
  hygiene, aging resolved tickets → Task 2.2
- [x] `skills/backlog/SKILL.md` + verb prose — capture-bureau framing → the instrument contract
  (pack §4.3); unstamped conduct verb-by-verb (capture verbs lazily init; all others refuse) →
  Task 2.4
- [x] `skills/backlog/docs/TAXONOMY.md` — reduced to a pointer at the doctrine's canonical
  schema (doctrine is canonical from Task 0.2); escalation/wire content lives in the doctrine →
  Task 2.4
- [x] `skills/backlog/verbs/{note,debrief}.md` — the note-vs-`MEMORY.md` classifier retargeted
  to the INVARIANTS bar → Task 2.4
- [x] `skills/backlog/*` prose references to "the doc-linter" (SKILL.md, TAXONOMY.md, verbs,
  `scripts/scoped-commit.sh` comment) — re-pointed at the deployed check chain (no linter
  implementation exists in this library) → Task 2.4
- [x] proxy alias skills `bug` / `task` — new one-line SKILL.mds; join the lock's `optional:` +
  `skills:` lines and README's inventory in the same commit → Task 2.4

## Phase 2 — foreman (slim to routing + rulebook)

- [x] `skills/foreman/verbs/{setup,migrate,check}.md` — deleted (successors: clankshop Tasks
  1.3–1.5); the `init` alias surface in SKILL.md removed (`/foreman init` ceases to exist) →
  Task 2.5
- [x] `skills/foreman/BOOTSTRAP.md` — retired (durable judgment absorbed by the Phase-0
  doctrine); the skills-lint BOOTSTRAP-manifest check (check 3) loses its subject and is
  adjusted in the same commit → Task 2.5
- [x] `skills/foreman/SKILL.md` — slimmed to `route` + rulebook stewardship; description
  rewritten (no setup language; probe re-runs at the phase gate) → Task 2.5
- [x] `skills/foreman/verbs/route.md` — live consumer of the old deployed layout
  (`.agents/foreman/docs/ROUTING.md` at lines 4/18) re-pointed to `.handbook/rules/ROUTING.md`;
  promotion-bar hand-off to `/backlog promote` stated → Task 2.5
- [x] `skills/foreman/scripts/foreman-health.sh` — the five-subcommand transfer table:
  `check-projection` (incl. `routing-targets`, line 339) → clankshop `check-facts.sh` (landed
  1.5), removed here; `inventory` (`tree_quiet`/`linked_worktrees` → migrate preflight + check;
  tracker sizes → `backlog-health.sh`) removed here; `stale-refs` + `coverage` stay until Task
  2.8 moves them; `derive-seams` stays until Task 4.3 → Task 2.5
- [x] `skills/foreman/docs/{ROUTING,PLANNING,WORKTREES,MAINTENANCE}.md` — judgment diffed
  against the Phase-0 doctrine and absorbed here; files deleted in Task 4.4 (live consumers:
  `route.md:4`, `feature/SKILL.md`, `workstream/flow.md:69`, `packs/clankshop.md:131`) →
  Task 2.5
- [x] `skills/foreman/scripts/scoped-commit.sh` — doc-linter comment re-pointed → Task 2.5
- [ ] `skills/foreman/templates/report.md` — no absorption needed; successors are the bundled
  templates of Tasks 2.7/2.8; deleted in Task 4.4 → Task 4.4

## Phase 2 — the new roles and the instruments

- [x] `skills/guardian/` — new build (SKILL.md + tend/judge verbs; `testing/` chapter seeded
  from doctrine Task 0.3); joins lock `skills:`/`core:` + README inventory in the same commit →
  Task 2.6
- [x] `skills/debugger/SKILL.md` — conform as the diagnostic instrument: findings per the
  report wire contract, bundled `templates/investigation.md` (a `report.md` successor), pause
  refusal, playbook pointer, unstamped read-only; discipline verbatim → Task 2.7
- [x] `skills/chiropractor/SKILL.md` — drop the any-repo genericity mandate; framework-aware
  document-fact set (the §4.6 partition); reports per the wire contract with bundled
  `templates/doc-drift.md` (the other `report.md` successor); unstamped read-only → Task 2.8
- [x] `skills/chiropractor/scripts/spine-scan.sh` — hardcoded `GLOSSARY.md`/`INDEX.md`
  candidate lists (the "Affordance flags" section — locate by content; old `:427,429` drifted)
  replaced by the frozen facts (`has_front_door`/`has_stewardship_map`/`has_glossary`); consumes
  `spine-parse.sh`; its `.records/archive` + typed-edge comment references updated; fixtures
  updated → Task 2.8
- [x] `skills/foreman/scripts/foreman-health.sh` — `stale-refs` + `coverage` absorbed into
  chiropractor's scripts (destination tested first, then both subcommands deleted here) →
  Task 2.8
- [x] `skills/architect/SKILL.md` + `verbs/{extract,init,brainstorm,plan}.md` +
  `docs/DOCTRINE.md` — paths (`.records/design-draft/` → `.records/design/draft/`, archived on
  consumption; seat/role-contract re-framing; `packs/clankshop` references; doc-linter
  re-point); `init`'s door registration → pack-style block (today `verbs/init.md:226` writes an
  `Edges:` body) → Task 2.9
- [x] `skills/architect/verbs/reconcile.md` — report writing conformed to the wire contract:
  `reconcile-<date>-<slug>.md` (today slug-less, line 107), frontmatter floor, collision rule →
  Task 2.9
- [x] `skills/auditor/{SKILL.md,BOOTSTRAP.md}` — seat path → `.agents/roles/auditor/`;
  `.agents/foreman` + doc-linter references; finding shape gains optional `processed:`;
  `deploy`'s door registration → pack-style block; system-improvement-bar framing (findings past
  the bar feed the calibrator; code findings → route) → Task 2.10
- [x] `skills/auditor/rules/technical-debt.md` — "calibrate" as ordinary rubric English — **no
  change** (verified in Task 2.10's pass)

## Phase 2 — the steward-grammar surfaces (built 2026-07-28; dissolved into the calibrator)

All four execute **in Task 2.11's commit** (the calibrator must exist first — no window with no
drain owner):

- [x] `skills/foreman/verbs/calibrate.md` — deleted → Task 2.11
- [x] `skills/architect/verbs/calibrate.md` + its SKILL.md Verbs-table row, description
  sentence, edges consumes clause, and `distill`'s seam-line revert → Task 2.11
- [x] `skills/chiropractor/SKILL.md` — the `## Calibrate` section, its description sentence, the
  `tracker-entry (optional)` consumes line → Task 2.11
- [x] `skills/skill-builder/verbs/calibrate.md` + SKILL.md references — the toolmaker's own
  doctrine-distillation verb, **outside the pack** — **no change** (verified when 2.11 lands:
  the calibrate-grammar supersession covers pack members only)
- [x] `packs/clankshop.md` — the four 2026-07-28 drain seam rows (`backlog ↔ chiropractor`,
  `backlog ↔ architect`, amended `foreman ↔ chiropractor` / `architect ↔ foreman` cells) + the
  `tracker-entry` vocabulary row — replaced with the calibrator-loop framing (minimal edits;
  full body absorption is Task 4.4) → Task 2.12

## Phase 3 — pipelines and helpers

- [ ] `skills/feature/SKILL.md` — retired-layout references (`.agents/foreman/docs/PLANNING.md`,
  `MEMORY.md`, GOTCHAS paths, TAXONOMY as frontmatter authority) → handbook chapters + the
  doctrine schema; stamped-only guard; `init` conformed to the pack-style door block (the fourth
  surviving core route writer — today a path-SHA stamp + `Edges:` body) → Task 3.1
- [ ] `skills/feature/templates/{plan-implementation,roadmap}.md` — `.agents/foreman/MEMORY.md`
  / GOTCHAS / `PLANNING.md` references → new homes → Task 3.1
- [ ] `skills/feature/docs/ideal-use.md` — teaches typed-edge continuation at HEAD — rewritten
  to the pack seam (also swept by 4.2's assert) → Task 3.1
- [ ] `skills/workstream/SKILL.md`, `verbs/{ship,close,create,sync}.md`, `flow.md`,
  `templates/{coordinator,debug,design,workstream-handoff}.md` — old-layout hits
  (`.agents/foreman`, `MEMORY.md`, `.records/archive` → per-store archiving + `.records/done/`,
  doc-linter prose, PLANNING/ROUTING references); `ship` calls `backlog done` per shipped item
  + writes its own done-record; stamped-only guard → Task 3.2
- [ ] `skills/foreman/templates/done-record.md` — **deleted** (deferred from Task 2.1;
  `ship.md`'s reference re-pointed to backlog's copy in the same commit) → Task 3.2
- [ ] `skills/workstream/scripts/workstream-git.sh` — reads `records-root` (the variable keeps
  its exact contract) — **no change** beyond path verification in 3.2's sweep → Task 3.2
- [ ] `skills/handoff/SKILL.md` — two ratified path edits (locate by content): durable-record
  pointer `.records/archive/` → `.records/done/`; Pointers row `.agents/foreman/README.md` →
  `.handbook/README.md` → Task 3.3
- [ ] `skills/{delegate,mailbox,handoff}/SKILL.md` — frontmatter gains `version: 1`; same
  commit upgrades the lock's `helpers:` line bare → ranged (`delegate>=1 mailbox>=1
  handoff>=1`); **everything else in the helpers untouched** (edges blocks and independence
  discipline stay) → Task 3.3

## Phase 4 — retire the independence machinery (core members only)

- [ ] `skills/skill-builder/scripts/skills-lint.sh` — reads the lock's `core:` line as the
  machine-readable exemption for the independence checks that exist (sibling-name/boundary
  description warns; edge-block validation + orphan-type pairing; sibling verb-roster checks);
  helpers + skill-builder keep the full discipline; gate re-baselined → Task 4.1
- [ ] `skills/skill-builder/docs/DOCTRINE.md` — the pack-vs-portable split (portable rules for
  standalone skills + helpers; pack core follows authored composition) → Task 4.1
- [ ] `skills/skill-builder/{SKILL.md,verbs/new.md}` + `docs/BOUNDARY-AUDIT.md` — typed-edge /
  boundary teaching for **portable** skills — **no change** beyond DOCTRINE's split framing
  (verified in 4.1's pass) → Task 4.1
- [ ] core members' `<!-- edges: -->` blocks + edge-referencing prose —
  `skills/{architect,auditor,backlog,chiropractor,debugger,feature,foreman,workstream}/SKILL.md`
  (+ any `Edges:` route-block content a Phase-2 conformance missed) — removed; sibling-blind
  indirections rewritten to direct pack references; helpers untouched → Task 4.2
- [ ] `skills/foreman/scripts/foreman-health.sh` — `derive-seams` removed (its last home after
  2.5/2.8); composition is authored → Task 4.3
- [ ] `skills/{foreman,architect,auditor,feature}/scripts/register-route.sh` — the
  `derive-seams` comparison comments (line 29 at HEAD; comments only — backlog and
  skill-builder copies verified clean) rewritten → Task 4.3
- [ ] `packs/clankshop.md` body — reduced to frontmatter (manifest + lock) + a short pointer at
  `skills/clankshop/`; body judgment diffed against doctrine + runbook and absorbed first
  (additive before subtractive) → Task 4.4
- [ ] `README.md` — *Storage convention* section, steward-inventory framing, skill-table rows
  naming the old layout (`.agents/foreman`, `.records/archive`, BOOTSTRAP, design-draft,
  doc-linter, calibrate language) → the pack model → Task 4.4
- [ ] `AGENTS.md` — the steward-inventory paragraph + typed-edge references (authored library
  doctrine; patient-zero forbids registration blocks, not doctrine prose) → Task 4.4
- [ ] `docs/design/2026-07-18-skill-self-init-model.md`,
  `2026-07-18-skill-boundaries-and-glue-ownership.md` (pack-member provisions superseded;
  helper provisions stand), `2026-07-26-front-door-architecture.md` (partial supersession per
  mechanics §10) — one status-line sentence each; `2026-07-27-steward-grammar.md` already
  marked → Task 4.5

## Triage — unclassifiable, for the human

*(empty — every swept surface classified into exactly one row above)*
