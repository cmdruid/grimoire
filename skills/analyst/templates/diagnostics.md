---
template: diagnostics
use-when: "Is the project healthy — are builds and tests passing, are defects and stale records piling up. Health and hygiene facts, never a quality score. For what WORK is in flight or blocked, use the status snapshot instead."
inputs: audit-reports, bug-records, stale-records, trackers, gate-state
---

# Diagnostics — project health snapshot

Health **facts**, assembled in one place: what the project's own instruments last reported,
what defects are open, where the records have gone stale.

**Two hard limits.** This report does not **score** — no rubric, no grade, no "quality is
declining." And it does not **root-cause** — surfacing "test X has failed since Tuesday" is the
whole job; chasing why is a separate invocation of the debugging discipline. Report the fact and
stop.

## Gather

1. `analyst-facts.sh health <root>` — open bug records, stale records (`open` with old `updated:`),
   tracker debt, ledger cadence.
2. **Prefer the project's own instruments.** If the project runs a code-quality audit, its
   latest audit reports are the authority on scored health — read them and **attribute** the
   numbers to that audit with its date. Never re-derive a score, and never restate an audit's
   verdict as your own finding.
3. **Gate state**: read what is already recorded — the last audit's invariant check, CI status
   files, a recorded gate result. **Never run the project's gate, build, or test commands**;
   they are slow, may mutate state, and are not this skill's business. If nothing recent is
   recorded, report gate state as **unknown** and say when it was last known.

## Synthesize

Lead with what a maintainer would act on today: failing gates, open defects, anything with an
age that has crossed from "recent" into "neglected."

**Attribute every number.** "17 findings (audit of 2026-08-02)" — a bare number with no source
and no date is worse than no number, because it reads as current.

Where a fact is **absent**, say so rather than omitting it. "No gate result recorded since
2026-07-30" is a health fact; silence looks like health.

Age is reported, never interpreted. "Open 94 days" is a fact. "Neglected" is a judgment — leave
it to the reader.

## Skeleton

```markdown
# Health snapshot — <project>, <date>

## In short
<Two or three sentences of what a maintainer should know today.>

## Gates and tests
<Last recorded state, with its date and source. "Unknown since <date>" is a valid entry.>

## Open defects
- <bug> — open <duration>. (`<bug record>`)

## Audit findings
<Only what the project's own audits reported, attributed and dated. Omit if none exist.>

## Record hygiene
<Stale open records, tracker debt, ledger gaps — counts with their evidence.>

## Not known
<Health facts that could not be established, and why. Omit only if genuinely nothing.>
```
