---
doctype: specs
status: draft
created: 2026-08-24
updated: 2026-08-24
tags: [spec]
---

# Inspector adequacy + review-close + project doctrine — Spec

This library's design home is `docs/design/` (patient-zero: grimoire
authors the workshop, it does not run one on itself). This spec lives
here. It doubles as the implementation plan.

Settled 2026-08-24 in conversation: next-turn offer-and-parse (not
same-turn auto-enter); one spec covering that close plus the
adequacy calibration; inspector also reviews a completed code
implementation; no numeric finding cap; empty refine package skips
proposal-and-confirm. Project review doctrine uses no hook. Explicit
`/inspector setup` deploys bundled kinds absent-only to
`<agent-workspace>/doctrine/inspector/`, creating that subtree when
absent. Inspector owns those files; clankshop does not deploy,
validate, or repair them. Remaining forks are resolved in *Approach*
and *Mechanism* below.

Lineage this amends, not replaces:
`docs/design/2026-08-21-architect-contractor-inspector.md` (inspector
as critique and fold; conversation verdict; caller publishes;
failing review stops on `draft`) and
`docs/design/2026-08-20-revise-propose-then-apply.md` (propose-then-
apply; each arrow is a stop; named re-review; auto-entering refine
from review left out of that change on purpose). The no-auto-enter
rule still binds: this spec adds an *offer* and a *next-utterance
parse*, not same-turn fold.

This spec reverses the earlier fifth-landing-class decision in the
2026-08-21 lineage. Inspector kinds are project doctrine, not a
sibling home beside doctrine.

## Problem

Inspector is an independent second set of eyes, then the fold back.
Four failures keep showing up in use, and they compound.

**The failing-review stop does not name the next path.** After
`needs-rework`, `verbs/review.md` dumps findings and stops. After
`refine` applies, the same skill names `review` and offers it
without running it. The failing-review stop has no matching offer.
Operators fill the hole with a freeform prompt — "what do you think
of the findings? what fixes would you recommend?" — which is
`refine`'s job (verify, classify, propose). `refine` already
resolves in-session findings when no paths are given. Review never
points there, and `refine` is in the passing-review reject set
(`do not write`) without starting the fold.

**The critique is calibrated as an artifact maximizer.** Several
rules turn "more proof or detail would be nice" into a blocker:
every absence-style test needs a red-proof that reads as execution
evidence at spec time; spec substrate-skepticism is a finding even
when every `HEAD` claim is true; plan slice 1 must be a tracer;
omitted severity becomes must-fix; one unresolved `ask` holds the
whole proposal; named re-review reruns the full procedure and can
raise the bar each pass. `refine` then treats that pile as
load-bearing. The result is extra turns, unrequested requirements,
and a stalled goal for work that does not change whether the
artifact is safe to execute.

**A completed implementation has no inspector lane.** `review` is
currently document-only and explicitly sends code changes to
unspecified host tooling. That leaves the final claim — that the
code actually realizes the approved design and plan — outside the
same independent adequacy gate. Document groundedness reads code,
but it does not review the completed change as the primary artifact.

**Project review policy has no deliberate deployment path.** A host
may add kind files, but the current path is the separate
`<agent-workspace>/inspector/` landing class and the skill declares
that it has no setup. There is no explicit operation that gives a
project full, editable copies of the bundled review doctrine.
Making clankshop seed or police those copies would couple an
independent skill to the pack face and make clankshop responsible
for another skill's policy.

The root need: **inspector is an independent, project-tunable
adequacy gate whose next path is always visible.** It reviews the
decision, the execution plan, and the completed implementation.
Safety and correctness stay hard. Perfection is not a finding. The
fold is one offer away, not a phrase the operator has to invent.

## Goal

After this feature:

1. A failing document `review` names `refine`, offers it, and stops. The next
   utterance that accepts that offer starts `refine` on the
   in-session findings. `approve-with-changes` keeps publish-on-accept
   and treats `refine` as a live door (don't publish, start the
   fold). Clean `approve` stays publish-only.
2. A must-fix requires a concrete failure scenario against the
   artifact's next step. Preferences, extra proof, future-proofing,
   and unrequested requirements do not block. Re-review does not
   raise the bar. Omitted severity is not must-fix. One optional
   `ask` does not hold unrelated amendments. If nothing material
   remains to fold, `refine` says so and stops.
