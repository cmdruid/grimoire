---
doctype: design
status: published
created: 2026-08-21
updated: 2026-08-22
tags: [spec]
---

# architect / contractor / inspector — Spec

This library's design home is `docs/design/` (patient-zero). This
spec lives here. Feature spec, not a skill-builder authoring
contract.

Depends on `docs/design/2026-08-21-records-status-stage.md` (journal
`status` / `stage`). Do not implement this file ahead of that
contract.

Settled 2026-08-21 in conversation. Capture of the remaining
workshop-shape work: rename, extract, kind templates, and the
gate. Later reversals in the same conversation (no review records,
no finding-list write-back) win over earlier turns.

## Problem

Three jobs share two packages, and the names do not match the
jobs.

`blueprint` is an artifact word. `contractor` is an actor. Daily
prose (“ask blueprint to review the spec”) fails the test
`/contractor review` already passes. The design station’s old
persona name `architect` is being gutted from `clankshop`; it is
free for the spec skill.

`review` and `revise` live on both author skills. `/blueprint spec`
then `/blueprint review` is the author wearing a judge badge.
“Review is not the author” is a paragraph, not a package
boundary. The two review procedures were split on purpose (spec
axes vs plan axes) but the *machine* — dump, fold, named
re-review — is one.

`build` gates on a Review-history stamp (`approve` /
`needs-rework`). An independent agent does not understand
`needs-rework`; they understand `draft`. Multiple review passes
must not mint a document per pass.

## Goal

Three actor skills, one job each:

| skill | job | verbs |
|---|---|---|
| `architect` | design | `brainstorm`, `grill`, `spec`, `new`, `deploy` |
| `contractor` | implementation | `roadmap`, `plan`, `runbook`, `build` |
| `inspector` | critique and fold | `review`, `refine` |

Inspector owns **both** artifact sets (specs / ADRs / founding, and
plans / roadmaps / runbooks). Kind-detect, then the matching
judgment. Hosts may **add** kinds.

The durable gate is the records contract, not a verdict stamp.
Review writes **no** finding list and **no** review record. Losing
a review is acceptable; re-run it. `refine` folds from the
session (propose-then-apply, already shipped) and leaves the
artifact `draft` until it is published again.

## Approach

**Chosen: rename `blueprint` → `architect`.** Mechanical. Cut the
`/blueprint` alias — a shim is a second name to explain; this
library already paid that cost (`feature` → `blueprint`).
Historical design docs keep the old name as the name that
shipped.

**Chosen: extract `review` / `revise` from both packages into
`inspector`.** `revise` is renamed **`refine`** (the workflow
word used with the status gate). Named re-review stays
*inside* inspector, which is the natural home now that both
verbs live there. The 2026-08-20 propose-then-apply machine
moves with the verb; it is not redesigned.

**Chosen: kind templates, not a mushed rubric.** Bundled in the
inspector package. Project copies at
`<agent-workspace>/inspector/<kind>.md` (default
`.dev/inspector/<kind>.md`). That path is a **fifth landing
class** next to doctrine’s four (records, templates, doctrine,
hooks) — undated judgment, not mint shells, not records, not
the audit rubric. No new front-door variable. Incumbent wins;
upgrade is a judgment-assisted diff. Missing copies are not a
refuse — use the bundle. Inspector may `mkdir` that subpath
when `<agent-workspace>` already exists or is the derived
default `.dev` (same narrow rule as hooks). This is **not**
auditor: inspector must work on the first invoke with no
`setup`. Amend
`skills/skill-builder/docs/DOCTRINE.md` *Which home* in
Slice 2.

**Chosen: templates are not records and not mint shells.** They
are undated judgment. They do **not** live under
`<agent-records>`. They do **not** use
`<agent-workspace>/templates/<skill>/<doctype>.md` (that path
is `records.sh new`). A new kind is a new file plus a
discriminator (`tags:` / `doctype` / shape). No matching
template → ask or refuse; do not invent a rubric.

**Chosen: no review documents.** Not a `reviews/` store, not a
Review-history finding list on the artifact. Conversation
holds the list until `refine` applies edits. The artifact’s
`status` / `stage` are the only durable write from this
loop.

