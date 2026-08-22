---
template: briefing
use-when: "Catch me up / what happened / what's changed since <a point in time>. A span-shaped review of work landed, decisions taken, and what's still open."
inputs: span, ledger, closed-records, trackers, commits
---

# Briefing

The flagship report: what happened in a span, why it mattered, and what is still moving.
Written for someone who was away and needs to act — not a changelog, not a commit dump.

## Gather

1. **Resolve the span** and say which anchor you used (explicit → last persisted briefing →
   14 calendar days). Report the anchor in the output; never leave it implicit.
2. `analyst-facts.sh span <root> --since <anchor>` — closures in span, records touched,
   commit counts by area. Tracker line state is not in that output — read the tracker
   records yourself for "what's still moving."
3. **Read what the closures point at.** A ledger line is a fact; the story is in the closed
   record — the plan's goal, the debrief's findings, an ADR's decision. Read them, not just
   their titles.
4. **Open items**: trackers plus any record still `draft` whose activity falls in the span. A
   catch-up without "what's still moving" is half a briefing.

## Synthesize

Group by **theme, not by store** — a reader thinks in features and problems, not in `plans/` vs
`reports/`. Within each theme, lead with the outcome and follow with why it mattered.

Judge what earns a line: a shipped feature, a reversed decision, a new constraint, a blocker
that appeared. Routine churn (formatting, dependency bumps, docs typos) belongs in one summary
sentence, if at all. **Translate** — "closed plan: records-root declaration" becomes "projects
can now declare a custom records directory."

Cite every claim with the record path or `file:line` that supports it. A briefing the reader
cannot check is gossip.

If a decision in the span **contradicts** an earlier one, say so plainly and cite both — an
inherited assumption quietly reversed is the single most expensive thing to miss.

## Skeleton

```markdown
# Briefing — <span description>

_Anchor: <what the span was measured from, and why that anchor>._

## In short
<Two or three sentences: the shape of the span. What a reader who stops here must know.>

## Landed
- **<theme>** — <what changed and what it means>. (`<source path>`)

## Decisions
- <decision> — <consequence for the reader>. (`<adr/record path>`)

## Still open
- <item> — <state, and what it is waiting on>. (`<tracker/record>`)

## Worth your attention
<Contradictions, risks, or things the reader should act on. Omit if genuinely none.>
```
