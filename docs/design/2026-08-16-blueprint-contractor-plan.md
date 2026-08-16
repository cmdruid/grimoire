# blueprint / contractor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split today’s `blueprint` into a drawings skill (`blueprint`: brainstorm / grill / spec / review) and a job-lead skill (`contractor`: roadmap / plan / runbook / review / build), wired into the pack and the stream templates.

**Architecture:** Two standalone skill packages. `blueprint` keeps the design-station verbs and `templates/spec.md` + `templates/adr.md`. `contractor` takes `templates/plan.md` + `templates/roadmap.md`, a copy of `ground-check.sh`, and new `runbook` / `build` procedures. Neither leaf names the other. `workstream` and the seed handbook compose them by artifact type.

**Tech Stack:** Portable `SKILL.md` packages; bash 3.2; existing `records.sh` on workshop hosts; `skills-lint.sh`.

**Spec:** `.scratch/contractor/NOTES.md` (settled notes). This plan locks the remaining defaults.

## Global Constraints

- `blueprint` verbs: `brainstorm`, `grill`, `spec`, `review`. Bare `/blueprint` → `brainstorm`.
- `contractor` verbs: `roadmap`, `plan`, `runbook`, `review`, `build`. Bare `/contractor` **requires a verb** (ask; do not guess).
- `grill` lives only on `blueprint`. Open plan branches → spec not settled, back to grill.
- Small work may stop at `blueprint spec` (spec doubles as the plan). `contractor` is for a second phase, declared blocking edges, or a tracer sequence you would dispatch. Small `contractor` path: `plan` → `review` → `build` — **no `runbook`**.
- Roadmap is never executable. `runbook` is a conductor. `build` walks a **plan** or a **runbook**, never a raw roadmap.
- Review before `build` (or a human). Runbook “review” is a cheap completeness check, not a second full `/contractor review` gate.
- Delegation is optional. `contractor` does not restate `/delegate` spawn/return. `contractor` does not `ship`, detect a stream, or name siblings in `description:`.
- Descriptions: trigger-only, ≤ ~700 chars, quote if they contain `: `, no sibling `/name`.
- Edges name types (`spec`, `plan`, `roadmap`, `runbook`), never sibling names.
- Self-contained: `contractor` **copies** `ground-check.sh` (do not call `blueprint`’s copy).
- `bootstrap` retirement is **out of scope**.
- Do not edit grimoire `AGENTS.md` except the one existing helper-roster line that already names `blueprint` (inventory, not a door block).
- Patient-zero: no workshop registration against this library’s real front door.
- Every task implicitly includes this section and the notes.

## Locked description drafts

**`blueprint`**

```
Use when the user runs `/blueprint`, or asks to brainstorm, grill, or write a spec for a feature or design. Turns an idea into an argued specification. grill is the interview primitive until every decision branch resolves. review critiques a spec or design doc (soundness + groundedness). Does not write roadmaps or implementation plans and does not build. For a one-line patch, skip it (fix on the trunk).
```

**`contractor`**

```
Use when the user runs `/contractor`, or asks to write a roadmap, implementation plan, or runbook, to review one of those, or to execute a plan or runbook. One job: sequence work from an approved spec, optionally delegate slices, walk the job. Never writes a spec. Never ships to trunk. For a one-line patch, skip it.
```

## File map