**Chosen: inspector approves; the caller publishes.** Passing
`review` dumps the verdict in conversation and **waits**.
The verdict turn does not write `status:` / `stage:`.
Failing `review` stops on `draft`. On **accept** of a
passing verdict, the same session (the caller) writes
`published` (and `stage: approved` on job artifacts), then
stops again. `proceed` / a request to sequence or walk
counts as accept — write first, then the rest of that
utterance. Founding-shaped stays `draft`. A `build` waive
is the same write by the caller, noted in conversation.
Verdict words stay **conversation-only**. Inspector `refine`
still leaves `draft` (and drops `stage: approved`).

**Rejected: inspector for plans only.** The extract is from both
skills; spec review staying on architect recreates the author-
as-judge hole on the spec side.

**Rejected: auditor-style thin driver + required `setup`.**
Document review must work standalone.

**Rejected: kind templates under doctrine/test/audit.** That home
is the code-quality rubric.

**Rejected: `rejected` as a `stage` value.** Failing review →
`draft`. Abandonment → `archived` + ledger `dropped`.

**Rejected: journal uniqueness of published specs.** Architect
*may* keep “one published spec per subject” as writer prose.
Journal does not enforce it.

**Assumed, not this spec:** `clankshop` persona summons go away.
This rename does not wait on that gutting, and does not edit
persona machinery except live `/blueprint` pointers in seed
routing / workstream flow.

## Mechanism

### Pipeline (visible from every door)

```
spec  →  review  →  publish              →  (host sequences / plan)
                 →  stay draft           →  refine  →  review  →  …
plan  →  review  →  publish              →  build
                 →  stay draft           →  refine  →  review  →  …
```

Each arrow is a stop. No verb invokes the next, except an
inspector `refine` confirmation that asks for `review` after
apply (named re-review, already shipped).

`publish` is not a new verb. It is the calling session
writing front-matter on **accept** of a passing inspector
verdict (inspector `review` confirm-parse), or a `build` /
`plan` waive of that gate. Review’s first stop is the
verdict (pass or fail). The publish write is the next stop
on accept — same session, not a later unnamed duty.

### `status` / `stage` (writers)

Per the journal spec. This file owns **writer values** only.

**Specs, ADRs, founding (architect mints; caller publishes after
inspector approval):**

- Mint `status: draft`. No `stage` required.
- Publish → `status: published`. Architect may, in prose, treat
  two published specs on the same subject as a writer error
  (supersede / archive the prior). Not a journal check.
- The spec usually stays `published` after the first cut.
  Later replacement is `archived` + ledger `superseded`.
- `plan` / `roadmap` require that spec `status: published`.
  Founding-shaped stays `draft` and is not that input. An
  explicit waive writes `published` on the spec, then
  sequences. It does not sequence against a `draft`.

**Plans, roadmaps, runbooks (contractor mints; caller publishes
after inspector approval; contractor walks):**

- Mint `status: draft`. No `stage` yet.
- Publish → `status: published` and `stage: approved`.
- `build` requires `status: published` and, for a **plan**,
  `stage: approved`. `stage: implemented` is not a walkable
  gate. An explicit human waive writes that same gate
  (`published` + `stage: approved` on a plan) and notes the
  waive in conversation — it does not walk a `draft`.
- After a successful walk, contractor sets `stage:
  implemented`. The plan stays `published` (citable). Archive
  is a later close, not automatic.
- Roadmaps are never walked. Runbooks: completeness check
  additional; the referenced **plans** must each pass the plan
  gate.

**`build` refuse (replaces Review-history stamp):** latest
`status` is not `published`, or a plan’s `stage` is missing /
not `approved` / is `implemented`. Do not read a Review-history
verdict. Waive is a write of the gate, then walk — not a
walk of `draft`.

### Inspector `review`

Kind-detect from the artifact (`tags:` / `doctype` / shape /
founding-shaped parser), then load the kind template
(workspace copy if present, else bundle). Two-axis critique
as today, **axes from the template**. Verdict in conversation
(`approve` / `approve-with-changes` / `needs-rework` —
conversation-only). Do not amend. Do not mint a record. Do
not write Review history.

- **Failing** (`needs-rework`): stop. Leave `draft`. Do not
  write front-matter.
