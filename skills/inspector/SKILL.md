---
name: inspector
description: "Use when the user runs `/inspector`, asks to review a document or completed implementation, wants supported findings revised into a document, wants a spec or plan simplified, or wants Inspector's project doctrine deployed. Review is a material two-axis judgment; revise corrects findings; refine is an optional minimum-sufficiency pass. Both mutation verbs propose before editing. Does not mint records. Bare `/inspector` asks which verb. For a one-line patch, skip it."
---

# inspector — critique, correct, and simplify

Independent second set of eyes, correction fold, and optional minimum-sufficiency pass. Owns
document review for specs / ADRs / founding-shaped files and plans / roadmaps / runbooks, plus
review of completed implementations. Kind-detect, then the matching judgment. Hosts may add
document kinds.

This `SKILL.md` is a **thin router**: kind-detect, the
dispatch table, the seams every verb shares, and the typed edges.
Each verb's procedure lives in `verbs/` (see the dispatch table).
When a verb is selected, **read its file and follow it**.

This skill is **self-contained** and depends on no other skill.

There is no `init`. Explicit `/inspector setup [<root>]` deploys Inspector's bundled kinds
for project customization. Missing `.agents/skilldata/inspector/doctrine/`
is not a refuse — use the bundled `kinds/<kind>.md`.

**Kind doctrine** lands at the fixed `.agents/skilldata/inspector/doctrine/<kind>.md` path.
There is no front-door variable.
Incumbent wins; upgrade is a judgment-assisted diff. Load the complete
project skilldata copy when it is a readable regular file, else the bundled
`kinds/<kind>.md` when absent. A symlink, directory, other incompatible
entry, or unreadable file is an error — never a fallback and never a merge.

Review, revise, and refine are not setup operations: they never create this
namespace. An absent skilldata root or kind file uses the bundle.

This package does **not** mint records.

**Status vocabulary.** Writer `stage` values are in-package:

- **review** writes neither `status` nor `stage` in the verdict
  turn. On accept of a passing verdict, this session writes
  `published` (job artifacts: also `stage: approved`).
  Founding-shaped: no write; stay `draft`. Implementation review never
  writes status or stage.
- **revise** and **refine** leave `status: draft` and drop `stage: approved` if
  present.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does |
|---|---|---|
| `review` | `verbs/review.md` | two-axis critique; resolve the kind's review-continuation policy; conversation verdict |
| `revise` | `verbs/revise.md` | verify findings, propose corrections, fold on confirm; a review-origin chain re-reviews by default |
| `refine` | `verbs/refine.md` | explicitly simplify a spec or plan; propose, confirm, apply, then mandatory full review |
| `/inspector setup [<root>]` | `verbs/setup.md` | deploy all bundled kind doctrine absent-only |
| (bare) | — | **ask** which verb; do not default |

```
approve document                     →  accept/publish  →  (host sequences / walk)
material + automatic-proposal        →  revise questions/proposal  →  confirm/apply + queued review  →  …
material + offered                   →  explicit revise offer  →  stop
material + unavailable               →  publish-as-is offer or verdict-only  →  stop
implementation review → verdict only
explicit refine of spec/plan         →  simplification proposal  →  confirm/apply + mandatory review
```

The automatic `review` → `revise` handoff is not a stop: report the verdict and findings, then enter
the revision procedure in the same turn. Questions and the proposal remain stops; review never
authorizes an edit. A `revise` entered from any document review carries a queued re-review:
approval applies the proposal and immediately runs the existing `review` procedure. Standalone
`revise` invokes review only when its confirmation names re-review. `Refine` is never an automatic
review continuation; every accepted refinement runs review and that review may enter `revise`.

## Kind-detect (review, revise, and refine; once)

Kind-detect is the **only** target gate. Unknown kind → ask or refuse;
do not invent a rubric. The seven bundled kinds are in-scope. Hosts
add document-kind files; they do not invent a rubric at runtime.

1. Resolve the optional `.agents/skilldata/inspector/doctrine/` directory. Never create
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
4. No matching discriminator among project kind files and bundled kinds →
   ask or refuse. Do not invent a rubric.
5. Axes, groundedness extras, revision legal locations, and the review-continuation selector come
   **from the kind file**. Kind doctrine selects a continuation mode; verb files own its meaning
   and the shared machine (verdict words, confirmation parse, status custody, and apply rules that
   are not kind-specific). Kind files do not override those semantics.

Host-added policies extend document review and revision only; they cannot replace the
reserved `implementation` discriminator or create a code-revise or code-refine path.

## Review-continuation policy

After kind-detect, read the effective kind file's optional `## Review continuation` section. Its
selector is one exact declaration:

```text
revision-after-review: automatic-proposal | offered | unavailable
```

The effective project kind file is a complete replacement, so its declaration wins when
present. A missing declaration uses the detected-kind default regardless of whether the effective
file came from the bundle or project skilldata: `spec` and `plan` → `automatic-proposal`; every other
document kind, including a host-added kind → `offered`; `implementation` → `unavailable`. An
explicit recognized declaration overrides a document default. An absent declaration remains
valid and uses the default above. The retired `refinement-after-review:` declaration is invalid,
including when both old and new declarations are present. A malformed, conflicting, or
unrecognized declaration is also invalid doctrine: name the file and ask for correction; do not
guess. `implementation` is reserved and always `unavailable`, even if its effective file says
otherwise.

## Brief the human (every verb)

The artifact holds `status: draft` / `published`. The conversation
does not open with it. Verdict words stay conversation-only.

- **Lead with the situation** a newcomer could use: what is wrong
  with the document, or that it is ready. Then the path.
- **One ask per stop.** After a review acceptance offer, accept is a
  stop; the applicable gate write is that stop. After `revise` or `refine`:
  questions (when they fire) are a stop; the proposal is a stop;
  approval of a review-origin fold runs its queued re-review; after
  standalone apply without named re-review, the offer is a stop.
- **Translate the closing code.** "The tests would go green and
  still encode the wrong scripts" not a bare `needs-rework`.

## Shared discipline (every verb)

- **Read the verb file.** Do not reconstruct a procedure from this router.
- **Scripts from this package.** `scripts/ground-check.sh` is this
  skill's copy — resolve it from this skill's own base directory,
  never a host path.
- **Kind file from this package** (or the project incumbent).
  Resolve `kinds/` from this skill's own base directory.
- Do not mint a record. Do not write `published` in the
  `review` verdict turn.

## Edges

No private runtime store. Explicit `setup` may deploy project-customizable kind doctrine;
verdicts remain conversation-only.

<!-- edges:inspector -->
- produces: doctrine — setup deploys Inspector-owned kind policy; verdict is conversation-only; accepted passing document review publishes, and revise/refine amend in place
- handoff: — (none; after publish the host sequences)
- consumes: spec, plan, review, doctrine — artifacts or completed changes under review; a findings baton; optional project kind policy
<!-- /edges:inspector -->

## Done when

The selected verb's done-when holds: the kind and effective policy were resolved without fallback
through an invalid incumbent, each documented stop was honored, and no verb wrote outside its
declared review/revise/refine/setup boundary.
