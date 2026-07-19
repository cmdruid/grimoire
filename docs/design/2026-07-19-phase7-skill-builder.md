# Phase 7 (capstone) — the `skill-builder` steward

**Status:** Implemented (2026-07-19). Deliverable of **Phase 7** — the last phase of
`docs/design/2026-07-18-skill-self-initialization-roadmap.md`. Closes the roadmap.

**What this doc is.** The disposition + build record for `skill-builder`: the toolmaker steward that
consolidates `scripts/skills-lint.sh` (the gate), `docs/boundary-audit.md` (the audit workflow),
new-skill scaffolding, and the authoring doctrine itself — and becomes the **portable home** that
doctrine moves to, so grimoire's own `AGENTS.md` thins to local overrides that *import* it (the same
public-doctrine + private-override shape the user's own `~/.agents/AGENTS.md` already uses over
grimoire's `AGENTS.md`).

## Why this is a skill, not a doc

Nothing steward the skills themselves. `architect` stewards a project's design seed, `foreman` the
workflow glue, `chiropractor` the doc spine, `auditor` scores project code — but the *authoring*
doctrine this session has been building against (boundary tenets, the three self-description layers,
self-init/edges, the lint gate, the boundary-audit workflow) has lived as a **loose federation** of
`AGENTS.md` bullets, a standalone `docs/boundary-audit.md`, and a root `scripts/skills-lint.sh` —
each independently portable in spirit but not packaged as one. `skill-builder` is that missing
package: a skill that can be dropped into *any* agent-skill library (via `./install.sh skill-builder`
or a bare symlink, same as every other skill here) and carry the doctrine + gate + audit workflow with
it.

**Sequenced last on purpose** (per the roadmap): the doctrine only stabilized through Phases 0–6.
Building the portable package earlier would have meant distilling a moving target.

## Disposition (the same three axes Phase 3 scored the other ten skills on)

| axis | disposition |
|---|---|
| **Self-init / home** | **None.** `skill-builder` ships its doctrine + workflow as **bundled, read-only package content** (`docs/DOCTRINE.md`, `docs/BOUNDARY-AUDIT.md`, `scripts/skills-lint.sh`) — not a per-project scaffold. It reads/writes the **library's own `skills/` tree** in place, the same shape as `chiropractor` (an in-place steward maintaining the repo's own layer, no private `.agents/`/`.records/` home to create). Tier: **in-place steward** (Phase 3 F1's third tier), not durable-home. |
| **Typed edges** | **All `—`.** Its output is new/audited skill files + a conversational report — in-place changes to the skill library itself, not a typed artifact another skill drains. Same shape as `chiropractor`'s and `delegate`'s all-empty blocks. |
| **Front-door registration** | **Optional, not implemented v1.** Same call as `chiropractor` (no durable home, no captured items to surface — the registration payoff per F3 doesn't apply). A later pass may add it if a real need surfaces; not manufactured now. |

This mirrors `chiropractor`'s precedent almost exactly — both are "a steward with no private home,"
maintaining a layer of the *repo itself* in place. The one difference: `chiropractor` tunes the doc
*spine*; `skill-builder` tunes the *skills* (their boundary health, their edges, their onboarding
scaffold).

## Verbs

Three, matching the roadmap's own naming (`new`, `audit`/`check`, `distill`):

- **`new`** — scaffold a new skill's `SKILL.md` (frontmatter + self-scoping description reminder +
  an empty `## Edges` block) against the **tier-templated pattern** Phase 3's F1 finding proved
  (durable-home / in-place-steward / scratch-only / pure-mechanism), asking which tier fits and, for
  durable-home, drafting a `verbs/init.md` skeleton + a copy of the proven `register-route.sh`
  mechanism. This is the F1 tiering + the self-init model's registration format, generalized from "the
  five things Phase 5 built by hand" into a repeatable scaffold.
- **`check`** (alias `audit`) — run `scripts/skills-lint.sh` (the mechanical gate) **and** walk
  `docs/BOUNDARY-AUDIT.md`'s workflow (inventory → scan descriptions → cross-check the runbook's seam
  table → findings → routing-probe). One verb, both checks — the roadmap's "boundary + layers + edges
  + lint, replacing/wrapping `skills-lint.sh` + the manual boundary-audit workflow."
