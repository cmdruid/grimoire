# `feedback` — capture a dev-experience observation

How the **development system** felt in use — a gate too slow, docs too heavy, a skill that
misfired, a workflow that sang. Signal about the tooling/process, not about the product (that
is a `task`/`issue`). Capture honestly, both directions; the improvement loop judges meaning
downstream.

1. Resolve the records root and the deployed `records.sh` (SKILL.md guard — no records layer → stop and point at `/journal setup`). Before any `records.sh new`, lazy-deploy this skill's `templates/trackers.md` if the deployed copy is absent (SKILL.md).
2. **Find or create the Feedback tracker**: `records.sh list --type trackers`, title
   `Feedback`; when absent, `records.sh new trackers --title "Feedback"`.
3. **Append one line** under `## Items`, newest last, in the contract's live tracker-line
   form: `- [ ] <date> — [<surface, e.g. the skill or gate name>] <the observation, one sentence>`.
4. **Stamp**: `records.sh touch <tracker-path>`.
5. **Commit per the capture-commit policy** (SKILL.md): standalone → its own scoped commit
   (`Backlog: feedback — <slug>`); inside a `debrief` sweep → write-only.

## Done when

- Feedback tracker found or created; one live line appended newest-last; tracker touched;
  standalone commit landed (or write-only inside a sweep).
- No records layer: stopped; pointed at standing the layer up.
