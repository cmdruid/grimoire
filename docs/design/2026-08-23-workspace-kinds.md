---
doctype: specs
status: published
created: 2026-08-23
updated: 2026-08-24
tags: [spec]
---

# Workspace skill namespaces — `<skill>/<kind>` — Spec

This library's design home is `docs/design/` (patient-zero). This spec
lives here. It doubles as the implementation plan.

Dependency (land first):
`docs/design/2026-08-24-grimoire-faceless-pack.md` removes the
clankshop assembler and establishes the faceless pack. This spec does
not redefine packaging or delete clankshop.

Lineage already aligned:
`docs/design/2026-08-19-two-roots-simple-spec.md` declares the two roots
and the owner-first workspace contract. It is an input, not an
implementation path.

Consumers (land after this feature):

- `docs/design/2026-08-23-backlog-living-trackers.md`
- `docs/design/2026-08-23-delegate-byproducts-hook.md`
- `docs/design/2026-08-24-inspector-adequacy-and-review-close.md`

Those specs consume canonical paths from this file. They do not edit
this spec during implementation.

## Problem

`<agent-workspace>` is kind-first today: one skill's project surface is
scattered across `doctrine/<skill>`, `hooks/<skill>`,
`scripts/<skill>`, `templates/<skill>`, and sometimes an unkeyed kind
such as `trackers/` or `flows/`. Ownership is not visible at the first
path component. Setup, scoped commits, removal, and review therefore
need a separate ownership table and repeatedly touch unrelated
top-level directories.

The kind-first design also makes a shared assembler tempting: something
must appear to coordinate all of those roots. The faceless-pack feature
removes that assembler. The workspace layout should make the same
ownership boundary structural.

`<agent-records>` already has a different, sound discriminator:
front-matter makes a file a record. It is a shared artifact store and
must remain doctype-oriented. This feature concerns only
`<agent-workspace>`, the home for project configuration and executable
support owned by skills.

## Goal

After this feature:

- A `workspace` skill is the format authority and read-only guard for
  `<agent-workspace>`.
- The canonical grammar is:

  ```text
  <agent-workspace>/<skill>/<kind>/...
  ```

- The owner set is open. Any valid skill stem may own a namespace; no
  installed-skill registry or pack membership probe is required.
- The kind set beneath an owner is closed:
  `doctrine`, `hooks`, `scripts`, `templates`, `trackers`, and `flows`.
  A skill creates only the kinds it actually owns.
- A skill may write only beneath its own namespace. Project-owned
  content may win inside doctrine, hooks, templates, and flows. Package
  bytes win for staged scripts. A skill-owned engine defines the write
  policy for structured data such as trackers.
- Old top-level kind directories — `doctrine/`, `hooks/`, `scripts/`,
  `templates/`, `trackers/`, and `flows/` — are known-bad and always
  fail workspace check. There is no dual read or relocation.
- All live workspace consumers use skill-first paths. No live skill,
  script, test, current spec, or doctrine rule uses a kind-first
  workspace path.
- `<agent-records>` and `.workstreams/` are unchanged.
- Lint `fails=0`; the workspace harness and affected consumer harnesses
  are green.

## Approach

**Chosen: open owners, closed kinds.** Ownership comes first in the
path; kind remains a small vocabulary inside the owner.

```text
.dev/
  analyst/templates/
  auditor/doctrine/
  backlog/hooks/
  backlog/scripts/
  backlog/trackers/
  debugger/flows/
  delegate/hooks/
  inspector/doctrine/
  journal/scripts/
  shopbook/flows/
  workstream/hooks/
```

Only materialized directories exist. This tree is illustrative, not a
required roster.

`/workspace check` validates the generic owner/kind grammar, safe path
shape, file extensions, executability where generic, and symlink rules.
It does not infer whether an owner is installed or whether an owner-specific
filename is semantically known. A typo in an owner stem is a project-level
naming error, not something portable code can detect without a
harness-specific registry. A typo in a kind is deterministic and fails.

**Rejected: kind-first with a better ownership table.** The table is
the indirection causing the repeated alignment work.

**Rejected: `_shared`, `common`, or `project` pseudo-skills.** Shared
records have their own root. General project prose belongs in ordinary
project documentation. Workspace content must have a real steward.

**Rejected: a workspace assembler.** Publishers create only their own
namespace. The faceless pack writes nothing into a project.

**Rejected: versioned roots or compatibility readers.** Alpha hard-cut:
one grammar, one resolver, one check.

## Mechanism

### Path grammar

Let `W` be the resolved agent workspace: the first line-start
`agent-workspace:` in `AGENTS.md`, then `CLAUDE.md`, else `.dev`.
The declaration remains repo-relative and may not be empty, `.`,
absolute, or root-escaping.

Every managed workspace path is:

```text
<root>/<W>/<owner>/<kind>/<kind-specific-tail>
```

`<owner>` uses the skill-name grammar `[a-z0-9-]+`. Reserved legacy
kind stems (`doctrine`, `hooks`, `scripts`, `templates`, `trackers`,
`flows`) may not be owners: their top-level presence is the hard-cut
signature and fails.