- **Passing** (`approve` or `approve-with-changes`): dump the
  verdict. Wait. Do not write front-matter in the verdict
  turn. On accept, this session writes `published` (and
  `stage: approved` on job artifacts), then stops.
  Founding-shaped: no write.

Unknown kind → ask or refuse.

Bundled kinds at ship: `spec`, `adr`, `founding`, `plan`,
`roadmap`, `runbook`. Hosts add files; they do not edit
journal.

### Inspector `refine`

Move the shipped propose-then-apply procedure from
`skills/contractor/verbs/revise.md` and (after Slice 1)
`skills/architect/verbs/revise.md` (live numbering, questions →
proposal → confirm → apply → stop-or-named-review). Package
deltas that today live in those files (grill-park vs spec-park,
founding mapped H2, job-aimed push-back) move into the **kind
template** so adding a kind does not fork the verb.

After apply: always leave `status: draft`; drop `stage:
approved` if it was present (a fold is unverified); offer
`review`. Do **not** copy the stamp-keyed After-confirm split
(`needs-rework` vs `approve-with-changes`) — those stamps are
gone. Named re-review runs `review` on the current file. No
skip-proposal token.

Findings baton: in-session list, a named markdown file, or
council `RESULT.md` — same shapes as today **except** “the
artifact’s Review history” is no longer a findings source
once stamps stop being written. Open Review-history blocks
already on disk are still readable until the next rewrite of
that file; do not require them.

### Kind template shape

One markdown file per kind. Minimum:

- discriminator (how to detect this kind)
- soundness axes
- groundedness extras (or “none beyond ground-check +
  re-read”)
- refine legal locations (what a `keep` may edit; what must
  park)

Inspector’s verb files own the shared machine (verdict words
in conversation, confirm parse — including the publish write
on accept of a passing review — and apply rules that are not
kind-specific). The verdict turn does not write `status:` /
`stage:`. Templates do not override those.

### Routing

Descriptions name no sibling `/name`. Triggers move:

- `architect` — `/architect`, brainstorm / grill / write a
  spec, founding `new` / `deploy`. Drop review / revise /
  “how should we revise a spec.”
- `contractor` — `/contractor`, roadmap / plan / runbook /
  execute. Drop review / revise / “how should we revise a
  plan.”
- `inspector` — `/inspector`, review a spec or plan (or
  named kind), how should we refine / revise this, apply
  review findings.

Bare `/architect` stays `brainstorm`. Bare `/contractor` and
bare `/inspector` **ask**.

### Pack, seed, streams

`clankshop` `PACK.md`: Slice 1 renames the member
`blueprint` → `architect` (no bump). Slice 4 adds
`inspector` and the minor bump (member set changed). Seed
`ROUTING.md` / `feature.md` and workstream PLAN lines:
`/architect spec`, then `/inspector review`, then
`/contractor plan` only when sequencing is required.

Independence: leaves still do not name each other. Composition
stays in the pack / flow.

### Out of scope

- Journal `status` / `stage` contract (the dependency spec).
- `skill-builder/specs/` registry (that spec).
- Implementing `clankshop` persona deletion.
- Auditor rubric. Council. Review records store.
- Changing `list` TSV width.

## Verification

**Mechanical**

- `git mv` leaves no `skills/blueprint/` tree.
- `test ! -e skills/blueprint`.
- `rg -n "/blueprint" skills/architect skills/contractor skills/inspector skills/clankshop/seed skills/workstream/flow.md skills/workstream/verbs skills/workstream/templates` — no live invoke hits (historical `docs/design/` exempt).
- `rg -n "verbs/review.md|verbs/revise.md" skills/architect skills/contractor` — no hits.
- Lint `fails=0`. Descriptions ≤ 1024, quoted if they contain
  `: `, no sibling `/name`.
- `test ! -e skills/architect/verbs/review.md` (and revise).
- Kind files exist for the six bundled kinds.
- `build` refuse tests (or a documented prose gate + a grep
  that the Review-history stamp gate is gone).

**Judgment**

- `/architect review` does not route. `/inspector review` on a
  spec and on a plan both kind-detect.
