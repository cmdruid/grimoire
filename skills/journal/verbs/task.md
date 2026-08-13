# `task` — capture a thing to build

A product/feature follow-up: something someone should **build or change**, cut by subject —
a reproducible defect is a `bug`; a project problem/concern is an `issue`; a durable fact is a
`note`. When the item needs the human, not a builder, it is a `ticket`.

1. Resolve the records root (SKILL.md discipline); stand the layer up lazily if missing.
2. **Find or create the Backlog tracker**: `records.sh list --type trackers` and match the
   title `Backlog`; when absent, `records.sh new trackers --title "Backlog"`.
3. **Append one line** under `## Items`, newest last:
   `- [ ] <date> — <the item, one sentence, concrete enough to act on cold>`
   (date from `records.sh`/`date +%Y-%m-%d`, never guessed). Link a related record with
   `→ <store>/<file>.md` when one exists. Keep it one line — detail that doesn't fit belongs
   in a linked record.
4. **Stamp**: `records.sh touch <tracker-path>`.
5. **Commit per the capture-commit policy** (SKILL.md): standalone → its own scoped commit
   (`Journal: task — <slug>`); inside a `debrief` sweep → write-only.
