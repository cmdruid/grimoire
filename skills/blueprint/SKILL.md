---
name: blueprint
description: "The planning spine as verbs — `/blueprint brainstorm | grill | spec | roadmap | plan | review`. Turns an idea into an argued spec, a decision-map roadmap, and a tracer-bullet implementation plan; `grill` is the standalone interview primitive (relentless questioning until every decision branch resolves) and `review` the two-axis critique (soundness + groundedness) of any planning artifact. Use when the user runs `/blueprint ...`, or asks to brainstorm / grill / spec / roadmap / plan / review a feature, design, or planning doc. Building is not blueprint's job — the approved plan hands off to the host's build lane. For a one-line patch, skip it (fix on the trunk)."
---

# blueprint — the planning spine

`/blueprint <verb> [args]` runs the planning spine: divergent ideation (`brainstorm`), the
interview that resolves every open decision (`grill`), the argued specification (`spec`), the
multi-phase decision map (`roadmap`), and the tracer-bullet implementation plan (`plan`) — plus
the cross-cutting `review`, an independent two-axis critique of any artifact the others produce.
**Building is not blueprint's job**: the approved plan hands off to the host's build lane (on a
workshop host, the build station's workflows). Landing and the debrief sweep stay with the
orchestrator; `/blueprint` never builds, lands, or debriefs.

This skill is **self-contained and uniquely named**: it depends on no other skill and collides
with none.

## One environment probe (at entry)

Does `<root>/.handbook/README.md` exist and carry the clankshop install stamp (a line matching
`Seeded from clankshop`)? That single fact picks the homes and context; nothing else is probed,
and no verb ever refuses or stalls for lack of a workshop.

- **Workshop present** → artifacts are records: specs and design docs in the `design/` store,
  roadmaps and plans in `plans/`, ADRs in `adr/` — minted with the deployed
  `<records-root>/scripts/records.sh new <store> --title "…"` (the front-matter contract is
  stamped at write time; the records root is the declared `records-root:`, else `.records/`).
  **Blueprint owns these stores' templates and lazy-deploys them** (the records contract's
  template convention): before minting, copy the bundled template into
  `<records-root>/templates/<doctype>.md` when absent — `templates/plan.md` → `plans.md`,
  `templates/spec.md` → `design.md`, `templates/adr.md` → `adr.md` (the templates carry the
  contract front-matter plus the `<title>`/`<date>` mint slots; body sections are the
  authoring scaffold). **Summon station context per verb**
  (`.handbook/scripts/context.sh <station>`): the **design station** for
  `brainstorm`/`grill`/`spec`/`review`, the **build station** for `roadmap`/`plan`.
- **Standalone** → confirm an **output home** once (default `docs/`); artifacts are the bundled
  `templates/` copied whole (they carry the same front-matter vocabulary, so a later migration
  adopts them unchanged). The project's own design docs and READMEs stand in for station
  context.

**Status vocabulary** (the records contract): a working draft is `status: open`; the accepted,
living spec is promoted to `status: current` (one per subject); closure — `done`, `dropped`,
`superseded`, `consumed` — goes through `records.sh done` on a workshop host.

## The verbs

| Verb | Does | Consumes → Produces | Station |
|---|---|---|---|
| `brainstorm [topic]` | divergent ideation → a draft design doc | conversation + prompt → `design/` doc (`status: open`) | design |
| `grill [doc]` | the interview primitive: question until every decision branch resolves | a draft design / spec / plan (or the conversation) → resolved decisions (in the doc or in context) | design |
| `spec [doc]` | synthesize → grill the gaps → the argued spec | conversation or draft → `design/` spec, candidate for `status: current` | design |
| `roadmap` | multi-phase decision map for large work | a spec → `plans/` roadmap: phases, gates, blocking edges | build |
| `plan [spec/phase]` | tracer-bullet implementation plan | a spec or roadmap phase → `plans/` plan: thin end-to-end slices | build |
| `review <doc>` | two-axis critique: **soundness** + **groundedness** | any planning artifact → a verdict (in context) | design |

