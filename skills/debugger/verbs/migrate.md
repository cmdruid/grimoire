# `migrate <source-path>` — upgrade Debugger artifacts

Select one file or directory tree. Own `doctype: bugs` records matching the filed-repro shape and
map them to `debugger/bug@1`. Own a `doctype: reports` record only when it matches Debugger's exact
investigation section signature; map it to `debugger/investigation@1`. Other reports are skips and
an ambiguous explicitly selected report still refuses. Active templates are `bugs.md` and
`investigation.md`; generic `reports.md` is retired.

For registered schema-less input, require legacy `created` to equal the filename date, preserve
lifecycle/tags/legal extra keys and authored bytes, add the classified schema, and remove every
retired generic history key. A different declared schema refuses. Move recognized previous-home or
flat active templates to `.spaces/debugger/templates/`, stripping legacy record-shell
front matter. Stock retired `reports.md` may be removed after preview; customized content requires
an explicit mapping. Project templates cannot carry `schema:`.

Reject symlinks/out-of-project paths, inventory stably, preview source/kind/schema/destination and
all changes/skips, then confirm. Stage and validate the batch and write
`.debugger-migrate-manifest` beside/inside the selection with ordered components,
before/staged checksums, and phase. Discover it before requiring the source; resume forward from
before/staged states (`absent` for deletion), refuse a third state, and never remove a selected
directory. Identity moves use Journal `records.sh relocate`; external exact references block.
Re-inventory and report `changes=0`, including on a later ordinary rerun.

## Done when

Selected bugs/investigations validate under their Debugger schemas, foreign reports remain
untouched, active templates are canonical and schema-free, no manifest remains, and replay is
`changes=0`.
