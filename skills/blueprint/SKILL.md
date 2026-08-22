---
name: blueprint
description: "Use when the user runs `/blueprint`, or asks to brainstorm, grill, or write a spec for a feature or design; or when starting a new project / new repository from scratch (`new`, `deploy`, founding spec, no repo yet); or to apply review findings or amend a needs-rework spec, or to ask how we should revise a spec. Turns an idea into an argued specification. grill is the interview primitive until every decision branch resolves. review critiques a spec or design doc (soundness + groundedness). Does not write roadmaps or implementation plans and does not build. For a one-line patch, skip it (fix on the trunk)."
---

# blueprint — the specification spine

`/blueprint <verb> [args]` runs the specification spine: divergent ideation
(`brainstorm`), the interview that resolves every open decision (`grill`), the
argued specification (`spec`), the cross-cutting `review` — an independent
two-axis critique of a spec or design doc — and `revise`, the fold back from
a `needs-rework` verdict. Genesis is two verbs around that
spine: `new` mints a founding-shaped working file; `grill`/`spec` fill it in
place; `deploy` materializes a git repository (new directory, or in place
in a non-git folder). **Building is not
blueprint's job**, and neither is sequencing implementation. Trunk landing
and the debrief sweep stay with the orchestrator. `deploy` does not land
onto a host trunk.

This skill is **self-contained and uniquely named**: it depends on no other skill
and collides with none.

**Brief the human.** The conversation leads with the decision or the draft,
not the machinery. "Here are two approaches; I recommend A because…" /
"The spec is at `<path>`. Please read it before we sequence work."
After `revise`: questions (when they fire) are a stop; the proposal
is a stop; after apply without named re-review, the offer is a
further stop. Do not collapse questions and proposal into one ask.
`founding-shaped`, `status: draft`, and station names stay in the files.

## One environment probe (at entry)

Station context is doctrine, so it lives at `<agent-workspace>/doctrine`: the
declared `agent-workspace:` (front-door `AGENTS.md` then `CLAUDE.md`), else
`.dev` — by default `.dev/doctrine/`. Resolving the home is
not finding the artifact — resolve it, **then** test for the design station's
loader. Nothing else is probed, and no verb ever refuses or stalls for lack of
one.

- **`<agent-workspace>/doctrine/scripts/context.sh` present** → summon the design station
  (`<agent-workspace>/doctrine/scripts/context.sh design`).
- **Absent** → the project's own design docs and READMEs stand in for
  station context.

**Destination is not stamped.** Feature `spec` / `brainstorm` / ADR artifacts
land in `<agent-records>/specs/` and `<agent-records>/adr/` on every host
(first `agent-records:` or `records-root:` in `AGENTS.md` then `CLAUDE.md`,
else `.records/`). Resolve `spec.md` / `adr.md` via the project-templates rule;
`records.sh new specs --template <resolved>` when the tool exists (the flag is
required — there is no fallback); else file-mode from that path, naming the
file `YYYY-MM-DD-<slug>.md` — an undated filename is not a record, so the tool
will not see it. `spec.md` carries both the front-matter and the body scaffold,
so there is no second template to fill from. Never write the flat
`<agent-workspace>/templates/<doctype>.md`. Status promotion:
`records.sh touch --status published` when the tool exists; else file-mode
stamp. Closure through `records.sh done` when the tool exists; else
file-mode stamp. Founding-shaped `grill` / `spec` stay on the named file
(no records mint). `new` / `deploy` unchanged.

**Probe exemption.** The records-mint / output-home path above applies to
`brainstorm`, feature `spec`, and ADRs. It does **not** apply to `new` or
`deploy`, and it does **not** apply to `grill`/`spec` when the named file is
founding-shaped (*Founding-shaped* below). Those stay on the cwd working file.

**Status vocabulary** (the records contract): a working draft is `status: draft`;
the accepted, living spec is promoted to `status: published` (one `published`
spec per subject); closed is `archived`. Closure goes through
`records.sh done` on a workshop host. Optional `stage` (non-empty if present).
Founding-shaped working files stay `status: draft`. They are not the living
feature spec. Do not promote them to `status: published`.

## The verbs

