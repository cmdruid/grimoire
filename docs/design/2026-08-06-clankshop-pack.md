# The clankshop pack — roles, pipelines, and helpers as one system

**Status:** Draft (2026-08-06), revision 4 — rev 2 reworked after an independent review
(`.scratch/agent-framework/codex-review-4.md`, REWORK): five-role remnants purged from §7, the
doctrine projection specified as a base-aware three-way protocol with a human-reviewed upstream
path (§5), the pre-stamp dispatch table added (§3.4), intake/completion ownership settled (§4.2–
§4.3), pack versioning separated from layout with a pack lock (§3), the audit seam partitioned
exactly (§4.6), aliases re-based on proxy *skills* (no vendor-specific mechanisms anywhere —
skills and docs only), debugger's contract corrected, and the rollout expanded to the
live migration surface (§8); rev 3 adds the **calibrator** role (§4.7 — the improvement loop
elevated from foreman; per-role calibrate verbs dissolved) and restores the **backlog** name;
rev 4 adds the **instruments tier** (backlog + debugger) and the **guardian** role (§4.4 —
verification stewardship split from the debugger instrument), then closes the final verification
pass (`codex-review-5.md`): instruments joined the core/lock definitions with the refined
role/instrument criterion (§2), the calibrator's intake table + materialized improvement items
(§4.7), the calibrate-grammar supersession delta (§7.7), the report wire contract (§4.8), and
the backlog no-rename cleanups. Companion to
`docs/design/2026-08-04-agent-framework.md` (the mechanics, which survive intact); §7 enumerates
the composition deltas. Both docs land together.

**Goal:** Reorganize the framework skills as **one atomically-versioned pack — `clankshop`** —
with four tiers: **roles** (inheritable expertise exercising judgment over a domain),
**instruments** (mechanical core tools any role or agent operates), **pipelines** (multi-stage
work processes), and **helpers** (portable utilities). The pack itself
is the bootstrap: `clankshop` carries the doctrine and runbook and stands the system up; roles
never bootstrap. Skills inside the pack reference each other and the deployed layout directly —
the independence machinery (typed edges, seam derivation, sibling-blind prose) is retired *for
the core — the face, roles, instruments, and pipelines* — and retained in full by the portable
helpers.

**References:**
- `docs/design/2026-08-04-agent-framework.md` — the mechanics this pack deploys (three-root
  layout, spine, tickets, mirror, submodules, stamped-only migration).
- `packs/clankshop.md` — the runbook this pack absorbs and replaces (name inherited).
- `docs/design/2026-07-27-steward-grammar.md`, `2026-07-18-skill-self-init-model.md`,
  `2026-07-18-skill-boundaries-and-glue-ownership.md` — the independence-era composition docs
  whose pack-member provisions this design retires (their helper-tier provisions stand).
- Review evidence: `.scratch/agent-framework/{codex-review-2,opus-review,codex-review-3}.md` —
  the independence tax made concrete (see §1).

---

## 1. Why a pack — the independence tax, paid in evidence

The framework skills were authored as independent leaves: typed edges instead of names, seams
derived rather than authored, self-scoping descriptions guarded by routing probes, prose like
"the tracker the host's front door names" instead of a path. That discipline has a real purpose —
for skills that travel alone. But the framework skills do not travel alone: they share a deployed
layout, a schema contract, and a methodology. This week's design reviews made the tax measurable:
the hardest findings — ticket ownership (backlog vs. foreman), the capture-only boundary
gymnastics, escalation vocabulary leaking into "portable" consumers, the composer-vs-self-init
sentinel blocker — were **all boundary-maintenance problems between skills that were never going
to be separated**. When an architecture's hardest problems are its internal walls, the walls are
billing you.

The precedent is established practice: the leading skill packs (superpowers; Matt Pocock's
skills) name siblings freely as mandatory control flow, ship pack-level setup that writes shared
substrate, and avoid reference rot the honest way — **atomic versioning**: the pack ships as one
unit, so cross-references cannot drift. Clankshop adopts the same posture.

What the pack model deletes for its **core members** (face + roles + instruments + pipelines —
helpers are exempt throughout): typed-edge blocks and the open-vocabulary matching,
`derive-seams` (composition is authored, not derived), the sibling-blind prose indirection, and
the genericity machinery built solely to let pack-adjacent skills pretend ignorance of the pack
(§4, chiropractor). What it keeps: the thin-router SKILL.md shape, verb files read on demand,
self-scoping descriptions (they still route), scripts-compute-facts, scoped commits, and the
deployed system's own independence — the **project** never depends on the skills (the mechanics
doc's cold-clone guarantees are untouched).

## 2. The taxonomy — roles, instruments, pipelines, helpers

