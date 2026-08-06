# Agent framework for git projects — knowledge spine, tickets, and submodules

**Status:** Draft (2026-08-05), revision 5 — **the mechanics layer**. Rev 2 reworked after an
independent external review; rev 3 adopted the **three-root model** (§2.3); rev 4 reworked after
two further independent reviews (Codex + cold Opus; `.scratch/agent-framework/`); rev 5 closes
the verification pass's remaining findings (`codex-review-3.md`) and adopts **format-agnostic
migration** (stamped-only operation; no legacy formats, no dual-layout support). **Composition
and ownership are superseded by the companion pack design,
`docs/design/2026-08-06-clankshop-pack.md`** (its §7 enumerates the deltas: the clankshop pack
model: six roles — architect, foreman (slimmed to routing + rulebook), the new `guardian`
(verification, owning the `testing/` chapter), auditor, chiropractor (repurposed as docs
quality), and the `calibrator` (the improvement loop) — plus two instruments (backlog, the
records instrument; debugger, the diagnostic procedure), two pipelines, three helpers, and
clankshop owning setup/migrate/system-check) — read this doc for the deployed mechanics, that
doc for who owns and operates them. Supersedes parts of the front-door
architecture's deployed doc set (§10); designed via a wayfinder decision map (12 tickets) plus
live grilling.

**Goal:** Replace foreman's workflow-stage doc layout (`ROUTING`/`PLANNING`/`WORKTREES`/
`MAINTENANCE`) with a **knowledge-typed spine** (routing, workflows, gotchas, invariants, policy,
records-format), formalize the **record taxonomy** (`adr`/`plans`/`reports`/`tickets`/`trackers`/
`done`), introduce **tickets** as an optional human-in-the-loop escalation surface that never
slows the agent fast path, and extend the framework to **super-projects with submodules**. Foreman
and backlog refactor to deploy and manage this; chiropractor gains **generic** form checks over
self-describing docs (§2.2); architect and auditor conform. The deployed layout is the
**three-root model** (§2.3): `.handbook/` (the project's normative documents), `.records/` (the
paper trail), `.agents/` (optional agent machinery).

**References:**
- `docs/design/2026-07-26-front-door-architecture.md` — read-cost tiers, the four hard rules, the
  compiler model this design keeps (§2.1 supersedes its §7.2/§8.B WORKFLOWS dissolution's payload
  half; §8-C's rejection of dual-dispatch rows is *upheld* by §2.1's fallback chain).
- `docs/design/2026-07-27-steward-grammar.md` — the per-layer calibrate grammar, **superseded by
  the pack design's calibrator role** (pack §4.7/§7); `tracker-entry` consumers' contract is
  amended via the declaration-led pause (§5).
- `docs/design/2026-07-18-skill-self-init-model.md` + `2026-07-18-skill-boundaries-and-glue-ownership.md`
  — typed edges, self-init-no-floor, seam rules this design builds under.
- `skills/backlog/docs/TAXONOMY.md` — the capture taxonomy §5 layers escalation over (the five
  kinds stand; one classifier is retargeted, §9).
- `packs/clankshop.md`, `README.md` § Storage convention — the layout/seam surfaces §11 updates.
- Matt Pocock's `mattpocock-skills` (marketplace, v1.2.0) — ticket-art conventions surveyed;
  adopted/adapted per §5–§6.

---

## 1. The problem — four failures of the current layout

The deployed doc set is cut by **workflow stage**, so the knowledge types agents actually need are
smeared across files: load-bearing rules live inside `WORKTREES.md`, traps inside `ROUTING.md`,
doctrine inside `MAINTENANCE.md`. Concretely:

1. **Wrong organizing axis** — an agent cannot load "just the rules" or "just the traps," and a new
   rule/trap/judgment has no obvious home.
2. **Too heavy** — prose-dense docs burn context to find the few load-bearing lines.
3. **Missing types** — gotchas, invariants, and policy exist only implicitly inside other docs.
4. **Not project-adaptive** — deployed docs are near-copies of bundled templates, generic where they
   should be shaped by the host's stack, gate, and layout.

Two axes are new, not refactors: an **escalation surface** for work that needs the human (today:
nothing between a tracker line and a full feature lane), and **super-projects** (today: an unstated
single-root assumption).

## 2. The knowledge spine — cut by what a reader needs

Deployed per installation:

```
.handbook/
  README.md             # stewardship map (§2.3) — NOT a reading menu; the door routes reading
  rules/                # the rulebook (no file/dir mixing at the top level)
    ROUTING.md          #   decision walk + dispatch rows — source of the compiled tier-0 table
    GOTCHAS.md          #   ID'd trap entries
    INVARIANTS.md       #   ID'd one-line load-bearing rules — the "just the rules" read
    POLICY.md           #   ID'd standing judgments — the why behind the rules
    RECORDS.md          #   the record formats: entry shapes, IDs, done-log line, ticket schema
  workflows/<lane>.md   # the lanes, NOTHING else: one complete lane per file (patch, bug, …)
  design/               # the authored design spec (project brief, system specs)
```

