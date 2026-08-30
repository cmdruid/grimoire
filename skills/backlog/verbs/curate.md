# `curate [<stem>]` — update or consume rows

Resolve roots and run package-local `scripts/tracker-runtime-check.sh` with them. Invoke only its
returned installed provider. Work from bounded `page` output.

- Sharpen an open row with `update --tracker <stem> --id <id> [--text <text>]
  [--evidence <artifact-ref>]`.
- Resolve or dismiss rows with `consume --consumer <stable-key> --tracker <stem> --ids <id>...
  --resolution <text> [--result <artifact-ref>]`. Consumption preserves source rows and is their
  normal exit from the open queue; there is no delete, complete, drop, or reorder action.

Prefix each API tracker-relative `wrote=` path with `<agent-trackers>`, then commit every changed
path once through the scoped helper. Curation does not perform queued work or mint records.

Done when page output reflects the intended current state and every reported mutation was committed
once with exact paths.
