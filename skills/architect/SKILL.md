---
name: architect
description: "Use when the user runs `/architect`, or asks to brainstorm, grill, or write a spec for a feature or design; or when starting a new project / new repository from scratch (`new`, `deploy`, founding spec, no repo yet). Turns an idea into an argued specification. grill is the interview primitive until every decision branch resolves. Does not write roadmaps or implementation plans and does not build. For a one-line patch, skip it (fix on the trunk)."
---

# architect — the specification spine

`/architect <verb> [args]` runs the specification spine: divergent ideation
(`brainstorm`), the interview that resolves every open decision (`grill`), the
argued specification (`spec`). Genesis is two verbs around that
spine: `new` mints a founding-shaped working file; `grill`/`spec` fill it in
place; `deploy` materializes a git repository (new directory, or in place
in a non-git folder). **Building is not
architect's job**, and neither is sequencing implementation. Trunk landing
and the debrief sweep stay with the orchestrator. `deploy` does not land
onto a host trunk.

This skill is **self-contained and uniquely named**: it depends on no other skill
and collides with none.

**Brief the human.** The conversation leads with the decision or the draft,
not the machinery. "Here are two approaches; I recommend A because…" /
"The spec is at `<path>`. Please read it before we sequence work."
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
`<agent-workspace>/templates/<doctype>.md`. Mint stays `status: draft`.
The caller writes `published` after a passing host's review they accept.
Closure through `records.sh done` when the tool exists; else
file-mode stamp. Founding-shaped `grill` / `spec` stay on the named file
(no records mint). `new` / `deploy` unchanged.

**Probe exemption.** The records-mint / output-home path above applies to
`brainstorm`, feature `spec`, and ADRs. It does **not** apply to `new` or
`deploy`, and it does **not** apply to `grill`/`spec` when the named file is
founding-shaped (*Founding-shaped* below). Those stay on the cwd working file.

**Status vocabulary** (the records contract): a working draft is `status: draft`.
Mint stays `draft`. The caller writes `published` after a passing host's
review they accept (one `published` spec per subject, as writer prose).
Closed is `archived`. Closure goes through
`records.sh done` on a workshop host. Optional `stage` (non-empty if present).
Founding-shaped working files stay `status: draft`. They are not the living
feature spec. Do not write `published` on them.

## The verbs

| Invocation | Does | Consumes → Produces | Station |
|---|---|---|---|
| (none) | `brainstorm` | conversation + prompt → `specs/` doc (`status: draft`) | design |
| `brainstorm [topic]` | divergent ideation → a draft design doc | conversation + prompt → `specs/` doc (`status: draft`) | design |
| `new <name>` | mint `./<name>.md` — founding-shaped, empty of design content | — → that file only | — |
| `grill [doc]` | interview until every decision branch resolves; founding-shaped → fill the six map H2s **in place** | a draft / spec (or the conversation) → resolved decisions | design |
| `spec [doc]` | synthesize → grill the gaps → the argued spec; founding-shaped → fill the map **in place** (no records mint, no reshape) | conversation or draft → feature `specs/` spec, **or** the named founding file | design |
| `deploy <file>` | project a founding spec into a git repo + three founding docs (new dir or in-place) | founding file → git repository | — |

```
spec  →  (host's review)  →  (caller publishes)  →  (host sequences)
```

Each arrow is a stop. No verb invokes the next.

`brainstorm → spec` is the linear spine; `grill` is a primitive
callable at any point. Bare `/architect` stays `brainstorm`. Genesis is
explicit `new`. Weight scales with the work: a **small feature** may stop
at the accepted spec (the spec doubles as its plan — slices live **in**
`templates/spec.md`, not a separate job artifact). For a **patch**, architect
is not used at all.

`new` lives in `verbs/new.md`, `deploy` in `verbs/deploy.md` — read the
verb file and follow it. `grill` / `spec` / `brainstorm` stay inline
and gain a founding-shaped branch below.

## Founding-shaped

A file is **founding-shaped** iff it has `founding` in `tags:` **and** its
structural H2 set is exactly the six map strings in `templates/founding.md`,
each appearing once. That template owns the H2 strings; if they drift, the
template wins. A duplicate mapped H2 or an extra unmapped H2 fails the shape.

**Parser** (one grammar; founding `grill` / `spec`
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
   prose). Either leftover class refuses `deploy` and is a critique finding.

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
  feature-spec `grill` / `spec` (may reshape / records-mint).
- **Otherwise** (tag without the exact map; any map H2 without being
  founding-shaped, including a duplicate mapped H2) → refuse: restore the
  shape with `/architect new` or fix the H2 set. Do not reshape. Do not
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
5. **User-review gate** — the human reads the written spec before anything is
   sequenced against it. For an ADR-tier spec, the host's review first is
   recommended by default — design-stage review has caught must-fix defects
   before any cut existed. The artifact stays `status: draft`. The caller
   writes `published` after a passing verdict they accept (the superseded
   spec, if any, closes `--as superseded` naming its successor).

Output: the argued spec. Tell the human where it is and that they should
read it before anything is sequenced against it. Then **stop**.
Implementation sequencing is a different job.

## State between verbs = the artifacts

There is no separate architect state file. Each verb consumes the previous
verb's artifact by path: `brainstorm`'s draft → `spec` argues it — and each
doc's front-matter `status` tracks its lifecycle. `grill` writes
no new file.

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
  `verbs/deploy.md` + `scripts/ground-check.sh` (the
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

<!-- edges:architect -->
- produces: spec, founding-documents — argued specification; a repo's three founding docs
- handoff: spec, git-repository — the accepted spec is the feature baton; a git repository carrying three founding documents is the genesis baton
- consumes: doctrine — station context read from the agent-workspace home; also a conversation or a draft the user names
<!-- /edges:architect -->
