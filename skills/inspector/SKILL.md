---
name: inspector
description: "Use when the user runs `/inspector`, asks to review a document or completed implementation, wants findings folded into an artifact, asks how to refine or revise one, or wants Inspector's project doctrine deployed. Review is an adequate, material two-axis judgment; accepted passing document reviews publish, implementation verdicts never mutate; refine is propose-then-apply and leaves draft; setup seeds kinds absent-only. Does not mint records. Bare `/inspector` asks which verb. For a one-line patch, skip it."
---

# inspector — critique and fold

Independent second-set-of-eyes, then the fold back. Owns document
review for specs / ADRs / founding-shaped files and plans / roadmaps /
runbooks, plus review of completed implementations. Kind-detect, then
the matching judgment. Hosts may add document kinds.

This `SKILL.md` is a **thin router**: kind-detect, the
dispatch table, the seams every verb shares, and the typed edges.
Each verb's procedure lives in `verbs/` (see the dispatch table).
When a verb is selected, **read its file and follow it**.

This skill is **self-contained** and depends on no other skill.

There is no `init`. Explicit `/inspector setup [<root>]` deploys Inspector's bundled kinds
for project customization. Missing `<agent-workspace>/inspector/doctrine/`
is not a refuse — use the bundled `kinds/<kind>.md`.

**Kind doctrine** lands at `<agent-workspace>/inspector/doctrine/<kind>.md`
(default `.spaces/inspector/doctrine/<kind>.md`). No new front-door variable.
Incumbent wins; upgrade is a judgment-assisted diff. Load the complete
workspace copy when it is a readable regular file, else the bundled
`kinds/<kind>.md` when absent. A symlink, directory, other incompatible
entry, or unreadable file is an error — never a fallback and never a merge.

Review and refine are not setup operations: they never create this
namespace. An absent workspace or kind file uses the bundle.

This package does **not** mint records.

**Status vocabulary.** Writer `stage` values are in-package:

- **review** writes neither `status` nor `stage` in the verdict
  turn. On accept of a passing verdict, this session writes
  `published` (job artifacts: also `stage: approved`).
  Founding-shaped: no write; stay `draft`. Implementation review never
  writes status or stage.
- **refine** leaves `status: draft` and drops `stage: approved` if
  present.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does |
|---|---|---|
| `review` | `verbs/review.md` | two-axis critique; conversation verdict |
| `refine` | `verbs/refine.md` | classify findings, propose amendments, fold on confirm; a failed-review chain re-reviews by default |
| `/inspector setup [<root>]` | `verbs/setup.md` | deploy all bundled kind doctrine absent-only |
| (bare) | — | **ask** which verb; do not default |

```
document review  →  accept/publish   →  (host sequences / walk)
needs-rework     →  refine proposal  →  approve/apply + queued review  →  …
implementation review → verdict only
```

Each arrow is a stop. A `refine` entered directly from a failing document review carries a queued
re-review: approval applies the proposal and immediately runs the existing `review` procedure.
Standalone `refine` invokes review only when its confirmation names re-review.

## Kind-detect (review and refine, once)

Kind-detect is the **only** target gate. Unknown kind → ask or refuse;
do not invent a rubric. The seven bundled kinds are in-scope. Hosts
add document-kind files; they do not invent a rubric at runtime.

1. Resolve `<agent-workspace>` (front-door `agent-workspace:`, else
   `.spaces`) and the optional `inspector/doctrine/` directory. Never create
   it here. For each bundled stem, a readable regular project file is
   the complete effective policy; absence uses bundled `kinds/<kind>.md`.
   Symlinks, directories, other incompatible entries, and unreadable
   files are errors. Never merge or dual-read.
2. Read the target. Try the effective document policies in this order:
   founding, spec, adr, plan, roadmap, runbook. Founding is before spec
   because both may carry a spec tag. Then try additional readable,
   regular project `doctrine/*.md` policies in filename order. If two
   document discriminators match, ask.
3. Only after every document kind fails, an explicit named diff, range,
   worktree, or commit may match the effective `implementation` policy.
   Resolve its governing design when named or discoverable from the
   change context. A document never falls through to implementation.
4. No matching discriminator among workspace files and bundled kinds →
   ask or refuse. Do not invent a rubric.
5. Axes, groundedness extras, and refine legal locations come
   **from the kind file**. Verb files own the shared machine
   (verdict words, confirm parse, apply rules that are not
   kind-specific). Kind files do not override those.

Host-added policies extend document review only; they cannot replace the
reserved `implementation` discriminator or create a code-refine path.

## Brief the human (every verb)

The artifact holds `status: draft` / `published`. The conversation
does not open with it. Verdict words stay conversation-only.

- **Lead with the situation** a newcomer could use: what is wrong
  with the document, or that it is ready. Then the path.
- **One ask per stop.** After a passing `review`, accept is a
  stop; the publish write is that stop. After `refine`:
  questions (when they fire) are a stop; the proposal is a stop;
  approval of a failed-review fold runs its queued re-review; after
  standalone apply without named re-review, the offer is a stop.
- **Translate the closing code.** "The tests would go green and
  still encode the wrong scripts" not a bare `needs-rework`.

## Shared discipline (every verb)

- **Read the verb file.** Do not reconstruct a procedure from this router.
- **Scripts from this package.** `scripts/ground-check.sh` is this
  skill's copy — resolve it from this skill's own base directory,
  never a host path.
- **Kind file from this package** (or the workspace incumbent).
  Resolve `kinds/` from this skill's own base directory.
- Do not mint a record. Do not write `published` in the
  `review` verdict turn.

## Edges

No private runtime store. Explicit `setup` may deploy project-customizable kind doctrine;
verdicts remain conversation-only.

<!-- edges:inspector -->
- produces: doctrine — setup deploys Inspector-owned kind policy; verdict is conversation-only; accepted passing document review publishes, and refine amends in place
- handoff: — (none; after publish the host sequences)
- consumes: spec, plan, review, doctrine — artifacts or completed changes under review; a findings baton; optional project kind policy
<!-- /edges:inspector -->

## Done when

The selected verb's done-when holds: the kind and effective policy were resolved without fallback
through an invalid incumbent, each documented stop was honored, and no verb wrote outside its
declared review/refine/setup boundary.
