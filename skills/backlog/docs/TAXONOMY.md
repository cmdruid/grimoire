# Document taxonomy -- the artifact types, their frontmatter format, and how to search them

The cross-cutting **document system** for `.agents/dev/`: what kinds of artifact exist, the unified
frontmatter every artifact-instance file carries, the boundary between instances (which carry it)
and system docs (which don't), and the `rg` recipes that let you query the whole doc set by
type/status. This is where you learn the system; `.agents/dev/templates/` is where you copy the shape from.

The format is **enforced** -- the host's doc-linter (surfaced in its `AGENTS.md`; wired at
`/foreman init`) walks every store dir and fails the gate on a file with missing or invalid
frontmatter. That total coverage is what makes the search recipes trustworthy: if some types were
ungated, `rg '^type:'` couldn't be trusted to find everything.

Linked from `.agents/dev/docs/PLANNING.md` and `.agents/dev/docs/DEVELOPMENT.md` (which point here rather than
re-describing the schema), and indexed in `.agents/dev/README.md`.

## The artifact taxonomy

Each artifact type is produced from a template and lives in one store dir. The type makes a doc
self-describing when moved, and lets tooling/audits filter the set.

| `type` | What it is for | Template | Instances live in |
|---|---|---|---|
| `design` | the *why* of a feature argued before the *how* (problem, approach, alternatives, mechanism) | `.agents/dev/templates/plan-design.md` | `.agents/dev/plans/` |
| `roadmap` | a track's spec: phase sequence + per-phase goal/scope/done-when, settled once | `.agents/dev/templates/roadmap.md` | `.agents/dev/plans/` |
| `implementation` | the task-by-task brief an implementer executes | `.agents/dev/templates/plan-implementation.md` | `.agents/dev/plans/` |
| `adr` | a Nygard record of a cross-cutting architecture decision | `.agents/dev/templates/adr.md` | `.agents/dev/adr/` |
| `bug` | a defect report (repro + expected/actual + evidence) | `.agents/dev/templates/bug-report.md` | `.agents/dev/bugs/` |
| `report` | a research investigation / deep dive someone would browse to | `.agents/dev/templates/report.md` | `.agents/dev/reports/` |
| `note` | long-form context backing a single index pointer (never browsed) | `.agents/dev/templates/note.md` | `.agents/dev/notes/` |
| `task-record` | an append-only record of completed work + commit refs | `.agents/dev/templates/task-record.md` | `.agents/dev/done/` |

A host may **extend** the type set for its own artifact kinds (a captured measurement log, a
release record): add the template, a store dir, a row here, and the linter rule -- one deliberate
edit per face, keeping all four in step.

## The frontmatter schema

One uniform block on every artifact-instance file, at the very top:

```yaml
---
type: design          # one value from the type set above
status: draft         # one value from the per-type set below
updated: 2026-06-21   # YYYY-MM-DD
related: [.agents/dev/adr/0001-example.md]   # optional; omit the key if empty
---
```

`status` is drawn from a **per-type closed set** -- a `type -> allowed-status` map, so each type's
lifecycle stays honest. **Living docs** (a real drain via `/foreman tune`) move through their set;
**record docs** (write-once) carry a single terminal value. This table is the same map the host's
doc-linter encodes -- the doc and the linter are the two faces of one source of truth; **keep them
identical.**

| `type` | `status` set | Lives in |
|---|---|---|
| `design` | `draft` -> `active` -> `shipped` / `superseded` | `.agents/dev/plans/` |
| `roadmap` | `draft` -> `active` -> `shipped` / `superseded` | `.agents/dev/plans/` |
| `implementation` | `draft` -> `active` -> `shipped` / `superseded` | `.agents/dev/plans/` |
| `adr` | `proposed` -> `accepted` -> `superseded` | `.agents/dev/adr/` |
| `bug` | `open` -> `fixed` / `wontfix` | `.agents/dev/bugs/` |
| `report` | `final` | `.agents/dev/reports/` |
| `note` | `evergreen` | `.agents/dev/notes/` |
| `task-record` | `shipped` | `.agents/dev/done/` |

Field rationale: `type` makes the doc self-describing and filterable; `status` feeds the `/foreman tune`
staleness + archival drains; `updated` is the staleness signal; `related` carries the ADR / roadmap /
back-link the system already requires. Deliberately absent: `title` (the H1 is the source of
truth), `description` (the doc's Goal/Problem section is), `tags` (no consumer).

The linter validates: a leading `---` ... `---` block; `type` present and legal for the dir;
`status` present and in that type's set; `updated` present and shaped `YYYY-MM-DD` (shape only, not
calendar-accurate -- it rejects placeholders and prose like `yesterday`). `related` is **not**
link-checked in this pass (its values are bare YAML paths, invisible to the markdown-link checker).

**ADR reconciliation:** frontmatter `status` is canonical for ADRs too. The ADR body keeps
`Deciders`, `Related`, and its prose, but drops any separate `Status:` / `Date:` bullet line (no two
sources of truth). "Superseded by NNNN" is expressed as `status: superseded` + that NNNN in `related`.

## The boundary -- what carries frontmatter, what doesn't

Gate *instances*, not *system docs*. An instance is produced from a template and has a lifecycle
worth querying; a system doc is a single living document; the aggregator trackers hold entries as
blocks inside one shared file, where per-file frontmatter can't sit.

| Carries frontmatter -- artifact-instance store dirs | Does NOT -- system docs / aggregators |
|---|---|
| `.agents/dev/plans/`, `.agents/dev/adr/`, `.agents/dev/bugs/`, `.agents/dev/notes/`, `.agents/dev/done/`, `.agents/dev/reports/` (+ any host-added store) | `.agents/dev/docs/*` doctrine (`PLANNING.md`, `DEVELOPMENT.md`, this file, ...), root meta (`AGENTS.md`, `README.md`), the aggregator trackers (`BACKLOG.md`, `ISSUES.md`, `FEEDBACK.md`, `MEMORY.md`), `.agents/dev/templates/*` (templates are not instances), and any `README.md` / `archive/` inside a store |

The linter encodes the gated-dir list **explicitly** (not "all of `.agents/dev/`"), so adding a new store dir
is a deliberate one-line edit. `.agents/dev/templates/feedback.md` is an entry-block (a `###` heading appended
into the shared `FEEDBACK.md`), not a standalone file -- it carries no frontmatter.

## Search / index recipes

The metadata is latent until you query it. The patterns:

```sh
# every active design (intersect two type/status greps)
rg -l '^type: design' .agents/dev/ | xargs rg -l '^status: active'

# archival candidates -- anything superseded
rg -l '^status: superseded' .agents/dev/

# all open bugs
rg -l '^status: open' .agents/dev/bugs/

# everything of one type, anywhere
rg -l '^type: roadmap' .agents/dev/

# recently-touched (sort by the updated date, newest last)
rg -l '^type: ' .agents/dev/ | xargs rg -H '^updated:' | sort -t: -k3
```

`updated` is a **soft** staleness signal: the linter checks its presence and shape, not its accuracy,
so treat a stale-looking date as a prompt to look, not as ground truth.

## Pointer

`.agents/dev/templates/` is where you copy the shape from when starting a new artifact; this doc is where you
learn the system that shape belongs to. Reach the format from either direction.
