---
doctype: specs
status: published
schema: architect/spec@1
tags: [backlog, debrief, anchor, lifecycle]
---

# Backlog debrief-anchor reliability — Spec

## Problem

Backlog's universal debrief cadence is installed in the root `AGENTS.md`, but the current managed
block compresses its behavioral contract into one long sentence beneath a generic skill-route
heading. It tells an agent to debrief after a human-visible work unit and before a healthy reset or
hand-off, but it does not define the unit, make automatic execution explicit, cover an autonomous
transition to the next unit, or carry the exclusions and emergency rule that determine when the
cadence must stay quiet. The full rules exist in Backlog's published design and verb, but an agent
must first trigger Backlog before those surfaces can help.

The result is an always-loaded pointer whose most important job still depends on interpretation at
the exact seam where an agent is most likely to report completion, continue autonomously, or discard
context. Reinforcement must improve that trigger without coupling Backlog back into Checkpoint or
Workstream, adding a harness-specific hook, or creating a durable debrief cursor.

The cadence and current managed route are governed by the published base spec
(→ `specs/2026-08-27-backlog-routines-and-universal-debrief.md`). The draft provider/setup addendum
(→ `specs/2026-08-28-backlog-tracker-provider-discoverability.md`) owns setup reconciliation of the
bounded root route; this addendum defines that route's exact debrief-anchor postcondition.

## Goal

Install one versioned, locally complete Backlog debrief anchor in the always-loaded root front door.
It makes a custodial main agent run `/backlog debrief` automatically and once at the earliest
observable boundary after substantive repository work, while remaining silent for excluded
contexts and deferring safely during involuntary context emergencies.

The anchor remains a trigger, not a second copy of the Backlog workflow. It introduces no durable
cursor, session enrollment, timer, harness hook, lifecycle-owner integration, or separate
`/backlog anchor` verb.

## Approach

**Chosen: one exact versioned anchor with a pre-completion gate.** Replace the commit-stamped route
body with a stable version-stamped package template under Backlog's existing reserved marker family.
The block retains the registration heading, route, and typed edge required by portable doctrine,
then names who the debrief boundary applies to, defines a coherent work unit, lists three observable
trigger moments in earliest-of order, says to act without asking, bounds once-only scope in the
current context, carries the existing exclusions, and preserves the primary-work-first rule for
involuntary compaction or context pressure.

Setup remains the genuine installation and reconciliation moment. When at least one queue exists,
setup installs or refreshes the exact anchor as part of its bounded root-route surface; removing the
last queue removes it. Backlog's runtime verbs do not create project instructions, and no second
anchor installer is introduced.

Alternatives rejected:

- **Keep the one-sentence cadence and strengthen only `SKILL.md`.** The agent must already have
  triggered Backlog before skill-local detail can correct a missed trigger.
- **Invoke Backlog from Checkpoint or Workstream lifecycle code.** That would cover only those
  owners, miss ordinary root and other custodial sessions, duplicate general project policy, and
  reverse the base spec's boundary independence.
- **Install harness-specific pre-response hooks.** They could enforce an event more strongly but
  would sacrifice the portable `AGENTS.md` contract and require a different implementation per
  harness.
- **Record a durable last-debrief cursor or event ledger.** Exact cross-context once-only state would
  turn Backlog into a session event log before measured duplicate or missed sweeps justify that
  lifecycle. The current-context boundary remains sufficient.
- **Add `/backlog anchor`.** Setup already has the legitimate moment and complete write set for the
  root route. A separate verb would create two reconciliation paths for one package-owned block.
- **Run after every response, command, commit, or test.** That would make routine progress noisy and
  collapse a work-unit boundary into implementation churn.

## Mechanism

Backlog packages one exact root-front-door template:

```markdown
<!-- skill:backlog BEGIN built-against:debrief-anchor@1 -->
### /backlog — project follow-up trackers
Route: Inspect project trackers with `/backlog query` or `/backlog tracker list`; capture
completed-work leftovers with `/backlog debrief`.
Edges: produces `tracker`.

**Debrief boundary.**

This applies to the custodial main agent performing substantive repository work. It does not apply
to pure Q&A, routine status replies, or child/delegate sessions; those return their byproducts to
the custodial caller.

Run `/backlog debrief` automatically, without asking, once at the earliest of:

1. before telling the human that a coherent work unit is complete;
2. before beginning the next coherent work unit after one completes; or
3. before a healthy reset or hand-off would discard substantive context.

A coherent work unit is an outcome worth reporting: a completed request, feature slice,
investigation, design decision, or review. An individual edit, command, test run, or progress update
is not a work unit. The debrief sweep and any recovery it invokes close the preceding unit; neither
is itself a new work unit.

Sweep only completed-work leftovers since the previous successful debrief in this context. Do not
file the current objective, resume instructions, or ordinary in-flight work. Zero filed rows is
success. Remember the boundary in the current context and do not repeat the same unit.

During involuntary compaction or context-pressure emergencies, preserve and recover the primary work
first; run any deferred debrief at the next safe boundary. If debrief refuses, follow its recovery
diagnostic when safe and retry once. If it still refuses, keep the boundary pending, report the
refusal, and do not begin another unit or deliberately reset or hand off. A completion response may
report the primary work complete only when it also states that debrief remains pending. Never
hand-edit tracker data.
<!-- skill:backlog END -->
```

The exact current begin marker is
`<!-- skill:backlog BEGIN built-against:debrief-anchor@1 -->`; the reserved begin family is a
complete line that starts `<!-- skill:backlog BEGIN`, and the exact end marker remains
`<!-- skill:backlog END -->`. The marker carries a stable behavior version rather than a package
commit stamp: `debrief-anchor@1` versions the public behavior, while byte identity against the
package template detects drift.

The root-route classifier accepts exactly these normal states:

- `current` — exactly one ordered current-begin/end pair whose bounded bytes equal the package
  template, with no second reserved marker;
- `drifted-current` — exactly one ordered current-begin/end pair whose bounded bytes differ, with no
  second reserved marker;
- `replaceable-managed` — exactly one ordered reserved-begin/end pair whose begin is not the current
  marker, with no second reserved marker; and
- `absent` — no reserved begin or end marker and no structural H3 whose text is exactly
  `/backlog — project follow-up trackers`.

Duplicate, nested, reversed, unmatched, or overlapping reserved markers and an unmarked reserved
heading are malformed. Setup and tracker administration preflight that state before any write and
refuse a malformed front door without selecting a replacement extent. `drifted-current` and
`replaceable-managed` are package-owned bounded extents: setup replaces the whole extent with the
exact current template while preserving every byte before and after it. It never imports, parses, or
translates content from a replaced block. `absent` appends the exact block beneath the existing
self-registered-routes heading, creating that heading only when absent. A current rerun is a no-op.

The existing commit-stamped Backlog block is therefore replaced through the generic reserved-family
rule, not a format-specific migration branch. Historical records retain its wording. An unrelated
project-authored Backlog heading outside the exact reserved heading remains project prose; only the
exact unmarked `### /backlog — project follow-up trackers` heading is reserved to prevent two apparently
authoritative anchors.

The three trigger moments are an earliest-of gate, not three debriefs. Completion reporting is the
ordinary interactive trigger. Beginning the next unit covers autonomous work that crosses a seam
without first responding to the human. Healthy reset or hand-off is the final guard before context
loss. After one successful debrief, the agent remembers that boundary in current context and the
same completed unit cannot fire another trigger.

The debrief sweep, a setup or repair operation reached through its diagnostic, and the single retry
are closure work for the preceding unit. They never create another coherent unit or recursively
trigger the anchor. If the retry refuses, the successful-debrief boundary has not advanced. The
agent reports that refusal and retains the pending boundary in current context; it may accurately
report the primary outcome complete, but it cannot begin another unit or deliberately discard that
context as though debrief had succeeded.

