# `migrate <source-path>` — upgrade Analyst artifacts

Select one file or directory tree. Canonical report records remain in `<agent-records>/reports/`;
active catalog templates live in `<agent-workspace>/analyst/templates/`.

Resolve the effective catalog with deployed-wins semantics, then inventory stably. Analyst owns
only `doctype: reports` records tagged `analyst` plus exactly one safe token present in that catalog.
Other reports are skips; missing, malformed, or ambiguous tokens refuse. All owned reports map to
package schema `analyst/report@1`; catalog tokens remain tags and never become project-defined
schemas. Own only the five declared catalog templates, never the retired `reports.md` shell.

For registered schema-less reports, require legacy `created` to match the filename date, preserve
status/tags/legal extra keys and authored body, add the schema, and remove every retired generic
history key. A different declared schema refuses. Move recognized previous-home templates to the
canonical workspace path without changing catalog metadata or authored guidance. A project
template containing `schema:` refuses. Stock retired `reports.md` may be removed after preview;
customized retired content requires an explicit mapping.

Apply the common forward transaction: reject symlinks/out-of-project paths; preview source, kind,
schema, destination, changes and skips; confirm; stage and validate the whole batch; and maintain
`.analyst-migrate-manifest` beside/inside the selection with ordered components, before/staged
checksums, and phase. Look for it before requiring the source and resume the first incomplete
component; source deletion stages as `absent`, a third state refuses, and a selected directory is
never removed. Identity moves use Journal `records.sh relocate`; external exact references block.
Re-inventory and report `changes=0`, including on a later ordinary rerun.

## Done when

Every selected Analyst record validates as `analyst/report@1`, active catalog templates are
canonical and schema-free, foreign reports remain untouched, the manifest is gone, and replay is
`changes=0`.
