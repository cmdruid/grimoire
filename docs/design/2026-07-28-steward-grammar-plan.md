# Steward Grammar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `docs/design/2026-07-27-steward-grammar.md` §6 — per-layer `calibrate` verbs
on chiropractor and architect, foreman's calibrate rescoped to classify-and-dispatch, the
clankshop seam rows, and the routing-probe gate.

**Architecture:** Prose/skills repo — markdown edits across three skills plus the runbook. The
drains all consume the `tracker-entry` type (no new types); chiropractor's is optional-input so
its portability survives; architect's stays sharp against `distill`; foreman's composer hat does
the classification.

**Tech Stack:** Markdown. Gate: `bash skills/skill-builder/scripts/skills-lint.sh .` from the repo
root → `fails=0` with the same 11 pre-existing warns (a NEW warn — e.g. description-length from
this plan's description edits — is a task failure to fix, not accept).

## Global Constraints

- Working directory `/Users/cscott/Repos/grimoire`, branch `main`. Pathspec-scoped commits
  (`git add -- <paths> && git commit -m "<msg>" -- <paths>`); no `Co-Authored-By` trailers.
- `docs/design/*.md` are historical records — only `2026-07-27-steward-grammar.md` (status line,
  Task 5) may change.
- **Chiropractor stays fully generic:** its files never name another skill, `foreman`,
  `ROUTING.md`, `backlog`, `grimoire`, or `clankshop`. It consumes the *type* `tracker-entry` and
  speaks of "a tracker the repo's own front door names."
- **Foreman's calibrate may name companion skills** in its *Relationship* section (existing
  pattern) but the classification/dispatch prose speaks of "the installed doc-spine steward" /
  "the design steward" with by-hand fallbacks — never a hardcoded sibling in the procedure.
- Cited line numbers are pre-plan snapshots; locate every edit by quoted content.

---

### Task 1: Chiropractor gains `calibrate` (optional-input drain)

**Files:**
- Modify: `skills/chiropractor/SKILL.md` (description; a Verbs note after Overview; a new
  `## Calibrate` section before `## Boundaries`; the `## Edges` block + its intro paragraph)

**Interfaces:**
- Produces: the verb name `calibrate`, the consumed type `tracker-entry (optional)` — Tasks 3–4
  reference both.

- [ ] **Step 1: Extend the frontmatter description**

Append to the existing `description:` (keep everything before it byte-identical):

```
Also `/chiropractor calibrate`: drain captured doc-flavored dev-experience signal (tracker entries about the docs, or entries handed inline) into targeted spine fixes.
```

- [ ] **Step 2: Add the verb-dispatch note**

Insert after the `## Overview` paragraph (before `## When to Use`):

```markdown
**Verbs.** Bare `/chiropractor` (or `audit`) runs the adaptive flow below — the default.
`/chiropractor calibrate` is the drain verb (see *Calibrate*, below): captured doc-flavored
signal in, targeted fixes out, reusing the same diagnose → adjust machinery.
```

- [ ] **Step 3: Add the Calibrate section**

Insert immediately before `## Boundaries`:

```markdown
## Calibrate — drain doc-flavored signal

`calibrate` turns captured dev-experience signal *about the docs* — "the front door is bloated,"
"I couldn't find X," "doc Y contradicts doc Z" — into targeted spine fixes, reusing the audit
machinery: each signal entry becomes a focused diagnosis (which rubric dimension does it
indict?), then a normal Adjust with the usual confirmation gate.

**Signal source — an optional ladder, portability preserved:**

1. A **tracker the repo's own front door names** (a feedback/issues store): read it and take the
   slice that is about the docs. Entries are consumed by content; this skill assumes no
   particular tracker shape or owner.
2. **Entries handed inline** in the invocation ("calibrate: the onboarding path loses agents at
   the third hop").
3. **Neither present:** report "no captured signal found" and offer the plain audit instead. A
   repo with no trackers loses nothing.

**The pass:** (1) collect the doc-flavored slice; (2) for each entry, map it to the dimension(s)
it indicts and confirm against the current spine (scan facts or a targeted read) — a complaint
may already be fixed, or may indict doctrine content rather than doc form (out of scope; hand it
back to the caller); (3) batch the confirmed items into Adjust (mechanical vs. structural, same
gates); (4) record, per entry acted on, what changed — the caller clears or updates the source
entries (this skill does not curate another store). Re-scan to verify, as Adjust always does.
```