The top level is three content-named chapters plus the stewardship map — `rules/` (what must hold
and where changes go), `workflows/` (how work flows), `design/` (what we're building).
`ROUTING.md` sits in `rules/`, not `workflows/`: the decision walk is the project's *routing
rules*, and a directory of lanes must contain only lanes. `RECORDS.md` exists so the handbook
**actually stands alone**: without it, a skill-less reader finds `.records/` but no deployed
definition of how to write to it — the formats lived only in skill-bundled docs. It is deployed
and maintained by backlog (the taxonomy owner), the one chapter not tended by a §2.4 role.

**Entry formats** (strict — the fix for "no obvious home"):

- `ROUTING.md` — **deliberately lean** (≈25-line budget): the classification walk plus dispatch
  rows. With lanes extracted to `workflows/`, only the *judgment* stays here — the
  patch-vs-feature line, spike handling, the bug-vs-known-gotcha check, the promotion bar at
  dispatch — citing IDs, never restating. Remains the single source the front-door routing table
  compiles from. **Row-target contract:** a compiled row dispatches to the lane's owning skill
  entry point where one is installed (feature-shaped → `/feature`, bug → `/debugger`…) — rows
  never re-document a lane. **Fallback contract (the no-runner path, stated exactly):** the door
  keeps its **one shared fallback line**, now pointing at `rules/ROUTING.md`; ROUTING's dispatch
  rows carry the lane-file paths; so the skill-less chain is `AGENTS.md → rules/ROUTING.md →
  workflows/<lane>.md` — **two reads**, within tier rule 2, with no per-row dual targets
  (front-door §8-C's rejection stands) and no menu doc (ROUTING is a decision walk, not an index).
- `workflows/<lane>.md` — one lane per file, holding **only what no skill owns** (the
  one-authority rule): a purpose line; *enter-from* (the routing row that dispatches here); the
  lane's **project policy** (this project's gate, trunk, worktree rules — as ID citations);
  **seam glue** (what wraps the skill: capture the debrief, apply the promotion bar); and the
  **by-hand walk** with a **done-when** block. The by-hand walk is the **co-equal skill-less
  path** — for a reader without the skills it is *the* path, and the doc frames it that way
  ("with `/feature` installed, it runs this walk for you"); it is never labeled subordinate.
  Procedure a skill owns lives in the skill and is *referenced at the seam*, never restated as
  authoritative steps — `check` emits a fact comparing each lane's walk against installed skill
  coverage so neither side silently rots. Steps cite rules by ID, never restate them
  ("3. Commit scoped to your paths [INV-4]").
- `GOTCHAS.md` — per entry: `## G-n: title`, `Symptom:` / `Cause:` / `Avoid:` lines, optional
  `(seen: date, ref)`. Retiring a gotcha (root cause fixed) is a calibrator-driven act, recorded
  in the run log (§3).
- `INVARIANTS.md` — one line per rule, grouped by area:
  `INV-4: Stage and commit scoped to exactly the paths you wrote — never add -A. (why → POL-2)`.
  **Absorbs `MEMORY.md`** — the separate sacred-rules file is retired; the promotion mechanism
  (foreman promotes durable notes into invariants) survives with a new target.
- `POLICY.md` — per entry: `## POL-n: title`, `Judgment:` / `Rationale:` / `Implications:`
  (pointers to the INV/G/workflow surfaces it governs). **POL vs ADR, in one line:** a POL entry
  is *standing and present-tense* (it governs today and is edited in place); an ADR
  (`.records/adr/`) is *dated and historical* (one decision, never retroactively edited). A new
  judgment goes to POLICY; the decision-moment that produced it may also earn an ADR.
- `RECORDS.md` — the deployed reference for every record format a contributor writes: the five
  tracker-entry wire formats (below), the done-log line shape, the ticket file schema (§5), and
  the ID rules. **Authority is explicit:** the skill-bundled TAXONOMY.md remains the canonical
  schema (one source per fact); `RECORDS.md` is its **stamped projection** — backlog writes it,
  the declaration block carries a `built-against:` naming the taxonomy version it projects, and
  drift between the two is a `check` fact. For the skill-less reader it is complete and
  sufficient; for the schema's evolution, TAXONOMY leads and the projection follows.

**Typed IDs — the complete namespace.** One prefix per store; policy is `POL-` rather than a
single letter so it can never collide with pre-existing project numbering that migration preserves
verbatim as aliases (§8):

| prefix | store | | prefix | store |
|---|---|---|---|---|
| `G-` | gotchas | | `T-` | tasks |
| `INV-` | invariants | | `I-` | issues |
| `POL-` | policy | | `B-` | bugs |
| — | workflows (file-per-lane, path-addressed) | | `N-` | notes |
| `TK-` | tickets (§5) | | `F-` | feedback |

**On-disk syntax, per store** (the wire formats `RECORDS.md` deploys; Phase 0 freezes these):
- `tasks.md` — the ID leads the bullet: `- T-041 — <task text> · added 2026-08-05`.
- `issues.md` — the ID leads the heading: `### I-017 — <title> (HIGH)`; migrated entries keep any
  pre-existing identifier appended verbatim as `(alias <old>)`.
- `feedback.md` — `### F-003 · <short title> · 2026-08-05`.
- `bugs/`, `notes/` — store-dir frontmatter gains an `id:` key (`id: B-009`); the doc-linter's
  store schema and rules update in the same pass (§11).
- tickets — the ID is **derived by prefixing**: file `.records/tickets/<YYYY-MM-DD>-<slug>.md`
  (consistent with `bugs/`), ID `TK-<YYYY-MM-DD>-<slug>`. The file is never renamed; the ID is
  globally unique by construction (date + slug), so **`TK-` IDs are the only ID legal in
  cross-installation citations** (§7) — bare counter IDs (`T-041`) are installation-scoped and
  never cross a boundary; there is no qualified-path citation form.

**Identity and allocation — unique before published, by construction.** An ID is **immutable once
published** — published means referenced outside its own store file (a commit message, the done
log, a ticket `origin:`, a mirror footer). Uniqueness is guaranteed *before* publication by where
allocation happens: **counter IDs are allocated only on the trunk checkout** — capture verbs
commit tracker entries trunk-side via the existing pathspec-scoped-commit discipline (a capture is
a small shared-state edit, exactly the class that discipline already routes to the trunk). Work on
a branch then cites an ID that already exists and is unique. The one exception — a capture made
branch-side because the trunk is unreachable — carries a slug placeholder, not a counter ID;
`curate` stamps the real ID at landing, *before* anything cites it. `check` still emits
duplicate-ID facts across the whole installation (archives included) as the backstop, and any
duplicate it ever finds is repaired **pre-publication by definition** (nothing may cite an
unstamped or duplicated ID); there is no post-publication renumber path to reason about.

**Budgets are curation triggers, not split triggers.** Soft caps (≈25 invariants, ≈20 live gotchas,
≈10 judgments, ≈60 lines per lane file) mean *calibrate must merge/retire/tighten* on overflow —
never "start a second file." One safety valve: a doc may declare an explicit budget exception when
its content is genuinely one large coherent job, or a lane may split into independently executable
sub-jobs *each directly routed from tier 0* — the one-job-per-payload principle governs; the
number is its proxy. The self-declared budget is deliberately not an enforcement floor: the checks
emit facts (over/under, in the declared unit), and the steward judges — a doc "passing by editing
its own number" is visible in the diff and the calibrator's run log, which is the intended control.

**Self-describing docs — the declaration grammar (normative, versioned; Phase 0 freezes it).**
Every spine doc opens with a machine-readable declaration block:

```markdown
<!-- spine-doc v1
kind: gotchas
entry: ^## (G-[0-9]+):
ids: G
refs: .handbook/** .records/**
budget: 20 entries
exclude: archive/**
-->
```

**Syntax (normative):** the block is the first HTML comment in the file; the opening line is
exactly `<!-- spine-doc v<integer>`; each following line is `key: value` where the value is the
raw text to end-of-line (no quoting, no escaping, no inline comments — a `#` is data); the block
closes with `-->` alone on a line. Duplicate keys or a second block in one file = malformed.
**Dialects:** `entry` and `paused` values are POSIX extended regexes (the dialect the library's
scripts already grep with); `refs` and `exclude` are space-separated, installation-root-anchored
git-pathspec globs. **Semantics:** a line matching `entry` *defines* the ID in capture group 1;
`ids: <prefix>` makes `\b<prefix>-[A-Za-z0-9-]+\b` the citation matcher; any citation-matcher hit
that is not a definition is a *citation*, resolved within `refs` minus `exclude`. **Keys:** `kind`,
`entry`, `ids` required for spine docs; `budget` (unit explicit: `entries` | `lines` | `bytes`),
`refs`, `exclude`, `paused` (§5 — trackers only) optional. A file without a block is simply not a
spine doc (never an error); unknown versions and malformed blocks are emitted as facts, never
guessed at. **Discovery anchor:** a self-describing *tree* is a directory whose README carries a
`<!-- spine-index v1 -->` block listing its member docs (same syntax, `docs:` key of relative
paths) — that block, not a naming convention, is what declaration-led discovery (§2.2) keys on;
nested trees are independent. Declarations ride every agent read — their byte cost is counted in
§13's sizing measures.

### 2.1 Superseding the WORKFLOWS dissolution — explicitly

The front-door architecture (§7.2, §8.B) **deleted** the deployed workflow-index doc
(`.agents/foreman/docs/WORKFLOWS.md`) under tier rule 3: that file was a *menu* — "an index of
common how-tos (pointers, not restatements)" — and menus live in the door's table. This design
does not reverse that decision; it satisfies it. `workflows/<lane>.md` files are **payloads, not a
menu**: there is *no workflow index doc at all* — the tier-0 table dispatches each row to its
**owning skill entry point** (the shipped row-target contract, unchanged), and the skill-less
reader follows the stated two-read fallback chain (§2) — the *fallback half* of the door contract
is restated for the new tree, not silently broken. One lane per file is exactly rule 4's
one-job-per-payload. BOOTSTRAP's rationale sentence — "a how-to's payload lives in the one content
doc that owns its topic" — is rewritten: lane payloads now have a dedicated home; the sentence's
*menu* half stands.

### 2.2 The audit seam — chiropractor (form) vs. `/foreman check` (fidelity)

The front-door architecture's audit split survives: **chiropractor scores form, generically, on
any repo — it never names foreman/ROUTING/grimoire concepts**; **`/foreman check` scores
fidelity** to *this* framework. Self-description (§2) is the bridge that lets chiropractor watch
the spine without learning its names. It gains three **generic** checks, each phrased against a
doc's *own declaration*:

1. **Declared-format conformance** — entries match the declared `entry` matcher (parsed, never
   inferred).
2. **ID resolution** — every citation within the declared `refs` scope resolves to exactly one
   definition; duplicate definitions are facts; declared `exclude` subtrees are skipped.
3. **Declared-budget respect** — the doc within its own stated budget *in its stated unit*;
   overflow reported as a fact for the calibrator's intake to act on (pack §4.7).

**Declaration-led discovery.** Chiropractor recognizes the handbook **as a form, never as a
name**: its scanner walks the repo's tracked markdown (minus declared and conventional
exclusions), and any directory containing declaration-carrying docs plus an index README mapping
them is a *self-describing doc tree* — it gets the three checks. Nested declared trees are audited
independently; no path or name is hardcoded; the word "handbook" never enters its rubric. Whether
a tree is *the framework's* handbook with the expected chapters remains foreman's fidelity
question — chiropractor checks what a doc claims about itself; foreman checks that the docs the
framework expects exist and that cross-store, framework-specific relationships are faithful (the
door's table projection, IDs matching tracker entries, mirror drift, submodule-index staleness,
lane-vs-skill coverage). Chiropractor's existing Entry-Door Audit is unchanged.

