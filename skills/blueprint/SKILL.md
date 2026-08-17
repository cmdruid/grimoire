---
name: blueprint
description: "Use when the user runs `/blueprint`, or asks to brainstorm, grill, or write a spec for a feature or design; or when starting a new project / new repository from scratch (`new`, `deploy`, founding spec, no repo yet). Turns an idea into an argued specification. grill is the interview primitive until every decision branch resolves. review critiques a spec or design doc (soundness + groundedness). Does not write roadmaps or implementation plans and does not build. For a one-line patch, skip it (fix on the trunk)."
---

# blueprint — the specification spine

`/blueprint <verb> [args]` runs the specification spine: divergent ideation
(`brainstorm`), the interview that resolves every open decision (`grill`), the
argued specification (`spec`), and the cross-cutting `review` — an independent
two-axis critique of a spec or design doc. Genesis is two verbs around that
spine: `new` mints a founding-shaped working file; `grill`/`spec` fill it in
place; `deploy` materializes a **new** repository. **Building is not
blueprint's job**, and neither is sequencing implementation. Trunk landing
and the debrief sweep stay with the orchestrator. `deploy` materializes a new
repository; it does not land onto a host trunk.

This skill is **self-contained and uniquely named**: it depends on no other skill
and collides with none.

## One environment probe (at entry)

Does `<root>/.handbook/README.md` exist and carry the clankshop install stamp (a
line matching `Seeded from clankshop`)? That single fact picks the homes and
context; nothing else is probed, and no verb ever refuses or stalls for lack of
a workshop.

