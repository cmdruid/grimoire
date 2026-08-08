# Skill boundaries + glue ownership — Design & Implementation Plan

**Status:** Implemented (2026-07-18) on branch `skill-boundaries-glue-ownership`. Routing-probe gate
passed 12/12 against the thinned descriptions alone (fresh sub-agent); `skills-lint.sh` `fails=0` with
the only check-7 WARN being the documented `mailbox → /delegate` fragment exception. **Superseded in
part (2026-08-08)** by the clankshop pack design (`docs/design/2026-08-06-clankshop-pack.md`): pack
**core members** follow the pack's authored composition and are exempt from the independence checks;
the boundary/glue provisions **stand for standalone skills and helpers**.

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development to
> implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Raise how competently agents wield this library — the prime constraint (see *North star*).
The lever: stop skills from co-mingling. Establish, as written doctrine, that a skill's frontmatter
describes **only its own job**, and that the **cross-skill glue lives in the `clankshop` runbook** —
not scattered across leaf descriptions. Re-scope `clankshop`↔`foreman` so the runbook **owns the glue
content** (births the constellation) and `foreman` **stamps and grows** it (never authors it). Ship a
repeatable **boundary-audit workflow** plus a mechanical lint backstop, and apply it once to clean the
current library.

**Architecture:** Prose/skills repo. The work is doctrine (`AGENTS.md`), one runbook (`clankshop.md`),
two `foreman` files (`SKILL.md`, `verbs/init.md`), one new maintainer workflow doc, and description
edits across the ten skills. Gate: `scripts/skills-lint.sh` → `fails=0`.

**References:**
- The design conversation this plan implements (this session).
- `packs/clankshop.md` — the runbook that owns the composition + seam contracts.
- `docs/design/2026-07-17-library-refactor.md` — the operators/plumbing/steward taxonomy.
- `AGENTS.md` — the library's design-philosophy home (where the new tenets land).

---

## The reframe (what changed in our thinking)

Two realizations drive this plan:

1. **The glue already has a home, and the descriptions were duplicating it.** `clankshop.md` already
   states the principle — *"the cross-skill seams live between skills, in no single skill's frontmatter,
   so they must live here"* (clankshop.md ~L17) — and already carries the seam-contract table and the
   *"Which audit?"* disambiguation. The friction ("two skills read like the same paragraph") is leaf
   descriptions **cross-referencing siblings**, which the runbook already owns. The fix is to *thin the
   leaves*, not enrich them.

2. **`clankshop` births; `foreman` grows.** `clankshop.md` calls `foreman` a **pack-agnostic oven**
   (*"never names a specific skill"*, ~L12–14) yet the seam table also says `foreman` **authors** the
   `AGENTS.md` glue (~L102). Those collide: an agnostic oven can't author pack-specific glue — it can
   only **stamp** glue the recipe supplies. Resolution: the runbook owns the glue **content** and the
   authority for **initial deployment (birth)**; `foreman` is the generic **executor** that stamps it,
   and owns the **ongoing lifecycle (growth)** — `calibrate` incorporates new skills, `check` validates
   drift. This preserves `foreman`'s packless-baseline path and its cross-pack mechanism reuse (why we
   keep `foreman` as the executor rather than making `clankshop` self-deploying).

---

## North star — competence is the constraint, independence is the means

The prime goal is **agents using these skills with high competence.** Independence (self-scoped
descriptions, no cross-references) is *how* we get there — pursued aggressively, but **gated on routing
accuracy, never traded for it.**

- **Descriptions are the routing surface, and they route *alone*.** The harness selects a skill from
  its `description:`; the runbook is in context only if something loaded it. A **bare install** (skills
  installed, `/foreman init` never run) has *only* the descriptions — no seam map. So every description
  must route correctly **on its own**. Removing a cross-reference is safe only when the two self-scopes
  are distinct enough to disambiguate without it.
- **Two layers, defense in depth.** Descriptions = the minimal self-sufficient routing surface (works
  in a bare install). Runbook → `AGENTS.md` = the richer authoritative seam map (deployed projects).
  Both independently enable correct routing.
- **Tie-breaker — performance wins.** Where two self-scopes can't disambiguate, **sharpen the scopes**
  until they can; do *not* restore the pointer. Keep a single minimal pointer only if two skills are
  genuinely inseparable (a documented exception). Never trade routing accuracy for purity.
- **Independence = no *hard* dependency.** Each skill's core job works standalone; a soft **body**
  pointer to the next step ("land the work next") aids competent multi-skill use and doesn't break
  standalone use, so it stays. Severing the workflow chain would *hurt* competence — not our goal.
- **Verified, not assumed.** The cleanup is gated by a **routing probe** (§C): realistic ambiguous
  prompts checked against the thinned descriptions alone. A mis-route fails the gate; the fix is
  sharper self-scope.

