---
doctype: design
status: current
created: 2026-08-17
updated: 2026-08-17
tags: [spec]
---

# skill-builder review — Spec

**Shipped 2026-08-17** on `stream/grok` — subjects: `Add skill-builder
review roadmap`; `Accept skill-builder review spec`; `agent-council:
classify briefs and hand off review`; `skill-builder: add review verb`.

Argued 2026-08-17 on stream `grok` from the locks in
`docs/design/2026-08-17-skill-builder-review-roadmap.md`. Locks 1, 2,
and 4 stand. **Lock 3 flipped** at acceptance (conversation
2026-08-17): the council target is no longer skill-package-only; a
named brief wins, otherwise a mechanical classifier selects
`generic` / `skill` / `spec`. `skill-builder review` stays
skill-package-only. Accepted 2026-08-17 (`status: current`).

This spec doubles as the Phase 2/3 plan (Slices). A separate
contractor plan is not required unless a later flip changes a slice
boundary.

## Problem

This library can lint a skill and can convene a three-family panel
against a skill package. It cannot cheaply *judge* a skill, and the
expensive judgment cannot be consumed.

`skill-builder check` is the facts gate: `scripts/skills-lint.sh` plus
the independence walk in `docs/BOUNDARY-AUDIT.md`. Its Pass 2 is a
structured audit with a routing-probe, not a substance review. Growing
it into “is this skill any good?” would mix a deterministic gate with
judgment and make the cheap path expensive.

`agent-council` already *produces* type `review` (scratch `RESULT.md`,
ballot / reply contracts). Its `handoff` is empty — “the report ends
the pass.” The brief is hardcoded to `briefs/skill-review.md` and the
target resolver refuses anything without `SKILL.md`. A convene against
a spec therefore gets a skill rubric, or does not run. A caller that
wants the same judgment without six headless runs has nowhere to go.
A caller that *did* convene cannot hand the ranked list to another
skill without that skill pasting the convene loop.

The missing instrument is a `review` *verb* on the toolmaker that
judges a skill package on the same rubric the panel uses for skills,
and a `review` *baton* so the panel’s artifact is an input, not a dead
end. The missing council step is a classifier: pick a brief from the
target, with a generic fallback, instead of assuming every target is
a skill.

## Goal

`/skill-builder review <skill>` exists and prints a verdict +
findings. `check` is unchanged (lint + independence). Default depth
is same-session judgment against the **skill** brief.
`/agent-council [path]` still convenes; a caller can pass a brief;
if they do not, a classifier selects `generic`, `skill`, or `spec`.
The ranked `RESULT.md` is a `review` baton another skill can consume
without re-implementing spawn or cluster. First run of the new verb
is `blueprint`. Descriptions name no sibling.

## Approach

**Chosen:** two thin edits around a typed baton. The convene loop
stays in `agent-council`. The new judgment lives in `skill-builder`.
They meet on types, never on names.

1. **Council protocol.** Optional second argument is a brief file
   (named brief wins; missing named brief → ask, no silent fallback).
   Absent a named brief, `scripts/classify-brief.sh` prints facts
   (`brief=skill|spec|generic` or empty). Three bundled briefs:
   `briefs/generic.md` (fallback), `briefs/skill-review.md` (token
   `skill`; today’s file, not renamed), `briefs/spec.md`. Edges
   become `produces: review, review-brief`, `handoff: review`,
   `consumes: review-brief`. Ballot, reply, and `RESULT.md` shapes
   do not change; the load-bearing fields a consumer may parse are
   frozen below. No `briefs/feature.md`. No `briefs/code.md`. Target
   is a readable file or directory, not skill-package-only.
2. **`skill-builder review`.** New verb file + router row +
   description trigger. Target remains a skill package. Pass 1 is
   this skill’s own lint facts. Pass 2 is judgment on the **skill**
   brief’s axes, or consumption of a `review` baton when one is
   supplied. It never classifies, never pastes the convene loop,
   and never writes `RESULT.md`.
3. **First use after the verb exists.** `/skill-builder review
   blueprint`. Fold only must-fix findings that survive the
   receiving discipline. Do not hand-audit `blueprint` as a prior
   pass.

