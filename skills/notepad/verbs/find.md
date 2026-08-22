# `find` — list or retrieve notes

Look up what is already written. Default visibility is **live**
(`draft` ∪ `published`). Do not mint. Do not commit.

1. Resolve both homes (SKILL.md).
2. If the operator asked for a closed or all notes, honor that; otherwise
   live only.
3. If `<agent-records>/scripts/records.sh` is executable: `records.sh
   list --type notes` (live-set default) or with the requested `--status`.
   Else scan `<agent-records>/notes/*.md` and filter on `status:` —
   live is `draft` ∪ `published`; `archived` is closed (and still skip
   `done` / `dropped` / `superseded` / `consumed` on unmigrated trees).
4. Print enough to cite a path: relative path + title. For a single
   retrieve, show the body.
5. No notes: say so. Do not mint.

## Done when

- Listed or retrieved the requested notes (live by default).
- Empty store: said so; did not mint; did not commit.