Most often independence and competence pull the *same* way — a cross-reference injects another skill's
concept into this skill's recall surface, so thinning usually makes routing *sharper*, not weaker. The
probe exists to catch the rare case where they don't.

---

## Locked design

### A. Design tenets (new doctrine → `AGENTS.md`)

Add to the `AGENTS.md` "Design philosophy" list:

- **Self-scoping descriptions.** A skill's frontmatter `description:` states only its **own** job and
  domain. It MUST NOT name a sibling skill to **defer, disambiguate, or contrast** — no *"for X use
  /other"*, *"distinct from /other"*, *"peer to /other"*. State your own scope sharply enough that it
  doesn't grab a neighbor's work; the *contrast* is the runbook's job, not yours.
  - **Narrow exceptions (must not swallow the rule):**
    - (a) A **router** whose function *is* to dispatch among mechanisms may name those mechanisms —
      it's describing its own function, not deferring (`delegate` → inline/mailbox/codex/…).
    - (b) A skill that is a genuine **fragment** of a named parent mechanism may carry **one** pointer
      to that parent for orientation (`mailbox` → `delegate`).
  - **Bodies** (not frontmatter) may keep an **operational** pointer a reader needs mid-task
    (*"land via …"*), but MUST NOT **re-document** or **own** another skill's seam — point, don't paste.
  - **Gate, not purity.** Remove a cross-reference only when the two self-scopes route correctly
    *without* it (the *North star* routing test); where they can't, sharpen the scope — never restore
    the pointer. Competence is the hard constraint; independence is maximized under it.

- **Cross-skill seams live in the runbook.** The map of who-owns-what and how two skills compose
  belongs to the pack/runbook (`clankshop.md`'s seam table + *"Which audit?"*), never duplicated into a
  leaf's frontmatter. Invariant (existing): **no skill crosses another's seam.**

- **Glue is content (birth) vs. mechanism (growth).** The glue **content** — the seams, the initial
  `AGENTS.md`/`WORKFLOWS.md` glue — is owned by the pack/runbook. The workflow engine **stamps** it at
  deploy and **grows** it post-deploy (via `calibrate`); it **never authors** the initial pack-specific
  glue. Recipe owns *what*; oven owns *how* and *ongoing*.

### B. `clankshop` ↔ `foreman` re-scoping (Option A — foreman stays the executor)

- **`clankshop` owns birth:** source of truth for the seams and the initial glue that lands in a
  target's `AGENTS.md`/`WORKFLOWS.md`.
- **`foreman` owns the mechanism + growth:** `init` **stamps** whatever the recipe specifies (and still
  **baselines** on a bare, packless install — the reason the mechanics stay in the oven); `calibrate`
  incorporates new skills into the deployed workflow; `check` validates drift.
- **Concrete doc changes** (wording, not new mechanics):
  - `clankshop.md` seam table: `foreman authors the AGENTS.md glue` →
    **`clankshop` specifies the initial glue; `foreman` stamps it; `chiropractor` audits its
    ergonomics.** (recast the "Author vs. auditor" seam accordingly)
  - `clankshop.md`: state the **birth-vs-growth** split explicitly in the *Mechanism vs. composition*
    section.
  - `clankshop.md`: **complete the seam table** so it is the whole truth — add the `delegate ↔ mailbox`
    row (*decides vs. carries*) and the `auditor ↔ chiropractor` row (*code vs. doc-spine*), which today
    live only as prose elsewhere in the file.
  - `foreman/SKILL.md` + `foreman/verbs/init.md`: drop "author(s) the glue" language in favor of
    **"stamps/instantiates the pack's glue"** at birth and **"grows it via `calibrate`"** thereafter.

### C. The boundary-audit workflow (grimoire-local maintainer workflow)

Home: a new maintainer doc, **`docs/boundary-audit.md`**, linked from `AGENTS.md`. It is a
**library-maintainer** workflow — deliberately **not** a `foreman` verb (foreman's domain is a
*consuming* project's workflow; auditing grimoire's own authored artifacts is a toolmaker concern).

**Violation rubric (what the audit flags):**
1. A `description:` names a sibling skill to defer/disambiguate/contrast (outside exceptions a/b).
2. A `description:` carries decision- or domain-language that duplicates another skill's job (the
   pre-fix `mailbox` case: it led with `delegate`'s "when to delegate / model routing").
3. A body **re-documents** another skill's protocol/seam instead of pointing at it.
4. A seam asserted in a leaf that is **absent from `clankshop`'s seam table** (leaf↔runbook drift).

**Workflow steps:** inventory skills → scan each `description:` + body against the rubric → cross-check
each asserted seam against `clankshop`'s table → produce findings → fix (self-scope the leaf; move any
real seam into the runbook) → **routing-probe the thinned descriptions** → re-run the lint +
`skills-lint.sh` → report.

