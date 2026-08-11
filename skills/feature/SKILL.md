---
name: feature
description: "Execute the planning spine as verbs -- `/feature brainstorm | design | plan | build`, plus the cross-cutting `review` (an independent ground-truthed verdict on an existing design/plan/roadmap/ADR), `/feature setup` (register its front-door route), and `/feature templates [<name>]` (customize a bundled planning-template shape, on demand). Use when the user runs `/feature ...`, or asks to brainstorm / design / plan / build / review a feature or its design, plan, or roadmap. Turns an idea into a validated approach, an argued spec, a task-by-task plan, and tested code at gate-green. `feature` never debriefs, ships, or lands. For a one-line patch, skip it (fix on the trunk)."
---

# feature -- the executable planning spine

`/feature <verb> [args]` executes the planning spine (validate -> design -> plan -> build); on a
clankshop host its four core verbs ARE the host feature lane's plan-and-build walk
(`.handbook/workflows/feature.md`). Landing and the debrief sweep stay with the
orchestrator. A
fifth verb, `review`, is **cross-cutting** -- an independent ground-truthed critique of an artifact any
stage produced, callable at any point. Each verb
distills the planning discipline it needs into a compact checklist, pointed at the host's gate,
this skill's own bundled `templates/`, and the plans home -- inputs resolved per host in
*Host layout*, below.

This skill is **self-contained and uniquely named**: it depends on no other skill and collides with
none. The upstream superpowers planning skills stay installed but go unused for planning -- no
settings change, no precedence question.

## Two layers: verbs are primitives, an orchestrator sequences them

- **Verbs** -- the four spine stages (`brainstorm`, `design`, `plan`, `build`) plus the cross-cutting
  `review` -- are *primitives*: each does one job and is invokable directly at any time (`/feature plan
  <design-file>`, or `/feature review <doc>`, by hand works exactly as when a flow calls it).
- **The flow** is the orchestration that sequences verbs and owns the seams *around* planning --
  landing the work and capturing what it surfaced. The orchestrator is the user (standalone), the
  `/clankshop route` router, or a `/workstream` loop. **`/feature` itself never lands or debriefs** (see
  *Composition*).

## Host layout -- standalone by default, framework-aware when present

Feature is **self-contained**: every verb works on any repo -- no framework install is a
precondition, and no verb ever refuses or stalls for lack of one. The verbs consume four host
inputs; where each resolves varies by host:

| input | clankshop host (installation block present) | any other host |
|---|---|---|
| the gate | the command `.handbook/testing/GATE.md` names | the project's own test/build command -- discover it (manifests, CI config) or ask once |
| design context | `.handbook/design/`, plus `.handbook/rules/` INVARIANTS + GOTCHAS | whatever design docs, READMEs, and ADRs the project has |
| the plans home | `.records/plans/` (ADRs: `.records/adr/`) | the project's own docs/records convention -- a declared records-root, an existing docs area; ask once if unclear |
| the record schema | frontmatter per `.handbook/rules/RECORDS.md` | keep the same artifact frontmatter; no schema seam |

On any other host, **skip the framework-only seams** (`/backlog debrief`, the schema floor)
instead of stalling on them. Do not create `.handbook/` or `.records/` on a host that doesn't
have them, and never emit `unstamped` or route to the clankshop onramps: standing the framework
up is the human's separate decision, not a feature's precondition.

## The verbs (the spine, executable)

| Verb | Does | Consumes -> Produces | Args |
|---|---|---|---|
| `brainstorm` | idea -> validated approach; **classifies the tier** | prompt -> approved approach (in context) + tier call | `<prompt>` |
| `design` | write the design spec; self-review; user-review gate | approach -> the plans home: `<date>-<slug>-design.md` | `[notes/context]` |
| `plan` | write the impl plan; run the **plan gate** | design -> the plans home: `<date>-<slug>-implementation.md` | `<design-file>` |
| `build` | execute task-by-task to the green gate | plan -> code + checked-off tasks | `<plan-file>` |
| `review` | **cross-cutting:** independent ground-truthed critique of an existing artifact | any spine artifact -> a verdict (in context) | `<doc-file> [focus]` |