The anchor's `custodial main agent` is the context with repository and commit custody. A child or
delegate returns candidate byproducts to that caller and never mutates trackers itself. Pure Q&A,
routine status, an individual tool action, and ordinary in-flight work do not trigger. The current
objective and resume instructions remain primary work rather than leftovers. These rules specialize
Backlog's trigger only; the debrief verb and editable routing prompt remain authoritative for what
gets filed and where.

Involuntary compaction and context-pressure emergencies do not run a potentially mutating debrief
ahead of primary-work preservation or recovery. At the next safe boundary, the recovered custodial
agent runs one deferred debrief over the completed work it can support from current context and
durable facts. It does not put a cursor, candidate buffer, or Backlog-specific instruction into a
Checkpoint or Workstream save-state. A deliberate healthy reset remains gated by debrief success or
an explicit recovery refusal; it is not an emergency exemption.

The anchor cannot make a prose-driven agent event mathematically guaranteed. Its portable contract
maximizes reliability by using an always-loaded surface, observable pre-action moments, imperative
language, one locally complete decision rule, and one owner. Harness-level enforcement remains out
of scope unless later evidence shows this contract is insufficient.

## Verification

All front-door mutation tests run against throwaway repositories and never register Backlog in
grimoire's authored root `AGENTS.md`.

- Exact-template fixtures prove fresh setup with at least one queue writes one byte-identical
  `debrief-anchor@1` block, a current rerun writes nothing, and removing the final queue removes only
  that block. Re-adding a queue restores it.
- Classifier fixtures cover current, drifted-current, the existing commit-stamped block through the
  generic `replaceable-managed` state, absent, and every duplicate, nested, reversed, unmatched,
  overlapping, or unmarked-reserved-heading refusal. Replacement preserves surrounding project
  bytes and never carries content forward from the replaced extent. Mutation red-proofs weaken each
  marker and reserved-heading guard in turn and require its corresponding refusal fixture to fail.
- Failure injection before front-door replacement and immediately before its final rename proves
  complete preflight, destination revalidation, and convergence without a partial anchor.
- The anchor contract test requires applicability, all three ordered earliest-of triggers,
  automatic execution without a permission round trip, the coherent-unit definition, once-only
  current-context scope, zero-result success, exclusions, emergency deferral, and provider-recovery
  behavior. A controlled broken template independently removes each class of requirement and must
  make its assertion fail.
- Debrief behavior fixtures cover one completed interactive unit, two autonomous consecutive units,
  a healthy pre-reset boundary, zero-result success, pure Q&A, routine status, child/delegate return,
  debrief/recovery recursion, terminal refusal with a pending boundary, and involuntary-compaction
  deferral. The repository stores expected dispatch decisions as contract scenarios; it does not
  call a hosted model from the deterministic gate.
- Bounded attended acceptance cells run the implemented anchor in separately configured throwaway
  projects under the current Grok and Codex harnesses named by this library. A planted
  completed-work leftover proves debrief mutation precedes the completion response; a two-unit run
  proves one debrief boundary occurs before the second unit begins; and pure Q&A proves no debrief
  dispatch or tracker change. Harness transcripts or rollout logs plus tracker state and Git ordering
  are the evidence. These hosted cells are not a deterministic repository gate; record their dated
  result in a published spike before accepting the implementation.
- Backlog's full harness, consuming-project configuration fixture, Checkpoint and Workstream
  documentation-contract fixtures, skill lint, and repository integration tests pass. A live-source
  search finds no Backlog-specific invocation in Checkpoint or Workstream and no current
  commit-stamped Backlog marker outside the generic replacement fixture and historical records. Its
  red-proof plants each prohibited source in a temporary live-source copy and requires the absence
  gate to fail before restoring the green fixture.

The addendum is complete when setup owns one exact versioned debrief anchor, every substantive
custodial work unit reaches one observable pre-action trigger, excluded contexts stay quiet,
emergencies preserve primary work first, current-context once-only behavior needs no durable state,
and no lifecycle owner or harness becomes a second Backlog dispatcher.