| tier | skill | is | manages / does |
|---|---|---|---|
| **pack** | **clankshop** | the pack's executable face | doctrine + runbook; `setup` / `migrate` / system `check` (§3) |
| **role** | **architect** | design expertise | `.handbook/design/` + `.records/design/` |
| **role** | **foreman** | operations expertise | `route`; `.handbook/rules/` + `workflows/`; `.records/logs/` |
| **role** | **guardian** | verification expertise | `.handbook/testing/` (gate, CI/CD, diagnostics playbook); verification judgment (§4.4) |
| **role** | **auditor** | code-quality expertise | rubric (seat) + `.records/audit/` |
| **role** | **chiropractor** | docs-quality expertise | audits `.handbook/` + `.records/` + the front door (§4.6) |
| **role** | **calibrator** | the improvement loop (§4.7) | intake over trackers + quality findings; dispatches improvement items; upstream contributions |
| **instrument** | **backlog** | the records instrument | capture + debrief + `done` + curate + tickets/escalation; `rules/RECORDS.md`; `.records/trackers|tickets|done` |
| **instrument** | **debugger** | the diagnostic instrument | the root-cause procedure (§4.8); guided by guardian's playbook |
| **pipeline** | **feature** | brainstorm → build | planning artifacts → `.records/plans|adr` |
| **pipeline** | **workstream** | shipping lanes | parallel work units; ships `done-record`s |
| **helper** | **delegate** / **mailbox** / **handoff** | plumbing | dispatch, transport, session continuity; portable |

**The vocabulary table, binding for both design docs and all pack prose:**

| term | means | never means |
|---|---|---|
| `/backlog` / "the backlog instrument" | the records instrument (the skill) | the files or the remote |
| "the trackers" / `.records/trackers/` | the store files | the remote |
| "the mirror" | the remote issue system | — (it is never called "the tracker") |
| "ticket promotion" / `/backlog promote` | entry → ticket escalation | the upstream loop |
| "upstream contribution" | the human-reviewed doctrine loop (§5, driven by the calibrator) | ticket promotion |

The terminology sweep is a rollout item (§8) and a routing-probe fixture.

**A role is an expertise an agent inherits.** When the work calls for the role — the front door's
routing and the lane files' seam glue say when (§6) — the agent loads the skill and *is* that
role for the session. Roles manage their part of the system (chapters, records, machinery); they
never bootstrap it, and none is special: the old "foreman as composer" carve-out is gone (§3).
Under the pack, roles are cheap (no independence machinery), so **cohesion — not seam-avoidance —
draws the boundaries**: routing a change, judging verification, and improving the system are
standing judgments at different moments — each a role; recording the work and diagnosing a
defect are procedures anyone runs — each an instrument. Every role is a profession describable
in one sentence; every instrument is a tool nameable in one.

**Instruments** — the criterion, stated precisely: **a role stewards a domain and owns its
standing judgments; an instrument is an invokable procedure or store operation whose *operator*
exercises the judgment.** Running the debugger involves hypothesizing — but that judgment
belongs to whoever runs it, applied through the procedure; curating a list involves ranking —
but backlog owns no standing judgment about the *system*, only the upkeep of its own stores
(the way a filing cabinet owns its drawers). Domain-level standing judgments always live with a
role: the calibrator judges what signal means, guardian judges verification, backlog and
debugger are the tools those judgments are exercised through.

**Pipelines** are processes the roles' system supports, not domain managers. Feature and
workstream stay separate: one turns an idea into gate-green code; the other encapsulates work
into parallel-safe shipping lanes. (A future merge remains possible if verb overlap proves it;
nothing in this design depends on it.)

**Helpers** are now *purely* plumbing — delegate, mailbox, handoff — portable on any repo,
keeping the full independence discipline. No hybrid "consultant" category remains: chiropractor
became a role, debugger an instrument.

## 3. Clankshop — the pack's executable face

`clankshop` graduates from a runbook document to the pack's entry skill.

### 3.1 The doctrine

The pack's own handbook, written in the spine format the mechanics doc froze (declaration
blocks, `INV-`/`POL-` entries, lane files): the default rule/policy/lane seed sets, the
**canonical record schema** (§7.6), the door profile, the **chapter registry** (`rules/`,
`workflows/`, `design/`, `testing/` — plus the stewardship-map protocol for adding one), and the
team roster (§2). Because doctrine and project handbooks share one format, **seeding is copying
entries** under the projection protocol (§5): provenance-stamped, base-recorded, mechanically
diffable. The doctrine is swappable in principle — its declaration carries a **source ID**
(`doctrine: clankshop`) and version, so two doctrines can never be confused even when both carry
a `v1` and an `INV-4`; the pack bundles its default.

### 3.2 The runbook (using-doc)

The methodology narrative, superpowers-style: the flow of a change through the system, when to
assume which role, how the pieces play together. The runbook is pack-level and universal; the
*handbook* is per-project and specific; the *doctrine* is the seed content between them. Three
documents, three altitudes.

