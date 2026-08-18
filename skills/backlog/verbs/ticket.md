# `ticket` — escalate to the human

A larger item that **needs the human** — a decision, a credential, a sign-off, work only they
can do. A ticket is a standing ask with context, not a chat message that scrolls away.

1. Resolve both homes (SKILL.md).
2. **Mint the record**: `scripts/record-mint.sh mint <agent-records> <agent-templates> tickets "<the ask, as a headline>"` — fill
   the template: **Ask** (one clear question or request), **Context** (enough to answer
   without re-deriving: what surfaced it, what was tried, links to related records), leave
   **Resolution** empty. If the ticket graduates an existing tracker line, link that line to
   the ticket (`→ tickets/<file>.md`) rather than deleting it.
3. **Commit per the capture-commit policy** (SKILL.md): standalone → its own scoped commit
   (`Backlog: ticket — <slug>`); inside a `debrief` sweep → write-only.
4. **Surface it**: tell the human the ticket exists and what it asks — a record nobody is
   told about escalates nothing. Open tickets are `records.sh list --type tickets --status
   open` when the tool exists; else scan live `<agent-records>/tickets/*.md`.

**Resolving** (when the human answers): write the outcome into **Resolution**, apply whatever
writebacks it implies (originating tracker line → the contract's completed form + `touch`,
update linked records), then close with the deployed tool:
`scripts/record-mint.sh stamp <agent-records> <abs-path> --status done --note "<outcome>"`
(`--status dropped` for a wontfix). Then search each tracker body for
`→ tickets/<file>.md` and rewrite every hit to the contract's completed tracker-line
form + `record-mint.sh stamp`.

## Done when

- Ticket minted, Ask/Context filled, Resolution empty; human told; standalone commit landed
  (or write-only inside a sweep).
- Resolving: Resolution written; stamp wrote the disposition (and a ledger line only when
  `records.sh` ran); linked tracker lines match the contract's completed form and were
  touched.
