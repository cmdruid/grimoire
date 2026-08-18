---
doctype: plans
status: open
created: 2026-08-17
updated: 2026-08-17
tags: [plan]
---

# workstream review remediation — Implementation Plan

Tracer-bullet: slice 1 is the template `ship` → `recycle` loop an
agent actually follows — the two must-fixes plus the draft/WIP
split that makes the loop executable. Later slices close the
resume, status, and host-fork holes.

Spec: `docs/design/2026-08-17-workstream-review.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Invariants:** one session drives one stream. Verbs stay
  primitives; do not merge `recycle` into `ship`. Helper scripts
  stay facts-not-verdicts — do not add a `recycle-ready` verdict
  flag. Do not invent a `/workstream coordinator` verb. Do not
  run `/clankshop setup` in this library. Do not write findings
  back as a second `WORKSTREAM.md` anywhere except Coordinates
  `this hand-off:`.
- **Live-API gotchas:** re-read each cited span against
  `<worktree>` HEAD before editing. Load-bearing wraps:
  `skills/workstream/verbs/ship.md:147-155` (queue advance +
  draft), `:88-95` (`landing: pr` already defers step 3).
  `skills/workstream/verbs/recycle.md:24-28` (dirty guard),
  `:38-45` (regenerate path).
  `skills/workstream/verbs/load.md:41-44` (Confident launch).
  `skills/workstream/verbs/create.md:218-221` (seed-only
  unattended path).
  `skills/workstream/verbs/park.md:26-32` (unpark).
  `skills/workstream/verbs/status.md:1-4`.
  `skills/workstream/SKILL.md:144-146` (“No remote.”).
  `skills/workstream/templates/workstream-handoff.md:142-174`
  (Loop routine `/backlog debrief`).
  `skills/workstream/flow.md:102-126` (Confident launch),
  `:273-285` (manual-mode `/backlog debrief`).
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
  the spec’s receiving locks.

## File map

| Path | Responsibility |
|---|---|
| `skills/workstream/verbs/ship.md` | Template skip of procedure step 3 |
| `skills/workstream/verbs/recycle.md` | Hand-off path + refuse-on-WIP |
| `skills/workstream/SKILL.md` | “No remote.” bullet only |
| `skills/workstream/verbs/load.md` | First-load confirm of `unconfirmed` |
| `skills/workstream/flow.md` | Confident-launch sentinel; debrief host fork |
| `skills/workstream/verbs/park.md` | `unpark` gathers `inplace-state` |
| `skills/workstream/verbs/status.md` | Resolve `<root>` |
| `skills/workstream/templates/workstream-handoff.md` | `<debrief>` placeholder |
| `skills/workstream/verbs/create.md` | Fill `<debrief>` from the install-stamp probe |
| `skills/workstream/verbs/close.md` | Eventful-close debrief host fork |

No other files. Do not touch `scripts/`.

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

- [ ] **Slice 1: template ship → recycle (the tracer)** <requires: —>

  - Files: Modify `skills/workstream/verbs/ship.md`,
    `skills/workstream/verbs/recycle.md`,
    `skills/workstream/SKILL.md`
  - Findings: 1, 2, 3 (+ Notes “No remote.”)
  - Change: three surgical replacements. Do not rewrite Landing.
    Do not add a script.

    1. **`ship.md` procedure step 3** (`:147-155`). After the
       current first sentence (“Advance the queue — hand-off only
       …”), insert this branch *before* the queue-advance /
       draft sentences, and keep the existing `manual` skip as a
       nested case of the plan-bound path:

       ```
       3. **Advance the queue — hand-off only** (the ledger row already rode the branch in step 1).
          **If Coordinates `source-kind: template`:** do not invent a next queue item and do not
          draft a next plan. Mark the landed unit done in the hand-off (TL;DR / What's been done)
          and hand back to `recycle` (`verbs/recycle.md`) — that is this archetype's advance.
          (`landing: pr` already defers this step until the PR merges; template is a second skip.
          Either reason is enough — do not draft in either case.)
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

       Leave steps 1, 2, 4, 5 and the whole Landing section
       untouched, including the existing `landing: pr` bullet
       (`:88-95`).

    2. **`recycle.md` step 2** (`:24-28`). Replace the refuse
       condition with:

       ```
       2. **Guard — refuse on un-dealt-with work.** Run `workstream-git.sh stream-state <worktree> <branch>
          <target>`. If `wip_tracked=true` (real uncommitted edits) **or** `ahead>0` (committed but
          unshipped), STOP: the current unit isn't resolved. Direct the user to **`ship`** it (if done) or
          discard it explicitly (a `git -C <worktree> reset --hard` / checkout is the user's call — recycle
          never destroys work silently). Do **not** key on `dirty=true`: an untracked plans draft is
          expected dirt (`drafted_next_plan`, `wip_tracked=false`). If that is the only dirt, **delete the
          draft** (it is uncommitted; recycle's job is a blank unit) and continue. Do not ask. Only a
          fully-shipped tree with no real WIP may recycle.
       ```

       Leave the in-place custody paragraph that follows.

    3. **`recycle.md` step 4** (`:38-45`). Replace the opening
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

    4. **`SKILL.md` “No remote.”** (`:144-146`). Replace the
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
      rg -n "source-kind: template" skills/workstream/verbs/ship.md && \
      rg -n "Regenerate \`<worktree>/WORKSTREAM.md\`" skills/workstream/verbs/recycle.md ; \
      rg -n "this hand-off:" skills/workstream/verbs/recycle.md && \
      rg -n "Do \*\*not\*\* key on \`dirty=true\`|wip_tracked=true" skills/workstream/verbs/recycle.md && \
      rg -n "^\- \*\*No remote\.\*\*" skills/workstream/SKILL.md ; \
      rg -n "Land locally onto" skills/workstream/SKILL.md && \
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "FAIL:|workstream:"
    ```

    Expected: `ship.md` hits `source-kind: template`; recycle
    “Regenerate `<worktree>/WORKSTREAM.md`” is empty; `this
    hand-off:` and the `wip_tracked` / not-`dirty` phrases hit;
    `SKILL.md` “No remote.” heading is gone and “Land locally”
    hits; lint `fails=0`; workstream line is only the symlink
    WARN.

- [ ] **Slice 2: first-load confirm** <requires: —> (parallel with 3, 4)

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

       Do not otherwise rewrite Confident launch.

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

- [ ] **Slice 3: unpark gathers** <requires: —> (parallel with 2, 4)

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

- [ ] **Slice 4: status root** <requires: —> (parallel with 2, 3)

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

- [ ] **Slice 5: host-correct debrief** <requires: 1>

  - Files: Modify
    `skills/workstream/templates/workstream-handoff.md`,
    `skills/workstream/verbs/create.md`,
    `skills/workstream/flow.md`,
    `skills/workstream/verbs/close.md`
  - Finding: 6
  - Change: do **not** rewrite `SKILL.md` *Host layout* or the
    already-qualified Scope capture lines. The workshop bullet
    staying `/backlog debrief` is correct — that *is* the
    workshop path.

    1. **Handoff template — introduce `<debrief>`.** In
       `templates/workstream-handoff.md`, replace every
       `/backlog debrief` in the Loop routine (`:142-174`) and
       in the Phase model map (`:84-85`) with `<debrief>`. Four
       Loop-routine hits and two Phase-map hits. After the
       Coordinates block (or at the top of Loop routine), add
       one gloss so a reader of an unfilled template is not
       stuck:

       ```
       `<debrief>` is filled at `create` / `recycle` from the host probe
       (`SKILL.md` *Host layout*): workshop → `/backlog debrief`; else →
       `the project's own close-the-books sweep (do not invoke /backlog)`.
       ```

    2. **`create.md` step 6** — in the hand-off fill list
       (Coordinates / Stream-queue bullets, around `:100-117`),
       add a sibling bullet:

       ```
       - **`<debrief>`:** run the *Host layout* probe (`.handbook/README.md`
         carries `Seeded from clankshop`?). Stamp present → write `/backlog debrief`.
         Absent → write `the project's own close-the-books sweep (do not invoke /backlog)`.
         Recycle re-applies this fill (it re-runs this step).
       ```

       Do not change seed-only / unattended behavior otherwise.

    3. **`flow.md`.** Two sites:
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
      skills/skill-builder/scripts/skills-lint.sh . 2>&1 | rg "^FAIL:"
    ```

    Expected: first grep (template `/backlog debrief`) empty;
    `<debrief>` hits the template and `create.md`; `flow.md` and
    `close.md` no longer contain `/backlog debrief`; `SKILL.md`
    still contains it (workshop bullet + Scope, correctly);
    `FAIL:` empty.

## Done when

All seven findings in the spec have a landed slice. From the
worktree:

```
cd /Users/cscott/Repos/grimoire/.workstreams/grok && \
  rg -n "source-kind: template" skills/workstream/verbs/ship.md && \
  rg -n "Regenerate \`<worktree>/WORKSTREAM.md\`" skills/workstream/verbs/recycle.md ; \
  rg -n "Do \*\*not\*\* key on \`dirty=true\`" skills/workstream/verbs/recycle.md && \
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

Expected: `ship.md` has the template branch; recycle no longer
says `Regenerate <worktree>/WORKSTREAM.md`; the not-`dirty`
phrase, `unconfirmed` in `load.md`, `unpark`’s `inplace-state`,
and status’s Resolve-root all hit; template `/backlog debrief`
and `SKILL.md` “No remote.” heading are empty; lint `FAIL:`
empty. The workstream symlink WARN remains.

_On completion (before landing), run the host's close-the-books sweep._

## Review history

**2026-08-17 — `/contractor review`: `needs-rework`.** Ground-check clean
(`checked=13`). Blocking findings below; prune this section when they
are resolved.

### must-fix

1. **Slice 1 makes `ship` call `recycle`.** Location: slice 1 change 1
   (`ship.md` step 3, proposed “hand back to `recycle`”). `ship.md:158-164`
   (left untouched) still hands back to the reset ritual. The plan’s own
   invariant says verbs stay primitives — do not merge `recycle` into
   `ship`. Spec lock 1’s “hand back to recycle” is the *flow’s* next
   action after a template ship, not an in-procedure call. As written,
   an agent recycles mid-`ship` and then still runs step 5 (save /
   reset), or skips recycle because step 5 wins. Fix: step 3 only
   *skips* queue-advance and the next-plan draft for
   `source-kind: template`. Step 5 stays the reset ritual; `flow.md`
   names `recycle` as the next action after that ritual for a template
   stream.

2. **Slice 1 does not update the other “ship drafts” sites.** Location:
   slice 1 Files (only `ship.md` / `recycle.md` / `SKILL.md`). Live
   claims that survive the slice: `flow.md:210-214` (Scenario A: ship
   “advances the queue … and drafts the next plan”; only `manual`
   skips), `ship.md:158-161` (“pre-reset `save` (advanced queue +
   drafted next plan)”),
   `templates/workstream-handoff.md:145-146` (same parenthetical).
   `flow.md` is already in context at every loop entry — an agent will
   still draft. Fix: add those three sites to slice 1 (or a tight
   follow-on in the same slice). Template skip = no draft, no
   “advanced queue” in the save parenthetical.

3. **Slice 1 change recipe is insert *and* replace.** Location: slice 1
   change 1 prose (`:98-102`) vs the fenced step-3 block (`:104-120`).
   “Insert this branch after the current first sentence” plus a
   complete new `3.` block duplicates the numbered step if followed
   literally. Fix: say **replace** `ship.md:147-155` with the fenced
   block. Drop the insert sentence.

4. **Slice 5 cannot pass its own verify.** Location: slice 5 change 1
   gloss (`:336-340`) vs verify (`:373`) and Done when (`:404`). The
   gloss contains the string `/backlog debrief`. The verify requires
   that string absent from the template. A correct fold fails the
   slice. Fix: write the gloss without that exact command string
   (e.g. “the workshop backlog debrief verb”), or change the verify to
   accept the gloss and require the Loop-routine / Phase-map *command*
   hits gone.

### nice-to-have

5. **`landing: pr` parenthetical is unimplemented in the Otherwise
   branch.** Location: slice 1 change 1. “Either reason is enough”
   lives only inside the template `if`. Plan-bound + `landing: pr`
   still hits Otherwise and would advance/draft, fighting
   `ship.md:88-95`. Drop the pr sentence from the template branch;
   leave deferral in the Landing tail.

6. **Slice 1 verify `this hand-off:` is already green.** Location:
   slice 1 verify (`:179`). `recycle.md:33` already contains that
   phrase. A no-op slice 4-path-fix still passes. Grep for `The file
   you write MUST equal` instead.

7. **Slice 5 `<requires: 1>` is not a blocking edge.** create /
   template / flow / close do not need the ship/recycle edits.
   Parallel-eligible.

8. **“Delete the draft” should name the paths.** Location: slice 1
   change 2. `drafted_next_plan` can be a comma-separated list.
   Delete each listed path; do not `rm` a guessed plans glob.