- [ ] **Step 4: Update the Edges block and its intro**

In the paragraph above the block, replace the sentence `All three edges are a *stated* empty
(model §2.3), not an omission.` with:

```
Produces and handoff are a *stated* empty (model §2.3), not an omission; `calibrate` adds the one
optional consumes.
```

Replace the block's consumes line:

```markdown
- consumes: tracker-entry (optional) — `calibrate` drains captured doc-flavored signal when a tracker exists; the audit flow consumes nothing
```

- [ ] **Step 5: Verify generic phrasing, lint, commit**

```bash
grep -n 'foreman\|ROUTING\|grimoire\|clankshop\|backlog\|/architect\|/feature' skills/chiropractor/SKILL.md
```
Expected: no output.

```bash
bash skills/skill-builder/scripts/skills-lint.sh .
git add -- skills/chiropractor/SKILL.md && git commit -m "chiropractor: calibrate verb -- optional-input drain for doc-flavored signal" -- skills/chiropractor/SKILL.md
```

---

### Task 2: Architect gains `calibrate` (distinct from `distill`)

**Files:**
- Create: `skills/architect/verbs/calibrate.md`
- Modify: `skills/architect/SKILL.md` (description; Verbs table; Edges block),
  `skills/architect/verbs/distill.md` (one seam line after the intro paragraph)

**Interfaces:**
- Consumes: the `tracker-entry` type name (same as Task 1).
- Produces: the verb name `calibrate` and the distill/calibrate seam sentence Tasks 3–4 echo.

- [ ] **Step 1: Create `skills/architect/verbs/calibrate.md`**

```markdown
# `/architect calibrate` — drain design-flavored signal into the seed

Fold captured dev-experience signal *about the seed* — a spec that repeatedly misleads builds, a
contract complaint, a "this tenet fights reality" observation — into targeted seed edits. The
signal source is the host's trackers (the dev-experience/issues stores the front door names),
consumed as entries by content; the slice that belongs here is the one whose fix would edit
**the seed** (a spec, a contract, PHILOSOPHY) rather than code or process doctrine.

**`calibrate` ≠ `distill`, kept sharp:** `distill` compacts the seed's *own accretion* (ADRs/plans
already in the record stores) into clean present-tense specs; `calibrate` absorbs *external
signal* (tracker entries about dev experience with the seed). One compresses inward, the other
absorbs inward. The editing discipline is shared: hand-edit, never bulk; the seed stays
regenerable; the durability gradient (`docs/DOCTRINE.md`) governs what may change.

## The pass

1. **Harvest the design slice.** Read the host's dev-experience/issues trackers (locations per
   the host's front door / ownership index) for entries whose fix would edit the seed. One
   complaint is a note; a pattern (the same spec misleading twice) is a calibration.
2. **Confirm against the seed.** Read the indicted spec/tenet. The entry may be stale (the seed
   already fixed), may indict the *code* (that is drift — `reconcile`'s finding, not a seed
   edit), or may indict process doctrine (not this skill's layer; hand it back to the caller).
3. **Edit, scoped by the gradient.** A confirmed miscalibration becomes a targeted edit: a
   `src/<system>.md` spec sharpened, a contract clarified, a `PHILOSOPHY.md` tenet amended
   (highest stakes — propose, never silently rewrite). Anything bigger than a targeted edit
   routes to `brainstorm`/`plan` as a design campaign.
4. **Record the outcome.** For each entry acted on, note the resolution so the caller can clear
   the source entry; log the pass alongside the seed's other change-records. Run the host's gate.

## Done when

The recurring design-flavored signal has become concrete seed edits (or a routed campaign), each
acted-on source entry has its resolution recorded, and the seed still passes `check`.
```