- A failing review leaves `draft` and stops; a passing review
  dumps the verdict and waits; on accept the same session
  writes `published` (jobs: + `stage: approved`). Founding-
  shaped stays `draft`. `plan` refuses a spec that is not
  `published` (waive is that write, then plan).
- `refine` does not write in the propose turn; after apply the
  file is `draft` again (no stamp-keyed offer).
- `build` on a `draft` plan refuses; a waive writes
  `published` + `stage: approved` then walks.
- A host-added kind with a discriminator is judged; an unknown
  kind is not invented.
- Standalone (no `<agent-workspace>/inspector/`) still reviews
  from the bundle.

## Slices

Sequence: journal contract landed first (other spec). Then:

- [ ] **Slice 1: rename `blueprint` → `architect`** <requires: —>
  - Paths: `git mv skills/blueprint skills/architect`;
    `SKILL.md` name + description + body invokes;
    `PACK.md` **rename member only** (no bump, no
    `inspector` yet); README + AGENTS.md inventory;
    seed / workstream: rename `/blueprint` → `/architect`
    only (do not insert `/inspector` yet).
  - Verify: no `skills/blueprint/`; live `/architect`; lint
    `fails=0`. Review/revise files still present (slice 3
    moves them). No live `/inspector` pointer yet.

- [ ] **Slice 2: stand up `inspector` package** <requires: Slice 1>
  - Paths: `skills/inspector/SKILL.md`;
    `verbs/review.md` (union of the two critique procedures
    behind kind-detect + templates; verdict only — caller
    publishes);
    `verbs/refine.md` (from `skills/architect/verbs/revise.md`
    and `skills/contractor/verbs/revise.md`; no stamp-keyed
    offer);
    bundled `kinds/<kind>.md` for the six kinds;
    `scripts/ground-check.sh` (copy, one);
    `skills/skill-builder/docs/DOCTRINE.md` *Which home*
    (fifth landing class: inspector kinds).
  - Verify: lint; kind files present; description routes
    review/refine; doctrine lists five destinations.

- [ ] **Slice 3: strip author skills** <requires: Slice 2>
  - Paths: `skills/architect/SKILL.md` (drop review/refine,
    pipeline, description);
    delete architect review/revise;
    `skills/contractor/SKILL.md` + delete
    `verbs/review.md` / `verbs/revise.md`;
    `build.md` gate → `status`/`stage`;
    stop author mint-time `published` writes (architect
    Status promotion / spec step 5 / templates / ideal-use;
    contractor `roadmap.md`).
  - Verify: grep absence of those verbs on author skills;
    `build` prose has no Review-history stamp gate.

- [ ] **Slice 4: pack + composition** <requires: Slice 3>
  - Paths: `skills/clankshop/PACK.md` (add `inspector` +
    minor bump);
    seed `ROUTING.md`, `feature.md`;
    `skills/workstream/flow.md` + templates/create/sync as
    needed.
    Insert `/inspector review` into the PLAN pipeline here.
  - Verify: pack member set lists `architect` and
    `inspector`; live pointers are `/architect` and
    `/inspector`.

_On completion (before landing), run the host's close-the-books sweep._

## Review history

### 2026-08-21 — needs-rework

Judged against the journal spec as written (that spec’s F1–F3
are now folded in the same session).

Must-fix:

- **F1** Approach “`review` dumps the verdict and **stops**. It
  does not flip `status`” vs Mechanism “On a passing judgment,
  one ask: publish?” vs “`publish` is not a new verb. It is
  the confirm of a passing `review`.” Those cannot all be
  true. Either review’s last step is the publish confirm
  (Approach’s “stops” is after that write), or review stops
  after the verdict and a later utterance is publish.
  **Fix:** pick one. Recommended: passing `review` ends with
  the publish ask; failing `review` stops on `draft`. Qualify
  “stops” and “does not flip `status`” (not until confirm).
  - resolved — passing `review` ends with the publish ask;
    failing `review` stops on `draft`; write only on confirm.

- **F2** `build` refuse allows an explicit waive without a
  front-matter write. A walked plan can remain `draft`, so
  `list --status published` lies and an independent agent
  still should not build it. **Fix:** waive writes the same
  gate as publish (`published` + `stage: approved` on a plan)
  and notes the waive in conversation.
  - resolved — waive writes the gate, then walks.

