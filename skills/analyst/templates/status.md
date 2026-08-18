---
template: status
use-when: "What work is in flight, blocked, or queued right now. A snapshot of the present with no time span — about WORK and its blockers, not about build/test health (that is the health snapshot)."
inputs: trackers, open-records, streams
---

# Status

A snapshot of **now**. No history, no span — what is in flight, what is blocked, what is
waiting on a person.

## Gather

1. `analyst-facts.sh status <root>` — open records by store, tracker line counts, active streams,
   uncommitted/unlanded work.
2. Read the **trackers** themselves. Their line text is the state; counts alone say nothing.
3. For each in-flight item, find its **last movement** (record `updated:`, last commit touching
   it). Age is the signal that separates "in progress" from "stalled."

## Synthesize

Sort by what the reader can act on: **blocked** first (someone is waiting), then **in flight**,
then **queued**. Within blocked, name what each is blocked *on* — a person, a decision, an
external event. "Blocked" with no blocker named is not a status, it is a shrug.

Flag **staleness** honestly: an item in flight with no movement in weeks is a fact worth
stating, not a judgment about anyone. Report the age; draw no conclusion about why.

Do not editorialize about volume. A long backlog is not a finding.

## Skeleton

```markdown
# Status — <project> as of <date>

## In short
<One or two sentences: what is actually moving right now.>

## Blocked
- <item> — blocked on <what/whom> since <when>. (`<source>`)

## In flight
- <item> — <state>; last movement <when>. (`<source>`)

## Queued
- <item> (`<source>`)

## Notes
<Stalled items, anything waiting on the reader. Omit if none.>
```
