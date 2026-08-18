---
doctype: plans
status: open
created: 2026-08-17
updated: 2026-08-17
tags: [plan]
---

# workstream review remediation — Implementation Plan

Tracer-bullet: slice 1 is the template `ship` → (reset ritual) →
`recycle` loop an agent actually follows — the two must-fixes plus
the draft/WIP split, with `ship` still a primitive. Later slices
close the resume, status, and host-fork holes.

Spec: `docs/design/2026-08-17-workstream-review.md`

Folded 2026-08-17 `/contractor review` (`needs-rework`, `cf1dac4`).
The four must-fixes and four nice-to-haves are in the slices
below; the write-back list is pruned.

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Invariants:** one session drives one stream. Verbs stay
  primitives; do not merge `recycle` into `ship`. `ship` step 3
  *skips* queue-advance and the next-plan draft for
  `source-kind: template`; it does **not** invoke `recycle`.
  `recycle` is the flow’s next action *after* the reset ritual
  (`flow.md` Scenario A). Helper scripts stay facts-not-verdicts
  — do not add a `recycle-ready` verdict flag. Do not invent a
  `/workstream coordinator` verb. Do not run `/clankshop setup`
  in this library. Do not write findings back as a second
  `WORKSTREAM.md` anywhere except Coordinates `this hand-off:`.
- **Live-API gotchas:** re-read each cited span against
  `<worktree>` HEAD before editing. Load-bearing wraps:
  `skills/workstream/verbs/ship.md:147-155` (queue advance +
  draft), `:158-164` (step 5 reset ritual + “drafted next plan”),
  `:88-95` (`landing: pr` already defers step 3 — leave it).
  `skills/workstream/verbs/recycle.md:24-28` (dirty guard),
  `:38-45` (regenerate path).
  `skills/workstream/verbs/load.md:41-44` (Confident launch).
  `skills/workstream/verbs/create.md:218-221` (seed-only
  unattended path).
  `skills/workstream/verbs/park.md:26-32` (unpark).
  `skills/workstream/verbs/status.md:1-4`.
  `skills/workstream/SKILL.md:144-146` (“No remote.”).
  `skills/workstream/templates/workstream-handoff.md:142-174`
  (Loop routine), `:145-146` (ship “drafts the next plan”),
  `:180-183` (template/intake “refuses if dirty”).
  `skills/workstream/flow.md:102-126` (Confident launch),
  `:210-214` (Scenario A ship drafts), `:273-285` (manual-mode
  `/backlog debrief`), `:293-295` (delegate-mode ship drafts).
- **Coexisting work:** this branch is `stream/grok` in
  `/Users/cscott/Repos/grimoire/.workstreams/grok`. Sibling
  `feat` does not own workstream. Root checkout dirt (blueprint +
  mailbox scripts + two untracked design docs) is disjoint — do
  not sweep it in.
- **CI-safety / scope:** markdown-only (plus no script change
  unless a slice names one — none do). Gate is
  `skills/skill-builder/scripts/skills-lint.sh` → `fails=0`. The
  workstream symlink WARN is expected from a worktree. Do not
  add a pack version bump. Do not run `check` Pass 2
  (`docs/BOUNDARY-AUDIT.md`).
- Every slice’s requirements implicitly include this section and
  the spec’s receiving locks. Spec lock 1’s “hand back to
  recycle” means the *flow’s* next action after a template ship,
  not an in-procedure call.

## File map

| Path | Responsibility | Slice |
|---|---|---|
| `skills/workstream/verbs/ship.md` | Template skip of procedure step 3; step 5 save parenthetical | 1 |
| `skills/workstream/verbs/recycle.md` | Hand-off path + refuse-on-WIP | 1 |
| `skills/workstream/SKILL.md` | “No remote.” bullet only | 1 |
| `skills/workstream/flow.md` | Scenario A / delegate draft skip (1); Confident-launch sentinel (2); debrief host fork (5) | 1, 2, 5 |
| `skills/workstream/templates/workstream-handoff.md` | Loop-routine draft parenthetical (1); `<debrief>` placeholder (5) | 1, 5 |
| `skills/workstream/verbs/load.md` | First-load confirm of `unconfirmed` | 2 |
| `skills/workstream/verbs/park.md` | `unpark` gathers `inplace-state` | 3 |
| `skills/workstream/verbs/status.md` | Resolve `<root>` | 4 |
| `skills/workstream/verbs/create.md` | Fill `<debrief>` from the install-stamp probe | 5 |
| `skills/workstream/verbs/close.md` | Eventful-close debrief host fork | 5 |

