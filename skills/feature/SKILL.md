---
name: feature
description: "Execute the planning spine as verbs -- `/feature brainstorm | design | plan | build`, plus the cross-cutting `review` (an independent ground-truthed verdict on an existing design/plan/roadmap/ADR). Use when the user runs `/feature ...`, or asks to brainstorm / design / plan / build / review a feature or its design, plan, or roadmap. Turns an idea into a validated approach, an argued spec, a task-by-task plan, and tested code at gate-green, tuned to the host's gate and templates. The four stages are primitives an orchestrator (you, `/foreman`, or `/workstream`) sequences. Capture stays `/backlog debrief`, landing stays `/workstream` -- `/feature` never debriefs, ships, or lands. For a one-line patch, skip it (fix on the trunk)."
---

# feature -- the executable planning spine

`/feature <verb> [args]` makes the host's `dev/docs/PLANNING.md` spine **executable**. Its four core verbs ARE
the spine's plan-and-build stages (1-4); stage 5 (debrief) stays the separate `/backlog debrief` skill. A
fifth verb, `review`, is **cross-cutting** -- an independent ground-truthed critique of an artifact any
stage produced, callable at any point. Each verb
distills the planning discipline it needs into a compact checklist, pointed at the host's gate
(named in its `AGENTS.md`), templates (`dev/templates/`), frontmatter (`dev/docs/TAXONOMY.md`), and
home (planning artifacts always land in `dev/plans/`; ADRs in `dev/adr/`).

This skill is **self-contained and uniquely named**: it depends on no other skill and collides with
none. The upstream superpowers planning skills stay installed but go unused for planning -- no
settings change, no precedence question.

## Two layers: verbs are primitives, an orchestrator sequences them

- **Verbs** -- the four spine stages (`brainstorm`, `design`, `plan`, `build`) plus the cross-cutting
  `review` -- are *primitives*: each does one job and is invokable directly at any time (`/feature plan
  <design-file>`, or `/feature review <doc>`, by hand works exactly as when a flow calls it).
- **The flow** is the orchestration that sequences verbs and owns the seams *around* planning --
  landing the work and capturing what it surfaced. The orchestrator is the user (standalone), the
  `/foreman` router, or a `/workstream` loop. **`/feature` itself never lands or debriefs** (see
  *Composition*).

## The verbs (the spine, executable)

| Verb | Does | Consumes -> Produces | Args |
|---|---|---|---|
| `brainstorm` | idea -> validated approach; **classifies the tier** | prompt -> approved approach (in context) + tier call | `<prompt>` |
| `design` | write the design spec; self-review; user-review gate | approach -> `dev/plans/<date>-<slug>-design.md` | `[notes/context]` |
| `plan` | write the impl plan; run the **plan gate** | design -> `dev/plans/<date>-<slug>-implementation.md` | `<design-file>` |
| `build` | execute task-by-task to the green gate | plan -> code + checked-off tasks | `<plan-file>` |
| `review` | **cross-cutting:** independent ground-truthed critique of an existing artifact | any spine artifact -> a verdict (in context) | `<doc-file> [focus]` |

The first four are the linear spine (stages 1-4); `review` is orthogonal -- it critiques any artifact
the others produce, at any point, and is not part of the brainstorm->build sequence.

State flows between verbs through the **spine artifacts themselves** -- there is no separate
`/feature` state file (see *State between verbs*).

## Tier-aware output (the verb set is constant; the output scales)

The four **spine** verbs never change; each verb's *output* scales by the `PLANNING.md` **tier dial**
(`review` is tier-agnostic -- it critiques whatever artifact exists, at whatever weight).
`brainstorm` makes the tier call **up front** and states which verbs collapse:

- **Patch** -> `/feature` is **not used**; land the fix directly on the trunk (`DEVELOPMENT.md` ->
  *Fixes & patches*).
- **Small feature** -> `brainstorm` is light (a few sentences); `design` emits a **brief that doubles
  as the plan**, so `plan` folds into it; `build` runs once.
