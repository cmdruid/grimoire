# `build` · execute an accepted plan or runbook

Walk the accepted job in place. Do not redesign it, enlarge it, or ship it.

## Procedure

1. **Resolve the job.** Accept a plan from the current conversation, a plan
   file, or a runbook. A roadmap is a map rather than an executable job: use a
   named phase's existing executable plan, or ask for the missing plan. Do not
   require a runbook solely because a roadmap exists.
2. **Confirm authority once.** An explicit user authorization to build the
   accepted job is sufficient. A combined plan-and-build request already
   contains that authority. In a formal durable workflow, `status: published`
   and `stage: approved` may record acceptance, but missing metadata does not
   override current explicit authorization and must not trigger a ceremonial
   write.
3. **Re-ground at the point of use.** Before changing a load-bearing path or
   interface, confirm the plan still matches the worktree. Replan only the
   affected unit when drift materially changes it; do not reopen the entire
   job.
4. **Walk the minimum units.** Execute an atomic plan directly. For a sliced
   plan, follow real dependency order. Delegation is optional and justified by
   separability or throughput, never by the mere existence of multiple steps.
   For a runbook, follow its conductor and gates without inventing work.
5. **Verify proportionately.** Run the narrowest evidence that proves each
   changed behavior, plus broader checks only when coupling or host policy
   warrants them. A failed check may justify a causal fix inside scope; an
   unrelated failure is reported, not absorbed.
6. **Handle discoveries through the scope firewall.** Include only blockers
   causally necessary for the accepted outcome. Report independent actionable
   issues as follow-ups and omit speculation.
7. **Close.** Report what now works, verification performed, and any accepted
   skip, blocker, or concrete follow-up. For a durable Contractor record, set
   `stage: implemented` after a successful formal walk if that lifecycle is in
   use. Run a host closure routine only when the host or formal job requires it.

## Job assessment

- `DONE` — the accepted outcome is implemented and verified.
- `DONE_WITH_CONCERNS` — implemented, with a concrete residual risk.
- `NEEDS_CONTEXT` — a material decision is missing.
- `BLOCKED` — an external dependency or required check prevents completion.

Translate the assessment into plain language for the user. Do not emit only the
code. The host lane still owns landing to trunk.
