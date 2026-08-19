# `issue` — capture a project problem, concern, or limitation

Something **wrong or risky about the project itself** — an architectural risk, a known
limitation, a maintenance concern. One sentence: what is wrong and where it bites.
Substantial analysis stays one sentence or is split into two lines.

1. Resolve both homes (SKILL.md).
2. **Find or create the Issues tracker**: if `records.sh` is executable,
   `records.sh list --type trackers`, title `Issues`; else scan live
   `<agent-records>/trackers/*.md` by H1. When absent,
   `scripts/record-mint.sh mint <agent-records> <templates-home> trackers "Issues"`.
3. **Append one line** under `## Items`, newest last, in the contract's live tracker-line
   form: `- [ ] <date> — <the concern, one sentence: what is wrong and where it bites>`.
   An ask that must survive a reset uses the leftover form
   `needs human: <the ask, one sentence>`.
4. **Stamp**: `scripts/record-mint.sh stamp <agent-records> <tracker-path>`.
5. **Commit per the capture-commit policy** (SKILL.md): standalone → its own scoped commit
   (`Backlog: issue — <slug>`); inside a `debrief` sweep → write-only.

## Done when

- Issues tracker found or created; one live line appended newest-last; tracker touched;
  standalone commit landed (or write-only inside a sweep).
