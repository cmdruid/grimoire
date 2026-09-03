# `repair` — restore an initialized records tool layer

Restore only `.records/records.sh` and Journal's delimited block in `.records/README.md`. Bare repair
never initializes the layer, changes `history.tsv`, touches records, consults `.agents/skilldata`, performs a
migration, or recognizes an earlier Journal version.

1. Resolve `<root>` exactly as setup does.
2. Run `scripts/standup.sh repair <root>` standalone or outside Git; inside an announced sweep, add
   the final `--write-only`. A missing or unsafe ledger stops with exactly
   `reason=setup-required action=/journal setup`. Unsafe destinations and malformed markers refuse
   before mutation. Provider and managed-block drift are replaced atomically; surrounding README
   bytes remain unchanged. A README change after preflight is preserved and refuses with
   `reason=concurrent-project-edit detail=.records/README.md`. A later content failure emits
   `records check failed — tool layer is current; action=/journal curate`.
3. For Git-backed standalone custody, take the unique `wrote:` plus `reconciled:` paths that remain
   dirty and call
   `scripts/scoped-commit.sh <root> "Repair the records tool layer" <paths...>`. The set may contain
   only `.records/records.sh` and `.records/README.md`. A custody refusal or empty set makes no
   commit. Outside Git, make no commit. Inside a sweep, return current writes to its approved diff.

`/journal repair --closure` is a separate recovery contract. Do not infer or improvise it from bare
repair.

## Done when

- The initialized layer has the current executable provider and managed README block.
- Ledger, records, unowned README prose, `.agents/skilldata`, and writer-owned surfaces are byte-identical.
- Standalone custody committed only a nonempty proven provider/README diff, or the caller retained
  custody outside that mode.