**Rejected:**

- **Grow `check`.** Lock 1. `check` already says “judgment” for Pass
  2 in its header; that pass is the independence audit and stays.
  Substance judgment is a different job. A judgment tail on the
  cheap gate trains agents to skip the gate or to treat lint WARNs
  as design opinions.
- **Paste the council loop into `skill-builder`.** Lock 2 and the
  Phase 2 risk. “Composable” that re-implements spawn/cluster is a
  second orchestrator. The protocol is the product.
- **Keep the skill brief as the unnamed default.** Hardcodes every
  convene as a skill review. The skill brief stays; it is selected
  when the target is a skill package.
- **Skill-package-only council target (old lock 3).** A generic
  brief that cannot fire is dead weight. The flip is target-open +
  classifier, not a dedicated code-review council.
- **“Review any code” / a `code` brief.** Standing lock. `auditor`
  and host code-review already exist. `generic` judges the *named*
  target (followability, holes, scope, output shape,
  judgment-vs-mechanism). It is not a tree-walk for defects.
- **LLM classifier.** A judgment in the driver. Predicates are
  mechanical and live in a facts script.
- **Hand-audit `blueprint` first, then add the verb.** Lock 4. The
  founding-branch reshape hazard is the known starting *claim* for
  the first run, not a pre-pass.
- **Same-session review writes `RESULT.md`.** The baton has seats,
  support tags, and a review-round status. A single session does
  not have those. Forcing the shape would invent fake seats or
  fork the contract. Same-session output is a different, smaller
  report (below). Only `RESULT.md` is type `review`.
- **`skill-builder` convenes the panel.** That is naming a sibling
  in a procedure and owning its seam. On an explicit panel request
  with no baton, `review` stops after facts and says a `review`
  baton is required. The orchestrator or human convenes.
- **Copy brief axes into `skills/skill-builder/verbs/review.md`
  (S2 creates that file).** One home per fact. The brief file is
  the rubric. The verb points at it.
- **Durable records drain / workshop registration.** Council V1
  scratch-only stands. Patient-zero: no registration against this
  library’s real `AGENTS.md`. No `PACK.md` bump (member set
  unchanged).
- **`needs-rework` write-back into the target skill.** Blueprint
  review writes into a spec it is iterating. Mutating a skill
  package under review is the wrong artifact. Verdict stays in
  context.

**Greenfield check.** The substrate we could delete is
`agent-council`’s empty `handoff` — “the report ends the pass” —
and the hardcoded skill brief. Pay that debt: flip the edge, add
the classifier. Do not add an `export` verb or a second report
file. Dated `bootstrap` mentions and the expected
`founding-documents` / `git-repository` orphan WARNs are leftover
substrate; leave them. Do not add new orphan edge-types: the
pairings below make `review` and `review-brief` two-skill or
BL-4-paired.

## Mechanism

### Types

| Type | Meaning | Who |
|---|---|---|
| `review` | Ranked council report in the frozen `RESULT.md` shape | `agent-council` produces + hands off; `skill-builder` consumes |
| `review-brief` | Markdown file a panelist (or same-session judge) reads as the rubric | `agent-council` produces (bundled briefs) and consumes (caller may pass another); `skill-builder` consumes |

Types are plain strings, matched by equality
(`skills/skill-builder/docs/DOCTRINE.md` § Typed edges). Neither
skill names the other.

**Bundled briefs** (the producer of `review-brief` owns this map;
paths are relative to that skill directory):

| Token | File | When selected |
|---|---|---|
| `generic` | `briefs/generic.md` | Classifier fallback |
| `skill` | `briefs/skill-review.md` | Target is a skill package |
| `spec` | `briefs/spec.md` | Target is a design/spec document |

Do not rename `briefs/skill-review.md` this track. A caller-supplied
brief is not in this table; `RESULT.md` prints `Brief: <basename
without .md>`.

**Locate a bundled brief (consumers share this rule):**

1. Caller passed a readable file that is not a skill package → use
   it.
