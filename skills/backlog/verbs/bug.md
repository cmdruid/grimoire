# `bug` — file a reproducible defect

Observed behavior diverging from intended behavior, **with a repro**. If it cannot be
reproduced or pinned yet, it is an `issue` (a concern) until it can. Filing is capture, not
diagnosis — root-causing is the debugger's job, later.

1. Resolve both homes (SKILL.md).
2. **Mint the record**: `scripts/record-mint.sh mint <agent-records> <agent-templates> bugs "<symptom, specific>"` — then fill the
   template's sections: exact repro steps, expected vs. actual **with the real error/trace
   pasted in full**, and notes (suspected surface, related records). The report must stand
   cold: a fresh session should reproduce it from the record alone.
3. **Schedule it if it warrants scheduling**: append a Backlog tracker line (per
   `verbs/task.md` steps 2–4) linking the record — `- [ ] <date> — fix: <symptom> →
   bugs/<file>.md`. A bug nobody will schedule is still worth the record.
4. **Commit per the capture-commit policy** (SKILL.md): standalone → its own scoped commit
   (`Backlog: bug — <slug>`) covering the record and any tracker line; inside a `debrief`
   sweep → write-only.

When the defect is fixed, close the record:
`scripts/record-mint.sh stamp <agent-records> <abs-path> --status done --note "<outcome>"`
(records-mode writes the ledger line; file-mode stamps status only). Then search each
tracker body for `→ bugs/<file>.md` and rewrite every hit to the contract's completed
tracker-line form + `record-mint.sh stamp` (no ledger line for the line-item).

## Done when

- Bug record minted and filled so it stands cold; optional Backlog line linked; standalone
  commit landed (or write-only inside a sweep).
- Close path: stamp wrote the disposition (and a ledger line only when `records.sh` ran);
  linked tracker lines match the contract's completed form and were touched.
