# `repair` — restore an initialized records tool layer

Restore only Journal's package-managed operational surface: `.records/records.sh` and the
delimited `journal:records-tool` block in `.records/README.md`. Repair is narrower than setup:
it never initializes the layer, creates or changes `history.tsv`, consults or removes the prior
workspace provider, replaces the prior generated README pointer, or touches records and writer-owned
surfaces.

1. **Resolve `<root>`** exactly as setup does. Journal uses the fixed `.records` layer and checks
   the fixed `.spaces/journal/setup.intent` path.
2. **Run the shared reconciler**: `scripts/standup.sh repair <root>`. It requires a safe existing
   `.records`, a regular `history.tsv`, no
   setup intent, and zero or one well-formed managed README block. Missing initialization or an
   active intent → stop and name `/journal setup`. Unsafe destinations or malformed markers → stop
   without mutation. A provider is installed or refreshed atomically and validated before the
   managed block can be created or refreshed. A later content-aware `check` finding leaves the tool
   usable; report it and name `/journal curate` or the record owner's explicit migration path.
3. **Commit only reported writes.** Standalone → collect the unique `wrote:
   <repo-relative-path>` lines and call `scripts/scoped-commit.sh <root> "Repair the records tool
   layer" <paths...>`. The set may contain only `.records/records.sh` and
   `.records/README.md`. No writes → no commit. Inside an announced configuration sweep →
   hand those paths to the sweep's approved diff custody and make no nested commit.

## Done when

- The initialized layer has the current executable adjacent provider and current managed README
  block, or was already current.
- `history.tsv`, every record, unowned README prose, prior-provider state, and writer-owned surfaces
  are byte-identical to their starting state.
- Standalone repair committed exactly its reported provider/README paths, or the announced sweep
  retained them for its aggregate commit.