3. `review` accepts a completed implementation as a seventh bundled
   kind. It judges the change against its governing design and plan,
   the surrounding code, and relevant host gates. Its verdict is
   conversation-only: code review neither publishes a document nor
   enters `refine`.
4. `/inspector setup` optionally deploys all bundled kind files to
   `<agent-workspace>/doctrine/inspector/<kind>.md`. It may create
   the workspace, doctrine home, and inspector subtree when absent;
   it never overwrites an incumbent. Normal review/refine still use
   the bundle when a project copy is absent.
5. No project hook, no shopbook flow, no same-turn auto-enter, no
   numeric finding cap, and no clankshop ownership of inspector
   doctrine.

## Approach

**Calibrate the existing machine, add the missing review target,
and give its doctrine an explicit owner.**

Four changes, one skill surface:

- **Judgment policy.** An adequacy principle on the router;
  operational tests on `review` (materiality at emit, narrowed
  red-proof, compressed dump, re-review posture, depth-dial
  synthesis) and `refine` (severity, ask-hold, empty package);
  kind files that currently force maximization (spec substrate
  on, plan tracer-first) flipped to the same bar. Shared floor
  conditionals live in `verbs/review.md` once; kinds stop
  restating them.
- **Stop shape.** Failing document review already dumps a verdict. It
  gains the close `refine` already has after apply: name the
  path, offer it, do not run it this turn. The next utterance
  that accepts the offer follows the existing `refine`
  procedure. Same exception pattern as named re-review, opposite
  arrow.
- **Implementation review.** A new bundled `implementation` kind
  makes a completed change — not a document describing it — the
  primary artifact. It uses the same adequacy/materiality policy
  and conversation verdict, with code-specific scope, evidence,
  and close rules.
- **Project doctrine.** Kind files land under the open doctrine
  home at `doctrine/inspector/`. An explicit inspector-owned
  `setup` copies the bundle absent-only. Reads remain two-level:
  present project file wins; absent project file falls back to the
  bundle. No hook or merge format is needed because the project
  copy is the complete policy.

**Rejected: same-turn auto-enter `refine` from `review`.** Collapses
reviewer and owner in one dump, starts packaging amendments before
the human has seen the critique, and was left out of the 2026-08-20
change on purpose. Named re-review is the one same-turn exception
because the package was already confirmed.

**Rejected: a new review/fold verb, a shopbook/`flows/` workflow,
or a project hook.** The fold verb exists. Intra-skill sequencing
already lives on inspector's pipeline. Shopbook is for host
procedures. A hook would make review policy an ordered side effect;
the kind file is the policy and is wanted every time. `setup` is an
asset-deployment verb, not another review stage.

**Rejected: clankshop deployment or validation of inspector
doctrine.** Clankshop provides pack glue; it does not babysit
optional members. The doctrine directory is open workspace
substrate with path-level ownership, not a clankshop-owned tree.
Inspector creates and tends only `doctrine/inspector/`.

**Rejected: stuffing `refine`'s remediation table into the review
dump.** Duplicates the fold, mixes hats, and makes the critique
thinner.

**Rejected: a hard output cap** ("at most N must-fixes"). Agents
merge unrelated defects or drop the next safety issue. Require
root-cause compression and permission to omit low-value optionals.
Exceed freely for independent safety or correctness failures. No
number in the skill.

**Rejected: rewriting inspector, or changing contractor's plan
template / the feature-lane build-time red-proof.** Authoring
defaults may still recommend a tracer; inspector no longer
*requires* one. `skills/clankshop/flows/feature.md` step 4's
red-proof is implementation-time evidence and stays.

## Mechanism

### Review targets and kind resolution

Inspector has two target families:

- **Documents:** spec, ADR, founding, plan, roadmap, and runbook.
  Existing discriminator-based kind detection, review/refine,
  document status, and publish-on-accept rules apply.
- **Completed implementations:** a git worktree change, commit,
  range, branch delta, or explicit set of source paths. Review-only;
  there is no document to publish and `refine` does not edit code.

Add `skills/inspector/kinds/implementation.md` as the seventh
bundled kind. It matches only when the user explicitly asks to
review code / an implementation or explicitly names the kind. Do
not classify a source path as implementation merely because it is
not a recognized document. This keeps kind-detect as the only gate
without turning arbitrary files into an invented rubric.

Resolve the implementation target in this order:

1. Use the change target the user names (range, ref, commit, or
   paths).