- **Track** (more than one phase, or a decision worth an ADR) -> `brainstorm`+`design` produce a
  **roadmap once** (and an ADR if a cross-cutting decision surfaces); `plan`+`build` then run **per
  phase**.

When unsure, start as a small feature and **promote** the moment a second phase or a cross-cutting
decision appears (PLANNING.md -> *The tier dial*).

## brainstorm `<prompt>` -- idea into a validated approach

Turn an idea into an approach a human has approved, and **classify the tier** so the later verbs
know how much to produce. No file is written; the output is an agreed approach held in context.

Checklist:
1. **Explore context first** -- read the relevant code/docs/recent commits and `PROJECT.md` /
   `DESIGN.md` / `dev/MEMORY.md` invariants before asking anything. Don't brainstorm blind.
2. **Scope check** -- if the idea spans several independent subsystems, say so and decompose into
   separate features before refining details; brainstorm the first one.
3. **Ask one question at a time** -- multiple-choice when you can, open-ended when you must. One
   question per message; never a wall of questions. Pursue purpose, constraints, success criteria.
4. **Propose 2-3 approaches with trade-offs, lead with your recommendation** -- and say why. (Repo
   habit: on every fork, elaborate each option and recommend up front.)
5. **Present the design conversationally**, in sections scaled to their complexity; confirm each
   section before moving on. YAGNI ruthlessly -- cut features that aren't needed.
6. **Classify the tier up front** (patch / small feature / track, per *Tier-aware output*) and state
   which downstream verbs collapse, so `design`/`plan` produce the right weight.
7. **Approach gate** (PLANNING.md gate 1): the human **approves the chosen approach before any spec
   or code**. Do not let momentum write a spec off an unapproved approach.

