---
name: analyst
description: "Use when the user runs `/analyst`, asks to be briefed or caught up on a project, wants a status snapshot, a report on a subsystem or the project's health, a guide introducing part of the codebase, or to deploy a customizable report catalog. Synthesizes the project's own records and git history into cited, readable prose. Reports state; renders no quality score. Keywords: brief me, catch me up, what happened, status report, health snapshot, walk me through."
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
/analyst setup               # deploy the customizable catalog explicitly
/analyst migrate <path>      # upgrade owned reports or catalog templates
```

Every report kind is a **template**, not a verb (`templates/`, deployed per *Catalog*). Adding a
kind is dropping in a file.

## Catalog

The live catalog is `.spaces/analyst/templates/` when deployed, else this skill's bundled
`templates/`. **Deployed wins** — a project customizes its reports by editing the deployed copy,
and host-added templates join the catalog the same way.
The active bundled files are `briefing.md`, `status.md`, `subsystem.md`, `diagnostics.md`, and
`guide.md`; resolution reads the selected file during every report. No generic record shell is part
of the catalog.

`<root>` is `git rev-parse --show-toplevel` of the project being briefed. Non-git → ask.

Deploy is **explicit** and mechanical: `/analyst setup` runs
`scripts/analyst-deploy.sh <root>`. It copies only the bundled templates *absent* from the
deployed directory and **never overwrites** — a customized template is the project's, and
an upgrade of one is a judgment-assisted diff a human runs, never a silent replace. On a
host with no workspace home it creates only `analyst/templates/` beneath the declared home.
It refuses symlinked or non-directory parents before writing.
If a previous-home template exists while the canonical file is absent, setup refuses and names
`/analyst migrate <path>`; it never silently adopts a customization. A deployed template carrying
front-matter `schema:` is invalid because schemas stay in this package.
Standalone setup collects each `deployed=<file>` result and makes one pathspec-scoped commit over
the corresponding `.spaces/analyst/templates/<file>` paths; no deployed results means no
commit. Inside an announced configuration sweep, setup is write-only and the caller owns the one
aggregate commit.

Each template's front-matter carries `template:` (its token), `use-when:` (the routing
descriptor), and `inputs:` (the facts it needs). Its body carries the gathering and synthesis
instructions, then the output skeleton.

**Tier note (no self-init):** analyst owns a deployable template catalog — customizable assets,
not a project artifact store. Only explicit `setup` scaffolds its template home. Records it
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

1. **Resolve the template** (above). Read a deployed catalog when present; otherwise use the
   bundled catalog without creating project files. Only `/analyst setup` deploys templates.
2. **Gather facts** — run `scripts/analyst-facts.sh`; **each template's Gather section names its
   exact invocation** (every subcommand takes the project root as its first argument). It is
   read-only and prints `key=value` facts plus evidence; it never judges, and it **never runs the
   project's gate or test commands**. Gate state comes from what the project already recorded, or
   is reported unknown. If the script is missing or errors, say so and gather what you can by
   reading directly — degraded facts beat a stalled report.
   Status and briefing resolve `.trackers` independently and read only an advertised
   `tracker@2` provider through side-effect-free `describe`, `catalog`, and `page`. Missing provider
   state reports absent; legacy record-owned or owner-local tracker paths are never probed.
3. **Follow the links** — a ledger line is a closure *fact*; the substance is in the record it
   points at. Read what the facts point at, scaled to the template.
4. **Curate and synthesize** — select what this developer needs, group it, and translate
   record-speak into prose per the template's instructions and skeleton. **Cite sources**
   (record paths, `file:line`): a briefing must be checkable.
5. **Deliver** — in context by default; persist per *Persistence*.

Analyst is read-only toward the project during report generation. Its only writes are a report
persisted per *Persistence* and an explicitly requested catalog setup. Delegation, when a span is
large, follows the delegation front-door's own doctrine — and never an editing sub-agent.

## Span anchor (`briefing`)

An explicit span wins ("since Monday", "since v0.3"). Absent one, anchor to the **last persisted
briefing** — `.records/records.sh list --type reports --tag briefing` when that tool is executable,
newest first; else glob `.records/reports/YYYY-MM-DD-*.md` whose front-matter `tags`
contain `briefing`, newest filename first. If neither yields a hit, **14 calendar days back
from today**. Always name the anchor actually used in the output; there is no hidden state
file. The records tool is never a floor.

## Persistence

**Ephemeral by default.** Persist when the human asks — and **always when running headlessly**:
no human is present to read the output, so the record is the whole point. Treat the run as
headless when there is no interactive human in the loop to answer a question — a scheduled or
cron-fired tick, a non-interactive harness invocation, or any run whose output goes nowhere a
person will see it. When in doubt, persist: a spare record costs a line in a store, an
evaporated briefing costs the whole run.

To persist, use the resolved catalog template to author the report, then mint with
`.records/records.sh new reports --schema analyst/report@1 --title "…" --tag analyst --tag <token>`
when the tool exists (`<token>` is the resolved catalog token: `briefing`,
`status`, `subsystem`, `diagnostics`, or `guide`) and replace only the minted body with the authored
report; else file-mode with the same schema, naming the file `YYYY-MM-DD-<slug>.md` under
the fixed `.records/reports/` store (create it on
first write) and write `tags: [analyst, <token>]` yourself. **The in-package
contract:** front-matter keys `doctype`, `status`, `schema`, `tags`; schema
`analyst/report@1`; live `draft` / `published`; closed `archived` (ledger `--as` is
`done` / `dropped` / `superseded` / `consumed` when the tool exists).
File-mode close changes only status. Generic timestamps and revisions are not written. The filename
is `YYYY-MM-DD-<slug>.md`; links use `→ <store>/<file>.md`. Only a `briefing`-tagged report is a span anchor. On a host with no
records tool, file-mode still writes under fixed `.records`.

## Anti-patterns

- Scoring, grading, or ranking quality — that is an audit, not a briefing.
- Root-causing a failure you surfaced. Report the fact; the chase is a separate invocation.
- Writing tracker lines, closing records, or editing any project file other than a report.
- Uncited claims. Every assertion names where it came from.
- Overwriting a deployed template.
- Stretching a no-match ask into the nearest template.
- Explaining general concepts with no anchor in this project.

## Done when

For a report, the template was resolved (or the ask was routed elsewhere); facts were gathered from the
records layer and git, never from running the project's gates; the report follows its template's
skeleton with every claim cited; the anchor used is named; and the report was persisted only per
*Persistence*. For `setup`, every absent bundled template was deployed, every incumbent was left
untouched, and no namespace outside Analyst's template home was created.

## Project templates

- `briefing.md`
- `status.md`
- `subsystem.md`
- `diagnostics.md`
- `guide.md`

Schema identifiers and catalog-token validation are package-owned; project templates customize
authoring guidance only.

## Migration

For `/analyst migrate <source-path>`, read and follow `verbs/migrate.md`.

## Edges

<!-- edges:analyst -->
- produces: report — a catalog briefing, in context or persisted as a reports record tagged `analyst` plus the resolved template token
- handoff: — (none; a report informs, it does not start a workflow)
- consumes: record, report, tracker — the records layer (ledger and stores), the first-class tracker provider, and git history; audit reports feed the health snapshot when present
<!-- /edges:analyst -->