2. Else, for each installed skill directory that contains a
   `SKILL.md` whose edge block declares `produces: review-brief`,
   collect `<that-dir>/briefs/<file>` for the needed token (`skill`
   → `skill-review.md`, `spec` → `spec.md`, `generic` →
   `generic.md`).
3. Exactly one distinct file → use it. Zero → refuse (a `review`
   baton or an explicit brief path is required). Several distinct
   files → ask.

`skill-builder review` is skill-package-only, so step 2 always
requests token `skill`. It does **not** run the classifier.

A “skill package” is a directory containing `SKILL.md`.

### Classifier (council only)

`scripts/classify-brief.sh <target>` — facts, not a verdict. Never
recommends convening. Prints:

```
target=<absolute or empty>
workdir=<absolute cwd for seats, or empty>
readable=true|false
kind=skill|spec|other|unreadable
brief=skill|spec|generic|
reason=<short token>
```

Empty `brief=` means the agent asks; it does not pick `generic`.

**Predicates, in order:**

1. Missing, or not a readable file or directory →
   `readable=false` `kind=unreadable` `brief=`
   `reason=unreadable`.
2. Directory containing `SKILL.md` → `kind=skill` `brief=skill`
   `workdir=<that directory>`.
3. File whose basename is `SKILL.md` → same as (2) against the
   parent directory (`target` and `workdir` become the parent).
4. Readable file whose front-matter `doctype:` is exactly `design`
   or `spec`, **or** whose `tags:` sequence contains `founding` →
   `kind=spec` `brief=spec` `workdir=<parent directory>`.
   `doctype: plans` is **not** spec.
5. Any other readable file or directory → `kind=other`
   `brief=generic` `workdir=<directory, or the file’s parent>`.

Front-matter grammar matches the founding parser’s first step: if
the file begins with a line `---`, YAML through the next line that
is only `---`. `doctype:` is the first `^doctype:` value, quotes
stripped. A `founding` tag is a YAML sequence item (`tags: […,
founding, …]` or a `- founding` line), not the substring
`founding` inside another word.

The script does not accept a named brief. Named brief is a prior
step in the loop: if the caller named one, do not run the
classifier to override it.

### Briefs (what each file contains)

Each brief is a panelist rubric: a **Judge** list and a **Do not**
list. None names ranking, seats, or a sibling skill. None tells
the panelist to run a lint. The files are the one home for the
axes; `SKILL.md` and `verbs/review.md` point, they do not copy.

- **`generic`** — the named target, not a repo tour. Axes:
  followability; holes; judgment vs mechanism; scope; output
  shape. Do not: restate, rank, propose a rewrite, run a lint,
  self-tag, treat this as a code-quality or security audit of a
  source tree, read files the target does not name.
- **`skill`** — today’s `briefs/skill-review.md`, unchanged in
  substance. Read `SKILL.md`, then only what it names. Axes:
  trigger; followability; holes; independence; judgment vs
  mechanism; scope; output shape.
- **`spec`** — the named document, then only paths it cites.
  Axes: soundness (consistent, implementable, unambiguous, one
  artifact); groundedness (cited paths mean what the prose
  claims); holes (open branches presented as settled; verification
  that cannot go red); scope (a spec, not a sequenced plan);
  output shape (a specified baton is frozen enough to implement
  from). If `tags` contains `founding`: also empty mapped
  sections vs leftover headings. Do not: restate, rank, propose a
  whole-document rewrite, run a lint, self-tag, review a diff.

### `agent-council` — pluggable brief, live baton

**Invocation.** `/agent-council [target] [brief]`.

- `[target]` — a readable file or directory. Relative paths
  resolve from cwd. A bare slug → `<git-toplevel>/skills/<slug>/`
  if that directory contains `SKILL.md`. Missing or unreadable →
  ask. Do not guess a brief as the target. First argument is
  always the target.
- `[brief]` is optional. Present → a readable file, not a
  directory, not a skill package. Unreadable or wrong kind → ask.
  Do not fall back silently and do not classify over it.
- Absent `[brief]` → run `scripts/classify-brief.sh` on the
  resolved target. `brief=` → ask. Otherwise open the bundled
  file for that token.

