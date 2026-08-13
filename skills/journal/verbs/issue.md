# `issue` — capture a project problem, concern, or limitation

Something **wrong or risky about the project itself** — an architectural risk, a known
limitation, a maintenance concern. Not a reproducible defect (that is a `bug`), not a thing to
build (that is a `task`), not a dev-experience observation (that is `feedback`).

1. Resolve the records root (SKILL.md discipline); stand the layer up lazily if missing.
2. **Find or create the Issues tracker**: `records.sh list --type trackers`, title `Issues`;
   when absent, `records.sh new trackers --title "Issues"`.
3. **Append one line** under `## Items`, newest last:
   `- [ ] <date> — <the concern, one sentence: what is wrong and where it bites>`.
   When the analysis is substantial, put it in a dated `bugs/` or `notes/` record and link it
   from the line (`→ <store>/<file>.md`).
4. **Stamp**: `records.sh touch <tracker-path>`.
5. **Commit per the capture-commit policy** (SKILL.md): standalone → its own scoped commit
   (`Journal: issue — <slug>`); inside a `debrief` sweep → write-only.
