# `ticket` — escalate to the human

A larger item that **needs the human** — a decision, a credential, a sign-off, work only they
can do. A ticket is a standing ask with context, not a chat message that scrolls away.

1. Resolve the records root and the deployed `records.sh` (SKILL.md guard — no records layer → stop and point at `/journal setup`). Before any `records.sh new`, lazy-deploy this skill's `templates/tickets.md` if the deployed copy is absent (SKILL.md).
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
writebacks it implies (originating tracker line → the contract's completed form + `touch`,
update linked records), then close with the deployed tool:
`records.sh done tickets/<file>.md --as done --note "<outcome>"` (`--as dropped` for a
wontfix). Then search each tracker body for `→ tickets/<file>.md` and rewrite every hit
to the contract's completed tracker-line form + `touch`.

## Done when

- Ticket minted, Ask/Context filled, Resolution empty; human told; standalone commit landed
  (or write-only inside a sweep).
- Resolving: Resolution written; `records.sh done` wrote the disposition + ledger line;
  linked tracker lines match the contract's completed form and were touched.
- No records layer: stopped; pointed at standing the layer up.
