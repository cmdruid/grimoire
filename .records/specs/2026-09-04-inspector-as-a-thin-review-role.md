---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec, inspector]
---

# Inspector as a thin review role — Spec

Related: `.agents/skilldata/architect/drafts/inspector-thin-review-role.md`;
→ `specs/2026-09-03-inspector-implementation-review-action-loop.md` (archived; coded close
replaced here);
→ `specs/2026-09-02-skilldata-hard-cut-and-workspace-retirement.md` (historical closed-kind
grammar; live skill-builder doctrine no longer enumerates children).

## Problem

Inspector's procedure has replaced native review judgment. Kind axes, an adequacy loop that
mines must-fix findings, automatic amendment proposals, and a coded implementation close
(`1-A-R`, isolated fixers, destination identity) teach the agent to think like the skill
instead of reviewing in the Inspector role. A plan review that should have blocked only on
copy-paste walk-breakers also blocked on parenthetical fallbacks and prescribed a product
split among legal remedies.

The skill also has no honest way to enforce a project's named principles. Bundling
"no migrations" into Inspector is not portable. Auto-loading a standing list applies the
hard-cut when the caller wanted an unconstrained look. Restating the bullets on every
review, or stuffing them into `AGENTS.md`, either repeats doctrine or overpowers ordinary
work.

## Goal

Inspector is a thin role: the model still reviews; the skill only names the bar, the
in-force named sets, and when it may write. Document and implementation reviews share one
conversational shape. A project's invariants and lenses live as ordinary markdown under
Inspector skilldata and apply only when the caller names them. The coded action-close and
isolated fixers are gone.

## Approach

Keep kind-detect (do not invent rubrics) and the two-axis idea (soundness, groundedness).
Strip finding-generators: the adequacy "repeat until no new must-fix" loop, plan-kind
"open decisions are blocking," and `automatic-proposal` as the document default.

Named sets are opt-in files, not a management API and not an always-on bar. Default
review loads none. The caller repeats a short name, not the bullets.

Implementation still cannot enter document `revise` or `refine`. After a material code
verdict, ask in English to fix in this checkout. No reply-code grammar, no isolated
implementation agent, no destination-identity engine. Isolation is not used for a second
pair of eyes or for applying fixes; look-again is another pass in this session.

Rejected forks that informed the choice:

- Isolation as independence: cost without fixing severity inflation.
- Always-on standing invariants with explicit mute: the worse failure (unwanted apply)
  becomes the default.
- Invocation-only bullets: no store, restates doctrine every time.
- `/inspector invariants add|remove`: Inspector is not a curator.
- Store under `doctrine/`: longer, and kind-detect treats extra files there as kinds.
- Park the coded close: leaves the skill thinking in codes and splits one personality
  across two rewrites.
- Closed project skilldata kinds: already dropped in skill-builder; this spec assumes
  owner-defined children under `.agents/skilldata/<skill>/`.

## Mechanism

### Role

Inspector is a second look. It does not widen the job, invent a rubric, or edit during
`review`. It grounds cited commands and tests by opening them. It reports must-fix,
recommended, omit. Document review then stops (`offered`). A material implementation
verdict then uses the English close below. `approve` on implementation is ready and
returns; no menu.

Must-fix: the written step cannot succeed as specified, or a **falsifiable forbidden
shape** from an invariant file **in force for this review** is violated. Taste,
parenthetical alternatives, preamble restated as a follow-up, and "or whatever the
real install is" are not must-fix. Two legal in-boundary remedies → ask; review does
not pick the product. A bullet in `invariants/` that is not a forbidden shape is not
must-fix (omit or treat as a lens).

Light (default): one native pass, ground cited paths, apply in-force invariants, stop.
Deep (explicit): also inverse questions, safety of the mechanism, and named lenses.
The existing kind-file "substrate-skeptic / explicit deep" extras are this dial, not a
second switch. No auto-escalation from path names. Inspector may note that a deep look
would be proportionate without changing the dial.

A named lens on a light review is a non-blocking note unless that file also states a
forbidden shape (then the shape is must-fix; the rest of the lens is not).