| Invocation | Does | Consumes → Produces | Station |
|---|---|---|---|
| (none) | `brainstorm` | conversation + prompt → `specs/` doc (`status: draft`) | design |
| `brainstorm [topic]` | divergent ideation → a draft design doc | conversation + prompt → `specs/` doc (`status: draft`) | design |
| `new <name>` | mint `./<name>.md` — founding-shaped, empty of design content | — → that file only | — |
| `grill [doc]` | interview until every decision branch resolves; founding-shaped → fill the six map H2s **in place** | a draft / spec (or the conversation) → resolved decisions | design |
| `spec [doc]` | synthesize → grill the gaps → the argued spec; founding-shaped → fill the map **in place** (no records mint, no reshape) | conversation or draft → feature `specs/` spec, **or** the named founding file | design |
| `review <doc>` | two-axis critique; founding-shaped → six-H2 + leftover/gap rubric | a spec or design doc → a verdict (in context) | design |
| `revise [<findings>] [<artifact>]` | classify findings, propose amendments, fold on confirm | a findings baton + spec → proposed amendments, then amended spec on confirm | design |
| `deploy <file>` | project a founding spec into a git repo + three founding docs (new dir or in-place) | founding file → git repository | — |

```
spec  →  review  →  approve              →  (host sequences)
                 →  approve-with-changes →  host, or revise if asked
                 →  needs-rework         →  revise  →  review  →  …
```

Each arrow is a stop. No verb invokes the next, except a `revise`
confirmation that asks for `review` after apply.

`brainstorm → spec` is the linear spine; `grill` and `review` are primitives
callable at any point. Bare `/blueprint` stays `brainstorm`. Genesis is
explicit `new`. Weight scales with the work: a **small feature** may stop
at the accepted spec (the spec doubles as its plan — slices live **in**
`templates/spec.md`, not a separate job artifact). For a **patch**, blueprint
is not used at all.

`new` lives in `verbs/new.md`, `deploy` in `verbs/deploy.md`, and `revise`
in `verbs/revise.md` — read the verb file and follow it. `grill` / `spec` /
`review` / `brainstorm` stay inline and gain a founding-shaped branch below.

## Founding-shaped

A file is **founding-shaped** iff it has `founding` in `tags:` **and** its
structural H2 set is exactly the six map strings in `templates/founding.md`,
each appearing once. That template owns the H2 strings; if they drift, the
template wins. A duplicate mapped H2 or an extra unmapped H2 fails the shape.

**Parser** (one grammar; founding `grill` / `spec` / `review` / `revise`
and `deploy` share it):

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
  Do not rewrite to `templates/spec.md`. Do not mint a `specs/` record.
  Do not strip `founding`. Do not add an H2 that is not in the map. Do not
  promote `status`. Who/when notes go **inside** the mapped section as a
  whole line in this exact form (roman, not italic): `Settled: YYYY-MM-DD.`
- **No `founding` tag and no structural H2 is in the map** → existing
  feature-spec `grill` / `spec` / `review` (may reshape / records-mint).
- **Otherwise** (tag without the exact map; any map H2 without being
  founding-shaped, including a duplicate mapped H2) → refuse: restore the
  shape with `/blueprint new` or fix the H2 set. Do not reshape. Do not
  deploy-path this file.

## brainstorm `[topic]` — divergent ideation into a draft design

Open the space before narrowing it. **Harvest the current conversation first** —
pull every constraint, preference, and half-decision already stated into the
draft before asking anything; never start from a blank template.

