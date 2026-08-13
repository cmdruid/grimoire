# `note` — capture a durable project fact

Shared memory: a fact about the project a future session should not have to re-derive — how a
subsystem actually works, a non-obvious constraint, a decision's standing context. Not an
action item (no one "does" a note). A decision *between alternatives* with consequences worth
arguing belongs in an `adr` record instead — same mechanics, `records.sh new adr`.

1. Resolve the records root (SKILL.md discipline); stand the layer up lazily if missing.
2. **Mint the record**: `records.sh new notes --title "<the fact, as a headline>"` — state
   the fact, why it holds, and where it bites; link affected records. Prefer one fact per
   note (the path is the ID — a grab-bag note can't be cited precisely).
3. **Check for an existing note that already covers it** (`records.sh list --type notes`) —
   update that record (edit + `records.sh touch`) rather than minting a duplicate.
4. **Commit per the capture-commit policy** (SKILL.md): standalone → its own scoped commit
   (`Journal: note — <slug>`); inside a `debrief` sweep → write-only.

A note that stops being true is closed `dropped` (with a note saying what changed), or
`superseded` by its replacement — never silently edited into a different claim.
