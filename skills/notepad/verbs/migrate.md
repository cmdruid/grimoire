# `migrate <source-path>` — upgrade Notepad artifacts

Select one file or directory tree. Own only `doctype: notes` records matching Notepad's note body
shape and the active `notes.md` template. Current records use `notepad/note@1`; other declared
schemas and ambiguous notes refuse.

Require a registered legacy record's `created` to equal its filename date, preserve lifecycle,
tags, legal extra metadata, and authored fact bytes, add the schema, and remove all retired generic
history keys. Move recognized previous-home/flat templates to
`<agent-workspace>/notepad/templates/notes.md`, stripping legacy record-shell front matter; schema
in a project template refuses.

Use the forward migration transaction: reject symlinks/out-of-project paths, inventory stably,
preview every change/skip and confirm, stage and validate all output, then record ordered components,
before/staged checksums and phase in `.notepad-migrate-manifest` beside/inside the selection.
Discover it before requiring the source; resume matching before/staged states (`absent` for
deletion), refuse a third state, and never remove a selected directory. Identity moves use Journal
`records.sh relocate`; external exact references block. Re-inventory and report `changes=0`; a
later ordinary rerun must do the same.

## Done when

Selected notes validate as `notepad/note@1`, the active template is canonical and schema-free, no
foreign artifact changed, no manifest remains, and replay is `changes=0`.