Two honesty notes. First: chiropractor's genericity is **already violated at HEAD** — its scanner
hardcodes `.agents/foreman/GLOSSARY.md` / `README.md` / `INDEX.md` fallback candidates
(`spine-scan.sh:427,429`). Second: **no portability gate exists at any scope today** — the
library's lint checks match backticked slash-invocations, not composition-specific path strings,
so nothing would have caught this. The rollout (§11) removes the hardcoded candidates and
**builds** (not "widens") a package-wide portability gate.

### 2.3 The three-root model — `.handbook/` · `.records/` · `.agents/`

The deployed layout splits along **what the content is**, not who maintains it — `.agents/`
survives, repurposed to hold *only* agent machinery (a stranger can ignore it entirely):

```
AGENTS.md         # the front door — wires the three roots; carries the compiled routing table
.handbook/        # NORMATIVE, project-owned: how we work — the spine (§2) + the design spec
  README.md       #   stewardship map (see below)
  rules/  workflows/  design/
.records/         # the PAPER TRAIL: what happened (§3) — typed stores + role record domains
.agents/          # agent machinery — OPTIONAL, a stranger never needs to open it
  roles/          #   seats, created LAZILY, only where a role has deployed machinery
    auditor/      #   the one seat that exists today (tailored rubric: GUIDE, rules/, metrics.sh)
```

Three commitments make this more than a rename:

- **The project owns its documents.** A cold clone with *no skills installed* reads `.handbook/`
  and understands how to work here — no role vocabulary in any path, the co-equal by-hand walks as
  the skill-less procedure, `rules/RECORDS.md` defining every record format, the declaration
  blocks making every doc self-describing. The role-based skills **create and maintain** this
  structure (wired through `AGENTS.md`), but they are accelerators, never prerequisites.
- **The machinery/documents split — audited against the live tree.** A seat holds only
  *deployed, project-specific* machinery. Today that is **auditor alone** (its project-tailored
  rubric: `GUIDE.md`, `rules/`, `metrics.sh`). Architect's templates are skill-bundled and never
  deploy (that doctrine stands); its entire deployed seed is *documents* → `.handbook/design/` —
  **no architect seat**. Foreman's deployed content is likewise all documents, and its compiled
  table lives in `AGENTS.md` — **no foreman seat**. Seats are created **lazily**, only when a
  role first has genuinely project-specific machinery to deploy; an empty seat is never
  scaffolded. (Existing operator overrides such as `.agents/feature/templates/` stay where they
  are — a mapping-table row `migrate` proposes like any other, §8.)
- **Stewardship lives in the map, content in the path.** This is the storage analog of the
  typed-edge tenet: the path tells a *reader* what a thing is; the stewardship map tells a
  *maintainer* which skill tends it. **`.handbook/README.md` is a stewardship map, not a TOC** —
  a reading menu at tier 1 is exactly what rule 3 forbids, and reading order is the door's job.
  It has two regions with different authority: a short authoritative preamble (what this handbook
  is, one line per chapter — stewardship framing, not "read this next"), and a **maintenance
  region of per-producer delimited blocks**, written under the exact protocol door registration
  already uses: each skill owns a `<!-- steward:<name> -->…<!-- /steward:<name> -->` block holding
  its chapter rows, created on self-init (with the README skeleton itself, if absent —
  self-init-no-floor) and replaced wholesale by that skill only; the composer owns arrangement
  between blocks. **Each block carries its own stamp** with a stated input: a role block's
  `built-against:` names the skill version that wrote it; the composer's submodule-index block
  (§7) stamps against `.gitmodules` + the gitlink SHAs. `check` validates each stamp against its
  named input — one validator per projection, never one stamp pretending to cover all.
  `.records/README.md` follows the same two-region shape. `.agents/roles/` needs no map (its
  paths are its ownership). `check` flags unknown top-level entries in `.handbook/`.

"Role" stays the library's umbrella term for these skills; chiropractor, the in-place steward, has
no seat by nature. Each role self-inits **what it actually owns** — its chapters, its stores, and
a seat only if it has machinery. Deployed projects relocate via `migrate`'s mapping table and
its content classification (§8). The symmetry between roots is descriptive, not procrustean:
`.handbook/design/` (the authored spec) mirrors `.records/design/` (its accumulated records)
because design naturally has both sides — no cell is invented where a content area doesn't.

### 2.4 The role contract — optional maintainers of project-owned content

