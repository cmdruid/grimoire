---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec, migration]
---

# Skill-owned artifact migration — Spec

Related: `→ adr/2026-08-25-record-metadata-schema.md`

## Problem

Skills evolve their project-owned artifacts: destinations move, front-matter vocabularies change,
and body formats gain or rename structural sections. Today there is no owner-facing operation that
upgrades an existing corpus. Journal's deployed `migrate-status` is one narrow substrate migration
over the whole records root; it cannot identify or reshape one writer's documents.

Manual migration is unsafe. For typed records, the path is the record ID: moving a file can stale
`history.tsv` and every inbound `→ <record-path>` link. Replacing an old body with the current
mint template can silently discard authored prose. A directory-based move is also too coarse:
Analyst's `reports/` store is shared with other report writers, so Analyst owns only records
carrying its tag.

The proposed starting skills do not all own the same artifact shape:

- Architect owns spec and ADR records, plus founding-shaped working documents.
- Contractor owns plan, roadmap, and runbook records in one doctype, distinguished by tags.
- Analyst owns only `reports` records tagged `analyst`; it also owns project-customizable templates,
  which are configuration rather than report records.
- Workstream owns execution plans and debriefs. Its legacy records are mixed into Contractor's
  `plans/` store and the general `reports/` store, so the current location does not express that
  ownership.
- Backlog owns living TSV trackers. Converting its former `doctype: trackers` records is a
  record-to-row import, not Markdown/front-matter normalization.

A shared verb name is useful, but pretending these transformations are one generic file operation
would erase the ownership distinctions that make them safe.

## Goal

Give an artifact-owning skill an idempotent, lossless, previewable `migrate` operation that can
import known legacy artifacts into the skill's canonical home or normalize already-canonical
artifacts in place. Each skill selects only artifacts it can prove it owns and applies only
registered transformations whose source shape it recognizes. When two writers historically emitted
the same shape, only an explicitly named file—not a directory selection—may serve as the caller's
ownership assertion, and the preview must make that assertion visible. Establish the shared record
metadata needed to identify a writer schema before the initial adapters depend on it, without
imposing per-edit bookkeeping on record writers. The record-contract change is a global alpha hard
cut, not a writer-by-writer compatibility regime. This specification defines migration adapters for
Architect, Contractor, Analyst, Backlog, Workstream, Auditor, Notepad, and Debugger so every current
record writer has an explicit upgrade path when the cut lands.

## Approach

Define one conversational migration protocol and implement self-contained, skill-specific
adapters. Pilot the protocol with Architect, then apply it to Contractor and
Analyst. Treat Backlog's legacy-record-to-TSV conversion as a separate adapter under the same
preview/confirm/verify discipline, not as a shared Markdown formatter. Move Workstream's owned
execution records into a dedicated `streams/` record class so future ownership is structural rather
than inferred from a shared store. Auditor, Notepad, and Debugger use smaller in-place adapters over
their provably owned legacy records and project templates.

For Backlog only, this specification supersedes the “no standing adopt engine” and “record
adoption/conversion out of scope” decisions in
`docs/design/2026-08-23-backlog-living-trackers.md`. The exception is one explicit `migrate` verb
over the caller-named source; ordinary Backlog setup and mutation retain their published behavior.

The command contract is:

```text
/<skill> migrate <source-path>
```

`<source-path>` explicitly selects one file or one directory tree; it is not a destination. The
skill resolves its canonical destination from the existing workspace/records contract. When a
selected artifact is already at its canonical path, the same command performs an in-place format
upgrade. One argument therefore covers import and in-place normalization without making storage
configurable.

The command does not accept an arbitrary destination. Every record writer has a fixed future-write
location; Backlog has a canonical workspace tracker home; and Journal and Analyst discover records
beneath the agent-records home. Project templates likewise have one canonical destination:
`<agent-workspace>/<skill-name>/templates/<file>`. Moving active documents or templates to a
caller-chosen destination would make migration, future writes, and discovery disagree unless the
project also gains per-skill store configuration—a separate and much larger storage feature.

Alternatives rejected:

- **One central migrator.** It cannot own the semantic distinction among specs, plans, Analyst
  reports, and Backlog rows; it would become a registry of sibling formats and break standalone
  skill ownership.
- **Re-render every document through the latest template.** Templates mint new documents; they are
  not parsers for old authored content. This loses or misplaces prose when sections change.
- **Infer ownership from the parent directory.** Stores may be shared, and the record contract says
  front matter—not the directory—is authoritative.
- **Best-effort cleanup.** A migration that guesses is a data-loss tool. Unknown or ambiguous shapes
  are findings to report, not files to rewrite.

