---
template: guide
use-when: "Introduce me to / walk me through / explain how <this project or a part of it> works. An orientation for someone new to the topic, anchored in this codebase."
inputs: records, docs, code
---

# Guide

An introduction for someone who does not know this topic yet — the project as a whole, one of
its subsystems, or a convention it follows. Teaching, not reporting.

**Project-anchored only.** Every guide explains *this* project: how *this* codebase does the
thing. A request to explain a general concept with no anchor here (a language feature, a
protocol in the abstract) is not this template — say so and answer in plain conversation
instead, or point at the real documentation.

## Gather

1. **Resolve the topic** to concrete anchors: paths, docs, records. If nothing in the project
   anchors it, this is the wrong template — stop and say so.
2. `analyst-facts.sh topic --path <paths>` — the records and code surface involved.
3. **Read the project's own documentation first.** A guide that contradicts the project's
   README teaches a reader something they will have to unlearn.
4. **Read the code.** Explain what it actually does, not what the docs claim. Where they differ,
   the code is the truth and the difference is worth a note.
5. **Find the entry point** — where a newcomer would first touch this. A guide with no starting
   place leaves the reader knowing about the topic but unable to use it.

## Synthesize

Structure by **the reader's questions in the order they will ask them**: what is this, why does
it exist, how do I use it, what will bite me.

Start from what the reader already knows and build one step at a time. Name every concept the
first time it appears — a guide that assumes the project's vocabulary is a reference, not a
guide.

Prefer a worked example over description: a concrete path through the mechanism teaches more
than a paragraph about it.

Include what commonly goes wrong. The traps are usually the most valuable part, and they are
already recorded — in gotchas docs, bug records, and debrief findings.

Cite sources so the reader can go deeper, but keep the prose readable — this is the one report
kind where flow matters more than density of citation.

## Skeleton

```markdown
# <Topic> — a guide

## What this is
<Plain-language explanation, assuming no prior knowledge of the topic.>

## Why it exists
<The problem it solves; the decision that created it. (`<record>`)>

## How it works
<The mechanism, one step at a time, with a worked example. (`<paths>`)>

## Using it
<Where to start; the first thing to touch; the common path.>

## What bites
<Known traps, with their evidence. (`<gotchas / bug records>`)>

## Going deeper
<Pointers to the records, docs, and code that carry the full story.>
```