- **Workshop present** → artifacts are records: specs and design docs in the
  `design/` store, ADRs in `adr/` — minted with the deployed
  `<records-root>/scripts/records.sh new <store> --title "…"` (the front-matter
  contract is stamped at write time; the records root is the declared
  `records-root:`, else `.records/`). **Blueprint owns these stores' templates
  and lazy-deploys them** (the records contract's template convention): before
  minting, copy the bundled template into
  `<records-root>/templates/<doctype>.md` when absent — `templates/spec.md` →
  `design.md`, `templates/adr.md` → `adr.md` (the templates carry the contract
  front-matter plus the `<title>`/`<date>` mint slots; body sections are the
  authoring scaffold). **Summon the design station** for every blueprint verb
  (`.handbook/scripts/context.sh design`).
- **Standalone** → confirm an **output home** once (default `docs/`); artifacts
  are the bundled `templates/` copied whole (they carry the same front-matter
  vocabulary, so a later migration adopts them unchanged). The project's own
  design docs and READMEs stand in for station context.

**Probe exemption.** The records-mint / output-home path above applies to
`brainstorm`, feature `spec`, and ADRs. It does **not** apply to `new` or
`deploy`, and it does **not** apply to `grill`/`spec` when the named file is
founding-shaped (*Founding-shaped* below). Those stay on the cwd working file.

**Status vocabulary** (the records contract): a working draft is `status: open`;
the accepted, living spec is promoted to `status: current` (one per subject);
closure — `done`, `dropped`, `superseded`, `consumed` — goes through
`records.sh done` on a workshop host. Founding-shaped working files stay
`status: open`. They are not the living feature spec. Do not promote them
to `status: current`.

## The verbs

| Invocation | Does | Consumes → Produces | Station |
|---|---|---|---|
| (none) | `brainstorm` | conversation + prompt → `design/` doc (`status: open`) | design |
| `brainstorm [topic]` | divergent ideation → a draft design doc | conversation + prompt → `design/` doc (`status: open`) | design |
| `new <name>` | mint `./<name>.md` — founding-shaped, empty of design content | — → that file only | — |
| `grill [doc]` | interview until every decision branch resolves; founding-shaped → fill the six map H2s **in place** | a draft / spec (or the conversation) → resolved decisions | design |
| `spec [doc]` | synthesize → grill the gaps → the argued spec; founding-shaped → fill the map **in place** (no records mint, no reshape) | conversation or draft → feature `design/` spec, **or** the named founding file | design |
| `review <doc>` | two-axis critique; founding-shaped → six-H2 + leftover/gap rubric | a spec or design doc → a verdict (in context) | design |
| `deploy <file>` | project a founding spec into a new repo + three founding docs | founding file → git repository | — |

`brainstorm → spec` is the linear spine; `grill` and `review` are primitives
callable at any point. Bare `/blueprint` stays `brainstorm`. Genesis is
explicit `new`. Weight scales with the work: a **small feature** may stop
at the accepted spec (the spec doubles as its plan — slices live **in**
`templates/spec.md`, not a separate job artifact). For a **patch**, blueprint
is not used at all.

`new` lives in `verbs/new.md` and `deploy` in `verbs/deploy.md` — read the
verb file and follow it. `grill` / `spec` / `review` / `brainstorm` stay
inline and gain a founding-shaped branch below.

## Founding-shaped

A file is **founding-shaped** iff it has `founding` in `tags:` **and** its
structural H2 set is exactly the six map strings in `templates/founding.md`,
each appearing once. That template owns the H2 strings; if they drift, the
template wins. A duplicate mapped H2 or an extra unmapped H2 fails the shape.

**Parser** (one grammar; founding `grill` / `spec` / `review` and `deploy`
share it):

1. **Front-matter.** If the file begins with a line `---`, YAML through the
   next line that is only `---`. `tags:` is a YAML sequence; `founding` is
   present iff that sequence contains the string `founding`.
2. **Structural H2.** A line matching `^##[ \t]+\S` that is **not** inside a
   fenced code block (`` ``` `` or `~~~`). A `##` line inside a fence is body
   content, not a heading.
3. **Body span** of an H2 = bytes after that heading line until the next
   structural H2 or EOF.
4. **Permitted chrome** (discarded, not leftover): the front-matter, one ATX
   H1 (`^#[ \t]+`), and blank lines around those.
5. **Leftover H2** = a structural H2 whose exact string is not in the
   template map. **Authored leftover** = any non-whitespace byte outside
   permitted chrome and outside a mapped body (pre-map prose, trailing
   prose). Either leftover class refuses `deploy` and is a `review` finding.

**Gap vs settled** (mapped bodies only). Strip whole lines matching
`^Settled: [0-9]{4}-[0-9]{2}-[0-9]{2}\.$` and remaining whitespace.
Remainder empty → **gap**. Any remaining byte → **settled**. Who/when-only
is a gap. No italic / `TBD` / `<>` special cases.

**Branch** (on a named `[doc]`; never scan cwd for a founding file):

- **Founding-shaped** → stay on that file. Fill the six map H2s in place.
  Do not rewrite to `templates/spec.md`. Do not mint a `design/` record.
  Do not strip `founding`. Do not add an H2 that is not in the map. Do not
  promote `status`. Who/when notes go **inside** the mapped section as a
  whole line in this exact form (roman, not italic): `Settled: YYYY-MM-DD.`
- **No `founding` tag and H2s are not the map** → existing feature-spec
  `grill` / `spec` / `review` (may reshape / records-mint).
- **Otherwise** (tag without the exact map, map without the tag, duplicate
  mapped H2) → refuse: restore the shape with `/blueprint new` or fix the
  H2 set. Do not reshape. Do not deploy-path this file.

## brainstorm `[topic]` — divergent ideation into a draft design

Open the space before narrowing it. **Harvest the current conversation first** —
pull every constraint, preference, and half-decision already stated into the
draft before asking anything; never start from a blank template.

1. **Explore context** — the relevant code, docs, recent commits, and the host's
   design context (workshop: design-station summon + the `design/` store's
   `status: current` spec; standalone: the project's own design docs) before
   asking anything. Don't brainstorm blind.
2. **Scope check** — an idea spanning several independent subsystems decomposes
   into separate features first; brainstorm the first one. **And ask "is this
   already built?"** — probe by *capability* keywords repo-wide (not just the
   subsystem you expect it in), and `ls`/glob every path or name the idea would
   claim (plus the host's skills/workflows registry where one exists). An
   existing implementation turns the feature into a docs/discoverability task —
   the cheapest outcome, and one that has otherwise surfaced only at execution,
   after a design doc, an ADR, and a first commit duplicated it.
3. **Diverge** — propose 2–3 genuinely different approaches with trade-offs;
   lead with a recommendation and say why.
4. **Converge conversationally** — one question at a time (multiple-choice when
   possible), confirming each section before the next. YAGNI ruthlessly.
5. **Write the draft** — a `design/` doc (`status: open`), shaped per
   `templates/spec.md`'s sections at draft weight: problem, goal, candidate
   approach, open questions listed at the foot. Unresolved branches are
   *expected* here — `grill` or `spec` resolves them.

Output: the draft design doc. Terminal step: hand to `grill`/`spec` (or stop — a
draft is a legitimate resting state).

## grill `[doc]` — the interview primitive

Relentless questioning until **every decision branch resolves**. Standalone by
design: point it at a draft design, a spec — or nothing (it grills the current
conversation's proposal). A job artifact with open decision branches means the
**spec** is not settled — grill the spec, not the job artifact. `grill` writes
no artifact of its own; it drives decisions into whichever doc it was aimed at
(or leaves them in context for the calling verb).

If `[doc]` is named, classify it (*Founding-shaped*) **before** the steps
below. Founding-shaped → fill the six map H2s in place under that branch;
do not run the feature-spec reshape. Refuse the otherwise-case. They never
scan cwd for a founding file.

1. **Build the decision tree** — read the doc/conversation and enumerate every
   open branch: unstated assumptions, either/or forks, vague quantities
   ("fast", "some"), unowned risks, undefined terms. Each becomes a question.
2. **Ask in rounds** — numbered questions, a few per round, **each with a
   recommended answer and why** (the human confirms or overrides in one word).
   Multiple-choice when the options are enumerable; open only when they aren't.
   Never a wall of questions covering the whole tree at once — later rounds
   depend on earlier answers.
3. **Chase the consequences** — every answer can open new branches; keep going
   until a full round surfaces nothing new. Resolved ≠ mentioned: a decision is
   resolved when its consequence is stated and the human has confirmed it.
4. **Write the decisions back** — into the target doc's argued sections, or
   hand the resolved list to the calling verb. Record *who settled it and when*
   for the load-bearing ones.

Output: a doc (or context) with no unresolved decision branches. Terminal step:
return to the calling verb (`spec`) or the human.

## spec `[doc]` — synthesize, grill the gaps, argue the result

Produce the **argued specification** — concrete enough that a gap between
design and code is detectable, and measurable once found. Start from a
`brainstorm` draft, an existing doc, or the conversation itself.

If `[doc]` is named, classify it (*Founding-shaped*) **before** the steps
below. Founding-shaped → synthesize into the six map H2s on that same file;
run `grill` on those sections; do not write Problem / Goal / Approach as
H2s; skip the records-mint, `templates/spec.md` rewrite, and status
promotion. Refuse the otherwise-case. They never scan cwd.

1. **Synthesize first** — assemble everything already decided (conversation,
   draft, prior ADRs) into the spec's shape before asking anything.
2. **Grill the gaps** — run `grill` on the assembled draft: every remaining
   open branch gets resolved, not papered over.
3. **Write the spec** per `templates/spec.md`: **Problem** (root need, not a
   surface knob), **Goal**, **Approach** (+ alternatives rejected and why),
   **Mechanism** (concrete enough to implement from), **Verification** (how
   we'll know it works). A small feature may add the optional **Slices** stub
   in that same file (id / verify command / paths). A cross-cutting decision
   that surfaced gets its ADR (`templates/adr.md`, the `adr/` store) — one per
   decision, linked. **A numeric before/after acceptance target needs a
   population ATTRIBUTION, not just a count:** dump a few instances of the
   metric's population, section one, and name which mechanism/class produces it
   — a real count over the *wrong class* passes every review and dies only at
   measurement (observed: a headline "162 → 0" whose population belonged
   entirely to a class the mechanism deliberately excluded).
4. **Self-review** — placeholders (TBD/vague), internal contradictions, scope
   (one feature's worth?), ambiguity (any requirement readable two ways → pick
   one, make it explicit). **And the greenfield check:** is any mechanism
   shaped by a constraint we could *delete* instead (a code built-in, an
   integer substrate, a frozen baseline that could re-baseline)? Name each such
   constraint explicitly as pay-the-debt vs design-around — grounded review
   structurally cannot supply this (a reviewer refuting claims against `HEAD`
   never flags that `HEAD` itself is the problem).
5. **User-review gate** — the human reviews the written spec before anything is
   sequenced against it. For an ADR-tier spec, an independent `review` first is
   recommended by default — design-stage review has caught must-fix defects
   before any cut existed. On approval it becomes the candidate
   `status: current` spec (workshop: flip via
   `records.sh touch <spec> --status current`; the superseded spec, if any,
   closes `--as superseded` naming its successor).

Output: the argued spec. Terminal step: **stop**. The accepted spec is the
artifact. Implementation sequencing is a different job.

## review `<doc>` — the two-axis critique

Independent second-set-of-eyes on a **spec or design doc** — distinct from the
self-review baked into `spec` (the author checking their own work; this verb is
not the author). Artifact-free: findings + a verdict in context, no file
written (except a `needs-rework` write-back). It reviews **documents, not
diffs** — a code change is the host's code-review tooling.

This verb reviews **specs and design docs only** (an ADR written from `spec`
counts). A sequenced plan, multi-phase map, or conductor is the wrong artifact
for this review — refuse it.

1. **Read the whole doc; detect its kind** from front-matter or shape. A job
   artifact → refuse ("wrong artifact for this review"). If founding-shaped
   (*Founding-shaped*): soundness uses the six map H2s + leftover/gap
   rules, not `templates/spec.md`. Groundedness is against the bundled
   `templates/founding.md`, the deploy procedure (`verbs/deploy.md`), and
   live behavior — not a library design doc. Do not promote `status`.
   Feature-spec `review` is otherwise unchanged.
2. **Axis 1 — soundness** (internally consistent, feasible): no section
   contradicts another; the approach is justified with alternatives honestly
   weighed; the mechanism is implementable as written; scope is one artifact's
   worth; every requirement is unambiguous. Two verification-sufficiency checks
   the hand-trace habit misses: a **numeric acceptance target** must attribute
   its population to the mechanism's target class (a real count over the wrong
   class survives every rubric and dies at measurement); and every
   **guard/absence-style test** ("asserts X never happens") needs a
   **red-proof** — disable the guarded mechanism once and show the test fails,
   or argue concretely why the fixture can exercise the failing arm
   (hand-tracing verifies the green path; it never asks whether the test *can*
   go red — a fixture whose world cannot contain X stays green with the guard
   deleted).
3. **Axis 2 — groundedness** (conforms to the codebase — and to core doctrine
   when a workshop is present): run `scripts/ground-check.sh` `<root> <doc>`,
   then **re-read the load-bearing signatures/code the claims rest on** (a
   clean ground-check finds moved files; the trap is a confident doc citing a
   function that never existed — or a `file:line` that resolves but points at
   different code than the prose claims). On a workshop host, check the doc
   against `core/` (invariants, gotchas) and the `status: current` spec + live
   ADRs. **Add the substrate-skeptic pass** — grounding anchors the review to
   the present code, so deliberately ask its inverse: *which mechanisms would
   not exist in a from-scratch implementation?* A mechanism shaped by deletable
   substrate (a code built-in, an integer pipeline, a frozen baseline) is a
   finding even when every claim about `HEAD` is true.
4. **Report the verdict, in context**: `approve` / `approve-with-changes` /
   `needs-rework`; findings ranked by severity, each as location → what's wrong
   → why it matters → a concrete fix, must-fix separated from nice-to-have; a
   confidence note on anything unsure — never a guess presented as fact. **A
   blocking verdict is a durable fact about the artifact, not session
   chatter:** on `needs-rework`, also write the finding list into the artifact
   itself (a dated "Review history" section the owner prunes on resolution).
   An approve verdict changes nothing and stays in context.

Depth dial (default off): for a high-stakes artifact, dispatch a few
**read-only** subagents in parallel — each a distinct lens, one a skeptic
trying to *refute* the doc's central claim — and synthesize. Never an editing
subagent.

Terminal step: hand the verdict to whoever owns the artifact — `review`
changes nothing itself (except the `needs-rework` write-back).

## Acting on review feedback — yours, a human's, or an external reviewer's

`review` hands a verdict to the artifact's owner and stops. The receiving side
is its own discipline, the same whether the feedback came from
`/blueprint review`, a human, or an external tool:

1. **Verify before implementing — feedback is a claim, not a decision.**
   Re-check it against the actual code/doc (the grounding gate's posture): a
   reviewer's confident claim can still be wrong. Implementing an unverified
   claim just relocates the error. This applies with full force to **folding a
   finding into the artifact**: a fold is itself unverified content that
   bypasses the grounding gate the artifact's own claims passed through —
   re-ground a fold like any inherited claim, or mark it
   `(unverified — check at build)` (observed: a fold's confident nice-to-have
   claim was transcribed as fact and falsified at build).
2. **No performative agreement.** Don't thank or agree before actually
   checking; state findings and actions plainly.
3. **One unclear item holds up the whole batch** — clarify all ambiguous items
   before implementing any.
4. **Grep before generalizing** — a "make this configurable" suggestion gets a
   usage check first; unneeded generality is YAGNI regardless of how reasonable
   it sounds.
5. **Push back with reasoning when the feedback is wrong** — disagreement is a
   legitimate outcome; state the evidence.

## State between verbs = the artifacts

There is no separate blueprint state file. Each verb consumes the previous
verb's artifact by path: `brainstorm`'s draft → `spec` argues it — and each
doc's front-matter `status` tracks its lifecycle. `grill` and `review` are the
exceptions: primitives that consume a design artifact and write no new one.

## Composition (the orchestrator owns building, landing, capture)

- **Standalone** — the user runs the spine; the host's build lane consumes the
  accepted spec. The close-the-books sweep is the project's own convention.
- **Workshop routing** — the handbook's routing walk dispatches design-at-stake
  work here. The orchestrator / host lane consumes the spec.

Do not name a successor skill. Feature composition ends at the accepted
spec; genesis ends at the repo. The accepted spec is the feature baton.

## Structure, portability

- A self-contained skill directory: `SKILL.md` + `templates/` (`spec.md`,
  `adr.md`, `founding.md` — the bundled body shapes) + `verbs/new.md` +
  `verbs/deploy.md` + `scripts/ground-check.sh` (the re-grounding
  fact-checker) + `docs/ideal-use.md` (a worked arc).
- **Portable:** no workshop dependency (the one probe degrades to standalone),
  no host paths baked in, travels as one unit wherever the skills are
  installed.

## Edges

<!-- edges:blueprint -->
- produces: spec, founding-documents — argued specification; a fresh repo's three founding docs
- handoff: spec, git-repository — the accepted spec is the feature baton; a fresh repo carrying three founding documents and no code is the genesis baton
- consumes: — (conversation or a draft the user names)
<!-- /edges:blueprint -->