The first four are the linear spine (stages 1-4); `review` is orthogonal -- it critiques any artifact
the others produce, at any point, and is not part of the brainstorm->build sequence. Two more verbs
are **infrastructure, not spine stages**: `setup` registers feature's route into the project's
front-door doc (see *setup*, below) -- feature's whole self-init entry point, idempotent, working
framework or standalone (*Host layout*); and
`templates` deploys exactly one bundled template shape as an editable project override, on demand (see
*templates*, below) -- an optional action most projects never need.

**New here? Read `docs/ideal-use.md`** -- a self-contained worked arc (`brainstorm -> design -> plan ->
build`) on one concrete feature, showing how the spine runs and where its output hands off.

State flows between verbs through the **spine artifacts themselves** -- there is no separate
`/feature` state file (see *State between verbs*).

## Tier-aware output (the verb set is constant; the output scales)

The four **spine** verbs never change; each verb's *output* scales by the lane's **tier dial**
(INV-11: planning weight scales with the work; `review` is tier-agnostic -- it critiques whatever
artifact exists, at whatever weight).
`brainstorm` makes the tier call **up front** and states which verbs collapse:

- **Patch** -> `/feature` is **not used**; land the fix directly on the trunk (the patch lane,
  `.handbook/workflows/patch.md`).
- **Small feature** -> `brainstorm` is light (a few sentences); `design` emits a **brief that doubles
  as the plan**, so `plan` folds into it; `build` runs once.
- **Track** (more than one phase, or a decision worth an ADR) -> `brainstorm`+`design` produce a
  **roadmap once** (and an ADR if a cross-cutting decision surfaces); `plan`+`build` then run **per
  phase**.