| Path | Responsibility |
|---|---|
| `skills/contractor/SKILL.md` | Router, verbs table, seams, edges |
| `skills/contractor/verbs/roadmap.md` | Moved/adapted from current `blueprint` roadmap section |
| `skills/contractor/verbs/plan.md` | Moved/adapted from current `blueprint` plan section |
| `skills/contractor/verbs/runbook.md` | New conductor procedure |
| `skills/contractor/verbs/review.md` | Plan/roadmap/runbook critique (not spec) |
| `skills/contractor/verbs/build.md` | Execute a plan or runbook |
| `skills/contractor/templates/plan.md` | Move from `skills/blueprint/templates/plan.md` |
| `skills/contractor/templates/roadmap.md` | Move from `skills/blueprint/templates/roadmap.md` |
| `skills/contractor/scripts/ground-check.sh` | Copy of blueprint’s script; header says contractor |
| `skills/blueprint/SKILL.md` | Drop roadmap/plan/build-handoff; new description; edges `spec` |
| `skills/blueprint/docs/ideal-use.md` | Arc ends at approved spec |
| `skills/blueprint/templates/` | Keep `spec.md`, `adr.md` only |
| `skills/clankshop/PACK.md` | Add `contractor`; bump `2.1.0` → `2.2.0` |
| `README.md` | Inventory rows |
| `skills/clankshop/seed/core/ROUTING.md` | Compose blueprint then contractor |
| `skills/clankshop/seed/build/workflows/feature.md` | Same composition |
| `skills/workstream/flow.md`, `verbs/create.md`, `verbs/sync.md`, `templates/*` | Plan/build pointers → `/contractor`; spec stays `/blueprint` |

---

### Task 1: Stand up `skills/contractor/`

**Files:**
- Create: `skills/contractor/SKILL.md`
- Create: `skills/contractor/verbs/{roadmap,plan,runbook,review,build}.md`
- Create: `skills/contractor/templates/plan.md` (copy then delete from blueprint in Task 2)
- Create: `skills/contractor/templates/roadmap.md` (same)
- Create: `skills/contractor/scripts/ground-check.sh`

**Interfaces:**
- Consumes: type `spec` (a path the user names)
- Produces: types `roadmap`, `plan`, `runbook`; `build` executes a plan or runbook
- Blueprint still has the source templates until Task 2 — copy, do not `git mv` yet if that confuses Task 2’s shrink; **prefer `git mv`** so history follows, then Task 2 only deletes leftovers if any

- [ ] **Step 1: Copy templates and ground-check**

```bash
mkdir -p skills/contractor/verbs skills/contractor/templates skills/contractor/scripts
git mv skills/blueprint/templates/plan.md skills/contractor/templates/plan.md
git mv skills/blueprint/templates/roadmap.md skills/contractor/templates/roadmap.md
cp skills/blueprint/scripts/ground-check.sh skills/contractor/scripts/ground-check.sh
```

Edit the copy’s header comment: replace `/blueprint's plan gate` with `/contractor plan gate`. Do not change the script’s behavior.

- [ ] **Step 2: Write `skills/contractor/SKILL.md`**

Thin router. Must include:

- Frontmatter `name: contractor` and the locked description above (quoted).
- One-paragraph job: one job lead; drafts the bid and walks it; never writes a spec; never ships.
- The one workshop probe (copy the probe block from `skills/blueprint/SKILL.md` *One environment probe*, but summon **build** station for `roadmap` / `plan` / `runbook` / `build`, and **build** station for `review` of those artifacts). Template deploy: `templates/plan.md` → `plans.md`, `templates/roadmap.md` → `plans.md` (same store; two templates). Add `templates/runbook.md` only if you introduce a runbook template in Step 4 — otherwise runbook is a `plans/` record whose body is the conductor list (title + ordered steps). Prefer **no new template file** unless the plan/roadmap templates cannot host a short conductor body: write runbooks as `plans/` records with a heading `## Runbook` and an ordered list.
- Verb dispatch table (every verb file backticked as `verbs/<verb>.md`):

| Invocation | Verb file | Does |
|---|---|---|
| `roadmap` | `verbs/roadmap.md` | multi-phase map |
| `plan` | `verbs/plan.md` | tracer-bullet plan |
| `runbook` | `verbs/runbook.md` | compile conductor |
| `review` | `verbs/review.md` | critique roadmap/plan/runbook |
| `build` | `verbs/build.md` | execute plan or runbook |
| (bare) | — | **ask** which verb; do not default |

- Hard seams (verbatim intent from Global Constraints): no sibling names; no ship; optional delegate; review before build; never execute a raw roadmap.
- Edges:

```
<!-- edges:contractor -->
- produces: plan, roadmap, runbook — job artifacts in plans/ (workshop) or the output home
- handoff: — (build executes in-place; ship is not this skill)
- consumes: spec — an approved specification the user names
<!-- /edges:contractor -->
```

- [ ] **Step 3: Write `verbs/roadmap.md` and `verbs/plan.md`**

Move the procedures from `skills/blueprint/SKILL.md` sections `## roadmap` and `## plan` (the numbered steps, template pointers, workshop vs standalone writes). Adapt:

- Replace `/blueprint` with `/contractor` only for **this** skill’s verbs.
- Terminal step of `plan` is **`review` then `build`**, not “hand off to the host’s build lane” as the only ending — the lane/`workstream` still `ship`s; `build` walks slices.
- `plan` still runs `scripts/ground-check.sh` (this package’s copy).
- `roadmap` still forbids task-level detail and still requires a `plan` per phase before that phase can be built.
- Do not mention `blueprint` by name. Say “an approved spec” and “open decision branches belong in a grill on the spec, not here.”

- [ ] **Step 4: Write `verbs/runbook.md`**

Procedure:

1. Resolve input: a **plan** path or a **roadmap** path. Missing → ask. A spec is refused (“that is not a job conductor input”).
2. **From a plan:** emit a `plans/` record (workshop: `records.sh new plans --title "Runbook: <plan title>"`) or a file in the standalone output home. Body: ordered steps copied from the plan’s slices — command/gate/path only, no approach essay. Each step names the slice id it came from.
3. **From a roadmap:** same record shape. Body: ordered unblocked phases; each line is “obtain or write the phase plan, then build it.” Do not inline task-level work.
4. Completeness check (this **is** the runbook review): every phase/slice has a pointer; order respects `requires:`; no raw implementation steps invented. Fail → fix the runbook or send the human back to `plan`/`roadmap`. Do not run the full `review` rubric.
5. Done when the conductor file exists and the check is green.

- [ ] **Step 5: Write `verbs/review.md`**

Take `skills/blueprint/SKILL.md` section `## review` and **delete** the spec/design-only parts (substrate-skeptic as a required spec pass may stay as optional if a plan claims a mechanism — default off). Keep: kind detect among roadmap/plan/runbook only; refuse a spec (“wrong review verb”). Axes: tracer slices, blocking edges acyclic, HEAD re-verify via `scripts/ground-check.sh` + re-read, verification can go red, numeric targets attributed. Verdict in context; `needs-rework` writes a Review history section on the artifact.

- [ ] **Step 6: Write `verbs/build.md`**

Procedure:

1. Resolve input: a **plan** or a **runbook**. A raw **roadmap** → refuse; tell the caller to `runbook` it first (describe the artifact type, do not name a sibling skill).
2. Confirm `review` has passed or the human waives it. If unknown, run `review` (plan) or the runbook completeness check first.
3. **Plan:** walk slices in declared order. Per slice: do it yourself **or** write a self-contained brief and use the host’s delegation mechanism (do not restate spawn flags). After each slice: the slice’s verify command. Do not `ship`.
4. **Runbook:** walk the conductor list. Each “build this plan” is a nested plan-walk (step 3). Phase gate must pass before the next phase.
5. Status: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED — contractor’s own assessment of the **job**, not a git-land.
6. Done when every step/slice in scope has a verify result or an explicit skip the human accepted.

- [ ] **Step 7: Lint the new package in isolation**