Every role-based skill refactors onto one shared contract, stated here once (and, at build time,
once in the skills' shared doctrine — never re-derived per skill):

1. **Tend, don't own.** The role creates and maintains the handbook chapters mapped to it in the
   stewardship map; the documents are the project's. Chapter content never names the role.
2. **Machinery in the seat — lazily.** Genuinely project-specific equipment lives in
   `.agents/roles/<role>/`, and *only* there; a seat is created the first time such machinery
   exists, never before. Bundled templates/scripts stay in the skill package. (Today: auditor has
   a seat; architect, foreman, backlog, chiropractor do not.)
3. **Records to the stores.** Its accumulated output lands in its `.records/` stores per §3.
4. **Wired through the front door.** It registers its routes in `AGENTS.md` via the standard
   self-registration protocol — the door is how humans and agents discover which roles are active.
5. **Removable without harm.** Uninstalling the role must leave the project fully legible: the
   handbook stands alone. What goes stale is enumerated and `check`-flagged: the seat (if any),
   the door registration block, the stewardship-map rows, the compiled routing rows that
   dispatched to it, and lane seam references — none load-bearing for a reader, all repairable by
   re-running the map/table compile.

## 3. The record taxonomy — an open set with a named slice

```
.records/
  adr/  plans/  reports/  tickets/  trackers/  done/   # the six typed stores
  audit/  design/                                      # role record domains (auditor / architect)
  logs/                                                # infrastructure (calibrator + role run logs)
```

The named dirs are **foreman+backlog's slice of an open set**, not a closed inventory. The top
level reads as three kinds of thing, all mapped by the stewardship map: the **typed stores**
(including **`done/`, the typed completion store** — the done log `done/log.md` (§4) plus the
`type: done-record` files with their existing linter schema; the old top-level `archive/` was
their de-facto home and dissolving it requires giving them a typed one), the **role record
domains** — `audit/` (auditor's deliverables, self-initialized; its internal `logs/` and
`history/` are *store internals* and stay inside `audit/` — the shared-types rule below applies to
cross-cutting types like reports, not to a domain's own structure) and `design/` (architect's,
with `design/draft/` as its first tenant — `extract`'s staging output, formerly flat
`design-draft/`) — and **infrastructure** (`logs/`). A **role record domain is a directory of
stores** — archives live per *store* (`design/draft/archive/`), never at the domain level. Shared
*types* stay shared: architect's `reconcile` reports land in `reports/` like everyone else's —
`design/` holds only what architect alone owns.

**Archival is a per-store convention, not a place.** The top-level `.records/archive/` dissolves:
any store dir may contain an `archive/` subdir (`plans/archive/`, `design/draft/archive/`,
`tickets/archive/`…) — dead storage next to its living kin, archived *by the store's owner*, and
excluded uniformly from live reads (search recipes, declaration `exclude`, and the linter's
live-store walks skip `*/archive/`). Its former tenants each get a typed disposition in
`migrate`'s mapping table: `done-record` files → `done/`; anything else by source type, with
unclassifiable files surfaced for human triage rather than guessed. Three boundary rules:
**flat aggregator trackers need no file archive** — the done log (§4) is their archive, with
dropped/wontfix items logged there with that outcome; **seed-side entry retirement** (a retired
gotcha, a rescinded invariant) is a calibrator-driven act recorded in the run log (`logs/`), never a
`.handbook/`-side archive dir; **resolved tickets stay in `tickets/`** as durable records —
`curate` may move aged ones to `tickets/archive/`.

**`design/draft/` is transient by design** — unlike its accumulate-forever siblings, it should be
*empty* on a healthy, fully-onboarded project: born at `/architect extract`, consumed by
`/architect init` (migrate mode), and **archived on consumption** (to `design/draft/archive/`); a
stale draft surfaces as a `check` fact, not furniture.

`adr/` and `plans/` keep their current contract (feature's bundled templates still produce their
shapes; instances land here). `reports/` keeps drift/investigation reports. `trackers/` and
`tickets/` are §4–§5.

## 4. Trackers formalized — the fast path, with an audit floor

The flat capture files move under `.records/trackers/` (`tasks.md`, `issues.md`, `feedback.md`,
plus the `bugs/` and `notes/` store dirs) and become a first-class named type. Two additions:

- **Entry IDs.** Every tracker entry carries a lightweight typed ID in the store's wire format
  (§2). IDs are what promotion links, done-log lines, and commit messages reference.
- **The done log.** Completing an entry appends **one line** to `.records/done/log.md`, exact
  wire shape (Phase 0 freezes it):
  `- 2026-08-05 · T-041 · <one-line gist> · commits: abc1234,def5678 · <outcome>` — outcome one of
  `done | dropped | wontfix | drained`; no-work-commit outcomes write `commits: -` (the log
  mutation's own commit is bookkeeping, never cited). The work's commits reference the ID. An
  auditor reconstructs any item via done-log → commits → diff. Full done-record files (in `done/`,
  §3) remain a **feature-lane / workstream-ship** artifact only.

The capture flow is otherwise unchanged: backlog captures uniformly by kind, never drains; the
kinds and classifiers stand (escalation is a lifecycle layer over them, gated by the promotion
bar — §5, never a kind; the one classifier edit is the note-bar retarget, §9); `curate` keeps the
lists sharp (and now also stamps missing IDs).

## 5. Tickets — an escalation wrapper over a capture kind, not a pipeline stage

A **ticket** is what a tracker entry *graduates into* when it needs the human. The default path
stays fast (tracker → agent → done-log); nothing routes through tickets by default.

**The model: a wrapper, not a peer kind.** The capture taxonomy partitions signal by *subject and
nature* into exactly one of the five kinds; "needs a human" answers a **different question** —
lifecycle, not classification. A promoted bug is still a bug. So a ticket is an **escalation
record over an underlying capture kind**: every ticket carries a required `subject_kind`, plus —
when promoted — the `origin:` entry ID it wraps. The five-kind taxonomy and its exactly-one-kind
classifier survive; TAXONOMY.md gains an *escalation layer* section, not a sixth row.

**Ownership.** Backlog owns `tickets/` and the escalation layer — promotion is a lifecycle act on
captured signal it already holds, and a direct ticket is capture-plus-escalation in one motion.
Its capture-only boundary survives: backlog stores the escalation and its conversation, while
**acting** on a resolution stays the consumer's job. Foreman gains no store: the router applies
the promotion bar at dispatch and hands off to `/backlog promote`. No new steward skill.

**Origin-entry disposition — the pause rule, declaration-led.** Promoting an entry marks it
*escalated* in place (`[⇧ TK-…]` on the entry line): visible in its tracker but **paused** —
excluded from fast-path pickup and from the `tracker-entry` drain consumers until its ticket
resolves. Crucially, the pause is **not framework vocabulary consumers must learn**: it is
declaration-led (§2), with an encoding per store shape — **flat aggregators** declare a line
pattern (`paused: \[⇧ TK-[^]]+\]`) matched against the entry line; **store-dir items**
(bugs/notes) declare a frontmatter key (`paused: <TK-id>`, set by promote alongside `id:`).
Consumers skip what the declaration matches — the same mechanism as §2.2's checks, so portable
consumers (chiropractor, debugger) stay generic: they apply a declaration, they never know what a
ticket is. **Fail-safe:** a drain about to mutate, close, or act on an item whose store has a
missing or malformed pause declaration must **skip it and emit a fact** — never drain what it
cannot prove unpaused. On resolution the entry un-pauses and advances or closes; on demotion it
simply un-pauses. An escalated entry is always distinguishable from a stranded one.

**The promotion bar** — promote exactly when resolving the item would require the agent to stand
in for the human's side (the HITL litmus). Four recognizable triggers:

| trigger | promote when… |
|---|---|
| **decision** | a preference / tradeoff / scope call only the human can make |
| **sign-off** | risky, irreversible, or outward-facing enough to want approval |
| **ambiguity** | unclear enough that guessing risks real waste |
| **access** | human-only provisioning — accounts, credentials, purchases |

Deliberate exclusions: **multi-session scope alone is not a trigger** (big-but-clear work belongs
to plans/roadmaps in the feature lane). **Tie-breaker favors motion:** when uncertain, proceed if
the action is cheap to reverse (leave a tracker note); promote only if it isn't. Applied at two
points: the router at dispatch, and any agent mid-work. Humans can force-promote or demote at
will. **Promotion is a trunk-side act, wherever the promoting agent works.** Escalation is shared
state — the pause marker must be visible to every drain and the ticket to every sync *now*, not
when a branch lands (a branch whose landing waits on the human answer would make its own ticket
invisible — circular). So `promote` writes the ticket file and the pause marker directly on the
**trunk checkout** via the existing pathspec-scoped-commit discipline (the same rule all small
shared-state edits follow), and the working branch simply cites the `TK-` ID. Sync (§6) can then
run immediately; promotion is never blocked on the mirror, and no deferred-push state exists.

**Two entry paths.** `/backlog ticket <subject>` captures a ticket **directly** — classified into
its `subject_kind` like any capture, but born escalated: no tracker entry, `origin:` absent by
rule. `/backlog promote <id>` **graduates** an existing entry, stamping `origin:` and pausing it.
Re-promotion after a demotion is legal and produces a *new* ticket citing the same `origin:` —
origin citations are references, not definitions, so ID resolution is untroubled by N of them.

**Schema.** One file per ticket: `.records/tickets/<YYYY-MM-DD>-<slug>.md` (never renamed); the
ticket ID is **derived by prefixing the stem**: `TK-<YYYY-MM-DD>-<slug>` (§2). The uniform
store-dir frontmatter block, extended:

```yaml
---
type: ticket
id: TK-2026-08-05-gate-choice   # derived from the filename; stated for grep-ability
status: open                    # open | answered | resolved
subject_kind: issue             # REQUIRED — one of the five capture kinds
origin: I-017                   # promoted tickets only; absent on direct tickets
blocking: [TK-2026-08-01-trunk-name]  # optional; gates THIS ticket's resolution only; cycles = check fact
mirror:                         # present only while mirrored (§6)
  provider: github
  issue: 214
  pushed_hash: 5f2a…            # hash of the canonical projection (§6 — mirror block excluded)
  comments:                     # per-imported-comment state (§6)
    - {id: 1888214301, updated: 2026-08-05T14:02Z, hash: 9c1b…}
updated: 2026-08-05
---
```

Body sections:

```
## Context            — what this is; link to the origin entry (direct tickets: the capture context)
## Decision needed    — the question, WITH the agent's recommended answer (react, don't compose)
## Comments           — append-only human↔agent conversation (imported comments keyed by remote ID)
## Resolution         — what was decided + what the agent did with it
```

**Lifecycle — the transition/actor table.** States: `open` (waiting on the human), `answered`
(the agent has what it needs), `resolved` (terminal; `wontfix` and `demoted` are resolution
flavors). The **agent is the only state writer**; the human converses and the agent interprets.
Rows marked *(promoted only)* are n/a for direct tickets:

| event | actor | state | origin entry *(promoted only)* | done log |
|---|---|---|---|---|
| create (direct) | agent | → `open` | n/a | — |
| promote | agent | → `open` | paused `[⇧ TK]` | — |
| human comment (sufficient) | human→agent | → `answered` | paused | — |
| human comment (partial) | human→agent | stays `open` (agent sharpens the ask) | paused | — |
| agent follow-up question | agent | `answered` → `open` (oscillation is normal) | paused | — |
| resolve | agent (consumer acted) | → `resolved` | un-paused; advances or closes | one line, outcome + commits |
| wontfix | agent per human | → `resolved` (flavor: wontfix) | un-paused; closes | one line, `commits: -` |
| demote (human recalls it) | agent per human | → `resolved` (flavor: demoted) | un-paused, live again | — |

One known lag, accepted and surfaced: with verb-time-only sync (§6), a human who answers on the
mirror is invisible in-repo until the next verb runs — the canonical file lags knowingly, and
`check` emits an unanswered-age fact that includes mirror-side staleness.

**The `answer` and `resume` seam** (named in the runbook, §11): *answer* = the human's comment
that moves a ticket to `answered`; *resume* = the consumer that owns the origin work acting on it.
Backlog stores; the resuming consumer is whoever the router dispatches — the seam row states this.

## 6. The mirror — a stamped projection with an explicit sync protocol

For hosts with a remote issue system — **the mirror** (GitHub first; never called "the tracker,"
per the pack design's vocabulary table) — tickets project into it so the human gets UI and
notifications. Doctrine frame: **the in-repo file is canonical; the mirror is a stamped projection
with a drift check** — never the reverse. Sync state lives in the ticket's `mirror:` block (§5).

- **The canonical projection (the hashed input, defined exactly):** the rendered body minus
  `## Comments`, plus the projected header fields (`id`, `status`, `subject_kind`, `origin`,
  title). The **`mirror:` block and `updated:` are excluded** — the hash must not hash itself.
  `pushed_hash` is the built-against stamp; a push happens only when the projection's hash
  differs, and updates it.
- **Push** projects to the issue: labels = status, title = ticket ID + subject, body = the
  canonical projection + a `mirrored-from` footer carrying the ticket ID. Comments never
  round-trip into the body (the echo class is dead by construction).
- **Pull — full inventory, not a cursor.** Every sync lists the issue's **complete** comment set.
  New remote IDs are appended to `## Comments` (keyed by immutable remote ID — the idempotency
  key) in remote-ID order, and recorded in `mirror.comments` with `updated` + content hash.
  Known IDs whose remote `updated`/hash changed → **edited-comment drift fact**; known IDs absent
  remotely → **deleted-comment drift fact**. The file wins, always; drift facts are for the verb
  to judge. (Provider contract: immutable comment IDs with a total order, comment list + updated
  timestamps — GitHub satisfies it; another provider must, or it doesn't get a mirror.)
- **Idempotent creation.** Before creating an issue, **scan the repo's issues by the framework
  label** for the stamped ticket ID (a list scan, not the search index, which is eventually
  consistent) — found → adopt (lowest issue number wins if duplicates exist; the rest are flagged
  as facts), not found → create, then commit the `mirror:` block. A crash between the two heals on
  the next sync via the same scan.
- **Serialization — a lock, not a location.** Sync acquires a repo-local lock at
  `.records/tickets/.sync-lock` — **atomic `mkdir`**, a payload file naming owner (pid + session)
  and acquisition time, **stale after 10 minutes** with takeover logged as a fact, removed on
  completion, and excluded from tracking (the scaffold writes the exclusion). Two concurrent
  syncs therefore cannot interleave create/pull. Additionally sync runs **only on the trunk
  checkout** — **new discipline this design introduces**, binding *sync only* (ordinary records
  keep today's write-from-anywhere behavior); promotion is already trunk-side (§5), so there is
  no branch-held ticket state for sync to miss.
- **Trigger:** verb-time only (`promote`, `close`, `/backlog sync`) — never a daemon.
- **Degradation:** no remote or tracker → no `mirror:` block, no behavior change. The mirror is a
  harness/host edge; the portable core is the file.

Scripts compute the sync facts and perform the mechanical projection; verb prose owns every
judgment — facts-not-verdicts. The build-out (§11) tests the failure matrix explicitly: duplicate
retry, crash between create and commit, two-worktree sync attempt (must refuse), comment arriving
mid-sync, **edited-comment and deleted-comment drift**, **two concurrent trunk syncs (lock
contention)**, and adoption with duplicate stamped issues.

## 7. Super-projects — root owns, submodules opt in

- An **opted-in submodule is a complete, standalone installation** — its own front door, spine,
  and records. Cloned alone, it is simply a framework project.
- **The installation block — a first-class artifact, creatable by any self-init.** An
  *installation* is a repo root whose front door carries the **installation block**. Exact grammar
  (Phase 0 freezes it): the same comment-block syntax as §2's declarations — opening line
  `<!-- installation v<integer>`, then the v1 keys `layout: <integer>` (required), `pack: <name>`
  and `pack-version: <version>` (written by pack onramps; absent on bare single-skill installs —
  the pack design §3.5 defines the three axes), closing `-->`; at most one block per front door;
  malformed or duplicated = a fact, and resolution treats the root as unstamped. **Any durable-home self-init creates or adopts it idempotently** — the
  content is deterministic (same bytes regardless of writer), so a bare `/backlog init` with no
  composer anywhere produces a fully resolvable installation: self-init-no-floor holds, and the
  composer stays an optimization, never a dependency. The block sits outside every skill's
  registration delimiters; no verb ever writes inside another's. It is distinct from, and
  additional to, the *optional* `records-root` front-door variable, which keeps its exact current
  contract (one optional line; absence means the default). **There is no legacy heuristic:** an
  unstamped root is simply **unmigrated** — framework verbs on such a root route to `migrate`
  (pre-existing content of any shape) or `setup` (empty project) before operating (§8).
- **Nearest-enclosing installation wins.** Resolution is a **filesystem walk up from the session
  path** (authoritative); at each repo root without a stamped front door,
  `git rev-parse --show-superproject-working-tree` continues the walk across the repo boundary
  (recursively for nested submodules; standalone clones and worktrees terminate at their own
  root). If **no** stamped door is found anywhere, the session is simply unmanaged — skills offer
  `setup`, nothing resolves implicitly. Exactly one installation governs any session; **routing
  tables never merge**. The resolver hands the chosen root **explicitly** to the existing
  single-root machinery (registration, the front-door-variable readers, the health scripts) —
  that machinery is preserved; the *root-finding in front of it* is new, stated mechanism.
- **The root indexes.** `setup` detects `.gitmodules` and stamps a **submodule index** into
  `.handbook/README.md`'s maintenance region (§2.3): path → opted-in / not / **unknown**
  (uninitialized submodules are listed, never guessed), stamped against `.gitmodules` + each
  gitlink SHA so `check` can flag staleness after any submodule bump. Root's `ROUTING.md` gains
  one rule: a change living entirely inside an opted-in submodule is worked *there*.
- **Capture follows locality.** Submodule-local signal lands in the submodule's trackers.
  Cross-cutting work is tracked and ticketed at **root** as the canonical item; per-submodule
  slices are **derived links** citing the root item by its globally-unique `TK-` ID — the only
  legal cross-installation citation (§2's rule; bare counter IDs never cross a boundary, and no
  qualified-path form exists). Status lives at root. Landing order is the only order git permits: submodule commits
  first, then the superproject's gitlink bump; the root item resolves only after the gitlink
  lands. Signal about non-opted-in submodules lands in root trackers with a `component:` field.
- Opt-in is near-zero-config: root owns unless a submodule declares (the safe default).

## 8. Foreman's verbs against the new layout

- **`setup`** — *facts by script, decisions by interview, minimal seed.* The script gathers gate
  commands, trunk name, remote/tracker presence, `.gitmodules`, doc landmarks; the interview asks
  only genuine decisions (lanes, submodule opt-ins, mirror on/off). Templates are **skeletons with
  parameter slots** — lane files cite the host's actual gate and trunk. Knowledge docs deploy
  nearly empty: INVARIANTS seeds only universal load-bearing rules, parameterized; GOTCHAS is a
  format header + declaration; POLICY starts empty; RECORDS.md deploys complete (formats are not
  project-variable). Setup writes the installation block (§7) and the layout version,
  unconditionally. No generic prose ships.
- **`migrate` — format-agnostic by design: generic discovery + judgment, one gated pass.** The
  design names **no legacy formats**. `migrate` inventories *whatever exists* at the root —
  documents, tracker-like files, record stores, prior agent scaffolding of any convention —
  **classifies each artifact by its content** into the new taxonomy (a rule → INVARIANTS; a
  procedure → its lane file; a judgment → POLICY; a trap → GOTCHAS; work items → tracker entries;
  decision records → `adr/`; completion evidence → `done/`; genuinely project-specific tool
  material → the owning role's seat, with "no seat" a valid outcome; operator overrides stay put),
  and proposes the **complete mapping table** — every discovered artifact in exactly one row, with
  anything unclassifiable surfaced for human triage, never guessed. The human confirms the table
  once; `migrate` executes in a **worktree**; the table doubles as the **nothing-dropped check**
  and `check` must be green after. A declared `records-root` (a live variable, not a legacy
  format) is respected — same walk, no bulk git-mv. **Pre-existing identifiers of any shape are
  preserved verbatim as `(alias <old>)`** on the restamped entries, with in-repo citations
  rewritten and the alias map recorded in the migration's done-record. **Preconditions, checked
  before the table is proposed:** clean tree, no active workstreams/worktrees, a
  whole-installation duplicate-ID scan, and the unclassifiable-artifact triage. On completion,
  `migrate` writes the installation block (§7) — the project is now stamped, and never
  re-migrated.
- **Stamped-only operation — no compatibility window.** Framework skills **operate only on
  stamped installations**. On an unstamped root, every framework verb routes to the two onramps —
  `setup` (empty project) or `migrate` (pre-existing content) — and does nothing else; scripts
  emit an `unstamped` fact and stop. **One named exception:** a role's bare *domain* self-init
  may create its own stores and the installation block, per the pack design's pre-stamp dispatch
  table (its §3.4) — that is how a single-skill install becomes a resolvable installation. There is no dual-layout read/write support, no old↔new path
  map, and no old-skill/new-layout support matrix: prose and scripts speak **one** layout, the
  stamped one. The `layout:` version exists for the *future* — a later framework revision bumps
  it and ships a then-current `migrate` that upgrades any stamped older layout the same
  discovery-and-mapping way, still without dual operation.
- **`check`** — extends to the new shapes: spine coverage, declaration conformance delegation, ID
  integrity + whole-installation duplicate scan, budget overflow, done-log/tracker consistency,
  lane-vs-skill coverage, mirror drift (incl. unanswered-age), submodule-index staleness,
  installation-block validity, per-block stewardship-map stamps — all as facts. One honesty note: the
  routing-table drift check the front-door design names is **only partially implemented at HEAD**
  (`check-projection` diffs door registrations against installed skills; it never reads
  ROUTING.md) — this design's build extends it into a real table ↔ `rules/ROUTING.md` diff at the
  new path; that is an extension, not a claimed-unchanged mechanism.
- **`calibrate` — superseded by the pack's calibrator role** (pack §4.7): the improvement loop
  is driven by `/calibrator`, and edits land in typed homes (a trap → G-entry, a rule →
  INV-line, a judgment → POL-entry) as routed work applied by the owning role.
- **`route`** — unchanged, plus the promotion bar at dispatch (§5).

## 9. Backlog's changes

- `skills/backlog/docs/TAXONOMY.md`: the five kinds stand; **one classifier is retargeted** — the
  "note vs `MEMORY.md`" bar becomes "note vs `INVARIANTS.md`" (MEMORY.md retires, §10), which
  also touches backlog's `note`/`debrief` verb files (in §11's inventory). The doc gains the
  **escalation layer** section (wrapper model, `subject_kind`, the declaration-led pause, the
  transition table — §5) and the ID wire formats (§2). Stores move under `.records/trackers/`;
  `tickets/` is a store dir with the extended frontmatter block (§5). Backlog also deploys and
  maintains **`rules/RECORDS.md`** (§2) — the deployed subset of the taxonomy's formats.
- Verbs: the five capture verbs and `debrief` are unchanged; new verbs — **`ticket`** (direct
  capture-plus-escalation), **`promote`** (entry → ticket, `origin:` + pause — a trunk-side
  scoped commit, §5), **`sync`** (mirror pass, trunk + lock), **`close`** (resolve / wontfix /
  demote per §5's table, with writebacks); `curate` extends to ticket hygiene (stale `open`
  tickets, unanswered ages, ID stamping, duplicate-ID repair with aliases, aging resolved tickets
  to `tickets/archive/`).
- Registration: backlog's description gains tickets/escalation language, so the **routing probe**
  re-runs ("file a follow-up" and "escalate to the human" must both route to backlog cleanly).
  Typed edges: trackers keep producing `tracker-entry`; the **consumers' contract is amended via
  declaration** — drains skip entries matching the tracker's declared pause pattern (§5), and
  every drain writes its done-log line (§4). A `ticket` type enters the open vocabulary with its
  producer (backlog) and consumer (the resuming lane, via the answer/resume seam row) stated.

## 10. Doctrine reconciliation — what this supersedes, what stands

**Supersedes** (each surface updated in the same pass — fix-the-doctrine-everywhere):
- The four-doc workflow-stage layout and its BOOTSTRAP module table/tree.
- `MEMORY.md` as the invariants home (→ INVARIANTS; promotion mechanism survives) — including
  TAXONOMY's note-vs-MEMORY classifier, retargeted to the INVARIANTS bar (§9).
- The flat-at-root tracker paths (→ `.records/trackers/`).
- TAXONOMY's "capture is the whole story" silence — the five kinds and the closed set **stand**;
  an escalation layer is added over them (§5), and the drain consumers' view of tracker entries
  is amended *by declaration* (they skip declared-paused entries — no framework vocabulary enters
  portable consumers).
- The WORKFLOWS-dissolution rationale's payload half (§2.1 — the menu half stands, and §8-C's
  dual-dispatch rejection is upheld by the stated two-read fallback chain).
- The ownership-index row *content* and its framing (→ the two-region stewardship map, §2.3 —
  mechanism amended: delimited stamped maintenance region + content-vs-arrangement writer
  protocol).
- The unstated single-root assumption (→ §7's nearest-enclosing rule + installation block).
- Documents living in role homes — the old `.agents/<role>/` layout (→ documents to `.handbook/`;
  lazy machinery-only seats under `.agents/roles/`).
- The flat `design-draft/` store (→ `design/draft/`, with an explicit transient lifecycle).
- The top-level `.records/archive/` (→ per-store `<store>/archive/`; `done-record` tenants get
  the typed `done/` store; workstream's ship/close verbs archive into the stores their records
  came from).
- The unstated installation-discovery walk (→ §7's explicit resolver; the single-root machinery
  behind it is preserved, the root-finding and the installation block are new, stated mechanism).

**Preserved, by construction:** the routing compiler model's row-target contract and the read-cost
tier rules (§2, §2.1); typed edges and the open vocabulary; self-registration and the
content-vs-arrangement protocol (now also governing the stewardship-map region and the
installation block's composer ownership); self-init-no-floor (roles create index skeletons when
absent); the capture-only boundary (the per-layer drains are superseded by the pack's
calibrator loop — pack §4.7/§7; consumer skipping is amended only via declarations);
**`records-root` exactly as it is** — an optional variable, absence meaning the default; the
installation block is a separate, new artifact (§7); facts-not-verdicts scripts; the lint +
routing-probe gates; scoped-commit discipline; store-dir frontmatter + doc-linter wiring (extended
with `id:`); **the affordance/fidelity audit seam and chiropractor's any-repo genericity** (§2.2 —
extended via declarations, never via framework vocabulary; its portability *gate* is built new,
§11); design docs as historical records (superseded docs get status-line updates only).

**Constraints honored:** snapshot-never-authoritative (the mirror, the tier-0 table, the
stewardship-map region, and the submodule index are all stamped projections with drift checks);
patient-zero (grimoire's own AGENTS.md gains nothing; every new mechanism is exercised against
throwaway fixtures); harness-agnostic core with the GitHub mirror at the edge;
doctrine-trails-reality-by-zero (pilot before promoting rules into DOCTRINE).

## 11. Rollout — freeze, build, migrate, prove

Stamped-only operation (§8) removes the compatibility window entirely: skills are rewritten to
speak one layout, and every deployed project crosses over via its own single gated migration. The
phases:

- **Phase 0 — freeze the contracts.** The exact schemas this doc specifies — the declaration +
  spine-index grammar (§2), the ID namespace + per-store wire formats (§2), the ticket schema +
  transition table (§5), the mirror state + projection + lock (§6), the installation block (§7),
  the done-log wire line (§4), the stewardship-map block protocol (§2.3) — are fixed; the
  implementation plan carries them as its appendix. **The search-derived source inventory is also
  built here**: grep the whole *library* for every path/doc-name the refactor touches, so the
  skill rewrite in Phase 1 is sized from evidence, not recall.
- **Phase 1 — the surfaces**, in dependency order, each consuming the frozen contracts:
  1. **backlog** — TAXONOMY escalation layer + wire formats, `trackers/` paths, RECORDS.md
     projection, ticket store + templates, `ticket`/`promote`/`sync`/`close` verbs, mirror
     scripts (facts + lock), curate/health extensions; routing probe.
  2. **foreman** — BOOTSTRAP rewritten to the spine; setup interrogation + skeleton templates +
     declarations + installation block; check facts (§8's list, incl. the extended
     table↔ROUTING diff); route's promotion-bar line; recompiled door profile (skill-entry rows +
     the shared fallback line → `rules/ROUTING.md`).
  3. **chiropractor** — the three declaration-driven checks + declaration-led discovery (§2.2);
     removal of the hardcoded scanner paths (`spine-scan.sh:427,429`); **build** the
     package-wide portability gate (none exists today at any scope).
  4. **Role re-framing** — foreman/architect/auditor SKILL.md descriptions and verb docs
     rewritten onto the §2.4 contract; descriptions change, so the routing probe re-runs.
  5. **clankshop + README + AGENTS.md storage note** — layout rows, seam rows (promote / answer /
     resume as a runbook seam contract), vocabulary table (`ticket` type).
  6. **Conforming edits, from the Phase-0 inventory** — known today: the architect/auditor
     documents-vs-machinery conforming changes; architect's `design/draft/` +
     archive-on-consumption; workstream's per-store archiving + its scripts + its templates and
     `flow.md`; backlog's `note`/`debrief` verb files (the retargeted classifier); feature's
     SKILL.md/templates; handoff; foreman's report template; the doc-linter store list + `id:`
     schema; superseded design docs' status lines. Every verb gains the **stamped-only guard**
     (unstamped root → route to the onramps, emit the fact, stop).
- **Phase 2 — migration tooling.** `migrate`'s format-agnostic upgrade mode (§8): generic
  inventory, content classification, the mapping table, alias preservation, citation rewriting,
  worktree execution + rollback, nothing-dropped validation, final stamping.
- **Phase 3 — fixture proof, per mechanism and integrated.** Each mechanism is exercised against
  a throwaway fixture as it lands, plus a final integrated pass: greenfield setup; **migration of
  a pre-existing ad-hoc project** (arbitrary prior conventions, incl. a custom `records-root` and
  bare single-skill installs at default and custom roots); the **unstamped-refusal case** (every
  framework verb on an unstamped root routes to the onramps and does nothing else); a fixture
  super-project (standalone / opted / non-opted / uninitialized / nested submodules); and the
  **cold-clone acceptance fixture** — after setup, a reader given only the committed `AGENTS.md`
  \+ `.handbook/` (no skills, no `.agents/` reads) must be able to choose and execute each lane
  by hand; then each role is removed in turn and the link/depth/route checks re-run — the direct
  test of "accelerators, never prerequisites" and "removable without harm."

## 12. Alternatives considered

- **Atomic entry files with compiled views** — rejected: file sprawl and a mandatory compile step
  buy little at dozens-of-entries scale; kept only where lifecycle demands it (tickets).
- **One compressed operations doc** — rejected: re-smears the types and becomes the contested home
  for everything.
- **Dissolving `ROUTING.md` into the door** — rejected: routing edits would contend on the
  always-loaded door, tie-breaker judgment loses its single home, and the compiler machinery would
  be reworked rather than reused. `ROUTING.md` survives *lean* (§2).
- **Per-row fallback anchors** (dual-dispatch rows) — rejected again, upholding front-door §8-C:
  the two-read shared fallback chain (§2) serves the bare-agent case without doubling table rot.
- **Tickets as the universal work unit** — rejected: taxes the fast path; tickets exist only where
  the human is needed.
- **Ticket as a sixth capture kind** (this design's own first draft) — rejected on review: "needs
  a human" is a lifecycle question, not the subject/nature question the kinds partition on; the
  escalation wrapper (§5) keeps the taxonomy intact.
- **Header-line ticket metadata** — rejected for the canonical file (breaks the uniform store-dir
  frontmatter); the mirror projection owns the translation.
- **Tracker-canonical-while-open mirroring** — rejected: inverts snapshot-never-authoritative.
- **Root-always-governs / root-delegates submodule models** — rejected: split-brain risk, or root
  modeling every submodule's lanes; nearest-enclosing keeps every existing script single-root.
- **A new ticket-steward skill** — rejected: no proven gap, and a mirror mechanism alone doesn't
  earn front-door registration.
- **Overloading `records-root` as the installation sentinel** (rev 3's mistake) — rejected: the
  variable is optional by doctrine ("a host on the default declares nothing"), so it cannot mark
  installations; the dedicated installation block (§7) does, and `records-root` stays untouched.
- **A dual-layout compatibility window** (rev 4's mechanism: layout-conditional reads/writes, an
  old↔new path map, legacy heuristics) — rejected: it couples every script and verb to enumerated
  legacy formats forever, and prose cannot execute non-uniform path substitution anyway. Replaced
  by **stamped-only operation + format-agnostic migration** (§8): the design specifies no legacy
  formats; `migrate` discovers and classifies whatever exists, once, per project.

## 13. Measures

- Chiropractor facts: `always_loaded_bytes` within budget; `max_depth` ≤ 2 from door to any lane
  file (and the two-read fallback chain measured explicitly); `doc_sizes` shows no bundled-jobs
  outlier; **declaration-block bytes reported per spine doc** (they ride every tier-1/2 read);
  the three declaration checks report solid on a deployed fixture. *(Superseded by the pack
  design §4.6/§7.3: the non-`.handbook` genericity fixture and the package-wide portability gate
  are retired with chiropractor's any-repo mandate — the acceptance case is now the
  framework-aware document audit with the exact chiropractor/clankshop fact partition.)*
- `/foreman check` green on a migrated project and on the fixture super-project, including ID
  integrity, mirror-drift (edit/delete/age), stewardship-map stamps, and installation-block facts.
- Routing probe: fresh-subagent probe routes "file a follow-up," "escalate to the human," "where
  do I start a change," and "set up the dev system" correctly, descriptions only.
- The fast path stays lean — completing a tracker item adds one done-log line; capture adds one
  ID allocation; drains add one declared-pattern skip. Each measured against today's cost.
- The **cold-clone acceptance fixture** (§11 Phase 3) passes: every lane executable by hand from
  `AGENTS.md` + `.handbook/` alone, and role-removal leaves check-flagged-but-legible state.
- The build-out's test matrix covers: greenfield; migration of pre-existing ad-hoc projects
  (arbitrary conventions, custom `records-root`, bare single-skill installs, pre-existing
  identifiers preserved as aliases, unclassifiable-artifact triage); the unstamped-refusal case;
  trunk-side allocation + branch slug-placeholder stamping at landing; pause fail-safe on a
  missing/malformed declaration; no-remote degradation; mirror retry /
  crash-between-create-and-commit / worktree-sync refusal / mid-sync comment / **edited and
  deleted comments** / **concurrent-sync lock contention** / duplicate stamped-issue adoption;
  and standalone, opted, non-opted, nested, and uninitialized submodules.