### 3.3 The system verbs

- `/clankshop setup` — greenfield bootstrap: interrogate the project (facts by script, decisions
  by interview), **project the doctrine through the facts** into `AGENTS.md` + `.handbook/` +
  `.records/` (minimal-seed filtering: universal invariants deploy; the rest stays upstream as
  available doctrine), write the installation block, stamp the stewardship maps and the compiled
  routing table.
- `/clankshop migrate` — the same act over pre-existing content: the mechanics doc's
  format-agnostic discovery + classification + one confirmed mapping table, ending stamped.
- `/clankshop check` — whole-system **assembly** validation, exactly partitioned against the
  docs-quality role (§4.6): installation block; stamps and projections (door table ↔
  `rules/ROUTING.md`, stewardship maps, submodule index, `RECORDS.md` ↔ doctrine schema);
  **chapter presence** against the registry; **cross-store foreign-key integrity** (IDs cited
  across stores resolve: ticket origins, done-log rows, blocking); mirror drift; seat inventory;
  pack lock vs installed set. Validating the assembly is the assembler's job; roles validate
  nothing system-wide.

### 3.4 The pre-stamp dispatch table

"Roles never bootstrap" means **whole-system assembly is clankshop's alone**; a role's bare
*domain* self-init is a narrower act — and the explicit, named exception to the mechanics doc's
stamped-only refusal. The table, frozen here:

| verb on an unstamped root | may create | must not touch |
|---|---|---|
| `/clankshop setup` / `migrate` | everything (the bootstrap) | — |
| `/backlog init` (each capture verb calls it lazily) | `.records/trackers/` skeleton + the installation block (idempotent) | any `.handbook/` chapter |
| `/architect init` / `extract` | its design chapter + records + skeleton maps + the installation block | other chapters |
| `/auditor deploy` | its seat + `.records/audit/` + the installation block | any chapter |
| `/foreman route`, `/debugger`, `/chiropractor` | nothing — read-only on unstamped roots; emit the `unstamped` fact, point at the onramps | any write |
| every other framework verb | nothing — routes to the onramps | any write |

Any self-init that writes also creates-or-adopts the deterministic installation block, so a bare
single-role install is a resolvable installation (self-init-no-floor holds). **`/foreman init`
is removed** — its old meaning (full setup) moved to clankshop, and foreman has no domain-init
of its own: its chapters exist only after bootstrap.

### 3.5 Versioning — pack, layout, and the lock

