---
doctype: plans
status: published
stage: implemented
schema: contractor/plan@1
tags: [plan]
---

# Inspector automatic refinement proposals — Implementation Plan

Spec: `.records/specs/2026-08-26-inspector-automatic-refinement-proposals.md`

## Global Constraints (verify vs HEAD before editing — the plan gate)

- **Published contract:** Implement the governing spec exactly. Kind doctrine selects only the
  continuation; shared verbs retain verdict, status, confirmation, proposal/apply, and transition
  semantics.
- **Human write boundary:** Automatic continuation may classify, ask, or propose in the review
  invocation, but it never applies or publishes before the documented human stop.
- **Status custody:** Review verdict turns write no status or stage. Refinement apply leaves
  `status: draft`, drops `stage: approved`, and queues a full review unless explicitly canceled.
  Accepted passing specs publish; accepted passing plans publish with `stage: approved`.
- **Effective-policy custody:** A valid workspace kind remains the complete effective policy and is
  never rewritten. A missing continuation declaration resolves by detected kind: `spec` and `plan`
  → `automatic-proposal`; other documents → `offered`; implementation → `unavailable`.
- **No parser or migration:** The policy is agent-read Markdown. Do not add a runtime parser,
  migration, setup refresh, overlay merge, hook, or compatibility file. Setup remains absent-only.
- **Implementation boundary:** Host-added policies cannot replace the reserved implementation
  discriminator or create code refinement. Implementation review is verdict-only for every
  verdict.
- **Tests prove behavior:** Extend the existing close/refine state-machine fixtures. Every new
  absence or guard check gets a deliberate red-proof before restoration; a prose-presence grep is
  not sufficient evidence for the transition behavior.
- **Coexisting work:** Preserve all unrelated dirty paths, including current Checkpoint, Foreman,
  Workstream, `README.md`, and `PACK.md` changes. Do not stage, format, or rewrite them. This job owns
  only the paths listed in its slices.
- **Snapshot warning:** The paths and signatures below were checked before drafting, but Task 0 must
  repeat against the implementation worktree before any edit.

## Task 0 — Re-ground before editing

Read-only; produce no commit.

1. Run:

   ```sh
   git status --short
   skills/contractor/scripts/ground-check.sh \
     "$(git rev-parse --show-toplevel)" \
     .records/specs/2026-08-26-inspector-automatic-refinement-proposals.md
   ```

   Confirm the governing spec is `status: published`, every rooted reference resolves, and no
   newly dirty Inspector path belongs to another session.
2. Re-read the complete governing spec and these live seams:

   ```text
   skills/inspector/SKILL.md
   skills/inspector/verbs/review.md
   skills/inspector/verbs/refine.md
   skills/inspector/verbs/setup.md
   skills/inspector/kinds/spec.md
   skills/inspector/kinds/plan.md
   skills/inspector/kinds/implementation.md
   skills/inspector/scripts/tests/review-close-test.sh
   skills/inspector/scripts/tests/refine-test.sh
   skills/inspector/scripts/tests/implementation-test.sh
   skills/inspector/scripts/tests/setup-test.sh
   docs/design/2026-08-21-architect-contractor-inspector.md
   ```
3. Search capability-wide before adding language or fixtures:

   ```sh
   rg -n "Review continuation|refinement-after-review|Close exactly once|Next-turn parse|Thrash brake|Empty material package|stop boundaries" \
     skills/inspector docs/design/2026-08-21-architect-contractor-inspector.md
   ```

   Expected baseline: no continuation policy exists yet; review always stops before refine; the
   thrash brake covers `resolved`/`rejected` but not immediate `push-back`; setup preserves
   incumbents.
4. Run `skills/inspector/scripts/tests/run.sh`. Expected baseline at plan creation: `99 passed, 0
   failed` across the five test scripts. If the baseline has changed, reconcile the plan against
   the new behavior before sizing or editing.

## Slices

- [x] **Slice 1: Automatic needs-rework proposal tracer** — requires: —
  - Files:
    - `skills/inspector/SKILL.md`
    - `skills/inspector/verbs/review.md`
    - `skills/inspector/verbs/refine.md`
    - `skills/inspector/kinds/spec.md`
    - `skills/inspector/kinds/plan.md`
    - `skills/inspector/scripts/tests/review-close-test.sh`
    - `skills/inspector/scripts/tests/refine-test.sh`
  - Change:
    1. Add `## Review continuation` with
       `refinement-after-review: automatic-proposal` to bundled spec and plan policy.
    2. Teach the router to resolve the exact three-value declaration and the omission defaults by
       detected kind, including old workspace `spec.md` and `plan.md` incumbents. A missing section
       uses the default; a present unrecognized or conflicting declaration asks/refuses. Do not
       read or modify setup state.
    3. State the ownership split once: kind policy selects continuation; the shared review/refine
       machine owns all semantics and writes.
    4. For a `needs-rework` spec or plan, report the full verdict/findings and immediately enter the
       existing refinement classification with the artifact, kind, and findings already resolved.
       Skip only standalone input resolution. Carry queued re-review intent through questions and
       the proposal stop.
    5. Preserve the existing proposal-before-apply confirmation and every explicit cancellation
       token. Do not broaden implementation refinement.
    6. Extend the close/refine fixtures with an end-to-end transition model covering bundled spec,
       bundled plan, legacy workspace incumbents with no section, offered fallback, no pre-confirm
       write, and queued re-review after accepted apply.
    7. Red-proof the tracer by changing a copied spec/plan policy to `offered`; confirm the
       automatic-transition assertion fails, then restore the fixture and confirm byte identity.
  - Verify:

    ```sh
    skills/inspector/scripts/tests/review-close-test.sh
    skills/inspector/scripts/tests/refine-test.sh
    ```

    Expected: both pass; the modeled `needs-rework` spec/plan reaches refinement without a second
    user invocation, stops before apply, and queues a full review only after accepted apply.

