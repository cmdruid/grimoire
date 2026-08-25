# `migrate <source-path>` — import a legacy Markdown tracker

The argument explicitly selects one Markdown file or directory tree. Resolve the records home and
workspace; the canonical live destination is `<agent-workspace>/backlog/trackers/<stem>.tsv`. This
verb is the only exception to Backlog's ordinary no-adoption rule.

1. Reject out-of-project paths and symlinked source/parent/destination components. Before requiring
   the source, recover `.backlog-migrate-manifest` beside a selected file or inside a selected
   directory. Inventory stably. Own only the former `doctype: trackers` plus exact `## Items` line
   grammar. Unknown lines, ambiguous stems, or malformed dates/links refuse; ask for an explicit
   stem mapping when it cannot be proved.
2. Parse each item losslessly into status, created date, optional completion date, text, and optional
   link. Preview source, target stem/path, row count, ID range above current highwater, source
   normalization, and live-vs-archived disposition. Confirm before writes.
3. Stage a five-field TSV row file and call only the executable staged writer:
   `trackers.sh --root <root> --workspace <workspace> migrate-import --tracker <stem>
   --source <record-relative-source> --rows <staged>`. It validates rows, allocates monotonic IDs,
   preserves status/dates/text/links, and writes `# migrated=<record-relative-source>`. An existing
   receipt reports `changes=0`.
4. Normalize the retained Markdown source to the four-key profile with
   `schema: backlog/tracker@1`, preserving authored content and removing retired generic history
   keys. Require legacy `created` to equal its filename date. A live source closes `consumed`
   through Journal after import; an already archived source retains its disposition.
5. Record ordered tracker/source/ledger components, before/staged checksums, and phase in the
   manifest before replacement. Resume forward when components match before/staged (`absent` for
   deletion), refuse any third state, and never remove a selected directory. Identity moves, if
   any, use Journal `records.sh relocate`; external exact references block.
6. Validate the tracker, retained record, ledger coherence, and repeat inventory. Report
   `changes=0`; a later ordinary invocation must also do so without confirmation.

## Done when

Every selected legacy item exists once in the canonical TSV with a source receipt, the retained
record validates as `backlog/tracker@1` with correct closure state, no manifest remains, and replay
is `changes=0`.
