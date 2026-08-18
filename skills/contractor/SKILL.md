---
name: contractor
description: "Use when the user runs `/contractor`, or asks to write a roadmap, implementation plan, or runbook, to review one of those, or to execute a plan or runbook. One job: sequence work from an approved spec, optionally delegate slices, walk the job. Never writes a spec. Never ships to trunk. For a one-line patch, skip it."
---

# contractor — the job lead

One job lead: draft the bid from an approved spec, optionally staff slices, walk
the job. Never writes a spec. Never ships to trunk. Open decision branches belong
in a grill on the spec, not here.

This `SKILL.md` is a **thin router**: the probe, the dispatch table, the seams
every verb shares, and the typed edges. Each verb's procedure lives in
`verbs/` (see the dispatch table). When a verb is selected, **read its file
and follow it**.

This skill is **self-contained and uniquely named**: it depends on no other skill
and collides with none.

## One environment probe (at entry)

Does `<root>/.handbook/README.md` exist and carry the clankshop install stamp (a
line matching `Seeded from clankshop`)? That single fact picks the homes and
context; nothing else is probed, and no verb ever refuses or stalls for lack of
a workshop.

- **Workshop present** → artifacts are records in the `plans/` store, minted
  with the deployed `<records-root>/scripts/records.sh new plans --title "…"`
  (the records root is the declared `records-root:`, else `.records/`).
  **Contractor owns this store's template and lazy-deploys it**: before
  minting, copy `templates/plans.md` into `<records-root>/templates/plans.md`
  when absent. That shell is the `plans` doctype. After minting, the verb
  **fills the body** from `templates/plan.md` or `templates/roadmap.md` (or a
  runbook conductor list) and sets `tags:` to exactly one of `[plan]`,
  `[roadmap]`, `[runbook]`. Never deploy `plan.md` or `roadmap.md` *as*
  `plans.md`. **Summon the build station** for every contractor verb
  (`.handbook/scripts/context.sh build`).
- **Standalone** → confirm an **output home** once (default `docs/`); artifacts
  are the bundled body scaffolds copied whole (`templates/plan.md`,
  `templates/roadmap.md` — they carry the same front-matter vocabulary, so a
  later migration adopts them unchanged). A runbook is a new file in that home
  with `tags: [runbook]`. The project's own design docs and READMEs stand in
  for station context.

**Status vocabulary** (the records contract): a working draft is `status: open`;
the accepted, living job artifact is promoted to `status: current` (one per
subject); closure — `done`, `dropped`, `superseded`, `consumed` — goes through
`records.sh done` on a workshop host.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does |
|---|---|---|
| `roadmap` | `verbs/roadmap.md` | multi-phase map |
| `plan` | `verbs/plan.md` | tracer-bullet plan |
| `runbook` | `verbs/runbook.md` | compile conductor |
| `review` | `verbs/review.md` | critique roadmap/plan/runbook |
| `build` | `verbs/build.md` | execute plan or runbook |
| (bare) | — | **ask** which verb; do not default |

## Brief the human (every verb)

The artifact holds the job vocabulary (`status: open` / `current`, slice ids,
`DONE` / `needs-rework`). The conversation does not open with it.

- **Lead with the situation** a newcomer could use: what the software can do
  now, or what you need the human to decide. Then the path to the artifact.
- **One ask per stop.** After `plan` or `review`, stop and wait. During
  `build`, run each slice's verify; brief the human at start, at a blocker,
  and at the end — not after every slice unless they asked for a running
  log or a slice failed.
- **Translate the closing code.** "The plan is at `<path>`. Please read it
  before I implement." not "Terminal step: `review` then `build`." "The
  tests would go green and still encode the wrong scripts" not a bare
  `needs-rework`.

## Shared discipline (every verb)

- **Read the verb file.** Do not reconstruct a procedure from this router.
- **Scripts from this package.** `scripts/ground-check.sh` is this skill's copy
  — resolve it from this skill's own base directory, never a host path.
- **An approved spec is the input.** Missing → ask. A spec with open decision
  branches is not approved — send those branches back to a grill on the spec.
- **Land it** (minting verbs: `roadmap`, `plan`, `runbook`) per the probe
  above. Workshop: mint the shell, then overwrite `tags:` and the body.
  Standalone: write `<output-home>/<stem>.md`. Stem = a slug of the title
  (lowercase, hyphens, no punctuation) with a `-plan` / `-roadmap` /
  `-runbook` suffix if the slug does not already end in that word. Title
  missing or stem empty → ask once. Existing file → ask for a different
  stem; do not overwrite.

## Hard seams

- Descriptions and edges name **types**, never sibling skills.
- **Never ship** to trunk. Landing is someone else's job.
- Delegation is **optional**. Per slice: do it, or write a brief and use the
  host's delegation mechanism. Do not restate spawn/return mechanics.
- Every walked **plan** is reviewed (`review`) or the human waives it, before
  `build`.
- **Never execute a raw roadmap.** Compile a runbook first, and only when every
  unblocked phase already has a plan path.
- A runbook completeness check is **additional**. It does not substitute for
  plan review.
- After a walked plan or gated phase, run the host's close-the-books
  sweep (workshop: the deployed debrief; standalone: the project's own).
  Do not name a sibling.

## Project templates

- `plans.md`
- `plan.md`
- `roadmap.md`

## Edges

<!-- edges:contractor -->
- produces: plan, roadmap, runbook — job artifacts in plans/ (workshop) or the output home
- handoff: — (build executes in-place; ship is not this skill)
- consumes: spec — an approved specification the user names
<!-- /edges:contractor -->
