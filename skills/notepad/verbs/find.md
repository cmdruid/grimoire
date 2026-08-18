# `find` — list or retrieve notes

Look up what is already written. Default visibility is **live** (`open`
and `current`). Do not mint. Do not commit.

1. Resolve the records root (SKILL.md doctrine resolver).
2. If the operator asked for a closed or all notes, honor that; otherwise
   live only.
3. If `<records-root>/scripts/records.sh` is executable: `records.sh
   list --type notes` with `--status open` / `--status current` (or the
   requested status). Else scan `<records-root>/notes/*.md` and filter
   on `status:`.
4. Print enough to cite a path: relative path + title. For a single
   retrieve, show the body.
5. No notes: say so. Do not mint.

## Done when

- Listed or retrieved the requested notes (live by default).
- Empty store: said so; did not mint; did not commit.
