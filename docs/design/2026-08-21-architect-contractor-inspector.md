---
doctype: design
status: published
created: 2026-08-21
updated: 2026-08-24
tags: [spec]
---

# architect / contractor / inspector — responsibility spine

This library's design home is `docs/design/` (patient-zero). This is
the lineage contract for three already-built skills, amended
in place as their boundaries changed. It is not an implementation unit
in the current portfolio and contains no slices.

Current extension:
`docs/design/2026-08-24-inspector-adequacy-and-review-close.md` owns all
new Inspector behavior and setup. The skill-first workspace contract is
`docs/design/2026-08-23-workspace-kinds.md`. Neither spec edits this
lineage during implementation; alignment is folded before re-review.

## Problem

Specification authoring, implementation sequencing, and independent
review were once split inconsistently across artifact-named and
actor-named packages. Author skills also reviewed their own work, so the
independence rule existed only in prose.

The responsibility spine needs three names whose boundaries match the
jobs:

- `architect` argues what should exist;
- `contractor` sequences and walks approved work;
- `inspector` independently critiques and folds findings.

The skills must remain independently routable. Composition belongs in a
pack runbook or host procedure, not in their descriptions or setup.

## Goal

- Architect owns brainstorm, grill, spec, and founding new/deploy. It
  never writes implementation plans, builds, or reviews.
- Contractor owns roadmap, plan, runbook, and build. It never writes a
  spec, reviews, or ships to trunk.
- Inspector owns review and refine for the supported artifact kinds.
  Review is conversation-only until a passing document verdict is
  accepted; refine is propose-then-apply and returns the artifact to
  draft.
- A published spec is the gate into plan/build. Plans, roadmaps, and
  runbooks additionally use `stage: approved` after accepted review.
- Kind policy is Inspector-owned project doctrine at:

  ```text
  <agent-workspace>/inspector/doctrine/<kind>.md
  ```

  A present project file wins; absent falls back to the bundle.
- Lock-in templates are skill-first:

  ```text
  <agent-workspace>/<skill>/templates/<doctype>.md
  ```

- No review records store, Review-history stamp gate, sibling landing
  class, pack persona, or cross-skill setup dependency exists.

## Approach

**One job per actor.** Artifact creation and independent judgment are
separate packages. Contractor begins only after the specification gate.

**Kind files, not one mushed rubric.** Inspector's bundled/project kind
files provide discriminators and judgment axes. The verb machine owns
status custody, verdict vocabulary, stop boundaries, and confirmation.

**Conversation verdict, artifact gate.** Review findings are ephemeral
until refine folds them. Accepted passing review writes the artifact's
existing status/stage gate; no second review artifact is minted.

**Propose before apply.** Refine verifies and classifies findings,
surfaces required questions, proposes concrete amendments, stops, then
applies only after confirmation. Named re-review is a separate full
review after apply.

**Skill-first project ownership.** Each skill deploys only beneath its
own workspace namespace. Architect/Contractor template deployment and
Inspector doctrine deployment never create or inspect sibling
namespaces.

## Mechanism

### Pipeline

```text
idea
  → /architect brainstorm | grill | spec
  → /inspector review <spec>
  → caller accepts → spec status: published
  → /contractor plan only when sequencing is required
  → /inspector review <plan>
  → caller accepts → plan status: published, stage: approved
  → /contractor build
  → host landing lane
```

A failing review stops. A later `/inspector refine` may amend the same
artifact and leaves it draft. The active Inspector extension specifies
adequacy, review-close parsing, implementation review, and setup.

Founding-shaped work remains draft because it is a conversation driver,
not a publish-gated job artifact.

### Architect

Router surface:

| Verb | Owns |
|---|---|
| `brainstorm` | explore and sharpen an idea |
| `grill` | resolve material design branches |
| `spec` | write the argued feature/design contract |
| `new` | founding specification for a new repository |
| `deploy` | founding deployment design |

Architect mints specs as draft and never self-publishes. Its
ground-check is an author self-check, not independent review.

### Contractor

Router surface:

| Verb | Owns |
|---|---|
| `roadmap` | sequence several approved features |
| `plan` | sequence one approved feature when needed |
| `runbook` | one operational job |
| `build` | execute an approved plan/runbook or governing spec |

Contractor refuses an unpublished governing spec. Plan/roadmap/runbook
approval is status plus stage, not a Review-history string. Build stops
at gate-green; the host landing lane ships.

### Inspector

Router surface:

| Verb | Owns |
|---|---|
| `review` | independent two-axis judgment and conversation verdict |
| `refine` | findings verification, proposal, confirmed in-place fold |
| `setup` | Inspector-owned project kind doctrine deployment |

Bare Inspector asks. Unknown kinds ask/refuse; no rubric is invented.
Normal review/refine are read-only with respect to project doctrine.

### Status custody

| Artifact | Mint | Accepted review | Refine apply |
|---|---|---|---|
| spec / ADR | `status: draft` | `status: published` | `status: draft` |
| plan / roadmap / runbook | `status: draft`, no approved stage | `status: published`, `stage: approved` | `status: draft`, drop approved stage |
| founding | `status: draft` | no status write | remains draft |
| implementation | no artifact status | no write | refine unavailable |

Review verdict words remain conversation-only. Review never appends
Review history. Refine never mints a successor or findings record.

### Project surfaces

Architect and Contractor lock-in templates live below their respective
`<skill>/templates/` directories. Inspector project kind doctrine lives
below `inspector/doctrine/`. Each owner provides its own deployment
behavior when it has a durable surface.

No station loader, shared doctrine tree, pack setup, or composer is a
precondition. Missing project customization falls back to package law or
ordinary project documentation.

### Independence

- Descriptions name only the skill's own work.
- Typed edges use artifact/capability types, never sibling names.
- Cross-skill sequence is runbook/host-flow content.
- No skill writes another skill's workspace namespace.
- No implementation spec edits this lineage as a build task.

## Verification

- Router/verb rosters match the three responsibility tables.
- Architect and Contractor carry no review/refine verbs.
- Inspector does not author specs/plans or build.
- Contractor build gates on status/stage, not Review history.
- Accepted review and refine apply follow the status-custody table.
- Project paths are skill-first; zero kind-first Inspector/template
  paths in this file or live package prose.
- Descriptions remain self-scoping; lint `fails=0`.
- Active extension specs contain no implementation slice targeting this
  lineage file.

## Out of scope

- New Inspector adequacy/review-close/implementation/setup mechanics
  (owned by the 2026-08-24 extension).
- Workspace grammar and path migration.
- Pack installation or composition.
- Landing, shipping, or workstream custody.
- Review records, automatic refinement, or compatibility aliases.
