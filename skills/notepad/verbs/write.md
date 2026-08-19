# `write` — find-or-update a live note, else mint

A durable project fact: one claim a future session should not re-derive.
Not an action item. Not a defect. A decision between alternatives belongs
in an `adr` record.

1. Resolve both homes (SKILL.md). Locate `scripts/note-mint.sh` from
   this skill's own directory.
2. **List live notes only.** If `<agent-records>/scripts/records.sh` is
   executable: `records.sh list --type notes --status open` and
   `records.sh list --type notes --status current`. Else scan
   `<agent-records>/notes/*.md` and skip any file whose `status:` is
   `done`, `dropped`, `superseded`, or `consumed`.
3. If a **live** note already covers the fact: edit the body (one fact;
   why it holds; where it bites; links), then
   `note-mint.sh stamp <agent-records> <abs-path>`.
4. If a **closed** note matches the same subject: **STOP** — do not
   update it. Tell the operator to `/notepad supersede` (same subject,
   new claim) or `/notepad write` a distinct fact.
5. Otherwise mint:
   `note-mint.sh mint <agent-records> <templates-home> "<headline>"`,
   then fill the body. Prefer one fact per note.
6. **Commit** per SKILL.md: standalone →
   `scripts/scoped-commit.sh <root> "Notepad: write — <slug>" <paths…>`;
   write-only sweep → print `path=` / `rel=` and do not commit.

## Done when

- Live note updated and stamped, or a new one-fact note minted.
- Closed match: refused the silent edit; pointed at supersede or a new
  write.
- Write-only sweep: `path=` / `rel=` printed; no commit.
- Commit-tree STOP (detached, non-git, unheld `stream/*`/`feature/*`):
  no commit.
- Empty title/slug: refused; asked for a headline.