- **`distill`** — architect's ADR→distill→seed pattern, applied to skill-authoring: fold accreted
  design docs about skill-authoring (this roadmap's own trail, `docs/design/2026-07-18-skill-
  boundaries-and-glue-ownership.md`, the self-init model doc) back into `docs/DOCTRINE.md` as stable
  doctrine grows, the same collapse-ritual shape `architect distill` already runs for a project's
  design seed.

**Explicitly not built this phase:** collapsing the five skills' duplicated `register-route.sh` copies
into one shared script (BL-6), or the `built-against` per-directory stamp fix (BL-7). Both are real,
recorded follow-ups whose *natural home* is `skill-builder new`/`check` once it exists — but building
them now would be scope creep on the capstone itself; they stay open in `docs/BACKLOG.md`, now with a
concrete owner.

## Not part of `clankshop`

`docs/boundary-audit.md` was explicit: *"a toolmaker workflow, not a `/foreman` verb ... auditing
grimoire's own authored skills is our concern, not a deployed project's."* `skill-builder` inherits
that scope line — it is **not** added to `packs/clankshop.md`'s `skills:` manifest (which composes the
ten-skill *development loop* a consuming project deploys). `skill-builder` is grimoire's (and any
library's) own maintainer tool, installed the same way any skill is, but outside the pack that
`/foreman init` stands up on a project.

## What moves, what stays, what thins

- **`scripts/skills-lint.sh`** → `skills/skill-builder/scripts/skills-lint.sh`. It already took an
  `<agents-root>` parameter (portable by design); moving it into the skill bundle is what makes that
  portability real — a library that installs `skill-builder` gets the gate with it, no grimoire-root
  dependency. Living references (`README.md`, `AGENTS.md`, `docs/boundary-audit.md`) repoint to the
  new path. Historical design docs that show old `bash scripts/skills-lint.sh` transcripts are **left
  untouched** — they are frozen records of a session, not living instructions (the same rule Phase 6
  applied to stale `Status:` headers: repoint the doctrine, not the history).
- **`docs/boundary-audit.md`** → becomes a short pointer: the *workflow* (steps, rubric, mechanical
  backstop) is now `skill-builder`'s (`docs/BOUNDARY-AUDIT.md` + `verbs/check.md`); grimoire's own
  **routing-probe run log** (the "last run: 2026-07-18, 12/12" record) stays here as a library-local
  record, since it's a fact about *this* library's current skills, not portable doctrine.
- **`AGENTS.md`**'s `## Design philosophy` section thins to a pointer at
  `skills/skill-builder/docs/DOCTRINE.md` (the portable doctrine) plus grimoire's own **local
  overrides**: the feedback-channel choice (GitHub issues) and the patient-zero caveat (never let
  self-registration blocks accrete in grimoire's real `AGENTS.md`). This is the exact shape the user's
  own `~/.agents/AGENTS.md` already uses one level up (`@~/Repos/grimoire/AGENTS.md` + "Private
  overrides (this machine only)") — the pattern now recurses one level down too.
- **`README.md`** gains an eleventh row (`skill-builder`) and repoints the gate command in
  *Contributing*.
- **`packs/clankshop.md`** gains one orientation sentence noting `skill-builder` exists, outside the
  pack — no manifest change.

## Gate

Doc-only + one new skill dir + one file move — build-relevant (a `.sh` moves), so the full
`skills-lint.sh` pass is required, not just the doc-linter. Run it from its **new** location after the
move: `bash skills/skill-builder/scripts/skills-lint.sh` → `fails=0` expected (12 skills now, one new
all-`—` edge block, no new sibling refs).

## References

- `docs/design/2026-07-18-skill-self-initialization-roadmap.md` — Phase 7's own bullet (the deliverable
  this doc fulfills).
- `docs/design/2026-07-19-phase3-skill-dispositions.md` — F1 (four self-init tiers), F2 (universal
  edge block), F3 (registration tracks captured items) — the rubric this disposition applies.
- `docs/design/2026-07-18-skill-self-init-model.md` — §1 tenet, §2 edge format, §3 registration
  mechanism — what `skill-builder new` scaffolds and `docs/DOCTRINE.md` carries forward.
- `docs/boundary-audit.md` (pre-Phase-7) — the workflow `skill-builder`'s `check` verb now runs.