**Loop.** Step 1 no longer stops on “no `SKILL.md`.” After the
target resolves: named brief or classifier, then probe / cost /
scratch as today. Pass the **absolute brief path** to every seat.
cwd for every seat is the classifier’s `workdir` (or the named
target’s directory / parent). `references/spawn.md` says “target
workdir,” not “target skill directory.”

**`RESULT.md` header.** `Brief: <token>` is `skill` / `spec` /
`generic` for a bundled brief, or the caller file’s basename
without `.md`. Consumers treat the field as an opaque label, not
a path.

**Edges (exact lines):**

```
produces: review, review-brief — ranked council report (shown + scratch RESULT.md); bundled briefs
handoff: review — RESULT.md is the baton (ballot / reply / report contract unchanged)
consumes: review-brief — optional named brief; else classifier token
```

**What does not change.** `templates/ballot.md`,
`templates/review.md`, clustering rules, seat letters, cost
confirm, scratch-only home, “orchestrator is never a panelist,”
degrade-don’t-stall. Description still self-scopes (no sibling).
No verb table. No `briefs/feature.md`. No `briefs/code.md`.

**Description trigger** may say a skill, a spec, or a named path.
It must not summarize the classifier. It must not name a sibling.
It must stay ≤ 1024 characters (aim ~700).

**Baton contract (load-bearing for a consumer).** A consumer of
`review` must extract these and may ignore everything else:

- A heading `# Council: <target>`
- A `Brief: <token>` line
- Under `## Ranked opinions`, every `### N. [<seats>] <severity> — <claim>`
  block with `Evidence:`, `Action:`, and `Status:`
  (`held` / `refined` / `new`)
- `## Rescinded` is **not** a live finding
- A `Scratch: <absolute path>` line

A fixture caller (no live convene) proves this:
`scripts/read-result.sh <file>` prints `n=<count>` and one
`claim=<…>` line per ranked opinion. Wire it into
`skills/agent-council/scripts/tests/run.sh` next to
`probe-seats-test.sh`. Red-proof: a file whose only claim sits
under `## Rescinded` prints `n=0`.

Classifier tests (same runner, throwaway fixtures, no live
convene): skill directory → `brief=skill`; `SKILL.md` file →
`brief=skill` and `workdir` is the parent; `doctype: design` or
`doctype: spec` or a `founding` tag → `brief=spec`; `doctype:
plans` → `brief=generic` (not spec); random file or non-skill
directory → `brief=generic`; missing path → `brief=` (not
`generic`). Red-proof: a spec fixture must not print
`brief=skill`.

### `skill-builder review` — facts, then judgment or consume

**Invocation.** `/skill-builder review <skill> [<path>]`.

`<skill>` resolves like a **skill** target (directory with
`SKILL.md` / relative / bare slug). Missing → ask. Not a skill
package → refuse. No classifier.

`<path>` if present is classified by content, not flag:

- File whose first heading is `# Council:` → a `review` baton.
  Consume it.
- Else a readable file that is not a skill package → a
  `review-brief`. Same-session judgment against it.
- Else → ask.

**Depth.**

| Situation | What `review` does |
|---|---|
| Default (no panel asked, no baton) | Pass 1 facts, then same-session judgment against the **skill** brief |
| Baton supplied | Pass 1 facts, then consume the baton (do not re-judge from scratch) |
| User asked to convene / panel / council, no baton | Pass 1 facts, then **stop**. Say a `review` baton is required. Do not convene. Do not judge. |
| High-stake, no baton, no panel ask | Same as default, plus a note that a panel is warranted. High-stake = user-nominated, or the target directory contains `PACK.md` |

`review` never dispatches seats, never writes scratch, never
clusters, never runs `classify-brief.sh`.

**Pass 1 — facts.** Run this skill’s `scripts/skills-lint.sh`
against the target’s library root: walk up from the resolved
skill directory until a parent contains a `skills/` directory
that itself contains the target; that parent is the root. If no
such parent exists, skip the lint and note `Facts: lint skipped
(no library root)`. Report the target-relevant `FAIL:` / `WARN:`
lines as facts, not verdicts. Do **not** run `check` Pass 2
(`skills/skill-builder/docs/BOUNDARY-AUDIT.md`) as part of
`review`. Do not grow `check`. `check`’s two passes stay exactly
as they are.