- **F3** Kind templates at `<agent-workspace>/inspector/`.
  Doctrine “Which home” has four destinations (records,
  templates, doctrine, hooks) —
  `skills/skill-builder/docs/DOCTRINE.md` *Doctrine-touching
  skills*. A fifth sibling of `.dev/doctrine` and
  `.dev/templates` is undeclared. Lint will not know it;
  standup mkdir is “every other skill never mkdir.”
  **Fix:** add a fifth landing class to that doctrine list in
  this spec’s slices (inspector kinds: undated, not mint
  shells, not records), **or** place kinds under an existing
  class without colliding with
  `templates/<skill>/<doctype>.md` (e.g. package-only copies
  at `templates/inspector/kinds/` are still mint-adjacent).
  Recommended: fifth class, named here, doctrine pointer in
  Slice 2.
  - resolved — fifth landing class; Slice 2 amends doctrine
    *Which home*; narrow mkdir like hooks.

- **F4** Slice 2 copies `skills/blueprint/verbs/revise.md`
  after Slice 1 `git mv` to `skills/architect/`. **Fix:**
  Slice 2 source paths are `skills/architect/…` (and
  contractor, unchanged).
  - resolved — Slice 2 sources `skills/architect/verbs/revise.md`.

- **F5** “Move the shipped propose-then-apply procedure”
  includes After confirm’s split on the incoming Review-
  history stamp (`needs-rework` vs `approve-with-changes`).
  This spec deletes that stamp. **Fix:** after apply, always
  leave `draft`, drop `stage: approved`, offer `review`. Do
  not copy the stamp-keyed offer.
  - resolved — after apply always `draft` + offer `review`.

Nice-to-have:

- **N1** Slice 1 and Slice 4 both edit `PACK.md`. Slice 1 =
  rename member only; Slice 4 = add `inspector` + minor bump.
  - resolved — Slice 1 rename only; Slice 4 add + bump.

- **N2** Verdict words (`approve` / `approve-with-changes` /
  `needs-rework`) are unnamed once stamps die. Say they
  remain conversation-only, or drop them.
  - resolved — conversation-only; named in `review`.

- **N3** Ground-check: `skills/architect/SKILL.md`,
  `skills/inspector/SKILL.md`, `scripts/ground-check.sh`
  unresolved (future / skill-relative). Expected until ship.
  - deferred — expected until ship; not a spec hole.

### 2026-08-22 — approve-with-changes

Delta pass after the F1–F5 / N1–N2 fold. Prior must-fix remain
resolved. N3 stays deferred. Journal spec’s latest stamp is
still `needs-rework` (F4–F5 there); this file is implementable
against the journal *Mechanism* once those table/path nits
land. Same-session author; depth dial off.

Must-fix: none.

Nice-to-have:

- **N4** Slice 1 and Slice 4 both touch seed routing /
  workstream PLAN pointers. Slice 1 can rename `/blueprint` →
  `/architect` before inspector exists; inserting
  `/inspector review` in Slice 1 leaves a live pointer at a
  missing skill. **Fix:** Slice 1 = rename invokes only;
  Slice 4 = insert `/inspector review` in the pipeline.
  - resolved — Slice 1 rename only; Slice 4 inserts
    `/inspector review`.

### 2026-08-22 — owner: caller publishes

Owner settled: inspector **approves** (conversation verdict,
no front-matter write). The **calling agent** writes
`published` (and `stage: approved` on job artifacts) based on
that approval. A `build` waive is the same caller write.
Inspector’s only status write is `refine` leaving `draft`.
Approach / Pipeline / Inspector `review` / writer tables /
Judgment Verification restated to match.

### 2026-08-22 — owner: accept is the publish write

The publish stop had no machine: “do not ask publish” plus a
hard stop left the caller duty unnamed, so a later `build`
waive published the plan and left the spec `open`. Restated:
passing `review` waits; on accept the same session writes
`published` (jobs: + `stage: approved`) before any next
verb. Founding-shaped stays `draft`. Contractor `plan`
refuses a spec that is not `published`. Kind-template
“publish write” is that confirm-parse, not the verdict turn.
