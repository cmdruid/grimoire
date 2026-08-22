# `upkeep` — fill missing title / use-when

Ongoing maintenance of crawl keys on `$DST/*.md` (same glob as the
index). Not a workshop onramp; not `migrate`. `--check` is facts-only.

1. Resolve project root and `<agent-workspace>` the same way as query.
2. Run this skill's `scripts/flows-upkeep.sh`
   `check|apply --root --workspace`.
3. Decision:
   - Missing `$DST` → no-op 0.
   - `--check`: exit 0 if `need=` empty and `malformed=` empty; else 1.
     Write nothing.
   - `apply`: insert a leading front-matter block when `fm=missing`
     (quoted `title` from first H1, else the stem; quoted `use-when`
     from the stem). When `fm=ok` with a missing key, add **only that
     key**. Never change an existing key. Never change the body after
     the front-matter. `fm=malformed` → skip that file, report it, do
     not rewrite. H1 containing newline or `---` → skip that file, do
     not insert.
4. Does not create files. Does not delete.

## Done when

- `--check`: facts printed; nothing written.
- `apply`: missing keys filled; existing keys and bodies unchanged;
  malformed files skipped and reported.