2. Otherwise use the already-established change target in the
   current task/session.
3. Otherwise, in a git worktree with one unambiguous pending change
   set, review tracked and untracked implementation files in that
   set. State the resolved base and target before judging.
4. If the target or base is ambiguous, ask once. Do not silently
   widen to the repository or pick a convenient branch.

Resolve governing intent from named or in-session published design
and approved plan/runbook artifacts. If none is available, the
implementation kind may still review intrinsic correctness, safety,
tests, and repository fit, but must name that conformance to intended
behavior could not be established. That absence is a must-fix only
when the implementation makes a completion claim whose acceptance
depends on the missing authority.

The implementation review reads the complete change, relevant
unchanged callers/callees and interfaces, affected tests, and host
instructions. It runs proportionate read-only diagnostics and the
host's relevant verification commands when safe and available. A
diff is an index, not the review boundary: follow changed behavior
far enough to test its actual consequences.

`kinds/implementation.md` supplies these code-specific axes on top
of the shared adequacy/materiality rule:

- **intent:** the change implements the governing requirements and
  acceptance criteria without unrelated product behavior;
- **correctness:** control flow, data flow, error paths, boundary
  conditions, compatibility, and security/privacy consequences are
  sound;
- **integration:** callers, contracts, migrations, configuration,
  and operational custody agree with the surrounding system;
- **verification:** tests and diagnostics exercise the material
  behavior, including a credible falsification of high-impact
  guards; passing tests that cannot fail for the defect do not count;
- **scope and residue:** no accidental generated files, debug
  artifacts, dead paths, or unexplained unrelated changes remain.

Implementation verdicts use the same conversation vocabulary and
finding shape, but a different close:

- `needs-rework` or `approve-with-changes`: name whether the listed
  findings block completion, say that they return to implementation
  work, and stop. Do not offer `refine` and do not modify code.
- clean `approve`: say the reviewed change is adequate for the
  declared completion claim and stop.
- never write document front-matter, publish, mint a review record,
  or turn a code-review verdict into a durable gate.

The depth dial applies to implementation review as it does to
documents. Its subagents remain read-only.

### Adequacy (one home)

Add a short principle as the **first bullet** under
`skills/inspector/SKILL.md` *Brief the human* (not a second
heading):

> Inspector is an adequacy gate, not an artifact maximizer. Its
> job is to decide whether the artifact is safe and sufficient
> for its declared next step (publish, sequence, walk, claim complete). Preserve
> safety, correctness, feasibility, and falsifiable acceptance.
> Do not add requirements, optimize beyond the declared goal,
> demand execution evidence during design, or delay delivery for
> improvements that can safely remain optional. User-stated
> deadlines affect optionality, never the safety or correctness
> threshold.

Verb and kind files do not restate this paragraph. They apply it.

### Shared floor (`verbs/review.md` step 2)

Keep the floor. Condition four clauses. Kind files do not override
the shared machine; they stop repeating the unconditioned forms.

- **Alternatives** only where *this* artifact makes a product or
  architectural decision. Plans and runbooks do not restate
  alternatives already settled by their governing spec or ADR.
  ADR kind keeps its own "alternatives honestly weighed" axis —
  that artifact *is* the decision. Founding's mapped *Rejected
  alternatives* H2 is a shape gap when empty, not a shared-floor
  finding.
- **Population attribution** only on numeric values that **gate
  acceptance**, not rough sizing or contextual measurements.
- **Scope is one artifact's worth** is a reviewability test, not
  a size preference. Split only when the artifact cannot be
  approved or executed independently as written.
- **Unambiguous** is material. Wording ambiguity blocks only when
  two plausible readings would change behavior, ownership, safety,
  sequencing, or acceptance.

`kinds/spec.md` currently restates population attribution and
"one feature's worth". Delete those restatements; the floor
plus spec's remaining axes (implementable from this file;
Slices consistent with Mechanism when present) are enough.

### Materiality (emit-time, `review` step 4)

Still run both axes. Filter before emitting.

A **must-fix** requires a concrete failure scenario showing that
the artifact as written could produce an unsafe result, the wrong
product, omission of a stated goal, an unexecutable plan, or an
unverifiable completion claim. State that impact in the finding.
If no such counterexample exists, the concern cannot block:
omit it, or emit it as nice-to-have only when it is a material
improvement inside the declared goal and cheaper to name than to
rediscover.

