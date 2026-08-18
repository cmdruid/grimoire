---
doctype: design
status: current
created: 2026-08-17
updated: 2026-08-17
tags: [spec]
---

# workstream review — Spec

Accepted 2026-08-17 on stream `grok`. Same-session `/skill-builder review
workstream` against `skills/agent-council/briefs/skill-review.md`. Verdict:
**needs-rework**. The human asked to remediate every numbered finding; this
file is the governing spec for that fold. It is the review report plus the
receiving locks — not a restatement of the skill.

Target (unchanged by the review verb):
`/Users/cscott/Repos/grimoire/.workstreams/grok/skills/workstream/`

Brief:
`/Users/cscott/Repos/grimoire/.workstreams/grok/skills/agent-council/briefs/skill-review.md`

## Facts (Pass 1)

lint fails=0 warns=1 (target-relevant):

- `WARN: workstream: ~/.claude/skills/workstream resolves to /Users/cscott/Repos/grimoire/skills/workstream, not this clone`

Expected worktree-vs-clone note. Not a finding.

## Findings (the requirements)

### 1. high — `ship` has no template-stream branch
Location: `skills/workstream/verbs/ship.md` (The ship procedure, step 3);
`skills/workstream/flow.md` (*Ship cadence*);
`skills/workstream/templates/workstream-handoff.md` (Loop routine)
Class: must-fix

The template/intake archetype has no queue. `flow.md` and the hand-off say
a unit lands, then `recycle` clears the instance. `ship.md` step 3 always
sets the next queue item and drafts the next plan. Following the verb
mints a draft; following the loop then hits `recycle`, which refuses a
dirty tree.

### 2. high — `recycle` rewrites the wrong hand-off path in-place
Location: `skills/workstream/verbs/recycle.md` steps 2 and 4
Class: must-fix

Step 2 says the in-place hand-off is Coordinates `this hand-off:`, not
`<worktree>/WORKSTREAM.md`. Step 4 says “Regenerate `<worktree>/WORKSTREAM.md`”.
For `isolation: in-place` that write is `<root>/WORKSTREAM.md` — a stray
the next `load` will not read. Same fork `save.md` already guards against.

### 3. mid — `recycle` keys `dirty=true` and ignores the draft/WIP split
Location: `skills/workstream/verbs/recycle.md` step 2;
`skills/workstream/scripts/workstream-git.sh` (`cmd_stream_state`)
Class: nice-to-have

`stream-state` treats an untracked plans draft as expected dirt
(`drafted_next_plan`, `wip_tracked=false`). Recycle stops on `dirty=true`.
The fact the script computed is unused.

### 4. mid — seed-only / unattended `create` promises a first-`load` confirm that `load` never runs
Location: `skills/workstream/verbs/create.md` (Seed-only mode, step 2);
`skills/workstream/templates/workstream-handoff.md` (Delegation route,
`unconfirmed`); `skills/workstream/verbs/load.md`
Class: nice-to-have

Seed-only records `unconfirmed — defaults to inline until confirmed` and
says the driving session confirms at first `load`. `load.md` and
Confident launch have no such step.

### 5. mid — `status` never defines `<root>`
Location: `skills/workstream/verbs/status.md` step 1
Class: nice-to-have

The verb “runs anywhere” and immediately uses `<root>`. From inside a
worktree, `rev-parse --show-toplevel` is the worktree; the
`.workstreams/*/` scan misses in-place streams.

### 6. mid — every instantiated hand-off hardcodes `/backlog debrief`
Location: `skills/workstream/templates/workstream-handoff.md` (Loop
routine); `skills/workstream/SKILL.md` (*Host layout*)
Class: nice-to-have

The router forks: workshop → `/backlog debrief`; any other host → skip
the records-layer seams. The template every `create` copies always says
`/backlog debrief`. After `create`, the live save-state contradicts the
router.

### 7. mid — standalone `unpark` consumes `inplace-state` facts it never gathers
Location: `skills/workstream/verbs/park.md` (`unpark` steps 1–3)
Class: nice-to-have

`park` step 1 runs `inplace-state`. `unpark` step 3 keys on
`top_wip=true` without invoking the script.

## Receiving locks (close the open branches)

The human accepted all seven findings. These locks are the chosen
remedies — not options for the implementer.

1. **Template `ship` skips procedure step 3.** If Coordinates
   `source-kind: template`, do not advance a queue and do not draft a
   next plan. Hand back to `recycle`. (`landing: pr` already defers
   step 3 for a different reason; template is a second skip. Either
   reason is enough.)
2. **`recycle` writes Coordinates `this hand-off:` only.** Same
   verify-then-write as `save.md`. Drop `<worktree>/WORKSTREAM.md` as a
   path recipe, or qualify it as worktree-isolation only.
3. **`recycle` refuses on `wip_tracked=true` or `ahead>0` only.** A
   lone `drafted_next_plan` (`wip_tracked=false`, `ahead=0`) is deleted
   uncommitted and recycle continues — recycle’s job is a blank unit.
   Do not ask. Do not key on `dirty=true`.
4. **`unconfirmed` is the sentinel.** At `load`, and at Confident
   launch (so `create` / `recycle` see it too): if the Delegation route
   contains `unconfirmed`, run create’s pre-confirm interview (mode,
   route, cadence; in-place: landing) *before* the KNOWN/AMBIGUOUS
   pick. That one interview covers the unattended defaults. The route
   string is the only flag.
5. **`status` resolves `<root>` as:** `git rev-parse --show-toplevel`;
   if that path contains `/.workstreams/`, root is the parent of
   `.workstreams`; else toplevel is root. Scan that root. When a stream
   is already loaded, Coordinates `root checkout:` is a check, not the
   only method.
6. **The instantiated hand-off is host-correct.** The bundled template
   uses a `<debrief>` placeholder. `create` (and `recycle` re-applying
   create step 6) fills it from the install-stamp probe: workshop →
   `/backlog debrief`; else → `the project's own close-the-books sweep
   (do not invoke /backlog)`. `flow.md` and the hand-off Loop routine
   use that filled command / the Host-layout fork. Do not rewrite the
   workshop bullet in *Host layout*, or the already-qualified Scope
   capture lines.
7. **`unpark` gathers before it consumes.** After the foreign-dirt
   check, run `inplace-state`. Step 3 keys on that output. (`top_wip`
   reads the branch ref, so the gather may run before the switch.)

## Out of scope

Review *Notes*, not numbered findings. Do not open slices for them
except the one while-in-file touch on `SKILL.md` “No remote.” (slice 1
already edits the land path):

- `SKILL.md` “No remote.” overclaims against in-place `landing: push |
  pr`. Tighten that one bullet when touching ship. Not a new finding.
- `templates/coordinator.md` has no dispatch row. Leave it.
- `save.md` does not name `templates/workstream-handoff.md`. Leave it.
- `load` does not mention `Open PR:`. Leave it.

## Done when

Every numbered finding has a landed slice. Lint `fails=0`. The
worktree-vs-clone WARN remains.
