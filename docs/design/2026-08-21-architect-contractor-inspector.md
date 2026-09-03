---
doctype: design
status: published
created: 2026-08-21
updated: 2026-08-27
tags: [spec]
---

# architect / contractor / inspector — responsibility spine

This library's design home is `docs/design/` (patient-zero). This is
the lineage contract for three already-built skills, amended
in place as their boundaries changed. It is not an implementation unit
in the current portfolio and contains no slices.

Current extensions: `docs/design/2026-08-24-inspector-adequacy-and-review-close.md` owns Inspector
adequacy and setup; `.records/specs/2026-08-26-inspector-automatic-refinement-proposals.md` owns
the original review-continuation behavior; `.records/specs/2026-08-27-inspector-revise-and-refine.md`
owns the hard-cut correction/simplification split. The skill-first workspace contract is
`docs/design/2026-08-23-workspace-kinds.md`.

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
- Inspector owns review, revise, and refine for the supported artifact kinds. Review is mutation-free
  through its verdict. An accepted passing document review writes its existing gate; an implementation
  verdict offers a plain-text action close for direct return or separately confirmed fixes and full
  re-review. Revise corrects
  supported document findings, while explicit refine simplifies specs and plans. Both document
  mutation verbs propose before applying and return the artifact to draft.
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

**Kind files, not one mushed rubric.** Inspector's bundled/project kind files provide
discriminators, judgment axes, and the review-continuation selector. The verb machine owns the
selector's meaning, status custody, verdict vocabulary, stop implementation, and confirmation.

**Conversation verdict, artifact gate.** Document review findings are ephemeral until revise folds
them. Implementation findings may instead enter the separately confirmed action close. Accepted
passing document review writes the artifact's existing status/stage gate; no second review artifact
is minted.

**Propose before apply.** Revise verifies and classifies findings,
surfaces required questions, proposes concrete amendments, stops, then
applies only after confirmation. Refine proposes supported simplifications without a findings
taxonomy. Every accepted refinement runs a full review.

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

A material document review follows its effective kind's continuation selector. Automatic kinds
enter revision classification and reach questions or a proposal without another user command;
offered kinds stop at an explicit choice; unavailable kinds do not revise. Every revision still
stops before apply, and a confirmed fold leaves the artifact draft. Implementation review remains
mutation-free through its verdict, then uses numbered scope plus `A`/`I` and `R`/`N` modifiers. A
destination-less selection retains only pending scope; a complete confirmed choice may use eligible
inline or isolated remediation followed by a full same-base re-review. That action never enters
document revise or refine. Refinement is an
explicit spec/plan simplification pass and always re-reviews an accepted change. The active Inspector
extensions specify adequacy, review-close parsing, continuation, implementation review, setup, and
the revise/refine split.

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
| `review` | independent two-axis judgment, conversation verdict, and applicable action close |
| `revise` | findings verification, proposal, confirmed in-place correction |
| `refine` | optional minimum-sufficiency proposal for a spec or plan |
| `setup` | Inspector-owned project kind doctrine deployment |

Bare Inspector asks. Unknown kinds ask/refuse; no rubric is invented.
Normal review/revise/refine are read-only with respect to project doctrine.

### Status custody

| Artifact | Mint | Accepted review | Revise/refine apply |
|---|---|---|---|
| spec / ADR | `status: draft` | `status: published` | `status: draft` |
| plan / roadmap / runbook | `status: draft`, no approved stage | `status: published`, `stage: approved` | `status: draft`, drop approved stage |
| founding | `status: draft` | no status write | remains draft |
| implementation | no artifact status | no write | revise/refine unavailable |

Review verdict words remain conversation-only. Review never appends
Review history. Revise and refine never mint a successor or findings record.

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

## Verification

- Router/verb rosters match the three responsibility tables.
- Architect and Contractor carry no review/revise/refine verbs.
- Inspector does not author specs/plans or build.
- Contractor build gates on status/stage, not Review history.
- Accepted review and revise/refine apply follow the status-custody table.
- Project paths are skill-first; zero kind-first Inspector/template
  paths in this file or live package prose.
- Descriptions remain self-scoping; lint `fails=0`.

## Out of scope

- New Inspector adequacy/review-close/implementation/setup mechanics
  (owned by the 2026-08-24 extension).
- Workspace grammar and path migration.
- Pack installation or composition.
- Landing, shipping, or workstream custody.
- Review records, automatic simplification, or compatibility aliases.
