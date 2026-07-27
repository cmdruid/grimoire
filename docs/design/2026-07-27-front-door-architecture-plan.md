# Front-Door Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `docs/design/2026-07-26-front-door-architecture.md` §7 — the compiled routing
table, the door profile, the two renames (`docs/DEVELOPMENT.md → docs/ROUTING.md`, `/foreman init →
/foreman setup`), the `docs/WORKFLOWS.md` dissolution, and the chiropractor rubric additions.

**Architecture:** Prose/skills repo — every task is markdown edits plus one small bash addition to
`foreman-health.sh`. The spec's compiler model: `ROUTING.md` is the source decision-walk, the
front-door routing table is its compiled projection (`setup` stamps, `calibrate` regrows, `check`
diffs), `/foreman route` is the slow path, chiropractor audits form only.

**Tech Stack:** Markdown, bash. Gate: `scripts/skills-lint.sh` (from repo root) → `fails=0`.

## Global Constraints

- Working directory: `/Users/cscott/Repos/grimoire`, branch `main` (the trunk — shared writes land here).
- Every commit is pathspec-scoped: `git add -- <paths> && git commit -m "<msg>" -- <paths>`. Never `git add -A`.
- No AI-attribution trailers (no `Co-Authored-By`) in any commit message.
- `docs/design/*.md` files other than this plan and `2026-07-26-front-door-architecture.md` are
  **historical records — never edit them**, even where they mention `DEVELOPMENT.md`, `WORKFLOWS.md`,
  or `/foreman init`. Same for `.claude/`/mirror paths: edit only files under `skills/`, `packs/`,
  `docs/design/`, `AGENTS.md`, `README.md` in the repo clone.
- `chiropractor` files must stay generic: they never name another skill, `ROUTING.md`, `foreman`,
  or grimoire deployment concepts. `foreman` files must stay pack-agnostic: they never name
  `clankshop` as a dependency (mentioning it as an example runbook is existing practice; keep as-is).
- The verb rename keeps `init` and `deploy` as accepted aliases of `setup` (spec §7.2).
- After each task: run `bash scripts/skills-lint.sh` from the repo root; expected `fails=0` before committing.
- Cited line numbers are snapshots from before this plan ran; earlier tasks shift them. Locate every
  edit by the quoted content, and treat the line number as a hint only.

---

### Task 1: Rename `docs/DEVELOPMENT.md` → `docs/ROUTING.md` (bundle + every live reference)

**Files:**
- Rename: `skills/foreman/docs/DEVELOPMENT.md` → `skills/foreman/docs/ROUTING.md`
- Modify: `skills/foreman/docs/ROUTING.md:1`, `skills/foreman/docs/PLANNING.md:3,5,15`,
  `skills/foreman/docs/MAINTENANCE.md:38,45,119`, `skills/foreman/docs/WORKFLOWS.md:18,38,47`,
  `skills/foreman/verbs/route.md:4,13,56`, `skills/foreman/verbs/check.md:88`,
  `skills/foreman/verbs/calibrate.md:60`, `skills/foreman/verbs/init.md:63`,
  `skills/foreman/verbs/migrate.md:103`, `skills/foreman/BOOTSTRAP.md:92,123,134,216,217,226`,
  `skills/workstream/SKILL.md:8`, `skills/backlog/verbs/bug.md:4`, `skills/feature/SKILL.md:60`

**Interfaces:**
- Produces: the path `.agents/foreman/docs/ROUTING.md` and bundle path
  `skills/foreman/docs/ROUTING.md` — every later task uses these names, never `DEVELOPMENT`.

- [ ] **Step 1: git mv the bundled doc**

```bash
git mv skills/foreman/docs/DEVELOPMENT.md skills/foreman/docs/ROUTING.md
```

- [ ] **Step 2: Retitle the moved doc**

In `skills/foreman/docs/ROUTING.md`, replace line 1:

```markdown
# Routing -- what kind of change, and where to go
```

(Leave the body paragraph "The **router** for making any change…" as is — it is already accurate.)

- [ ] **Step 3: Sweep every live reference**

```bash
grep -rln 'DEVELOPMENT' skills/ | grep -v docs/design
```