**Routing-probe acceptance gate.** For each pair of skills a fix thins, write 1–2 realistic ambiguous
prompts and the expected target (e.g. *"audit my repo"* → `auditor`; *"my docs are a mess"* →
`chiropractor`; *"where does this change start?"* → `foreman`). Verify routing against **only the
thinned descriptions**, ideally via a **fresh sub-agent** that cannot see the audit's reasoning. A
mis-route **fails the gate** — fix by sharpening self-scope, not by restoring the cross-reference.

**Mechanical backstop:** extend `scripts/skills-lint.sh` **check 6** to also emit a WARN when a
`description:` contains a backticked `/name` that resolves to a **sibling skill** (today it only warns
on refs matching *no* skill). Facts, not verdicts — the WARN surfaces a candidate; the maintainer
judges it against the rubric (the exceptions are real, so this stays advisory, never a FAIL).

### D. One-time cleanup (apply the audit now)

Per-skill disposition (frontmatter unless noted). Every removed seam must already exist in — or be
added to — `clankshop`'s seam map.

| skill | disposition |
|---|---|
| `mailbox` | **keep** the transport-first recast (self-scoping); trim `/delegate` mentions to the single fragment-pointer (exception b). **Revert** the "delegate decides / mailbox carries" line added to its Overview. |
| `delegate` | **revert** the Overview "decides/carries" stamp back to "points at `mailbox` for the slot protocol" (router-names-mechanism, exception a). **Remove** the `handoff` keyword (collides with the `handoff` skill). |
| `architect` | drop *"Seed-altitude peer to /feature … and /foreman"* → self-scope (*"foundational, seed-altitude design, not feature-scope"*). Altitude seam already in clankshop (~L104). |
| `backlog` | drop *"Distinct from … /foreman … and … /auditor"* and *"/foreman drains"* → self-scope (*"captures uniformly, never drains"*). Seam in clankshop (~L100). |
| `feature` | drop the *"orchestrator (you, /foreman, or /workstream) … capture stays /backlog … landing stays /workstream"* naming → self-scope (*"ends at gate-green; never lands, ships, or debriefs"*). Seams in clankshop (~L105). |
| `auditor` | drop *"distinct from any .agents/foreman/ … sweep"* and *"same shape as architect/foreman"* → self-scope (*"audits project code quality"*). *"Which audit?"* owns it (clankshop ~L129). |
| `handoff` | **borderline — flag for review.** Recast *"For isolated worktree streams use /workstream instead"* into pure self-scope (*"saves/resumes root, non-worktree sessions"*) so the scope excludes streams without naming `workstream`. |
| `foreman` | self-scope the *"capture bureau is /backlog"* / *"distinct from /auditor"* contrasts (its **body** may still name the lanes it routes to — router exception a); fold in the B-task "stamp, not author" wording. |
| `workstream`, `chiropractor` | spot-check only; both read self-contained today. |

---

## Global constraints

- **Gate, every task:** `bash scripts/skills-lint.sh` → `fails=0` before each commit. WARN lines allowed.
- **Frontmatter `description:`** ≤1024 chars (FAIL), aim ≤750 (WARN); quote if it contains `": "`. The
  cleanup **shortens** descriptions — treat any that grow as a smell.
- **Commits** scoped to paths touched; **no `Co-Authored-By` trailer**.
- **Portable prose:** name the generic concept ("the runbook", "the workflow engine"), never a harness.
- **Doctrine-and-tool together:** when a rule changes, change it in the prose every agent reads
  (`AGENTS.md`/`clankshop.md`) *and* the lint — never only one.

## Non-goals (YAGNI)

- **No `foreman` "boundary audit" verb** — category error; the audit is a toolmaker workflow on grimoire
  itself, not a consuming-project operation.
- **`clankshop` does not become self-deploying** (Option B rejected) — that would orphan the packless
  baseline and duplicate deploy mechanics per pack.
- **No change to deployed-project behavior** beyond wording that clarifies already-existing ownership.
- No unrelated description rewrites — only boundary violations per the rubric.

---

## Tasks

### Task 1 — Doctrine: the three tenets → `AGENTS.md`
**Files:** `AGENTS.md`
- [ ] **Baseline.** `bash scripts/skills-lint.sh` → `fails=0`; record BASE (`git rev-parse --short HEAD`).
- [ ] Add the three tenets from **§A** to the "Design philosophy" list (self-scoping descriptions +
  exceptions; seams-live-in-the-runbook; glue content-vs-mechanism / birth-vs-growth).
