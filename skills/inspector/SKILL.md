---
name: inspector
description: "Use when the user runs `/inspector`, or asks to review a spec or plan (or named kind), to apply review findings or amend a needs-rework artifact, or to ask how we should refine or revise this. Critique and fold as one skill. review dumps a conversation verdict. refine is propose-then-apply and leaves the artifact draft. Does not mint a record and does not write published. Bare `/inspector` asks which verb. For a one-line patch, skip it."
---

# inspector — critique and fold

Independent second-set-of-eyes, then the fold back. Owns both
artifact sets: specs / ADRs / founding-shaped files, and plans /
roadmaps / runbooks. Kind-detect, then the matching judgment.
Hosts may add kinds.

This `SKILL.md` is a **thin router**: the probe, kind-detect, the
dispatch table, the seams every verb shares, and the typed edges.
Each verb's procedure lives in `verbs/` (see the dispatch table).
When a verb is selected, **read its file and follow it**.

This skill is **self-contained and uniquely named**: it depends on no other skill
and collides with none.

There is no `init` and no `setup`. Missing
`<agent-workspace>/inspector/` is not a refuse — use the bundled
`kinds/<kind>.md`.

## One environment probe (at entry)

Station context is doctrine, so it lives at `<agent-workspace>/doctrine`: the
declared `agent-workspace:` (front-door `AGENTS.md` then `CLAUDE.md`), else
`.dev` — by default `.dev/doctrine/`. Resolving the home is
not finding the artifact — resolve it, **then** test for the matching
station's loader after kind-detect. Nothing else is probed, and no verb
ever refuses or stalls for lack of one.

- spec / adr / founding → design station
  (`<agent-workspace>/doctrine/scripts/context.sh design`) when present
- plan / roadmap / runbook → build station
  (`<agent-workspace>/doctrine/scripts/context.sh build`) when present
- Absent loader → the project's own design docs and READMEs stand in
  for station context

**Kind templates** land at `<agent-workspace>/inspector/<kind>.md`
(default `.dev/inspector/<kind>.md`). No new front-door variable.
Incumbent wins; upgrade is a judgment-assisted diff. Load the
workspace copy if present, else the bundled `kinds/<kind>.md`.

`mkdir` of `<agent-workspace>/inspector/` only when
`<agent-workspace>` already exists or is the derived default `.dev`
(creates `.dev` as a container for `inspector/`, never `doctrine/`).
Declared `agent-workspace:` that is absent → do not create; use the
bundle. Never create a declared-absent workspace.

This package does **not** mint records.

**Status vocabulary.** The `status` enum is
`specs/records-front-matter.md`. Writer `stage` values are in-package
(journal does not own them):

- **review** writes neither `status` nor `stage`.
- **refine** leaves `status: draft` and drops `stage: approved` if
  present.
- This package does **not** write `published`.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does |
|---|---|---|
| `review` | `verbs/review.md` | two-axis critique; conversation verdict |
| `refine` | `verbs/refine.md` | classify findings, propose amendments, fold on confirm |
| (bare) | — | **ask** which verb; do not default |

```
review  →  (caller publishes)        →  (host sequences / walk)
        →  stay draft                →  refine  →  review  →  …
```

Each arrow is a stop. No verb invokes the next, except a `refine`
confirmation that asks for `review` after apply.

## Kind-detect (review and refine, once)

Kind-detect is the **only** artifact gate. Unknown kind → ask or
refuse; do not invent a rubric. The six bundled kinds are in-scope.
Hosts add files; they do not invent a rubric at runtime.

1. Read the artifact. Classify from `tags:` / `doctype` / shape,
   then the founding-shaped parser in `kinds/founding.md` (try
   founding **before** spec — both may carry a spec tag).
2. Resolve `<agent-workspace>` (front-door `agent-workspace:`, else
   `.dev`). Test for `<agent-workspace>/inspector/<kind>.md`.
   Present → use it. Absent → bundled `kinds/<kind>.md`.
3. No matching discriminator among workspace files and bundled
   kinds → ask or refuse. Do not invent a rubric.
4. Axes, groundedness extras, and refine legal locations come
   **from the kind file**. Verb files own the shared machine
   (verdict words, confirm parse, apply rules that are not
   kind-specific). Kind files do not override those.

Match order for bundled kinds: founding, then spec, adr, plan,
roadmap, runbook. A workspace kind with its own discriminator is
tried against the same artifact; first confident match wins. If
two match, ask.

## Brief the human (every verb)

The artifact holds `status: draft` / `published`. The conversation
does not open with it. Verdict words stay conversation-only.

- **Lead with the situation** a newcomer could use: what is wrong
  with the document, or that it is ready. Then the path.
- **One ask per stop.** After `review`, stop. After `refine`:
  questions (when they fire) are a stop; the proposal is a stop;
  after apply without named re-review, the offer is a stop.
  Named re-review is the exception.
- **Translate the closing code.** "The tests would go green and
  still encode the wrong scripts" not a bare `needs-rework`.

## Shared discipline (every verb)

- **Read the verb file.** Do not reconstruct a procedure from this router.
- **Scripts from this package.** `scripts/ground-check.sh` is this
  skill's copy — resolve it from this skill's own base directory,
  never a host path.
- **Kind file from this package** (or the workspace incumbent).
  Resolve `kinds/` from this skill's own base directory.
- Do not mint a record. Do not write `published`.

## Edges

In-place steward: no private home. Verdict is conversation-only.

<!-- edges:inspector -->
- produces: — (verdict is conversation-only; refine amends the named file in place)
- handoff: — (none; the caller publishes or the host sequences)
- consumes: spec, plan, review, doctrine — artifacts under review; a findings baton (in-session list, named markdown, council RESULT.md); station context
<!-- /edges:inspector -->