- [ ] **Step 2: Add the Verbs-table row** (after the `distill` row)

```markdown
| `calibrate` | `verbs/calibrate.md` | drain captured design-flavored signal (tracker entries about the seed) into targeted seed edits |
```

- [ ] **Step 3: Extend the description**

In the frontmatter `description:`, insert after the sentence ending `…collapses accreted
ADRs/plans into clean present-tense specs.`:

```
`/architect calibrate` drains captured design-flavored dev-experience signal into targeted seed edits (external signal in; `distill` compacts internal accretion).
```

- [ ] **Step 4: Update the Edges block**

Replace the consumes line inside `<!-- edges:architect -->`:

```markdown
- consumes: design, tracker-entry — `distill`/`reconcile` read architect's own accreted specs (intra-skill: same skill on both ends); `calibrate` drains captured design-flavored signal
```

(The paragraph below the block about excluding the intra-skill `design` pair stays as-is — it
still applies to `design` only.)

- [ ] **Step 5: One seam line in distill.md**

After `verbs/distill.md`'s intro paragraph (ends `…never code).`), append to that paragraph:

```
*(Seam: `distill` compacts the seed's own accretion; external tracker signal is `calibrate`'s to absorb.)*
```

- [ ] **Step 6: Lint, commit**

```bash
bash skills/skill-builder/scripts/skills-lint.sh .
git add -- skills/architect && git commit -m "architect: calibrate verb -- drain design-flavored signal into the seed (distinct from distill)" -- skills/architect
```

---

### Task 3: Foreman's calibrate — classify by layer, dispatch the other slices

**Files:**
- Modify: `skills/foreman/verbs/calibrate.md` (step 2 tail; the `/chiropractor` bullet in
  *Relationship to neighboring verbs & skills*)

**Interfaces:**
- Consumes: the existence of drain verbs on the two stewards (Tasks 1–2); the dispatch prose
  names layers + "the installed steward's drain verb," not skill names.

- [ ] **Step 1: Add the classification to step 2**

In `## The pass`, step 2 ends with `…the same friction three times is a doctrine miscalibration.`
Append to that step:

```markdown
   **Classify each entry by the layer its fix would edit** — this verb wears foreman's composer
   hat here, same as `route`: **operational** (a routing rule, workflow doctrine, the front
   door's wiring/table, MEMORY/GOTCHAS) → this pass acts on it in step 3; **doc-form**
   (front-door bloat, navigation, a spine that loses agents) → dispatch to the installed
   doc-spine steward's own drain verb, else the by-hand fallback (fix per the deployed docs);
   **design-seed** (a spec/contract/tenet that misleads) → dispatch to the installed design
   steward's drain verb, else the fallback. Mixed entries split; unclassifiable entries stay
   here (the default owner).
```

- [ ] **Step 2: Replace the `/chiropractor` relationship bullet**

Replace:

```markdown
- **`/chiropractor`** owns general doc-spine *ergonomics* for any repo (front-door bloat, navigation,
  glossaries). `calibrate` stays scoped to *this system's* doctrine; hand broad doc-tuning to
  `/chiropractor`.
```

with:

```markdown
- **`/chiropractor`** owns doc-spine *ergonomics*; **`/architect`** owns the design seed.
  `calibrate` classifies the harvested signal by layer (step 2) and **dispatches** the doc-form
  and design-seed slices to those stewards' own drain verbs — it acts only on the operational
  slice itself.
```

- [ ] **Step 3: Lint, commit**

```bash
bash skills/skill-builder/scripts/skills-lint.sh .
git add -- skills/foreman/verbs/calibrate.md && git commit -m "foreman(calibrate): classify harvested signal by layer; dispatch doc-form and design-seed slices" -- skills/foreman/verbs/calibrate.md
```

---

### Task 4: Clankshop — the drain seam rows + vocabulary

