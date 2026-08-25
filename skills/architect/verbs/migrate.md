# `migrate <source-path>` — upgrade Architect artifacts

Migrate only the explicitly selected file or directory tree. The argument is the source; canonical
destinations remain `<agent-records>/specs/`, `<agent-records>/adr/`, and
`<agent-workspace>/architect/templates/`. In-place selection normalizes formatting.

1. Resolve the project root, records home, and workspace. Reject paths outside the project and any
   symlinked source/parent/destination. Before requiring the source, look for
   `.architect-migrate-manifest` beside a selected file or inside a selected directory and resume
   it forward.
2. Inventory in stable path order. Own only `doctype: specs` plus tag `spec`, `doctype: adr`, an
   exact founding shape, and active `specs.md`/`adr.md` legacy templates. A directory selection
   skips proven non-owned files and refuses ambiguity. Current schemas are `architect/spec@1`,
   `architect/adr@1`, and `architect/founding@1`; any other declared schema refuses.
3. For a schema-less registered record, require legacy `created` to equal the dated filename,
   preserve status/tags/extra legal keys and authored body, add the classified schema, and remove
   `created`, `updated`, `created_at`, `updated_at`, and `revision`. Founding files have no filename
   comparison. For templates at `<agent-records>/templates/architect/<file>` or an exact registered
   flat legacy path, strip the old record-shell front matter and target the canonical workspace
   file. `founding.md` is package-only and is never deployed.
4. Preview source, kind, old/current schema, destination, metadata/body changes, and skips. Stop on
   an unknown shape or a different destination collision; identical template bytes may remove the
   old copy after confirmation. Obtain confirmation for any write.
5. Stage and validate every result first. Record ordered paths, before/staged checksums, and phase
   in the manifest. Apply components forward; `absent` is the staged state for source deletion.
   Resume the first incomplete component when bytes match before/staged state and refuse any third
   state. Never remove a selected directory.
6. Record identity moves use the staged Journal `records.sh relocate`; it owns `history.tsv` and
   internal `→` links. External exact references reported by relocation block the batch. Validate
   the four-key record contract and Architect's shape, then inventory again. Report `changes=0` on
   both the internal replay and a later ordinary rerun; a missing moved source is a no-op only when
   its one derived canonical destination validates current.

## Done when

The selected Architect artifacts are current and canonical, authored prose is preserved, no
foreign artifact changed, the manifest is gone, validation passes, and the repeat comparison is
`changes=0`.