1. **Explore context** — the relevant code, docs, recent commits, and the host's
   design context (workshop: design-station summon + the `specs/` store's
   `status: published` spec; standalone: the project's own design docs) before
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
5. **Write the draft** — a `specs/` doc (`status: draft`), shaped per
   `templates/spec.md`'s sections at draft weight: problem, goal, candidate
   approach, open questions listed at the foot. Unresolved branches are
   *expected* here — `grill` or `spec` resolves them.

Output: the draft design doc. Tell the human where it is. Stop if they
need to read it; otherwise offer `grill` or `spec`. A draft is a
legitimate resting state.

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
   `status: published` spec (workshop: flip via
   `records.sh touch <spec> --status published`; the superseded spec, if any,
   closes `--as superseded` naming its successor).

Output: the argued spec. Tell the human where it is and that they should
read it before anything is sequenced against it. Then **stop**.
Implementation sequencing is a different job.

## review `<doc>` — the two-axis critique

Independent second-set-of-eyes on a **spec or design doc** — distinct from the
self-review baked into `spec` (the author checking their own work; this verb is
not the author). Findings + a verdict in context. Every verdict writes a dated
stamp into the artifact's Review history; `needs-rework` also writes the
finding list. It reviews **documents, not diffs** — a code change is the
host's code-review tooling.

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
   against `core/` (invariants, gotchas) and the `status: published` spec + live
   ADRs. **Add the substrate-skeptic pass** — grounding anchors the review to
   the present code, so deliberately ask its inverse: *which mechanisms would
   not exist in a from-scratch implementation?* A mechanism shaped by deletable
   substrate (a code built-in, an integer pipeline, a frozen baseline) is a
   finding even when every claim about `HEAD` is true.
4. **Report the verdict, in context**: `approve` / `approve-with-changes` /
   `needs-rework`; findings ranked by severity, each as location → what's wrong
   → why it matters → a concrete fix, must-fix separated from nice-to-have; a
   confidence note on anything unsure — never a guess presented as fact.
   **Every verdict is a durable fact about the artifact:** write a dated stamp
   into the artifact's `## Review history` (create the section if missing):

   ```
   ### YYYY-MM-DD — needs-rework | approve | approve-with-changes
   ```

   `needs-rework` still carries the finding list under the stamp (must-fix
   separated from nice-to-have). `approve` and `approve-with-changes` may
   be a stamp-only line. This is a write-back, not a new verdict word. The
   owner may prune a fully resolved dated block after a later `approve`.

Depth dial (default off): for a high-stakes artifact, dispatch a few
**read-only** subagents in parallel — each a distinct lens, one a skeptic
trying to *refute* the doc's central claim — and synthesize. Never an editing
subagent.

Terminal step: hand the verdict to whoever owns the artifact and **stop**.

## After the verdict

`review` hands the verdict to the artifact's owner and stops. The owner
folds a `needs-rework` (or an `approve-with-changes` they want applied)
with `revise` (`verbs/revise.md`). This verb does not amend.

## State between verbs = the artifacts

There is no separate blueprint state file. Each verb consumes the previous
verb's artifact by path: `brainstorm`'s draft → `spec` argues it — and each
doc's front-matter `status` tracks its lifecycle. `grill` and `review` write
no new file; `revise` amends the named artifact in place after
confirm, not in the invoke turn.

## Composition (the orchestrator owns building, landing, capture)

- **Standalone** — the user runs the spine; the host's build lane consumes the
  accepted spec. The close-the-books sweep is the project's own convention.
- **Workshop routing** — the doctrine's routing walk dispatches design-at-stake
  work here. The orchestrator / host lane consumes the spec.

Do not name a successor skill. Feature composition ends at the accepted
spec; genesis ends at the repo. The accepted spec is the feature baton.

## Structure, portability

- A self-contained skill directory: `SKILL.md` + `templates/` (`spec.md`,
  `adr.md`, `founding.md` — the bundled body shapes) + `verbs/new.md` +
  `verbs/deploy.md` + `verbs/revise.md` + `scripts/ground-check.sh` (the
  re-grounding fact-checker) + `docs/ideal-use.md` (a worked arc).
- **Portable:** no workshop dependency (the one probe degrades to standalone),
  no host paths baked in, travels as one unit wherever the skills are
  installed.

## Project templates

- `adr.md`
- `spec.md`

`founding.md` is package-only.

_(`design.md` was a front-matter-only stub minted first and then filled from
`spec.md`. It existed to satisfy the store-named-lock-in filename convention;
`records.sh` no longer guesses a template from a doctype name, so `spec.md` —
which already carries the same front-matter plus the body scaffold — is minted
directly and the stub is gone.)_

## Edges

<!-- edges:blueprint -->
- produces: spec, founding-documents — argued specification; a repo's three founding docs
- handoff: spec, git-repository — the accepted spec is the feature baton; a git repository carrying three founding documents is the genesis baton
- consumes: review, doctrine — a findings baton (council RESULT.md or Review history); station context read from the agent-workspace home; also a conversation or a draft the user names
<!-- /edges:blueprint -->