When unsure, start as a small feature and **promote** the moment a second phase or a cross-cutting
decision appears (the lane's tier rule, INV-11).

## brainstorm `<prompt>` -- idea into a validated approach

Turn an idea into an approach a human has approved, and **classify the tier** so the later verbs
know how much to produce. No file is written; the output is an agreed approach held in context.

Checklist:
1. **Explore context first** -- read the relevant code/docs/recent commits and the host's design
   context (*Host layout*: the design chapter and invariants on a clankshop host, the project's
   own design docs otherwise) before asking anything. Don't brainstorm blind.
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
7. **Approach gate** (the lane's walk step 1): the human **approves the chosen approach before any
   spec or code**. Do not let momentum write a spec off an unapproved approach.

Output: an approved approach (in context) + the tier call. Terminal step: proceed to `design` (or,
for a patch, stop -- `/feature` isn't used).

## design `[notes/context]` -- argue the *why* in a written spec

Write the design that argues the chosen approach before any code, then gate it on review. Skip the
standalone design for a patch; for a **small feature** this is the **brief that doubles as the plan**
(keep it short -- problem, approach, a task list, a done-when); for a **track** it is the **roadmap**
(written once, settling all phases). Copy the shape from `templates/plan-design.md` (or
`templates/roadmap.md` for a track) -- **preferring the project's `.agents/feature/templates/` override
if present**, else this bundled default (see *templates*) -- do not double-plan by also re-filling a
template by hand.

Checklist:
1. **Write the spec** with the template's sections: **Problem** (the root need, not a surface knob),
   **Goal**, **Approach** (+ the 1-2 alternatives rejected and why), **Mechanism** (concrete enough
   to implement from), **Verification** (how we'll know it works).
2. **Land it in the plans home** (*Host layout*) as `<YYYY-MM-DD>-<slug>-design.md`, with frontmatter
   `type: design`, `status: draft`, `updated: <today>`, `related: [...]` (on a clankshop host this
   is the record schema's `type`/`status` vocabulary, doc-linter enforced; keep the same
   frontmatter standalone). `design` moves
   `draft -> active -> shipped` as the feature advances.
3. **Spec self-review** (the lane's design-review gate, first half) -- scan the written spec for: placeholders
   (TBD/TODO/vague), internal contradictions, scope (focused enough for one plan?), ambiguity (any
   requirement readable two ways -> pick one, make it explicit). Fix inline.
4. **User-review gate** (the design-review gate's second half) -- ask the human to **review the written
   spec file** before planning. Make requested changes and re-run the self-review until approved.

Consumes `brainstorm`'s approach; produces the design doc. Terminal step: proceed to `plan` (passing
the design file).

## plan `<design-file>` -- the task-by-task implementation brief

Turn the approved design into a plan an implementer executes step by step, after re-grounding it
against the live tree. For a **small feature** this folds into `design`'s brief (no separate plan);
for a **track**, write one plan **per phase** from the roadmap. Copy
`templates/plan-implementation.md` (preferring the project's `.agents/feature/templates/` override if
present, else this bundled default -- see *templates*).

Checklist:
1. **Writing discipline** -- decompose into **bite-sized tasks** (each an independently testable
   deliverable with its own test cycle); give **exact file paths**; put **complete code in every
   step** (no "add error handling", no "similar to Task N"); DRY, YAGNI, TDD, frequent commits. Map
   the file structure first (one responsibility per file; right-size tasks so a reviewer could reject
   one without the others).
2. **Plan gate -- re-verify against `HEAD`** (the lane's walk step 3; the design ages well, the *literal
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
   - Name the load-bearing live-API traps from the host's gotchas list (`.handbook/rules/GOTCHAS.md`,
     when the host has one) in the plan's **Global Constraints** so each task re-verifies them.
3. **Plan self-review** -- spec coverage (every spec requirement maps to a task -- list gaps), a
   placeholder scan, and type/name consistency across tasks. Fix inline; add a task for any
   uncovered requirement.
4. **Land it** in the plans home as `<YYYY-MM-DD>-<slug>-implementation.md`, frontmatter `type:
   implementation`, `status: draft`, `updated`, `related: [<the design>]`. An ADR (the ADR home, via
   `templates/adr.md`) is part of this stage **only** if a cross-cutting decision surfaced -- one
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

**Green gate** (the lane's walk step 4): the host's full gate (*Host layout*) green **plus a
relevant end-to-end / scenario
check** before each commit; build in the worktree, never inline on the trunk. Optionally request a
**read-only** code-review subagent before finishing.

**`build` ends at gate-green and hands back.** It does **not** land (merge/ship) and does **not**
debrief -- the orchestrator owns both (see *Composition*).

## review `<doc>` -- independent ground-truthed critique of an existing artifact

Review a spine artifact someone already wrote -- a design, an implementation plan, a roadmap, or an
ADR -- as an **independent** second set of eyes, distinct from the *self*-review baked into `design`
and `plan` (self-review is the author checking their own work; this verb is not the author). The
**cross-cutting** verb: callable any time on any artifact, by any orchestrator (you, `/clankshop route`, a
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
     the host's design context (*Host layout*) and ADRs; scope = one plan; ambiguity resolved; YAGNI.
   - **implementation** -- **spec->plan coverage** (every design requirement maps to a task -- list
     gaps); bite-sized testable tasks, exact paths, complete code (no "similar to Task N"); plan-gate
     grounding; riskiest piece spiked first; load-bearing gotcha traps in
     Global Constraints (when the host has a gotchas list); per-task verify.
   - **roadmap** -- phase decomposition + build order/dependencies explicit; each phase shippable;
     cross-cutting decisions surfaced as ADRs.
   - **adr** -- decision + alternatives + consequences honest; supersession recorded.
   - **any type** -- internal consistency (no section contradicts another); frontmatter valid
     (per the record schema on a clankshop host); right altitude.
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

## Acting on review feedback -- yours, a human's, or an external reviewer's

`review`'s own terminal step hands a verdict to the artifact's owner and stops there -- what the owner
does with it is a distinct discipline, and it applies the same way whether the feedback came from
`/feature review`, a human, or an external tool (`/code-review`, a PR comment). No skill in this
library owned that receiving side before now:

1. **Verify before implementing -- feedback is a claim, not a decision.** Re-check it against the
   actual code/doc the same way `plan`'s gate re-verifies against `HEAD` (see *plan*, above): a
   reviewer's confident claim can still be wrong (a function that moved, a case that isn't actually
   reachable). Confirm it first -- implementing an unverified claim just relocates the error.
2. **No performative agreement.** Don't open with "you're absolutely right" or thank the reviewer
   before actually checking. State findings and actions plainly -- the same facts-not-verdicts posture
   this library takes toward its own claims, turned toward someone else's.
3. **One unclear item holds up the whole batch.** If any single piece of feedback is ambiguous,
   clarify **all** ambiguous items before implementing **any** of them -- don't half-implement a batch
   while genuinely unsure what part of it means.
4. **Grep before generalizing.** A "handle this more generally" / "make this configurable" suggestion
   gets a usage check first. If nothing in the codebase actually needs the generality, implementing it
   anyway is YAGNI regardless of how reasonable it sounds in isolation.
5. **Push back with reasoning when the feedback is wrong.** Disagreement is a legitimate outcome, not
   a failure to comply -- state the evidence, not just a refusal.

## setup -- register feature's front-door route

Make `/feature` visible in the project's always-loaded front-door doc. This is feature's **whole
self-init entry point** (not a spine stage) and its **only** job. On a pack install
`/clankshop setup` writes this block for every member at bootstrap; this verb exists for the
installs the composer never sees -- feature added to a stamped root after bootstrap, or feature
running **standalone** on a repo with no framework at all. It does **not** touch templates --
customizing a template shape is a separate, optional, on-demand action (see *templates* below)
that a project may never need.

The principle here is **visibility by construction**: a skill registers its route where the harness
already loads it, so it surfaces with no composer present. Idempotent: re-running is a
no-op beyond refreshing the `built-against` stamp; a sibling skill's own front-door block is never
touched.

Checklist:
1. **Resolve the front-door doc.** The registration target is the project's always-loaded
   front-door (`AGENTS.md`/`CLAUDE.md`, whichever the harness auto-loads). It must exist -- if
   the project has none, say so and **offer** to create a minimal one; creating a front door is
   the human's call, never a silent side effect.
   **Grimoire caveat (patient-zero):** never register against grimoire's own authored `AGENTS.md` -- see
   *The fixture caveat* below.
2. **Resolve the body + stamp by host** (*Host layout*):
   - **Clankshop host:** the body is feature's entry in the pack doctrine's **door profile** (the
     fenced `### /feature` block in `skills/clankshop/doctrine/README.md` -- the single source
     every pack route writer copies, never authored here), stamped
     `built-against:clankshop@<pack-version>` read from the root's installation block, carrying
     **no `Edges:` lines**. An existing pack-style block written by the composer is **adopted**
     (re-running converges byte-identically), never overwritten with a different body.
   - **Any other host:** feature's own bundled body, stamped `built-against:standalone` -- there
     is no pack to version against:
     ```markdown
     ### /feature — the planning pipeline
     Route: brainstorm → design → plan → build a feature to gate-green; planning artifacts to
     the project's plans home.
     ```
3. **Register.** Feed the resolved body on stdin to
   `scripts/register-route.sh <front-door> feature <stamp>`. Report `appended` / `replaced`. If
   it reports **malformed**, surface that -- a delimiter was hand-broken; the human repairs it,
   then re-run. Do **not** force it.

**The fixture caveat (grimoire is patient-zero -- model §3.2).** Grimoire's own `AGENTS.md` is authored
library doctrine, not a consuming project's scaffold -- self-registration blocks must never accrete in
it. In grimoire this verb is exercised only against a throwaway fixture front-door (a temp `AGENTS.md`
under the scratchpad, never the real one); in a consuming project the parameter resolves to that
project's real front-door, which is the whole point.

Produces the project's `skill:feature` front-door block; consumes nothing. Terminal step: a bare
reader of the front-door doc sees feature's route with no composer having run.

## templates `[<name>]` -- customize one planning-template shape, on demand

Deploy **exactly one** of this skill's bundled planning-artifact shapes as an editable,
project-specific override at `<root>/.agents/feature/templates/<name>.md`, **only when a project
actually wants to customize it**. There is no bulk-seed step and no unconditional scaffold: a project
that never customizes anything carries zero duplicated template files, and a project that customizes
one shape doesn't silently freeze the other three against future improvements to this skill's bundled
defaults (an earlier eager-seed-everything design did exactly that -- cut for violating YAGNI and for
the staleness footgun of a never-touched copy permanently shadowing the bundle).

**Resolution order (baked default vs. project override) is unchanged.** When `design` or `plan` copies
a shape, it **prefers the deployed override** `<root>/.agents/feature/templates/<name>.md` **if
present**, and falls back to this skill's **bundled** `templates/<name>.md` otherwise. The bundle is
always the working default; an override is opt-in, per-file, and created only on request. A skill that
ships customizable assets is **still not a steward** -- it owns no cross-cutting layer, it just deploys
files a project may edit.

Checklist:
1. **No `<name>` given** -- list the four available shapes (`adr`, `plan-design`,
   `plan-implementation`, `roadmap`) and ask which one to customize. Do not scaffold all four.
2. **Create-if-absent, one file.** If `<root>/.agents/feature/templates/<name>.md` already exists,
   report `exists=<name>` and stop -- **never** overwrite a project's edit. Otherwise:
   `mkdir -p <root>/.agents/feature/templates && cp templates/<name>.md <root>/.agents/feature/templates/<name>.md`
   (resolve the source `templates/<name>.md` from this skill's own base directory), then report
   `created=<name>` and the path. No script is needed for a single idempotent copy.
3. **Edit the override directly.** The file just created is a plain copy of the bundled default --
   tailor it now. The next `design`/`plan` picks it up by the resolution order above; no further
   action needed.

Produces the one deployed template override named; consumes nothing. Terminal step: the named
override is on disk (or already was), and the spine verbs resolve against it on their next run.

## State between verbs = the spine artifacts

There is no separate `/feature` state file. Each verb consumes the previous verb's artifact by path:
`brainstorm`'s approach lives in context -> `design` writes the design doc -> `plan` reads it and
writes the implementation plan -> `build` reads the plan and checks off its tasks. Those artifacts
live in the plans home (*Host layout*; on a clankshop host they are the `.records/plans/` docs the
record schema catalogs), and each doc's frontmatter `status` tracks its lifecycle.
`review` is the exception: it **consumes** any of these artifacts by path and produces only an
in-context verdict, adding nothing to the chain (artifact-free, like `brainstorm`).

## Composition (the orchestrator owns landing + capture)

`/feature` is the plan+build engine; an orchestrator sequences its verbs and owns everything around
them. **`/feature` never debriefs, ships, or lands.**

- **Standalone** (a one-off feature) -> the user runs `brainstorm -> design -> plan -> build`, then
  lands the work and sweeps the follow-ups it surfaced -- **`/backlog debrief`** on a clankshop
  host (the lane's close-the-books step), the project's own convention otherwise.
- **Inside `/workstream`** -> the stream calls `/feature` per queue item; `build` stops at gate-green
  and **hands back**. Landing, capture, and the reset ritual around the hand-back are `/workstream`'s to
  run and document — `/feature` initiates none of it.
- **`/clankshop route`** (router) -> for a feature, dispatches into `/feature` at the right verb (start at
  `brainstorm`, or jump to `design`/`plan` if an approach/spec already exists).
- **`review`** (cross-cutting) -> any orchestrator can call it on an artifact at any point: after
  `design` as an independent gate before `plan`, after `plan` before `build`, or standalone (a
  coordinator reviewing another stream's doc). **For a multi-task feature, running `review` on the
  plan between `plan` and `build` is recommended by default**, not only on request -- an independent
  ground-truthed pass there has repeatedly caught must-fix bugs before any code was written. It is artifact-free and changes nothing -- the verdict
  goes back to whoever owns the artifact, who decides what to revise.

## Structure, plugin posture, portability

- A self-contained skill directory (`SKILL.md` + `templates/` -- this skill bundles the artifact
  shapes it produces: `plan-design.md` / `plan-implementation.md` / `roadmap.md` / `adr.md`).
- The upstream superpowers planning skills stay **installed and unused** for planning -- `/feature` is
  uniquely named, so nothing collides and no settings/plugin toggle is needed; their session bootstrap
  is unaffected. They simply go unused for the plan-and-build path.
- **Portable:** `/feature` is a self-contained skill directory, so the planning engine travels as one
  unit wherever the skills are installed (vendored in a repo, or a shared global skills home).