Allowed kinds:

| Kind | Canonical shape | Content policy |
|---|---|---|
| `doctrine` | `<owner>/doctrine/**/*.md` | explicit owner setup, then project copy wins |
| `hooks` | `<owner>/hooks/<seam>.md` | safe Markdown filename; the owner knows its seams; missing = skip; project body wins |
| `scripts` | `<owner>/scripts/<entry>.sh` | staged/refreshed only by the owner; package bytes win |
| `templates` | `<owner>/templates/**/*.md` | owning skill deploys absent-only; project copy wins |
| `trackers` | `<owner>/trackers/*` | generic safe-entry checks only; owning engine defines filenames/schema and is sole writer |
| `flows` | `<owner>/flows/*.md` | owning skill or project authors; project copy wins |

Unknown second-level directories fail. Files directly under an owner
fail. Files directly under workspace fail when the workspace and records
homes differ.

### Coincident roots

The two roots may still coincide. Let `R` be the resolved records home.
When `W != R`, every top-level workspace child must be a valid owner
namespace and every owner must follow the closed kind grammar.

When `W == R`, record stores and `history.tsv` may coexist with skill
namespaces. Workspace check applies full validation to directories that
contain recognized kind children. Other top-level entries warn
`reason=coincident-unknown`; they do not fail merely for being record
stores. The six retired top-level kind names remain known-bad and fail
in both modes.

Workspace check never enumerates record doctypes and never parses or
writes records. Journal remains the records format authority.

### Narrow creation and setup

Normal reads never create directories. An explicit setup/deploy verb
may create:

```text
<agent-workspace>/<its-own-name>/<owned-kind>/
```

including under a declared, absent workspace. It may not create or
interpret another owner namespace. Recheck each parent before creation;
refuse symlinked or non-directory parents. A publisher without explicit
setup creates its namespace only as part of the operation that needs
the owned asset and only when that operation already authorizes the
write.

There is no pack-level exception.

### Canonical migrations

This feature hard-cuts all current live consumers to the following
shape:

| Surface | Canonical path |
|---|---|
| Inspector review policy | `inspector/doctrine/<kind>.md` |
| Auditor rubric/policy | `auditor/doctrine/` |
| Backlog debrief hook | `backlog/hooks/debrief.md` |
| Backlog staged engine | `backlog/scripts/trackers.sh` |
| Backlog living lists | `backlog/trackers/<stem>.tsv` |
| Delegate return overlay | `delegate/hooks/byproducts.md` |
| Workstream seams | `workstream/hooks/<seam>.md` |
| Journal staged engine | `journal/scripts/records.sh` |
| Skill lock-in templates | `<skill>/templates/` |
| Skill-owned procedures | `<skill>/flows/` |

The later Backlog, Delegate, and Inspector specs own behavior and setup
for those surfaces. This spec owns only the path grammar, generic
publisher rules, current-consumer path rewrites, and absence of the old
grammar.

### Hooks

Hook paths are `<owner>/hooks/<seam>.md`. One file is one overlay. The
consumer reads only its known filenames; no glob creates runtime
behavior. Missing or empty is skip unless that consumer's own spec says
otherwise. There is no shared parser requirement.

Workstream's existing single-file hook becomes:

```text
workstream/hooks/feature-completion.md
workstream/hooks/after-eventful-ship.md
```

Its parser takes an absolute `--dir`, hashes the canonical known-file
population, and compiles that snapshot into the hand-off. The owning
Workstream package publishes its skeletons. No pack fills them.

### Scripts

Staged entrypoints live at `<owner>/scripts/<entry>.sh`. The package is
the source of truth; host editing is unsupported. The owner setup or
explicit owner materializer uses `cmp` then `cp` and includes a changed
staged script in the same scoped commit as the operation that required
it. No generic skill refreshes another owner's scripts. Every staged
script takes the explicit roots its data needs and does not scan the
front door: Backlog takes root/workspace; Journal takes root/records-root.

Journal uses `journal/scripts/records.sh`; the former records-home dump
and `doctrine/scripts` shapes are absent. Every Journal engine invocation
takes `--root <root> --records-root <repo-relative-R>`, validates that R
stays under root, and operates on `<root>/<R>` rather than deriving R from
the script's deployed location. Journal setup stages/refreshed package
bytes under `<agent-workspace>/journal/scripts/` while creating and
tending `history.tsv`, the records README, and records beneath
`<agent-records>`. Record semantics do not change. Backlog's
materialization and commit custody are specified by its consumer spec.

### Templates, doctrine, trackers, and flows

- Templates: `<owner>/templates/`; project copy wins.
- Doctrine: `<owner>/doctrine/`; explicit setup only; project copy
  wins. No shared station loader or root doctrine tree.
- Trackers: `<owner>/trackers/`; workspace validates generic safe-entry
  structure only. The owner validates filenames and content; Backlog
  defines TSV behavior.
