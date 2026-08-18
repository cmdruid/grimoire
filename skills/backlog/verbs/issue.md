# `issue` — capture a project problem, concern, or limitation

Something **wrong or risky about the project itself** — an architectural risk, a known
limitation, a maintenance concern. Not a reproducible defect (that is a `bug`), not a thing to
build (that is a `task`), not a dev-experience observation (that is `feedback`).

1. Resolve the records root and the deployed `records.sh` (SKILL.md guard — no records layer → stop and point at `/journal setup`). Before any `records.sh new`, lazy-deploy this skill's `templates/trackers.md` if the deployed copy is absent (SKILL.md).
2. **Find or create the Issues tracker**: `records.sh list --type trackers`, title `Issues`;
   when absent, `records.sh new trackers --title "Issues"`.
3. **Append one line** under `## Items`, newest last, in the contract's live tracker-line
   form: `- [ ] <date> — <the concern, one sentence: what is wrong and where it bites>`.
   When the analysis is substantial, put a defect in a dated `bugs/` record, or mint a
   durable fact through notepad `write` write-only, then link it from the line
   (`→ <store>/<file>.md`).
4. **Stamp**: `records.sh touch <tracker-path>`.
5. **Commit per the capture-commit policy** (SKILL.md): standalone → its own scoped commit
   (`Backlog: issue — <slug>`); inside a `debrief` sweep → write-only.

## Done when

- Issues tracker found or created; one live line appended newest-last; tracker touched;
  standalone commit landed (or write-only inside a sweep).
- No records layer: stopped; pointed at standing the layer up.
