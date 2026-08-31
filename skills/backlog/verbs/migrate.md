# `migrate` — convert one tracker@1 installation

1. Resolve `<root>` per `SKILL.md`. Resolve an optional `<source-root>` as a safe repo-relative
   path; without one, inspect only `.trackers`. Never infer a source from `AGENTS.md`, another
   front door, or a filesystem scan.
2. Run package-local `scripts/migrate-trackers.sh preview --root <root>` and add
   `--source <source-root>` only when the operator named one. Preview requires a clean attached Git
   checkout and accepts only the exact tracked tracker@1 TSV population described by its output.
3. Present the source, destination, complete path inventory, and path count. Obtain explicit confirmation
   before applying the same previewed scope.
4. Run the same command with `apply` and `--confirmed`. The converter moves queue files to
   `.trackers/tables/`, renames `receipts.tsv` to `history.tsv`, rewrites only leading receipt IDs,
   installs the tracker@2 surface, verifies it, and makes one scoped migration commit.

Queue row order and bytes are preserved. History row order and every non-ID byte are preserved.
Unsupported, mixed, dirty, untracked, ignored, symlinked, or malformed sources refuse before the
first write. If a post-write check fails, report the ordinary Git diff and stop; Git is the rollback
mechanism.

Done when the migration commit contains the exact source-to-`.trackers` conversion, the installed
provider reports `schema=tracker@2`, bounded reads succeed, no front-door file changed, and the
worktree is clean.