## Mechanism

Every adapter follows the same transaction:

1. Resolve the project root, both project homes, and the explicit source path. Reject paths outside
   the project and any symlinked source, parent, or destination component.
2. Inventory in stable order without writing. Classify ownership from front matter plus the
   writer's structural discriminator; directory names are evidence only. Proven non-owned files are
   reported as skips. Ambiguous ownership stops the entire batch unless the command names that exact
   file and the adapter registers its legacy shape as requiring a caller ownership assertion. A
   directory argument never asserts ownership of ambiguous descendants. The preview labels every
   accepted assertion.
3. Match each owned artifact to a registered migration chain. Record instances and declared
   project templates are separate recognized kinds. A chain names an exact source shape,
   deterministic transformations, and a current-shape validator. Unknown shapes stop before any
   write. Do not equate “different from today's template” with “old format.” A schema identifier,
   validator, or migration chain is always loaded from the bundled skill package, never from the
   project template being migrated.
4. Derive missing record identity facts only from evidence: valid existing front matter, filename,
   or Git history. For a dated record instance, the filename is the creation-date authority. When
   that record carries legacy `created`, require it to equal the filename date before retiring it;
   a mismatch stops for review. This comparison does not apply to an undated project template or
   Architect founding file. Template date placeholders are retired as template chrome, and a
   founding file's legacy dates may be removed without inventing a filename date.
5. Present one table: source, classified kind, current/target format, destination, front-matter
   changes, body changes, link/ledger effects, and any skips. Moving or destructive normalization
   requires confirmation after this preview.
6. Preflight the whole batch: no destination collisions, duplicate identities, malformed ledger
   rows, unresolved transformation, or unsafe path. Stage transformed bytes separately and validate
   them before touching sources. A transaction manifest records source/destination paths, original
   and staged checksums, and the last completed phase.
7. Apply the preflighted batch as a forward-recoverable transaction. An in-place, single-file
   rewrite uses an adjacent temporary file plus atomic rename. A multi-file operation uses the
   manifest and ordered component replacements. A handled failure, trappable signal, or abrupt
   termination leaves the manifest and staged bytes for the next invocation to resume; it does not
   attempt a best-effort rollback after writes begin. A completed transaction removes its manifest
   and temporary files. Preserve authored prose and unknown legal front-matter keys unless a
   registered migration explicitly retires one. Preserve lifecycle state. A schema-aware migration
   retires legacy `created` and `updated`; it does not replace them with timestamps or a revision
   counter.
8. For a record identity move, use a records-layer relocation primitive that first materializes and
   validates the destination, then rewrites field 3 of matching `history.tsv` rows and retargets
   exact inbound `→ <old-path>` links, and removes the source last. The temporary old/new overlap
   is recorded in the manifest so a rerun can resume forward deterministically.
   The transaction rewrites links only in records beneath `<agent-records>`. Its preflight also
   scans
   regular project files outside `<agent-records>`, excluding `.git/`, migration temporaries, binary
   files, and symlinks, for the literal record-link token `→ <old-path>`. Every match, including
   one in an example, is reported with file and line and stops the move. The migration does not
   rewrite files owned by another system or guess whether an occurrence is operative. The caller
   resolves or separately authorizes those changes, then reruns migration. Skills must not hand-edit
   the ledger.
   A move that cannot perform this transaction refuses before writing; in-place normalization does
   not need relocation.
9. Validate the resulting skill-specific shape and the records contract, then repeat the adapter's
   inventory and transformation comparison internally. It must report `changes=0`. A later ordinary
   invocation of the same `/<skill> migrate <source-path>` command must also report `changes=0`
   without requesting confirmation; there is no separate check-mode command.

The records-layer tool is a narrow capability boundary, not a general migration floor. An adapter
may normalize or reshape an owned record in place using its self-contained file-mode path. If the
canonical destination changes the record ID, the adapter requires the executable staged
`<agent-workspace>/journal/scripts/records.sh` with the relocation operation; when it is absent or
too old, preflight refuses before any write and names the required tool refresh. Adapters that
expose identity-changing migration declare `consumes: records-tool`; ordinary record minting and
in-place migration remain complete without it.