No other files. Do not touch `scripts/`. `flow.md` and the hand-off
template are shared by slices 1 and 5 — that is why 5 requires 1.

## Coverage

| Finding | Slice |
|---|---|
| 1 must-fix template `ship` | 1 |
| 2 must-fix recycle hand-off path | 1 |
| 3 recycle `dirty` vs `wip_tracked` | 1 |
| Notes: “No remote.” | 1 |
| 4 `unconfirmed` at `load` | 2 |
| 7 `unpark` gathers facts | 3 |
| 5 `status` root | 4 |
| 6 hand-off hardcodes `/backlog` | 5 |

## Slices

- [x] **Slice 1: template ship skip + recycle path (the tracer)** <requires: —>

  - Files: Modify `skills/workstream/verbs/ship.md`,
    `skills/workstream/verbs/recycle.md`,
    `skills/workstream/SKILL.md`,
    `skills/workstream/flow.md`,
    `skills/workstream/templates/workstream-handoff.md`
  - Findings: 1, 2, 3 (+ Notes “No remote.”)
  - Change: do not rewrite Landing. Do not add a script. Do not
    make `ship` invoke `recycle`.

    1. **`ship.md` procedure step 3** (`:147-155`). **Replace**
       those lines (do not insert in front of them) with:

       ```
       3. **Advance the queue — hand-off only** (the ledger row already rode the branch in step 1).
          **If Coordinates `source-kind: template`:** do not invent a next queue item and do not
          draft a next plan. Mark the landed unit done in the hand-off (TL;DR / What's been done).
          Leave step 5's reset ritual in place; `recycle` is the *flow's* next action after that
          ritual (`flow.md` Scenario A), not something this step calls.
          **Otherwise** (plan / roadmap / brief): in the (ignored) worktree hand-off, mark
          **all landed features** done and set the next queue item current.
          Then **draft** the next feature's implementation plan from the queue source into the host's plans
          home (workshop: mint it with `records.sh new plans --title "…"` so the front-matter contract is
          stamped; elsewhere the project's own plans location) — a working-tree draft: it rides the *next*
          ship; do not commit it now. Do not start the next
          feature automatically. **In `manual` mode, skip this draft** — plan-authoring belongs to the next
          PLAN session on the plan-model (`flow.md` -> *Manual mode: the phase loop*); set `Phase: plan`
          instead and PLAN starts the draft fresh.
       ```

       Leave steps 1, 2, 4 and the whole Landing section
       untouched, including the existing `landing: pr` bullet
       (`:88-95`) — that bullet remains the only pr-deferral.
       Do not mention `landing: pr` in this step.

    2. **`ship.md` step 5 parenthetical** (`:158-161`). Replace
       `(advanced queue + drafted next plan)` with
       `(plan-bound: advanced queue + drafted next plan; template: landed unit marked done, no draft)`.
       Leave the rest of step 5 (hand back to the reset ritual)
       unchanged.

    3. **`flow.md` Scenario A** (`:210-214`). Replace the ship
       bullet with:

       ```
       - **`ship` — only at a landing point.** Lands **every accumulated feature** + their debrief commits.
         For plan / roadmap / brief: advances the queue and drafts the next plan into the working tree
         (uncommitted — it persists on disk across the reset; **in `manual` mode `ship` skips this draft** —
         the next PLAN session authors it). For `source-kind: template`: do not advance a queue and do not
         draft. After the reset ritual (`save` → reset → `load`) the next action is `recycle`
         (`verbs/recycle.md`) — `ship` does not invoke it.
       ```

       Also in `flow.md:293-295` (manual-mode contrast), replace
       `In \`delegate\` mode \`ship\` drafts the next feature's plan into
       the working tree` with
       `In \`delegate\` mode on a plan / roadmap / brief stream, \`ship\` drafts
       the next feature's plan into the working tree (\`source-kind: template\` never drafts)`.

    4. **Handoff Loop-routine parenthetical**
       (`templates/workstream-handoff.md:145-146`). Replace

       ```
         (lands every accumulated feature + advances the queue, drafts the next plan into the working tree —
         except in `manual` mode, where the next PLAN session drafts it)
       ```

       with

       ```
         (lands every accumulated feature; plan-bound: advances the queue and drafts the next plan —
         except in `manual` mode, where the next PLAN session drafts it; template: no queue-advance,
         no draft — after the reset ritual, `/workstream recycle`)
       ```

       Also replace the template/intake refuse line
       (`:182-183`) so the bundled hand-off does not re-teach
       the old `dirty` guard:

       ```
         (worktree persists). `recycle` refuses if `wip_tracked=true` or `ahead>0` —
         `ship` or discard first. A lone `drafted_next_plan` is deleted, not a refuse.
       ```

    5. **`recycle.md` step 2** (`:24-28`). Replace the refuse
       condition with:

       ```
       2. **Guard — refuse on un-dealt-with work.** Run `workstream-git.sh stream-state <worktree> <branch>
          <target>`. If `wip_tracked=true` (real uncommitted edits) **or** `ahead>0` (committed but
          unshipped), STOP: the current unit isn't resolved. Direct the user to **`ship`** it (if done) or
          discard it explicitly (a `git -C <worktree> reset --hard` / checkout is the user's call — recycle
          never destroys work silently). Do **not** key on `dirty=true`: an untracked plans draft is
          expected dirt (`drafted_next_plan`, `wip_tracked=false`). If that is the only dirt, **delete
          each path listed in `drafted_next_plan`** (comma-separated; uncommitted; recycle's job is a
          blank unit) and continue. Do not ask. Do not `rm` a guessed plans glob. Only a
          fully-shipped tree with no real WIP may recycle.
       ```

       Leave the in-place custody paragraph that follows.

    6. **`recycle.md` step 4** (`:38-45`). Replace the opening
       “Regenerate `<worktree>/WORKSTREAM.md` exactly as …” with
       a verify-then-write, same discipline as `save.md`:

       ```
       4. **Re-instantiate the hand-off from the template.** The file you write MUST equal the
          Coordinates `this hand-off:` line (the one absolute path). On mismatch, STOP — do not
          write. Then regenerate that file exactly as `create.md`'s **Hand-off instantiation**
          (step 6) does for template mode, **but in place** (no `worktree add`, no exclude re-run —
          already done):
       ```

       Keep the rest of step 4 (preserve Coordinates; update
       `source`/`source-kind` if a new template was passed;
       re-embed durable sections; blank per-unit sections; file
       write, never a commit). Do not mention
       `<worktree>/WORKSTREAM.md` as a path recipe. The in-place
       paragraph in step 2 already names the real path.

    7. **`SKILL.md` “No remote.”** (`:144-146`). Replace the
       three-line bullet with:

       ```
       - **Land locally onto `<target>` first.** Integrate against the workstream's `<target>`
         (Coordinates `integration-target`): `git -C <worktree> rebase <target>` + a by-ref
         advance of `<target>` (`verbs/ship.md` -> *Landing*). Never hardcode `main` — the trunk
         may be `dev` later. Do not treat a remote as the integration target. In-place
         `landing: push | pr` is an optional *tail* after that local land (`pr` skips the local
         advance and opens a PR instead — still keyed on `<target>`, not on `origin/main`).
       ```

  - Verify: from the worktree,

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
      rg -n "source-kind: template" skills/workstream/verbs/ship.md skills/workstream/flow.md && \
      rg -n "hand back to \`recycle\`|hand back to recycle" skills/workstream/verbs/ship.md ; \
      rg -n "ship does not invoke|does not invoke it" skills/workstream/verbs/ship.md skills/workstream/flow.md && \
      rg -n "Regenerate \`<worktree>/WORKSTREAM.md\`" skills/workstream/verbs/recycle.md ; \
      rg -n "The file you write MUST equal" skills/workstream/verbs/recycle.md && \
      rg -n "each path listed in \`drafted_next_plan\`" skills/workstream/verbs/recycle.md && \
      rg -n "refuses if the tree is dirty" skills/workstream/templates/workstream-handoff.md ; \
      rg -n "refuses if \`wip_tracked=true\`" skills/workstream/templates/workstream-handoff.md && \
      rg -n "template: landed unit marked done, no draft" skills/workstream/verbs/ship.md && \
      rg -n "^\- \*\*No remote\.\*\*" skills/workstream/SKILL.md ; \
      rg -n "Land locally onto" skills/workstream/SKILL.md && \
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "FAIL:|workstream:"
    ```

    Expected: `source-kind: template` hits `ship.md` and
    `flow.md`; `ship.md` has no “hand back to recycle”; the
    “does not invoke” phrase hits; recycle
    “Regenerate `<worktree>/WORKSTREAM.md`” is empty;
    `The file you write MUST equal`, `drafted_next_plan` path
    delete, and the step-5 template parenthetical all hit;
    hand-off “refuses if the tree is dirty” is gone and
    `wip_tracked=true` refuse hits;
    `SKILL.md` “No remote.” heading is gone and “Land locally”
    hits; lint `fails=0`; workstream line is only the symlink
    WARN.

- [x] **Slice 2: first-load confirm** <requires: 1> (parallel with 3, 4 once 1 has landed)

  - Files: Modify `skills/workstream/verbs/load.md`,
    `skills/workstream/flow.md`
  - Finding: 4
  - Change:

    1. **`load.md`** — insert a new step 4 and renumber the
       current step 4 to 5. New step 4:

       ```
       4. **Confirm unattended defaults (attended `load` only).** If the hand-off's **Delegation
          route** contains `unconfirmed`, run `create.md` step 6's pre-confirm sub-steps
          (execution mode, delegation route, ship cadence; in-place: also landing) *before*
          Confident launch. Record the result in the hand-off (file write, not a commit). The
          `unconfirmed` string is the only sentinel — that one interview covers the unattended
          defaults seed-only / unattended `create` wrote. If the route is already a confirmed
          route or `inline-only`, skip. Unattended `load` (no human) → leave `unconfirmed` and
          continue inline; do not invent a confirmation.
       ```

       The previous step 4 (Confident launch) becomes step 5,
       unchanged.

    2. **`flow.md` Confident launch** — after the “Gather it
       token-free first” paragraph (`:104-111`) and *before* the
       KNOWN/AMBIGUOUS bullets, insert:

       ```
       **If the Delegation route contains `unconfirmed` and a human is present,** run
       `create.md` step 6's pre-confirm interview first (see `verbs/load.md` step 4) — then
       classify. An unconfirmed stream has no standing route; launching past that interview
       is the hole seed-only `create` documented and `load` must close.
       ```

       Do not otherwise rewrite Confident launch. If slice 1
       already landed, this insert sits next to the Scenario A
       edit — different region; do not revert slice 1.

  - Verify:

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
      rg -n "unconfirmed" skills/workstream/verbs/load.md skills/workstream/flow.md && \
      rg -n "^4\. \*\*Confirm unattended" skills/workstream/verbs/load.md && \
      rg -n "^5\. Run the \*\*Confident launch" skills/workstream/verbs/load.md && \
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "^FAIL:"
    ```

    Expected: `unconfirmed` hits both files; load has the new
    step 4 and Confident launch is now step 5; `FAIL:` empty.

