# `task` — capture a thing to build

A product/feature follow-up: something someone should **build or change**, cut by subject —
a reproducible defect is a `bug`; a project problem/concern is an `issue`; a durable fact is a
`note`. When the item needs the human, not a builder, it is a `ticket`.

1. Resolve both homes (SKILL.md).
2. **Find or create the Backlog tracker**: if `records.sh` is executable,
   `records.sh list --type trackers` and match the title `Backlog`; else scan
   live `<agent-records>/trackers/*.md` by H1. When absent,
   `scripts/record-mint.sh mint <agent-records> <agent-templates> trackers "Backlog"`.
3. **Append one line** under `## Items`, newest last, in the contract's live tracker-line
   form: `- [ ] <date> — <the item, one sentence, concrete enough to act on cold>`
   (date from `date +%Y-%m-%d`, never guessed). Link a related record with
   `→ <store>/<file>.md` when one exists. Keep it one line — detail that doesn't fit belongs
   in a linked record.
4. **Stamp**: `scripts/record-mint.sh stamp <agent-records> <tracker-path>`.
5. **Commit per the capture-commit policy** (SKILL.md): standalone → its own scoped commit
   (`Backlog: task — <slug>`); inside a `debrief` sweep → write-only.

## Done when

- Backlog tracker found or created; one live line appended newest-last; tracker touched;
  standalone commit landed (or write-only inside a sweep).
