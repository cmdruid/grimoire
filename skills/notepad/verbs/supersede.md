# `supersede` — close the old note; mint the replacement

The claim changed. Do not silently edit the old note into a different
fact. No successor → refuse; that is `drop`.

1. Resolve both homes (SKILL.md). Locate `scripts/note-mint.sh` from
   this skill's own directory.
2. Identify the old note (path the operator names, or `find` first).
3. **Successor required.** If none exists and none will be minted,
   STOP and point at `/notepad drop`.
4. Mint the replacement
   (`note-mint.sh mint <agent-records> <agent-templates> "<headline>"`)
   or confirm the successor path already exists. Fill the new body.
5. On the **old** note's body, append one contract record-link:
   `→ notes/<successor-file>.md`.
6. Close the old note:
   `note-mint.sh stamp <agent-records> <old-abs> --status superseded --note "notes/<successor-file>.md"`.
   The body link is the canonical shape; `--note` is the ledger field
   when `records.sh done` runs.
7. **Commit** per SKILL.md: standalone →
   `scripts/scoped-commit.sh <root> "Notepad: supersede — <slug>" <paths…>`;
   write-only sweep → print `path=` / `rel=` for every path written;
   no commit.

## Done when

- Successor minted or confirmed; old body has `→ notes/<file>.md`; old
  note closed `superseded`.
- No successor: refused; pointed at `drop`.
- Write-only sweep: facts printed; no commit.
- Commit-tree STOP: no commit.