Preferences, future extensibility, stronger-than-needed evidence,
alternative formulations, and work outside the declared goal are
omitted. "More complete" and "I would design it differently" are
not findings.

**Compress by root cause.** One finding with affected locations,
not every manifestation. Omit optional observations whose expected
benefit is lower than the cost of amendment and re-review. If the
central claim, invariants, execution path, and acceptance gate are
sound, approve (or `approve-with-changes` only for optionals the
reviewer chose to emit). Do not hunt to populate the report. No
numeric cap.

### Red-proof (narrowed, still on the floor)

Replace "every guard/absence-style test needs a red-proof —
disable the guarded mechanism once and show the test fails, or
argue concretely why the fixture can exercise the failing arm"
with:

> A high-impact absence guard used as **acceptance evidence**
> must prescribe a credible red-proof (how the invariant can be
> falsified). A concrete failing fixture or a data-flow argument
> is sufficient at spec/plan review. Actual mutation /
> disable-and-show evidence belongs to implementation unless the
> artifact claims the proof has already run. Do not require
> bespoke mutation machinery for every guard.

### Depth dial

Default remains off. When on: every lens gets the same
materiality test; synthesize by root cause; do not union every
suggestion; reviewer disagreement is not itself a blocker; a
skeptic's inability to refute the central claim is positive
evidence for approval. The skeptic's job remains "try to disprove
the central claim." No per-lens numeric cap.

### Document review-close (the stop)

The document pipeline stays:

```
review  →  (caller publishes)        →  (host sequences / walk)
        →  stay draft                →  refine  →  review  →  …
```

Each arrow is still a stop. Qualify "No verb invokes the next":

- a `refine` confirmation that asks for `review` after apply
  (named re-review), **or** the next utterance that accepts the
  after-apply offer of `review`;
- a failing document `review`, **or** an `approve-with-changes` live door,
  whose next utterance accepts the offer of `refine`.

Same-turn auto-enter remains forbidden.

**Document `needs-rework`.** After the verdict dump: one sentence the human
can act on, then the path, then the offer: `refine`. Stop. Do not
classify, do not propose amendments, do not amend, do not write
front-matter.

Next-utterance parse (new, failing-document-review wait only):

1. **Reject** (closed set): `stop` / `don't` / `not yet` / `I'll
   fix it` / `I'll edit it myself` → do not start `refine`. Stay
   `draft`.
2. **Accept the offer** (open set): any clear acceptance,
   including `yes`, `do that`, `refine`, `/inspector refine`,
   `what do you think`, `what do you think of the findings`,
   `what would you recommend`, `what fixes would you recommend`,
   `how should we refine this`, `recommend fixes`, `let's fold`.
   **Do:** follow `verbs/refine.md` on the in-session findings
   (resolver step 4). Name the artifact in the opening line.
3. **Unclear** → ask once whether they want `refine`. Do not
   start it. Do not write.

**`approve-with-changes`.** Keep the passing wait-for-accept
(step 5). Changes to that parse:

- `refine` leaves the reject set and becomes a **live door**:
  do not write `published`; start `refine` on the in-session
  findings (same accept-the-offer paraphrases as above).
- Accept of the *verdict* still publishes, then honors the rest
  of the utterance.

**Clean `approve`.** Publish-only wait, unchanged, except:
`refine` / the offer paraphrases are **not** accept-to-publish.
If the dump listed nice-to-haves, those phrases are the same live
door as `approve-with-changes`. If the dump had no findings, ask
once whether to publish; do not start `refine` on an empty list.

**Description.** Add the habitual phrases as refine-shaped
triggers (`what do you think of the findings`, `what fixes would
you recommend`) so a later turn without a slash still routes.
Stay ≤ 1024 characters. Do not put the adequacy principle in the
description (trigger, not summary).

*One ask per stop* (SKILL.md) lists the failing-review offer next
to passing-review accept and refine's stops. Named re-review and
next-utterance accept of an offer are the exceptions. Empty
refine (below) is not a proposal stop — it never opens one.

### Re-review posture

Named re-review still runs `verbs/review.md` (not a different
file, not a delta mode). When this session just applied a `refine`
package on this artifact — or skipped apply because nothing
material remained — and `review` is now running from that named
path **or** from next-utterance accept of the after-apply offer,
the **re-review posture** is on:

- Walk both axes (regressions and missed safety still get
  caught).
