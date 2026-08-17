# `review` · critique a roadmap, plan, or runbook

Independent second-set-of-eyes on a **job** artifact — distinct from the
self-review baked into `plan` (the author checking their own work; this verb is
not the author). Artifact-free: findings + a verdict in context, no file
written (except a `needs-rework` write-back). It reviews **documents, not
diffs** — a code change is the host's code-review tooling.

This verb reviews **roadmap / plan / runbook only**. A spec or design doc is
the wrong review verb — refuse it.

## Procedure

1. **Read the whole doc; detect its kind** (roadmap, plan, runbook) from
   front-matter `tags:` / `doctype` or shape. A spec, design doc, or ADR →
   refuse ("wrong review verb"). Kind picks the rubric weighting.
2. **Axis 1 — soundness** (internally consistent, feasible):
   - no section contradicts another;
   - the approach is justified with alternatives honestly weighed;
   - scope is one artifact's worth; every requirement is unambiguous;
   - **tracer slices** (a plan): slice 1 is the thinnest end-to-end path; later
     slices widen; each is independently testable;
   - **blocking edges** (roadmap/plan) are complete and acyclic; each
     slice/phase has a real verification/gate;
   - **numeric acceptance target** must attribute its population to the
     mechanism's target class (a real count over the wrong class survives every
     rubric and dies at measurement);
   - every **guard/absence-style test** ("asserts X never happens") needs a
     **red-proof** — disable the guarded mechanism once and show the test
     fails, or argue concretely why the fixture can exercise the failing arm.
3. **Axis 2 — groundedness** (conforms to the codebase — and to core doctrine
   when a workshop is present): run `scripts/ground-check.sh` `<root> <doc>`,
   then **re-read the load-bearing signatures/code the claims rest on** (a
   clean ground-check finds moved files; the trap is a confident doc citing a
   function that never existed — or a `file:line` that resolves but points at
   different code than the prose claims). On a workshop host, check the doc
   against `core/` (invariants, gotchas) and the `status: current` spec + live
   ADRs. **Substrate-skeptic is default off** here; turn it on only when a plan
   claims a mechanism shaped by deletable substrate (a code built-in, an
   integer pipeline, a frozen baseline) — then ask *which mechanisms would not
   exist in a from-scratch implementation?*
4. **A runbook** is a thinner pass: confirm the completeness check in
   `verbs/runbook.md` step 4 (plan-sourced vs roadmap-sourced). That is
   the same check `runbook` already ran — this verb confirms it and
   still does **not** replace plan review of the referenced plans.
5. **Report the verdict, in context**: `approve` / `approve-with-changes` /
   `needs-rework`; findings ranked by severity, each as location → what's wrong
   → why it matters → a concrete fix, must-fix separated from nice-to-have; a
   confidence note on anything unsure — never a guess presented as fact. **A
   blocking verdict is a durable fact about the artifact, not session
   chatter:** on `needs-rework`, also write the finding list into the artifact
   itself (a dated "Review history" section the owner prunes on resolution).
   An approve verdict changes nothing and stays in context.

Depth dial (default off): for a high-stakes artifact, dispatch a few
**read-only** subagents in parallel — each a distinct lens, one a skeptic
trying to *refute* the doc's central claim — and synthesize. Never an editing
subagent.

Terminal step: hand the verdict to whoever owns the artifact — `review`
changes nothing itself (except the `needs-rework` write-back).

## Acting on review feedback — yours, a human's, or an external reviewer's

`review` hands a verdict to the artifact's owner and stops. The receiving side
is its own discipline:

1. **Verify before implementing — feedback is a claim, not a decision.**
   Re-check it against the actual code/doc. A fold is itself unverified content
   — re-ground it like any inherited claim, or mark it
   `(unverified — check at build)`.
2. **No performative agreement.** State findings and actions plainly.
3. **One unclear item holds up the whole batch** — clarify all ambiguous items
   before implementing any.
4. **Grep before generalizing** — a "make this configurable" suggestion gets a
   usage check first; unneeded generality is YAGNI.
5. **Push back with reasoning when the feedback is wrong** — disagreement is a
   legitimate outcome; state the evidence.
