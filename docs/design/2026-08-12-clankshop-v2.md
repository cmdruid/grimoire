# Clankshop v2 — design

> Status: settled design, 2026-08-12. This is a full v2 redesign of the `clankshop` skill —
> the v1 implementation (never deployed) is prior art, not a constraint. Remaining work is
> execution: see *Open items*.

## Purpose

`clankshop` sets up an **agentic workshop** around a code project: a deployed structure of
doctrine, records, and routing that lets agents (and humans) work the project through a
well-defined lifecycle, with the right context loaded at the right time.

## The model

The workshop is a line of four **stations**. Work moves through them in lifecycle order, and
each station is a standing area of work with its own doctrine and its own persona:

| station | persona | covers |
|---|---|---|
| `design` | the architect | design and specification. Produces a strong specification of what we are building, so gaps between the spec and the code implementation can be measured. |
| `build` | the foreman | planning and development of the codebase. Workflows, worktrees, and development resources. |
| `test` | the guardian | testing and gating of code prior to release. Fixtures, resources, CI/CD pipelines. |
| `review` | the admin | upkeep of the repository after each cycle. Agent debriefing and journaling, record and tracker book-keeping, handbook and `AGENTS.md` maintenance, and folding collected feedback into workshop improvements. |

A station merges place and actor: an agent *works a station* by loading its context. The
persona names are **color, not machinery** — each station's chapter opens in its persona's
voice, and the names serve as handles for discussion ("ask the architect"), but nothing
routes on them.

Three deployed surfaces carry the workshop:

- **`.handbook/`** — doctrine: policy and procedure. Pure "how we work"; never "what we are
  building".
- **`.records/`** — accumulated work products, including the living design spec.
- **`AGENTS.md`** — the door: the routing table plus a pointer to the handbook.

## Working a station

There are **no role skills**. A station's persona and doctrine are project-resident — they
live in the handbook, where the review station tends them — so the workshop works in any
harness that can read files and run scripts; no skill runner required.

**Load rule** (stated once in `.handbook/README.md`):

> To work station X, read `core/*` plus `<station>/POLICY.md`. Workflows load lazily, when
> routing selects one.

This keeps the standing context lean: policy is always-on, procedures are pay-per-use.

Four ways context gets loaded:

1. **`.handbook/scripts/context.sh <station>`** — renders the station's load set on demand
   (cat with source-path headers) for one-page reading or injection into a sub-agent prompt.
