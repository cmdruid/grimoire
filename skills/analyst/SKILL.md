---
name: analyst
description: "Use when the user runs `/analyst`, asks to be briefed or caught up on a project, wants a status snapshot, a report on a subsystem or the project's health, or a guide introducing part of the codebase. Synthesizes the project's own records and git history into cited, readable prose. Reports state; renders no quality score. Keywords: brief me, catch me up, what happened, status report, health snapshot, walk me through."
---

# analyst — reports and briefings for the developer

A project accumulates a complete account of itself — a closure ledger, closed plans, debrief
reports, decisions, live trackers, commit history — and nobody reads it back. This skill does:
it gathers that account, curates it, and writes the developer a briefing with its sources cited.

**Reports state; never scores it.** No rubric, no grade, no verdict on quality. A finding of
"this is bad" is a different job — analyst says what *is*, and where the evidence sits.

## Surface

```
/analyst <token> [args]      # direct pick: briefing | status | subsystem | diagnostics | guide
/analyst <free text>         # classified against the catalog's use-when descriptors
```

Every report kind is a **template**, not a verb (`templates/`, deployed per *Catalog*). Adding a
kind is dropping in a file.

## Catalog

The live catalog is `<records-root>/templates/analyst/` when deployed, else this skill's bundled
`templates/`. **Deployed wins** — a project customizes its reports by editing the deployed copy,
and host-added templates join the catalog the same way.

Deploy is **lazy** and mechanical: run `scripts/analyst-deploy.sh <root>` on the first
workshop-host use. It copies only the bundled templates *absent* from the deployed directory and
**never overwrites** — a customized template is the project's, and an upgrade of one is a
judgment-assisted diff a human runs, never a silent replace. On a host with no records root it
deploys nothing and reports so; read the bundled templates in place. It refuses nothing.

Each template's front-matter carries `template:` (its token), `use-when:` (the routing
descriptor), and `inputs:` (the facts it needs). Its body carries the gathering and synthesis
instructions, then the output skeleton.

**Tier note (no self-init):** analyst owns a deployable template catalog — customizable assets,
not a project artifact store — so it has no `init` verb and no home to scaffold. Records it
persists live in the project's existing `reports/` store.

## Resolving the template

An explicit token wins. Otherwise match the free text against the catalog's `use-when:`
descriptors:

| case | do |
|---|---|
| one clear match | run it |
| two plausible matches | **ask** — never guess between kinds |
| nothing matches | say so and name the right home (a quality score → the host's audit tooling; *why* something broke → root-cause debugging; a general concept → plain conversation). No best-effort stretch. |
| catalog empty/unreadable | fall back to the bundled templates and say so |

This match is judgment, not a script: a target file's *kind* is mechanically detectable, a
question's *intent* is not. Keep it cheap and inline — never spend a dispatch on it.

## The engine

1. **Resolve the template** (above).
2. **Gather facts** — run `scripts/analyst-facts.sh` for the facts the template's `inputs:`
   names. It is read-only and prints `key=value` facts plus evidence; it never judges, and it
   **never runs the project's gate or test commands**. Gate state comes from what the project
   already recorded, or is reported unknown.
3. **Follow the links** — a ledger line is a closure *fact*; the substance is in the record it
   points at. Read what the facts point at, scaled to the template.
4. **Curate and synthesize** — select what this developer needs, group it, and translate
   record-speak into prose per the template's instructions and skeleton. **Cite sources**
   (record paths, `file:line`): a briefing must be checkable.
5. **Deliver** — in context by default; persist per *Persistence*.

Analyst is read-only toward the project. Its only writes are a persisted report and the lazy
template deploy. Delegation, when a span is large, follows the delegation front-door's own
doctrine — and never an editing sub-agent.

## Span anchor (`briefing`)

An explicit span wins ("since Monday", "since v0.3"). Absent one, anchor to the **last persisted
briefing** — `records.sh list --type reports --tag briefing`, newest first — else **14 calendar
days back from today**. Always name the anchor actually used in the output; there is no hidden
state file.

## Persistence

**Ephemeral by default.** Persist when the human asks — and **always when running headlessly**
(a scheduled tick has no surviving context, so the record is the whole point).

To persist: mint with `records.sh new reports --title "…"`, then fill the minted skeleton — body
**and** the `tags:` line, which must carry the template's token (`tags: [analyst, briefing]`).
The mint tool sets no tags; filling them is what lets the next briefing find this one as its
anchor. On a host with no records layer, write to the project's own docs home, confirmed once.

## Anti-patterns

- Scoring, grading, or ranking quality — that is an audit, not a briefing.
- Root-causing a failure you surfaced. Report the fact; the chase is a separate invocation.
- Writing tracker lines, closing records, or editing any project file other than a report.
- Uncited claims. Every assertion names where it came from.
- Overwriting a deployed template.
- Stretching a no-match ask into the nearest template.
- Explaining general concepts with no anchor in this project.

## Done when

The template was resolved (or the ask was routed elsewhere); facts were gathered from the
records layer and git, never from running the project's gates; the report follows its template's
skeleton with every claim cited; the anchor used is named; and the report was persisted only per
*Persistence*.

## Edges

<!-- edges:analyst -->
- produces: report — a briefing from the catalog, in context or persisted as a reports record tagged with its template token
- handoff: — (none; a report informs, it does not start a workflow)
- consumes: record, report — the records layer (ledger, stores, trackers) and git history; audit reports feed the health snapshot when present
<!-- /edges:analyst -->