- Confirm the accepted amendments.
- A new must-fix only if the fold created it, or a
  safety / correctness / execution / acceptance blocker was
  missed. No new style, completeness, optimization, or
  future-proofing findings on that pass.

A later-session `/inspector review`, or a same-session review
that is not post-refine on this artifact, is a full review.

The after-apply offer of `review` gains the same next-utterance
parse as the new refine offer (`yes` / `do that` / `review` /
paraphrases → start `review` with re-review posture). Reject
leaves `draft` and does not start `review`.

### Refine calibration (`verbs/refine.md`)

**Omitted severity.** Replace "if omitted, treat as must-fix"
with: severity on the finding is a claim to verify. If omitted,
apply the materiality test independently. Classify must-fix /
`keep` only when a concrete blocking counterexample exists;
otherwise `keep-optional`, `push-back`, `resolved`, or omit.
Uncertainty alone does not elevate severity. This is the import
path for pasted and council findings.

**Ask-hold.** Replace "one unresolved `ask` holds the proposal"
with: an unresolved `ask` holds only the amendments whose product
meaning depends on its answer. Defer an unrelated optional
question and continue with independently verified must-fixes.
Stop the entire proposal only when the answer changes a
product-class amendment, the artifact's goal, or the safety and
acceptance boundary. Park-ack is unchanged (does not use the
`ask` exit).

**Empty package.** After classify, if every finding is `resolved`,
`push-back`, omit, or recommended `deferred` — no `keep` and no
`keep-optional` the owner recommends taking — report that no
amendment is recommended and **stop**. Do not generate a
remediation table that requires confirmation. There is still no
skip-proposal token when there *is* something to fold.

- Last verdict was `needs-rework`: offer `review` (do not run
  it). The artifact is still `draft`; a fresh passing verdict is
  how it becomes publishable. Next-utterance parse matches the
  after-apply offer (accept starts `review` with re-review
  posture).
- Last verdict was passing: restore review's passing wait
  (step 5). One sentence that the document is still ready; on
  accept, follow `verbs/review.md`'s **Write** rules (same
  session, same opportunistic `records.sh` / file-mode /
  founding-shaped no-write). Refine does not grow a second
  publish protocol.

**Deadlines.** When the human has stated that the goal is stalled
or a deadline is approaching, default `keep-optional` to defer
unless the item is unusually cheap and materially valuable.
Never move a genuine must-fix out of `keep`.

**Group** repeated manifestations before producing the table. Do
not amend merely so a later review can observe that a suggestion
was addressed.

Classify vocabulary stays: `keep` / `keep-optional` / `push-back`
/ `resolved` / `ask` / park. Do not add a parallel taxonomy.
Review *omit* means the dump never listed the concern, so refine
never sees it.

### Kind files

**`kinds/spec.md` — substrate-skeptic default off.** Replace
"Substrate-skeptic **on** … is a finding even when every claim
about `HEAD` is true" with: default off. Enable when the artifact
claims a durable architecture, the user asks for a clean-slate
design, or substrate coupling threatens the stated goal. A
mechanism's relationship to existing substrate is not itself a
finding. Emit only when the coupling can prevent the goal,
violate a declared non-goal, or create avoidable lasting
complexity material to the current decision.

**`kinds/plan.md` — slice 1 is the thinnest risk-retiring step.**
Replace "slice 1 is the thinnest end-to-end path; later slices
widen" with: slice 1 is the thinnest useful risk-retiring step —
an end-to-end tracer when appropriate, otherwise a necessary
prerequisite, feasibility proof, or custody boundary. Later
slices widen or consume that result. Do not restructure a
coherent dependency-ordered plan merely to manufacture a tracer.
Keep independently testable slices and complete acyclic blocking
edges.

**Other kinds.** ADR, founding, roadmap, runbook inherit the
conditioned shared floor. No further kind-file edits unless a
kind restates an unconditioned floor clause (none do today
beyond spec).

### Project doctrine and `/inspector setup`

Inspector kinds are living, normative review policy. They therefore
land at:

```
<agent-workspace>/doctrine/inspector/<kind>.md
```

The doctrine home is open workspace substrate. No skill owns the
container as a whole. Ownership is path-level: inspector may deploy
and tend `doctrine/inspector/`; it may not seed, validate, repair, or
interpret sibling doctrine. Conversely, another skill must not
rewrite inspector's subtree.

