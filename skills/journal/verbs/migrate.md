# `migrate [<source-root>]` — move one dedicated records root

Move a brownfield project's whole, dedicated records directory to fixed `.records`. This is a
narrow Git rename, not a content converter: it never selects records individually, rewrites record
links, changes record or ledger bytes, or offers a compatibility path.

1. **Resolve the project and source.** Resolve `<root>` as the exact Git top level that owns the
   records. An optional `<source-root>` must be a safe repo-relative directory. Without it, the
   helper may infer one source only from the retired declarations it recognizes at the migration
   edge. With it, every such declaration must agree. Conflicting declarations refuse.
2. **Preview without writing.** Run
   `scripts/migrate-records-root.sh preview --root <root> [--source <source-root>]`. It requires a
   clean attached-branch worktree, absent `.records`, a fully tracked non-symlink source, and no
   ignored source entries. It lists every tracked source path. The source may contain only records
   matching Journal's dated-filename-plus-`doctype` discriminator, the root controls
   `history.tsv`, `README.md`, and `records.sh`, and containing directories. A foreign entry makes
   the source mixed and refuses the whole move.
3. **Show the preview and obtain explicit confirmation.** Name the source, destination, and path
   count. Do not infer approval from the request to preview or migrate. Ask whether to apply this
   exact whole-root move.
4. **Apply once confirmed.** Run
   `scripts/migrate-records-root.sh apply --root <root> [--source <source-root>] --confirmed`.
   The helper repeats the full preflight before its first write, performs the whole Git move,
   removes matching retired declarations without changing surrounding front-door bytes, refreshes
   fixed-path Journal tooling, checks the installed layer, and creates one exact scoped commit. If
   setup created an intent, the helper finalizes it only after the commit succeeds.
5. **Report the outcome.** On success, report the commit and the canonical `.records` home. On a
   refusal, report its `reason=` and leave the project untouched. On a failure after the move,
   report the ordinary Git diff left for human inspection or reversion. Do not create a manifest,
   alias, fallback, rollback routine, migration intent, or automatic resume path.

## Done when

- Preview: the exact dedicated source and every tracked path were shown; no byte, index, or commit
  changed; explicit confirmation is still required.
- Apply: the source is absent, `.records` contains the wholesale move with record and ledger bytes
  unchanged, retired declarations are gone, the installed provider is current and passes `check`,
  one scoped commit contains the move and refresh, no setup intent remains, and Git status is clean.
- Refusal or post-write failure: the reason and recovery surface were reported exactly; no
  compatibility machinery was introduced.