**Files:**
- Modify: `packs/clankshop.md` (two new seam rows; two amended rows; the typed-edge vocabulary
  table)

**Interfaces:**
- Consumes: Tasks 1–3's verb names and the `tracker-entry (optional)` phrasing.

- [ ] **Step 1: Add two seam rows** (after the `backlog ↔ debugger` row)

```markdown
| `backlog` ↔ `chiropractor` | `backlog` **captures**; `chiropractor calibrate` **drains** the doc-flavored slice into spine fixes — optional input, the audit runs with or without trackers. Capture vs. doc-drain. | **dep** — `chiropractor` reads `backlog`'s `tracker-entry` (optional) |
| `backlog` ↔ `architect` | `backlog` **captures**; `architect calibrate` **drains** the design-flavored slice into targeted seed edits (`distill` compacts internal accretion; `calibrate` absorbs external signal). Capture vs. design-drain. | **dep** — `architect` reads `backlog`'s `tracker-entry` |
```

- [ ] **Step 2: Amend the `foreman ↔ chiropractor` row's contract cell**

Append to the cell (after `…none authors another's part.`):

```
`foreman calibrate` classifies harvested signal by layer and **dispatches the doc-form slice** to `chiropractor calibrate` — the drain split.
```

- [ ] **Step 3: Amend the `architect ↔ foreman` row's contract cell**

Append to the cell (after `Design vs. operation.`):

```
The drain split mirrors it: `foreman calibrate` dispatches the design-seed slice of harvested signal to `architect calibrate`.
```

- [ ] **Step 4: Update the vocabulary table's `tracker-entry` row**

Replace the consumed-by cell:

```
`foreman` (calibrate), `debugger` (investigate), `architect` (calibrate), `chiropractor` (calibrate, optional)
```

- [ ] **Step 5: Lint, commit**

```bash
bash skills/skill-builder/scripts/skills-lint.sh .
git add -- packs/clankshop.md && git commit -m "clankshop: drain seam rows -- per-layer calibrate verbs consume tracker-entry" -- packs/clankshop.md
```

---

### Task 5: Gate — derive-seams, routing probe, design-doc status

**Files:**
- Modify: `docs/design/2026-07-27-steward-grammar.md` (Status line only)

- [ ] **Step 1: Full lint + seam derivation**

```bash
bash skills/skill-builder/scripts/skills-lint.sh .
bash skills/foreman/scripts/foreman-health.sh derive-seams skills
```
Expected: lint `fails=0`, same 11 warns; derive-seams `deps:` now includes
`chiropractor reads backlog's tracker-entry` and `architect reads backlog's tracker-entry`.

- [ ] **Step 2: Routing probe (design §5 gate)**

Build a descriptions-only fixture (name + `description:` frontmatter of every `skills/*/SKILL.md`)
and dispatch a **fresh subagent** with ONLY that fixture and these prompts, one pick each:

1. "Fold this feedback into the docs." → expected `chiropractor`
2. "The design keeps misleading us — fix the spec." → expected `architect`
3. "Calibrate the dev system." → expected `foreman`
4. "The workflow keeps tripping me — fix the doctrine." → expected `foreman`

A mis-route fails the gate; the fix is sharper self-scoping in the offending `description:`
(never a cross-reference), then re-probe.

- [ ] **Step 3: Mark the design implemented, commit**

Replace the design doc's Status line with:
`**Status:** Implemented (<date from \`date +%Y-%m-%d\`>); routing probe <N>/4.`

```bash
git add -- docs/design/2026-07-27-steward-grammar.md && git commit -m "docs(design): mark steward grammar implemented (routing probe N/4)" -- docs/design/2026-07-27-steward-grammar.md
```

---

## Deliberately out of scope

- Deployed hosts' registered route blocks (e.g. atelier's architect/chiropractor blocks now
  understate edges) — refreshed by each skill's next re-register; BL-16 governs stamp policy.
- `auditor` gaining a drain: its findings already drain via foreman (the `audit-finding` dep);
  no new cell in the design's grammar table.