- [ ] Gate → commit (`docs(agents): boundary + glue-ownership tenets`).

### Task 2 — Runbook: re-scope + complete `clankshop.md`
**Files:** `packs/clankshop.md`
- [ ] Recast the `foreman`↔glue seam row per **§B** (*clankshop specifies / foreman stamps / chiropractor
  audits*); state **birth-vs-growth** in *Mechanism vs. composition*.
- [ ] Add the missing seam-table rows: `delegate ↔ mailbox`, `auditor ↔ chiropractor`.
- [ ] Verify no remaining text says `foreman` *authors* the glue.
- [ ] Gate → commit.

### Task 3 — `foreman`: stamp-not-author wording
**Files:** `skills/foreman/SKILL.md`, `skills/foreman/verbs/init.md`
- [ ] Reword init/identity so `foreman` **stamps/instantiates** the pack's glue at birth and **grows** it
  via `calibrate`; drop "authors the glue". Preserve the packless-baseline description.
- [ ] Self-scope `foreman`'s `description:` contrasts (keep router/lane naming in the **body** only).
- [ ] Gate → commit.

### Task 4 — The boundary-audit workflow + lint backstop
**Files:** `docs/boundary-audit.md` (new), `AGENTS.md` (link), `scripts/skills-lint.sh`
- [ ] Write `docs/boundary-audit.md` — the rubric + steps from **§C**.
- [ ] Link it from `AGENTS.md` (one line, under skill-authoring guidance).
- [ ] Extend `skills-lint.sh` check 6: WARN on a `description:` `/name` that resolves to a **sibling**
  skill. Keep it a WARN (exceptions are legitimate). Add a self-test line/fixture if the script has one.
- [ ] Gate → commit.

### Task 5 — Apply the cleanup to the ten skills
**Files:** the `SKILL.md` (and `delegate`/`mailbox` Overview) rows in **§D**
- [ ] Work the disposition table row by row; for each, confirm the removed seam is present in
  `clankshop`'s map (add it in Task 2's spirit if a gap surfaces).
- [ ] Revert the two Overview "decides/carries" stamps; keep the `mailbox` recast.
- [ ] **Pause on `handoff`** — present the recast for human sign-off before applying (the flagged
  borderline).
- [ ] Run `skills-lint.sh`; confirm the new check 6 WARNs are all either fixed or a documented exception.
- [ ] Gate → commit.

### Task 6 — Routing-probe acceptance (fresh sub-agent)
**Files:** none (verification); record the probe set in `docs/boundary-audit.md` as worked examples
- [ ] For each thinned pair, run the routing probes from **§C** against the **thinned descriptions
  only**, via a **fresh sub-agent** that cannot see this session's reasoning.
- [ ] Any mis-route → sharpen that skill's self-scope and re-probe until green (never restore the
  cross-reference). Record the final probe set + outcomes in `docs/boundary-audit.md`.

### Task 7 — Verify
- [ ] `bash scripts/skills-lint.sh` → `fails=0`; review residual WARNs.
- [ ] Grep sweep: no `description:` names a sibling outside the two documented exceptions; `handoff`'s
  keyword collision gone; every asserted seam appears in `clankshop`'s table.
- [ ] Skim each changed `description:` cold — does it still route correctly on its own scope alone?

---

## Open questions for review

1. **`handoff` (§D).** *Resolved (2026-07-18): pure self-scope for now* — recast into "saves/resumes
   root, non-worktree sessions"; no `/workstream` pointer.
2. **Audit-doc home.** *Resolved (2026-07-18): `docs/boundary-audit.md`* — flat in `docs/`, no
   sub-folder.
3. **`foreman`'s description — function vs. contrast.** *Resolved (2026-07-18): adopt the
   recommendation below — drop contrast, genericize function mentions, keep change-kinds; applied in
   Task 3.* `foreman` is a **hub** whose
   identity is coordinating the others, so its `description:` mentions siblings for two different
   reasons that the tenet treats differently:
   - **Function** (naming what a verb operates on) — e.g. *"`calibrate` drains `/backlog`'s signal into
     doctrine."* Borderline exception (a): can be self-scoped to *"drains the captured signal"* without
     naming the sibling.
   - **Contrast** (distinguishing `foreman` *from* a sibling) — e.g. *"the capture bureau is
     `/backlog`"*, *"distinct from `/auditor`."* Clear violation → the seam already lives in the
     runbook (clankshop `backlog↔foreman` ~L100; *"Which audit?"* ~L129).

   **Recommendation:** drop the contrast clauses; self-scope the function mentions (say what the verb
   does, not which sibling feeds it); keep change-**kind** naming (`bug/patch/feature/spike` — those are
   not skills). `foreman`'s `route` already names kinds, not skills, so this is a light touch.
