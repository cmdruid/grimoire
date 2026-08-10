# Clankshop Pack Implementation Plan

> **For agentic workers:** execute this plan **one phase per build session** (`/feature build`,
> tasks tracked via the `- [ ]` checkboxes). At the **start of every phase**, re-ground: re-read
> this plan's Global Constraints, re-run the lint gate for the current baseline, and re-verify any
> path/count the phase's tasks cite against `HEAD` — the trunk moves during a long rollout.
> Between phases, an independent review of the next phase's tasks (`/feature review`) is
> recommended.

**Revision:** reworked 2026-08-07 across **five** independent external review rounds (48
must-fix findings total), every finding verified against the live tree before adoption; four
owner decisions ratified (Global Constraints' *Ratified decisions*). Rounds 1–2 fixed structure
and contract coherence; round 3 froze wire-level determinism (differ normalization, completion
mutation, collision rules, the executable ratification gate); round 4 closed contract gaps
(the BASES retrieval rule, the tier-aware door-registration protocol, completion spans + ticket
log-ID identity, claim markers + per-finding keys, optional-member semantics, the widened
retirement sweep, `routing-targets`); round 5 hardened the round-4 contracts — bump-record
coverage metadata so archive corruption is detectable (Appendix J), the equal-or-higher-rank
removal span preserving category headers (Appendix C), lifecycle-aware ticket-origin validation
(Task 1.5), feature `init` conformed as the fourth route writer (Task 3.1) with the
setup→each-init stability fixture (Task 5.3), one unified `source:`/keyed-heading/`processed:`
grammar (Appendices K/L), and the ratification gate synchronized to the full pending-freeze
list (Task 0.8). Freezes awaiting that gate: Appendix K's improvement-item + claim-marker
encodings, Appendix J's path-qualified whole-file origin IDs, Appendix L's collision +
finding-key grammar. The review trail lives in
`.scratch/agent-framework/codex-review-plan*.md` (machine-local, git-excluded).

**Status (close-out, 2026-08-08): Phases 0–4 built and gated; Phase 5 superseded by real-world
deployment.** The owner judged the fixture-proof phase over-engineered relative to real usage and
chose a live deployment test instead — greenfield `/clankshop setup` on a real consuming project,
then `/clankshop migrate` on a legacy host; usage decides what further hardening is worth
building. Tasks 5.1–5.8 stay unchecked by design; the sole pulled-forward piece is Task 5.3's
registration-stability fixture (`c4c1be6` — the four self-registering members adopt the pack-style
door block byte-identically; a hand-broken delimiter refuses untouched). Close-out baseline: commit
`7640557`, lint `fails=0 warns=10` (the recorded Phase-4 set), suite 200 asserts green across the
six committed harnesses. **Ratified divergence from Appendix H (owner, 2026-08-08):** `workstream`
is standalone — no workstream verb refuses on an unstamped root; Task 3.2's blanket-refusal
conduct (Appendix H's catch-all row) is replaced by `skills/workstream/SKILL.md` § *Host layout*
(`7640557`): clankshop hosts get the framework homes and seams, any other host gets the project's
own conventions, framework-only seams skipped. Appendix H's table text is unchanged per the
historical-record rule; this status line is the record of the divergence, which so far applies to
workstream only. **Superseded (owner, 2026-08-10): Appendix J's three-way-diff layer** — the base
archive (BASES.md), bump records, per-entry provenance markers, the differ, and the
`missing_base`/`bump_uncovered` facts are removed as unearned machinery; file-level origin stamps
and `doctrine-version` remain. Appendix J's text is unchanged per the historical-record rule;
decision and removal record: `docs/design/2026-08-10-doctrine-sync-removal.md`. **Second ratified
divergence from Appendix H (owner, 2026-08-10): `feature` is standalone** — its unstamped refusal
is replaced by `skills/feature/SKILL.md` § *Host layout* (same shape as workstream's), and `init`
is renamed `setup`, registering the pack-style block on a clankshop host and its own bundled body
under a `standalone` stamp elsewhere; no verb refuses or routes to the onramps. **Extended
(owner, 2026-08-10) to the self-init family:** the self-init verbs are uniformly `setup`
(`backlog init` → `setup`, `architect init` → `setup`, `auditor deploy` → `setup` with `deploy`
kept as an alias), and **backlog is standalone**: its trackers scaffold at the resolved
records-root on any repo, its lifecycle verbs operate on whatever stores exist instead of
refusing unstamped, and its `setup` no longer writes the installation block — that pre-stamp
license (§3.4's backlog row) is retired; framework assembly stays with the onramps. **Auditor
followed (same date):** every mode works on any repo (a missing rubric points at `setup`, never
at the onramps), its `setup` writes no installation block either and registers
standalone-stamped off-framework — §3.4's single-role install-block licenses are fully retired.
**Third ratified divergence from Appendix H (owner, 2026-08-10): the framework roles merge into
the pack face** — `architect`, `foreman`, `guardian`, `calibrator`, `chiropractor` cease to be
separate skills; routes flatten to intent verbs (`design`, `route`, `verify`, `calibrate`,
`docs`) that inherit role "hats" (an instruction layer inside clankshop; calibrator's duties fold
into the chiropractor hat), plus `ask <role>` for hat-on discussion; `auditor` stays standalone.
Design + migration plan: `docs/design/2026-08-10-clankshop-role-merge.md`.

**Goal:** Implement the clankshop pack per `docs/design/2026-08-06-clankshop-pack.md` §8, over the
mechanics of `docs/design/2026-08-04-agent-framework.md`. Where the two docs differ, **pack §7 is
authoritative**. The frozen contracts both docs name are consolidated in this plan's **Appendix**
(A–L) — phases consume them; no phase re-derives or re-decides them.

**Architecture:** Prose/skills library. The work is: three new skills (`clankshop`, `guardian`,
`calibrator`), one skill graduating from a runbook file (`clankshop` absorbs `packs/clankshop.md`),
deep edits to the six existing roles and instruments, conformance edits to the two pipelines,
ratified minimal edits to the three helpers (stale-path fixes + `version:` keys), retirement of
the independence machinery for core members,
and a fixture matrix proving the deployed system. Scripts compute facts; verb prose owns judgment
(facts-not-verdicts, unchanged).

**Gate:** `bash skills/skill-builder/scripts/skills-lint.sh .` from the repo root → `fails=0`.
Baseline at plan time: `warns=11`. A NEW warn is a task failure to fix, not accept, **unless it
is in the recorded phase baseline**: the Phase 0 gate records the expected forward-reference
warns (doctrine prose naming `/guardian`/`/calibrator` before Phase 2 creates them), each later
phase gate re-states the expected set, and every recorded warn must clear by the gate of the
phase that resolves it. Phase 4 Task 4.1 changes the gate itself (core-member exemption) and
re-states the baseline from scratch. **Recorded (2026-08-08, Task 4.1 landed): `fails=0
warns=10`** — the pre-4.1 baseline 11 minus exactly the `audit-finding` orphan-type warn
(auditor is a `core:` member, so its edge declarations no longer feed check 8's orphan
analysis; this also retires BL-4's known false-positive for good). The 9 description-length
warns (check 1) and mailbox's sibling-`/delegate` warn (a helper, check 7) persist by design;
4.2's core edge-block strips are already outside the checked set, so no further delta is
expected from this phase. Phase-end
gates add the **routing probe** (descriptions-only fixture + fresh subagent, per the Phase-gate
tasks) and, from Phase 1 on, the committed **fixture harnesses** under
`skills/clankshop/scripts/tests/`.

## Global Constraints

- Working directory `/Users/cscott/Repos/grimoire`, branch `main`. Pathspec-scoped commits
  (`git add -- <paths> && git commit -m "<msg>" -- <paths>`); no AI-attribution trailers. History
  is public: no private project names or paths in files or commit messages.
- **Both design docs are the contract; pack §7 wins on conflict.** This plan's Appendix is the
  frozen-contract text: editing it mid-build is a design change requiring an explicit human gate,
  never a drive-by fix.
- **Design docs are historical records.** Only status lines change, and only where a task says so
  (Phase 4 Task 4.5, Phase 5 Task 5.8).
- **Patient-zero:** grimoire's own `AGENTS.md` gains no registration blocks and no deployed-layout
  content; every deployed mechanism is exercised against throwaway fixtures (temp dirs). Committed
  fixture *harnesses* live in `skills/clankshop/scripts/tests/` (precedent:
  `skills/chiropractor/scripts/tests/`); fixture *instances* are created and destroyed in temp
  dirs at run time.
- **Additive before subtractive.** A capability moves by landing its new home first and retiring
  the old one in a later task or phase — at every commit the installed skill set remains operable
  (e.g. clankshop `setup` works before foreman's is removed; the doctrine carries the record
  schema before `TAXONOMY.md` is reduced). A task may land as several pathspec-scoped commits —
  one per independently verifiable step.
- **Ratified decisions (owner, 2026-08-07, post-review):** (1) the mid-rollout window is
  **accepted** — a Phase-1 `setup` before Phases 2–3 conform is a known pre-release state; no
  publication gate, no cutover commit. (2) Helpers take **stale-path fixes + the `version:`
  frontmatter key** — pack §8's "untouched" means no re-framing and no independence-machinery
  changes, not frozen bytes. (3) The doctrine diff's base store is the **versioned base archive**
  (Appendix J). (4) Lock semantics: **implicit core pinning by `pack-version:` + helper
  `version:` ranges** (Appendix I, superpowers precedent). (5) **Phase-0 gate freezes ratified
  as written (owner, 2026-08-07):** Appendix K's improvement-item + claim-marker encodings,
  Appendix J's path-qualified whole-file origin IDs, Appendix L's collision + finding-key
  grammar — no amendments.
- **The vocabulary table (pack §2) is binding** for every line of prose written: the mirror is
  never "the tracker"; ticket promotion is never "upstream contribution"; backlog is the skill,
  the trackers are the files.
- **No legacy formats, no vendor mechanisms.** `migrate` is generic discovery + judgment — never
  enumerate old formats. Aliases are proxy *skills*; nothing writes `.claude/commands/` or any
  harness-specific surface.
- **Lint traps:** `skills-lint.sh` hard-fails on any `skills/*/` directory lacking `SKILL.md`
  (line 65) — Phase 0's scaffold therefore includes clankshop's real `SKILL.md` from the first
  commit. It also **warns on any skill dir not mentioned in `README.md`'s skill inventory**
  (line 132) — every skill-creation task adds the README inventory line in the same commit.
  Backticked references to a not-yet-existing sibling (doctrine naming `/guardian` in Phase 0) may
  add warns: each phase gate records such understood warns, and they must clear by the gate of
  the phase that creates the sibling.
- **Installer trap:** `install.sh` resolves a pack by `sed -n 's/^skills:[[:space:]]*//p'` over
  `packs/<name>.md` (line 27) — extra frontmatter keys are ignored, so the pack lock can live in
  that file's frontmatter; but a skill named on the `skills:` line must exist on disk, so new
  members join the line **only in the task that builds them**.
- Cited line numbers are pre-plan snapshots; locate every edit by quoted content.

---

## Phase 0 — pack skeleton, frozen contracts, checked migration manifest

Everything in Phase 0 is **additive**: new files under `skills/clankshop/`, one frontmatter
extension, one new companion doc. No existing skill's behavior changes.

### Task 0.1: Scaffold `skills/clankshop/` with its real SKILL.md

**Files:** Create `skills/clankshop/SKILL.md`; modify `README.md` (inventory line).

- [x] Write the frontmatter: `name: clankshop`; a self-scoping `description:` (≤750 chars to stay
  under the lint WARN) covering the pack face — the pack's doctrine + runbook home, and the three
  system verbs (`setup` greenfield bootstrap, `migrate` brownfield onramp, `check` whole-system
  assembly validation), trigger phrases "set up the project", "migrate this repo onto the
  framework", "check the system".
- [x] Body: the pack-face overview (pack §3), the four-tier roster table (pack §2), the asset map
  (doctrine at `doctrine/`, runbook at `docs/RUNBOOK.md`, lock at `packs/clankshop.md`), and a
  verb table whose rows note **"lands in Phase 1 of the rollout plan"** until they do — an honest
  status, updated by Task 1.3–1.5.
  (`packs/clankshop.md`'s `skills:`/`core:` lines are NOT touched here — Task 0.6 is the lock's
  single writer.)
- [x] Add `clankshop` to `README.md`'s skill inventory (backticked name) in the same commit — the
  lint warns on any skill dir absent from it.
- [x] Verify: `bash skills/skill-builder/scripts/skills-lint.sh .` → `fails=0` (the new dir now
  has a SKILL.md; description-length within bounds). Commit scoped to `skills/clankshop/` +
  `README.md`.

### Task 0.2: Author the doctrine — rules chapters + the canonical record schema

**Files:** Create `skills/clankshop/doctrine/rules/{ROUTING,GOTCHAS,INVARIANTS,POLICY,RECORDS}.md`.

Every doctrine file is written in the spine format (Appendix A): declaration block first, entries
in the declared shape. The doctrine's source ID is `clankshop`, version `v1`; **every seedable
entry carries an origin ID** (`clankshop:INV-n` etc.) per Appendix J — the provenance the
projection protocol stamps at seeding.

- [x] `INVARIANTS.md` — only universal load-bearing rules, parameterized (slots for gate command,
  trunk name), each one line per Appendix A's entry shape. Seed source: the durable rules currently
  in `skills/foreman/BOOTSTRAP.md` and foreman's doc set — copy judgment, not prose.
- [x] `GOTCHAS.md` — format header + declaration, no seed entries (traps are project-specific).
- [x] `POLICY.md` — declaration + empty (judgments accrue per project).
- [x] `ROUTING.md` — the skeleton classification walk (≈25-line budget, Appendix A): patch-vs-
  feature line, spike handling, bug-vs-known-gotcha check, the promotion bar at dispatch
  (Appendix D), dispatch rows with parameter slots.
- [x] `RECORDS.md` — **complete** (formats are not project-variable): the canonical record schema
  absorbed from `skills/backlog/docs/TAXONOMY.md` — the five capture kinds and classifiers, the
  typed-ID namespace and per-store wire formats (Appendix B), the done-log line (Appendix C), the
  ticket schema + escalation layer (Appendix D), the report wire contract (Appendix L). The
  note-kind classifier is written against the **INVARIANTS bar** (mechanics §9), not MEMORY.md.
- [x] Verify: each file's declaration block parses per Appendix A syntax (first HTML comment,
  `spine-doc v1`, required keys); grep each frozen format against the Appendix text — no
  divergence. Commit.

### Task 0.3: Author the doctrine — workflows + testing chapters

**Files:** Create `skills/clankshop/doctrine/workflows/{patch,bug,feature,spike}.md`,
`skills/clankshop/doctrine/testing/{GATE,PIPELINE,DIAGNOSTICS}.md`.

- [x] Each lane file per mechanics §2's lane shape: purpose line, *enter-from*, project-policy ID
  citations (parameter slots), seam glue naming the pack's skills **directly** (pack §4 makes this
  legal: "defect → `/debugger`", "human call → `/backlog promote`"), and the co-equal **by-hand
  walk** with a done-when block. ≤60 lines each.
- [x] `testing/` seeds for guardian's chapter — all three docs pack §4.4 names: `GATE.md` (gate
  definition skeleton with command slots), `PIPELINE.md` (the CI/CD pipeline doc skeleton),
  `DIAGNOSTICS.md` (playbook skeleton: symptom → first moves, seeded from debugger's discipline
  headings).
- [x] Verify: lane files within budget; every skill named in seam glue exists or is scheduled
  (guardian/calibrator references acceptable — recorded as phase-baseline warns per the Gate;
  the ratified mid-rollout window covers any pre-release deploy). Commit.

### Task 0.4: Doctrine index, chapter registry, roster, door profile

**Files:** Create `skills/clankshop/doctrine/README.md`, `skills/clankshop/doctrine/BASES.md`.

- [x] The doctrine's own index: a `spine-index v1` block (Appendix A) listing member docs; the
  **chapter registry** (`rules/`, `workflows/`, `design/`, `testing/` — plus the protocol for a
  role adding a chapter: a stewardship-map row + registry row, per Appendix G); the **team
  roster** (pack §2's table verbatim); and the **door profile** — the compiled tier-0 table's row
  seeds (intent → owning skill entry point), the single shared fallback line →
  `rules/ROUTING.md` (mechanics §2's fallback contract), and the **frozen per-member
  registration block bodies** (Appendix G's door-block protocol — what setup and every domain
  self-init write from).
- [x] Create `doctrine/BASES.md` — the ratified base archive (Appendix J): the frozen entry
  grammar in its header, **empty of bases at v1** (v1 bodies are the live doctrine). The header
  and `doctrine/README.md` state the bump procedure: before any doctrine version bump, every
  changed or retired entry's prior body is appended here **plus the bump record naming those
  origins** (Appendix J's coverage metadata) — a bump-record origin with no body block, or a
  provenance stamp citing an `origin@version` with no retrievable base, is a `check` fact
  (Task 1.5).
- [x] Verify: registry names exactly the four chapters; door rows dispatch only to pack-member
  entry points. Commit.

### Task 0.5: Author the runbook

**Files:** Create `skills/clankshop/docs/RUNBOOK.md`.

- [x] The methodology narrative (pack §3.2), superpowers-style: the flow of a change end to end
  (capture → route → lane → gate → land → done-log), **when to assume which role**, how doctrine /
  handbook / runbook relate (three altitudes), the escalation story (promotion bar → ticket →
  answer/resume), and the improvement loop (calibrator intake → routed items → drained). Seed
  narrative from `packs/clankshop.md`'s prose where it survives — copy now; the old file retires
  in Phase 4 (Task 4.4), not here.
- [x] Verify: no seam tables (those retire with the independence machinery — the runbook narrates,
  the door routes); vocabulary-table conformance grep (`grep -n 'the tracker' …` finds no mirror
  references). Commit.

### Task 0.6: The pack lock

**Files:** Modify `packs/clankshop.md` (frontmatter only).

- [x] Extend the frontmatter per Appendix I: add `pack-version: 1`, `layout: 1`, `core:` (the core
  members **existing at this commit**: `clankshop architect auditor backlog chiropractor debugger
  feature foreman workstream`), `helpers:` (`delegate mailbox handoff` — **bare-listed, presence
  semantics**; the `>=1` ranges land together with the helpers' `version:` keys in Task 3.3, per
  Appendix I's rule that a declared range requires the key), `optional:` (empty for now — alias
  proxies join in Task 2.4). Add `clankshop` to
  the `skills:` install line. `guardian` and `calibrator` join `skills:`/`core:` in Tasks 2.6/2.11.
- [x] Verify — **non-mutating** (`install.sh` has no dry-run mode and creates real links when
  invoked): loop the frontmatter's `skills:` line and `test -d skills/<name>` for each member;
  never run the installer as a check before Task 1.7 lands the transactional preflight. Body
  prose untouched (Phase 4's job). Commit.

### Task 0.7: The checked migration manifest

**Files:** Create `docs/design/2026-08-06-clankshop-pack-manifest.md`.

The search-derived, item-checked inventory of every live surface this restructure touches
(pack §8 Phase 0). Build it **from grep evidence, not recall**:

- [x] Sweep the library for each term-family and record every hit as a manifest row
  (`surface → disposition → receiving task → [ ]`): `\.agents/foreman`, `MEMORY\.md`, `BOOTSTRAP`,
  `TAXONOMY`, `derive-seams`, `check-projection`, `packs/clankshop`, `calibrate`, `done-record`,
  `design-draft`, `\.records/archive`, `foreman (setup|init|migrate|check)`, `tracker-entry`,
  `<!-- edges:`, `typed[- ]edge`, `open vocabulary`, `Edges:` (route-block lines the
  independence-era writers emit), `PLANNING\.md`, `ROUTING\.md`, `records-root`, `doc-linter`
  (mechanics §11 names its store list + `id:` schema as a conforming edit — locate the linter by
  this sweep).
- [x] Seed rows known today (verify each by grep, then keep): the `install.sh` ↔ `packs/clankshop.md`
  manifest seam (lock format landed in 0.6; transactional install Task 1.7; body absorption Task
  4.4); the live backlog surface — **re-framing edits only, no rename** (route blocks, templates,
  docs describing "the capture bureau"); foreman's setup/migrate/check verb files + `foreman-
  health.sh` split (assembler checks → clankshop Task 1.5/2.5; `derive-seams` retires Task 4.3);
  the **done-record template re-home** `skills/foreman/templates/done-record.md` →
  `skills/backlog/templates/` (Task 2.1); the **skill-builder doctrine/gate split** (core-member
  exemption keyed to the lock's `core:` line, Task 4.1); `skills/backlog/docs/TAXONOMY.md`
  absorption (doctrine is canonical from Task 0.2; file reduced Task 2.4); the **steward-grammar
  surfaces built 2026-07-28** — `skills/chiropractor/SKILL.md`'s Calibrate section,
  `skills/architect/verbs/calibrate.md` + its Verbs-table/description/edges rows,
  `skills/foreman/verbs/calibrate.md`, the `packs/clankshop.md` drain seam rows — all dissolved
  into the calibrator (Tasks 2.5/2.8/2.9/2.11); grimoire's `README.md` *Storage convention* +
  `AGENTS.md` steward-inventory paragraph (library doctrine prose, Task 4.4); superseded design
  docs needing status lines (Task 4.5); `skills/foreman/docs/{ROUTING,PLANNING,WORKTREES,
  MAINTENANCE}.md` — the workflow-stage doc set the spine replaces — retired after absorption
  (Task 2.5); `skills/foreman/templates/report.md` dissolved into the report writers' bundled
  templates (Tasks 2.7/2.8); `skills/backlog/scripts/{scaffold-records,backlog-health}.sh` —
  both hardcode the old flat store paths (Task 2.1); prose references to "the doc-linter" — **no
  linter implementation exists in this library** (verified at review) — re-pointed to the
  deployed check chain (Task 2.4); workstream's old-layout hits across `SKILL.md`,
  `verbs/close.md`, `flow.md`, and templates, not just `ship.md` (Task 3.2); handoff's two stale
  paths, ratified in scope (Task 3.3).
- [x] Every row names exactly one disposition and one **receiving task** — the manifest is the
  authoritative enumeration (later tasks execute *their* manifest rows, so a surface with no task
  is a plan bug surfaced here); anything unclassifiable is listed under a *triage* heading for
  the human, never guessed.
- [x] Verify: re-run each sweep grep — every hit appears in exactly one row. Commit.

### Task 0.8: Phase 0 gate

- [x] `bash skills/skill-builder/scripts/skills-lint.sh .` → `fails=0`; record the new warn count
  and attribute every delta to an understood cause (README inventory satisfied in 0.1, so the
  expected deltas are only forward references to `/guardian`/`/calibrator` in doctrine prose —
  recorded here, cleared by the Phase 2 gate).
  **Recorded (2026-08-07, gate run at `366a5d6`): `fails=0 warns=15` — baseline 11 plus exactly
  four understood deltas, all `clankshop: references /X which is not a skill in this suite`
  forward references to scheduled members: `/guardian` (Task 2.6), `/calibrator` (Task 2.11),
  `/bug` and `/task` (Task 2.4) — each must clear by the Phase 2 gate.**
- [x] **Human ratification gate** — the complete pending-freeze list, kept in sync with the
  appendices' flags: Appendix K's `T-`/`improve:`/`source:` improvement-item encoding **and its
  tracker claim-marker encoding** (`[⇢ dispatched <date>]` / `dispatched:`), Appendix J's
  path-qualified whole-file origin IDs, Appendix L's report-ID collision suffix rule **and its
  keyed-heading / `processed:`-list grammar**. Phase 1 does not begin until each is ratified or
  amended; on amendment, re-run the conformance pass below.
  **RATIFIED (owner, 2026-08-07): all three bundles ratified as written — no amendments; the
  conformance pass below stands. Phase 1 is unblocked.**
- [x] Doctrine-vs-Appendix conformance pass: each frozen format cited by a doctrine file matches
  the Appendix byte-for-byte where the Appendix states exact syntax.
- [x] Working tree clean; every Phase 0 commit scoped.

---

## Phase 1 — clankshop the skill

The executable face: verbs, scripts, projection machinery, transactional install, onramp fixtures.
Order is dependency order: parsers → block/stamp lib → verbs → differ → installer → fixtures.
Tasks 1.3/1.4 land verb prose whose executable verification is deliberately the Task 1.8 harness
(a verb doc has no unit test without a fixture) — the phase is complete only when 1.8 is green.

### Task 1.1: The spine parser and project-facts scripts

**Files:** Create `skills/clankshop/scripts/spine-parse.sh`,
`skills/clankshop/scripts/interrogate.sh`.

- [x] `spine-parse.sh` — parse a declaration block / spine-index per Appendix A (emit
  `key=value` facts; `malformed=…` / `unknown-version=…` as facts, never guesses). This is the
  **shared parser** pack §4.6 allows: chiropractor consumes it from Task 2.8 on.
- [x] `interrogate.sh` — facts by script (mechanics §8 setup): gate commands (from package
  manifests), trunk name, remote + issue-system presence, `.gitmodules` inventory, doc landmarks.
  Facts only; every decision stays in the verb interview.
- [x] Verify: shellcheck-clean at the lint gate's severity; unit exercise against a temp fixture
  dir (a minimal declaration block round-trips). Commit.

### Task 1.2: Installation-block library and the resolver walk

**Files:** Create `skills/clankshop/scripts/install-block.sh`.

- [x] Read/write/validate the installation block per Appendix F (deterministic content; idempotent
  create-or-adopt; malformed/duplicate = fact + treat root as unstamped).
- [x] The **resolver walk** (mechanics §7): filesystem walk up from the session path; at each
  unstamped repo root, `git rev-parse --show-superproject-working-tree` continues across the repo
  boundary; nearest stamped door wins; none found → `unmanaged` fact. Emits the chosen root; all
  other machinery takes it as an explicit parameter.
- [x] Verify: temp-fixture cases — stamped root, unstamped root, nested submodule, worktree
  (terminates at its own root). Commit.

### Task 1.3: `setup` — greenfield bootstrap

**Files:** Create `skills/clankshop/verbs/setup.md`; modify `skills/clankshop/SKILL.md` (verb
table row goes live).

- [x] The verb: interrogate (script) → interview (only genuine decisions: lanes, submodule
  opt-ins, mirror on/off) → **project the doctrine through the facts** into `AGENTS.md` +
  `.handbook/` + `.records/` — minimal-seed filtering (universal invariants deploy; the rest stays
  upstream), parameter slots filled, **every seeded entry provenance-stamped** (Appendix J
  encodings) — → write the installation block (`pack:`/`pack-version:`/`layout:`), the compiled
  tier-0 table + fallback line, the two-region stewardship maps (Appendix G), **each installed
  member's `skill:*` door registration block** (created-or-adopted, stamped per Appendix G —
  without this, Task 1.5's `unregistered` fact can never be empty on a fresh setup), and the
  submodule index when `.gitmodules` exists.
- [x] Verify: deferred to Task 1.8's fixture (the verb is prose; the fixture proves it). Lint.
  Commit.

### Task 1.4: `migrate` — the brownfield onramp

**Files:** Create `skills/clankshop/verbs/migrate.md`,
`skills/clankshop/scripts/migrate-preflight.sh` (the precondition-facts producer named below);
SKILL.md row live.

- [x] Format-agnostic per mechanics §8: preconditions (clean tree; **no active workstreams —
  worktree or in-place**, a linked-worktree check alone being insufficient since workstream
  supports in-place streams; whole-installation duplicate-ID scan; unclassifiable-artifact
  triage). The migrate **preflight script emits these precondition facts itself**: clean-tree and
  linked-worktree facts (absorbing what foreman-health `inventory`'s `tree_quiet` /
  `linked_worktrees` supply today — Task 2.5's transfer table), plus active in-place streams read
  from workstream's stream registry → generic inventory →
  content classification into the taxonomy → **one confirmed mapping table** (every artifact in
  exactly one row) → execution in a worktree with rollback → alias preservation
  (`(alias <old>)`, citations rewritten, alias map in the migration's done-record) → nothing-
  dropped check → stamp. A declared `records-root` is respected in place — same walk, no bulk
  `git-mv`.
- [x] Verify: fixture in Task 1.8. Lint. Commit.

### Task 1.5: `check` — whole-system assembly validation

**Files:** Create `skills/clankshop/verbs/check.md`, `skills/clankshop/scripts/check-facts.sh`;
SKILL.md row live.

- [x] Script emits the **assembly facts** (pack §3.3, exactly the clankshop side of the §4.6
  partition): installation-block validity; every stamped projection vs its named input (door
  table ↔ `rules/ROUTING.md`, stewardship-map blocks, submodule index vs `.gitmodules` +
  gitlinks, `RECORDS.md` ↔ doctrine schema version); **chapter presence** vs the registry;
  **cross-store foreign-key integrity** — origin validation is **lifecycle-aware** (a completed
  origin is removed from its flat tracker by Appendix C, so "origin → live entry" would go red
  on every resolved promoted ticket): `open`/`answered` → a live **paused** origin entry;
  `resolved`/`wontfix` → a done-log line carrying the origin ID whose gist cites the `TK-`;
  `demoted` → a live **unpaused** origin; a resolved **direct** ticket → its `TK-` done-log
  line. Done-log consistency **prefix-aware per Appendix C** — a flat-tracker ID absent from
  its live file, a store-dir ID carrying resolved status, a `TK-` ID resolving to a resolved
  ticket; `blocking:` cycles; **ID-rule facts** beyond
  duplicates: ticket filename ↔ derived-ID agreement, cross-installation citations are `TK-`
  only; **lane-vs-installed-skill coverage** (each lane's by-hand walk vs the skill coverage that
  claims it — mechanics §2's rot check); mirror drift incl. unanswered-age; seat inventory; pack
  lock vs installed set; duplicate-ID scan (archives included); stale `design/draft/` content;
  **door-registration facts** — unregistered installed skills, orphaned registration blocks,
  stale registration stamps, and **routing-target resolution** (every `/skill` token in the
  door's table rows resolves to an installed skill or a by-hand lane path — absorbing live
  `check-projection`'s complete fact set, `routing-targets` included; a bad-target corruption
  fixture asserts the red fact); **missing-base facts** (a provenance stamp citing an `origin@version` with no
  retrievable base in the doctrine or `BASES.md`).
- [x] Document-shape facts (entry conformance, citation resolution, budgets) are **not** here —
  they are chiropractor's (§4.6); the verb prose states the partition.
- [x] Verify: fixture in Task 1.8 asserts check-green on a fresh setup and specific red facts on
  seeded corruptions (a dangling ticket origin, a stale stewardship stamp). Lint. Commit.

### Task 1.6: The doctrine three-way differ

**Files:** Create `skills/clankshop/scripts/doctrine-diff.sh`.

- [x] Per Appendix J: for every provenance-stamped handbook entry, retrieve the base per the
  ratified retrieval rule (the oldest qualifying `BASES.md` block, else the live entry —
  Appendix J states it exactly; this task implements, never restates), three-way classify into
  the
  six states (*unchanged / locally edited / upstream updated / conflict / locally deleted /
  upstream retired*), emit facts only. The calibrator (Task 2.11) owns the offer/apply judgment.
- [x] Verify: six micro-fixtures, one per state, in `scripts/tests/`; a prior-version retrieval
  case (the base comes from `BASES.md`, not the live doctrine); and a fresh-seed *unchanged*
  case per entry shape — INV line, heading entry, lane file, testing file — proving the
  normalization (Appendix J's canonical comparison input); the unrelated-bump case — an
  untouched v1 entry still retrieves its correct base (the live body) after a v2 bump that
  changed a *different* entry; and the corruption case — a changed origin whose body block was
  removed from `BASES.md` fires the missing-base fact via its bump record, never a silent live
  fallback. Commit.

### Task 1.7: Transactional install against the lock

**Files:** Modify `install.sh`.

- [x] `--pack` preflights the member set against the lock: every member on the `skills:` line
  present on disk; no destination collision; helper checks per Appendix I — a bare-listed helper
  is a presence check, a range-declared helper must have a `version:` key within range (missing
  or malformed → **abort**, never a silent pass); any failure → abort with
  the fact, **no partial install**; on mid-flight error, roll back what this run linked. Bare
  single-skill install is untouched.
- [x] Verify: temp-destination runs — full pack installs; a seeded collision aborts cleanly
  leaving the destination unchanged; an out-of-range range-declared helper aborts; a version-less
  **range-declared** helper aborts; a version-less **bare-listed** helper installs with the
  presence-check fact. Commit.

### Task 1.8: Onramp fixtures

**Files:** Create `skills/clankshop/scripts/tests/run.sh` (+ fixture builders under
`scripts/tests/`).

- [x] **Greenfield fixture:** temp git repo → walk `setup`'s projection mechanically (the
  scriptable core: doctrine → handbook copy with stamps + block writes) → assert: `check-facts.sh`
  green; every seeded entry carries its provenance marker; `AGENTS.md` table rows resolve; every
  installed member has its door registration block (the `unregistered` fact is empty);
  cold-clone readable (no skill path referenced from `.handbook/`).
- [x] **Migrate fixture:** temp repo with ad-hoc content (a stray TODO list, a rules file, an old
  decisions doc) → classification produces a complete mapping table → post-execution
  nothing-dropped + check-green + aliases preserved.
- [x] **Unstamped-refusal fixture:** framework scripts on an unstamped root emit `unstamped` and
  stop.
- [x] Verify: `bash skills/clankshop/scripts/tests/run.sh` → all green. Commit.

### Task 1.9: Phase 1 gate

- [x] Lint `fails=0`; tests green; SKILL.md verb table fully live (no "lands in Phase 1" rows
  remain). *(Gate run 2026-08-07: `fails=0 warns=15` — the recorded Phase-0 baseline, 4 forward
  references included; `scripts/tests/run.sh` all green.)*
- [x] **Routing probe** (descriptions-only fixture of every `skills/*/SKILL.md` + fresh subagent,
  one pick each): "set up the project on the framework" → `clankshop`; "migrate this repo onto the
  framework" → `clankshop`; "check the whole system" → `clankshop`; "where do I start a change" →
  `foreman`. A mis-route fails the gate; fix is sharper self-scoping in the offending description,
  then re-probe. *(Probed 2026-08-07: 4/4 correct on the first pass.)*

---

## Phase 2 — roles and instruments

Dependency order: backlog (the stores everyone writes) → foreman slim → guardian → debugger →
chiropractor → architect/auditor → **calibrator last** (it consumes every other member's outputs)
→ the phase sweep.

### Task 2.1: Backlog — stores, IDs, `done`

**Files:** Modify `skills/backlog/SKILL.md`, capture verb files,
`skills/backlog/scripts/{scaffold-records,backlog-health}.sh`; create
`skills/backlog/verbs/done.md`; **copy** `skills/foreman/templates/done-record.md` →
`skills/backlog/templates/done-record.md`.

- [x] Tracker paths → `.records/trackers/` (`tasks.md`, `issues.md`, `feedback.md`, `bugs/`,
  `notes/`); wire formats per Appendix B; store-dir frontmatter gains `id:`.
- [x] **ID allocation discipline:** counter IDs allocated only on the trunk checkout
  (pathspec-scoped commit); branch-side capture takes a slug placeholder; `curate` stamps the real
  ID at landing (Appendix B).
- [x] **`done <id>`** — the canonical completion verb: mutate the entry **per Appendix C's
  completion table** (flat entries removed, the log line their archive; store-dir status
  advanced; an absent/completed/paused ID refuses with a fact), append the done-log line, per
  the writer map (Appendix C). Done-record template **copied**
  to backlog (the `done/` steward); the foreman copy **stays until Task 3.2** — live
  `workstream/verbs/ship.md:107` still references it, so deleting it here breaks workstream for
  a phase.
- [x] Rewrite `scaffold-records.sh` and `backlog-health.sh` to the `.records/trackers/` paths
  and the ID-aware entry shapes (both hardcode the old flat stores today); `backlog-health.sh`
  additionally absorbs the tracker-size facts foreman-health `inventory` supplies today (the
  destination Task 2.5's transfer table names — landed and tested here, before 2.5 removes the
  source).
- [x] **`init` (lazy):** each capture verb calls it on an unstamped root — creates the
  `.records/trackers/` skeleton + creates-or-adopts the installation block, idempotently, touching
  no `.handbook/` chapter (Appendix H). Its door registration is rewritten to the **pack-style
  block** (doctrine body, `clankshop@<pack-version>` stamp, no `Edges:` — Appendix G's door-block
  protocol; today it writes a path-SHA/`Edges:` block, `verbs/init.md:69`).
- [x] Verify: Appendix C's removal-span fixtures (last-in-a-non-final-category, middle entry,
  EOF — the category-header-preservation cases); manifest rows for these surfaces checked off;
  lint. Commit.

### Task 2.2: Backlog — the escalation family

**Files:** Create `skills/backlog/verbs/{ticket,promote,close}.md`,
`skills/backlog/templates/ticket.md`; modify `curate` verb file.

- [x] `ticket` (direct capture-plus-escalation; `origin:` absent by rule), `promote` (entry →
  ticket: `origin:` stamped, pause marker written — **a trunk-side scoped commit**, Appendix D),
  `close` (resolve / wontfix / demote per the transition table, with writebacks and done-log
  lines). Ticket file + ID per Appendix D; pause encodings per store shape; the promotion bar
  (Appendix D) cited, not restated.
- [x] `curate` extensions: ID stamping, duplicate-ID repair with aliases, stale-`open`/unanswered
  ages, aging resolved tickets → `tickets/archive/`.
- [x] Verify: temp-fixture walk of promote → pause visible → close → un-pause + done-log line;
  a same-day re-promotion mints the suffixed ticket (Appendix B's collision rule); the
  lifecycle-aware origin facts stay green through resolution — a resolved **promoted** ticket
  (flat origin and store-dir origin) and a resolved **direct** ticket each validate per Task
  1.5's lifecycle table; lint. Commit.

### Task 2.3: Backlog — the mirror

**Files:** Create `skills/backlog/verbs/sync.md`, `skills/backlog/scripts/mirror-sync.sh`;
fixture additions under `skills/clankshop/scripts/tests/` (the failure matrix runs where the
integrated fixtures live).

- [x] Per Appendix E: canonical-projection hash (mirror block + `updated:` excluded), push on
  hash-change only, **full-inventory pull** keyed by immutable remote comment ID,
  edited/deleted-comment drift facts (file wins), idempotent creation via label scan +
  lowest-issue-number adoption, the `mkdir` lock (10-minute staleness, takeover logged),
  trunk-only sync, verb-time-only trigger, no-remote degradation (no `mirror:` block, no behavior
  change).
- [x] Failure-matrix fixtures (mechanics §6): duplicate retry; crash between create and commit;
  worktree-sync refusal; mid-sync comment; edited + deleted comment drift; concurrent-sync lock
  contention; duplicate stamped-issue adoption. Mock the provider with a local fixture script —
  no live GitHub in the gate.
- [x] Verify: matrix green; lint. Commit.

### Task 2.4: Backlog — re-framing, `RECORDS.md` projection, aliases

**Files:** Modify `skills/backlog/SKILL.md`, `skills/backlog/docs/TAXONOMY.md`,
`verbs/{note,debrief}.md`; create `skills/backlog/scripts/records-projection.sh`,
`skills/bug/SKILL.md`, `skills/task/SKILL.md`; modify `packs/clankshop.md`
(frontmatter `optional:` + `skills:`), `README.md` (inventory lines for `bug`/`task`),
`skills/clankshop/verbs/setup.md` (route its `RECORDS.md` step through the projection writer).

- [x] Re-frame prose to the **instrument contract** (pack §4.3): tool-like capture/books-keeping;
  judgment about signal meaning belongs to the calibrator. No rename anywhere.
- [x] `rules/RECORDS.md` **projection writer**: backlog writes the deployed projection of the
  doctrine schema, stamped `built-against: clankshop-doctrine@<doctrine-version>` (Appendix A's
  `doctrine-version:` key is the input); drift is a clankshop-check fact (already in Task 1.5).
  **Wire the authority chain:** `skills/clankshop/verbs/setup.md` (Task 1.3) is amended to invoke
  `records-projection.sh` for its `RECORDS.md` step — backlog stays the sole schema-facing writer
  (pack §7.6), and a fixture asserts it (no other writer produces the file's stamp).
- [x] `TAXONOMY.md` reduced to a pointer at the doctrine's canonical schema (§7.6's authority
  chain: doctrine → backlog executes → RECORDS.md projects; nothing else states the schema).
  `note`/`debrief` classifier retargeted to the INVARIANTS bar.
- [x] **Proxy alias skills** `bug` and `task`: one-line SKILL.md each, invoking `/backlog bug` /
  `/backlog task`; join the lock's `optional:` + `skills:` lines and `README.md`'s skill
  inventory in the same commit.
- [x] Re-point prose references to "the doc-linter" (TAXONOMY, verb files, ship-adjacent docs) at
  the deployed check chain (clankshop check / chiropractor facts) — no doc-linter implementation
  exists in this library (verified at review); the schema authority is the doctrine.
- [x] **Unstamped conduct, verb-by-verb** (the backlog matrix Appendix H's catch-all implies):
  the five capture verbs lazily `init` (Appendix H's writer row); every other backlog verb —
  `ticket`, `promote`, `sync`, `close`, `done`, `curate`, `debrief` — refuses on an unstamped
  root: emit `unstamped`, point at the onramps. Task 5.3 exercises each of these by name.
- [x] Verify: routing probe spot-check — "file a bug" routes to `bug`/`backlog` cleanly; lint
  (two new skill dirs pass); manifest rows checked. Commit.

### Task 2.5: Foreman — slim to routing + rulebook

**Files:** Delete `skills/foreman/verbs/{setup,migrate,check}.md` (and the `init` alias surface;
`verbs/calibrate.md` is deleted in Task 2.11, when its successor exists); modify
`skills/foreman/SKILL.md`, `skills/foreman/verbs/route.md` (a live consumer of the old deployed
doc layout — `.agents/foreman/docs/ROUTING.md` at lines 4/18 — re-pointed to
`.handbook/rules/ROUTING.md`), `skills/foreman/scripts/foreman-health.sh`,
`skills/foreman/BOOTSTRAP.md` (retire — content absorbed by doctrine in Phase 0).

- [x] Foreman keeps **`route` only** + rulebook stewardship: `rules/` + `workflows/` chapters,
  `.records/logs/` run log, ROUTING.md maintenance + table recompile on change, the promotion bar
  at dispatch (hand-off to `/backlog promote`). `/foreman init` removed (pack §3.4); on an
  unstamped root, foreman is read-only: emit `unstamped`, point at the clankshop onramps.
- [x] `foreman-health.sh` — **all five subcommands dispositioned** (verified inventory:
  `inventory`, `stale-refs`, `coverage`, `derive-seams`, `check-projection`):
  the **fact-by-fact transfer table** (destination lands and is tested before the source
  subcommand is removed, same task): `check-projection`'s facts — unregistered installed skills,
  orphaned registration blocks, stale registration stamps, **and `routing-targets`** (line 339
  at HEAD) — → clankshop `check-facts.sh`
  (landed Task 1.5), removed here; `inventory`'s facts — `tree_quiet`/`linked_worktrees` → the
  migrate preflight (landed Task 1.4) and clankshop check, tracker-size counts →
  `backlog-health.sh` (landed Task 2.1) — removed here; `stale-refs` + `coverage` →
  document-side facts, moved to chiropractor in Task 2.8 (they **stay in foreman-health until
  2.8 deletes them there**); `derive-seams` → stays until Phase 4's retirement task (Task 4.3,
  which runs after 4.4 per that phase's execution order; helpers still carry edges).
- [x] `skills/foreman/docs/{ROUTING,PLANNING,WORKTREES,MAINTENANCE}.md` — the workflow-stage doc
  set the spine replaces: **absorption here, deletion in Phase 4 (Task 4.4).** Diff each against
  the Phase-0
  doctrine chapters and absorb any judgment not yet captured; the files themselves are deleted
  in **Task 4.4**, after every consumer is conformed — `route.md` here, `feature`/`workstream`
  in Phase 3, and the pack body's own references at 4.4's absorption (live consumers verified:
  `route.md:4`, `feature/SKILL.md`, `workstream/flow.md:69`, `packs/clankshop.md:131`).
  `templates/report.md` follows the same split (absorption none needed — its successors are
  Tasks 2.7/2.8's templates; deleted at Task 4.4); `templates/done-record.md` stays until Task
  3.2 (per Task 2.1).
- [x] `BOOTSTRAP.md` deleted; SKILL.md description rewritten (router + rulebook; no setup
  language) — routing probe re-runs at the phase gate.
- [x] Verify: no framework verb regression — "set up" intents now route to clankshop (probe at
  gate); lint; manifest rows checked. Commit.

### Task 2.6: Guardian — the verification role (new build)

**Files:** Create `skills/guardian/SKILL.md`, `skills/guardian/verbs/tend.md` (author/maintain the
`testing/` chapters from the doctrine seed), `skills/guardian/verbs/judge.md` (the
verification-judgment flow); modify `packs/clankshop.md` frontmatter (`skills:` + `core:`),
`README.md` (inventory line).
(The design specifies guardian's scope, not its verb names — these two are this plan's minimal
decomposition; renaming them during build is a task-local call, adding a third is not.)

- [x] The role: tends `.handbook/testing/` (gate definition, CI/CD pipeline doc, diagnostics
  playbook — seeded from the doctrine's `testing/` chapter, Task 0.3); owns verification
  **judgment** (defect vs flaky gate; does this change need a deeper pass; is the playbook
  missing a chapter). No records of its own; no seat; investigations are written by whoever runs
  the debugger. On unstamped roots: read-only, emit the fact.
- [x] Description self-scopes on verification-stewardship intents ("harden the gate", "the CI
  keeps flaking", "we need a diagnostics playbook") — distinct from debugger's
  root-cause-a-defect intents; the phase-gate probe checks the pair.
- [x] Verify: lint (new dir; `README.md` inventory line added in the same commit); lock updated;
  role-contract conformance (tend-don't-own, removable without harm — chapter content never
  names guardian). Commit.

### Task 2.7: Debugger — conform as the diagnostic instrument

**Files:** Modify `skills/debugger/SKILL.md` (+ its verb/reference files per manifest rows).

- [x] Keep the discipline verbatim (reproduce → trace → hypothesize → verify → fix;
  human-confirm-before-edit). Add: findings write `.records/reports/investigation-<date>-<slug>.md`
  per Appendix L; guided by guardian's playbook when present (`.handbook/testing/`); accepts a
  routed report or live symptom, **never enumerates `bugs/`**; a routed report whose linked entry
  is paused → refuse + emit the pause fact (declaration-led, Appendix D); on an unstamped root,
  read-only — emit `unstamped`, point at the onramps (Appendix H). Bundles its report template,
  `skills/debugger/templates/investigation.md` (the Appendix L shape — one of
  `foreman/templates/report.md`'s two successors).
- [x] Verify: lint; instrument-contract framing (operator owns the judgment); manifest rows.
  Commit.

### Task 2.8: Chiropractor — repurpose as the docs-quality role

**Files:** Modify `skills/chiropractor/SKILL.md`, `skills/chiropractor/scripts/spine-scan.sh`,
`skills/foreman/scripts/foreman-health.sh` (delete `stale-refs`/`coverage` as they move here)
(+ rubric/reference files per manifest rows).

- [x] Drop the any-repo genericity mandate: chiropractor knows `.handbook/`, `.records/`, and the
  front door **directly**. Keeps: the three declaration-driven checks (now consuming
  `spine-parse.sh` from Task 1.1), the Entry-Door Audit (framework-aware), the declaration-led
  pause. Its fact set is exactly the *document* side of the §4.6 partition (entry conformance,
  within-scope citation resolution, budgets, link/path health, navigability, read-cost,
  affordance) — the verb prose states the partition against clankshop check.
- [x] `spine-scan.sh`: replace the hardcoded `GLOSSARY.md`/`INDEX.md` candidate lists (the
  "Affordance flags" section — locate by content, the old `:427,429` has drifted) — an ordinary
  path update now, not a doctrine violation. The frozen replacement facts: `has_front_door`
  (`AGENTS.md`/`CLAUDE.md` present), `has_stewardship_map` (`.handbook/README.md` carrying a
  spine-index + steward blocks — reported as a *map*, never labeled an index/TOC), `has_glossary`
  (root or `docs/` `GLOSSARY.md`). Its fixtures update to match.
- [x] Absorb `stale-refs` + `coverage` from `foreman-health.sh` (Task 2.5's disposition) into
  chiropractor's scripts, consuming `spine-parse.sh` — destination tests first, then delete both
  subcommands from `foreman-health.sh` in this same task (no duplicate implementations survive).
- [x] Findings land as `.records/reports/doc-drift-<date>-<slug>.md` per Appendix L. On an
  unstamped root: read-only — emit `unstamped`, point at the onramps (Appendix H). Bundles
  `skills/chiropractor/templates/doc-drift.md` (the Appendix L shape — the other successor of
  `foreman/templates/report.md`).
- [x] The `## Calibrate` section, its description sentence, and the `tracker-entry (optional)`
  consumes line (steward-grammar surfaces; manifest rows) are removed **in Task 2.11's commit**,
  when the calibrator exists — never before (no window with no drain owner).
- [x] Verify: lint; probe spot-check "audit the docs" → chiropractor; manifest rows. Commit.

### Task 2.9: Architect — conforming edits

**Files:** Modify `skills/architect/SKILL.md`, `skills/architect/verbs/reconcile.md`, verb files
per manifest. (`verbs/calibrate.md` is deleted in Task 2.11's commit, when its successor exists.)

- [x] Paths: tends `.handbook/design/` + `.records/design/` (with `design/draft/` transient:
  born at `extract`, consumed by `init` migrate-mode, **archived on consumption** to
  `design/draft/archive/`); role-contract re-framing (direct references legal; tend-don't-own).
- [x] `calibrate`'s dissolution — the verb file, its Verbs-table row, description sentence, edges
  consumes clause, and `distill`'s seam-line revert ("external signal arrives as
  calibrator-routed improvement items") — executes **in Task 2.11's commit**: the calibrator
  must exist first.
- [x] Conform `reconcile`'s report writing (a live third writer into `.records/reports/`,
  `verbs/reconcile.md:107`) to Appendix L: namespace `reconcile-<date>-<slug>.md`, the
  frontmatter floor (`type: reconcile`, `id`, `date`, `source`), the collision rule.
- [x] Unstamped conduct: `init`/`extract` keep their Appendix H writer rows; every other
  architect verb is read-only on an unstamped root — emit `unstamped`, point at the onramps.
  `init`'s door registration rewrites to the pack-style block (Appendix G's door-block
  protocol — no path-SHA stamp, no `Edges:`).
- [x] Verify: lint; manifest rows. Commit.

### Task 2.10: Auditor — conforming edits

**Files:** Modify `skills/auditor/SKILL.md`, `skills/auditor/BOOTSTRAP.md` (+ files per manifest).

- [x] Seat path → `.agents/roles/auditor/` (the one seat that exists); records `.records/audit/`
  (internal `logs/`/`history/` stay store-internal); `deploy` keeps its pre-stamp right (Appendix
  H) and creates-or-adopts the installation block; findings that pass the **system-improvement
  bar** feed the calibrator's intake — ordinary code findings go back to `route` (the verb prose
  states the bar). Non-`deploy` verbs are read-only on an unstamped root (Appendix H).
- [x] The deployed finding shape (BOOTSTRAP/template contract) gains the optional `processed:`
  field — Appendix K's terminal-writeback target for calibrator-accepted findings. `deploy`'s
  door registration rewrites to the pack-style block (Appendix G's door-block protocol).
- [x] Verify: lint; manifest rows. Commit.

### Task 2.11: Calibrator — the improvement loop (new build)

**Files:** Create `skills/calibrator/SKILL.md` (+ verb files: the intake pass, the upstream-
contribution pass); modify `packs/clankshop.md` frontmatter (`skills:` + `core:`), `README.md`
(inventory line); execute the deferred dissolutions — delete `skills/foreman/verbs/calibrate.md`
and `skills/architect/verbs/calibrate.md`, edit architect's SKILL.md rows + `distill` seam line,
remove chiropractor's `## Calibrate` surfaces (per Tasks 2.5/2.8/2.9).

- [x] **Intake:** one pass over the frozen intake table (Appendix K) — the only scanner of those
  sources; paused entries always skipped. Non-tracker findings **materialized** as ID'd
  improvement items (Appendix K's artifact rule) before dispatch.
- [x] **Dispatch:** each item routes to the owning role as ordinary work, applied by that role's
  own expertise; the per-role calibrate verbs no longer exist (2.5/2.8/2.9 removed them).
- [x] **Uptake + closure:** verify the edit landed (chapter changed, check-green), then
  `backlog done <id> --outcome drained`; source stamped (`processed:` for reports **and audit
  findings** — Task 2.10 adds the field to the finding shape); run log →
  `.records/logs/` (typed, beside foreman's).
- [x] **Downstream offer/apply:** for `upstream updated` / `upstream retired` facts from
  `doctrine-diff.sh`, run Appendix J's offer gate; an **accepted** update is dispatched as an
  improvement item to the owning role, which applies it to its own chapter and re-stamps
  provenance (`@vN`) — the calibrator edits no chapter (tend-don't-own, pack §4.7); it verifies
  uptake and closes. This is the receiving half of the loop every *other* project runs when
  doctrine vNext ships (Task 5.4's round-trip fixture exercises it).
- [x] **Dissolve the per-role calibrate family in this commit** (the deferred steps of Tasks
  2.5/2.8/2.9) — the improvement loop has exactly one owner from this commit on, and never zero.
- [x] **Upstream contribution:** consume `doctrine-diff.sh` facts (Task 1.6); assemble evidence
  for a locally-proven rule; prepare the doctrine patch — **a human lands it**; the verb never
  writes the upstream library.
- [x] No seat, no chapters; boundary with backlog `curate` stated (list hygiene is the
  instrument's; signal *meaning* is the calibrator's).
- [x] Verify: lint (`README.md` inventory line in the same commit); lock updated; on an unstamped
  root the calibrator is read-only (Appendix H's final row); a **repeated intake pass dispatches
  nothing already claimed**, and a **concurrent second pass** started mid-claim also dispatches
  nothing (the trunk-side claim commit is the serialization point — Appendix K's claim markers); a **two-finding report** with
  different owners processes one finding without hiding the other (Appendix L's finding keys);
  probe spot-check "calibrate the system" → calibrator. Commit.

### Task 2.12: Phase 2 gate — probe, vocabulary sweep, seam rows

**Files:** Modify `packs/clankshop.md` (the four steward-grammar drain seam rows + the
`tracker-entry` vocabulary row — dissolved per manifest).

- [x] Remove/replace the 2026-07-28 drain seam rows (`backlog ↔ chiropractor`,
  `backlog ↔ architect`, the amended `foreman ↔ chiropractor` / `architect ↔ foreman` cells) with
  the calibrator-loop framing — minimal edits; the body's full absorption is Task 4.4.
- [x] **Routing probe, full set** (pack §10): "file a bug" / "where do I start" / "escalate to the
  human" / "audit the docs" / "audit the code" / "calibrate the system" / "set up the project" —
  descriptions + aliases only, fresh subagent, one pick each. All 7 correct or fix-and-re-probe.
- [x] **Vocabulary sweep** (pack §2 table): grep the pack's prose for the banned usages (mirror
  called "the tracker"; promotion called "upstream contribution"; instrument/role framing) — fix
  every hit.
- [x] Lint `fails=0`; manifest Phase-2 rows all checked (the `templates/report.md` row is
  Task 4.4's by disposition). *(Gate run 2026-08-07: `fails=0 warns=11` — 10 of the pre-phase
  baseline (foreman's description-length warn cleared with the Task 2.5 rewrite; all 4 recorded
  forward-reference warns cleared as required) **plus one recorded delta**: `audit-finding`
  declared by only one skill — foreman's `consumes` dissolved with its calibrate verb in Task
  2.11; clears at the Phase 4 gate when Task 4.2 strips the core edges blocks. Routing probe
  7/7: bug · foreman · backlog · chiropractor · auditor · calibrator · clankshop. Vocabulary
  sweep clean. Fixture suite `scripts/tests/run.sh` all green — 180 asserts across six
  harnesses.)*

---

## Phase 3 — pipelines and helpers conformance

### Task 3.1: Feature — path and seam conformance

**Files:** Modify `skills/feature/SKILL.md` + templates per manifest rows.

- [x] Update every reference to the retired layout (`.agents/foreman/docs/PLANNING.md`,
  `MEMORY.md`, GOTCHAS paths, TAXONOMY as frontmatter authority) to the new homes (handbook
  chapters; the doctrine schema via `rules/RECORDS.md`); planning artifacts still land in
  `.records/plans/` + `.records/adr/` (unchanged). Verbs gain the stamped-only guard (unstamped
  root → onramps, emit the fact, stop).
- [x] Conform feature's `init` verb — the **fourth surviving core route writer** (its SKILL.md
  init section writes a path-SHA `built-against` stamp + an `Edges:` block body today) — to
  Appendix G's door-block protocol: pack-style body from the doctrine's door profile, the stamp
  converted path-SHA → `clankshop@<pack-version>`, no `Edges:` lines.
- [x] Verify: manifest rows; lint. Commit.

### Task 3.2: Workstream — ship seam and archiving

**Files:** Modify `skills/workstream/SKILL.md`, `verbs/ship.md`, `verbs/close.md`, `flow.md`, and
the workstream templates + scripts named by their manifest rows (the sweep found old-layout hits
across all of these, not just `ship.md`); delete `skills/foreman/templates/done-record.md`.

- [x] `ship` calls **`backlog done` per shipped item** *and* writes its own full done-record file
  → `.records/done/` (Appendix C writer map); per-store archiving (`<store>/archive/`, no
  top-level archive); path updates; stamped-only guard.
- [x] Update `ship.md`'s done-record template reference to backlog's copy and **delete
  `skills/foreman/templates/done-record.md`** (the deletion Task 2.1 deferred here).
- [x] Verify: manifest rows; lint. Commit.

### Task 3.3: Helpers — verify untouched

- [x] **Ratified scope:** pack §8's "untouched" means no re-framing and no independence-machinery
  changes; stale-path fixes and the lock's `version:` key are in scope (Global Constraints,
  decision 2).
- [x] `skills/handoff/SKILL.md`, two path edits (locate by content): the durable-record pointer
  `.records/archive/` → `.records/done/` (the "A *durable* record of *finished* work" line), and
  the Pointers row `.agents/foreman/README.md` → `.handbook/README.md`.
- [x] All three helpers gain `version: 1` in SKILL.md frontmatter — the lock's comparison target
  (Appendix I) — and **in the same commit** `packs/clankshop.md`'s `helpers:` line upgrades from
  bare to ranged (`delegate>=1 mailbox>=1 handoff>=1`): the bare→ranged transition Appendix I
  stages, landed atomically so a declared range never exists without its keys. Grep-verify no
  other reference broke, per their manifest rows; nothing else changes.
  **→ Superseded, not landed (2026-08-08, owner-ratified):** the pack-format spec
  (`docs/spec/pack-format.md`, format 1, landed `3877eef`..`06b684c`) eliminates member version
  ranges — members pin by **content hash** in `grimoire.lock` — so the `version:` keys and the
  ranged `helpers:` line would contradict the ratified format. The lock surface migrates
  wholesale to `PACK.md` + `grimoire.lock` as that spec's own implementation work; Appendix I's
  range grammar is superseded with it (bare listing without keys stays the valid state until the
  migration). Helpers stay untouched beyond the two handoff path edits above.
- [x] Verify: lint; helpers' edges blocks intact (they keep the full independence discipline).
  Commit.

### Task 3.4: Phase 3 gate

- [x] Confirm the Phase-3 consumers (`feature`, `workstream`) no longer reference the retired
  foreman doc set — its deletion lands in Task 4.4, after the pack body's own references are
  absorbed (the last consumer standing).
- [x] Lint; fixtures still green (`skills/clankshop/scripts/tests/run.sh`); manifest Phase-3 rows
  checked. *(Gate run 2026-08-08: grep confirms zero `foreman/docs` / `foreman/templates`
  references left in `skills/feature/` + `skills/workstream/` (the doc set itself persists until
  Task 4.4). Lint `fails=0 warns=11` — unchanged baseline, the one recorded delta
  (`audit-finding` single-declarer) still clears at the Phase 4 gate. Fixture suite all green —
  180 asserts across six harnesses. Manifest Phase-3 rows all checked (the helper version-keys
  row resolved as superseded — Task 3.3's supersession note). No routing probe this gate: no
  skill description changed in Phase 3, so the probe surface is identical to the 2.12 run.)*

---

## Phase 4 — retire the independence machinery (core members only)

Execution order within this phase: **4.1 → 4.2 → 4.4 → 4.3 → 4.5** — the pack-body absorption
(4.4) removes the last active `derive-seams` prose references (five body hits in
`skills/clankshop/PACK.md` at post-migration HEAD; outside it, the four `register-route.sh`
comments and the `skills/foreman/SKILL.md` fact-script bullet, all Task 4.3's to rewrite —
re-verified 2026-08-08), so it must precede 4.3's sweep.

> **Migration note (2026-08-08, owner-ratified — re-ground against this before building):** the
> pack manifest migrated to the ratified pack-format spec (`docs/spec/pack-format.md`, format 1)
> ahead of this phase: `packs/clankshop.md` is now **`skills/clankshop/PACK.md`** (frontmatter
> `pack:`/`version: 1.0.0`/`format: 1`/`skills:` (core+helpers folded, face implicit)/`optional:`/
> `setup:`; the body rode along verbatim), the `packs/` shelf is retired, and `install.sh --pack`
> resolves `PACK.md` + writes the sidecar `grimoire.lock`. **`core:` survives in `PACK.md`
> frontmatter as a grimoire author extension key** (spec §2: unknown keys ignored + preserved) —
> Task 4.1 reads it from `skills/clankshop/PACK.md`, not `packs/clankshop.md`. Task 4.4's file
> target is likewise `skills/clankshop/PACK.md`; its "frontmatter (manifest + lock)" phrase now
> means the spec manifest surface (the install lock is the separate `grimoire.lock` sidecar).
> Task 4.3's/4.4's active-surface sweeps drop the `packs/` glob (the dir no longer exists).

### Task 4.1: Skill-builder — the core-member exemption and the doctrine split

**Files:** Modify `skills/skill-builder/scripts/skills-lint.sh`,
`skills/skill-builder/docs/DOCTRINE.md`.

- [x] The lint gate reads the pack lock's `core:` line (`packs/clankshop.md` frontmatter — the
  machine-readable membership rule) and exempts core members from the independence checks **that
  actually exist** (verified at review — edges blocks are already optional, skills-lint.sh:218,
  so there is no "presence" check to exempt): the sibling-name/boundary description warns, the
  edge-block validation + orphan-type pairing, and the sibling verb-roster checks; helpers and
  skill-builder itself keep the full discipline. *(Landed per the Migration note: `core:` is read
  from PACK.md frontmatter via install.sh's discovery walk — `$root/PACK.md` + `skills/*/PACK.md`
  — so a second pack's `core:` composes; checks 7/8/9 gained an `is_core` skip.)*
- [x] `DOCTRINE.md` gains the pack-vs-portable split: the portable authoring rules apply to
  standalone skills and helpers; pack core members follow the pack's authored composition.
  *(New § "Two regimes" after the intro + a scope qualifier on the layer-1 edges requirement.)*
- [x] **Re-baseline the gate:** run lint, record the new `warns=N` in this plan's Gate line
  (edit above), attribute every delta (core boundary warns disappearing; nothing unexplained).
  *(Recorded: `fails=0 warns=10`, sole delta the `audit-finding` orphan — see the Gate line.)*
- [x] Verify: lint on a helper still enforces edges (seed a deliberate violation in a temp copy;
  confirm it fails). Commit. *(Temp fixture: helper with seeded sibling-edge violation →
  `fails=1`; same skill listed `core:` in a fixture PACK.md → `fails=0`. Shellcheck clean.)*

### Task 4.2: Strip core members' typed-edge machinery

**Files:** Modify every core member's `SKILL.md` (edges blocks + edge-referencing prose), per
manifest rows.

- [x] Remove `<!-- edges:… -->` blocks and open-vocabulary matching language from the face, roles,
  instruments, and pipelines — **including core bundled docs and route-writer output**, not just
  SKILL.mds (live examples: `skills/feature/docs/ideal-use.md` teaches typed-edge continuation
  at HEAD; any `Edges:` route-block content a Phase-2 conformance missed); rewrite sibling-blind
  indirections ("the tracker the host's front door names") into direct pack references where the
  manifest flagged them. Helpers untouched. *(Landed: the 8 core SKILL.md `## Edges` sections
  deleted whole — intro prose, block, and trailing edge-teaching paragraphs; the two
  typed-edge-tenet citations in `backlog/verbs/init.md` + `feature/SKILL.md` (init) rewritten as
  plain principles. `ideal-use.md` was already conformed by Task 3.1 — zero hits at HEAD. The
  door-block format's "no `Edges:` lines" prohibitions stay: pinned format language.)*
- [x] Assert: no core **active surface** (SKILL.mds, verb files, bundled docs, script output)
  still teaches edge derivation — the manifest's widened sweep terms are the check.
  **Exclusion (2026-08-08, post-migration):** `skills/clankshop/PACK.md`'s body — moved inside
  `skills/**` by the migration — still carries the pre-absorption pack body; it is Task 4.4's
  target and is excluded from this assert, mirroring 4.3's historical-records exclusion.
  *(Sweep run with two further recorded exclusions: `foreman-health.sh` — 4.3 deletes it — and
  `chiropractor/scripts/spine-scan.sh`, whose "escape-typed edge" is its own link-graph
  terminology, not skill edges. Result: CLEAN.)*
- [x] Verify: lint (post-4.1 gate) `fails=0`; no core SKILL.md contains `<!-- edges:`; manifest
  rows. Commit. *(`fails=0 warns=10`, unchanged from the 4.1 baseline as predicted.)*

### Task 4.3: Retire `derive-seams`

**Files:** Delete `skills/foreman/scripts/foreman-health.sh` (`derive-seams` is its only
remaining subcommand — re-verified 2026-08-08; removing the command would leave an empty shell,
so the file goes with it); modify `skills/foreman/SKILL.md` (the *Scripts compute facts* bullet
names the script and command), and the four `register-route.sh` copies whose comments mention
`derive-seams` (foreman, architect, auditor, feature — line 29 at HEAD; comments only, verified;
the backlog and skill-builder copies are clean).

- [x] Remove `derive-seams` by deleting `foreman-health.sh` outright and rewriting the
  `skills/foreman/SKILL.md` bullet that names it (composition is authored — doctrine + runbook;
  helpers' edges remain as *declarations* validated by the lint gate, but no seam derivation
  runs). *(Script deleted; the *Scripts compute facts* bullet now names only
  `scoped-commit.sh`.)*
- [x] Rewrite the stale comparison comments in the four `register-route.sh` copies (the Files
  list) so the active-surface sweep below can pass. *(All four line-29 comments were
  byte-identical; rewritten to cite lint check 8's parse-anothers-grammar trade instead.
  Shellcheck clean.)*
- [x] Verify, scoped to **active** surfaces only — `skills/**`, `packs/`, `README.md`,
  `AGENTS.md`: no `derive-seams` reference remains. Historical records (`docs/design/*`,
  `docs/BACKLOG.md` — 4 hits verified) legitimately retain the term and are excluded
  (design-docs-are-historical). Lint. Commit. *(Sweep CLEAN — `packs/` glob dropped per the
  Migration note; chiropractor's "absorbed from foreman-health" provenance comments retained
  as historical attribution. Lint `fails=0 warns=10`.)*

### Task 4.4: Absorb `packs/clankshop.md`'s body + library-doctrine surfaces

**Files:** Modify `packs/clankshop.md`, `README.md` (the *Storage convention* section + skill-
inventory framing), `AGENTS.md` (the steward-inventory paragraph — authored library doctrine;
patient-zero forbids registration blocks and deployed-layout content, not doctrine prose).

- [x] Reduce to: the frontmatter (manifest + lock — the machine surface `install.sh` and the lint
  gate read) + a short body pointing at `skills/clankshop/` (SKILL.md, doctrine, runbook). Before
  deleting body content, diff it against the doctrine + runbook: any judgment not yet absorbed
  gets absorbed first (additive before subtractive). *(Diff outcome: the only unabsorbed judgment
  was the "skill-builder deliberately outside the pack" rationale — absorbed into the reduced
  body. Everything else verified absorbed (roster/layout/door/seams/workflows/which-audit/install
  → doctrine + RUNBOOK; roadmap-as-queue-source → workstream SKILL.md; debugger-fix-lands → bug
  lane) or superseded (oven/recipe foreman framing, derive-seams enrichment, typed-edge
  vocabulary, five-section door restatement — mechanics §10's reconciliation governs).
  Frontmatter byte-preserved.)*
- [x] `README.md` + `AGENTS.md`: rewrite the independence-era framing (steward inventory,
  typed-edge references, seam language) to the pack model, per their manifest rows. *(Roster
  tiers replace the steward inventory; Storage convention rewritten to `.handbook`/`.records`/
  `.agents/roles` with the old-layout table dropped in favor of the doctrine pointers;
  patient-zero caveat retargeted to fixtures-in-`scripts/tests/`; `BOOTSTRAP.md` and
  `doc-linter` prose cleared.)*
- [x] With the body absorbed, execute the deferred deletions (Tasks 2.5/3.4's pointers):
  `skills/foreman/docs/{ROUTING,PLANNING,WORKTREES,MAINTENANCE}.md` and
  `skills/foreman/templates/report.md`; then grep-verify zero references across active surfaces
  (`skills/**`, `packs/`, `README.md`, `AGENTS.md`). *(Deleted; sweep CLEAN — `packs/` glob
  dropped per the Migration note.)*
- [x] Verify: `./install.sh --pack clankshop` green; no unique content lost (the diff is the
  check); manifest rows. Commit. *(Green after one surfaced defect was fixed: the migrated
  preflight's collision check compared one `readlink` level, false-positiving on links that
  resolve to the same source through an intermediate symlink chain — now a physical-path compare,
  the same rule skills-lint.sh's wiring check applies. Suite 189 green; lint `fails=0
  warns=10`.)*

### Task 4.5: Superseded design docs — status lines

**Files:** Modify status lines only, per manifest: `docs/design/2026-07-18-skill-self-init-model.md`
and `2026-07-18-skill-boundaries-and-glue-ownership.md` (pack-member provisions superseded; helper
provisions stand), `2026-07-26-front-door-architecture.md` (partial supersession note per
mechanics §10). `2026-07-27-steward-grammar.md` is already marked.

- [x] One status-line sentence each, citing the pack design. No other edits. *(Self-init model +
  boundaries doc: pack-member provisions superseded, helper provisions stand (§ Two regimes
  cited); front-door architecture: partial supersession per mechanics §10, with the read-cost
  tier rules + compiled-table model noted as preserved by construction.)*
- [x] Verify: `git diff` shows status lines only. Commit. *(Diffstat: three files, status-block
  lines only.)*

### Task 4.6: Phase 4 gate

- [x] Lint at the new baseline; routing probe re-run (descriptions changed in 4.2); fixtures
  green; manifest Phase-4 rows checked. *(Gate run 2026-08-08: lint `fails=0 warns=10` — the
  Task-4.1 re-stated baseline, no further delta from 4.2–4.5 as predicted. **No routing probe
  this gate:** `git diff` over the phase confirms zero `description:` changes — 4.2's
  indirection rewrites all landed at body level, so the probe surface is identical to the 2.12
  run (the same justification as the 3.4 gate). Fixture suite all green — 189 asserts across
  six harnesses (doctrine-diff 16, onramp 81, backlog 35, escalation 13, mirror 28, calibrator
  16). Manifest Phase-4 rows all checked. Phase landed as `93a1388` (plan must-fixes),
  `ef1444e` (4.1), `a41d042` (4.2), `9f8743e`+`70b450f` (4.4), `8585617` (4.3), `16095ed`
  (4.5). One surfaced defect fixed in 4.4's verify: install.sh preflight collision false-
  positive on symlink chains. **Post-phase note:** the pack-format spec moved to draft 4
  (`64ca07c`, concurrent owner review — `name:`/`required:` keys, comma-separated lists,
  `setup:` key deleted); the implemented manifest/installer follow ratified draft 3 — draft-4
  conformance is follow-on work outside this plan, pending ratification.)*

---

## Phase 5 — fixture proof

> **Status (2026-08-08): superseded by real-world deployment** — see the close-out status block at
> the top of this plan. Tasks below stay unchecked by design; only Task 5.3's
> registration-stability fixture was pulled forward (`c4c1be6`).

All fixtures run from `skills/clankshop/scripts/tests/run.sh` against temp dirs; each task adds
cases to the committed harness. Mechanics §11 Phase 3's matrix + pack §8 Phase 5's additions.

### Task 5.1: Greenfield acceptance

- [ ] Fresh temp repo → setup walk → `check` green; doctrine-provenance stamps on every seeded
  entry; tier-0 table rows resolve; two-read fallback chain (`AGENTS.md → rules/ROUTING.md →
  workflows/<lane>.md`) holds.

### Task 5.2: Migration matrix

- [ ] Ad-hoc project fixture (arbitrary conventions, a custom `records-root`, pre-existing
  identifiers) → complete mapping table, aliases preserved verbatim in every store shape
  (Appendix B's per-store encoding), citations rewritten,
  unclassifiable-artifact triage surfaced, nothing dropped, check-green, stamped.
- [ ] Bare single-skill installs (per Appendix H's writer rows) at default **and** custom roots →
  each yields a resolvable installation (self-init-no-floor).
- [ ] Trunk-side ID allocation: a branch-side capture takes a slug placeholder, `curate` stamps
  the real counter ID at landing **before** anything cites it (Appendix B).

### Task 5.3: Unstamped refusal + the pre-stamp dispatch table

- [ ] Every framework verb class on an unstamped root: writers in Appendix H may create exactly
  their column; everything else routes to the onramps, emits `unstamped`, stops. One case per
  table row, plus each backlog non-capture verb **by name** — `ticket`, `promote`, `sync`,
  `close`, `done`, `curate`, `debrief` (Task 2.4's matrix).
- [ ] Registration stability: `setup` followed by **each self-registering member's init/deploy**
  (backlog `init`, architect `init`, auditor `deploy`, feature `init`) → the existing pack-style
  door block is **adopted, never overwritten** with an independence-era body (Appendix G's
  tier-aware protocol).
- [ ] Pause fail-safe: a drain over a store whose pause declaration is missing or malformed
  **skips the item and emits the fact** — never mutates, closes, or acts on it (Appendix D).

### Task 5.4: Doctrine three-way fixtures

- [ ] The seven cases (pack §5): local-only edit, upstream-only edit, both-sides conflict, local
  deletion (never re-imposed), upstream retirement, entry split (new IDs citing the parent), and
  a doctrine-source swap (two doctrines' `INV-4` never confused — source-qualified origin IDs).
- [ ] The **round-trip case** (Tasks 2.11 and 5.8 cite it): project A's local improvement →
  calibrator-prepared contribution → human-landed doctrine vNext → project B's calibrator sees
  *upstream updated*, offers it, the owning role applies and re-stamps `@vNext`, check-green.

### Task 5.5: Pack-lock transactional install

- [ ] Full-pack install green; seeded member-collision → abort, destination unchanged; lock vs
  installed-set drift → `check` fact; install → **remove the alias proxies** → `check` still
  green (a missing optional member is a fact, never drift — Appendix I).

### Task 5.6: Super-project matrix

- [ ] Standalone clone, opted-in submodule (its own full installation), non-opted (root trackers +
  `component:`), uninitialized (listed as **unknown**, never guessed), nested; resolver picks the
  nearest-enclosing stamped root in each; submodule-index staleness flagged after a gitlink bump;
  cross-installation citation only by `TK-` ID.

### Task 5.7: Cold-clone acceptance + role removal

- [ ] A reader given only the committed `AGENTS.md` + `.handbook/` (no skills, no `.agents/`
  reads) can choose and execute each lane by hand (the co-equal by-hand walks). Then remove each
  role in turn: the project stays legible; staleness is enumerated and check-flagged; re-running
  the map/table compile repairs the wiring.

### Task 5.8: Close-out

- [ ] The measures, each as a checkable assertion (not a blanket "checklists green"): **pack
  §10's five** — install-as-one-unit + check-green greenfield with provenance stamps (Task 5.1
  re-asserted); the 7-intent routing probe; the doctrine-diff divergence facts + an upstream
  contribution round-tripped onto a second fixture project (Task 5.4); cold-clone acceptance (Task
  5.7); the three-way audit seam on fixtures — no overlapping verdicts, no uncovered surface.
  **Mechanics §13 as amended by pack §7.3** (retired genericity items dropped): declaration-block
  bytes reported per spine doc; `always_loaded_bytes` within budget; `max_depth` ≤ 2 and the
  two-read fallback chain measured on the greenfield fixture; **fast-path cost** — completing a
  tracker item adds one done-log line, a capture adds one ID allocation, a drain adds one
  declared-pattern skip, each asserted on the fixture against today's cost.
- [ ] Final routing probe (the §10 intent set) — record `N/7` in the status lines.
- [ ] Mark both design docs' status lines **Implemented** (with date + probe score); mark this
  plan and the manifest complete (every row checked or explicitly triaged).
- [ ] Lint at final baseline; working tree clean.

---

## Deliberately out of scope

- **Migrating deployed host projects.** Each consuming project runs `/clankshop migrate` on its
  own schedule after the pack ships; legacy-layout hosts (e.g. a `records-root: dev` project) are
  the migrate verb's ordinary input, not plan tasks.
- **Other installed skill families** (superpowers, etc.) — untouched; `/feature`'s
  unique-name coexistence posture stands.
- **A feature ↔ workstream merge** — explicitly deferred by the design (pack §2); nothing here
  depends on it.
- **Mirror providers beyond GitHub** — the provider contract (Appendix E) is frozen; a second
  provider is future work.
- **Upstream doctrine hosting/distribution beyond this repo** — the contribution path prepares
  patches against `skills/clankshop/doctrine/`; multi-repo doctrine distribution is not designed.

---

## Appendix — the frozen contracts

Normative for every phase. Consolidated from mechanics §§2–7 and pack §§3–5; the design docs are
the rationale record, this appendix is the build contract. **Editing it is a design change.**

### A. Declaration blocks and spine-index (mechanics §2)

The block is the **first HTML comment** in the file. Opening line exactly
`<!-- spine-doc v<integer>`; each following line `key: value` (value = raw text to end-of-line; no
quoting/escaping/inline comments — `#` is data); closes with `-->` alone on a line. Duplicate keys
or a second block = malformed (a fact, never a guess). A file without a block is not a spine doc
(never an error).

```markdown
<!-- spine-doc v1
kind: gotchas
entry: ^## (G-[0-9]+):
ids: G
refs: .handbook/** .records/**
budget: 20 entries
exclude: archive/**
-->
```

Keys: `kind` required always; `entry` + `ids` required for **ID-store kinds** and absent for
**whole-file kinds** (`workflow`, `testing` — path-addressed per Appendix B, no entry matcher;
their identity is Appendix J's path-qualified origin ID); `budget` (unit explicit:
`entries|lines|bytes`), `refs`, `exclude`, `paused` (trackers only) optional. Dialects: `entry`/`paused` are POSIX extended
regexes; `refs`/`exclude` are space-separated installation-root-anchored git-pathspec globs.
Semantics: an `entry` match *defines* the ID in capture group 1; `ids: <prefix>` makes
`\b<prefix>-[A-Za-z0-9-]+\b` the citation matcher; a matcher hit that is not a definition is a
citation, resolved within `refs` minus `exclude`.

**Provenance & projection keys (same syntax, same block):** doctrine-side docs carry
`doctrine: <source-id>` + `doctrine-version: <integer>`; seeded whole-file docs — lane **and**
testing files alike — carry `origin:` + `origin-version:` (and, for splits, `origin-parent:`) in
their declaration (entry-level encodings are Appendix J's); stamped
projections (`rules/RECORDS.md`, stewardship-map blocks) carry `built-against: <input @ version>`
(Appendices G, I). **Unknown keys:** ignored by consumers and emitted as an `unknown-key` fact —
forward-compatible, never an error. **Discovery scope:** the spine-index survives as
*self-description* (a parse anchor for any checker and the cold clone); declaration-led *generic
discovery* is retired with pack §7.3 — the framework's checkers walk the known roots
(`.handbook/`, `.records/`) directly.

**Spine-index:** a self-describing tree's README carries `<!-- spine-index v1 … -->` (same syntax;
`docs:` key of relative paths). The block, not naming convention, anchors discovery; nested trees
are independent.

**Budgets are curation triggers, not split triggers** (soft caps: ≈25 invariants, ≈20 live
gotchas, ≈10 judgments, ≈60 lines/lane, ROUTING ≈25 lines); checks emit facts, stewards judge.

### B. Typed IDs and per-store wire formats (mechanics §2, §4)

| prefix | store | | prefix | store |
|---|---|---|---|---|
| `G-` | gotchas | | `T-` | tasks |
| `INV-` | invariants | | `I-` | issues |
| `POL-` | policy | | `B-` | bugs |
| — | workflows (path-addressed) | | `N-` | notes |
| `TK-` | tickets | | `F-` | feedback |

Wire formats:
- `tasks.md`: `- T-041 — <task text> · added 2026-08-05`
- `issues.md`: `### I-017 — <title> (HIGH)`; migrated entries append `(alias <old>)` verbatim.
- `feedback.md`: `### F-003 · <short title> · 2026-08-05`
- `bugs/`, `notes/`: store-dir frontmatter gains `id:` (`id: B-009`).
- tickets: file `.records/tickets/<YYYY-MM-DD>-<slug>.md`, ID derived by prefixing:
  `TK-<YYYY-MM-DD>-<slug>`. Never renamed. **Same-day slug collision** (including re-promotion
  of the same origin, which mints a new ticket by rule): suffix the slug deterministically
  (`-2`, `-3`, …) **before first publication** — file and derived ID together; never rename
  after.

**Alias encoding, per store** (migration preserves pre-existing identifiers — mechanics §8; the
form was previously frozen only for `issues.md`): `issues.md` / `feedback.md` — `(alias <old>)`
appended to the heading line; `tasks.md` — appended to the bullet; `bugs/` / `notes/` / tickets —
a frontmatter `alias: <old>` key. Task 5.2's migration fixture exercises every shape.

**Identity:** an ID is immutable once published (cited outside its own store). Counter IDs are
allocated **only on the trunk checkout** (pathspec-scoped commit); a trunk-unreachable capture
carries a slug placeholder and `curate` stamps the real ID at landing, before anything cites it.
`TK-` IDs are the **only** ID legal in cross-installation citations; bare counter IDs never cross
a boundary; no qualified-path form exists. `check`'s whole-installation duplicate scan (archives
included) is the backstop. Report IDs are filename-derived, not counter-based — their grammar is
Appendix L's.

### C. The done log and the writer map (mechanics §4; pack §4.3)

One line per completed entry, appended to `.records/done/log.md`:

```
- 2026-08-05 · T-041 · <one-line gist> · commits: abc1234,def5678 · <outcome>
```

Outcome ∈ `done | dropped | wontfix | drained`. No-work-commit outcomes write `commits: -` (the
log mutation's own commit is never cited). Work commits reference the entry ID.

**Writer map** (stated once, here): fast-path item finished → `backlog done`; ticket
resolved/wontfix → `backlog close` (writes the line itself); calibrator-dispatched improvement
landed → calibrator confirms uptake, `backlog done … --outcome drained`; workstream `ship` →
`backlog done` per shipped item **and** its own full done-record file into `.records/done/`;
dropped at curation → `curate` logs the `dropped` outcome. The completion moment is **landed on
the trunk**, not gate-green. Full done-record files remain a feature-lane/workstream artifact
only. **The logged ID for ticket completion:** a **promoted** ticket's line carries the **origin
entry's ID** (the work item; the gist cites the `TK-`); a **direct** ticket's line carries the
**`TK-` ID** (it has no origin by rule).

**Completion mutation, per store (frozen — the writer's and checker's shared contract):** flat
aggregators (`tasks.md`, `issues.md`, `feedback.md`) — the entry is **removed** from the live
file on completion; its done-log line is the archive (mechanics §3's no-file-archive rule for
flat trackers). **Removal span:** a bullet entry is its one line; a heading-led entry
(`issues.md`, `feedback.md` — multi-line blocks) is the heading line through the line before the
**next heading of equal or higher rank** or EOF — live `###` entries sit under `##` category
headings (scaffold-verified), so a same-level-only rule would consume the following category
header when completing a category's last entry. Fixtures: last-in-a-non-final-category, middle
entry, and EOF (Task 2.1). Store-dir items (`bugs/`, `notes/`) — the file is retained; `done` advances its
frontmatter (`status: resolved` + date), and `curate` may age it into the store's `archive/`. A
`done` naming an ID that is absent, already completed, or paused **refuses with a fact** — never
a duplicate done-log line. The `check` consistency fact: every done-log ID is gone from its live
flat tracker (or carries resolved status in its store-dir file), and no live entry cites a
done-log outcome.

### D. Tickets — schema, lifecycle, pause, promotion bar (mechanics §5)

File `.records/tickets/<YYYY-MM-DD>-<slug>.md`; frontmatter:

```yaml
---
type: ticket
id: TK-2026-08-05-gate-choice   # derived from the filename; stated for grep-ability
status: open                    # open | answered | resolved
subject_kind: issue             # REQUIRED — one of the five capture kinds
origin: I-017                   # promoted tickets only; absent on direct tickets
blocking: [TK-…]                # optional; gates THIS ticket's resolution only; cycles = check fact
mirror:                         # present only while mirrored (E)
  provider: github
  issue: 214
  pushed_hash: 5f2a…
  comments:
    - {id: 1888214301, updated: 2026-08-05T14:02Z, hash: 9c1b…}
updated: 2026-08-05
---
```

Body sections: `## Context`, `## Decision needed` (with the agent's recommended answer),
`## Comments` (append-only; imported comments keyed by remote ID), `## Resolution`.

Transition table (the agent is the only state writer; *(p)* = promoted only):

| event | actor | state | origin entry *(p)* | done log |
|---|---|---|---|---|
| create (direct) | agent | → open | n/a | — |
| promote | agent | → open | paused `[⇧ TK-…]` | — |
| human comment (sufficient) | human→agent | → answered | paused | — |
| human comment (partial) | human→agent | stays open | paused | — |
| agent follow-up | agent | answered → open | paused | — |
| resolve | agent | → resolved | un-paused; advances/closes | one line, outcome + commits |
| wontfix | agent per human | → resolved (wontfix) | un-paused; closes | one line, `commits: -` |
| demote | agent per human | → resolved (demoted) | un-paused, live | — |

**Pause encoding, declaration-led:** flat aggregators declare `paused: \[⇧ TK-[^]]+\]` matched
against the entry line; store-dir items declare frontmatter `paused: <TK-id>`. Consumers skip what
the declaration matches. **Fail-safe:** a drain that cannot prove an item unpaused (missing/
malformed declaration) skips it and emits a fact. Promotion and its pause marker are **trunk-side
scoped commits**, always; the working branch cites the `TK-` ID.

**Promotion bar** (HITL litmus — promote when resolving would require standing in for the human):
*decision* (preference/tradeoff/scope call), *sign-off* (risky/irreversible/outward-facing),
*ambiguity* (guessing risks real waste), *access* (accounts/credentials/purchases). Multi-session
scope alone is NOT a trigger; tie-breaker favors motion (proceed if cheaply reversible).
Re-promotion after demotion mints a new ticket citing the same `origin:`.

### E. The mirror protocol (mechanics §6)

The in-repo file is canonical; the mirror is a stamped projection with drift facts — never the
reverse.

- **Canonical projection (the hashed input):** rendered body minus `## Comments`, plus projected
  header fields (`id`, `status`, `subject_kind`, `origin`, title). `mirror:` block and `updated:`
  excluded. `pushed_hash` is the stamp; push only on hash change.
- **Push:** labels = status; title = ticket ID + subject; body = projection + `mirrored-from`
  footer carrying the ticket ID. Comments never round-trip into the body.
- **Pull:** full comment inventory every sync, keyed by immutable remote ID (idempotency key),
  appended in remote-ID order and recorded in `mirror.comments` with `updated` + content hash.
  Changed known ID → edited-comment drift fact; absent known ID → deleted-comment drift fact. The
  file wins.
- **Idempotent creation:** scan issues by the framework label for the stamped ticket ID (list
  scan, not the search index) → adopt (lowest issue number; extras flagged) or create, then
  commit the `mirror:` block. Crash between the two heals on next sync.
- **Lock:** `.records/tickets/.sync-lock` via atomic `mkdir`; payload names owner (pid + session)
  + acquisition time; stale after 10 minutes with takeover logged; removed on completion;
  git-excluded (the scaffold writes the exclusion). Sync runs **only on the trunk checkout**.
- **Trigger:** verb-time only (`promote`, `close`, `sync`) — never a daemon. **Degradation:** no
  remote, or a remote with no issue system → no `mirror:` block, no behavior change.
- **Provider contract:** immutable comment IDs with a total order, comment list + updated
  timestamps — or no mirror.

### F. The installation block (mechanics §7; pack §3.5)

Same comment-block syntax as A, in the front door (`AGENTS.md`/`CLAUDE.md`); at most one per
door; malformed/duplicate = fact + root treated as unstamped.

```markdown
<!-- installation v1
layout: 1
pack: clankshop
pack-version: 1
-->
```

`layout:` required; `pack:`/`pack-version:` written by pack onramps, absent on bare single-skill
installs. Content is deterministic (same bytes regardless of writer); **any durable-home
self-init creates or adopts it idempotently** (self-init-no-floor). It sits outside every skill's
registration delimiters. Distinct from and additional to the optional `records-root` variable
(unchanged contract). An unstamped root is **unmigrated**: framework verbs route to
`setup`/`migrate` and do nothing else, except per Appendix H — the writers licensed to create the
block on an unstamped root are **exactly Appendix H's table rows**; "any durable-home self-init"
means those verbs and no others.

**Resolution:** nearest-enclosing stamped root wins, via the filesystem walk +
`git rev-parse --show-superproject-working-tree` across repo boundaries; no stamped door anywhere
→ unmanaged (skills offer `setup`); routing tables never merge.

### G. The stewardship-map protocol (mechanics §2.3)

`.handbook/README.md` and `.records/README.md` are **two-region maps, not TOCs**: a short
authoritative preamble (what this is; one stewardship line per chapter — never reading order), and
a maintenance region of per-producer delimited blocks — `<!-- steward:<name> -->…
<!-- /steward:<name> -->` — each created on self-init (with the README skeleton itself if absent),
replaced wholesale only by its owner; the composer owns arrangement between blocks. Each block
carries its own `built-against:` stamp naming its input (a core role's block:
`clankshop@<pack-version>` — core members carry no individual version, Appendix I; a
helper-written block: `<name>@<version>` from its frontmatter key; the
composer's submodule-index block: `.gitmodules` + gitlink SHAs). One validator per projection.
`.agents/roles/` needs no map. `check` flags unknown top-level `.handbook/` entries.

**Door registration blocks (same delimiter protocol; frozen here, distinct from the maps —
route-registration has tier-specific authority):** a **core member's** block body comes from the
doctrine's door profile (Task 0.4 — the single source setup and every domain self-init write
from), is stamped `built-against: clankshop@<pack-version>`, and carries **no `Edges:` lines**
(the live independence-era writers emit path-scoped SHA stamps + `Edges:` content — their Phase-2
conformance tasks rewrite them, so a later domain init can never overwrite a pack-style block
with an independence-era body). A **helper's** block keeps the full independence protocol
(path-scoped SHA stamp, `Edges:` legal). An **optional proxy** registers only when installed.
The `check` validator is tier-aware: core blocks validate against the pack version, helper
blocks against their own protocol.

### H. The pre-stamp dispatch table (pack §3.4)

| verb on an unstamped root | may create | must not touch |
|---|---|---|
| `/clankshop setup` / `migrate` | everything (the bootstrap) | — |
| `/backlog init` (capture verbs call it lazily) | `.records/trackers/` skeleton + installation block (idempotent) | any `.handbook/` chapter |
| `/architect init` / `extract` | its design chapter + records + skeleton maps + installation block | other chapters |
| `/auditor deploy` | its seat + `.records/audit/` + installation block | any chapter |
| `/foreman route`, `/debugger`, `/chiropractor` | nothing — read-only; emit `unstamped`, point at the onramps | any write |
| every other framework verb | nothing — routes to the onramps | any write |

`/foreman init` does not exist. Any writing self-init also creates-or-adopts the installation
block, so a bare single-role install is a resolvable installation. The table is the **complete**
pre-stamp write license: every framework verb not named in a writer row has the last row's
conduct, and each member's conformance task states its verbs' unstamped behavior explicitly.

### I. The pack lock (pack §3.5; this plan's concrete grammar)

The lock lives in `packs/clankshop.md`'s frontmatter (the file `install.sh` already reads):

```yaml
---
name: clankshop
description: "…"
skills: <every installable member, space-separated — the install list>
pack-version: 1
layout: 1
core: clankshop architect foreman guardian auditor chiropractor calibrator backlog debugger feature workstream
helpers: delegate>=1 mailbox>=1 handoff>=1
optional: bug task
---
```

Three axes: `pack-version` (prose/verbs may change without the layout), `layout` (the frozen
format contract; bumped only by a migration), and the member partition. **Pinning semantics
(ratified 2026-08-07; the superpowers precedent — one pack-level version, members pinned by
shipping together):** core members carry **no individual versions** — they ship in the pack repo,
so `pack-version:` pins them implicitly (one release = one content state; stated, not
per-member). **Helpers declare `version: <integer>` in SKILL.md frontmatter** (an inert extra key
on every harness; written in Task 3.3); a lock line may list a helper **bare** (presence
semantics — Task 0.6's initial state) or **with a range** `name>=N` (Task 3.3 on); once a range
is declared, a missing or malformed `version:` key **fails preflight** — never a silent pass.
Optional members (alias proxies) are **default-installed** (they ride the `skills:` install
line) yet **removable without trace**: `check`'s lock-vs-installed comparison reports a missing
optional member as a green fact, never drift, and setup registers only the optional members
actually present. Install is **transactional**: preflight presence + collision + helper
ranges, abort/roll back on failure, never a partial pack. `check` compares lock vs installed set
as a fact. The lint gate reads `core:` as the machine-readable exemption rule (Task 4.1).
Members appear on these lines **only once they exist on disk**.

### J. The doctrine projection protocol (pack §5)

- **Origin identity:** every seedable doctrine entry has an origin ID — its doctrine-side typed ID
  qualified by the doctrine source ID (`clankshop:INV-4`) — stable across renames/edits/versions;
  splits mint new IDs citing the parent. The doctrine declaration carries `doctrine: clankshop` +
  version, so two doctrines' `INV-4` can never be confused. **Whole-file assets** (lanes, testing
  docs) are path-addressed: their origin ID is the path-qualified form
  `clankshop:workflows/<lane>` / `clankshop:testing/<DOC>`, and their base in `BASES.md` is the
  whole prior file body *(a plan-level freeze completing the design's lane-file provenance —
  ratify at the Phase-0 gate, alongside Appendix K's encoding)*.
- **Canonical comparison input (frozen — the differ is deterministic only over normalized
  bodies):** deployed bodies gain provenance encodings the doctrine bodies lack, so before
  diffing, strip the encoding per shape — an INV line minus its trailing `⟨…⟩` marker; a heading
  entry minus its `origin:`/`origin-version:`/`origin-parent:` lines; a whole-file asset minus
  its entire declaration block. `origin-version`'s exact value form is the doctrine's integer
  version (`@v3` in markers; `origin-version: 3` as a key). A split's child cites its parent in
  the same encoding: `⟨clankshop:INV-9 @v4 parent:INV-4⟩` for line entries, `origin-parent:
  <origin-id>` for heading and whole-file shapes. A freshly seeded, untouched entry of **every**
  shape must classify *unchanged* (Task 1.6 fixtures one per shape).
- **Provenance encoding:** seeded one-line entries (INV) append `⟨clankshop:INV-4 @v3⟩`;
  heading-led entries (G/POL) carry `origin:`/`origin-version:` lines under the heading; seeded
  lane files carry both keys in their declaration block.
- **The base store (ratified 2026-08-07):** the current doctrine holds the current bodies; on
  every doctrine version bump, each changed or retired entry's **prior body** is appended to
  `skills/clankshop/doctrine/BASES.md`, keyed `origin-id @version` — the frozen entry grammar:
  one delimited block per superseded body, `<!-- base clankshop:INV-4 @v1 -->` … the exact prior
  bytes … `<!-- /base -->` (whole-file assets store the full prior file body). **Base retrieval
  of `origin@vN`:** the *oldest* BASES block for that origin with version ≥ N (the body that was
  current at vN); if none exists, the **live doctrine entry** — an unrelated bump archives
  nothing for untouched origins, so their base is correctly the live body. **Coverage metadata
  (so an omitted block is never mistaken for an unchanged origin):** every version bump also
  appends one **bump record** — `<!-- bump v<N>: <origin-id> <origin-id> … -->` — listing
  exactly the origins changed or retired in that bump. The checker cross-references: a bump
  record naming an origin with no matching body block is a **missing-base fact**; the live
  fallback is legal only for origins no bump record names. Fully offline (the archive ships with the skill; the deployed *project*
  never carries it — diffing runs where the skills are installed); it grows by lines, not files.
- **Three-way diff:** the origin version pins the retrievable base; each seeded entry classifies
  as *unchanged / locally edited / upstream updated / conflict / locally deleted / upstream
  retired* — all six emitted as facts with an offer/apply gate; a locally deleted seed is never
  silently re-imposed; divergence is a state, not an error.
- **Upstream contribution is human-reviewed:** the calibrator prepares the patch and evidence; a
  human lands it in doctrine vNext; only then do other projects see an *upstream updated* offer.

### K. The calibrator intake table (pack §4.7)

Pack §4.7 requires eight columns per row: exact path/type, eligibility bar, stable source ID,
claim encoding, dispatched artifact, receiving owner, uptake proof, terminal writeback. The
uniform columns are stated once, **split by source class per the design's rule — only
non-tracker findings are materialized** (pack §4.7):

- **Tracker sources** (the `F-`/`I-`/`N-` rows): the entry is already an ID'd work item — the
  entry **itself** is the dispatched artifact and the single closure handle; no `T-` item is
  minted. **Claim wire encoding** (without it a second pass re-dispatches the same entry): a
  flat entry gains a trailing claim marker `[⇢ dispatched <date>]` on its entry line; a
  store-dir item a `dispatched: <date>` frontmatter key — written **atomically before dispatch**
  as a trunk-side scoped commit (the same discipline as the pause marker). A later pass skips
  claimed entries; `backlog done <F/I/N-id> --outcome drained` closes and clears the marker;
  a stale claim surfaces as an age fact and `curate` may release it (a judged act, logged).
  Paused entries are always skipped. *(This claim encoding joins the Appendix K bundle at Task
  0.8's ratification gate.)*
- **Non-tracker sources** (the three finding/report rows): materialized before dispatch as an
  ID'd improvement item — a `T-` entry in `.records/trackers/tasks.md` carrying the `improve:`
  marker and `source: <source-identifier>#<finding-key>` (one form for every non-tracker
  source: the source-identifier is the report ID for reports, the repo-relative path for the
  audit FINDINGS store — matching the table and Appendix L exactly) — which is both the claim
  marker (a later pass skips claimed sources) and the closure handle *(this `T-`/`improve:`/`source:` wire encoding is a
  plan-level freeze flagged at review — ratify or amend at the Phase-0 gate)*.
- **Receiving owner** (uniform): the role owning the indicted chapter or store, routed per item.
  **Uptake proof** (uniform): the owning role's edit landed + check-green. Universal rules: the
  calibrator is the **only** scanner of these sources; paused entries are always skipped;
  terminal writeback is `backlog done` on the closure handle plus the source stamp below.

| source (exact) | eligibility bar | source ID | writeback on the source |
|---|---|---|---|
| `.records/trackers/feedback.md` | the whole dev-experience channel | `F-n` | entry advanced via `backlog done … drained` |
| `.records/trackers/issues.md` | process-flavored only (*how we work*; the rest stays with `route`) | `I-n` | entry advanced via `backlog done … drained` |
| `.records/trackers/notes/` | system-flavored (a durable trap/rule belonging in GOTCHAS/INVARIANTS) | `N-n` | entry advanced via `backlog done … drained` |
| `.records/audit/FINDINGS.md` (type: audit finding) | passes the system-improvement bar (evidence the *framework* should change; code findings → `route`) | `<file>#<finding-key>` | `processed:` gains the finding key |
| `.records/reports/doc-drift-*.md` (type: doc-drift) | accepted doc-drift findings | `<report-ID>#<finding-key>` (Appendix L) | `processed:` list gains the finding key |
| `.records/reports/investigation-*.md` (type: investigation) | the lessons slice | `<report-ID>#<finding-key>` (Appendix L) | `processed:` list gains the finding key |

Report and finding identity is **per finding, never per report** (pack §4.7's
`<report file / finding key>` source): a report with several findings routed to different owners
processes each independently — accepting one never hides the rest.

### L. The report wire contract (pack §4.8)

Each writer into `.records/reports/` owns a distinct `type:`. Common frontmatter floor: `type`,
`id`, `date`, `source`, optional `processed:`. Disjoint filename namespaces:
`investigation-<date>-<slug>.md` (debugger), `doc-drift-<date>-<slug>.md` (chiropractor), and
`reconcile-<date>-<slug>.md` (architect — the **live third writer**, `verbs/reconcile.md`, today
writing slug-less `reconcile-<date>.md`; Task 2.9 conforms it) — writers can never collide, and
the calibrator's closure protocol has a stable key. `bugs/` is a report store, never a work
queue.

**Report IDs (frozen — the grammar Appendix B defers here):** `id` = the filename stem verbatim
(`investigation-2026-08-07-<slug>`, `doc-drift-2026-08-07-<slug>`) — derived by construction like
ticket IDs, unique via type-prefix + date + slug, never renamed; stated in frontmatter for
grep-ability. Uniqueness scope is the installation; report IDs never cross an installation
boundary. **Collision allocation:** date + slug is a derivation, not a guarantee — if the target
filename already exists in the namespace, the writer suffixes deterministically (`-2`, `-3`, …)
**before first publication**; a report file is never renamed after. **Finding keys:** every
multi-finding report type (doc-drift, investigation, reconcile, and the audit FINDINGS store)
gives each finding a **stable key** — the frozen grammar: a keyed finding heading
`#### <key> — <title>` where `<key>` matches `[a-z0-9-]+` and is unique within the report; the
calibrator's `source:` cites `<source-identifier>#<finding-key>` (report ID for reports,
repo-relative path for the FINDINGS store); `processed:` is a **YAML list of finding keys**
(`processed: [gate-gap, stale-map]`), never a boolean — one writer grammar, so no two writers
can produce incompatible processing state.
