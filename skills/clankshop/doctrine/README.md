# The clankshop doctrine — index

<!-- spine-index v1
doctrine: clankshop
doctrine-version: 1
docs: rules/ROUTING.md rules/GOTCHAS.md rules/INVARIANTS.md rules/POLICY.md rules/RECORDS.md workflows/patch.md workflows/bug.md workflows/feature.md workflows/spike.md testing/GATE.md testing/PIPELINE.md testing/DIAGNOSTICS.md
-->

The pack's seed content: what `setup` and `migrate` project — through a project's facts — into its
`.handbook/`. Every member doc is a spine doc (declaration block first); the doctrine's source ID
is `clankshop` and this version is **1**. Whole-file assets are stamped at projection with a
path-qualified origin (`clankshop:workflows/<lane>`, `clankshop:testing/<DOC>`) and the doctrine
version they were seeded from (versioning note below). This index is the parse anchor — the
spine-index block, not naming convention, is what discovery keys on.

## Chapter registry

The deployed handbook has exactly these four chapters:

| chapter | holds | tended by |
|---|---|---|
| `rules/` | ROUTING (the classification walk), GOTCHAS, INVARIANTS, POLICY — plus RECORDS, the records instrument's stamped projection of the record schema | the operations role (RECORDS: the records instrument) |
| `workflows/` | one complete lane per file — nothing else | the operations role |
| `design/` | the authored design spec (project brief, system specs) | the design role |
| `testing/` | the gate definition, the CI/CD pipeline doc, the diagnostics playbook | the verification role |

**Adding a chapter** (the protocol, per the stewardship-map contract): a role that earns a new
top-level `.handbook/` chapter adds its **stewardship-map row** — its own delimited steward block
in `.handbook/README.md`, stamped against its input — and the chapter joins the deployed registry
through that block. A top-level `.handbook/` entry with no steward block is an unknown-entry fact
at `check`. The doctrine's registry (this table) names the pack's seed chapters; it grows only
with a doctrine version bump.

## The team roster

| tier | member | is | manages / does |
|---|---|---|---|
| **pack** | `clankshop` | the pack's executable face | doctrine + runbook; `setup` / `migrate` / system `check` |
| **role** | `architect` | design expertise | `.handbook/design/` + `.records/design/` |
| **role** | `foreman` | operations expertise | `route`; `.handbook/rules/` + `workflows/`; `.records/logs/` |
| **role** | `guardian` | verification expertise | `.handbook/testing/` (gate, CI/CD, diagnostics playbook); verification judgment |
| **role** | `auditor` | code-quality expertise | rubric (seat) + `.records/audit/` |
| **role** | `chiropractor` | docs-quality expertise | audits `.handbook/` + `.records/` + the front door |
| **role** | `calibrator` | the improvement loop | intake over trackers + quality findings; dispatches improvement items; upstream contributions |
| **instrument** | `backlog` | the records instrument | capture + debrief + `done` + curate + tickets/escalation; `.handbook/rules/RECORDS.md`; `.records/trackers|tickets|done` |
| **instrument** | `debugger` | the diagnostic instrument | the root-cause procedure; guided by the diagnostics playbook |
| **pipeline** | `feature` | brainstorm → build | planning artifacts → `.records/plans|adr` |
| **pipeline** | `workstream` | shipping lanes | parallel work units; ships done-records |
| **helper** | `delegate` / `mailbox` / `handoff` | plumbing | dispatch, transport, session continuity; portable |

## The door profile

What `setup` compiles into the front door's tier-0 routing table, and the single source every
door-registration writer copies from. The compiled table is a stamped projection of the deployed
`.handbook/rules/ROUTING.md` — rows dispatch to owning entry points, and the door carries **one
shared fallback line** beneath the table (the two-read skill-less chain):

> No skill runner? Follow `.handbook/rules/ROUTING.md` by hand.