For each hit, replace the token only (`DEVELOPMENT.md` → `ROUTING.md`, backticked
`` `DEVELOPMENT` `` → `` `ROUTING` ``, path `…docs/DEVELOPMENT` → `…docs/ROUTING`), keeping the
surrounding sentence. The expected hit list is exactly the Modify list above; a hit outside it
means the survey drifted — update it the same way and note it in the commit body. Two callouts:
  - `skills/foreman/BOOTSTRAP.md:226`: `**DEVELOPMENT** = *making a change*` → `**ROUTING** = *making a change*`.
  - `skills/workstream/SKILL.md:8`: `` `DEVELOPMENT -> PLANNING -> WORKTREES` `` → `` `ROUTING -> PLANNING -> WORKTREES` ``.

- [ ] **Step 4: Verify no live references remain**

```bash
grep -rn 'DEVELOPMENT' skills/ packs/ AGENTS.md README.md | grep -v docs/design
```

Expected: no output.

- [ ] **Step 5: Lint, then commit**

```bash
bash scripts/skills-lint.sh
git add -- skills/ && git commit -m "foreman: rename docs/DEVELOPMENT.md -> docs/ROUTING.md (front-door design 2026-07-26 §7)" -- skills/
```

---

### Task 2: Dissolve `docs/WORKFLOWS.md` (rule 3: no menu-only reads)

**Files:**
- Delete: `skills/foreman/docs/WORKFLOWS.md`
- Modify: `skills/foreman/BOOTSTRAP.md:95,137,226-227`, `skills/foreman/docs/MAINTENANCE.md:38-40,46`,
  `skills/foreman/verbs/calibrate.md:61`, `skills/foreman/verbs/init.md:63-64`,
  `skills/foreman/verbs/migrate.md:103`

**Interfaces:**
- Consumes: `ROUTING.md` naming from Task 1.
- Produces: a bundle with **no** workflow-index doc; later tasks (4, 6) route its lane rows into
  the door's routing table.

- [ ] **Step 1: Relocate the three `<stack:>` content slots**

`docs/WORKFLOWS.md` is mostly a menu (rows pointing at ROUTING/PLANNING/WORKTREES/MAINTENANCE,
which survive as direct door pointers), but three sections carry project-content `<stack:>` *slots*
that need a new home in the content docs that already own their topics:
  - Append to the DIAGNOSTICS content-doc **brief** in `skills/foreman/BOOTSTRAP.md:142` (the
    `DIAGNOSTICS.md` tree line): extend the line's description to
    `-- <content doc> the debugging playbook + E2E/integration harness + visual/integration fast-path tooling`.
  - `PERFORMANCE.md`'s brief (BOOTSTRAP line 143) already covers the perf slot: leave as-is.
  - No bundled `DIAGNOSTICS.md`/`PERFORMANCE.md` files exist (they are host-authored content docs),
    so the slots live on only as those briefs — nothing else to move.

- [ ] **Step 2: Delete the doc and its module-map row**

```bash
git rm skills/foreman/docs/WORKFLOWS.md
```

In `skills/foreman/BOOTSTRAP.md`:
  - Delete line 95 (`| **Workflow index** | docs/WORKFLOWS | Core | enough how-tos to need an index |`).
  - Delete line 137 (the `WORKFLOWS.md` tree entry).
  - Rewrite lines 226-227 from "Keep the three navigation docs non-overlapping: **README** = *where
    things live*, **ROUTING** = *making a change*, **WORKFLOWS** = *how to do task Y*…" to:

```markdown
Keep the two navigation docs non-overlapping: **README** = *where things live*, **ROUTING**
= *making a change*. There is deliberately no workflow-index doc: an index is a menu, and menus
live in the front door's routing table (free at tier 0) -- a how-to's payload lives in the one
content doc that owns its topic.
```

- [ ] **Step 3: Repoint the verb + doc references**

  - `skills/foreman/verbs/calibrate.md:61`: replace the knob
    `- a recurring how-to question → add/repoint it in .agents/foreman/docs/WORKFLOWS.md;` with:

```markdown
   - a recurring how-to question → answer it in the content doc that owns the topic
     (ARCHITECTURE / GOTCHAS / DIAGNOSTICS / PERFORMANCE) and, if it is a *where-does-work-start*
     question, add the missing row to the front door's routing table — never a menu doc;
```

  - `skills/foreman/verbs/init.md:63-64`: change the doc-set list
    `(`DEVELOPMENT`, `PLANNING`, `WORKTREES`, `WORKFLOWS`, `MAINTENANCE`)` →
    `` (`ROUTING`, `PLANNING`, `WORKTREES`, `MAINTENANCE`) `` (Task 1 already renamed the first).
  - `skills/foreman/verbs/migrate.md:103`: `DEVELOPMENT/PLANNING/WORKFLOWS…` → `ROUTING/PLANNING…`
    (drop `WORKFLOWS` from the example list).
  - `skills/foreman/docs/MAINTENANCE.md:38-40`: rewrite the "Tier the pointers" bullet's index
    reference — `…the rest goes behind an index (`WORKFLOWS.md` for how-tos, `.agents/foreman/README.md`
    for the rest)` → `…the rest goes behind `.agents/foreman/README.md` (the one index)`.
  - `skills/foreman/docs/MAINTENANCE.md:46`: row `add a **how-to / process doc** | add it to
    `WORKFLOWS.md`; name it directly in `AGENTS.md` only if it's first-reach` → `add a **how-to /
    process doc** | give the payload one owning doc; add a front-door routing-table row (or
    `AGENTS.md` pointer) only if it's first-reach`.

- [ ] **Step 4: Verify**

```bash
grep -rn 'WORKFLOWS' skills/ packs/ AGENTS.md README.md | grep -v docs/design
```

Expected: no output.

- [ ] **Step 5: Lint, then commit**

```bash
bash scripts/skills-lint.sh
git add -- skills/ && git commit -m "foreman: dissolve docs/WORKFLOWS.md -- menus live in the door, payloads in owning docs" -- skills/
```

---

### Task 3: Rename the stand-up verb `init` → `setup` (aliases `init`, `deploy` kept)

**Files:**
- Rename: `skills/foreman/verbs/init.md` → `skills/foreman/verbs/setup.md`
- Modify: `skills/foreman/SKILL.md:3,23,30-34`, `skills/foreman/verbs/setup.md:1` (+ its
  self-references and step-8 route block), `skills/foreman/verbs/route.md:7`,
  `skills/foreman/verbs/check.md:3,16-17,57-60`, `skills/foreman/verbs/migrate.md` (its
  init-reuse mentions), `skills/foreman/BOOTSTRAP.md` (all `/foreman init` + `verbs/init.md` hits),
  `skills/backlog/verbs/init.md:4,17,26,96`, `skills/backlog/docs/TAXONOMY.md:123`,
  `packs/clankshop.md` (all 8 `foreman init` hits, mechanical only), `README.md:51,68`, `AGENTS.md:20`

**Interfaces:**
- Consumes: Tasks 1–2 file names.
- Produces: verb name `setup`, file `skills/foreman/verbs/setup.md` — Tasks 4–6 write against these.

- [ ] **Step 1: git mv and retitle**

```bash
git mv skills/foreman/verbs/init.md skills/foreman/verbs/setup.md
```

Line 1 of `setup.md`: `# \`/foreman setup\` — instantiate a composition's glue on a fresh project`.

- [ ] **Step 2: Update foreman's own dispatch surface**

In `skills/foreman/SKILL.md`:
  - Description (line 3): `` `/foreman init` stands up… `` → `` `/foreman setup` (aliases `init`, `deploy`) stands up… ``.
  - Dispatch row (line 23): `| \`/foreman setup\` *(aliases \`init\`, \`deploy\`)* | \`verbs/setup.md\` | …` (Does/Trigger cells unchanged).
  - Verb-set paragraph (lines 30–34): `route / setup / migrate / calibrate / check`, and
    `**\`setup\` = greenfield**` in the seam sentence.

- [ ] **Step 3: Sweep the remaining references**

```bash
grep -rn 'foreman init\|verbs/init\.md\|`init`' skills/foreman/ skills/backlog/ packs/clankshop.md README.md AGENTS.md | grep -v docs/design
```