2. **Manual reads** — any agent follows the load rule by hand; the README states it.
3. **Helpers summon it** — skills that do a station's work open by loading that station's
   context when a workshop is present (e.g. `blueprint` begins: "you are working the
   design station — load its context first").
4. **Summoned for discussion** — `/clankshop <persona> [prompt]` loads the station's
   context and adopts the persona's voice: discuss matters through that lens. Judgment
   only, no procedure.

**Persona preamble:** each station's `POLICY.md` opens with a short preamble — identity and
standing judgments, written in the persona's voice. This is doctrine like everything else in
the chapter: seeded by `setup`, owned by the project thereafter.

## Handbook

The handbook is readable by humans and agents alike, and DRY: shared doctrine lives once in
`core/` and is linked, never restated.

**Tree-as-manifest:** a station's load set is deterministic from the directory structure —
no manifest file, no build step, no stored compiled artifact.

```
.handbook/
  README.md         # orientation: flow narrative, layout + load + precedence rules, install stamp
  core/             # every station loads this — the shared floor
    POLICY.md       #   workshop-wide policy
    INVARIANTS.md   #   hard rules, never overridden
    GOTCHAS.md      #   project traps: working-as-coded but surprising behavior
    ROUTING.md      #   how work is classified and dispatched to workflows
  design/           # the design station (the architect's chapter)
    POLICY.md       #   persona preamble + station policy + chores
    workflows/      #   loaded on demand, per routing
  build/            # the build station (the foreman)        (same shape)
  test/             # the test station (the guardian)        (same shape)
  review/           # the review station (the admin)         (same shape)
  scripts/          # deployed tooling: context.sh (records tooling lives with the records)
```

**Precedence rule:** `core/` is the floor. A station's `POLICY.md` may *refine* core but
never restate or contradict it. A restatement is a bug the review station fixes.

**Orientation is pay-per-first-use.** The README carries the **flow narrative** — how a
change moves through the line: work enters, routing classifies it, design shapes it, build
lands it, test gates it, review sweeps up. Orientation lives *outside* the station load
set (the README is the entry point, not standing context), so no load pays for the story
twice; if the narrative ever outgrows a page, it splits to `.handbook/RUNBOOK.md` beside
the README — still outside the load set. `ROUTING.md` stays pure classification rules.

**Chores** (required tasks — record-keeping, cleanup) live in each station's `POLICY.md`.
The link-tree spine audit (v1's `chiropractor` helper) becomes a workflow in
`review/workflows/`.

**Compilation is a view, never an artifact.** A stored per-station compile would be a second
copy of truth that drifts, gets edited directly, or gets read stale — and it buys agents
nothing, since reading three files costs the same as reading one concatenation. `context.sh`
renders on demand; nothing persists, so nothing goes stale. The same script doubles as the
load-set contract test.

## Seed

The `clankshop` skill carries the **template handbook** (the seed) and four verbs:

- `setup` — greenfield bootstrap: project the seed into `.handbook/` (doctrine +
  `context.sh`), delegate records standup to `journal` (a required pack member), write the
  door.
- `migrate` — brownfield onramp: inventory what exists, map it into the workshop layout.
- `check` — assembly validation: layout shape, required files, resolvable links, record
  front-matter conformance (delegates to the deployed `context.sh --check` and
  `records.sh check`).
- `<persona> [prompt]` — summon a persona for discussion: load its station's context (via
  `context.sh`), adopt the voice, discuss through that lens.

**Provenance is one install stamp**: a single line in `.handbook/README.md` —
`seeded from clankshop vX.Y on DATE`. No per-file origin stamps, no doctrine-version
lockstep. Once seeded, the handbook is the project's document; upgrades are a
judgment-assisted diff against the current seed, anchored by that one line.

## Migration — the brownfield onramp

There are no v1 deployments; `migrate` targets only projects with **organic** structure —
ad-hoc doc trees, hand-rolled trackers and notes, possibly a legacy records root (e.g.
`dev/`). The procedure, in order:

1. **Preflight (script).** Inventory candidate artifacts: doc trees, planning documents,
   trackers, test/CI docs. Propose a classification for each.
2. **One confirmed mapping table.** Every inventoried artifact gets a destination — a
   station chapter, a record store, or *leave in place*. Nothing moves before the human
   confirms the table.
3. **Script executes the mechanical rows.** `git mv` into stores (history survives),
   front-matter backfill on every adopted record — `doctype` from the destination store,
   dates from `git log`, `status` flagged for judgment where ambiguous — plus seeding of
   `core/`, the station chapters, and the deployed tooling (`context.sh` from the seed,
   the records machinery via `journal`). Adopted records keep their original filenames;
   the path is the ID either way.
4. **Agent performs the judgment merges.** Organic policy and convention docs fold into
   `core/` or station `POLICY.md`s (below the seeded preambles); the door is written into
   the existing `AGENTS.md` — integrated, never clobbered.
5. **Done means `check` is green.** The migration is complete only when v2 `check` passes;
   the install stamp is written last.

One conformance regime, no grandfathering: after migration, `records.sh` sees everything.

## Records

Markdown documents accumulated during normal development, stored under `.records/`
(overridable via `AGENTS.md` — how a legacy records root like `dev/` stays where it is).

**The records layer is `journal`'s domain.** `records.sh`, the record templates, and the
`.records/` scaffolding are journal's deployed assets: standalone, journal stands up
records on a bare repo by itself; under the workshop, `setup` delegates records standup to
it. Templates live in `.records/templates/`, tooling in `.records/scripts/` — both
reserved directories that `records.sh` skips when scanning stores.

| store | holds |
|---|---|
| `adr` | architecture decision records. Coordinate decisions between stations; later decisions may override earlier ones. The design station consolidates and drains these into the design spec as maintenance. |
| `bugs` | detailed bug and issue reports. Trackers may link to these as references. |
| `design` | the design station's documents — ideation, iteration, and the **living design spec**. The current spec is the doc with `status: current`; superseded drafts and working papers keep their history alongside it. |
| `notes` | general information an agent wants to persist — shared memory. Trackers may link to these. |
| `plans` | the build station's planning documents — feature plans, implementation plans, roadmaps. |
| `reports` | informational reports from investigative work. |
| `tickets` | larger tasks involving human interaction. |
| `trackers` | micro-task tracking — issues, feedback, backlog items. May link to other records. |

**Front-matter contract** (mandatory on every record):

```yaml
doctype:  # one of the store kinds
status:   # e.g. open | current | superseded | done
created:  # YYYY-MM-DD
updated:  # YYYY-MM-DD
tags:     # free-form list
```

The contract is enforced by journal's templates (`.records/templates/`) and validated by
`check`.

**Querying is a live scan, no stored index.** `records.sh` (journal's deployed asset —
see *Scripts*) scans front-matter on demand. At repo scale a front-matter grep is
milliseconds; an index file would be one more snapshot that drifts.

**Filenames are `YYYY-MM-DD-<slug>.md`**, generated by `records.sh new` — sortable,
self-describing, no counter state to maintain; the path is the ID.

## Scripts

Agent-facing tooling, deployed into the project with ownership-aligned homes:
`context.sh` lands in `.handbook/scripts/` (deployed by `setup`), `records.sh` in
`.records/scripts/` (deployed by `journal`). Project-resident either way, so the workshop
is fully self-contained: any harness that can read files and run scripts gets everything,
with no installed skills required. Skills invoke them by path.

Design constraints: these are for agents, not humans. Plain deterministic output — no
color, no pagination; grep/awk-friendly formats; terse errors on stderr; meaningful exit
codes. The scripts own the **facts** — dates, paths, conformance — so agents never guess
them.

### `context.sh` — the load-set renderer

```
context.sh <station|persona>    # render the load set: each file prefixed by a `===> <path>` header
context.sh <station> --list     # the reading list only (paths, in load order)
context.sh --check              # contract test: every station's load set resolves
```

Persona names are accepted as station aliases (`architect` → `design`) — this is what
`/clankshop <persona>` calls. Exit codes: `0` ok, `1` usage, `2` broken load set.

### `records.sh` — record query + lifecycle

```
records.sh list [--type t] [--status s] [--tag g] [--since d] [--until d]
records.sh show <path>
records.sh new <doctype> --title "..."
records.sh touch <path> [--status s]
records.sh check
```

- `list` emits TSV — `path · doctype · status · updated · tags · title`, one record per
  line, sorted by `updated` descending. No parser needed; pipe to grep/awk.
- `new` creates a record from its store's template, stamps front-matter with the real date,
  and prints the path. The contract is enforced at the only moment it can be: write time.
- `touch` updates the `updated:` stamp (and optionally `status:`) — agents never hand-edit
  dates.
- `check` is the conformance scan `clankshop check` calls.

## The door

`AGENTS.md` carries a routing table (what kind of work goes to which station, workflow, or
skill) and points at `.handbook/README.md`. Routing detail lives in
`.handbook/core/ROUTING.md`; the door stays thin.

## The placement principle

One rule and one ladder answer "where does a new thing go?" for every future addition.

**The knowledge rule:** anything two projects could legitimately want to differ on is
*doctrine* — it lives in the handbook, project-resident, tended by the review station. Skills
carry only portable procedure. (This is why roles dissolved into the handbook: personas are
doctrine.)

**The coupling ladder** — each pack tier is defined by how much workshop a skill needs:

| tier | relationship to the workshop |
|---|---|
| system | *creates* it — requires nothing, stands up everything |
| helper | *runs anywhere, enriched when present* — full standalone life; summons station context and writes records opportunistically |
| utility | *agnostic* — pure plumbing; never touches the layout |

**The placement test**, asked in order for any new capability:

1. Could two projects legitimately want it to differ? → handbook (doctrine).
2. Does it use the workshop when present but run without it? → helper.
3. Neither? → utility.

What the *workshop* needs is a different question from what a *skill* needs: hard
dependencies of the workshop itself (e.g. `journal`, which owns the records layer) are
expressed in `PACK.md`'s required-member list. Dependency is manifest data, not a tier.

## The pack

`clankshop` remains a **pack**: the face skill carries a `PACK.md` manifest naming required
and optional members, and the installer (`grimoire`) resolves it — installing the face
ensures the supporting skills are present.

| tier | skill | is |
|---|---|---|
| system | `clankshop` | the seed (handbook + `context.sh`) + `setup` / `migrate` / `check` / `<persona>` summons |
| helper | `blueprint` (was `feature`) | feature planning on any repo — ideation to implementation plan; in a workshop, writes to `.records` and summons design or build context per verb |
| helper | `journal` (was `backlog`) | **owns the records layer** — capture, curation, escalation, `records.sh`, templates, `.records` scaffolding; stands up records standalone on a bare repo; a *required* pack member (setup delegates to it) |
| helper | `workstream` | long-lived development streams — worktrees, queues, shipping; writes done-records and takes build-station context when a workshop is present |
| helper | `auditor` | code-quality audits on any repo; drains findings into `.records` when a workshop is present |
| helper | `debugger` | root-cause debugging anywhere; guided by the test station's diagnostics when present |
| utility | `checkpoint` (was `handoff`) | save/resume session context |
| utility | `mailbox` | worktree-safe transport for delegated results |
| utility | `delegate` | sub-agent dispatch routing (decides whether/where; mailbox is the transport) |
| utility | `scheduler` | cron wrapper + chores runner. *Placeholder: an existing implementation exists and needs to be located.* |

### Blueprint verbs

Inspired by [Matt Pocock's skills](https://github.com/mattpocock/skills): grilling as a
reusable primitive, conversation-first
specs (`to-spec`), tracer-bullet tickets with declared blocking edges (`to-tickets`), a
decision-map roadmap (`wayfinder`), and two-axis review.

- `brainstorm [topic]` — divergent ideation → design doc (`status: draft`). Harvests the
  current conversation before asking anything; never starts from a blank template.
- `grill [doc]` — the interview primitive, standalone: relentless questioning until every
  decision branch resolves. Works on a draft design, a spec, or a plan.
- `spec [doc]` — synthesize (from the conversation or a draft) → grill the gaps →
  concrete spec(s), candidate for `status: current`.
- `roadmap` — multi-phase decision map for large work: phases with gates and declared
  blocking edges; each phase requires its own `plan` before build.
- `plan` (was `implementation`) — tracer-bullet implementation plan: thin end-to-end
  slices, blocking edges declared, a verification step per slice.
- `review [doc]` — two-axis review of any planning artifact: **soundness** (internally
  consistent, feasible) and **groundedness** (conforms to the codebase — and to core
  doctrine when a workshop is present).

Blueprint is a helper: one environment probe at entry (the install stamp). Standalone, it
bundles minimal templates and confirms an output home once (default `docs/`). In a
workshop, it writes to `.records/design/` and `.records/plans/` via `records.sh` and
summons context per verb — design station for `brainstorm`/`grill`/`spec`/`review`, build
station for `roadmap`/`plan`. Building is not blueprint's job: the approved plan hands off
to the build station's lanes.

## Persona preambles (seed drafts)

Each station's `POLICY.md` opens with its preamble: an identity paragraph plus standing
judgments, in second person — the agent reading it becomes the persona. Preambles are
standing context (always loaded with the station), so they stay tight: every line is paid
for on every load. They are seed content — generic here; project specifics accrete below
them in each deployed `POLICY.md`.

### The architect — design station

> You are the architect. You own the spec: the specification the code is measured
> against. Your altitude is *what* and *why* — never *how*. When a conversation drops into
> implementation detail, hand it to the build station and hold the line.
>
> Standing judgments:
> - A decision that is not written down was not made. Significant choices become ADRs, and
>   ADRs are drained into the spec before they pile up.
> - A spec must be falsifiable: concrete enough that a gap between design and code is
>   detectable — and measurable once found.
> - Scope is the enemy. Cut before you add; every feature earns its place in the spec.
> - Later decisions may override earlier ones, but must say so explicitly.

### The foreman — build station

> You are the foreman. You run the floor: work gets classified, planned, dispatched, and
> landed. Unfinished work is your measure — the floor exists to reach *done*.
>
> Standing judgments:
> - Ceremony must fit the job. A one-line patch does not ride the full feature lane;
>   routing exists so effort matches work.
> - Build to the spec. When the code needs to deviate, that is a design gap — route it to
>   the design station; never redesign silently from the floor.
> - The smallest plan that reaches done is the right plan.
> - Blocked work is routed or recorded, never silently stalled.
> - Leave the floor clean: branches, worktrees, and lanes are torn down when work lands.

### The guardian — test station

> You are the guardian. You keep the gate, and the gate's word must mean something: green
> is a promise, not a mood.
>
> Standing judgments:
> - A flaky test is a defect in the gate itself — it is tomorrow's false green. Never
>   shrug and rerun.
> - Diagnose before acting: defect or flake decides the route, and guessing is neither.
> - Verification depth is proportional to risk — a doc typo and a migration do not get the
>   same scrutiny.
> - Never weaken the gate to let a change pass. Loosening the gate is a design decision;
>   escalate it.
> - Evidence before claims: the test was run, and the output was read.

### The admin — review station

> You are the admin. You tend the workshop itself — the records, the handbook, the door.
> Entropy is your adversary: every cycle leaves residue, and you sweep it while it is
> still fresh.
>
> Standing judgments:
> - The record is the workshop's memory. Work that was not debriefed will be re-learned at
>   full price.
> - Doctrine describes what *is*, not what was hoped. When practice and handbook diverge,
>   one of them is wrong — fix that one.
> - A restatement is a bug: shared doctrine lives once, in core, and is linked.
> - Capture signals now, judge them later: friction goes into the trackers the moment it
>   is felt.
> - A stale open record is a lie. Curate: close, supersede, or archive — do not let the
>   stores rot.

## Open items

- [ ] Locate the existing `scheduler` implementation.
- [ ] After clankshop is finalized: the upgrade wave, in dependency-weight order (see the
      check below) — `journal`, `auditor`, `workstream`, `blueprint`, then the light
      touches (`debugger`, `checkpoint`, the `bug`/`task` proxies) and the repo-root
      `README.md`/`AGENTS.md` refresh.
- [ ] Recalibrate `skill-builder`'s lint gate: it encodes the v1 door-block protocol and
      the `PACK.md` `core:` exemption; both change under v2.

### Dependency check (run 2026-08-12)

Repo-wide sweep for the machinery v2 deletes (provenance stamps, spine blocks,
doctrine-version, door registration, stewardship maps, old `.handbook` chapter paths, old
`.records` stores). Reference counts per member:

| member | refs | verdict |
|---|---|---|
| `backlog` → `journal` | 168 | **a rewrite, not a rename** — its verbs and scripts are built around `rules/RECORDS.md` projection, the done log, typed stores, and registration blocks |
| `auditor` | 36 | helper-tier rework: registration blocks, `.records/audit`, seat bootstrap |
| `workstream` | 29 | expected — already queued for upgrade; `.handbook` paths, done-records, route registration |
| `feature` → `blueprint` | 27 | expected — already queued for upgrade |
| repo `README.md` / `AGENTS.md` | 14 / 10 | describe the v1 pack; refresh after the rebuild |
| `skill-builder` | 10 | its lint gate + doctrine encode v1 door-block protocol and pack `core:` exemption — gate recalibration item above |
| `debugger` / `handoff` / `pack-format.md` | 2 / 1 / 1 | trivial touch-ups; the pack format itself survives |
| `delegate`, `mailbox`, `bootstrap`, `bug`, `task`, `install.sh` | 0 | fully independent — the utility tier's independence discipline validated by measurement |

Not dependencies: `docs/design/*` and `.scratch/*` reference the old machinery as
historical record — they stay untouched. The `bug`/`task` proxies carry zero machinery
references but name `/backlog`, so they follow the `journal` rename.