Three axes, recorded separately (the installation block gains `pack:` and `pack-version:` keys
beside `layout:`; the mechanics doc's block grammar is amended accordingly):

- **`pack:` + `pack-version:`** — which pack, at which release, assembled this installation. A
  pack release may change prose and verbs without touching the layout.
- **`layout:`** — the deployed format contract (the mechanics doc's frozen schemas). Bumped only
  by a migration.
- **The pack lock** — the release manifest: every **core member** (face + roles + instruments +
  pipelines — backlog and debugger pin like every other core member) pinned to the release; **helpers as dependencies with compatibility ranges** (a helper may be
  installed alone or shared by another pack, so it versions independently; the lock states what
  this release is known-good with). Install is **transactional against the lock**: preflight the
  member set, abort or roll back on collision — never a partial pack. `/clankshop check`
  compares the lock to the installed set as a fact.

Cross-skill references inside the **core** cannot rot (core members ship and version together);
the mechanics doc's Phase-0 "freeze" is simply the pack's versioned doctrine + schemas.

## 4. The roles and instruments

The role contract (revising the mechanics doc §2.4): a role **tends** its chapters and stores
(the documents are the project's; content never names the role), keeps genuinely
project-specific machinery in a **lazy seat** (`.agents/roles/<role>/` — created only when such
machinery exists), registers its routes in the front door, and is **removable without harm**
(the handbook stands alone; staleness is enumerated and `check`-flagged). What changes under the
pack: roles may reference clankshop, each other, and the deployed paths **directly** — the
expertise docs say `/backlog promote` and `.records/trackers/tasks.md`, not "the capture verb
the host provides."

### 4.1 architect — design

Unchanged in scope: tends `.handbook/design/` (the authored spec) and `.records/design/`
(accumulated design records, `draft/` staging included); design-altitude verbs (`init`,
`extract`, `brainstorm`, `plan`, `distill`, `reconcile`). No seat today; improvement items for
its chapters arrive from the calibrator (§4.7) as routed work.

### 4.2 foreman — operations

Slimmed to what a foreman actually is: **routes the work, keeps the rulebook.**

- **Routing:** `route` — the change classifier behind the door's compiled table; maintains
  `rules/ROUTING.md` (clankshop stamps the initial projection; foreman maintains it and
  recompiles on change), applying the promotion bar at dispatch and handing escalations to
  `/backlog promote`.
- **Chapters:** `rules/` (ROUTING, GOTCHAS, INVARIANTS, POLICY) + `workflows/`.
- **Records:** `logs/` (the routing/rulebook maintenance log).
- No seat today (machinery is pack-bundled). Improvement items targeting foreman's chapters
  arrive from the calibrator (§4.7) as routed work, like every other role's.

### 4.3 backlog — the records instrument (instrument tier)

**Captures signal, debriefs finished work, keeps the books.** Deliberately tool-like: backlog is
the mechanical face of the records system — its verbs record, list, and mutate entries with
minimal judgment, and the *judgment about what the signal means* belongs to the calibrator
(§4.7). It keeps its established name: a thing-name fits an instrument, and the live skill,
its route blocks, and every existing reference stay put — no rename anywhere in the migration.

- **Verbs:** the capture family (`task`/`bug`/`issue`/`note`/`feedback`), the escalation family
  (`ticket`/`promote`/`sync`/`close`), **`done <id>`** — the canonical completion operation: any
  consumer that finishes a tracker item calls it (or follows its by-hand walk), and it un-pauses/
  advances the entry and writes the done-log line — `debrief` (sweep a finished body of work to
  every store), and `curate` (dedupe/rank/sharpen/weed; ID stamping; aging resolved tickets).
  **The done-log writer map, stated once:** fast-path item finished → `backlog done`; ticket
  resolved/wontfix → `backlog close` (which writes the line itself); a calibrator-dispatched
  improvement lands → the calibrator confirms uptake and `backlog done` clears it; workstream
  `ship` → calls `backlog done` per shipped item *and* writes its own full done-record file; dropped at
  curation → `curate` logs the `dropped` outcome. The completion moment is **landed** (on the
  trunk), not merely gate-green.
- **Aliases as proxy skills — no vendor mechanisms.** The high-frequency verbs get tiny
  standalone proxy skills (`bug`, `task`), each a one-line SKILL.md that invokes the canonical
  `/backlog bug` / `/backlog task`. Being ordinary skills, they are portable across harnesses,
  listed in the pack lock as optional members, removable without trace, and covered by the
  routing probe. No `.claude/` or other harness-specific command surface is used anywhere in the
  pack; where a host lacks even skill invocation, the front door's table rows still route the
  natural-language intents.
- **Chapters:** `rules/RECORDS.md` — the deployed record-format reference (the stamped
  projection of the capture schema, whose canonical source is the clankshop doctrine, §7.6).
- **Records:** `trackers/`, `tickets/`, `done/` — the live queues, the escalation surface, and
  the completion ledger.
- The capture taxonomy, its classifiers, and the escalation layer (the mechanics doc §5) are the
  backlog's operating contract; the promotion bar is applied by foreman at dispatch and by any
  agent mid-work, and executed by `/backlog promote`.

### 4.4 guardian — verification

The verification expertise: **guards the gate, the pipeline, and what happens when they fail.**
A new role — the steward the verification domain never had.

- **Chapters:** `.handbook/testing/` — the gate definition, the CI/CD pipeline doc, and the
  diagnostics playbook (content that historically had no steward). Guardian *defines* the gate;
  every pipeline and agent *executes* it.
- **Judgment:** verification calls — is this failure a defect or a flaky gate, does this change
  need a deeper verification pass, is the diagnostics playbook missing a chapter for what just
  happened. Investigation lessons (from debugger runs, §4.8) feed the calibrator's intake;
  improvement items for its chapters arrive from the calibrator as routed work.
- **Records:** none of its own; no seat today. Investigations are written by whoever runs the
  debugger instrument (§4.8).
- **Scope honesty:** guardian is a genuinely new steward build (verb router, chapter authoring
  seeded from doctrine, verification judgment); splitting it from the debugger instrument keeps
  each artifact small and honest.

### 4.5 auditor — code quality

Unchanged in scope: the project-tailored rubric is the canonical **seat** (`.agents/roles/
auditor/`); findings and history accumulate in `.records/audit/`; audit verbs as today.

### 4.6 chiropractor — docs quality (repurposed)

Chiropractor **joins the pack as a role** and drops the any-repo genericity mandate —
a principled reversal: the genericity was the *price* of leaf-independence, not a goal, and its
costs (declaration-led indirection for every check, a portability gate to build, auditing a
system while pretending not to know it) purchased nothing the pack values. Repurposed, it is the
**docs auditor for this system**: it knows `.handbook/`, `.records/`, and the front door
directly. **The fact partition with clankshop check, exact — every fact has one verdict owner:**
chiropractor owns *document* facts — entry conformance to the declared shape, **within-scope ID
citation resolution** (a citation resolves per the doc's declaration), budget adherence, link
and path health, navigability, read-cost facts (`always_loaded_bytes`, depth, doc sizes), and
front-door affordance (the old Entry-Door Audit, now framework-aware). Clankshop check owns
*assembly* facts — chapter **presence** against the registry, producer/stamp fidelity,
projections, **cross-store foreign-key semantics** (a ticket's `origin:` names a real entry; a
done-log row's ID exists), mirror, seats, and the pack lock. The two may share one parser; they
never share a verdict. Findings land in `.records/reports/` (typed `type: doc-drift` — the
shared-store convention and wire contract, §4.8) and feed the calibrator's intake (§4.7). The seam with its siblings: **chiropractor audits the documents, auditor audits
the code, clankshop check audits the assembly.**

Two survivals from the genericity era, kept on their own merits: **declaration blocks stay** —
the handbook's self-description serves the cold clone and gives every checker a parse target
instead of a heuristic — and the **declaration-led pause** stays as the clean contract by which
any consumer (debugger foremost) skips escalated entries. The old hardcoded-path findings
against `spine-scan.sh` cease to be doctrine violations and become ordinary path updates in the
repurpose.

### 4.7 calibrator — the improvement loop

The role whose domain is **the system's own improvement** — it covers the full agent
experience, not one slice. It owns no handbook chapters (precedent: auditor) and never edits
another role's; it drives the loop that makes every chapter better:

- **Intake — one classifier, one pass, one table.** The intake table (Phase 0 freezes it) has
  one row per source: exact path/type, eligibility bar, stable source ID, claim encoding,
  dispatched artifact, receiving owner, uptake proof, terminal writeback. The sources:
  `.records/trackers/feedback.md` (the whole dev-experience channel, `F-` IDs);
  `.records/trackers/issues.md`, process-flavored entries only (about *how we work* — the rest
  stays work for `route`; `I-` IDs); **system-flavored `notes/`** (a captured durable trap or
  rule that belongs in GOTCHAS/INVARIANTS; `N-` IDs); and the quality findings — auditor's
  findings **that pass the system-improvement bar** (evidence the *framework* should change;
  ordinary code findings go back to `route` as project work), chiropractor's `doc-drift`
  reports, and `investigation` reports' lessons. Paused entries are always skipped; no other
  role scans these sources, so nothing is claimed twice or never cleared.
- **Non-tracker findings are materialized before dispatch.** A report is not a tracker entry
  and has no backlog ID — so every accepted quality finding is materialized as an ID'd backlog
  **improvement item** carrying `source: <report file / finding key>`. That item *is* the claim
  marker (a second calibrator pass sees it and skips the source) and the closure handle.
- **Dispatch as ordinary work.** Each improvement item routes to the owning role — a trap for
  foreman's GOTCHAS, a spec correction for architect, a diagnostics gap for guardian, a schema
  fix for backlog's projection, a rubric adjustment for auditor — applied by that role's own
  expertise (tend-don't-own stands). **The per-role `calibrate` verb family is dissolved**:
  improvement is routed work with a dedicated driver, not four parallel judgment verbs.
- **Uptake and closure.** The calibrator verifies the item landed (the receiving role's edit is
  in the chapter, check-green), then `backlog done <id> --outcome drained` appends the done-log
  line (the `drained` outcome the mechanics doc reserves) and stamps the source — the tracker
  entry advances, or the source report gains a `processed:` field. Its run log lands in
  `.records/logs/` (typed, beside foreman's).
- **Upstream contributions.** The calibrator owns §5's contribution path: it runs the three-way
  doctrine diff, assembles the evidence for a locally-proven rule, and prepares the patch a
  human reviews into doctrine vNext. It is the single driver of both stages of the
  self-improvement loop — project-level (signal → handbook) and pack-level (handbook →
  doctrine).
- **Boundary with backlog:** backlog keeps `curate` (list hygiene — dedupe, rank, sharpen, ID
  stamping — is the instrument's own upkeep); the calibrator judges what signal *means*, never
  how the lists are kept. No seat; no chapters; pure loop.

### 4.8 debugger — the diagnostic instrument (instrument tier)

The root-cause procedure, close to its live shape: **reproduce → trace → hypothesize → verify →
fix**, run by whoever hits the defect — a role mid-work, a pipeline, the human. Guided by
guardian's diagnostics playbook when one exists (`.handbook/testing/`); its findings write
`reports/` entries (typed `type: investigation` — the shared-store convention: each writer into
`reports/` owns a distinct `type:`, so investigations and chiropractor's doc-drift reports
coexist without collision — and the wire contract is frozen: a common report frontmatter floor
(`type`, `id`, `date`, `source`, optional `processed:`) plus disjoint filename namespaces,
`investigation-<date>-<slug>.md` and `doc-drift-<date>-<slug>.md`, so two writers can never
collide and the calibrator's closure protocol (§4.7) has a stable key). **`bugs/` is a report
store, never a work queue** (the settled store contract stands): the debugger accepts an explicitly routed bug report or a live symptom — it
never enumerates `bugs/` looking for work — and when the routed report's linked entry is paused,
it refuses and emits the pause fact (the declaration-led pause as clean internal contract). The
live skill's human-confirm-before-edit posture survives unchanged.

## 5. The doctrine model — policy as flowing content

Restating §3.1 as the system's content lifecycle:

```
clankshop doctrine (spine format, source-ID'd, versioned)
   │  setup/migrate: project through project facts (minimal seed, provenance recorded)
   ▼
project .handbook/ (project-shaped, project-owned)
   │  calibrator: local growth (improvement items → owning roles' chapter edits)
   │  calibrator: three-way diff against doctrine (facts, per the protocol below)
   ▼
upstream contribution (human-reviewed) → doctrine vNext
   │
   ▼  every other project's calibrator offers the update
```

**The projection protocol** (Phase 0 freezes it — without this, "mechanical diff" is a slogan):

- **Stable origin identity.** Every seedable doctrine entry carries an **origin ID** — its
  doctrine-side typed ID qualified by the doctrine's source ID (`clankshop:INV-4`) — stable
  across renames, edits, and doctrine versions (splits mint new IDs citing the parent).
- **Provenance encoding, per entry shape.** Seeded one-line entries (INV) append a trailing
  marker: `⟨clankshop:INV-4 @v3⟩`; heading-led entries (G/POL) carry `origin:`/`origin-version:`
  lines under the heading; seeded lane files carry both keys in their declaration block. The
  encoding is part of the wire formats `RECORDS.md`/the spine grammar already freeze.
- **Base-aware three-way diff.** The origin version pins the **base**: the exact upstream content
  the entry was seeded from (retrievable — the doctrine is versioned with the pack). Calibrate
  classifies each seeded entry as *unchanged / locally edited / upstream updated / both (conflict)
  / locally deleted / upstream retired* — all six as facts with an offer/apply gate; a locally
  deleted seed is never silently re-imposed, and divergence is a state, not an error.
- **Upstream contribution is a separate, human-reviewed act.** The calibrator may *prepare* a
  contribution (the entry, its evidence, a ready patch against the doctrine) — it never writes
  the upstream library. A human lands it in doctrine vNext through the pack's ordinary
  change process; only then do other projects see it as an *upstream updated* offer.

The role that tends a chapter is its projector and curator; **clankshop's doctrine is the
source; the handbook is the project's living copy** — provenance-carrying, never a blind mirror.
Fixture coverage (§8 Phase 5): local-only edit, upstream-only edit, both-sides conflict, local
deletion, upstream retirement, entry split, and a doctrine-source swap.

## 6. The front door as conductor — "what to do and when"

The requirement the pack must satisfy: an agent operating in a project knows what to do and when
because the front door tells it — workflows surface naturally, not because skills guess.
The chain, end to end:

1. `AGENTS.md` — the compiled routing table dispatches the common intents at tier 0 (rows →
   owning skill entry points; one shared fallback line → `rules/ROUTING.md`).
2. `rules/ROUTING.md` — the classification walk for the ambiguous case.
3. `workflows/<lane>.md` — the lane's seam glue names the *role moments*: "design decision at
   stake → work this as the architect (`/architect …`)", "defect → root-cause first
   (`/debugger`)", "human call needed → promote (`/backlog promote`)". Under the pack these are
   plain names — no indirection.
4. The role skill loads; the agent inherits the expertise; the handbook stays the source of
   project truth throughout.

Aliases serve muscle memory on the capture path via the proxy skills (§4.3: `/bug` is a
one-line skill invoking `/backlog bug`); the canonical forms keep the router unambiguous, and
no harness-specific command surface exists anywhere in the pack.

## 7. Deltas to the mechanics doc (`2026-08-04-agent-framework.md`)

The mechanics survive; ownership and composition re-map. The authoritative delta list:

1. **Ownership table**: backlog stays backlog — same name, new tier: the records instrument (capture, tickets, done log,
   `RECORDS.md` — same scope, new name and tier); chiropractor moves from "generic form auditor"
   to the docs-quality role; the **guardian** role is created for verification and
   `.handbook/testing/` joins the chapter registry under it; debugger slims to the diagnostic
   instrument; foreman slims to routing + `rules/` + `workflows/`.
2. **Bootstrap**: everywhere the mechanics doc says foreman `setup`/`migrate`, read **clankshop**
   `setup`/`migrate`; the whole-system `check` is clankshop's; foreman retains **`route` only**
   (improvement edits arrive via the calibrator, §4.7). The installation block is written by clankshop's onramps — and by an eligible
   member's bare *domain* self-init per the pre-stamp dispatch table (§3.4).
3. **§2.2 (audit seam) is superseded** by §4.6's three-way seam (documents / code / assembly)
   with the exact fact partition, and mechanics §13's genericity measures are retired with it.
   The "never names framework concepts" mandate, the portability grep gate, and declaration-*led*
   discovery as a genericity mechanism are retired; declarations themselves and the
   declaration-led pause remain (cold-clone self-description; debugger).
4. **§2.4 (role contract)** is revised per §4's opening: direct references legal inside the pack;
   the rest of the contract (tend don't own, lazy seats, removable without harm) stands.
5. **Typed edges / registration**: core members (face + roles + instruments + pipelines) drop typed-edge blocks and open-vocabulary
   matching; door registration blocks remain (they are deployment wiring, not independence
   machinery). Helpers keep the full discipline. The routing probe still runs over the pack's
   descriptions (aliases included) — it guards routing quality, not independence.
6. **Backlog's §9 — one exact authority chain for the record schema:** the **clankshop doctrine**
   carries the pack-versioned canonical record schema (the capture taxonomy, wire formats,
   escalation layer — absorbed from backlog's TAXONOMY.md); **backlog** is the sole
   schema-facing executor of the schema (the schema's standing judgments live in the doctrine); **`rules/RECORDS.md`** is the backlog-written stamped
   *project* projection of that schema; **foreman consumes** record signal and owns none of its
   formats or ticket machinery. One canonical source (doctrine), one steward (backlog), one
   projection (RECORDS.md) — nothing else states the schema.
7. **The calibrate grammar is superseded wholesale.** Every mechanics-doc reference to a
   per-role/steward `calibrate` (foreman's classify-and-dispatch shape, "the owning steward's
   calibrate," the per-layer drains, the foreman calibrate log) now means the single
   `/calibrator` loop of §4.7; `.records/logs/` holds the calibrator's and roles' typed run
   logs. `docs/design/2026-07-27-steward-grammar.md` is **superseded by this design** (its
   status line says so now, not at a future rollout step), and its live verb surfaces are in
   §8's checked manifest. Non-intake maintenance verbs survive under their roles (backlog
   `curate`, foreman's ROUTING recompile, auditor's rubric upkeep).
8. **Rollout (§11) is restructured** — see §8.

Everything else in the mechanics doc — the spine formats and grammar, tickets/mirror protocol,
ID contract, submodule model, stamped-only operation, format-agnostic migration, the cold-clone
guarantees and fixtures — stands as written.

## 8. Rollout — build the pack, then the projects

- **Phase 0 — the pack skeleton + the checked migration manifest.** Author the clankshop
  doctrine (spine format, seeded from the current BOOTSTRAP/clankshop content), the runbook, the
  frozen schemas (the mechanics doc's Phase-0 set + this doc's §3.4/§3.5/§5 protocols), and the
  pack lock (pack v1, layout 1 — separate axes). Build the **checked migration manifest** — a
  search-derived, item-checked inventory of the live surface this restructure touches, known
  today to include: the `packs/clankshop.md` manifest/`install.sh` seam (the installer consumes
  a machine-readable manifest — keep one, or update the installer first, before the runbook
  content moves); the live `backlog` surface (**no rename — the name stays**; the
  inventory covers *re-framing* edits only: route blocks, templates, and docs that describe
  backlog as the capture bureau update to the instrument contract);
  foreman's setup/migrate/check code and `foreman-health.sh` split (assembler checks → clankshop,
  route/ops maintenance stays); the **done-record template re-homed** from foreman to backlog
  (the `done/` steward); and the **skill-builder doctrine/gate split** — the portable authoring
  rules (sibling blindness, typed edges) keep applying to helpers and to skill-builder itself,
  while core members are exempted by an explicit, machine-readable membership rule (the pack
  lock is that rule) that the lint gate reads.
- **Phase 1 — clankshop the skill.** SKILL.md + thin verb router, doctrine assets, runbook,
  schemas, scripts, fixtures; `setup` / `migrate` / `check` against the doctrine; the projection
  machinery (§5); the installation block; transactional install against the lock; fixtures for
  both onramps.
- **Phase 2 — the roles.** Backlog re-framed as the records instrument (no rename;
  `done` verb added; proxy-skill aliases built and locked); foreman slimmed to routing +
  rulebook; the **calibrator built** (intake, improvement-item dispatch, uptake verification,
  upstream-contribution preparation); **guardian built** — honestly scoped as a new steward
  build (§4.4): verb router, testing chapter authored from doctrine, verification judgment;
  **debugger conformed** as the diagnostic instrument (§4.8: report schema, pause handling,
  playbook pointer — the discipline itself unchanged);
  architect and auditor conforming edits + re-framing onto the role contract; chiropractor
  repurpose (framework-aware checks; parser build; path updates; Entry-Door Audit retained).
  Routing probe across the pack's descriptions + proxy aliases; the vocabulary-table sweep (§2).
- **Phase 3 — pipelines + helpers conformance.** Feature/workstream path and seam updates
  (workstream `ship` calls `backlog done` per shipped item); delegate/mailbox/handoff untouched.
- **Phase 4 — retire the independence machinery** for core members: typed-edge blocks,
  `derive-seams`, the seam-table sections of the old runbook; `packs/clankshop.md` content
  absorbed into doctrine + runbook (manifest disposition per Phase 0); skill-builder's gate
  gains the core-member exemption; superseded design docs get status lines.
- **Phase 5 — fixture proof**, per the mechanics doc's matrix plus this doc's additions:
  greenfield, migration of arbitrary pre-existing projects, unstamped refusal + the §3.4
  pre-stamp table (bare single-role installs at default/custom roots), the doctrine three-way
  fixtures (§5: local edit / upstream edit / conflict / local deletion / retirement / split /
  source swap), pack-lock transactional install + collision abort, super-project cases, and the
  cold-clone acceptance fixture (unchanged: the *project* must stand alone even though the
  *skills* are now a pack).

## 9. Alternatives considered

- **Two-tier contract coupling** (shared versioned contract, independence machinery retained
  inside the pack) — rejected: keeps paying the boundary tax the reviews measured, for a
  partial-adoption property (auditor-only, trackers-only installs) judged not worth its cost.
- **Strict independence (status quo)** — rejected: same tax at full price; the framework skills
  already behave as one system in every design decision that matters.
- **A dedicated `handbook` container skill** — rejected: creates a second composer beside the
  pack's own bootstrap; the container contract is clankshop's doctrine + protocols, not a
  workload needing its own skill.
- **Folding testing/CI into foreman with debugger as helper** (this design's own first draft) —
  revised twice: first, debugger took the verification domain whole (rev 2–3); finally (rev 4)
  the domain went to the new **guardian** role and debugger settled as the diagnostic
  *instrument* — stewardship and procedure are different kinds of thing, and the split keeps
  both artifacts small.
- **A roles-only core** (rev 3's five-tier-less model) — superseded by the instruments tier:
  with two honest members (backlog, debugger) and a principled criterion (roles judge,
  instruments execute — the skill-level analog of facts-not-verdicts), the tier is a real
  category, not a symmetry cell.
- **Backlog merged into foreman** (the pack model's first draft) — revised during refinement:
  the merge's payoff was dissolving the promote/route/capture seams, but the pack made those
  seams free anyway; by cohesion, routing and record-keeping are different professions, so the
  capture bureau became a standalone core member again — ultimately the records instrument.
  (Names explored: scribe, registrar, chronicler,
  clerk, bookkeeper, tracker — before settling back on **backlog**: once the role slimmed to a
  records *instrument*, a thing-name fit honestly, the vocabulary tangle with "the trackers"/
  "issue tracker" vanished, and the migration sheds every rename disposition.)
- **Chiropractor stays generic** (the mechanics doc's rev-5 position) — rejected: genericity was
  the price of leaf-independence, purchasing nothing under the pack; repurposed as the
  docs-quality role it audits with full knowledge instead of pretended ignorance. Declarations
  survive on their own merits (self-description; the pause).
- **Renaming foreman → handbook** — rejected: misnames the router/operations majority of the
  role; container stewardship went to the pack instead.
- **Foreman owning the intake calibrate** (rev 2's model) — superseded: the improvement loop
  covers every domain, which is meta expertise, not operations; elevated to the **calibrator**
  role (§4.7), dissolving the four per-role calibrate verbs into routed improvement work.
- **Harness-native command aliases** (e.g. generated `.claude/commands/` files) — rejected: the
  pack uses no vendor-specific mechanisms; skills and docs are the whole surface. Aliases are
  ordinary proxy skills (§4.3), portable wherever skills are.

## 10. Measures

- The pack installs as one unit; `/clankshop setup` on a greenfield fixture yields a
  `check`-green installation with doctrine-provenance stamps on every seeded entry.
- The routing probe routes the pack's intents ("file a bug", "where do I start", "escalate to
  the human", "audit the docs", "audit the code", "calibrate the system", "set up the
  project") to the right skill,
  descriptions + aliases only.
- The doctrine diff: a project handbook edited locally shows exactly its divergence from
  doctrine as calibrate facts; an upstream promotion round-trips onto a second fixture project.
- The cold-clone acceptance fixture passes unchanged (the project stands alone; the pack is an
  accelerator).
- The three-way audit seam holds on fixtures: chiropractor (documents), auditor (code),
  clankshop check (assembly) — no overlapping verdicts, no uncovered surface.