- [x] **Slice 3: unpark gathers** <requires: —> (parallel with 2, 4)

  - Files: Modify `skills/workstream/verbs/park.md`
  - Finding: 7
  - Change: replace `unpark` steps 1–3 (`:26-32`) with:

    ```
    1. **Foreign-dirt check:** if `git -C <root> status --porcelain` is non-empty while parked on the
       trunk, STOP — that dirt is someone else's uncommitted work (the stream's own WIP always rides
       its branch); switching would entangle it. Report and let the human resolve.
    2. **Gather custody facts:** `workstream-git.sh inplace-state <root> <stream> <branch> <target>`
       (`top_wip` reads the branch ref, so this may run before the switch).
    3. **Take the tree:** `git -C <root> switch <branch>`.
    4. **Restore WIP:** if step 2 reported `top_wip=true`, `git -C <root> reset --soft HEAD~1`
       — the parked WIP returns to the tree uncommitted, exactly as left. Soft-reset ONLY a `wip:`
       commit — never a real commit.
    5. **Record it:** set `Parked: false` in the hand-off's Queue state, then continue per the
       hand-off's next action (a fresh session continues into the Confident launch, `flow.md`).
    ```

    The old step 4 becomes step 5. Leave `park` untouched.

  - Verify:

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
      rg -n "inplace-state" skills/workstream/verbs/park.md && \
      python3 -c '
    t=open("skills/workstream/verbs/park.md").read()
    u=t.split("## \`unpark\`",1)[1]
    assert "inplace-state" in u, "unpark still does not invoke inplace-state"
    print("unpark invokes inplace-state")
    ' && \
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "^FAIL:"
    ```

    Expected: `inplace-state` appears in both `park` and
    `unpark`; the python assert prints the ok line; `FAIL:`
    empty.

- [x] **Slice 4: status root** <requires: —> (parallel with 2, 3)

  - Files: Modify `skills/workstream/verbs/status.md`
  - Finding: 5
  - Change: insert this as the new step 1 and renumber the
    current 1–4 to 2–5:

    ```
    1. **Resolve `<root>`.** `here=$(git rev-parse --show-toplevel)`. If `here` contains
       `/.workstreams/`, `<root>` is the parent of that `.workstreams` directory; otherwise
       `<root>` is `here`. When a stream is already loaded this session, Coordinates
       `root checkout:` must equal that path — mismatch → STOP and report (do not guess).
       This verb runs anywhere; do not assume cwd is the root checkout.
    ```

    Current step 1 (`git -C <root> worktree list` + the
    `.workstreams/*/` scan) becomes step 2, unchanged. The scan
    now hits in-place hand-offs even when invoked from inside a
    worktree.

  - Verify:

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
      rg -n "Resolve \`<root>\`" skills/workstream/verbs/status.md && \
      rg -n "/.workstreams/" skills/workstream/verbs/status.md && \
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "^FAIL:"
    ```

    Expected: both greps hit; `FAIL:` empty.

- [x] **Slice 5: host-correct debrief** <requires: 1>

  - Files: Modify
    `skills/workstream/templates/workstream-handoff.md`,
    `skills/workstream/verbs/create.md`,
    `skills/workstream/flow.md`,
    `skills/workstream/verbs/close.md`
  - Finding: 6
  - Change: do **not** rewrite `SKILL.md` *Host layout* or the
    already-qualified Scope capture lines. The workshop bullet
    staying `/backlog debrief` is correct — that *is* the
    workshop path. Requires 1 because this slice edits
    `flow.md` and the hand-off template after slice 1’s
    Scenario A / Loop-routine draft edits — do not revert those.

    1. **Handoff template — introduce `<debrief>`.** In
       `templates/workstream-handoff.md`, replace every
       `/backlog debrief` in the Loop routine (`:142-174`) and
       in the Phase model map (`:84-85`) with `<debrief>`. Four
       Loop-routine hits and two Phase-map hits. After the
       Coordinates block (or at the top of Loop routine), add
       one gloss so a reader of an unfilled template is not
       stuck. **Do not put the characters `/backlog debrief`
       anywhere in this template** (the slice-5 verify greps
       that exact string):

       ```
       `<debrief>` is filled at `create` / `recycle` from the host probe
       (`SKILL.md` *Host layout*): workshop → the workshop backlog
       debrief verb; else → the project's own close-the-books sweep
       (do not invoke the workshop backlog verb).
       ```

       Keep slice 1’s Loop-routine draft parenthetical.

    2. **`create.md` step 6** — in the hand-off fill list
       (Coordinates / Stream-queue bullets, around `:100-117`),
       add a sibling bullet. This file *may* name the workshop
       command — it is the filler, not the template:

       ```
       - **`<debrief>`:** run the *Host layout* probe (`.handbook/README.md`
         carries `Seeded from clankshop`?). Stamp present → write `/backlog debrief`.
         Absent → write `the project's own close-the-books sweep (do not invoke /backlog)`.
         Recycle re-applies this fill (it re-runs this step).
       ```

       Do not change seed-only / unattended behavior otherwise.

    3. **`flow.md`.** Two sites (do not touch slice 1’s
       Scenario A / `:293-295` wording):
       - Manual-mode BUILD / SHIP (`:278`, `:284`): replace
         `/backlog debrief` with
         `debrief` and add “(the hand-off’s filled `<debrief>`
         command — `SKILL.md` *Host layout*)”.
       - Event-driven debrief heading body may keep saying
         “debrief” without a command. Leave it, except any
         remaining `/backlog debrief` in this file must become
         the same host-fork pointer.

    4. **`close.md`** (`:8`). Replace
       `run \`/backlog debrief\` explicitly` with
       `run the hand-off's filled \`<debrief>\` command explicitly`.

  - Verify:

    ```
    cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
      rg -n "/backlog debrief" skills/workstream/templates/workstream-handoff.md ; \
      rg -n "<debrief>" skills/workstream/templates/workstream-handoff.md skills/workstream/verbs/create.md && \
      rg -n "Host layout" skills/workstream/verbs/create.md && \
      rg -n "/backlog debrief" skills/workstream/flow.md skills/workstream/verbs/close.md ; \
      rg -n "/backlog debrief" skills/workstream/SKILL.md && \
      rg -n "source-kind: template" skills/workstream/flow.md && \
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "^FAIL:"
    ```

    Expected: first grep (template `/backlog debrief`) empty
    — the gloss must not reintroduce it; `<debrief>` hits the
    template and `create.md`; `flow.md` and `close.md` no
    longer contain `/backlog debrief`; `SKILL.md` still
    contains it (workshop bullet + Scope, correctly); slice 1’s
    `source-kind: template` in `flow.md` still hits; `FAIL:`
    empty.

## Done when

All seven findings in the spec have a landed slice. From the
worktree:

```
cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
  rg -n "source-kind: template" skills/workstream/verbs/ship.md skills/workstream/flow.md && \
  rg -n "hand back to \`recycle\`|hand back to recycle" skills/workstream/verbs/ship.md ; \
  rg -n "Regenerate \`<worktree>/WORKSTREAM.md\`" skills/workstream/verbs/recycle.md ; \
  rg -n "The file you write MUST equal" skills/workstream/verbs/recycle.md && \
  rg -n "each path listed in \`drafted_next_plan\`" skills/workstream/verbs/recycle.md && \
  rg -n "refuses if the tree is dirty" skills/workstream/templates/workstream-handoff.md ; \
  rg -n "unconfirmed" skills/workstream/verbs/load.md && \
  rg -n "inplace-state" skills/workstream/verbs/park.md && \
  python3 -c '
t=open("skills/workstream/verbs/park.md").read()
assert "inplace-state" in t.split("## \`unpark\`",1)[1]
' && \
  rg -n "Resolve \`<root>\`" skills/workstream/verbs/status.md && \
  rg -n "/backlog debrief" skills/workstream/templates/workstream-handoff.md ; \
  rg -n "^\- \*\*No remote\.\*\*" skills/workstream/SKILL.md ; \
  skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "^FAIL:"
```

Expected: `ship.md` and `flow.md` have the template skip;
`ship.md` does not say “hand back to recycle”; recycle no
longer says `Regenerate <worktree>/WORKSTREAM.md` and does
say `The file you write MUST equal` plus per-path draft
delete; hand-off no longer says recycle refuses if dirty;
`unconfirmed` in `load.md`, `unpark`’s
`inplace-state`, and status’s Resolve-root all hit; template
`/backlog debrief` and `SKILL.md` “No remote.” heading are
empty; lint `FAIL:` empty. The workstream symlink WARN remains.

_On completion (before landing), run the host's close-the-books sweep._