The command writes one `.<skill>-migrate-manifest` beside an explicitly selected file or inside an
explicitly selected directory. The manifest records the ordered components, source and destination,
before and staged checksums, and completed phase. Its creation is the operation lock for that
selection. Manifest lookup happens before requiring the selected source to exist, so recovery still
works after the source-removal phase of a file move. Before preflighting new work, the adapter
recovers a manifest at that location. A
component matching its before checksum is pending; one matching its staged checksum is complete.
For a source-removal component, the recorded staged state is `absent`, and absence counts as a
completed match. A mixture resumes at the first incomplete phase. A component matching neither
recorded state refuses with its path and both expected values. Recovery is the only operation
allowed while the manifest remains. Migration temporaries and the manifest itself are excluded from
inventory and external reference scans.

A completed migration never removes an explicitly selected directory itself. For an explicitly
selected file whose migration moves or renames it, a later invocation may find the source absent.
That is `changes=0` only when the adapter can derive exactly one canonical destination from the
original path and registered chain and that destination validates as current; otherwise the missing
source is an error. This rule covers record relocation and legacy-template renaming without a
persistent compatibility receipt.

Initial ownership classifiers:

- **Architect:** `doctype: specs` with the `spec` tag; `doctype: adr`; founding-shaped documents
  only when explicitly selected and still kept outside the records-mint path prescribed for them.
  Their current schemas are respectively `architect/spec@1`, `architect/adr@1`, and
  `architect/founding@1`. Its active project templates are `specs.md` and `adr.md`;
  `founding.md` remains package-only.
- **Contractor:** `doctype: plans` with exactly one writer kind (`plan`, `roadmap`, or `runbook`),
  retaining optional `stage` and its writer-owned value. The current schema matches that kind:
  `contractor/plan@1`, `contractor/roadmap@1`, or `contractor/runbook@1`. Its active project
  templates are the body scaffolds `plan.md` and `roadmap.md`; a runbook is compiled and has no
  project template. The former generic record shell `plans.md` is retired.
- **Workstream:** current owned records use `doctype: streams` beneath
  `<agent-records>/streams/`. An execution plan declares `schema: workstream/plan@1` and includes
  the `plan` tag; a debrief declares `schema: workstream/debrief@1` and includes the `debrief` tag.
  Other domain tags are preserved. Its active project templates are `manifest.md` for execution
  plans and `debrief.md` for debriefs. The adapter moves legacy Workstream `plans.md` to
  `manifest.md` and `reports.md` to `debrief.md`, stripping their retired record-shell front matter
  while preserving their authored bodies. A schema-less legacy `reports` record with the `debrief`
  tag is attributable to Workstream and moves to `streams/`. A schema-less legacy plan in `plans/`
  is structurally indistinguishable from a Contractor plan, so Workstream never claims or sweeps it
  by directory. Passing that exact file explicitly to `/workstream migrate` is the caller's
  ownership assertion; the adapter still requires the exact registered legacy plan shape and shows
  the assertion in preview. Existing Contractor-owned plans remain in `plans/` and may be consumed
  as queue sources without Workstream taking ownership or relocating them.
- **Analyst:** `doctype: reports` with tag `analyst` plus a recognized catalog token. Other reports
  in the same directory are skipped as not owned. Resolve the effective catalog with Analyst's
  deployed-wins rule: a valid deployed catalog when present, otherwise the bundle. Any safe token
  present in that effective catalog is owned and maps to the package-owned `analyst/report@1`;
  missing, malformed, or ambiguous tokens refuse. Catalog tokens remain tags, not project-defined
  schema names. Its active project templates are `briefing.md`, `status.md`, `subsystem.md`,
  `diagnostics.md`, and `guide.md`; the former generic record shell `reports.md` is retired.
- **Backlog:** current TSV files match the exact tracker header/schema. A legacy Markdown tracker
  must match the former `doctype: trackers` plus `## Items` line grammar; its destination stem and
  any unclassifiable line require an explicit mapping before conversion through the staged writer.
  When the stem is not provable from the record, the preview asks for it before confirmation. The
  retained source record normalizes to `schema: backlog/tracker@1` so it remains a valid record
  after its rows have moved into TSV.
- **Auditor:** `doctype: reports` with tag `audit`. Its current schema is `auditor/audit@1`, and its
  active project template is `reports.md`. Other reports are skipped.
- **Notepad:** `doctype: notes` matching Notepad's legacy note shape. Its current schema is
  `notepad/note@1`, and its active project template is `notes.md`.
- **Debugger:** `doctype: bugs` matching Debugger's bug shape maps to `debugger/bug@1`; a
  `doctype: reports` record must match Debugger's exact investigation section signature before it
  maps to `debugger/investigation@1`. Its active project templates are `bugs.md` and
  `investigation.md`; the former generic record shell `reports.md` is retired. Other reports are
  skipped, while an ambiguous explicitly selected report refuses rather than becoming a Debugger
  record by assertion.