`brainstorm → spec → (roadmap →) plan` is the linear spine; `grill` and `review` are
primitives callable at any point, on any artifact. Weight scales with the work: a **small
feature** takes a spec that doubles as its plan (skip `roadmap`, fold `plan` in); **large
work** — more than one phase, or a decision worth an ADR — takes a roadmap once, then a plan
per phase. When unsure, start small and promote the moment a second phase or a cross-cutting
decision appears. For a **patch**, blueprint is not used at all.

## brainstorm `[topic]` — divergent ideation into a draft design

Open the space before narrowing it. **Harvest the current conversation first** — pull every
constraint, preference, and half-decision already stated into the draft before asking anything;
never start from a blank template.

1. **Explore context** — the relevant code, docs, recent commits, and the host's design context
   (workshop: design-station summon + the `design/` store's `status: current` spec; standalone:
   the project's own design docs) before asking anything. Don't brainstorm blind.
2. **Scope check** — an idea spanning several independent subsystems decomposes into separate
   features first; brainstorm the first one. **And ask "is this already built?"** — probe by
   *capability* keywords repo-wide (not just the subsystem you expect it in), and `ls`/glob every
   path or name the idea would claim (plus the host's skills/workflows registry where one exists).
   An existing implementation turns the feature into a docs/discoverability task — the cheapest
   outcome, and one that has otherwise surfaced only at execution, after a design doc, an ADR, and
   a first commit duplicated it.
3. **Diverge** — propose 2–3 genuinely different approaches with trade-offs; lead with a
   recommendation and say why.
4. **Converge conversationally** — one question at a time (multiple-choice when possible),
   confirming each section before the next. YAGNI ruthlessly.
5. **Write the draft** — a `design/` doc (`status: open`), shaped per `templates/spec.md`'s
   sections at draft weight: problem, goal, candidate approach, open questions listed at the
   foot. Unresolved branches are *expected* here — `grill` or `spec` resolves them.

Output: the draft design doc. Terminal step: hand to `grill`/`spec` (or stop — a draft is a
legitimate resting state).

## grill `[doc]` — the interview primitive

Relentless questioning until **every decision branch resolves**. Standalone by design: point it
at a draft design, a spec, a roadmap, a plan — or nothing (it grills the current conversation's
proposal). `grill` writes no artifact of its own; it drives decisions into whichever doc it was
aimed at (or leaves them in context for the calling verb).

1. **Build the decision tree** — read the doc/conversation and enumerate every open branch:
   unstated assumptions, either/or forks, vague quantities ("fast", "some"), unowned risks,
   undefined terms. Each becomes a question.
2. **Ask in rounds** — numbered questions, a few per round, **each with a recommended answer
   and why** (the human confirms or overrides in one word). Multiple-choice when the options
   are enumerable; open only when they aren't. Never a wall of questions covering the whole
   tree at once — later rounds depend on earlier answers.
3. **Chase the consequences** — every answer can open new branches; keep going until a full
   round surfaces nothing new. Resolved ≠ mentioned: a decision is resolved when its
   consequence is stated and the human has confirmed it.
4. **Write the decisions back** — into the target doc's relevant sections (a "Decisions
   settled" section for a plan/roadmap; the argued sections of a spec), or hand the resolved
   list to the calling verb. Record *who settled it and when* for the load-bearing ones.

Output: a doc (or context) with no unresolved decision branches. Terminal step: return to the
calling verb (`spec`, `roadmap`, `plan`) or the human.

## spec `[doc]` — synthesize, grill the gaps, argue the result

Produce the **argued specification** — concrete enough that a gap between design and code is
detectable, and measurable once found. Start from a `brainstorm` draft, an existing doc, or the
conversation itself.

1. **Synthesize first** — assemble everything already decided (conversation, draft, prior
   ADRs) into the spec's shape before asking anything.
2. **Grill the gaps** — run `grill` on the assembled draft: every remaining open branch gets
   resolved, not papered over.
3. **Write the spec** per `templates/spec.md`: **Problem** (root need, not a surface knob),
   **Goal**, **Approach** (+ alternatives rejected and why), **Mechanism** (concrete enough to
   implement from), **Verification** (how we'll know it works). A cross-cutting decision that
   surfaced gets its ADR (`templates/adr.md`, the `adr/` store) — one per decision, linked.
   **A numeric before/after acceptance target needs a population ATTRIBUTION, not just a count:**
   dump a few instances of the metric's population, section one, and name which mechanism/class
   produces it — a real count over the *wrong class* passes every review and dies only at
   measurement (observed: a headline "162 → 0" whose population belonged entirely to a class the
   mechanism deliberately excluded).
4. **Self-review** — placeholders (TBD/vague), internal contradictions, scope (one plan's
   worth?), ambiguity (any requirement readable two ways → pick one, make it explicit). **And the
   greenfield check:** is any mechanism shaped by a constraint we could *delete* instead (a code
   built-in, an integer substrate, a frozen baseline that could re-baseline)? Name each such
   constraint explicitly as pay-the-debt vs design-around — grounded review structurally cannot
   supply this (a reviewer refuting claims against `HEAD` never flags that `HEAD` itself is the
   problem).
5. **User-review gate** — the human reviews the written spec before anything plans against it.
   For an ADR-tier spec, an independent `review` first is recommended by default — design-stage
   review has caught must-fix defects before any plan existed.
   On approval it becomes the candidate `status: current` spec (workshop: flip via
   `records.sh touch <spec> --status current`; the superseded spec, if any, closes
   `--as superseded` naming its successor).

Output: the argued spec. Terminal step: `roadmap` (large work) or `plan` (single phase).

## roadmap — the multi-phase decision map

For work too large for one plan: phases with **gates** and **declared blocking edges**, written
once against the approved spec. Build-station work: it sequences execution, it does not
redesign (a design gap found here routes back to `spec`).

Shape per `templates/roadmap.md`:

- **Phases** — each a coherent, independently-valuable slice with: goal, scope (in/out), a
  **gate** (the exit criteria that make "done" checkable), and risks.
- **Blocking edges, declared** — which phases require which (`requires: phase N`), and which
  are parallel-eligible. The edges are the map's load-bearing content — sequencing follows
  from them, not from prose order.
- **Each phase requires its own `plan` before build** — the roadmap never carries task-level
  detail.

Output: the `plans/` roadmap (`status: open`; flip `current` while it governs). Terminal step:
`plan` the first unblocked phase.

## plan `[spec/phase]` — the tracer-bullet implementation plan

Turn the approved spec (or one roadmap phase) into a plan an implementer executes: **thin
end-to-end slices**, each proving the path through the whole system before the next widens it —
not horizontal layers that integrate only at the end. Re-ground against the live tree before
writing.

1. **Slice tracer-first** — slice 1 is the thinnest change that exercises the riskiest/newest
   path end to end (a green unit test can hide a blank render — verify a *new* render/tech
   path visually in isolation; a reused, proven path where only wiring is new needs only a
   wiring test). Later slices widen coverage; each is independently testable and committable,
   with **blocking edges declared** between slices that genuinely depend on each other.
   **When the acceptance bar is subjective** (art, UX, feel), slice 1 is an **owner-gated concept
   sample** — one from-scratch instance the human approves *before* any propagation slice (a v1
   that passed every technical gate has been rejected whole on taste, wasting the propagation).
2. **The plan gate — re-verify against `HEAD`** (a spec ages well; the literal code it cites
   ages fast): re-read every load-bearing signature / path / count against the worktree's
   `HEAD` before sizing. A claim **inherited from a scout, sub-agent, or queued item** is
   exactly what this gate re-verifies, never trusts. **Ground via a dispatched read-only sweep as
   the plan's literal Task 0** — a sub-agent checking every queued item's symbols/files against
   the done trail and live code, not a mental "does this still look right" pass (3-for-3 catching
   already-shipped or sibling-drained items before build time; the vaguer phrasing lets an author
   skip to a shallower check). Two claim-specific verdicts: an **"is X still used"** claim needs
   narrow-then-compile — grep produces the candidate list, the compiler/dead-code analysis issues
   the verdict (a complete grep has confidently named test-only callers as live); and a
   **prior-art check** — search capability-wide for an existing implementation before sizing new
   work. `scripts/ground-check.sh <root> <spec>`
   lists the rooted path / `file:line` references that no longer resolve (facts, not a
   verdict: you still re-read the signatures — **a reference that *resolves* can still point at
   the wrong code**; the script proves the path exists, never that the line supports the prose).
   **Re-measure before you size** — run the real
   tool against `HEAD`; a snapshot count is a guess. Name the host's load-bearing gotchas
   (workshop: `core/GOTCHAS.md`) in the plan's Global Constraints.
3. **Writing discipline** — exact file paths; complete code in every slice (no "add error
   handling", no "similar to slice N"); **a verification step per slice** (command + expected
   result); DRY, YAGNI, red-first. Two shape rules: a **new shared public type pins its
   derives/traits** alongside its fields (parallel implementers otherwise each invent a bridge
   around the missing ones); and an **exploratory/spike slice** is a legitimate distinct shape —
   when the slice's point is to *discover* an algorithm, write it as a v0 implementation + an
   **objective probe as the acceptance test** + a bounded measure-and-iterate loop with a stated
   convergence target and an escalate/fallback branch, instead of pretending the answer is known
   and faking complete code.
4. **Self-review** — spec→plan coverage (every requirement maps to a slice — list gaps),
   placeholder scan, type/name consistency. Add a slice for any uncovered requirement.
5. **Land it** per `templates/plan.md` in the `plans/` store (workshop) or the output home.

Output: the implementation plan. Terminal step: **hand off to the host's build lane** (workshop:
the build station's feature lane runs it red-first to the green gate; a `/workstream` builds it
per its own loop). For a multi-slice plan, running `review` on it first is recommended by
default — its value is **bimodal, and both modes pay**: either an independent grounded pass
catches must-fix defects before any code (repeatedly: compile breaks, missed callers, perf
regressions, insufficient test oracles), or it independently corroborates the plan's own flagged
uncertainties, de-risking building every slice in one pass — and there is no cheap way to know in
advance which mode a given plan will get.

## review `<doc>` — the two-axis critique

Independent second-set-of-eyes on any planning artifact — distinct from the self-review baked
into `spec` and `plan` (the author checking their own work; this verb is not the author).
Artifact-free: findings + a verdict in context, no file written, nothing edited. It reviews
**documents, not diffs** — a code change is `/code-review`.

1. **Read the whole doc; detect its kind** (design/spec, roadmap, plan, adr) from front-matter
   or shape, to pick the rubric weighting.
2. **Axis 1 — soundness** (internally consistent, feasible): no section contradicts another;
   the approach is justified with alternatives honestly weighed; the mechanism is
   implementable as written; scope is one artifact's worth; every requirement is unambiguous;
   for a roadmap/plan, the blocking edges are complete and acyclic and each slice/phase has a
   real verification/gate. Two verification-sufficiency checks the hand-trace habit misses:
   a **numeric acceptance target** must attribute its population to the mechanism's target class
   (a real count over the wrong class survives every rubric and dies at measurement); and every
   **guard/absence-style test** ("asserts X never happens") needs a **red-proof** — disable the
   guarded mechanism once and show the test fails, or argue concretely why the fixture can
   exercise the failing arm (hand-tracing verifies the green path; it never asks whether the
   test *can* go red — a fixture whose world cannot contain X stays green with the guard
   deleted).
3. **Axis 2 — groundedness** (conforms to the codebase — and to core doctrine when a workshop
   is present): run `scripts/ground-check.sh <root> <doc>`, then **re-read the load-bearing
   signatures/code the claims rest on** (a clean ground-check finds moved files; the trap is a
   confident doc citing a function that never existed — or a `file:line` that resolves but
   points at different code than the prose claims). On a workshop host, check the doc
   against `core/` (invariants, gotchas) and the `status: current` spec + live ADRs.
   **For a design/spec, add the substrate-skeptic pass** — grounding anchors the review to the
   present code, so deliberately ask its inverse: *which mechanisms would not exist in a
   from-scratch implementation?* A mechanism shaped by deletable substrate (a code built-in, an
   integer pipeline, a frozen baseline) is a finding even when every claim about `HEAD` is true.
4. **Report the verdict, in context**: `approve` / `approve-with-changes` / `needs-rework`;
   findings ranked by severity, each as location → what's wrong → why it matters → a concrete
   fix, must-fix separated from nice-to-have; a confidence note on anything unsure — never a
   guess presented as fact. **A blocking verdict is a durable fact about the artifact, not
   session chatter:** on `needs-rework`, also write the finding list into the artifact itself (a
   dated "Review history" section the owner prunes on resolution) — a nine-finding verdict that
   lived only in context has cost a full re-review after a session park. An approve verdict
   changes nothing and stays in context.

Depth dial (default off): for a high-stakes artifact, dispatch a few **read-only** subagents in
parallel — each a distinct lens, one a skeptic trying to *refute* the doc's central claim — and
synthesize. Never an editing subagent.

Terminal step: hand the verdict to whoever owns the artifact — `review` changes nothing itself.

## Acting on review feedback — yours, a human's, or an external reviewer's

`review` hands a verdict to the artifact's owner and stops. The receiving side is its own
discipline, the same whether the feedback came from `/blueprint review`, a human, or an
external tool:

1. **Verify before implementing — feedback is a claim, not a decision.** Re-check it against
   the actual code/doc (the plan gate's posture): a reviewer's confident claim can still be
   wrong. Implementing an unverified claim just relocates the error. This applies with full
   force to **folding a finding into the artifact**: a fold is itself unverified content that
   bypasses the grounding gate the artifact's own claims passed through — re-ground a fold like
   any inherited claim, or mark it `(unverified — check at build)` (observed: a fold's confident
   nice-to-have claim was transcribed as fact and falsified at build).
2. **No performative agreement.** Don't thank or agree before actually checking; state
   findings and actions plainly.
3. **One unclear item holds up the whole batch** — clarify all ambiguous items before
   implementing any.
4. **Grep before generalizing** — a "make this configurable" suggestion gets a usage check
   first; unneeded generality is YAGNI regardless of how reasonable it sounds.
5. **Push back with reasoning when the feedback is wrong** — disagreement is a legitimate
   outcome; state the evidence.

## State between verbs = the artifacts

There is no separate blueprint state file. Each verb consumes the previous verb's artifact by
path: `brainstorm`'s draft → `spec` argues it → `roadmap`/`plan` sequence it — and each doc's
front-matter `status` tracks its lifecycle. `grill` and `review` are the exceptions: primitives
that consume any artifact and write no new one.

## Composition (the orchestrator owns building, landing, capture)

- **Standalone** — the user runs the spine, then the host's build lane executes the plan; the
  close-the-books sweep is `/backlog debrief` on a workshop host, the project's own convention
  otherwise.
- **Inside `/workstream`** — the stream calls the planning verbs per queue item and builds the
  plan itself per its own loop; landing, capture, and the reset ritual are the stream's.
- **Workshop routing** — the handbook's routing walk dispatches design-at-stake work here
  (`/blueprint`, where installed, runs the spine and hands the approved plan back to the
  lane).

## Structure, portability

- A self-contained skill directory: `SKILL.md` + `templates/` (`spec.md`, `plan.md`,
  `roadmap.md`, `adr.md` — the bundled body shapes) + `scripts/ground-check.sh` (the
  re-grounding fact-checker) + `docs/ideal-use.md` (a worked arc).
- **Portable:** no workshop dependency (the one probe degrades to standalone), no host paths
  baked in, travels as one unit wherever the skills are installed.
