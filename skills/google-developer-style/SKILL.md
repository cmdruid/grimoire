---
name: google-developer-style
description: "Use when writing or editing developer documentation, API docs, tutorials, how-tos, README procedures, or technical prose in the Google developer documentation style. Keywords: Google style, Google developers writing style, developer docs style, /google-developer-style."
---

# Google developer style

Write like a knowledgeable friend who already knows what the developer wants to do. Conversational, not cute. Project style wins if it conflicts. Clear beats house-style pedantry.

Snapshot of the [Google developer documentation style guide](https://developers.google.com/style), built against 2026-08-17. If a term is disputed, the live guide is the authority — this package does not fetch it.

Disposition: **pure mechanism** — no home to scaffold.

## Write

1. **Name the reader.** `you` does the work. `user` is who *their* software serves.
2. **Pick the heading.** Task → bare infinitive (`Create a VM`). Concept → noun phrase (`VM networking overview`). Sentence case. No leading gerund.
3. **Draft every instruction** as location → condition or goal → action → result.
4. **Self-edit.** Done only when the checklist below is all true.

When a word feels off, read [`references/word-list.md`](references/word-list.md). If it still isn't there: primary sense, first Merriam-Webster spelling, one term per concept.

## Voice

- Imperative for steps. Recommend one path. Required → *must* or an imperative. Suggested → *We recommend*. Optional → *can*. Possible → *might*.
- Active, present. Software specifies, returns, detects.
- Contractions on negatives. Keep *a* / *an* / *the*, including in headings.
- Product docs are timeless: no next-release promises.
- Verifiable facts only. API method blurbs: `Creates a task`, not `Create a task`.

## Shape

| Thing | Mark it |
|---|---|
| UI label | **bold** |
| Code, filename, method, flag, HTTP code, input | `code` |
| Word-as-word, new term | _italics_ |
| Placeholder | `UPPER_SNAKE_CASE` |
| Date | January 19, 2017 or `2017-04-15` |
| Time | 3 PM, 3:45 PM |
| Key | Control+S (Command+S on macOS) |

- Numbered = sequence. Bullets = unordered. A one-step procedure is one bullet.
- Introduce a list with a complete sentence, usually a colon. Parallel items.
- Unique `h1`. Don't skip heading levels. Point of a paragraph goes first.
- Spell out zero through nine; numerals from 10. Always numerals for versions, measurements, steps, percents (`40%`).

## Procedures

```
1. In TOOL, to GOAL, ACTION.
   command
   Replace `PLACEHOLDER` with …
   Result sentence.
```

One action per step. Prefix optional steps with `Optional:`. Say what a command does. Menu paths: `Click **File > New > Document**.`

## Self-edit

Done when:

- [ ] Reader is `you`
- [ ] Sentence-case headings; tasks are bare infinitives
- [ ] Every instruction is condition or goal, then action
- [ ] UI **bold**, code `code`, placeholders explained
- [ ] Links describe their destination (`For more information, see [Title].`)
- [ ] [`references/word-list.md`](references/word-list.md) applied where a word felt off

## Edges

<!-- edges:google-developer-style -->
- produces: documentation — developer-facing prose in this house style
- handoff: — (none; styles the caller's draft, does not terminate a workflow)
- consumes: — (none; reads the caller's writing task, not a typed artifact)
<!-- /edges:google-developer-style -->
