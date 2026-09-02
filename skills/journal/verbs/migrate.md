# `migrate <source-root>` — move one explicitly named records root

Move one human-named, dedicated records directory wholesale to fixed `.records`. This is a narrow
Git rename, not source discovery or content conversion. There is no no-argument form.

1. Resolve `<root>` as the exact Git top level and require `<source-root>` as a safe repo-relative
   directory. Do not read front-door declarations or infer the source from project residue.
2. Run
   `scripts/migrate-records-root.sh preview --root <root> --source <source-root>`. It requires a
   clean attached-branch worktree, absent `.records`, a fully tracked non-symlink source, no ignored
   entries, and a dedicated inventory containing only records and the three records-root controls.
   Empty directories and foreign entries refuse.
3. Show the exact source, destination, path list, and count. Obtain explicit confirmation for this
   whole-root move.
4. After confirmation, run
   `scripts/migrate-records-root.sh apply --root <root> --source <source-root> --confirmed`. The
   helper repeats preflight, performs one `git mv`, invokes stateless setup in write-only mode,
   validates the installed layer, and creates one scoped commit. It never reads or changes
   `AGENTS.md`, `CLAUDE.md`, retired declarations, or any path outside the named source and current
   `.records` destination.
5. Report the commit on success. A preflight refusal changes nothing. A post-move failure leaves an
   ordinary Git diff for inspection or reversion; do not create a manifest, fallback, rollback
   routine, compatibility path, or private resume state.

## Done when

- Preview changed no byte, index entry, or commit and still awaits confirmation.
- Apply moved the exact source wholesale, preserved record and ledger bytes, refreshed only current
  tool projections, made one scoped commit, left front doors unchanged, and ended with clean Git
  status.
