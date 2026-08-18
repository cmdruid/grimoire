# `drop` — close a note that is no longer true; no successor

The fact died. There is no replacement. A successor means `supersede`,
not this verb.

1. Resolve the records root (SKILL.md doctrine resolver). Locate
   `scripts/note-mint.sh` from this skill's own directory.
2. Identify the note. If the operator does not say **what changed**,
   refuse.
3. Write one body sentence saying what changed (the fact is no longer
   true, and why).
4. Close: `note-mint.sh stamp <records-root> <abs-path> --status dropped
   --note "<what changed>"`.
5. Do not mint a replacement.
6. **Commit** per SKILL.md: standalone →
   `scripts/scoped-commit.sh <root> "Notepad: drop — <slug>" <path>`;
   write-only sweep → print `path=` / `rel=`; no commit.

## Done when

- Note closed `dropped` with a body sentence naming what changed; no
  new note minted.
- No "what changed": refused.
- Write-only sweep: facts printed; no commit.
- Commit-tree STOP: no commit.
