---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# `agent-doctrine` — a front-door home for project doctrine — Grilled draft

`stream/feat` **feature 2**. Grounded against `1707ede` (post-`grok` records-layer-init
landing). Brainstormed and grilled 2026-08-18; every decision branch below is resolved and
attributed. Ready for `/blueprint spec`.

Companion feature: `2026-08-18-handbook-skill-extraction.md` (feature 3), which this one
unblocks.

## Problem

Skills that read or write **project doctrine** have no shared home resolution. Records got
one in `1707ede` — the **agent-records home** (declared `agent-records:`, else legacy
`records-root:`, else `.records/`), with the rule that a record-writing skill resolves that
home, carries its own template, and never refuses for lack of a `journal` floor. Doctrine
never got the equivalent.

The gap splits into two populations, and the second is where the cost actually falls.

**One doctrine writer, improvising a home.** `auditor`'s rubric — `GUIDE.md` +
per-dimension `rules/` + `metrics.sh` — is doctrine by any reading, and its standalone
default is a hardcoded `docs/audit/`, confirmed once at setup (`auditor/SKILL.md:31`). Its
own walk says "doctrine has one home" for the workshop path (`:93`) and then falls back to
an ad-hoc directory when bare.

**Three doctrine readers for whom doctrine is workshop-gated capability.**

- `debugger` consults `.handbook/test/workflows/diagnostics.md` on a workshop host. Bare, it
  emits `unstamped`, points at the clankshop onramps, and investigates through Phase 3 only
  (`debugger/SKILL.md:29-31`). **A bare project cannot have a diagnostics playbook at all.**
- `workstream`'s build lane reads `.handbook/build/workflows/feature.md`, else falls back to
  "the plan template's own structure" (`flow.md:56`).
- `blueprint` / `contractor` summon station context, else "the project's own design docs
  stand in" — a home that is not addressable.

**And all six probe a boolean where they need a path.** Those skills plus `clankshop` grep
`.handbook/README.md` for `Seeded from clankshop` to decide whether doctrine exists.
`1707ede`'s DOCTRINE rule 8 already stripped that probe of its records job, so it now gates
*only* station and playbook context — asking "is a workshop deployed?" when the real
question is "where does doctrine live, and is the piece I need in it?"

Rule 8 also forbids the tempting shortcut — *"Do not create `.handbook/` as a records side
effect"* — while offering no alternative destination.

## Goal

One resolution rule for project doctrine, owned by the **framework** (`skill-builder`'s
portable doctrine), available to every skill whether or not any workshop, `handbook`, or
`clankshop` is installed. Doctrine stops being a workshop privilege.

## Mechanism

### The variable

A front-door variable **`agent-doctrine:`**, resolved as: the project's declared
`agent-doctrine:` line (`AGENTS.md`, then `CLAUDE.md` where that is the front door), else
the derived default **`<agent-records>/doctrine`**.

This is a second instance of an existing, documented mechanism, not a new one:
`DOCTRINE.md:203` *Front-door variables — one declaration, two readers* already names the
agent-records home as "**the canonical example**", and fixes the form (one line, line start,
kebab-case).

**Why derive from the records home** rather than a flat `.doctrine/`:

- A brownfield host declaring `agent-records: dev` gets `dev/doctrine` with **no second
  declaration**. A flat default would force every such host to declare twice.
- It structurally guarantees what rule 8 currently only asks for in prose: a bare
  doctrine-writing skill can never create `.handbook/` as a side effect, because its default
  home is elsewhere by construction.

### Two-level resolution