Output: an approved approach (in context) + the tier call. Terminal step: proceed to `design` (or,
for a patch, stop -- `/feature` isn't used).

## design `[notes/context]` -- argue the *why* in a written spec

Write the design that argues the chosen approach before any code, then gate it on review. Skip the
standalone design for a patch; for a **small feature** this is the **brief that doubles as the plan**
(keep it short -- problem, approach, a task list, a done-when); for a **track** it is the **roadmap**
(written once, settling all phases). Copy the shape from `dev/templates/plan-design.md` (or
`dev/templates/roadmap.md` for a track) -- do not double-plan by also re-filling a template by hand.

Checklist:
1. **Write the spec** with the template's sections: **Problem** (the root need, not a surface knob),
   **Goal**, **Approach** (+ the 1-2 alternatives rejected and why), **Mechanism** (concrete enough
   to implement from), **Verification** (how we'll know it works).
2. **Land it in `dev/plans/`** as `dev/plans/<YYYY-MM-DD>-<slug>-design.md`, with frontmatter
   `type: design`, `status: draft`, `updated: <today>`, `related: [...]` -- the `type`/`status`
   vocabulary `dev/docs/TAXONOMY.md` defines and the doc-linter enforces (`design` moves
   `draft -> active -> shipped` as the feature advances).
3. **Spec self-review** (PLANNING.md gate 2, part 1) -- scan the written spec for: placeholders
   (TBD/TODO/vague), internal contradictions, scope (focused enough for one plan?), ambiguity (any
   requirement readable two ways -> pick one, make it explicit). Fix inline.
4. **User-review gate** (PLANNING.md gate 2, part 2) -- ask the human to **review the written spec
   file** before planning. Make requested changes and re-run the self-review until approved.

Consumes `brainstorm`'s approach; produces the design doc. Terminal step: proceed to `plan` (passing
the design file).

## plan `<design-file>` -- the task-by-task implementation brief

Turn the approved design into a plan an implementer executes step by step, after re-grounding it
against the live tree. For a **small feature** this folds into `design`'s brief (no separate plan);
for a **track**, write one plan **per phase** from the roadmap. Copy
`dev/templates/plan-implementation.md`.

Checklist:
1. **Writing discipline** -- decompose into **bite-sized tasks** (each an independently testable
   deliverable with its own test cycle); give **exact file paths**; put **complete code in every
   step** (no "add error handling", no "similar to Task N"); DRY, YAGNI, TDD, frequent commits. Map
   the file structure first (one responsibility per file; right-size tasks so a reviewer could reject
   one without the others).
2. **Plan gate -- re-verify against `HEAD`** (PLANNING.md gate 3; the design ages well, the *literal
   code/data* ages fast):
   - Re-read every load-bearing signature / path / count against the worktree's `HEAD` before sizing
     or coding -- the trunk moves (a dependency's API churns between versions; a renamed type, a moved
     signature). A claim **inherited from a scout/sub-agent or a queued item** is exactly what this
     gate re-verifies, never trusts -- a plausible inherited finding can name a bug that does not
     exist, and refuting it here is cheaper than building a fix for it. `scripts/ground-check.sh <root> <design-file>` lists the rooted path / `file:line`
     references in the design that no longer resolve at `HEAD` -- re-ground those first (facts, not a
     verdict: it finds moved/renamed files; you still re-read the signatures and re-measure).
   - **Re-measure before you size** -- run the actual tool against `HEAD` (a lint count, a fmt diff,
     a benchmark, a library's live API); a snapshot count is a guess.
   - **TDD fixtures must respect the rule's full dimensionality** -- sanity-check fixture *setup*
     against what the behavior actually exercises.
   - **Spike the riskiest/newest tech first -- scaled to how new it really is.** A **new**
     render/tech path: make it Task 1 and verify it **visually in isolation** (a green unit test can
     hide a blank render). A **reused, already-proven** path where only the *wiring* is new (a new
     member of an existing set, a new caller of a proven system): a wiring/membership **unit test
     suffices** -- a live visual spike there adds fiddly cost for low marginal assurance. Classify
     which case you are in before defaulting to the visual spike.
   - Name the load-bearing live-API traps from `dev/docs/GOTCHAS.md` in the plan's **Global
     Constraints** so each task re-verifies them.
3. **Plan self-review** -- spec coverage (every spec requirement maps to a task -- list gaps), a
   placeholder scan, and type/name consistency across tasks. Fix inline; add a task for any
   uncovered requirement.
4. **Land it** as `dev/plans/<YYYY-MM-DD>-<slug>-implementation.md`, frontmatter `type:
   implementation`, `status: draft`, `updated`, `related: [<the design>]`. An ADR (`dev/adr/`, via
   `dev/templates/adr.md`) is part of this stage **only** if a cross-cutting decision surfaced -- one
   per track, never per phase.

Consumes the design file; produces the implementation plan. Terminal step: proceed to `build`
(passing the plan file).

## build `<plan-file>` -- execute task-by-task to the green gate

Execute the plan's tasks to completion. `build` is **context-aware** -- how it runs depends on whether
it is in a worktree -- and **artifact-free**. It is the load-bearing verb: getting it right is what
makes `/feature` safe to call from inside a `/workstream`.

**Where it runs -- the build invariant, then routing.** In a worktree the main session is the **sole
writer of the tree** -- a dispatched subagent cannot hold the worktree's cwd, so a subagent that edits the
tree directly silently corrupts the trunk (the `WORKSTREAM.md` invariant). That is **forbidden** and
unchanged: whoever *authors* a work-unit, the main session stays the one hand that *mutates the tree*.

Within that invariant, **route each work-unit per the `/delegate` skill** -- it owns the delegate-or-not
call, the mechanism (inline / `/mailbox` patch / isolated worktree / parallel fan-out), the model-routing
table, and the **confirm-the-route** rule (never pin a provider/model without the human's OK on live
cost/availability). `build` adds only the two constraints `/delegate` can't know:

- **The tree-writer is always the main session.** A `/mailbox` delegate authors a patch into its
  slot (read-only on the tree; the main session applies and gates it); an isolated-worktree delegate
  works on its **own** branch, which the main session merges. Protocol + the full why: the
  `mailbox` skill.
- **The gate stays with the orchestrator** -- single build location, RAM-governed; **delegates never
  compile**. Whatever mode authored the change, the host's full gate runs at the main session.

**Standalone (not in a worktree)** -> the tree-corruption hazard is absent (no shared trunk): a fresh
subagent **may** implement each task (main session reviews between tasks), or run inline -- still route the
choice per `/delegate`.

**Artifact-free progress:** track progress in the plan's own `- [ ]` checkboxes plus the harness task
list. Write **no** working-tree state file for progress -- there is nothing to pollute or clean up.

**Per-task cycle** (red-first, TDD): write the failing test -> run it to confirm it fails for the
right reason -> minimal implementation -> run to green -> commit. For non-code work, a concrete
checkable assertion (a grep, a doc-linter run, a scenario screenshot) stands in for the unit test.
**A data/param retune of an existing system is not "non-code work":** it usually has existing unit
tests (pin-tests, value snapshots) that a *visual* verify is structurally blind to -- after the edit,
also run the host's **cheap unit suite** (not the full gate) in addition to the visual check, or a
stale pin-test surfaces only at the end-of-phase gate and costs a full cycle.
Run **all** the plan's tasks one after another, committing as you go -- **do not stop after each task**
to ask whether to continue. Pause only at a **blocker** (a failure you can't resolve, a missing
dependency, an unclear instruction) or a **genuine fork** (a decision that changes what gets built).

**Red-green in a delegated mode.** Inline mode runs the cycle locally as above. In **`/mailbox` mode**
the read-only delegate authors **test + implementation in one patch** (it can't run the tree's gate);
the main session applies it, runs the gate, and on red dispatches a **remediation** patch -- the
red-green loop simply moves to the **orchestrator's** granularity (apply -> gate -> remediate). Use a
separate failing-test dispatch (then a second impl dispatch) only when red-first genuinely matters, or
an **isolated worktree** when the delegate must run the loop itself. The gate always runs at the
orchestrator (single build location), whichever mode authored the change.

**Green gate** (PLANNING.md gate 4): the host's full gate green **plus a relevant end-to-end / scenario
check** before each commit; build in the worktree, never inline on the trunk. Optionally request a
**read-only** code-review subagent before finishing.

**`build` ends at gate-green and hands back.** It does **not** land (merge/ship) and does **not**
debrief -- the orchestrator owns both (see *Composition*).

## review `<doc>` -- independent ground-truthed critique of an existing artifact

Review a spine artifact someone already wrote -- a design, an implementation plan, a roadmap, or an
ADR -- as an **independent** second set of eyes, distinct from the *self*-review baked into `design`
and `plan` (self-review is the author checking their own work; this verb is not the author). The
**cross-cutting** verb: callable any time on any artifact, by any orchestrator (you, `/foreman`, a
`/workstream`, or a coordinator reviewing another stream's doc). Like `brainstorm` it is
**artifact-free** -- output is findings + a verdict in context, no file written; like every verb it
never edits, lands, or debriefs. It reviews **documents, not diffs** -- a code change is `/code-review`.

Checklist:
1. **Read the whole doc; detect its `type`** from frontmatter (`design`/`implementation`/`roadmap`/
   `adr`) to pick the rubric. A planning-shaped markdown with no frontmatter still gets the closest one.
2. **Ground it against `HEAD` -- the step self-review can't do from prose.** Run
   `scripts/ground-check.sh <root> <doc>` to flag rooted path / `file:line` refs that no longer
   resolve, then **re-read the load-bearing signatures/code the claims rest on**. A clean ground-check
   is a fact, not a verdict: it finds moved/renamed files; you still re-read the code and judge each
   claim (the trap is a confident doc citing a function that has moved or never existed).
3. **Apply the rubric for the doc's type:**
   - **design** -- Problem is the *root need*, not a surface knob; Approach justified with alternatives
     rejected; Mechanism implementable; **grounded** (refs resolve, claims match code); aligned with
     `DESIGN.md`/`dev/MEMORY.md` invariants, ADRs, `GOTCHAS`; scope = one plan; ambiguity resolved; YAGNI.
   - **implementation** -- **spec->plan coverage** (every design requirement maps to a task -- list
     gaps); bite-sized testable tasks, exact paths, complete code (no "similar to Task N"); plan-gate
     grounding; riskiest piece spiked first; load-bearing `GOTCHAS` in Global Constraints; per-task verify.
   - **roadmap** -- phase decomposition + build order/dependencies explicit; each phase shippable;
     cross-cutting decisions surfaced as ADRs.
   - **adr** -- decision + alternatives + consequences honest; supersession recorded.
   - **any type** -- internal consistency (no section contradicts another); frontmatter valid per
     `TAXONOMY.md`; right altitude.
4. **Report the verdict, in context** (the output IS this shape, in order):
   - **Verdict:** one of `approve` / `approve-with-changes` / `needs-rework`.
   - **Findings ranked by severity**, each as: location (`file:line` or section) -> what's wrong ->
     *why it matters* -> a concrete fix. Separate **must-fix** from **nice-to-have**.
   - **Confidence note** on any finding you're unsure of -- never present a guess as a fact.

Depth dial (default off): for a high-stakes artifact, dispatch a few **read-only** subagents in
parallel -- each a distinct lens, one a skeptic trying to *refute* the doc's central claim -- and
synthesize. Read-only **only**: never an editing subagent (the `build` worktree rule).

Consumes an existing artifact by path; produces a verdict in context. Terminal step: hand the verdict
to whoever owns the artifact -- `review` changes nothing itself.

## State between verbs = the spine artifacts

There is no separate `/feature` state file. Each verb consumes the previous verb's artifact by path:
`brainstorm`'s approach lives in context -> `design` writes the design doc -> `plan` reads it and
writes the implementation plan -> `build` reads the plan and checks off its tasks. Those artifacts are
the `dev/plans/` docs the frontmatter/taxonomy system already catalogs; `/feature` is the engine that
*produces what the taxonomy indexes*, and each doc's frontmatter `status` tracks its lifecycle.
`review` is the exception: it **consumes** any of these artifacts by path and produces only an
in-context verdict, adding nothing to the chain (artifact-free, like `brainstorm`).

## Composition (the orchestrator owns landing + capture)

`/feature` is the plan+build engine; an orchestrator sequences its verbs and owns everything around
them. **`/feature` never debriefs, ships, or lands.**

- **Standalone** (a one-off feature) -> the user runs `brainstorm -> design -> plan -> build`, then
  lands the work and runs **`/backlog debrief`** at the done-when (PLANNING.md -> *When a plan completes*).
- **Inside `/workstream`** -> the stream calls `/feature` per queue item; `build` stops at gate-green
  and **hands back**. `/workstream` owns the **reset ritual** (`/backlog debrief` #1 -> `ship` -> *(if the
  ship was eventful)* `/backlog debrief` #2 -> `save` -> reset). `/feature` initiates none of it.
- **`/foreman`** (router) -> for a feature, dispatches into `/feature` at the right verb (start at
  `brainstorm`, or jump to `design`/`plan` if an approach/spec already exists).
- **`review`** (cross-cutting) -> any orchestrator can call it on an artifact at any point: after
  `design` as an independent gate before `plan`, after `plan` before `build`, or standalone (a
  coordinator reviewing another stream's doc). **For a multi-task feature, running `review` on the
  plan between `plan` and `build` is recommended by default**, not only on request -- an independent
  ground-truthed pass there has repeatedly caught must-fix bugs before any code was written. It is artifact-free and changes nothing -- the verdict
  goes back to whoever owns the artifact, who decides what to revise.

## Structure, plugin posture, portability

- A self-contained skill directory (`SKILL.md` + an optional `templates/` subdir only if a verb ever
  needs a shape not already in the host's `dev/templates/` -- it shouldn't, since it reuses
  `plan-design.md` / `plan-implementation.md` / `roadmap.md` / `adr.md`).
- The upstream superpowers planning skills stay **installed and unused** for planning -- `/feature` is
  uniquely named, so nothing collides and no settings/plugin toggle is needed; their session bootstrap
  is unaffected. They simply go unused for the plan-and-build path.
- **Portable:** `/feature` is a self-contained skill directory, so the planning engine travels as one
  unit wherever the skills are installed (vendored in a repo, or a shared global skills home).