Normal `review` and `refine` are read-only with respect to doctrine.
For the selected kind, resolve the project path after resolving
`<agent-workspace>`. A present project file wins; an absent file
falls back to the bundled `kinds/<kind>.md`. Home presence is not
kind presence, and neither verb creates directories. A host-added
kind file remains eligible through its own discriminator. There is
no overlay merge and no hook: one complete project file is the
effective policy.

A project kind may tune its discriminator, soundness axes,
groundedness extras, and refine-legal locations. It may not replace
the verb machine: adequacy/materiality, verdict vocabulary, status
writes, stop/confirm parsing, implementation's review-only boundary,
and the prohibition on invented rubrics remain package rules. This
keeps customization at the criteria layer without letting one kind
silently redefine inspector's custody.

Add the explicit verb:

```
/inspector setup [<root>]
```

`<root>` defaults to the current repository root and must already be
an existing directory. The verb resolves `<agent-workspace>` from the
root's front door, default `.dev`. Reject an empty, absolute, `.`, or
root-escaping declaration before writing. Then pass the absolute
`<agent-workspace>/doctrine/inspector/` destination to this package's
`scripts/kinds-deploy.sh`. The script resolves the bundled `kinds/`
directory relative to its own package; it never opens `AGENTS.md` or
`CLAUDE.md`.

Explicit setup authorizes creation of the resolved workspace,
`doctrine/`, and `doctrine/inspector/` parents even when the workspace
was declared and is absent. That authority is narrow: create only
the parents needed for inspector's subtree and copy only inspector's
bundled kind files. Do not create a doctrine README, core/station
content, hooks, flows, templates, records, a front-door registration,
or any sibling doctrine.

Deployment is absent-only and idempotent:

1. Enumerate every bundled `kinds/*.md`; do not hardcode the current
   count.
2. Destination absent → copy the bundled file byte-for-byte.
3. Destination is any existing file or symlink → preserve it as the
   incumbent, including a dangling symlink; never follow it to write.
4. A required parent that is not a directory, or a destination that
   is a directory/other incompatible entry → report the collision and
   exit nonzero. Files copied before a later collision are safe;
   rerunning after repair completes the partial deployment without
   overwriting them.
5. Leave host-added extra files untouched. A later bundle that adds a
   new kind is deployed on rerun because that destination is absent;
   existing project kinds remain frozen until a human performs a
   judgment-assisted diff.

Print compact `created=<path>` / `preserved=<path>` facts and a final
count summary. Setup does not commit. It is optional enrichment, not
an operating floor: a bare inspector must review every bundled kind
without it.

Amend `skills/skill-builder/docs/DOCTRINE.md` with the general rule
this exercises:

- doctrine remains one of the four landing classes; inspector kinds
  are doctrine, not a fifth class;
- the doctrine container is open and ownership is path-level;
- reads always resolve-then-test and never mkdir;
- an explicitly invoked setup/deploy verb may create the resolved
  parents for only the invoking skill's owned doctrine subtree,
  including under a declared absent workspace;
- incumbent-wins, copy-bundled-then-customized, and no-floor behavior
  remain unchanged;
- remove the narrow `<agent-workspace>/inspector/` mkdir exception and
  the claim that clankshop owns or assembles the doctrine container.

Inspector's typed edges become `produces: doctrine` as well as
`consumes: doctrine`: setup emits project review doctrine; review and
refine consume the effective project-or-bundled kind. This is not a
dependency on a composer or another skill.

### Files this changes

- `skills/inspector/SKILL.md` — adequacy; document and implementation
  targets; project-doctrine resolver; setup dispatch; pipeline
  exceptions; one-ask list; description triggers; doctrine edges
- `skills/inspector/verbs/review.md` — floor, materiality,
  red-proof, dump compression, depth dial, failing /
  with-changes / clean-approve parse, re-review posture;
  implementation dispatch and close
- `skills/inspector/verbs/refine.md` — omitted severity,
  ask-hold, empty package, deadline defer, grouping,
  after-apply next-utterance parse; document-only boundary
- `skills/inspector/verbs/setup.md` — resolve the workspace and deploy
  inspector's doctrine subtree
- `skills/inspector/scripts/kinds-deploy.sh` — deterministic,
  absent-only bundled-kind deployment
- `skills/inspector/scripts/tests/run.sh` and
  `skills/inspector/scripts/tests/kinds-deploy-test.sh` — throwaway
  setup/deployment fixtures
- `skills/inspector/kinds/implementation.md` — explicit-only code
  target discriminator and implementation axes
