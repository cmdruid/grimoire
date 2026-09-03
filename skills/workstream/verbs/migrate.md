# `migrate <source-path>` — separate Workstream records

The source is one file or directory tree. Current Workstream records live only in
`.records/streams/`; active templates are
`.agents/skilldata/workstream/templates/manifest.md` and `debrief.md`.

Inventory stably. Own current `doctype: streams` records with `workstream/plan@1` plus tag `plan`
or `workstream/debrief@1` plus tag `debrief`. A schema-less legacy `reports` record tagged
`debrief` is attributable and moves to `streams/`. A schema-less record in `plans/` is ambiguous
with Contractor: never sweep it from a directory. An explicitly selected exact file is the caller's
ownership assertion, which the preview labels; it must still match the registered legacy plan
shape. Queue-source Contractor plans remain in `plans/` and are not relocated.

Require legacy `created` to equal the filename date, preserve lifecycle, domain tags, legal extra
metadata and authored body, add the mapped Workstream schema, and remove all retired generic
history keys. Move identity through executable staged Journal `records.sh relocate` so ledger field
3 and internal exact links follow; missing/old Journal tooling refuses before writes, and external
exact references block.

Recognize legacy active templates as `plans.md` → `manifest.md` and `reports.md` → `debrief.md` at
the previous-home or registered flat location. Strip their record-shell front matter while
preserving authored body. An absent canonical destination accepts; identical bytes may remove the
source after preview; different bytes block. Stock obsolete shells may be removed, but customized
obsolete content needs an explicit mapping.

Reject symlinks and out-of-project paths. Preview source, ownership assertion, kind, old/current
schema, destination, metadata/body/link/ledger changes and skips, then confirm. Stage and validate
the entire batch. Maintain `.workstream-migrate-manifest` beside/inside the selection with ordered
components, before/staged checksums, and phase; discover it before requiring the source. Resume the
first incomplete phase when each component matches before/staged (`absent` for deletion), refuse a
third state, and never remove a selected directory. Re-inventory and report `changes=0`; a later
ordinary rerun does the same without confirmation, including a uniquely derivable missing moved
source whose current destination validates.

## Done when

Selected Workstream records are valid under `streams/`, Contractor plans remain untouched,
`manifest.md`/`debrief.md` are canonical, no manifest remains, and replay is `changes=0`.
