# `migrate <source-path>` — upgrade Auditor artifacts

Select one file or directory tree. Own only `doctype: reports` records tagged `audit` and the
declared `reports.md` template; other reports are stable skips. Current records use
`schema: auditor/audit@1`. A different declared schema or ambiguous report refuses.

For an exact registered schema-less audit record, require legacy `created` to equal the filename
date, preserve lifecycle/tags/legal extra keys and authored report bytes, add the schema, and remove
all retired generic history keys. Move recognized previous-home or registered flat active templates
to `<agent-workspace>/auditor/templates/reports.md`, stripping only their legacy record-shell front
matter. A project template may not declare `schema:`.

Reject symlinks/out-of-project paths; inventory stably; preview source, kind, schema, destination,
changes and skips; confirm; stage and validate the full batch. Record ordered components,
before/staged checksums and phase in `.auditor-migrate-manifest` beside/inside the selection.
Discover it before requiring the source, resume forward (`absent` is deletion's staged state),
refuse a third byte state, and never remove a selected directory. Identity moves use Journal
`records.sh relocate`; external exact references block. Re-inventory and report `changes=0`, as must
a later ordinary rerun.

## Done when

Selected audit artifacts validate as `auditor/audit@1`, foreign reports are untouched, the active
template is canonical and schema-free, no manifest remains, and replay is `changes=0`.