```bash
# bundled refs inside contractor must resolve
python3 - <<'PY'
from pathlib import Path
import re
root = Path("skills/contractor")
needles = re.compile(r'`((?:scripts|templates|verbs|references|briefs|docs)/[^`]+)`')
missing = []
for md in root.rglob("*.md"):
    for m in needles.finditer(md.read_text()):
        if not (root / m.group(1)).exists():
            missing.append(f"{md}: {m.group(1)}")
print("ok" if not missing else "\n".join(missing))
raise SystemExit(1 if missing else 0)
PY
bash -n skills/contractor/scripts/ground-check.sh
```

Expected: `ok`; `bash -n` silent.

- [ ] **Step 8: Commit**

```bash
git add skills/contractor skills/blueprint/templates
git commit -m "$(cat <<'EOF'
contractor: new job-lead skill (roadmap/plan/runbook/review/build)

Takes plan+roadmap templates from blueprint. Copies ground-check.sh.
Does not shrink blueprint's SKILL.md yet.
EOF
)"
```

---

### Task 2: Shrink `blueprint`

**Files:**
- Modify: `skills/blueprint/SKILL.md`
- Modify: `skills/blueprint/docs/ideal-use.md`
- Modify: `skills/blueprint/scripts/ground-check.sh` (header only, still used by spec/review)
- Test: no `roadmap`/`plan` procedures left in `SKILL.md`; templates dir is spec+adr only

**Interfaces:**
- Consumes: Task 1’s move of plan/roadmap templates
- Produces: `blueprint` produces/handoff `spec` only

- [ ] **Step 1: Rewrite `SKILL.md` frontmatter and spine**

- Set `description:` to the locked blueprint draft (quoted).
- Title stays “the planning spine” **for drawings only**, or retitle “the specification spine” if “planning spine” now overclaims — prefer **specification spine**.
- Delete verb-table rows and sections for `roadmap` and `plan`.
- `review` section: specs and design docs only; refuse a plan/roadmap (“wrong artifact for this review”).
- Terminal step of `spec`: human gate; then **stop**. Do not say “proceed to plan.” Say the accepted spec is the artifact; implementation sequencing is a different job (no sibling name).
- Workshop probe: design station only. Templates: `spec.md` → `design.md`, `adr.md` → `adr.md`.
- Composition paragraph: the orchestrator / host lane consumes the spec. Do not name `contractor` or `workstream`.
- Edges:

```
<!-- edges:blueprint -->
- produces: spec — argued specification (design/ store or output home)
- handoff: spec — the accepted spec is the baton
- consumes: — (conversation or a draft the user names)
<!-- /edges:blueprint -->
```

- [ ] **Step 2: Rewrite `docs/ideal-use.md`**

Stop the worked arc after approved `spec`. Delete step 3 (`plan`). Last line: the spec is the terminal blueprint artifact.

- [ ] **Step 3: Confirm no dangling bundled refs**

```bash
test ! -e skills/blueprint/templates/plan.md
test ! -e skills/blueprint/templates/roadmap.md
ls skills/blueprint/templates/
# expect: adr.md spec.md
```

Grep `skills/blueprint` for `roadmap` / `plan [` / `/blueprint plan` in procedure (templates/spec.md may still say a small spec may double as a plan — **keep that sentence**).

- [ ] **Step 4: Commit**

```bash
git add skills/blueprint
git commit -m "$(cat <<'EOF'
blueprint: drop plan/roadmap; spec spine only

Review refuses job artifacts. Ideal-use ends at the accepted spec.
EOF
)"
```

---

### Task 3: Pack, inventory, composition, gate

**Files:**
- Modify: `skills/clankshop/PACK.md` (optional list + roster + version `2.2.0`)
- Modify: `README.md` (skills table + helpers sentence)
- Modify: `skills/clankshop/seed/core/ROUTING.md`
- Modify: `skills/clankshop/seed/build/workflows/feature.md`
- Modify: `skills/workstream/flow.md`
- Modify: `skills/workstream/verbs/create.md`
- Modify: `skills/workstream/verbs/sync.md`
- Modify: `skills/workstream/templates/design.md`
- Modify: `skills/workstream/templates/workstream-handoff.md`
- Modify: `AGENTS.md` only the existing helpers roster clause (`blueprint` the planner → keep blueprint, add contractor as the job lead) if that line already lists helpers
- Test: `skills/skill-builder/scripts/skills-lint.sh` → `fails=0`

**Interfaces:**
- Consumes: both skill packages from Tasks 1–2
- Produces: pack member `contractor`; stream/handbook compose spec vs job without putting sibling names in leaf descriptions

- [ ] **Step 1: PACK.md**

- `version: 2.2.0`
- `optional:` add `contractor` (keep `blueprint`)
- Roster table: helper `contractor` — one job: roadmap / plan / runbook / review / build
- Helper `blueprint` blurb: specification spine, not implementation plans
- Transition note: one sentence that `blueprint`’s plan/roadmap verbs moved to `contractor`

- [ ] **Step 2: README.md**

- Update the `blueprint` table row: ideation → argued spec; never plans or builds.
- Add `contractor` row (alphabetically after `clankshop` / before `debugger`): one job lead — roadmap, plan, runbook, review, build; never ships; never writes a spec.
- Helpers sentence: mention both.

- [ ] **Step 3: Seed + workstream composition**

Replace “`/blueprint` runs the planning spine (brainstorm → spec → roadmap/plan)” with: design-at-stake → `/blueprint` (spec); job sequencing and walking → `/contractor` (plan / runbook / build). `workstream` flow PLAN stage: `/blueprint spec` then `/contractor plan`. Build stage: `/contractor build` (stream still `ship`s). `sync.md` “`/blueprint review`” for a **plan** → `/contractor review`. Keep `/blueprint` for specs.

Do **not** add those names to `blueprint` or `contractor` descriptions.

- [ ] **Step 4: `./install.sh contractor`** (symlink; not committed)

- [ ] **Step 5: Lint + description sibling check**

```bash
bash skills/skill-builder/scripts/skills-lint.sh
```

Expected: `fails=0`. No `FAIL` on `contractor` or `blueprint`. A sibling-in-description WARN on either skill is a **bug** — fix the description. Single-use edge types may WARN (`runbook` if unmatched) — acceptable if the type string is intentional.

- [ ] **Step 6: Routing probe (descriptions only)**

Cold-router, at least these cases (record in `docs/boundary-audit.md` as a dated entry):

| prompt | expects |
|---|---|
| brainstorm this feature | `blueprint` |
| grill the spec until the forks close | `blueprint` |
| write the specification for this design | `blueprint` |
| review this spec for soundness | `blueprint` |
| write an implementation plan | `contractor` |
| draft a roadmap of phases | `contractor` |
| compile a runbook from this plan | `contractor` |
| execute the implementation plan | `contractor` |
| review this tracer-bullet plan | `contractor` |
| ship this stream to main | `workstream` |
| hand this slice to a cheaper model | `delegate` |

If a case fails, sharpen the **description** (self-scope), do not add sibling names.

- [ ] **Step 7: Commit**

```bash
git add README.md AGENTS.md docs/boundary-audit.md \
        skills/clankshop/PACK.md \
        skills/clankshop/seed \
        skills/workstream
git commit -m "$(cat <<'EOF'
clankshop 2.2.0: add contractor; compose blueprint vs job lead

Seed and workstream PLAN/build pointers split. Lint fails=0.
EOF
)"
```

---

## Spec coverage

| Notes / default | Task |
|---|---|
| Split, names, grill-only-on-blueprint | 1, 2 |
| Contractor verbs including runbook + build | 1 |
| Small-work stop at spec; no forced contractor | 2 ideal-use + descriptions |
| Review-before-build; runbook cheap check | 1 verbs/build.md, runbook.md |
| Optional delegate; no ship; no stream detect | 1 SKILL.md seams |
| Typed edges, no sibling descriptions | 1, 2, 3 probe |
| Pack / README / handbook / workstream compose | 3 |
| bootstrap out of scope | Global Constraints |

## Out of scope

- Retiring `bootstrap` or adding `blueprint land`
- `contractor ship`
- `agent-council` feature brief (plan docs are not a v1 council target)
- Rewriting `delegate` or `workstream` loop mechanics beyond citation updates