Mechanical replacements — `/foreman init` → `/foreman setup`; `verbs/init.md` → `verbs/setup.md`
where it means foreman's own verb file. Judgment calls, spelled out:
  - `skills/foreman/verbs/setup.md` step 8's registered block body: `` `/foreman|init|migrate|calibrate|check` ``
    → `` `/foreman|setup|migrate|calibrate|check` `` (the route line lists canonical verbs; aliases stay prose).
  - `skills/foreman/verbs/setup.md` step 2 + BOOTSTRAP:193: the phrase "a skill's own `init`/`deploy`
    verb" refers to the **generic self-init convention of other skills** — leave those untouched.
    Same for `skills/skill-builder/verbs/new.md:51` (do not edit skill-builder at all).
  - `skills/backlog/**`: only the `/foreman init` tokens change; `/backlog init` is backlog's own
    verb and stays.
  - `packs/clankshop.md`: mechanical rename only in this task (heading line 7, lines 11, 19, 36,
    55 verb list, 98, 100, 128, 219) — content additions come in Task 6.
  - `AGENTS.md:20` + `README.md:68`: `foreman init` writes an ownership index → `foreman setup`.
    `README.md:51`: `— \`init\` (greenfield)` → `— \`setup\` (greenfield)`.

- [ ] **Step 4: Verify**

```bash
grep -rn 'foreman init' skills/ packs/ AGENTS.md README.md | grep -v docs/design
```

Expected: no output.

- [ ] **Step 5: Lint, then commit**

```bash
bash scripts/skills-lint.sh
git add -- skills/ packs/ README.md AGENTS.md && git commit -m "foreman: rename stand-up verb init -> setup (aliases init/deploy kept)" -- skills/ packs/ README.md AGENTS.md
```

---

### Task 4: The door profile + compiled routing table (BOOTSTRAP + setup + ROUTING source note)

**Files:**
- Modify: `skills/foreman/BOOTSTRAP.md:121-124` (front-door brief), `:216-217` (nav walk),
  `skills/foreman/verbs/setup.md` step 6 area, `skills/foreman/docs/ROUTING.md` (top note)

**Interfaces:**
- Consumes: `setup` verb name, `ROUTING.md` path.
- Produces: the stamped-table contract text later tasks cite: "compiled from `docs/ROUTING.md`;
  `setup` stamps, `calibrate` regrows, `check` diffs".

- [ ] **Step 1: Rewrite BOOTSTRAP's front-door brief (lines 121-124)**

Replace the `<front door>` tree-entry description with the §4 profile:

```markdown
  <front door>            -- bootstrap entry, five ordered sections: (1) what-this-is, 1-2 lines;
                             (2) build/run/gate commands; (3) the ROUTING TABLE -- trigger -> lane
                             entry, ~10-15 lines, compiled from .agents/foreman/docs/ROUTING, with
                             one fallback line: "no skill runner? follow
                             .agents/foreman/docs/ROUTING by hand"; (4) repo map, one hop;
                             (5) pointers (conventions, gotchas, ownership index §4.1)
```

- [ ] **Step 2: Rewrite BOOTSTRAP's navigation walk (lines 216-217)**

```markdown
<front door>  (the routing table decides the common cases at zero extra reads)
   -> the lane's own entry point (skill verb, or the by-hand doc fallback)
   -> unsure / mixed altitude -> /foreman (route) -> .agents/foreman/docs/ROUTING  (classify the change)
```

- [ ] **Step 3: Make `setup` stamp the table**

In `skills/foreman/verbs/setup.md` step 6 (the AGENTS.md-surfacing step), after the gate/linter/
diagnostics sentence block, add:

```markdown
   **Stamp the routing table** — the tier-0 projection of `.agents/foreman/docs/ROUTING.md`'s
   decision-walk: one row per change class (bug / patch / feature / seed-altitude design / capture /
   unsure), each row dispatching directly to the lane's entry point from the Step 0 composition
   (or naming the by-hand fallback where the lane's skill is absent), ~10–15 lines, with the single
   fallback line beneath: *"no skill runner? follow `.agents/foreman/docs/ROUTING.md` by hand."*
   The last row is always *unsure / mixed altitude → `/foreman`* — `route` is the slow path behind
   the table, never a mandatory hop in front of it. The table is a **compiled projection**: this
   verb stamps it, `calibrate` regrows it when the walk or the installed skills change, and
   `/foreman check` diffs it against both.
```

- [ ] **Step 4: Mark ROUTING.md as the source**

In `skills/foreman/docs/ROUTING.md`, insert after the opening paragraph (below line ~7):

```markdown
The front door carries a **routing table compiled from this walk** -- the common cases at zero
extra reads. This doc is the source of truth the table projects; when the walk changes, recompile
the table (`/foreman calibrate`), and `/foreman check` diffs the two for drift.
```

- [ ] **Step 5: Lint, then commit**

