# `inventory [query]` — discover operations

Resolve `<root>` and `<agent-workspace>`, then run package-local
`scripts/operations-index.sh list --root <root> --workspace <relative>` or use `search` with
`--query <query>`. Add `--include-deprecated` only when the user explicitly asks for retired entries.

Present the smallest useful catalog: identity, title, use-when, areas, lifecycle, and verification
health. Do not load operation bodies during discovery. Report malformed files, stale active
operations, and native candidates separately; they are not selectable operations.

When a query returns exactly one credible operation, recommend it. When several materially differ,
show the short candidates and ask only if the intended operation cannot be inferred. An empty result
is a catalog gap, not a reason to create anything automatically.