**Pass 2 — same-session judgment.** Read the resolved brief in
full. Judge only on the axes it names. Follow that brief’s read
rule (the skill brief: `SKILL.md`, then only what it names). Emit
discrete findings (claim, evidence as path + quote or `file:line`,
action, severity `high` / `mid` / `low`). Do not restate the
skill. Do not run a second lint. Do not copy the brief’s axis
list into `skills/skill-builder/verbs/review.md`.

Independence findings that `check` Pass 2 already owns: point at
`check`, do not re-walk `docs/BOUNDARY-AUDIT.md`. A brief-axis
hit that is *also* a lint `WARN:` cites the lint line as
evidence.

**Pass 2 — consume a baton.** For each live ranked opinion
(skip `## Rescinded`):

1. Re-check the claim against the actual skill (path + quote).
2. Verified → keep, class `must-fix` if severity is `high`, else
   `nice-to-have` unless the action is a rewrite of the whole
   package (that is nice-to-have regardless of seat count).
3. Unverified → keep only as `unverified` with the failed check
   stated; do not fold later.
4. Do not re-cluster. Do not invent support tags.

Then add only those same-session findings that Pass 1 facts
support and the baton did not already claim (lint FAILs the brief
forbids a panelist to run).

**Receiving discipline** (fold into `blueprint` or any target;
state these rules in `skills/skill-builder/verbs/review.md`, do
not name a sibling):

1. Feedback is a claim, not a decision — re-check before
   implementing.
2. No performative agreement.
3. One unclear item holds the whole batch.
4. Grep before generalizing.
5. Push back with evidence when the claim is wrong.

**What `review` prints** (in context; no file):

```
# Review: <skill>
Depth: same-session | baton | stopped-for-baton
Brief: <path or `skill`>
Facts: lint fails=N warns=N (target-relevant listed)

## Verdict
approve | approve-with-changes | needs-rework

## Findings
### 1. high — <claim>
Location: <path>
Why: …
Fix: …
Class: must-fix | nice-to-have
Source: same-session | baton (verified) | baton (unverified)

## Notes
<panel-warranted note, stop reason, or empty>
```

Verdict rule: any verified `must-fix` → `needs-rework`; only
`nice-to-have` → `approve-with-changes`; no findings → `approve`.
Unverified baton claims do not by themselves block.

**Router + description.** Add a dispatch row. Add
`skills/skill-builder/verbs/review.md` (S2 creates it) and cite
it from `SKILL.md` (lint check 11).
Description trigger grows to fire on “review a skill,”
“skill review,” followability / holes / trigger-quality
questions — **when to use, not how.** Must not name
`/agent-council` or any sibling. Must stay ≤ 1024 characters
(aim ~700). Body may carry a soft pointer to the `review` type
and the skill-brief location rule; it must not re-document the
convene loop, the classifier, or enumerate another skill’s verbs.

**Edges (exact lines):**

```
produces: — (verdict + findings in context, not a typed artifact)
handoff: — (the review ends the pass)
consumes: review, review-brief — optional RESULT.md baton; skill brief for same-session judgment
```

`skill-builder` stays an in-place steward with no home and no
`init`.

### First use (`blueprint`)

Only after the verb exists. Command: `/skill-builder review
blueprint` (default depth). Known starting claim to test against,
not to pre-seed as a finding: the founding-shaped branch of
`grill` / `spec` / `review` can keep reading and reshape a
founding file into `templates/spec.md` if the shape check fails
open. Fold only verified `must-fix`. Out of scope for the fold:
rewriting `verbs/deploy.md`; a `blueprint` rewrite that is not a
review fold; adding a `code` brief to the council. Genesis
routing-probe winners stay 5/5; do not “clean up” dated
`bootstrap` mentions.

### What this track does not touch