- `skills/inspector/kinds/spec.md` — substrate default off;
  drop restated floor clauses
- `skills/inspector/kinds/plan.md` — risk-retiring slice 1
- `skills/skill-builder/docs/DOCTRINE.md` — open doctrine container,
  path-level ownership, explicit-setup creation rule, four landing
  classes, removal of the old inspector special case

No PACK bump: inspector remains the same pack member even though its
surface and payload grow. No clankshop file changes. The earlier
`<agent-workspace>/inspector/` proposal did not ship as a deployed
project migration contract, so setup does not probe, copy, move, or
delete that path. If a real host incumbent is later discovered, its
migration requires an explicit design rather than a silent adoption.

## Verification

How we'll know it works:

1. `skills/skill-builder/scripts/skills-lint.sh` against
   `skills/inspector/`, then the library-wide lint gate — `fails=0`.
   Description ≤ 1024; doctrine producer/consumer edges are valid.
2. `skills/inspector/scripts/tests/run.sh` in throwaway fixtures:
   - fresh default setup creates `.dev/doctrine/inspector/` and each
     bundled kind is byte-identical;
   - a declared, absent workspace is created at its declared path;
   - rerun preserves a planted project marker and byte identity;
   - deleting one deployed kind restores only that missing file;
   - host-added extra kinds remain untouched;
   - a file in a required-parent position and a directory at a kind
     destination both fail nonzero with the collision named;
   - no setup case creates a doctrine README, sibling subtree, hook,
     flow, template, record, or front-door block;
   - red-proof the incumbent guard: mutate exactly one preserve arm
     in a temporary script copy, prove the planted-marker case fails,
     restore, and confirm byte identity.
3. Grep gates on the live files (fail on 0 hits / on forbidden
   leftovers):
   - SKILL.md contains the adequacy sentence "adequacy gate"
     and an offer of `refine` in the one-ask / exception
     language.
   - SKILL.md and `verbs/setup.md` use
     `<agent-workspace>/doctrine/inspector/`; neither the live
     inspector package nor portable doctrine contains
     `<agent-workspace>/inspector/` or calls inspector kinds a fifth
     landing class.
   - SKILL.md dispatches `setup`, names seven bundled kinds without
     hardcoding deployment enumeration, and declares both produces /
     consumes doctrine.
   - `verbs/review.md` contains the materiality counterexample
     test; does **not** contain the unconditioned "every
     **guard/absence-style test** … needs a **red-proof** —
     disable the guarded mechanism once".
   - `verbs/review.md`'s failing-document branch offers `refine` and
     does not stop on a bare "Leave `draft`." Its implementation
     branch does not offer `refine` or publish.
   - `verbs/refine.md` does **not** contain "if omitted, treat
     as must-fix" or "One unresolved `ask` holds the proposal."
   - `verbs/refine.md` contains the empty-package stop (no
     amendment recommended) and rejects implementation/code targets.
   - `kinds/implementation.md` is explicit-only and contains intent,
     correctness, integration, verification, and residue axes.
   - `kinds/spec.md` does **not** contain "Substrate-skeptic
     **on**" / "finding even when every claim".
   - `kinds/plan.md` contains "risk-retiring" and does **not**
     require "thinnest end-to-end path" as the only legal
     slice 1.
4. Followability read, as a fresh agent, of these conversation
   shapes against the written verbs:
   - Failing document review → dump + offer `refine` + stop. Next
     "what do you think of the findings?" → `refine` starts
     (resolver step 4). Same-turn dump does not include a
     remediation table.
   - `approve-with-changes` + `yes` → publish. Same dump +
     `refine` → no publish, `refine` starts.
   - Clean `approve` + `lgtm` → publish. Clean `approve` with
     no findings + "what do you think?" → ask once, do not
     refine.
   - `refine` with all push-back / defer → no proposal wait;
     if last verdict was `needs-rework`, offer `review`.
   - Named re-review after a fold does not emit a new
     completeness nit that was available on the first pass.
   - Explicit implementation review resolves the named diff and
     governing artifacts, follows affected unchanged code, runs the
     relevant host gate, and emits a conversation verdict without a
     status write or refine offer.
   - Ambiguous implementation target → ask once; do not review the
     entire repository. `/inspector refine implementation` → explain
     the review-only boundary; do not edit code.
   - Review/refine with no deployed project kind uses the bundle;
     one deployed project kind overrides only that kind.
