---
name: inspector
description: "Use when the user runs `/inspector`, asks to review a document or completed implementation, wants supported findings revised into a document, wants a spec or plan simplified, or wants Inspector's project doctrine deployed. Review is a material two-axis judgment; after a material implementation verdict, ask in English to fix in this checkout. Revise and refine are document mutation verbs that propose before editing. Does not mint records. Bare `/inspector` asks which verb. For a one-line patch, skip it."
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

## Scope firewall

At the first review, establish one boundary from the user's requested outcome and the artifact's
declared goals, affected surface, explicit non-goals, and acceptance evidence. Derive it from the
conversation and artifact; do not require a new scope document or metadata block. When the artifact
is incomplete, use the narrowest supported reading and ask only when a consequential ambiguity
prevents judgment.

Only defects that prevent that bounded outcome, violate an in-scope requirement, or make its
implementation unsafe or incorrect may block. Material improvements may be recommended only inside
the same boundary. Adjacent cleanup or architectural opportunities are non-blocking follow-ups;
unsupported or speculative concerns are omitted. A finding that introduces a subsystem or surface
not named by the request or artifact needs direct causal evidence that the bounded outcome cannot be
achieved safely or correctly without it. Otherwise it cannot affect the verdict or enter revision.

Revision and every re-review carry this boundary unchanged. A later round may discover a
new in-boundary defect, but a finding cannot enlarge its own authority. Only a new user instruction
or an accepted upstream scope change widens the boundary.

## Verb dispatch (read the file, then follow it)

| Invocation | Verb file | Does |
|---|---|---|
| `review` | `verbs/review.md` | two-axis critique; resolve continuation; conversation verdict and applicable action close |
| `revise` | `verbs/revise.md` | verify findings, propose corrections, fold on confirm; a review-origin chain re-reviews by default |
| `refine` | `verbs/refine.md` | explicitly simplify a spec or plan; propose, confirm, apply, then mandatory full review |
| `/inspector setup [<root>]` | `verbs/setup.md` | deploy all bundled kind doctrine absent-only |
| (bare) | — | **ask** which verb; do not default |

```
approve document                     →  accept/publish  →  (host sequences / walk)
material + offered                   →  explicit revise offer  →  stop
material + unavailable               →  publish-as-is offer or verdict-only  →  stop
implementation material verdict       →  English close  →  fix in this checkout or stop
implementation approve                →  report ready  →  resume caller automatically
explicit refine of spec/plan         →  simplification proposal  →  confirm/apply + mandatory review
```

Document review with material findings stops after the verdict (`offered`) unless the effective kind
file declares `automatic-proposal`. A declared automatic-proposal reports the verdict and findings,
then enters the revision procedure in the same turn. Questions and the proposal remain stops; review
never authorizes an edit. A `revise` entered from any document review carries a queued re-review:
approval applies the proposal and immediately runs the existing `review` procedure. Standalone
`revise` invokes review only when its confirmation names re-review. `Refine` is never an automatic
review continuation; every accepted refinement runs review and that review may enter `revise`.

Implementation remains `revision-after-review: unavailable`: it never enters document `revise` or
`refine`. A material implementation verdict receives the English close in `verbs/review.md`;
`approve` reports readiness and resumes the caller automatically. The close asks in English to fix
in this checkout. The verdict is not permission to edit. A named commit or range that is not this
tree is refused. There is no reply-code grammar and no isolated fixer.

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
Kind-detect never treats `invariants/` or `lenses/` as kinds.

## Named sets

Opt-in project files, not a management API and not an always-on bar. Vocabulary:

| Term | Binding |
|---|---|
| invariant | Falsifiable forbidden shape. In force and violated → must-fix. |
| lens | A way to look. Does not block unless it also names a forbidden shape. |
| in force | Named on this invocation. Default none. |

Project instances:

```text
.agents/skilldata/inspector/invariants/<name>.md
.agents/skilldata/inspector/lenses/<name>.md
```

`<name>` is the invocation token and the filename stem: `[a-z0-9]+(-[a-z0-9]+)*`, no
slash, no parent traversal. Several names may be in force. Inspector owns the path
convention and the read rule. The project owns the bytes. Setup does not plant content
or create these directories. Missing directories mean this project has no named sets.
An arbitrary existing file path on the invocation is an escape hatch, not the usual form.

A review that is only reviewing never creates these files. Unnamed look-again does not
re-attach sets. Unknown name → ask.

## Review-continuation policy

After kind-detect, read the effective kind file's optional `## Review continuation` section. Its
selector is one exact declaration:

```text
revision-after-review: automatic-proposal | offered | unavailable
```

The effective project kind file is a complete replacement, so its declaration wins when
present. A missing declaration uses the detected-kind default regardless of whether the effective
file came from the bundle or project skilldata: every document kind, including spec, plan,
and a host-added kind → `offered`; `implementation` → `unavailable`. An
explicit recognized declaration overrides a document default. An absent declaration remains
valid and uses the default above. The retired `refinement-after-review:` declaration is invalid,
including when both old and new declarations are present. A malformed, conflicting, or
unrecognized declaration is also invalid doctrine: name the file and ask for correction; do not
guess. `implementation` is reserved and always `unavailable`, even if its effective file says
otherwise. A project incumbent that already declares `automatic-proposal` keeps those bytes until
the host edits them.

For implementation, `unavailable` governs document revision only. It does not suppress the distinct
English close owned by `review`.

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
