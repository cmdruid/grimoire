---
schema: foreman/operation@1
title: Complete the remaining Grimoire app phases
use-when: Phase 4 is complete on stream/app and Phases 5 through 7 must be planned, reviewed, refined, implemented, and verified without intermediate landing.
shape: procedure
status: active
areas: [app, delivery]
tags: [grimoire, workstream, phase-completion]
verified-against: sha256:d30b6eb641454c169796b5baf8934dee083687a61039d83637f4d30bf6b76dfe
---

# Complete the remaining Grimoire app phases

## Preconditions

- Work only in the existing `app` workstream on branch `stream/app`; its `WORKSTREAM.md` custody
  checks pass and the main session remains the sole writer.
- The product contract at
  `.records/specs/2026-08-31-grimoire-symlink-package-manager.md` and the roadmap at
  `.records/plans/2026-09-01-grimoire-hard-cut-rewrite-roadmap.md` are published and remain the
  scope authority.
- Phase 4 is committed and gate-green. Phases 5, 6, and 7 remain incomplete.
- Keep completed phases accumulated on `stream/app`; do not ship, rebase onto a moved target,
  waive a gate, or expand permissions without the stop required below.

## Procedure

1. Reconcile the workstream hand-off, branch, target movement, roadmap, existing phase plans, and
   live code. If `main` moved, follow the workstream's sync procedure before authoring the next
   phase plan. Preserve unrelated root or worktree changes.
2. For each remaining phase in order — Phase 5, then Phase 6, then Phase 7 — repeat this complete
   phase cycle:
   1. Re-read that roadmap phase, its dependencies, the published product contract, repository
      doctrine, relevant source, tests, and prior implemented plans. Confirm the phase is still
      real and not already completed.
   2. Draft one dated `contractor/plan@1` implementation plan from the roadmap phase. Keep it at
      `status: draft`; include a read-only Task 0, thin end-to-end slices with explicit dependency
      edges, exact paths, red-first verification per slice, the complete phase gate, and the
      close-the-books boundary.
   3. Review the complete draft against the effective plan doctrine and live tree. Fold every
      supported must-fix or recommended change through the normal revision procedure and re-review
      until the verdict is exactly `approve`. Accept that verdict and publish the plan with
      `stage: approved`.
   4. Run at least one explicit refinement pass on the approved plan. A supported no-op satisfies
      the pass. If refinement proposes changes, accept them only when they preserve the roadmap
      phase's scope, product behavior, ownership and security boundaries, dependency order, and
      verification obligations; then complete the mandatory full review/revision loop until the
      refined plan again receives `approve` and is republished at `stage: approved`. Record the
      pass outcome — no-op, or accepted changes plus reapproval — in the current goal progress and
      the next workstream save; do not add review-history prose to the plan.
   5. Walk every approved slice in dependency order. Start each slice red, implement the root
      mechanism, run its targeted verification and shared workspace check, and commit one coherent
      imperative commit. Do not stop between slices unless a documented stop condition fires.
   6. Run the plan's full phase gate. Correct in-scope failures at their root and rerun affected
      checks. Mark the plan `stage: implemented` only after every slice and gate is green, then run
      the host close-the-books sweep and commit any legitimate in-scope closure artifacts.
   7. Refresh the workstream hand-off with commit and gate evidence. After Phases 5 and 6, keep
      accumulating and immediately start the next phase without proposing a ship. After Phase 7,
      stop at the feature-completion seam with the entire roadmap track complete and ready for the
      user's final ship decision.
3. Bounded decisions may be auto-accepted only as follows:
   - accept a plan review verdict only when it is exactly `approve` with no material findings and
     the plan remains within the published roadmap phase;
   - accept a revision or refinement package only when every edit is confined to the current plan
     and preserves the scope, behavior, custody, security, dependency, and verification invariants
     named above;
   - choose implementation details already delegated by an approved plan when tests can decide
     them and they do not alter public policy or permissions.
   Any uncertainty about those criteria is a stop, not permission to infer broader authority.

## Outputs

- One published, approved, refined, and finally implemented plan for each of Phases 5, 6, and 7.
- Gate-green implementation commits for every plan slice, accumulated on `stream/app`.
- Updated README, roadmap, records, and close-out evidence required by the approved plans.
- A clean workstream at the final feature-completion seam, ready for an explicit ship decision.

## Verification

- Before activation, check this operation's closure and confirm that the published roadmap, product
  contract, plan/review/refine/build procedures, and workstream accumulation rules support every
  instruction without a missing owner or contradictory gate. Use the completed Phase 4 lifecycle
  as execution precedent for plan approval, refinement, gated implementation, and accumulation.
- During a goal run, do not declare a phase complete until its plan is a published
  `contractor/plan@1` record at `stage: implemented`, every slice is checked complete, and the goal
  progress plus workstream hand-off record one explicit refinement outcome before implementation.
- At final completion, confirm the Phase 7 integration gate and every narrower phase gate passed
  without waiver; the `app` worktree is clean; `stream/app` contains all Phase 5–7 commits and none
  were landed to `main`; and the roadmap and README consistently describe verified behavior.

## Recovery

- On context loss, re-enter only through `/workstream load app`, reconcile `WORKSTREAM.md` with Git
  and the current phase plan, then use the published goal record's Resume command from that same
  stream.
- Resume at the first unchecked plan slice or, before implementation, at the current document gate.
  Disk and committed evidence outrank conversational summaries.
- Stop for destructive action, target movement that cannot be cleanly synchronized, credentials,
  policy or scope change, verification waiver, permission expansion, source drift, an unresolved
  plan decision, or a recovery condition that needs human authority.

## Verification evidence

- Closure check passed for `foreman/complete-remaining-app-phases` at
  `sha256:d30b6eb641454c169796b5baf8934dee083687a61039d83637f4d30bf6b76dfe`;
  the source is current and structurally valid.
- The product contract and roadmap are published. The roadmap still declares Phase 5 after Phase
  4, Phase 6 after Phase 4, and the Phase 7 close-out after both adapter phases.
- The effective Contractor contract supports roadmap-phase planning, approved-plan execution,
  per-slice verification, implemented-stage closure, and close-the-books. The effective Inspector
  contract supports review/revision to approval plus an explicit refinement pass whose accepted
  changes trigger mandatory full re-review. Workstream's milestone cadence supports accumulating
  completed phases without landing.
- Phase 4 supplies execution precedent in this same workstream: its published plan is
  `stage: implemented`, all seven slices are checked, the hand-off records accepted review and
  refinement, the full gate passed, and the phase remains completed-but-unshipped.
- The goal-run completion checks name durable evidence for each requested outcome: implemented
  phase plans, recorded refinement outcomes, phase/final gates, clean accumulated Git state, and
  roadmap/README close-out consistency.
