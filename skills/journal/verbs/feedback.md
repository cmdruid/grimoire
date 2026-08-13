# `feedback` — capture a dev-experience observation

How the **development system** felt in use — a gate too slow, docs too heavy, a skill that
misfired, a workflow that sang. Signal about the tooling/process, not about the product (that
is a `task`/`issue`). Capture honestly, both directions; the improvement loop judges meaning
downstream.

1. Resolve the records root (SKILL.md discipline); stand the layer up lazily if missing.
2. **Find or create the Feedback tracker**: `records.sh list --type trackers`, title
   `Feedback`; when absent, `records.sh new trackers --title "Feedback"`.
3. **Append one line** under `## Items`, newest last:
   `- [ ] <date> — [<surface, e.g. the skill or gate name>] <the observation, one sentence>`.
4. **Stamp**: `records.sh touch <tracker-path>`.
5. **Commit per the capture-commit policy** (SKILL.md): standalone → its own scoped commit
   (`Journal: feedback — <slug>`); inside a `debrief` sweep → write-only.
