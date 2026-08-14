# `curate` — tracker grooming

Keep the trackers actionable: a tracker whose lines are stale, vague, or duplicated stops
being trusted, and an untrusted tracker stops being used. Curation is **hygiene, never
draining**: it may merge, sharpen, re-rank, and flip; it never decides what a signal *means*
for the system — that judgment lives downstream. This is the workflow's half of curation —
record-level hygiene (contract conformance, link rot, prune proposals) is the format
authority's half, not this verb's.

1. Resolve the records root and the deployed `records.sh` (SKILL.md guard — no records layer
   → stop and point at `/journal setup`).
2. **Walk each tracker** (`records.sh list --type trackers`): dedupe overlapping lines (merge
   into the sharper one), reword vague items until they act cold, re-order by priority (top =
   next), flip lines that completed without ceremony (`[x]` + date), and drop lines that no
   longer apply (strike or delete — the tracker body is not a ledger). `records.sh touch`
   every tracker edited.
3. **Graduate what outgrew its line**: an item that now needs the human becomes a `ticket`
   (`verbs/ticket.md` — link the line to the record); detail that outgrew one sentence gets a
   dated record, linked from the line.
4. **One scoped commit** over everything touched
   (`scripts/scoped-commit.sh <root> "Backlog: curate" <paths…>`) when standalone; write-only
   inside a larger sweep.