```bash
bash scripts/skills-lint.sh
git add -- skills/foreman/ && git commit -m "foreman: door profile + compiled routing table (setup stamps, ROUTING is source)" -- skills/foreman/
```

---

### Task 5: Wire `route` / `calibrate` / `check` + `routing-targets` facts in the health script

**Files:**
- Modify: `skills/foreman/verbs/route.md:3-5`, `skills/foreman/verbs/calibrate.md:60`,
  `skills/foreman/verbs/check.md` (Pass 1 table), `skills/foreman/scripts/foreman-health.sh:282-339`

**Interfaces:**
- Consumes: the compiled-table contract from Task 4.
- Produces: fact key `routing-targets:` emitted by `check-projection`, judged in `check.md`.

- [ ] **Step 1: Name route the slow path**

In `skills/foreman/verbs/route.md`, after the first paragraph (ends "…dispatches the change to the
lane that owns it."), add:

```markdown
The deployed front door carries a **routing table compiled from that walk** — it decides the
common cases at zero extra reads, dispatching straight to a lane. `route` is the **slow path
behind the table**: invoked from its *unsure / mixed altitude* row (or when no table is stamped
yet), never a mandatory hop in front of it.
```

- [ ] **Step 2: Make calibrate recompile the projection**

In `skills/foreman/verbs/calibrate.md`, replace the routing-gap knob (line 60):

```markdown
   - a routing gap → sharpen `.agents/foreman/docs/ROUTING.md` (the change-router walk), then
     **recompile the front door's routing table** so the projection matches the source;
```

- [ ] **Step 3: Emit routing-target facts**

In `skills/foreman/scripts/foreman-health.sh`, in `cmd_check_projection()`, insert before
`rm -f "$reg" "$inst"` (line 338):

```bash
  # routing-targets: distinct `/skill` tokens in the front door's table rows (facts, not verdicts)
  echo "routing-targets:"
  n=0
  for t in $(grep -E '^\|' "$front" | grep -oE '\`/[a-z][a-z-]*\`' | tr -d '\`' | sort -u); do
    echo "  $t"; n=$((n+1))
  done
  [ "$n" -eq 0 ] && echo "  (none)"
```

- [ ] **Step 4: Syntax-check the script**

```bash
bash -n skills/foreman/scripts/foreman-health.sh && echo OK
```

Expected: `OK`.

- [ ] **Step 5: Teach check.md to judge the new facts**

In `skills/foreman/verbs/check.md`, append a row to the Pass 1 fact table (after `seam-drift`):

```markdown
| `routing-targets: /<name>` | a lane target named in the front door's routing-table rows | judge two ways: each target resolves (the skill is installed at the resolved root, or the row/fallback names the by-hand doc), and the table's rows still match `.agents/foreman/docs/ROUTING.md`'s change classes — a class the walk gained but the table lacks (or vice versa) is projection drift; hand the recompile to `calibrate` |
```

- [ ] **Step 6: Lint, then commit**

```bash
bash scripts/skills-lint.sh
git add -- skills/foreman/ && git commit -m "foreman: route is the slow path; calibrate recompiles the table; check emits routing-targets" -- skills/foreman/
```

---

### Task 6: clankshop — the door-profile spec + sharpened seam row

**Files:**
- Modify: `packs/clankshop.md` (after the layout section ~line 117; seam row line 136; the
  "Make a change" glue-workflow bullet ~line 179)

**Interfaces:**
- Consumes: Task 4's contract wording; Task 3's `setup` naming (already mechanically applied).
- Produces: the pack-owned door-profile spec `foreman setup` reads as composition.

- [ ] **Step 1: Add the front-door spec section**

Insert after the canonical-layout section (after the "Session hand-offs…" paragraph, ~line 122),
before "## The seam contracts":

```markdown
## The front door this pack specifies (tier-0 contract)

The recipe owns the glue *content*, so the door's shape is specified here and stamped by
`/foreman setup` (design: `docs/design/2026-07-26-front-door-architecture.md`). Five ordered
sections: **what-this-is** (1–2 lines) → **build/run/gate commands** → **routing table** →
**repo map** (one hop) → **pointers** (conventions, gotchas, ownership index). The routing table
is a **compiled projection** of `.agents/foreman/docs/ROUTING.md` — trigger → lane entry, verb-first,
~10–15 lines, one by-hand fallback line beneath, last row *unsure / mixed altitude → `/foreman`*:

| you're about to… | go |
|---|---|
| fix a reproducible bug | `/debugger` (file it: `/backlog bug`) |
| land a one-line patch | trunk, no ceremony |
| build a feature | `/feature` |
| change a tenet/contract/seam | `/architect` |
| capture a follow-up | `/backlog` |
| unsure / mixed altitude | `/foreman` |

The tier rules behind the shape (decisions at tier 0; procedure ≤ 2 actions away; no menu-only
reads; one job per payload) live in the design doc — this section is the stampable composition,
not a restatement of the doctrine.
```

- [ ] **Step 2: Sharpen the `foreman ↔ chiropractor` seam row (line 136)**

Replace the row's contract cell with:

```markdown
`clankshop` **specifies** the `AGENTS.md` workflow-glue (content); `foreman` **stamps** it at `setup` and **grows** it via `calibrate` (mechanism); `chiropractor` **audits** the front-door's ergonomics — routing *affordance*, read-depth, payload — never route *fidelity*, which is `/foreman check`'s. Specify → stamp → audit — none authors another's part.
```

(Edge-matching cell unchanged.)

- [ ] **Step 3: Update the "Make a change" glue-workflow bullet (~line 179)**

Prepend one sentence to the bullet: `The stamped routing table dispatches the common cases at
tier 0; `/foreman` (route) is the slow path for the *unsure / mixed altitude* row.` (rest of the
bullet unchanged).

- [ ] **Step 4: Lint, then commit**

```bash
bash scripts/skills-lint.sh
git add -- packs/clankshop.md && git commit -m "clankshop: specify the tier-0 door profile; sharpen foreman<->chiropractor to affordance-vs-fidelity" -- packs/clankshop.md
```

---

### Task 7: chiropractor — Check 5 (Routing Affordance) + rule absorptions

**Files:**
- Modify: `skills/chiropractor/RUBRIC.md:127-137` (Read-Path), `:172-184` (Token Economy),
  `:346-350` (entry-door intro), append after `:455` (Check 5);
  `skills/chiropractor/SKILL.md:156,163,213-222` ("four checks" → five, report block)

**Interfaces:**
- Consumes: nothing from other tasks (deliberately — chiropractor stays generic; no skill names,
  no `ROUTING.md`, no foreman vocabulary anywhere in this task's text).

- [ ] **Step 1: Append Check 5 to RUBRIC.md** (after Check 4's example adjustments, line 455)

```markdown
---

### Check 5. Routing Affordance

**What it checks:** Whether the content door tells a cold agent where work
starts -- a compact task-routing affordance (a "making a change?" table or
section) whose rows dispatch directly to a lane's entry point (a doc or a
runnable command), with a stated fallback for readers who cannot use the
primary dispatch mechanism.

**Facts that inform it:** `entry_outline`, `entry_hub_links`, plus judgment

- **solid** -- The door carries a routing affordance: an agent can classify
  "I'm about to do X" and reach the owning instruction chunk in one action,
  without reading any intermediary; rows point at entry points, not at menu
  documents; a fallback is stated.
- **drift** -- An affordance exists but is incomplete (a common change class
  is missing), displaced below long prose, or a row targets an intermediary
  menu rather than an entry point.
- **gap** -- No routing affordance: a cold agent must already know the layout,
  read several documents, or guess where a change starts.

**Form only, never fidelity.** This check judges that a routing affordance
exists and dispatches cleanly. Whether the routes are the *right* routes is
the owning workflow system's own validation concern -- out of scope for a
doc-ergonomics audit.

**Example adjustments:**
- Add a "where a change starts" table to the content door: one row per change
  class, each pointing at the owning entry point.
- Replace a row that targets an index/menu doc with the leaf it meant.
```

- [ ] **Step 2: Update the entry-door intro (RUBRIC.md:346-350)**

"The four checks below examine…" → "The five checks below examine…" (dimension-count sentence
stays: the `##` dimension count remains 12).

- [ ] **Step 3: Absorb the depth rule into Read-Path (RUBRIC.md ## 4)**

In the **solid** tier, extend the first clause: `max_depth <= 3; working docs an agent must act on
are reachable in <= 2 actions from the entry door; the critical path is obvious from the entry
doc's own prose.` Then append one paragraph after the tier list, before *Example adjustments*:

```markdown
**A menu-only intermediary is a Read-Path defect.** A doc whose sole content is
pointers to other docs adds a hop with no payload; fold its table into the
entry door (menus are free where context is already loaded) or into its
parent, and let each leaf carry real procedure.
```

- [ ] **Step 4: Absorb the payload rule into Token Economy (RUBRIC.md ## 6)**

Append after the tier list, before *Example adjustments*:

```markdown
**Triage `doc_sizes` outliers by job count, not size alone.** A large doc that
is one coherent job (a reference read end-to-end) is healthy; a large doc
bundling many independent how-tos makes every reader pay for the jobs they are
not doing -- a split candidate. The converse also holds: two small docs that
are only ever read together are one job paying two read overheads -- a merge
candidate.
```

- [ ] **Step 5: Update SKILL.md's check count + report block**

- Line 156: "judge the four checks" → "judge the five checks".
- Line 163: "Score each of the four checks" → "Score each of the five checks".
- Report block (lines 216-219): add a fifth line, aligned with the others:

```
check 5. Routing Affordance   -- solid | drift | gap -- <one-line rationale>
```

- [ ] **Step 6: Generic-phrasing self-check + lint + commit**

```bash
grep -n 'foreman\|ROUTING\|grimoire\|clankshop\|/backlog\|/feature\|/architect' skills/chiropractor/RUBRIC.md skills/chiropractor/SKILL.md
```

Expected: no output (chiropractor names no sibling and no deployment vocabulary).

```bash
bash scripts/skills-lint.sh
git add -- skills/chiropractor/ && git commit -m "chiropractor: entry-door Check 5 (routing affordance) + read-depth/payload rules in rubric" -- skills/chiropractor/
```

---

### Task 8: Grimoire's own AGENTS.md pointer + final gate

**Files:**
- Modify: `AGENTS.md` (grimoire root, the storage-convention paragraph ending "…and
  `packs/clankshop.md`.")

**Interfaces:**
- Consumes: everything — this is the acceptance pass.

- [ ] **Step 1: Add the one-line design pointer**

At the end of grimoire `AGENTS.md`'s storage-convention paragraph (the one updated in Task 3 to say
`foreman setup`), append one sentence:

```markdown
The front-door architecture that layout serves — read-cost tiers, the compiled routing table —
is `docs/design/2026-07-26-front-door-architecture.md`.
```

(One line only — per the patient-zero caveat, nothing self-registers into grimoire's own door.)

- [ ] **Step 2: Full-repo verification sweep**

```bash
bash scripts/skills-lint.sh
grep -rn 'DEVELOPMENT\|WORKFLOWS\|foreman init' skills/ packs/ AGENTS.md README.md | grep -v docs/design
```

Expected: lint `fails=0`; grep no output.

- [ ] **Step 3: Routing probe (spec §7 gate)**

Dispatch a **fresh subagent** whose prompt contains ONLY the `description:` frontmatter of the ten
`skills/*/SKILL.md` files (post-edit) and these four prompts, asking it to pick one skill per
prompt with no other context:

1. "Check that my AGENTS.md routes are still right." → expected `foreman`
2. "My front door is bloated and hard to navigate." → expected `chiropractor`
3. "Where does a bug fix start in this repo?" → expected `foreman`
4. "Audit the docs for agent ergonomics." → expected `chiropractor`

A mis-route fails the gate; the fix is sharper self-scoping in the offending `description:` (never
a cross-reference), then re-probe. Record date, prompt count, and pass rate in the final commit body.

- [ ] **Step 4: Commit + update the design doc status line**

In `docs/design/2026-07-26-front-door-architecture.md`, change the **Status:** line to
`**Status:** Implemented (<date from \`date +%Y-%m-%d\`>); routing probe <N>/4.` Then:

```bash
git add -- AGENTS.md docs/design/2026-07-26-front-door-architecture.md && git commit -m "docs: front-door design pointer in AGENTS.md; mark design implemented (probe N/4)" -- AGENTS.md docs/design/2026-07-26-front-door-architecture.md
```

---

## Deliberately out of scope

- The steward-grammar convergence (per-layer `calibrate` verbs on architect/chiropractor) — spec §6
  names it future work.
- Deployed-project migration: existing hosts pick up `ROUTING.md`/`setup`/the table via
  `/foreman migrate` or the next `calibrate` pass; no host repo is touched by this plan.
- `skill-builder` files: untouched (its `verbs/init.md` reference is the generic self-init
  convention, not foreman's verb).
