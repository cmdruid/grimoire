---
name: contractor
description: "Use when the user runs `/contractor`, or asks to write a roadmap, implementation plan, or runbook, to review one of those, to apply review findings or amend a needs-rework job, or to execute a plan or runbook. One job: sequence work from an approved spec, optionally delegate slices, walk the job. Never writes a spec. Never ships to trunk. For a one-line patch, skip it."
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

- **Workshop present** → summon the build station
  (`.handbook/scripts/context.sh build`).
- **Standalone** → the project's own design docs and READMEs stand in for
  station context.

**Destination is not stamped.** `roadmap` / `plan` / `runbook` land in
`<agent-records>/plans/` on every host (first `agent-records:` or
`records-root:` in `AGENTS.md` then `CLAUDE.md`, else `.records/`), with
`tags:` exactly one of `[plan]`, `[roadmap]`, `[runbook]`. Resolve
`plans.md` via the agent-templates rule; `records.sh new --template
<resolved>` when the tool exists; else file-mode from that path. Then
fill the body from the resolved `plan.md` / `roadmap.md` / runbook
conductor. Never write the flat
`<agent-records>/templates/<doctype>.md`. Never deploy `plan.md` or
`roadmap.md` *as* `plans.md`.

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
| `revise` | `verbs/revise.md` | fold review findings into the job |
| `build` | `verbs/build.md` | execute plan or runbook |
| (bare) | — | **ask** which verb; do not default |

```
plan  →  review  →  approve              →  build
                 →  approve-with-changes →  build, or revise if asked
                 →  needs-rework         →  revise  →  review  →  …
```

Each arrow is a stop. No verb invokes the next.

## Brief the human (every verb)

The artifact holds the job vocabulary (`status: open` / `current`, slice ids,
`DONE` / `needs-rework`). The conversation does not open with it.

- **Lead with the situation** a newcomer could use: what the software can do
  now, or what you need the human to decide. Then the path to the artifact.
- **One ask per stop.** After `plan`, `review`, or `revise`, stop and wait. During
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
- **Land it** (minting verbs: `roadmap`, `plan`, `runbook`) under
  `<agent-records>/plans/` per the destination rule above. Mint the
  shell, then overwrite `tags:` and the body. Title missing → ask once.

## Hard seams

- Descriptions and edges name **types**, never sibling skills.
- **Never ship** to trunk. Landing is someone else's job.
- Delegation is **optional**. Per slice: do it, or write a brief and use the
  host's delegation mechanism. Do not restate spawn/return mechanics.
- Every walked **plan** has a latest Review history stamp of `approve` or
  `approve-with-changes` (or an explicit waive) before `build`. A latest
  `needs-rework` is not a pass — `revise` is the path back.
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
- produces: plan, roadmap, runbook — job artifacts in `<agent-records>/plans/`
- handoff: — (build executes in-place; ship is not this skill)
- consumes: spec, review — an approved specification, or a findings baton (council RESULT.md or Review history)
<!-- /edges:contractor -->