5. Boundary checks:
   - inspector names no sibling skill in `description:` and depends
     on no composer to function;
   - `git diff --exit-code -- skills/clankshop/` stays clean for this
     feature;
   - no implementation path deploys or validates inspector files
     through clankshop;
   - the portable doctrine says open container + path-level
     ownership, not a new doctrine skill.

## Slices

### S1 — Router + review-close + adequacy on review

Principle, stops, floor, materiality, red-proof, dump, confirm-
parse, re-review posture, depth dial.

- **id:** S1
- **paths:** `skills/inspector/SKILL.md`,
  `skills/inspector/verbs/review.md`
- **verify:** lint on `skills/inspector/`; grep gates for
  adequacy, refine-offer, materiality, narrowed red-proof,
  failing-branch offer; followability cases failing-review
  offer, with-changes live door, clean-approve publish-only.

### S2 — Refine calibration

Severity, ask-hold, empty package, deadline defer, grouping,
after-apply next-utterance parse.

- **id:** S2
- **paths:** `skills/inspector/verbs/refine.md`
- **verify:** lint; grep gates for omitted-severity replacement,
  ask-hold replacement, empty-package stop; followability
  cases empty-package, optional-ask-does-not-hold-must-fixes,
  after-apply `yes` starts review with re-review posture.
  Requires S1's re-review posture paragraph (refine names it).

### S3 — Kind calibration

Spec substrate default off; plan risk-retiring slice 1; drop
spec restatements of the shared floor.

- **id:** S3
- **paths:** `skills/inspector/kinds/spec.md`,
  `skills/inspector/kinds/plan.md`
- **verify:** lint; grep gates for substrate-off and
  risk-retiring; spec kind no longer restates population
  attribution or "one feature's worth". Independent of S2;
  after S1 so the floor S3 relies on is already conditioned.

### S4 — Completed implementation review

Add the explicit-only implementation kind and dispatch code review
through the shared adequacy machine without document publishing or
code editing.

- **id:** S4
- **paths:** `skills/inspector/SKILL.md`,
  `skills/inspector/verbs/review.md`,
  `skills/inspector/verbs/refine.md`,
  `skills/inspector/kinds/implementation.md`
- **verify:** lint; grep implementation axes and document-only
  refine boundary; followability cases named diff + governing
  artifacts, missing governing artifact, ambiguous target, passing
  implementation, failing implementation with no refine/publish.
  Requires S1's materiality and close split.

### S5 — Inspector-owned project doctrine

Move effective project kinds under the open doctrine home and add
explicit absent-only deployment with a deterministic fixture harness.

- **id:** S5
- **paths:** `skills/inspector/SKILL.md`,
  `skills/inspector/verbs/setup.md`,
  `skills/inspector/scripts/kinds-deploy.sh`,
  `skills/inspector/scripts/tests/run.sh`,
  `skills/inspector/scripts/tests/kinds-deploy-test.sh`,
  `skills/skill-builder/docs/DOCTRINE.md`
- **verify:** inspector deploy harness including the broken-guard
  red-proof; inspector and library lint; old-path/fifth-class grep;
  no-clankshop diff; fresh-agent read of project-copy → bundled
  fallback. After S3 and S4 so first deployment carries every final
  bundled kind.

S1 before S2, S3, and S4. S2 and S3 may land in either order after
S1; S4 follows S1. S5 follows S3 and S4. One landing after S5.

## Out of scope

- Same-turn auto-enter of `refine` from `review`.
- Editing or repairing code from implementation review; inspector
  reviews the completed change but does not become its implementer.
- A project hook, overlay/merge format, or shopbook flow for review
  policy.
- Numeric finding caps.
- `skills/contractor/templates/plan.md` tracer authoring
  default.
- `skills/clankshop/flows/feature.md` build-time red-proof.
- Any clankshop setup/migrate/check guard for inspector doctrine.
- Removing or replacing clankshop's stations/personas; that is a
  separate clankshop change and this spec must not invent its
  replacement.
- A generic `doctrine` skill or single owner for the doctrine
  container.
- PACK version (member set unchanged).
- Automatic adoption, move, or deletion of historical/proposed
  `<agent-workspace>/inspector/` content.
- Automatic overwrite or upgrade merge of a project kind.
- Changing verdict vocabulary (`approve` /
  `approve-with-changes` / `needs-rework`) or document
  caller-publish.
