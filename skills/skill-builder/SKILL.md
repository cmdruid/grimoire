---
name: skill-builder
description: "The toolmaker steward for a skills library itself -- not project code, the skills that build it. `new` scaffolds a skill's SKILL.md against the self-init tiers + typed-edge pattern; `check` (alias `audit`) runs the mechanical lint gate plus the independence/boundary-audit workflow; `review` judges a skill's substance; `calibrate` folds accreted authoring decisions back into the portable doctrine. Portable: installs in any skills library, authoring discipline travels with it, no host-repo dependency. Use when scaffolding a new skill, auditing, linting, or a skill review (followability, holes), asking about skill-authoring conventions (self-init tiers, typed edges), or checking whether a skill's description routes on its own."
---

# skill-builder — the toolmaker steward

Nothing in a skills library steward the skills themselves — a design-system steward maintains a
*project's* seed, a workflow hub maintains a *project's* dev glue, but the doctrine behind *how skills
here are authored* (boundary independence, self-init, typed edges, the lint gate) has no home of its
own. `skill-builder` is that home: a **portable** package (doctrine + gate script + audit workflow +
scaffolding) that installs the same way any other skill does, and carries its whole toolchain with it.

This skill audits and scaffolds **the library's own skills** — a maintainer/toolmaker concern,
distinct from auditing a consuming project's code or docs. It is deliberately **not** part of any
development-loop pack a project deploys; it is the tool the *authors* of a skill library reach for.

This `SKILL.md` is a thin router: each verb's procedure lives in its own `verbs/<verb>.md`, read on
demand. When a verb is selected, **read its file and follow it** — do not reconstruct a procedure from
memory.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does |
|---|---|---|
| `new` | `verbs/new.md` | Scaffold a new skill's `SKILL.md` (+ `init` if durable-home tier) against `docs/DOCTRINE.md`'s pattern |
| `check` (alias `audit`) | `verbs/check.md` | Run `scripts/skills-lint.sh` + the boundary-audit workflow; report findings |
| `review` | `verbs/review.md` | Judge a skill package's substance against the skill `review-brief`; optionally consume a `review` baton |
| `calibrate` | `verbs/calibrate.md` | Fold accreted authoring decisions back into `docs/DOCTRINE.md` (milestone-triggered, human-curated) |

## What this skill bundles

- **`docs/DOCTRINE.md`** — the portable design philosophy: the authoring bullets, the three
  self-description layers, the four self-init tiers, the typed-edge + registration mechanics, the
  corollaries. The doctrine's living home — a host library's own front-door doc should point here
  rather than restate it.
- **`docs/BOUNDARY-AUDIT.md`** — the independence-auditing workflow `check` runs (the violation rubric,
  the routing-probe acceptance gate, the mechanical backstop it relies on).
- **`scripts/skills-lint.sh`** — the mechanical gate: frontmatter limits, bundled-ref resolution,
  script syntax, cross-skill ref checks, edge-block well-formedness. Takes a `<library-root>` argument
  (default: the current directory) so it checks whatever library it's pointed at.
## Disposition (scored against its own doctrine)

- **Self-init / home:** none — an **in-place steward**. It maintains the host library's own `skills/`
  tree in place; there is nothing private to scaffold. (Same tier and reasoning as a doc-spine
  steward: a repo-layer maintainer, not a project-artifact owner.)
- **Front-door registration:** optional, not implemented — the payoff (surfacing captured items to a
  bare reader) doesn't apply to a skill with no durable store.

## Edges

skill-builder's **typed edges** — its place in a workflow declared as artifact *types*, never as
sibling names (`docs/DOCTRINE.md` § Typed edges). It is a **toolmaker with no private home**: its
output is new/audited skill files and a conversational report, in-place changes to the library itself.
`review` consumes a `review` baton and a `review-brief`; it does not produce either.

<!-- edges:skill-builder -->
- produces: — (scaffolded/audited skill files + a conversational report, not a typed artifact)
- handoff: — (the review ends the pass)
- consumes: review, review-brief — optional RESULT.md baton; skill brief for same-session judgment
<!-- /edges:skill-builder -->