**Row seeds** (setup keeps only rows whose owner is installed; the lane-path column stays in
ROUTING's dispatch rows, never duplicated into the door):

| you're about to… | go |
|---|---|
| fix a reproducible bug | `/debugger` (file it first: `/backlog bug`) |
| land a one-line patch | `<trunk>`, no ceremony — the patch lane |
| run a timeboxed spike | by hand, timeboxed — the spike lane |
| build a feature | `/feature` |
| capture a follow-up | `/backlog` (aliases: `/bug`, `/task`) |
| escalate to the human | `/backlog promote` |
| a design decision at seed altitude | `/architect` |
| harden the gate / CI / the diagnostics playbook | `/guardian` |
| audit the code | `/auditor` |
| audit the docs | `/chiropractor` |
| calibrate the system | `/calibrator` |
| set up / migrate / check the system | `/clankshop` |
| unsure / mixed altitude | `/foreman` |

### Registration block bodies (frozen — the door-block protocol's single source)

Every core member's door registration block is written **from the body below, verbatim** — by
`setup` at bootstrap and by a member's own domain self-init on a bare install — between that
member's standard delimiters, stamped `built-against:clankshop@<pack-version>`. Core bodies carry
**no `Edges:` lines**. (Helpers register under their own independence protocol and are not listed
here; an optional proxy registers only when installed.)

```markdown
### /clankshop — the pack face
Route: stand up (`setup`), onboard (`migrate`), or validate (`check`) this installation; the
pack's doctrine and runbook home.
```

```markdown
### /foreman — route a change
Route: classify a bug / patch / feature / spike and dispatch it to its lane; keeps the rulebook
(`.handbook/rules/` + `.handbook/workflows/`).
```

```markdown
### /architect — design expertise
Route: foundational design work at seed altitude; tends `.handbook/design/` and
`.records/design/`.
```

```markdown
### /guardian — verification expertise
Route: harden the gate, the CI/CD pipeline, and the diagnostics playbook; tends
`.handbook/testing/`; judges defect-vs-flaky and verification depth.
```

```markdown
### /auditor — code quality
Route: rubric-driven code-quality audits; findings and history in `.records/audit/`.
```

```markdown
### /chiropractor — docs quality
Route: audit `.handbook/`, `.records/`, and the front door for conformance, resolution, budgets,
and navigability; findings to `.records/reports/`.
```

```markdown
### /calibrator — the improvement loop
Route: drain captured signal and quality findings into system improvements — intake, dispatch to
the owning role, verify uptake, close; prepares upstream doctrine contributions.
```

```markdown
### /backlog — the records instrument
Route: capture by kind (task / bug / issue / note / feedback), escalate via tickets, complete via
`done`, curate the stores, debrief finished work.
```

```markdown
### /debugger — the diagnostic instrument
Route: root-cause a reproducible defect before any fix — reproduce, trace, hypothesize, verify;
findings to `.records/reports/`.
```

```markdown
### /feature — the planning pipeline
Route: brainstorm → design → plan → build a feature to gate-green; planning artifacts to
`.records/plans/` and `.records/adr/`.
```

```markdown
### /workstream — shipping lanes
Route: drive a long-lived stream of work units; lands, ships, and writes done-records to
`.records/done/`.
```

```markdown
### /bug — capture alias
Route: file a bug (proxy for the records instrument's bug capture).
```

```markdown
### /task — capture alias
Route: file a task (proxy for the records instrument's task capture).
```

## Versioning

`doctrine-version:` is one integer for the whole doctrine, carried in every declaration block;
bump it (everywhere, in one commit) whenever seeded content changes. Downstream, a deployed file
whose `origin-version:` — or RECORDS' `built-against:` stamp — is behind the current version was
seeded from older content; reconciling it is the improvement loop's judgment call (the
calibrator's doctrine seam): read the two bodies side by side, offer the differences, respect
local divergence — the operating agent is the differ.