Resolving the home is not finding the artifact. `contractor` summons "the build station"; if
`<agent-doctrine>` resolves to `.records/doctrine` with no station chapters in it, there is
nothing to summon. The rule: **resolve the home, then test for the specific artifact you
need** — already how `debugger` behaves (*"consult `diagnostics.md` when that file
exists"*). A missing artifact degrades exactly as a missing workshop does today; it never
breaks the consumer.

### Bare creation is permitted

A doctrine writer **creates its own directory under the resolved home with no floor**,
symmetric with grok's settled rule for record writers. On a repo with neither layer, a first
`/auditor setup` materializes `.records/doctrine/audit/`.

The cost is deliberate and should be stated in the docs: that is a dot-directory the user
did not explicitly opt into, where today they would get a visible `docs/audit/`. It was
weighed against adding a confirmation round-trip the records side does not have, and against
a refuse-and-stop that `1707ede` was built to eliminate.

### The classification test (prose — a lint cannot judge it)

> **Doctrine is living, normative, undated, and never closes. Records are dated, typed, and
> closeable.**

By that test: an audit rubric is doctrine; a diagnostics playbook is doctrine; a station
chapter is doctrine. A spec is **not** (a dated `design/` record); a notepad fact is
**not**; an audit *report* is **not** (it lands in the agent-records home).

### Declaration and lint

A skill declares its relationship to doctrine through the existing **typed-edge** mechanism
— `produces: doctrine` / `consumes: doctrine` in its Edges block — rather than a new
frontmatter field or a prose convention. One coarse `doctrine` type, matching every existing
type (`spec`, `report`, `plan`, `note` are all coarse); *which* doctrine artifact is meant
goes in the edge's prose description.

**Known cost, accepted:** an edge-matching composer would derive a loose `auditor →
debugger` seam that is not real. Acceptable while composer matching is still aspirational,
and revisable by splitting the type later.

The lint (mirroring `1707ede`'s `lint-records-writer-test.sh`) then checks that skills
declaring a `doctrine` edge:

- resolve the home rather than hardcoding one,
- never create `.handbook/` bare (rule 8's prohibition, finally lintable rather than merely
  asked for),
- degrade on a missing artifact rather than breaking.

**Prove by breaking:** the fixture must FAIL on a deliberately hardcoded home before the
rule is trusted.

### Consumers flipped in this feature

All five stamp-probing readers move from "does the stamp exist" to "resolve
`<agent-doctrine>`, then test for the artifact": `auditor`, `blueprint`, `contractor`,
`workstream` (`SKILL.md:93` + `verbs/create.md:119`). Their "point at the clankshop onramps"
branches restructure, since a missing workshop no longer implies missing doctrine.

`auditor`'s home becomes `<agent-doctrine>/audit/` for new setups, with **legacy
`docs/audit/` detection retained** exactly as `records-root:` remains accepted alongside
`agent-records:`. Nothing in the field moves or breaks. *(Consequence to verify at build:
auditor's home becomes resolved rather than "confirmed once at setup" — check that its setup
walk still reads coherently.)*

**`debugger` keeps the stamp probe — for one job only.** Phase 4 is already human-gated
(`:62`, `:103`: "Phase 4 starts only after the human confirms the root cause and that a fix
is wanted"); the workshop gate is a second, independent gate expressing a *policy* — do not
apply fixes on a project that has not opted into a workshop. That gate keeps the stamp. The
diagnostics playbook read flips to home resolution. Two probes, two distinct questions —
which is the design's own thesis demonstrated: *is a workshop assembled* is a policy
question, *where is doctrine* is a location question, and they were only ever conflated by
accident.

### Required fold

`DOCTRINE.md:304` (rule 8) currently reads that the stamp "still picks handbook, station
context, and playbooks." After this feature it picks none of those — only workshop policy
(debugger's Phase 4) and clankshop-internal provenance. The rule's wording must change with
the mechanism ("fix the doctrine, not just the tool", `DOCTRINE.md:61`).

## Why not the alternatives

- **A flat `.doctrine/` default** — one fewer indirection, but every brownfield host declares
  twice, and the "never create `.handbook/` bare" guarantee reverts to prose.
- **Leave doctrine to the workshop probe** (status quo) — keeps a boolean where a path is
  needed, leaves `auditor`'s home improvised, leaves three readers workshop-gated, and forces
  feature 3 to convert six consumers that would need converting again later.
- **Give `handbook` the variable** — makes an optional skill load-bearing for a framework
  rule, and every consumer would need to know handbook exists.
- **Home + writers only, or home + doctrine only** (narrower scope) — considered and
  rejected: the readers are where the value is, and a variable shipped with zero live
  consumers is its own risk.

## Risks

- **Doctrine nested under the records home reads against the distinction it encodes.**
  `.handbook` is doctrine, `.records` is work output — and the default path puts doctrine
  inside the records home. Mitigation is cheap but must be explicit: `journal` already
  reserves never-scanned entries (`journal/SKILL.md:28`), so `doctrine` joins that list; and
  the docs must state that the records **home** is a directory that may host sibling layers,
  while the records **layer** is the eight typed stores. Without that sentence the default
  path argues against the rule.
- **`agent-doctrine` and `agent-records` are coupled by the derived default** — moving the
  records home silently moves doctrine on any host that never declared `agent-doctrine:`.
  Acceptable, but it must be stated where hosts can read it.
- **Six consumer skills change** — the second consecutive feature to rewrite the same six
  files. `grok` has landed, so the contention is gone.
- **This feature edits `skills/workstream/SKILL.md`, the skill currently driving the
  stream.** No hazard in the worktree (the harness loads from the root checkout), but the
  running skill changes when this ships.

## Decision log (settled 2026-08-18, human)

| Decision | Resolution |
|---|---|
| Variable + default | `agent-doctrine:`, default `<agent-records>/doctrine` (derived) |
| Owner | `skill-builder` (framework), not `handbook` or `clankshop` |
| `handbook`'s relationship | *declares* the home; does not override a rule. Tier **optional** |
| Resolution | Two-level: home, then the specific artifact; degrade, never break |
| Scope | Home + writers + **readers** |
| Declaration | Typed edges, one coarse `doctrine` type |
| `auditor` migration | Legacy `docs/audit/` fallback retained; no field migration |
| `debugger` Phase 4 | Keeps the stamp probe for that gate alone |
| Bare creation | Permitted, no floor, symmetric with record writers |
| `journal` | `doctrine` joins the reserved list; `records.sh check` ignores it, asserts nothing |
| `agent-templates` | Unchanged — doctrine templates resolve under the existing templates home |
| Declaration site | `AGENTS.md`, then `CLAUDE.md` |

## Deferred to feature 3 (do not answer here)

If `handbook` is optional and owns `seed/` + `seed.sh`, can `/clankshop setup` stand up a
workshop without it — hard-stop like `journal`, or a doctrine-less workshop falling back to
`<agent-records>/doctrine`? That question decides what "optional" actually costs.

## For `spec` to add

Verification detail (the lint fixture's red-proof), slice sequencing, and the exact
`DOCTRINE.md` section text.

## Grounding

Built against `1707ede`. Verified at draft time: `DOCTRINE.md:203` defines the front-door
variable pattern with agent-records as the canonical example; `DOCTRINE.md:304` (rule 8)
decouples the stamp from records destination and forbids bare `.handbook/` creation;
`auditor/SKILL.md:31,93` confirms the improvised `docs/audit/` home; `debugger/SKILL.md:29-31`
confirms the bare playbook gap and `:62,:103` the human gate on Phase 4; `flow.md:56`
confirms workstream's build-lane fallback; `journal/SKILL.md:28` confirms the reserved-name
list; `lint-records-writer-test.sh` is the lint precedent; ten live `Seeded from clankshop`
sites across six consumer skills.
