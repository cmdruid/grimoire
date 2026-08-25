---
doctype: adr
status: published
schema: architect/adr@1
tags: [records, schema, migration]
---

# Record metadata names schema and leaves history to durable sources

- **Deciders:** project owner
- **Related:** `→ specs/2026-08-25-skill-owned-artifact-migration.md`; `skills/journal/SKILL.md`

## Context

The current record contract requires `doctype`, `status`, `created`, `updated`, and `tags`, but has
no machine-readable declaration of a writer artifact's structural schema. Skill-owned migration
needs that declaration: selecting every transformation by inference is unsafe, while a generic
`version` key could mean the pack release, skill release, document revision, or storage format.

Required mutation metadata has a cost. An agent must remember to stamp it on every edit, every
writer must implement the same fallback, and missed stamps create authoritative-looking falsehoods.
The dated filename already identifies the record and its creation date. Git records durable change
history where available. Filesystem timestamps are local operational facts: checkout, copy,
restore, migration, and editor behavior can replace them; Unix `ctime` is not creation time and
birth time is not portable.

## Decision

1. The record contract has exactly four required keys: `doctype`, `status`, `schema`, and `tags`.
   `created`, `updated`, `created_at`, `updated_at`, and `revision` have no shared generic meaning.
   They are retired reserved keys: a current record must not carry them. A migrator may accept them
   only on registered legacy input and removes them during upgrade. Writers may add optional
   domain-specific metadata under other names through the existing extra-key rule.
2. `schema` identifies the machine format. Bare `version` is not used.
3. `schema` has the grammar `<writer>/<artifact>@<positive-integer>`. The two names are lowercase
   kebab-case, and `writer` equals the owning skill's name. The artifact component and current
   integer are owned by that writer; shared infrastructure enforces the grammar, not a central
   registry. For example: `architect/spec@1` and `analyst/report@1`. Schema identifiers, validators,
   and migration chains are bundled skill contracts. Project-scoped templates neither declare nor
   override them.
4. This is a hard cut. Every newly minted record carries the four-key shape, and a record is current
   only when it does. The former five-key shape is not a second valid profile: records without
   `schema` are legacy migration inputs and fail current record validation.
5. Existing records gain `schema` and retire `created` and `updated` only through an owning skill's
   explicit `migrate` verb; readers never rewrite while reading. A legacy `created` value must equal
   the filename date before removal, or migration stops for review. A declared schema unsupported
   by the owning skill operation is an error; Journal validates only the shared grammar. A migrator
   may classify an absent schema only through an exact registered legacy signature.
6. Journal is authoritative for project record instances and runtime mutation mechanics.
   Skill-builder is authoritative for portable writer-package conformance: its records-front-matter
   spec and doctrine state the contract, while its lint gate checks bundled schema use and declared
   project templates. The shared layers validate schema grammar but do not enumerate writer-owned
   artifact names or schema numbers.
7. The filename date is the creation-date authority. Journal list/search date bounds operate on it
   and list output sorts by filename date then path.
8. Modification history comes from Git path history. Dirty and untracked records are reported as
   current but undated; non-Git modification history is `unknown`. Filesystem times may be exposed
   only as explicitly non-authoritative diagnostics.

## Alternatives considered

- **`version`:** shorter, but ambiguous with document revision and the repository's existing
  `PACK.md` release version.
- **Required `created_at`, `updated_at`, and `revision`:** self-contained metadata, but redundant
  with the record ID and Git, costly on every mutation, and easy for agents to leave stale.
- **Filesystem times:** require no authored metadata, but are neither portable nor durable enough to
  support record identity, migration, or history claims.
- **Structural signatures only:** necessary for legacy import, but too brittle as the permanent
  identity of newly minted formats.
- **Two indefinitely valid record profiles:** would let untouched writers keep emitting the old
  shape, but would turn an alpha format change into a permanent compatibility layer and weaken
  `schema` as the current-format discriminator.
- **Project-editable schemas:** would make local format experimentation easy, but the same schema
  identifier could then mean different structures in different projects. Validators and migration
  chains could no longer rely on it. Projects customize authoring templates within the bundled
  contract instead.
- **Skill-private metadata conventions:** avoid a records-layer change but make shared validation
  and migration inconsistent across writers.

## Consequences

Journal's contract, validator, list/filter output, deployed README, and mutation commands change with
every record-writing skill template and instruction. Legacy records remain readable input to
explicit owning-skill migration, not conforming current records; there is no compatibility read
mode. Every record-writing skill must adopt the four-key mint shape when the hard cut lands, even
before its existing records can conform. Analyst's touched/stale facts become Git-derived and must
distinguish dirty, untracked, and non-Git states. Skill-builder's schema and project-template lint
must be red-proved and must not mistake package-only files for project lock-ins. Agents no longer
stamp generic metadata on routine document edits.
Project templates remain editable authoring inputs, but changing one cannot redefine the schema
written into a record. A machine-relevant structural change belongs to a new writer-owned schema
version and explicit migration chain; template wording and guidance may evolve without a schema
bump while they continue to validate against the current contract.