Document continuation: bundled `kinds/plan.md` and `kinds/spec.md` declare `offered`.
`SKILL.md`'s missing-declaration default for every document kind, including spec and
plan, is `offered` (today spec and plan default to `automatic-proposal`). Host-added
kinds stay `offered` unless they declare otherwise. Project incumbent
`.agents/skilldata/inspector/doctrine/plan.md` (or `spec.md`) is a complete replacement
and keeps its bytes until the host edits them. Fold is `/inspector revise` (or an
explicit request to fold) after the verdict. Same-session re-review is another look,
not recusal.

### Named sets

Package vocabulary:

| Term | Binding |
|---|---|
| invariant | Falsifiable forbidden shape. In force and violated → must-fix. |
| lens | A way to look. Does not block unless it also names a forbidden shape. |
| in force | Named on this invocation. Default none. |

Project instances are files the owner writes:

```text
.agents/skilldata/inspector/invariants/<name>.md
.agents/skilldata/inspector/lenses/<name>.md
```

`<name>` is the invocation token and the filename stem: `[a-z0-9]+(-[a-z0-9]+)*`, no
slash, no parent traversal. Several names may be in force (`with hard-cut and
simplicity`). Inspector owns the path convention and the read rule. The project owns
the bytes. Setup does not plant content or create these directories. Missing
directories mean this project has no named sets. An arbitrary existing file path on
the invocation is an escape hatch, not the usual form.

A review that is only reviewing never creates these files. Creating, editing, or deleting
the markdown is the management surface. Unnamed look-again does not re-attach sets.
Unknown name → ask.

Kind-detect reads kind policy under `.agents/skilldata/inspector/doctrine/<kind>.md` (or
the bundled `kinds/<kind>.md`). It does not treat `invariants/` or `lenses/` as kinds.

### Implementation close

Implementation judgment uses the same must-fix test and light/deep dial.
`revision-after-review: unavailable` remains: document `revise`/`refine` still must not
rewrite a tree from a findings table.

After a material implementation verdict, the close is English, inline, this checkout:

- The verdict is not permission to edit.
- If the review named a commit or range that is not this tree, refuse to apply and say so.
- `approve`: ready; no menu.
- `needs-rework`: ask to fix must-fix findings in this tree, then look again — or stop.
- `approve-with-changes`: stand as-is, or apply the recommended changes here.
- `yes` / `fix them` / `stop` and obvious paraphrases are enough.

Delete from `verbs/review.md`: the `1-A-R` surface, reply-code parse, isolated-fixer
preflight, destination-identity engine, and `A`→`I` fallback. Tests under
`skills/inspector/scripts/tests/` that encode that grammar are rewritten or dropped with
the close they proved.

### Kind files and live copy

Bundled `kinds/plan.md` and `kinds/spec.md` declare `revision-after-review: offered`.
Plan-kind "open decision branches do not belong here" is not a blocking axis.
Shared soundness/groundedness remain questions the reviewer answers, not a quota of
findings.

Live surfaces that still advertise the coded close or automatic document fold are
updated with the package: `skills/inspector/SKILL.md` (including the frontmatter
`description:`), `verbs/review.md`, `kinds/implementation.md`, `kinds/plan.md`,
`kinds/spec.md`, and this library's `README.md` and `PACK.md`. Historical
`docs/design/` records are not live instructions and are not rewritten.

## Verification

A gap between this spec and the skill is detectable if any of the following fail:

1. `/inspector review` of a plan whose fenced command cannot succeed (wrong flag, invented
   location scheme, a test suite that cannot lift-and-run) reports those as must-fix, and
   does not treat a parenthetical fallback or a preamble restated as a follow-up as
   must-fix.
2. Two legal remedies for one defect produce an ask, not a determined split in the
   verdict turn, and document review does not enter `revise` until explicitly asked.
3. With invariant files present, a review that names none does not treat their shapes as
   must-fix. A review `with hard-cut` does. An unknown name asks.
4. Implementation `needs-rework` offers an English fix-in-this-tree question. The strings
   `1-A-R`, isolated-fixer preflight, and destination-identity protocol are absent from
   live Inspector instructions and from this library's `README.md` and `PACK.md`.
5. Inspector prose may name `.agents/skilldata/inspector/invariants/` and `lenses/`
   without `skills/skill-builder/scripts/skills-lint.sh` reporting `fails>0`.
6. Inspector package tests that still encode the old close or `automatic-proposal` as
   the spec/plan default are rewritten to the English close and `offered` continuation;
   `skills/inspector/scripts/tests/run.sh` is green after that rewrite. Historical
   `docs/design/` fixtures are not a live contract.