- [x] **Slice 2: Complete continuation matrix and safety closure** — requires: 1
  - Files:
    - `skills/inspector/SKILL.md`
    - `skills/inspector/verbs/review.md`
    - `skills/inspector/verbs/refine.md`
    - `skills/inspector/kinds/founding.md`
    - `skills/inspector/kinds/adr.md`
    - `skills/inspector/kinds/roadmap.md`
    - `skills/inspector/kinds/runbook.md`
    - `skills/inspector/kinds/implementation.md`
    - `skills/inspector/scripts/tests/review-close-test.sh`
    - `skills/inspector/scripts/tests/refine-test.sh`
    - `docs/design/2026-08-21-architect-contractor-inspector.md`
  - Change:
    1. Add explicit `offered` continuation policy to founding, ADR, roadmap, and runbook; add
       explicit `unavailable` to implementation. Keep missing host-added document policy at
       `offered`; enforce implementation as unavailable regardless of project policy.
    2. Complete the verdict matrix. Clean document reviews retain acceptance/publication.
       `approve-with-changes` on automatic kinds enters refinement; offered kinds present the
       explicit publish-as-is/refine choice; unavailable documents may publish as-is but cannot
       refine; implementation remains verdict-only.
    3. At an automatic proposal stop, parse bare acceptance as apply + queued full review. Accept
       `publish as-is` only for an `approve-with-changes` document, applying no amendment and
       publishing exactly the reviewed artifact. Keep `needs-rework` non-publishable.
    4. Broaden refinement input from the review path to retain recommended-change severity and
       support `approve-with-changes`, while standalone findings without severity remain must-fix.
    5. Complete empty-package behavior. `approve-with-changes` with no amendable recommendation
       returns to its publication offer. A `needs-rework` batch containing only resolved/pushed-back
       findings gets one unchanged full review with same-session dispositions; if the same location
       + assertion returns after `resolved` or `push-back`, classify `ask` on the first return and
       stop—never enter a second automatic cycle.
    6. Update the router diagrams, close parsing, and responsibility spine. The kind policy owns
       selection only; the shared verbs own stop implementation, verdict, confirmation, status,
       and apply. Remove both stale unconditional claims: every failing review stops, and kind files
       can never select a stop boundary.
    7. Extend the transition fixtures across all seven bundled kinds, a host-added omitted/opt-in
       policy, publish-as-is, implementation refusal, status/stage custody, empty packages, and the
       immediate recurrence brake.
    8. Red-proof each new guard using copied fixtures: permit implementation refinement, write
       before proposal confirmation, recur after `push-back`, and reintroduce the stale ownership
       statement one at a time. Count the planted occurrence, require the relevant check to fail,
       restore, and confirm byte identity before the final green run.
  - Verify:

    ```sh
    skills/inspector/scripts/tests/run.sh
    skills/skill-builder/scripts/skills-lint.sh
    skills/inspector/scripts/ground-check.sh \
      "$(git rev-parse --show-toplevel)" \
      docs/design/2026-08-21-architect-contractor-inspector.md
    ```

    Expected: all Inspector tests and library lint pass; the design document has zero unresolved
    paths; no unrelated dirty path changed. Re-read the complete router, both verb files, and all
    seven kind files after the mechanical gates to confirm one state machine.

## Done when

- Every governing-spec requirement maps to Slice 1 or Slice 2 with no open decision branch.
- Specs and plans surface verified refinement proposals without the redundant refine-request turn,
  but no artifact changes before package confirmation.
- Other document kinds and implementation follow their declared continuation policy exactly.
- Legacy workspace incumbents behave deterministically without setup, migration, or writes.
- The recurrence brake terminates the first repeated resolved/pushed-back finding with `ask`.
- Review/refine status custody, proposal stops, publish-as-is, and implementation refusal are
  covered by red-proven fixtures.
- `skills/inspector/scripts/tests/run.sh` and `skills/skill-builder/scripts/skills-lint.sh` pass.
- `skills/inspector/scripts/ground-check.sh` reports no unresolved references for every edited
  document, and a final scope check shows only the plan-owned files changed by this job.

_On completion (before landing), run the host's close-the-books sweep._
