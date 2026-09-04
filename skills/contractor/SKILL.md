---
name: contractor
description: "Use when the user runs `/contractor`, asks to write or execute a roadmap, implementation plan, or runbook, or deploys Contractor's optional templates with `/contractor setup`. Sequence implementation work within the accepted scope and walk it. Never writes the design or ships to trunk. For a one-line patch, skip it."
---

# contractor — the job lead

Turn accepted scope into the smallest useful implementation sequence, then walk
that sequence when asked. Never redesign the work, enlarge it, or ship it to
trunk.

This `SKILL.md` is a thin router. Read the selected file in `verbs/` and follow
it. The skill is self-contained and uniquely named: it depends on no other
skill and collides with none.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does |
|---|---|---|
| `roadmap` | `verbs/roadmap.md` | durable multi-phase map |
| `plan` | `verbs/plan.md` | proportionate implementation plan |
| `runbook` | `verbs/runbook.md` | durable execution conductor |
| `build` | `verbs/build.md` | execute an accepted plan or runbook |
| `setup [<root>]` | `verbs/setup.md` | deploy active project templates absent-only |
| `migrate <source-path>` | `verbs/migrate.md` | preview and upgrade owned plans/templates, including in place |
| (bare) | — | **ask** which verb; do not default |

## Scope firewall

Establish the boundary from the most direct available authority: a clear user
request, an accepted draft, a published spec, or a named phase. Capture only:

- the requested outcome and affected surface;
- explicit non-goals and constraints;
- acceptance evidence needed to know the requested work is done.

Do not add adjacent cleanup, refactors, abstractions, documentation, tooling,
deployment work, or follow-up systems merely because they might be useful. A
discovery enters the current job only when direct causal evidence shows the
requested outcome cannot work without it. Otherwise report a concrete,
independent issue as a follow-up and omit speculative concerns. Expanding the
accepted outcome requires an explicit user decision.

An unresolved choice blocks only when it materially changes implementation,
safety, or acceptance. Ask that question plainly; do not manufacture a new
design process.

## Operating levels

**Default — lightweight.** For bounded work, plan in the conversation unless
the user asks for a file. An atomic plan is preferred. Inspect only the code and
claims needed to make it executable, verify in proportion to the change, and
use the user's original request as authorization for everything it explicitly
includes.

**Formal — durable.** Use records, stages, explicit gates, and optional
independent review only when the user requests a roadmap, runbook, durable
plan, or formal review, or when the work itself crosses a concrete high-risk
boundary: an irreversible production data operation, a security/permission or
custody boundary, or a public compatibility migration. Say which trigger
applies. Formal handling adds evidence and recovery controls; it does not add
scope.

Do not escalate merely because work spans several files, has tests, is
unfamiliar, or would benefit from extra polish.

## Durable record contract

This section applies only when the formal level is selected. Durable roadmap,
plan, and runbook artifacts land in `.records/plans/`, with exactly one writer
tag: `roadmap`, `plan`, or `runbook`.

Resolve project scaffolds at `.agents/skilldata/contractor/templates/` when
present; otherwise read the bundled scaffold without a project write. Only
`/contractor setup` deploys fresh project copies. A recognized legacy template
requires `/contractor migrate <path>`.

The former generic `plans.md` shell is retired.

Create `.records/plans/` if missing, but no provider, history, or sibling store.
If `.records/records.sh` is executable, mint with `new plans --schema
contractor/<kind>@1 --template <resolved>` for plans and roadmaps (omit
`--template` for a compiled runbook). Without the tool, create the same
four-key record profile directly. Current records require `doctype`, `status`,
`schema`, and `tags`; schemas are `contractor/plan@1`,
`contractor/roadmap@1`, and `contractor/runbook@1`. Name files
`YYYY-MM-DD-<slug>.md`; links use `→ <store>/<file>.md`.

Mint stays `draft`. In a formal workflow, the caller may record acceptance as
`published` and `stage: approved`; after a successful formal walk, Contractor
may set `stage: implemented` while status stays `published`. Closed is
`archived`; metadata records approval; it does not create it. Never require a
metadata write to honor explicit authorization given in the current
conversation. Never hand-write `history.tsv`; ordinary edits add no generic
date or revision metadata.

## Shared discipline

- Read the selected verb file; do not reconstruct it from this router.
- Load the host's applicable instructions before planning or building.
- `scripts/ground-check.sh` is this package's optional reference checker. Run
  it only when a source document contains file or line references whose
  validity matters. It proves that a reference resolves, not that its prose is
  correct.
- Delegation is optional and never a default ceremony. Use it only when a
  genuinely separable unit benefits from it.
- Never ship to trunk. Landing is outside this skill.
- Run project-specific closure routines only when the host requires them or the
  selected formal workflow names them.

## Approval economy

If the user asks only for a plan, present or write it and stop. If the same
request asks to plan and build, proceed unless a material unresolved decision
remains. If the user later says to build an accepted plan, that explicit user
authorization is sufficient. Do not ask them to repeat approval or edit
metadata merely to unlock work.

## Structure, portability

- A self-contained skill directory: `SKILL.md`, `templates/plan.md`,
  `templates/roadmap.md`, the verb files, and `scripts/ground-check.sh`.
- Portable: no workshop dependency and no host paths baked in.

## Project templates

- `plan.md`
- `roadmap.md`

## Edges

<!-- edges:contractor -->
- produces: plan, roadmap, runbook — job artifacts when durable output is requested
- handoff: — (build executes in-place; ship is not this skill)
- consumes: spec, plan, runbook — accepted scope or a job artifact this skill walks
<!-- /edges:contractor -->

## Done when

- **Bare `/contractor`:** ask which verb; do not default.
- **A named verb ran:** satisfy that verb's closing condition without invoking
  another verb automatically.