- Flows: `<owner>/flows/`. Shopbook indexes
  `<agent-workspace>/*/flows/*.md`; create requires a named owner and
  writes only that owner. A consumer reads its own flow path.

### Workspace skill

Package `skills/workspace/`, thin router:

| Invocation | Does |
|---|---|
| `/workspace check` | Resolve W/R, validate owner/kind grammar and kind structure, report facts; write nothing. |

Bare `/workspace` runs `check`: there is one verb and no ambiguity. The
description names no sibling. Edges are all empty: it is an in-place
steward over a host layout, not a durable home.
It joins the root faceless pack as an optional member only after the
package exists. That member-set change bumps the pack minor version;
pack membership does not change Workspace behavior.

### Contract and lint

The aligned two-roots lineage is the governing root contract. Update
portable doctrine, `skill-builder new`, README guidance, and lint to the
skill-first grammar. Lint rejects kind-first workspace literals in live
skill prose and scripts. Do not encode a skill roster in lint and do not
edit the lineage document during implementation.

### Spec ownership

This spec exclusively owns:

- the `<skill>/<kind>` workspace grammar;
- workspace resolution, creation, coincidence, and validation rules;
- the `workspace` package;
- path-only migration of current consumers;
- the portable authoring and lint contracts for workspace paths.

It does not own pack installation/removal, Backlog semantics, Delegate
semantics, Inspector semantics, or their eventual setup protocols. It
never edits those sibling specs during implementation.

## Verification

**Workspace harness**

- split homes: valid owner/kind trees pass; unknown kinds, direct owner
  files, direct workspace files, invalid owner stems, and each retired
  top-level kind fail;
- coincident homes: valid owner/kind trees pass; record stores and
  `history.tsv` warn/skip as specified; retired top-level kinds still
  fail;
- each generic kind-shape malformed fixture fails; owner-specific
  semantic fixtures run in the owning skill's harness;
- workspace check reports symlinked owner or kind entries as invalid;
- each owner setup/deploy harness proves that it refuses symlinked or
  non-directory parents before creation;
- scripts-kind validation checks shape and executability only; package
  drift belongs to the owning setup and requires no central registry.

Every absence-style assertion has a red-proof fixture.

**Consumer harnesses**

- Workstream compiles the two skill-first hook files and ignores
  unrelated owner/kind files.
- Journal executes `journal/scripts/records.sh --root <root>
  --records-root <R>` with split and coincident roots; records and ledger
  operations stay under R, and no records-home or doctrine script is
  invoked.
- Shopbook indexes multiple `<owner>/flows/` trees and requires an owner
  on create.
- Existing template consumers resolve `<owner>/templates/`.
- Inspector and Auditor resolve `<owner>/doctrine/` without a shared
  station loader.

**Absence**

Across live `skills/`, current `docs/spec/`, active `docs/design/`,
README, and AGENTS:

- zero `<agent-workspace>/doctrine/`, `/hooks/`, `/scripts/`,
  `/templates/`, `/trackers/`, or `/flows/` kind-first paths;
- zero `.dev/doctrine/`, `.dev/hooks/`, `.dev/scripts/`,
  `.dev/templates/`, `.dev/trackers/`, or `.dev/flows/` live defaults;
- zero `doctrine/scripts` and records-home script execution;
- zero workspace skill-roster registry or owner marker.

Historical closed design records outside the active portfolio are
exempt. Red-proof the path-population grep.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| W1 | Build read-only `workspace check` around open owners + closed kinds, split/coincident rules, old-shape failures, and kind-shape facts | workspace harness + mutation red-proofs | `skills/workspace/**` |
| W2 | Update portable doctrine, `new`, lint, README, and current path contract | lint + old-shape absence gate | `skills/skill-builder/**`, `README.md` |
| W3 | Hard-cut hooks and flows to owner-first paths; Workstream folder compile; Shopbook multi-owner index/create | workstream + shopbook + debugger harnesses | `skills/{workstream,shopbook,debugger}/**` |
| W4 | Hard-cut scripts, templates, and surviving skill-owned doctrine to owner-first paths; give staged Journal its explicit records-root interface; remove old script dumps | affected owner harnesses + split-root Journal fixture + absence gate | `skills/{agent-council,analyst,architect,auditor,backlog,contractor,debugger,inspector,journal,notepad,shopbook,workstream}/**` (path/interface spans only; shared station-call removal already landed in F3) |
| W5 | Add the now-existing Workspace package to the faceless pack's optional members and update its inventory row | pack manifest/install fixture | `PACK.md`, `README.md` |

Land order W1 → W2 → W3 → W4 → W5. One landing after W5. Portfolio
integration then follows Backlog → Delegate → Inspector, serializing
their exact root-runbook spans.

## Out of scope

- Faceless pack implementation or clankshop deletion.
- Record schema, record storage, or `.workstreams/` relocation.
- Backlog tracker schema and verbs.
- Delegate return semantics.
- Inspector adequacy/review-close semantics.
- A generic shared workspace namespace.
- Compatibility reads, migration, aliases, or automatic cleanup of old
  alpha project paths.
