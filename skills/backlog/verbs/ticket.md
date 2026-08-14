# `ticket` — escalate to the human

A larger item that **needs the human** — a decision, a credential, a sign-off, work only they
can do. A ticket is a standing ask with context, not a chat message that scrolls away.

1. Resolve the records root and the deployed `records.sh` (SKILL.md guard — no records layer → stop and point at `/journal setup`).
2. **Mint the record**: `records.sh new tickets --title "<the ask, as a headline>"` — fill
   the template: **Ask** (one clear question or request), **Context** (enough to answer
   without re-deriving: what surfaced it, what was tried, links to related records), leave
   **Resolution** empty. If the ticket graduates an existing tracker line, link that line to
   the ticket (`→ tickets/<file>.md`) rather than deleting it.
3. **Commit per the capture-commit policy** (SKILL.md): standalone → its own scoped commit
   (`Backlog: ticket — <slug>`); inside a `debrief` sweep → write-only.
4. **Surface it**: tell the human the ticket exists and what it asks — a record nobody is
   told about escalates nothing. Open tickets are `records.sh list --type tickets --status
   open`.

**Resolving** (when the human answers): write the outcome into **Resolution**, apply whatever
writebacks it implies (flip/annotate the originating tracker line, update linked records),
then close: `/journal done tickets/<file>.md --as done` (`dropped` for a wontfix), note naming
the outcome.