A project template is a project-editable authoring scaffold that the owning skill actively resolves
and reads while doing work. It is not a schema definition. Every declared template has exactly one
canonical location, `<agent-workspace>/<skill-name>/templates/<file>`, and a live read site in the
owning package. Package-only templates are never copied there. Schema identifiers, validators, and
migration chains remain bundled with the skill and are never loaded from project templates.

Template migration recognizes the canonical path, the previous
`<agent-records>/templates/<skill-name>/<file>` path, and an explicitly selected legacy flat
`<agent-records>/templates/<doctype>.md` when the invoking skill plus exact legacy shape proves the
mapping. It moves active templates to the canonical path and strips record-shell front matter from
templates that remain as body scaffolds. An absent destination accepts the move. An identical
destination makes the source a removable duplicate after preview. Different destination bytes stop
without overwrite. A retired generic shell is removed only when it matches a registered stock
shape; customized retired content stops and requires an explicit mapping to an active template.

Ordinary template resolution is a hard cut: canonical incumbent when present, otherwise bundled
copy for a genuinely fresh project. If a recognized legacy template exists while the canonical path
is absent, the writer refuses and names `/<skill> migrate <legacy-path>` rather than silently copying,
adopting, or ignoring the customization. A project template with a front-matter `schema:` key is
invalid; it cannot select or override the schema written by the skill.

Backlog conversion uses a staged writer operation; the adapter never edits TSV bytes. The writer
maps legacy items in source order, preserving open/completed state, creation/completion dates, text,
and optional link, and allocates new IDs monotonically above the tracker's high-water mark. The same
atomic TSV rewrite adds a unique `# migrated=<records-relative-source>` receipt; an existing receipt
makes row import a no-op. After the receipt exists, retain the source Markdown so inbound links keep
resolving, add `schema: backlog/tracker@1`, and retire its legacy `created` and `updated` keys. A live
source closes through the records tool as `consumed`, with the destination TSV in the ledger note;
an already-archived source retains its status and existing disposition. Failure after the receipt
but before source normalization or closure resumes those steps without duplicating rows. Backlog's
validator accepts one receipt per source and rejects malformed or duplicate receipts.

Format evolution is an explicit global hard cut. Journal accepts one current record profile with
exactly the required keys `doctype`, `status`, `schema`, and `tags`. Current artifacts declare
`schema: <writer>/<artifact>@<positive-integer>`, where both name components are lowercase kebab-case
and the writer is the owning skill name. `created`, `updated`, `created_at`, `updated_at`, and
`revision` are retired reserved keys and are invalid on a current record. Other optional
domain-specific keys remain legal.

A record without `schema` is legacy migration input, not a second valid profile, and fails ordinary
current-record validation. Only an owning skill's explicit `migrate` verb may accept it, and only
when an exact registered legacy signature proves the transformation. An unknown declared schema
refuses rather than falling back to structural guessing. Readers never migrate or normalize as a
side effect.

All record-writing skills switch their bundled schema contracts, mint instructions, scripts, and
tests to the four-key profile in the same hard-cut release. This specification supplies legacy
adapters for Architect, Contractor, Analyst, Backlog, Workstream, Auditor, Notepad, and Debugger.

Schema and template are deliberately different things. A schema is the package-owned identifier
plus the machine constraints, validator, and migration chain that give the identifier stable
meaning. A template is optional project-editable guidance or body scaffolding used to author a
document within that contract. One schema may support several templates, as with
`analyst/report@1`; a schema may have no project template, as with a compiled Contractor runbook;
and changing template wording does not require a schema bump. A change to structure that a parser,
validator, or migrator relies on requires a new bundled schema version. A customized template that
cannot produce a valid document under the selected bundled schema stops with findings rather than
silently redefining that schema.

Temporal behavior uses durable evidence without asking agents to stamp every edit:

- The first ten filename characters are the creation date. Journal list/search date bounds operate
  on that date, not on freshness, and their documentation names that meaning explicitly.
- Journal list rows omit the profile-specific `updated` column and sort by filename date descending,
  then path.
- Analyst derives changed-since and last-modified facts from Git path history. Dirty and untracked
  records are reported separately as current but undated changes; they are never assigned a
  fabricated timestamp or classified as stale. For committed records it follows renames; shallow or
  rewritten history is reported as a bounded evidence span, not silently treated as complete.
- In a non-Git project, modification history is `unknown`. Filesystem timestamps may be shown as
  non-authoritative diagnostic hints but never satisfy a record-contract or migration decision.

Enforcement has two authorities at different layers:

- **Journal** owns runtime instances. Its record contract, staged `records.sh`, deployed README, and
  tests validate the four-key profile and schema grammar. Its ordinary commands reject schema-less
  records and records carrying retired keys rather than preserving or upgrading them, and add no
  timestamp or revision bookkeeping. `records.sh new <doctype> --schema <schema> --title <title>`
  validates the schema grammar and synthesizes the four-key front matter; repeatable `--tag` fills
  tags, `--dir` selects the store, and an optional `--template <body-template>` supplies authoring
  body bytes. It substitutes literal `<title>` and `<date>` body slots with the selected title and
  mint date; a body template containing `<schema>` or `<tags>` refuses because those are not
  project-template slots. The template never supplies front matter or the schema. A writer's
  file-mode path synthesizes the same shell and substitutions. Journal
  also supplies the forward-recoverable relocation transaction used by skill adapters. `setup`
  refreshes these bytes; ordinary reads never migrate implicitly.
- **Skill-builder** owns library packages. Its portable `specs/records-front-matter.md`,
  record-writer doctrine, scaffolding/review guidance, and lint gate require the four-key profile.
  The lint gate checks that every schema passed by a writer has that package's prefix; every declared
  project template has a live resolution/read path; no declared project template contains a
  front-matter `schema:` key; package-only templates are not copied; and removed generic shells are
  not retained as unused lock-ins. Each new lint arm is red-proved.

Neither authority owns a registry of valid artifact names or current schema numbers. Those semantic
facts remain in the writer package and its migration adapter; the shared layers enforce only grammar
and mechanics.

## Verification

The protocol needs fixtures for: single-file and tree selection; mixed-owner shared stores;
unknown/ambiguous formats; canonical in-place no-op and upgrade; source-to-canonical import;
destination collision; symlink escape; legacy creation-date disagreement; draft/published/archived
records; ledger and inbound-link relocation; injected mid-transaction failure; exact byte
preservation of untransformed prose; and a second-pass `changes=0` proof.

Record-contract fixtures additionally cover: matching and mismatched legacy `created` versus the
filename; rejection of schema-less records by ordinary Journal operations; acceptance of those same
records only through an exact owning-skill migration signature; retirement of `created` and
`updated`; rejection of every retired reserved key on a current record; schema grammar and
writer-prefix mismatch; Journal-synthesized front matter with and without an optional body template;
literal body-slot substitution and refusal of schema/tag slots; file-mode byte parity; filename-date
list filters and sorting; Git-derived touched/stale facts with rename following and shallow-history
disclosure; dirty and untracked records; and the non-Git `unknown` result. Fixtures also prove every
record-writing package mints the four-key profile and that project template edits cannot change its
schema.

Relocation fixtures prove that a missing or old staged records tool refuses without writes, while
the same adapter still completes an in-place migration in file mode. An executable current tool must
move the record and recoverably update ledger paths and records-root inbound links without leaving
partial state after recovery. Inject interruption after each manifest phase and prove the next
invocation recognizes all-before, all-staged, and mixed before/staged component sets; resumes forward
to exactly one source identity, correct ledger paths, and resolving links; and refuses a component
whose bytes match neither checksum.

Each adapter needs red-proofs for its ownership discriminator, every registered legacy shape, and
the current-shape validator. Backlog additionally needs lossless conversion of open/completed rows,
links, dates, monotonic IDs, receipt-based no-op reruns, receipt-before-close interruption recovery,
source normalization and retention, and a refusal fixture for lines that cannot map to TSV fields.
Analyst fixtures cover bundled, deployed override, and host-added catalog tokens. Workstream
fixtures prove future plan and debrief minting under `streams/`; preservation of additional plan
tags; debrief relocation from `reports/`; refusal to sweep schema-less `plans/`; explicit-file
migration of a recognized legacy Workstream plan; and byte-identical retention of Contractor plans
used as queue sources. They also prove `plans.md` → `manifest.md` and `reports.md` → `debrief.md`
template migration without collision or content loss. Auditor, Notepad, and Debugger fixtures cover
their exact legacy classifiers, in-place schema upgrades, shared-report skips, and current-shape
no-ops.

Template fixtures cover every declared active template and its live read site; canonical in-place
normalization; moves from both previous homes; identical and differing destination collisions;
stock obsolete-shell retirement; customized obsolete-shell refusal; package-only exclusion;
front-matter schema rejection; ordinary-mint refusal in the presence of an unmigrated legacy
template; and an ordinary second migration invocation reporting `changes=0`. A red-proof removes a
template's live read site and proves package conformance fails, and another makes a project template
select a schema and proves validation fails.