- `check` procedure, lint checks, `docs/BOUNDARY-AUDIT.md`
- `skills/skill-builder/docs/DOCTRINE.md` (unless a calibrate later
  folds a new authoring bullet — not this track)
- `PACK.md` version
- This library’s `AGENTS.md`
- Host leftover: `./install.sh --remove bootstrap` from the
  **root** clone (not a stream job)
- A general-purpose code-review council or a `briefs/code.md`

## Verification

No numeric headline without a population. The populations here
are small and named.

| Check | Population | Pass |
|---|---|---|
| Lint on the two edited skills | `FAIL:` lines from `skills/skill-builder/scripts/skills-lint.sh` aimed at this library | `fails=0`. Residual WARNs: existing `founding-documents` / `git-repository` orphans, worktree-vs-clone symlink notes. After S1 only, `review` may orphan until S2 adds the consumer (lint’s documented mid-rollout WARN). After S2: **not** a `review` or `review-brief` orphan. |
| Bare convene still documented | `skills/agent-council/SKILL.md` loop | Absent brief → classifier, not a hardcoded skill brief. Description still has no sibling name. |
| Classifier | throwaway fixtures in `scripts/tests/` | The predicate table above, including `doctype: plans` → `generic` and a spec fixture ↛ `skill`. |
| Baton is readable | Golden `RESULT.md` + `read-result.sh` | `n=` equals the ranked-opinion count; rescinded claims absent; red-proof: a file with the claim only under `## Rescinded` prints `n=0`. |
| `check` still facts | `skills/skill-builder/verbs/check.md` | Still two passes (lint + boundary-audit). No substance-review tail. |
| `review` exists | `/skill-builder review blueprint` in this worktree | Prints the report shape (Verdict + Findings). `skills/skill-builder/verbs/review.md` is cited. |
| Descriptions self-scope | both `description:` fields | No `/agent-council`, no `/skill-builder` in the *other* skill’s description. Check 7 clean on both. |
| Genesis battery | the 5 cold-router cases already recorded | Still 5/5 after any `blueprint` fold. |

Absence-style checks (no sibling in description; no new orphan
type; rescinded ≠ live; spec ↛ skill brief) each have a red-proof
in the table above.

## Slices

Sequential. Do not start S2 before S1’s gate. Do not start S3
before S2’s gate.

### S1 — Council protocol
- **Paths:** `skills/agent-council/SKILL.md`;
  `skills/agent-council/references/spawn.md` (workdir wording);
  `skills/agent-council/briefs/generic.md`;
  `skills/agent-council/briefs/spec.md`;
  `skills/agent-council/briefs/skill-review.md` (unchanged
  substance); `skills/agent-council/scripts/classify-brief.sh`;
  `skills/agent-council/scripts/read-result.sh`;
  `skills/agent-council/scripts/tests/` (classifier + baton
  reader + `run.sh` wire-up). Ballot / reply templates unchanged.
- **Verify:**
  `bash skills/agent-council/scripts/tests/run.sh` green
  (probe + classifier + baton reader, red-first);
  `bash skills/skill-builder/scripts/skills-lint.sh <worktree>`
  → `fails=0`; `review` orphan WARN expected until S2;
  description has no sibling; edges match Mechanism.

### S2 — `skill-builder review`
- **Paths:** `skills/skill-builder/SKILL.md`,
  `skills/skill-builder/verbs/review.md`.
- **Verify:** lint `fails=0` on both skills; check 11 does not
  report `verbs/review.md` orphan; `check.md` body unchanged in
  procedure; description trigger present and ≤ 1024;
  `description:` contains no `/agent-council`.

### S3 — first use on `blueprint`
- **Paths:** only folds that survive receiving discipline
  (likely none, or a tight shape-check phrase). Not
  `verbs/deploy.md` unless a verified must-fix lives there.
- **Verify:** `/skill-builder review blueprint` produces the
  report shape; any fold re-checked against live
  `skills/blueprint/`; genesis routing-probe 5/5.

_When a slice meets its gate, debrief before advancing. Stream
cadence is `milestone` — propose a land after S3 (or earlier if
another stream needs the protocol)._
