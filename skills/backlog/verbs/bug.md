# `bug` — file a reproducible defect

Observed behavior diverging from intended behavior, **with a repro**. If it cannot be
reproduced or pinned yet, it is an `issue` (a concern) until it can. Filing is capture, not
diagnosis — root-causing is the debugger's job, later.

1. Resolve the records root and the deployed `records.sh` (SKILL.md guard — no records layer → stop and point at `/journal setup`).
2. **Mint the record**: `records.sh new bugs --title "<symptom, specific>"` — then fill the
   template's sections: exact repro steps, expected vs. actual **with the real error/trace
   pasted in full**, and notes (suspected surface, related records). The report must stand
   cold: a fresh session should reproduce it from the record alone.
3. **Schedule it if it warrants scheduling**: append a Backlog tracker line (per
   `verbs/task.md` steps 2–4) linking the record — `- [ ] <date> — fix: <symptom> →
   bugs/<file>.md`. A bug nobody will schedule is still worth the record.
4. **Commit per the capture-commit policy** (SKILL.md): standalone → its own scoped commit
   (`Backlog: bug — <slug>`) covering the record and any tracker line; inside a `debrief`
   sweep → write-only.

When the defect is fixed, close the record: `/journal done bugs/<file>.md` (and flip the
tracker line).
