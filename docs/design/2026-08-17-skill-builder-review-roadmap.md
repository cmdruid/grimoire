---
doctype: plans
status: current
created: 2026-08-17
updated: 2026-08-17
tags: [roadmap]
---

# skill-builder review — Roadmap

The decision map for a composable skill-review instrument: `agent-council`
grows a protocol other skills can consume; `skill-builder` gains a `review`
verb; the first customer is `blueprint`. Each phase needs its own plan (or
a spec that doubles as one) before build. This file does not carry task
detail.

Spec: not yet written. Phase 1 produces it. Until then, the locks below
are the governing decisions (conversation 2026-08-17 on stream `grok`;
human asked for this map from those picks). If the spec flips a lock,
update this file.

## Sequencing

```
Phase 1 (spec) ──► Phase 2 (council protocol) ──► Phase 3 (skill-builder review + first use)
     —                     requires: 1                    requires: 2
```

No parallel-eligible phases. Do not start Phase 3 before Phase 2’s gate:
`review` must consume a `review` baton, not paste the council loop.

## Cross-cutting foundations

Locks (override only in the Phase 1 spec):

| # | Fork | Pick |
|---|---|---|
| 1 | `check` vs new `review` | New verb. `check` stays facts (lint + independence). |
| 2 | How they compose | Typed `review` baton. Descriptions name no sibling. |
| 3 | Council target | Still a skill package. Brief becomes pluggable. |
| 4 | First use | `blueprint`, after the verb exists. Do not hand-audit first. |

Also standing:

- Do not grow `check` into a judgment tail.
- Do not generalize the council to “review any code” on this track.
- `handoff: review` on the existing `RESULT.md` / ballot / reply contract —
  that contract already is the interface; it does not travel today.
- Default depth for `skill-builder review` is same-session judgment; convene
  the panel on request or high stake, then consume the artifact.
- Patient-zero: no workshop registration against this library’s real
  `AGENTS.md`. `skill-builder` is outside the pack; no `PACK.md` version bump
  unless the member set changes (it does not).
- Dated `bootstrap` mentions stay. Expected orphan-WARN on
  `founding-documents` / `git-repository` is not this track.

Doctrine: `skills/skill-builder/docs/DOCTRINE.md` (edges name types;
scripts compute facts). Council V1 deferred this (`Do not ship
briefs/feature.md`; report ends the pass).

## Phase 1 — Spec   requires: —

- **Goal:** An argued spec (`status: current`) that a Phase 2/3 plan can
  execute from, with no open decision branches.
- **Scope:** in: the four locks, the `review` baton, pluggable brief,
  `skill-builder review` shape, first-use rule, verification. out: a
  general-purpose code-review council; folding `check` into `review`;
  `blueprint` cleanup as a prior pass.
- **Gate:** spec accepted; this roadmap still matches it (or is updated
  in the same commit).
- **Risks:** writing the spec as a paste of this map. The spec must
  argue mechanism (brief argument shape, edge lines, what `review`
  prints) hard enough that a gap is detectable.

## Phase 2 — Council protocol   requires: 1

- **Goal:** `/agent-council [path]` still convenes as today. A caller can
  pass a brief. The ranked report is a `review` artifact another skill
  can consume without re-implementing spawn/cluster.
- **Scope:** in: brief argument (or `consumes: review-brief`);
  `handoff: review`; keep ballot / reply / `RESULT.md` contracts; default
  brief remains `briefs/skill-review.md`. out: non-skill-package targets;
  new panel seats; durable home / records drain; pasting spawn into
  another skill.
- **Gate:** lint `fails=0` on `agent-council`. Bare convene still works
  with the default brief. A fixture caller can read `RESULT.md` as the
  baton (shape specified in the spec). Description still self-scopes
  (no sibling name).
- **Risks:** “composable” becoming a second orchestrator inside
  `skill-builder`. The protocol is the product; the convene loop stays
  in `agent-council`.

## Phase 3 — skill-builder review + first use   requires: 2

- **Goal:** `/skill-builder review <skill>` exists. `check` is unchanged
  as the cheap gate. First run is `blueprint`; fold only must-fix
  findings that survive the receiving discipline.
- **Scope:** in: new verb file, router row, description trigger,
  Pass 1 as facts then judgment (council brief rubric), depth-dial,
  consume `review` when a panel ran. First customer: `blueprint` (the
  founding-branch “keep reading and reshape” hazard is the known
  starting claim). out: rewriting `verbs/deploy.md`; retargeting the
  council at non-skills; a `blueprint` rewrite that is not a review fold.
- **Gate:** `/skill-builder review blueprint` produces a verdict +
  findings. `check` still runs and stays facts-only. Lint `fails=0` on
  both skills. `blueprint` folds only verified must-fixes. Genesis
  battery winners unchanged.
- **Risks:** review that re-documents `check` or the council. Point,
  don’t paste. Description must not name `/agent-council`.

_When a phase meets its gate, debrief before advancing. Cadence is this
stream’s `milestone` — propose a land after Phase 3 (or earlier if a
later stream needs the protocol)._
