---
template: subsystem
use-when: "Report on the current state and history of <a module, component, or domain> — for someone who already works here and needs its condition, decisions, and known problems. To TEACH the topic to a newcomer instead, use the guide."
inputs: records, git, code
---

# Subsystem report

The state of one named part of the project: what it is, how it got here, what is known to be
wrong with it, and where it is heading. **State, not quality** — no score, no grade.

## Gather

1. **Resolve the subsystem** to concrete paths. If the name is ambiguous, ask rather than
   reporting on the wrong module.
2. `analyst-facts.sh subsystem <root> --path <paths>` — records referencing it, commit history and
   churn, contributors.
3. **Read the governing decisions** — the ADRs and design records that constrain it. These
   explain *why* it looks the way it does; without them a report describes shape without cause.
4. **Read the code as grounding.** Records go stale; the code is what runs. Verify the claims
   the records imply — a documented mechanism that no longer exists is the most valuable thing
   this report can surface.
5. **Known problems**: open bug records and tracker lines naming it.

## Synthesize

Open with **what it does and where it lives** — a reader may know nothing about it.

Then how it got here: the decisions that shaped it, in causal order, not chronological listing.
Then its current state, grounded in code you actually read.

Where a record and the code **disagree**, say so explicitly and cite both. That is drift, and it
is a fact, not a verdict.

Distinguish carefully between "recorded as a known problem" (cite the record) and "I observed
this while reading" (say you observed it). Never let the second masquerade as the first, and
never turn either into a quality judgment — report that a problem is *recorded*, not that the
code is bad.

## Skeleton

```markdown
# <Subsystem> — state report

## In short
<What it does, where it lives, its current condition in two or three sentences.>

## What it is
<Role in the system; entry points; key files. (`<paths>`)>

## How it got here
<The decisions that shaped it and their consequences. (`<adr/design records>`)>

## Current state
<Grounded in the code as read. Note the commit the reading was made against.>

## Known problems
- <recorded problem> (`<bug record / tracker line>`)

## Drift
<Where records and code disagree, both cited. Omit if none found.>
```
