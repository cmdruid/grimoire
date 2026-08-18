---
doctype: design
status: current
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# `analyst` — reports and briefings for the developer — Spec

**Shipped 2026-08-18** on `stream/feat` — subjects: `analyst: scaffold the skill engine and the
five-template catalog`; `analyst: add the facts harness and its prove-by-breaking fixture suite`;
`analyst: register in the pack manifest and library inventory`; `analyst: make the
never-overwrite deploy mechanical, sharpen template descriptors`; `analyst: fix template
invocations, wire deploy into the engine, define headless`; plus the two probe logs, the three
backlog captures, and `journal: skip code blocks when checking record links` (BL-20, a trunk-red
defect this stream's gate surfaced and fixed).

_Spec weight (grilled 2026-08-18; reviewed `needs-rework` and reworked same day — see Review
history). Building against this spec._

## Problem

The workshop's records layer is write-heavy and read-poor. A project accumulates a complete
account of its own history — the `history.tsv` closure ledger, closed plans, debrief reports,
ADRs, live trackers — but **no member synthesizes that account into cited, narrative,
developer-facing prose across a span**. Individual verbs report slices of state (`clankshop
check` lists findings, `workstream status` prints a cross-stream table, a `backlog debrief`
summarizes its own sweep), and auditor judges code against a rubric — but catching up ("what
happened here since I last looked?", "what's the state of subsystem X?", "how does this
project's auth flow work?") is still manual archaeology across stores, git log, and trackers.

## Goal

`/analyst` produces **developer-facing reports and briefings**, selected from a customizable
template catalog: a span catch-up, a status snapshot, a subsystem deep-dive, a project health
snapshot, a topic guide — synthesized from the records layer plus git history, curated and
translated into readable prose. The developer asks a question about their own project and gets
an argued answer with cited sources, not a pile of pointers.

## Approach

A **template-driven consumer** of the records layer + git, **read-only toward the project** —
its only writes are minting-and-filling a `reports/` record and the lazy template deploy. The
skill body is a thin engine; the report kinds live in a **template catalog** (the agent-council
briefs pattern, settled by the human 2026-08-18): each template is one file pairing a routing
descriptor, a gathering/synthesis procedure, and an output skeleton. Adding a report kind is
adding a template, not a verb.

**Alternatives rejected** (all settled 2026-08-18):

- **Journal verbs.** Journal is the format authority; all its verbs are substrate-side
  (setup/done/curate), and every consumer of the layer is deliberately a client — the Phase 6
  backlog split established exactly this boundary. Analyst's judgment (audience, salience,
  translation) is a different job, and folding it in would bloat the pack's one `required:`
  member with optional functionality.
- **A `records.sh report` subcommand.** Curation + translation need judgment, not templating.
- **Folding into auditor.** Different job: **auditor judges** (scores against a rubric, drains
  findings); **analyst synthesizes and informs** (renders no quality verdict). This line is
  load-bearing for routing (see *Boundaries*).
- **Verb-per-report-kind surface.** Rejected for the template catalog — a fixed verb set makes
  every new report kind a SKILL.md change; the catalog makes it a dropped-in file.
- **Release engineering scope** (changelogs, release notes, tags — the original `chronicler`
  sketch). Out of scope: those are *user*-facing maintained artifacts and a possible later
  skill; analyst's audience is the developer. (Name `chronicler` vetoed; `analyst` settled.)

## Mechanism

### Surface

```
/analyst <template-token> [args]     # direct pick: briefing | status | subsystem | diagnostics | guide
/analyst <free text>                 # classified inline against the catalog's descriptors
```

**Classification is inline judgment against deployed descriptors** (settled 2026-08-18 over a
dispatched classifier prompt): each template's front-matter carries a one-line `use-when:`
descriptor; the resident agent matches free text against the catalog and:

- **ambiguous between templates** → ask; never guess between two plausible kinds.
- **matches nothing** (an out-of-scope ask, e.g. a general-concept explainer or a quality
  verdict) → say so and name the right home (auditor, debugger, plain conversation) — no
  best-effort stretch.
- **catalog empty or unreadable** (deploy failed partway, host deleted files) → fall back to
  the bundled catalog and say so.

(Divergence from agent-council noted deliberately: council classifies a *target file's kind*,
which is mechanically detectable, so it uses a script; a free-text *question* is not, so
analyst's classifier is honest judgment, kept cheap and inline. Consequence: the classifier is
probe-tested, not unit-tested — see Verification.)

### Template catalog (v1)

One file per kind. Front-matter: `template:` (token), `use-when:` (routing descriptor),
`inputs:` (which stores/facts feed it). Body: gathering + synthesis instructions, then the
output skeleton (contract-conformant so a persisted copy drops into `reports/` unchanged).

| token | shape | inputs | line |
|---|---|---|---|
| `briefing` | span catch-up: shipped, changed, open/blocked since an anchor | ledger span + closed records + tracker deltas + commit summary | the flagship |
| `status` | now-snapshot: in-flight, open/blocked, tracker state | trackers + open records + active streams | no span |
| `subsystem` | deep-dive: state of a named module/domain | records + git + **code as grounding** | no quality verdict |
| `diagnostics` | **project health snapshot**: gate/test state, open bugs records, stale records, tracker debt | **auditor's artifacts when present** (its `reports/` audit records, `metrics.sh --check` output), else cheap derived facts | facts only — no rubric scoring (auditor's), no root-causing (debugger's); never runs a scored audit itself |
| `guide` | introduces a topic: a subsystem, the project itself, a convention it uses | records + docs + code as grounding | **project-anchored only** — general-concept tutoring is out of scope |

(Diagnostics = health-snapshot scope and guide = project-anchored both settled 2026-08-18;
diagnostics-consumes-auditor settled at review rework.)

### Deployment & customization

- **Lazy-deploy to `<records-root>/templates/analyst/`** on first workshop-host use (settled
  2026-08-18): the deployed copies are the live catalog, exposed so the project can customize
  them — tune a template's emphasis, sections, even its `use-when:` routing. **Deployed wins;
  bundled is the fallback.** Upgrades never overwrite a deployed copy (judgment-assisted diff,
  the handbook-seed rule).
- **Host-added templates** land in the same directory and enter the catalog scan — extensibility
  and customization are one mechanism.
- **Convention status (deferred seam, human 2026-08-18):** a skill-owned deployed template set
  is a **new convention** with no library precedent (journal's templates are flat doctype-mint
  files consumed by `records.sh new`; debugger bundles a body-shape template without deploying
  it). The generalized write-up — journal-contract subsection and/or a DOCTRINE.md pattern — is
  **deliberately deferred**; v1 documents the behavior **in analyst's own docs only** and
  touches nothing of journal's. Mechanically safe regardless: `records.sh` provably ignores
  `templates/` subdirectories (verified at review). Follow-up captured for the debrief sweep.
- **Standalone host** (no records root): read the bundled templates in place — no deploy, no
  refusal, per the pack's standalone rule.

### The engine (per invocation)

1. **Resolve the template** — explicit token, or inline classification vs the deployed catalog's
   descriptors (fallbacks above).
2. **Gather facts, token-free.** A bundled `scripts/analyst-facts.sh` (the `workstream-git.sh`
   pattern: read-only, `key=value` facts + evidence, never verdicts) computes the raw feed the
   template's `inputs:` names: ledger lines in span, closed/open record lists, tracker deltas,
   commit counts by area. It **reads** state; it never runs the project's gate/test commands —
   gate state comes from auditor's artifacts or the host's own recorded status, or is reported
   as unknown.
3. **Follow the links.** A ledger line is a closure fact; the substance lives in the record it
   points at (plan goal, debrief report, ADR). Read what the span's facts point at — scaled to
   the template (a status snapshot reads trackers; a guide reads the named domain's docs + code).
4. **Curate + synthesize — the judgment step.** Select what the developer needs, group it,
   translate record-speak into readable prose per the template's instructions, into its output
   skeleton. Claims cite their sources (record paths, `file:line`) — a briefing is checkable,
   not vibes.
5. **Deliver.** In context by default; persist per the policy below.

**Span anchor (`briefing`)** (settled 2026-08-18): an explicit span wins ("since Monday",
"since v0.3"); absent, anchor to the **last persisted briefing record** (located via
`records.sh list --type reports --tag briefing`, newest first) if one exists, else a stated
default window of **14 calendar days back from today**. No hidden state file — the anchor
actually used is always named in the output.

**Persistence** (settled 2026-08-18): **ephemeral by default, opt-in persist** — a report
persists when the human asks, and **always when run headlessly** (a scheduler tick has no
surviving context, so persisting is the point). To persist: mint via `records.sh new reports
--title "..."`, then **fill the minted skeleton — body and the `tags:` line** (adding the
template token, e.g. `tags: [analyst, briefing]`). `records.sh new` cannot set tags at mint
(`--title` only — a pre-existing journal gap, filed as a follow-up); filling the skeleton is
one write with the body it already implies, and it is what makes the span-anchor tag query
above actually match. Standalone host: the project's own docs home, confirmed once.

**Scale note:** v1 runs inline. Fan-out over a large span is permitted under `/delegate`'s own
doctrine (route confirmation, fallback ladder — nothing analyst-specific to build or test).
Analyst never uses an editing subagent.

### Boundaries (routing-critical)

- **auditor judges, analyst informs.** "How good is this code / score it" → auditor. "Report on
  / brief me on / what's the state of" → analyst. Analyst never scores against a rubric and
  never renders quality verdicts — including inside `diagnostics` (health *facts*, sourced from
  auditor's artifacts when present) and `subsystem` (state, not quality).
- **debugger root-causes.** `diagnostics` may *surface* "test X failing since Tuesday";
  chasing why is debugger's job, invoked separately — analyst stops at the fact.
- **backlog captures, analyst reads.** Analyst consumes trackers; it never writes tracker lines.
- **guide is project-anchored.** General-concept explainers ("explain OAuth") are out of scope.

### Pack registration

Two distinct edits in `skills/clankshop/PACK.md` (they are different mechanisms): add `analyst`
to the **`optional:` frontmatter list** (the machine surface `install.sh` reads — member-set
change ⇒ **minor version bump** per PACK.md's versioning rule), and add a **`helper`-tier row**
to the prose roster table (settled 2026-08-18: a records-layer client with real workshop seams,
standalone-degradable, alongside auditor/backlog). Plus the `README.md` inventory line.

### Edges (sketch for the build — coarse types before the em-dash, lint-parseable)

```
- produces: report — a briefing/report from the deployed catalog, in context or persisted as a reports/ record tagged with its template token
- handoff: — (none; a report informs, it doesn't start a workflow)
- consumes: record, report — the records layer (ledger, stores, trackers) read directly; auditor's audit reports feed `diagnostics` when present
```

## Verification

- **Fixture records tree, planted span** (the pack's fixture-harness pattern,
  `skills/clankshop/scripts/tests/`): a temp-dir records layer with known closures, open
  trackers, and a ledger. Per-template cases:
  - `briefing` over a planted anchor surfaces the planted closures AND the open/blocked items.
    **Anchor tiers:** one case with an explicit span; one where a planted tagged briefing
    record is the anchor; one with neither (the 14-day window fires and is named in output).
  - `status` reflects the planted tracker state with no span.
  - `subsystem` on a planted module cites records + code paths.
  - `diagnostics` with a planted auditor `reports/` record consumes it (the record's facts
    appear, attributed); with none, reports derived facts / unknown — and its output contains
    **no score/verdict language** (red-proof: a fixture variant planting verdict-bait — e.g. a
    rubric score in the auditor record — must NOT surface as analyst's own judgment).
  - `guide` on a planted project topic produces the intro shape; a general-concept ask
    (planted "explain OAuth"-style input) is refused to the right home (red-proof for
    project-anchored-only).
  - **Prove by breaking** throughout: remove a planted closure and confirm the assertion fails;
    portable ERE, no `\b`.
- **Persistence branches:** ephemeral run writes nothing to the fixture store (assert store
  unchanged); opt-in persist mints + fills (record exists, contract-conformant, `tags:` carries
  the token); headless invocation persists without being asked.
- **`analyst-facts.sh` proven by breaking** per grimoire gate doctrine.
- **Routing probe** (skill-builder's boundary-audit method — defined pass criterion: ambiguous
  prompts + expected target, fresh-agent check, mis-route fails): "brief me on the codebase" →
  analyst; "how good is this code" → auditor. **Classifier probe** (judgment-tested, not
  unit-tested — the honest cost of an inline classifier): sample free-text asks route to the
  right template token, to an ask (ambiguous), or to a named other home (zero-match).
- **Deploy semantics:** first workshop run deploys the catalog; a customized deployed template
  wins over the bundled copy (red-proof: plant a marker in the deployed copy, assert it is
  used); re-run never overwrites (red-proof: re-run after customizing, marker survives).
- **Standalone degrade:** a bare repo fixture (no records root) — analyst runs from git history
  + bundled templates, no deploy attempted (assert no `templates/` created), no refusal.
- **Lint gate:** `skills/skill-builder/scripts/skills-lint.sh` green over the new skill;
  `## Edges` block parses.

## Slices

_Stub — sequencing is the build's job; recorded here because the spec doubles as the small
feature's plan._

1. `skill-builder new` scaffold + SKILL.md engine (surface, classifier + fallbacks, engine
   steps, boundaries, persistence/anchor mechanics).
2. Template catalog ×5 (`templates/`), descriptors tuned for the classifier probe.
3. `scripts/analyst-facts.sh` + prove-by-breaking fixture.
4. Deploy/lazy-deploy mechanics + standalone degrade (documented analyst-side only — journal
   untouched per the deferred seam).
5. Fixture-harness verification tests (per-template, anchor tiers, persistence branches, deploy
   semantics red-proofs); routing + classifier probes logged.
6. `PACK.md` registration (two edits: `optional:` list + helper roster row; minor version bump)
   + `README.md` inventory line.

## Review history

**2026-08-18 — `/blueprint review`, 3-lens fan-out (skeptic / groundedness / soundness) +
ground-check: `needs-rework` → reworked same day.** Ground-check clean; groundedness verified
every repo claim. All six must-fixes folded: (1) tag-at-mint impossibility → fill-the-skeleton
mechanism + journal follow-up filed; (2) diagnostics now consumes auditor's artifacts, declared
in Edges; (3) Verification extended to every template, anchor tier, and persistence branch with
red-proofs; (4) Problem claim narrowed; (5) debugger boundary reworded off the typed-edge term;
(6) template-set convention named as new and **deferred by the human** — analyst-side docs only.
Nice-to-haves folded: classifier zero-match/empty-catalog fallbacks; depth dial cut to a scale
note; 14 calendar days; Edges sketch made lint-parseable; read-only claim scoped at first use;
pack registration split into its two real edits; classifier probe-not-unit-test cost stated.

## Decision log

All settled 2026-08-18 with the human (workstream `feat`, brainstorm → grill → review →
rework): name `analyst` (over chronicler/herald/gazette/publisher/envoy); developer audience,
releases out of scope; new skill over journal verbs; template-catalog architecture
(agent-council pattern); inline classifier vs deployed descriptors; v1 catalog of five
(briefing / status / subsystem / diagnostics=health-snapshot / guide=project-anchored);
lazy-deploy to `templates/analyst/` for per-project customization, deployed-wins; span anchor
last-briefing-else-14-days; ephemeral-with-opt-in persistence (headless always persists);
helper tier; diagnostics consumes auditor artifacts (review rework); template-set convention
write-up deferred (human) — analyst documents its own behavior, journal untouched; depth dial
cut to a v1 scale note.
