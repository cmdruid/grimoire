---
name: developer-writing
description: "Use when the requested outcome is human-facing developer prose: documentation, API reference, tutorials, README procedures, PR descriptions, release notes, design explanations, and technical summaries. Trigger on a writing outcome, not project investigation or technical correctness review. Do not trigger for agent-executed operational artifacts such as implementation plans, runbooks, task queues, handoffs, or workflow state unless the user explicitly requests editorial help on one. Applies purpose-aware structure, human editorial judgment, and Google developer documentation mechanics. Keywords: developer writing, technical writing, developer docs, PR description, release notes, Google style, /developer-writing."
---

# Developer writing

Write like a knowledgeable maintainer who understands what the developer needs. Be conversational,
not cute. Project voice and terminology win when they conflict. Clear beats house-style pedantry.

This package combines an original purpose-aware editorial method with compact mechanics adapted
from the [Google developer documentation style guide](https://developers.google.com/style), built
against 2026-08-17. The live guide is the authority for disputed Google style; this package does not
fetch it.

Disposition: **pure mechanism** — no home to scaffold.

## Frame the document

Identify the reader and the document's job before drafting:

- **Procedure:** Help the reader complete a task.
- **Reference:** Help the reader find an exact fact.
- **Explanation:** Help the reader understand what, why, and consequences.
- **Change communication:** Help a reviewer find consequential changes, rationale, and effects.

These are decisions, not required headings. For an explanation, PR description, or release note,
read [`references/human-editing.md`](references/human-editing.md).

Lead with the outcome and why it matters. Organize around the reader's likely questions, not the
author's investigation or validation sequence. Include proof or validation details only when the
reader needs them to evaluate a claim or act safely.

## Operational artifacts

An operational artifact's primary job is to control future execution rather than explain something
to a human. This skill does not normally apply to implementation plans, runbooks, task queues, agent
handoffs, or workflow state.

When the user explicitly requests editorial help on one, edit only explanatory prose outside its
protected control content. The artifact's governing schema and project conventions win. Preserve
verbatim and in place its execution order, dependencies, exact paths, local constraints,
verification steps, expected results, structured fields and checkboxes, and completion or
resumption state. Don't delete, merge, relocate, rephrase, narrow, generalize, or deduplicate those
elements. Their placement and repetition are part of the execution contract, including when a
critical constraint appears beside every action it governs.

## Draft

- Address the reader as `you`. A `user` is someone the reader's software serves.
- Put a section's point first. Group details that share one reason.
- Explain consequential behavior, rationale, risks, and limitations. State a boundary once near the
  topic it qualifies.
- Prefer representative links over a source index. Mention a fact again only when repetition helps
  the reader act.
- Make factual claims. Write as the maintainer explaining the work, not as an auditor certifying it.

When a word feels off, read [`references/word-list.md`](references/word-list.md). If it still isn't
there: use the primary sense, the first Merriam-Webster spelling, and one term per concept.

## Google mechanics

- Task heading → bare infinitive (`Create a VM`). Concept heading → noun phrase (`VM networking
  overview`). Use sentence case and no leading gerund.
- Use imperatives for steps. Required → *must* or an imperative. Suggested → *We recommend*.
  Optional → *can*. Possible → *might*.
- Prefer active, present-tense sentences. Software specifies, returns, or detects.
- Use contractions on negatives. Keep *a* / *an* / *the*, including in headings.
- Keep product documentation timeless; don't promise a next release.
- API method blurbs use third-person singular: `Creates a task`, not `Create a task`.

| Thing | Mark it |
|---|---|
| UI label | **bold** |
| Code, filename, method, flag, HTTP code, input | `code` |
| Word-as-word, new term | _italics_ |
| Placeholder | `UPPER_SNAKE_CASE` |
| Date | January 19, 2017 or `2017-04-15` |
| Time | 3 PM, 3:45 PM |
| Key | Control+S (Command+S on macOS) |

- Numbered lists are sequences; bullets are unordered. A one-step procedure is one bullet.
- Introduce a list with a complete sentence, usually ending in a colon. Keep items parallel.
- Use one unique `h1`; don't skip heading levels.
- Spell out zero through nine; use numerals from 10. Always use numerals for versions,
  measurements, steps, and percents (`40%`).

## Procedures

For each step, include only useful elements in this order: location → condition or goal → action →
result. Don't repeat context or add a result that tells the reader nothing.

```
1. In TOOL, to GOAL, ACTION.
   command
   Replace `PLACEHOLDER` with …
   Result sentence.
```

Use one action per step. Prefix optional steps with `Optional:`. Say what a command does. For a menu
path, write `Click **File > New > Document**.`

## Edit silently

Apply this guidance without mentioning the rubric, editing process, confidence, or assurance
framework in the finished prose. Before returning the draft, ask silently:

1. Can the intended reader identify the outcome and rationale quickly?
2. Does each section answer a question the reader is likely to have?
3. Can a heading, table, caveat, link, or repeated fact be removed without losing useful meaning?
4. Does the prose sound like a knowledgeable maintainer rather than a review system describing its
   controls?
5. Are the remaining Google-style mechanics correct?

Done when the document serves its identified purpose, preserves consequential information, and
contains no removable review scaffolding.

## Edges

<!-- edges:developer-writing -->
- produces: — (styles caller-owned prose in the calling context, not a new typed artifact)
- handoff: — (none; styles the caller's draft, does not terminate a workflow)
- consumes: — (none; reads the caller's writing task, not a typed artifact)
<!-- /edges:developer-writing -->
