---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# `analyst` — reports and briefings for the developer — Spec

_Spec weight (grilled 2026-08-18; all open branches resolved with the human). Awaiting the
user-review gate._

## Problem

The workshop's records layer is write-heavy and read-poor. A project accumulates a complete
account of its own history — the `history.tsv` closure ledger, closed plans, debrief reports,
ADRs, live trackers — but **nothing synthesizes that account for the developer**. Catching up
("what happened here since I last looked?", "what's the state of subsystem X?", "how does this
project's auth flow work?") is manual archaeology across stores, git log, and trackers. Every
existing pack member either writes the record (journal, backlog, workstream debriefs) or judges
the code (auditor); no member reads the record back and *informs*.

## Goal

`/analyst` produces **developer-facing reports and briefings**, selected from a customizable
template catalog: a span catch-up, a status snapshot, a subsystem deep-dive, a project health
snapshot, a topic guide — synthesized from the records layer plus git history, curated and
translated into readable prose. The developer asks a question about their own project and gets
an argued answer, not a pile of pointers.

## Approach

A **read-only, template-driven consumer** of the records layer + git. The skill body is a thin
engine; the report kinds live in a **template catalog** (the agent-council briefs pattern,
settled by the human 2026-08-18): each template is one file pairing a routing descriptor, a
gathering/synthesis procedure, and an output skeleton. Adding a report kind is adding a
template, not a verb.

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
descriptor; the resident agent matches free text against the catalog and **asks when ambiguous**
— never guesses between two plausible templates. (Divergence from agent-council noted
deliberately: council classifies a *target file's kind*, which is mechanically detectable, so it
uses a script; a free-text *question* is not mechanically classifiable, so analyst's classifier
is honest judgment, kept cheap and inline.)

### Template catalog (v1)

One file per kind. Front-matter: `template:` (token), `use-when:` (routing descriptor),
`inputs:` (which stores/facts feed it). Body: gathering + synthesis instructions, then the
output skeleton (contract-conformant so a persisted copy drops into `reports/` unchanged).

| token | shape | inputs | line |
|---|---|---|---|
| `briefing` | span catch-up: shipped, changed, open/blocked since an anchor | ledger span + closed records + tracker deltas + commit summary | the flagship |
| `status` | now-snapshot: in-flight, open/blocked, tracker state | trackers + open records + active streams | no span |
| `subsystem` | deep-dive: state of a named module/domain | records + git + **code as grounding** | no quality verdict |
| `diagnostics` | **project health snapshot**: build/test/gate state, open bugs records, stale records, tracker debt | mechanical health facts | facts only — no rubric scoring (auditor's), no root-causing (debugger's) |
| `guide` | introduces a topic: a subsystem, the project itself, a convention it uses | records + docs + code as grounding | **project-anchored only** — general-concept tutoring is out of scope |

(Diagnostics = health-snapshot scope and guide = project-anchored both settled 2026-08-18.)

### Deployment & customization

- **Lazy-deploy to `<records-root>/templates/analyst/`** on first workshop-host use (settled
  2026-08-18): the deployed copies are the live catalog, exposed so the project can customize
  them — tune a template's emphasis, sections, even its `use-when:` routing. **Deployed wins;
  bundled is the fallback.** Upgrades never overwrite a deployed copy (judgment-assisted diff,
  the handbook-seed rule).
- **Host-added templates** land in the same directory and enter the catalog scan — extensibility
  and customization are one mechanism.
- **Journal seam:** `templates/` in the records root is journal's territory as format authority.
  This spec extends the convention: *a skill may own a namespaced template set under
  `templates/<skill>/`*. The build must check journal's contract wording doesn't contradict this
  and add the one-line extension where the convention is documented.
- **Standalone host** (no records root): read the bundled templates in place — no deploy, no
  refusal, per the pack's standalone rule.

### The engine (per invocation)

1. **Resolve the template** — explicit token, or inline classification vs the deployed catalog's
   descriptors; ambiguous → ask.
2. **Gather facts, token-free.** A bundled `scripts/analyst-facts.sh` (the `workstream-git.sh`
   pattern: read-only, `key=value` facts + evidence, never verdicts) computes the raw feed the
   template's `inputs:` names: ledger lines in span, closed/open record lists, tracker deltas,
   commit counts by area, gate/test status where cheaply obtainable.
3. **Follow the links.** A ledger line is a closure fact; the substance lives in the record it
   points at (plan goal, debrief report, ADR). Read what the span's facts point at — scaled to
   the template (a status snapshot reads trackers; a guide reads the named domain's docs + code).
4. **Curate + synthesize — the judgment step.** Select what the developer needs, group it,
   translate record-speak into readable prose per the template's instructions, into its output
   skeleton. Claims cite their sources (record paths, `file:line`) — a briefing is checkable,
   not vibes.
5. **Deliver.** In context by default; persist per the policy below.

**Span anchor (`briefing`)** (settled 2026-08-18): an explicit span wins ("since Monday",
"since v0.3"); absent, anchor to the **last persisted briefing record** if one exists, else a
stated **default window (~14 days)**. No hidden state file — the anchor actually used is always
named in the output.

**Persistence** (settled 2026-08-18): **ephemeral by default, opt-in persist** — a report lands
in `reports/` (minted via `records.sh new reports`, tagged with its template token) when the
human asks, and **always when run headlessly** (a scheduler tick has no surviving context, so
persisting is the point). Standalone host: the project's own docs home, confirmed once.

**Depth dial:** default inline. For a large span or a broad subsystem, fan out read-only readers
per the session's confirmed delegation route (facts stay single-location; readers return bounded
summaries). Never an editing subagent — analyst is read-only except for minting a `reports/`
record and the lazy template deploy.

### Boundaries (routing-critical)

- **auditor judges, analyst informs.** "How good is this code / score it" → auditor. "Report on
  / brief me on / what's the state of" → analyst. Analyst never scores against a rubric and
  never renders quality verdicts — including inside `diagnostics` (health *facts*) and
  `subsystem` (state, not quality).
- **debugger root-causes.** `diagnostics` may *surface* "test X failing since Tuesday"; chasing
  why is a hand-off to debugger.
- **backlog captures, analyst reads.** Analyst consumes trackers; it never writes tracker lines.
- **guide is project-anchored.** General-concept explainers ("explain OAuth") are out of scope.

### Pack registration

**Helper tier** in `skills/clankshop/PACK.md` `optional:` (settled 2026-08-18) — a records-layer
client with real workshop seams, standalone-degradable, alongside auditor/backlog. Manifest
member-set change ⇒ minor version bump per PACK.md's versioning rule.

### Edges (sketch for the build)

- produces: report — a briefing/report, in context or as a `reports/` record tagged by template
- handoff: — (none; a report informs, it doesn't start a workflow)
- consumes: records layer (ledger, stores, trackers) + git history; template catalog (own)

## Verification

- **Fixture records tree, planted span** (the pack's fixture-harness pattern,
  `skills/clankshop/scripts/tests/`): a temp-dir records layer with known closures, open
  trackers, and a ledger; `briefing` over a planted anchor must surface the planted closures AND
  the open/blocked items; `status` must reflect the tracker state. **Prove by breaking**: remove
  a planted closure from the fixture and confirm the check that asserts its presence fails.
- **`analyst-facts.sh` proven by breaking** per grimoire gate doctrine (no check trusted until
  it FAILs on deliberately-broken input; portable ERE — no `\b`).
- **Routing probe** (skill-builder's boundary-audit discipline): description probes for
  "brief me on the codebase" → analyst, "how good is this code" → auditor; plus a
  classifier probe — sample free-text asks route to the right template token or to an ask.
- **Standalone degrade**: a bare repo fixture (no records root) — analyst runs from git history
  + bundled templates, no deploy attempted, no refusal.
- **Deploy semantics**: first workshop run deploys the catalog; a customized deployed template
  wins over the bundled copy; re-run never overwrites.
- **Lint gate**: `skills/skill-builder/scripts/skills-lint.sh` green over the new skill;
  `## Edges` block parses.

## Slices

_Stub — sequencing is the build's job; recorded here because the spec doubles as the small
feature's plan._

1. `skill-builder new` scaffold + SKILL.md engine (surface, classifier, engine steps, boundaries).
2. Template catalog ×5 (`templates/`), descriptors tuned for the classifier probe.
3. `scripts/analyst-facts.sh` + prove-by-breaking fixture.
4. Deploy/lazy-deploy mechanics + standalone degrade; journal convention seam note.
5. Fixture-harness verification tests; routing + classifier probes logged.
6. `PACK.md` registration (helper, version bump) + `README.md` inventory line.

## Review history

**2026-08-18 — `/blueprint review`, 3-lens fan-out (skeptic / groundedness / soundness) + ground-check: `needs-rework`.**
Ground-check clean (3/3 refs resolve); groundedness clean (every repo claim verified). Must-fix
findings, merged and ranked (owner prunes on resolution):

1. **Persistence/anchor mechanism doesn't exist as described** (soundness; verified against
   `records.sh`): `new` takes only `--title` — nothing can tag a minted record, so "tagged with
   its template token" is unachievable as written and the last-persisted-briefing anchor lookup
   (`list --tag`) can never match. Resolve: analyst fills the minted skeleton (body **and**
   `tags:` line) — the same write minting already implies; file records.sh's no-tag-at-mint gap
   as a journal backlog item.
2. **`diagnostics`/auditor hole** (skeptic): auditor already computes gate state
   (`metrics.sh --check`) and positions audit `reports/` records as the health-trend history.
   Spec must state whether `diagnostics` re-derives or consumes auditor's artifacts, and declare
   it in Edges.
3. **Verification coverage gaps** (soundness): `subsystem`/`diagnostics`/`guide` have zero named
   coverage (including the guard-style "no verdicts"/"project-anchored only" claims); the two
   span-anchor fallback tiers and all three persistence branches are untested.
4. **Problem claim overstated** (skeptic): `clankshop check`, `workstream status`,
   `backlog debrief` all read-state-and-inform; narrow the claim to "no member synthesizes the
   records layer into cited, narrative, cross-span prose."
5. **"Hand-off to debugger" collides with typed-edge vocabulary** (soundness): Boundaries says
   hand-off; Edges declares `handoff: —`. Reword Boundaries to avoid the load-bearing term.
6. **Journal-contract extension is a real new convention, punted to build** (soundness +
   skeptic): flat doctype-mint templates vs a deployed multi-file catalog are different animals
   (debugger's bundled `investigation.md` is quietly a third variant); needs a real contract
   subsection settled now, not a one-line note at build.

Nice-to-have (fold selectively): classifier zero-match/empty-catalog fallbacks; depth dial
underspecified (cut or pin); "~14 days" imprecise; Edges `consumes:` line not lint-parseable as
written; "read-only" headline qualified late; helper-tier = roster-table label + `optional:`
list (two edits); inline classifier has no deterministic test (probe only).

## Decision log

All settled 2026-08-18 with the human (workstream `feat`, brainstorm → grill): name `analyst`
(over chronicler/herald/gazette/publisher/envoy); developer audience, releases out of scope;
new skill over journal verbs; template-catalog architecture (agent-council pattern); inline
classifier vs deployed descriptors; v1 catalog of five (briefing / status / subsystem /
diagnostics=health-snapshot / guide=project-anchored); lazy-deploy to
`templates/analyst/` for per-project customization, deployed-wins; span anchor last-briefing-
else-window; ephemeral-with-opt-in persistence (headless always persists); helper tier.
