# `plan` · a proportionate implementation plan

Produce the smallest sequence that makes the accepted outcome executable.
Planning sharpens scope; it does not widen it.

## Procedure

1. **Resolve scope.** Accept a clear user request, an accepted draft or spec,
   or one named roadmap phase. Extract the outcome, affected surface,
   constraints, non-goals, and completion evidence. Ask only about a missing
   decision that materially changes implementation, safety, or acceptance.
2. **Ground what matters.** Read the host instructions and the load-bearing
   code, interfaces, and tests. Verify only claims that affect the plan:
   - run `scripts/ground-check.sh <root> <source>` when a source document's
     file or line references matter;
   - remeasure a numeric claim before relying on it;
   - search for prior art only when its existence would change the approach;
   - use a compiler or equivalent semantic check when text search cannot
     establish whether a symbol is live.
   There is no universal repository sweep, preliminary task, or delegation
   pass.
3. **Choose the lightest shape.** An atomic plan is the default for bounded
   work. Split it only for a real dependency, independently useful increment,
   risky transition, or distinct verification boundary. Use an end-to-end
   tracer when integration risk makes it useful; do not force one onto a local
   change.
4. **Write executable intent.** Include the outcome, affected paths or
   components, the change, and proportionate verification. Add non-goals or
   assumptions only when they prevent ambiguity. Include exact code only when
   a delicate interface or transformation would otherwise remain unclear.
   Require a failing regression first only when reproducing a defect or
   protecting regression-prone behavior makes it useful.
5. **Control discoveries.** Add newly found work only when direct causal
   evidence proves the accepted outcome cannot succeed without it. Report a
   concrete independent issue as a follow-up; omit speculation.
6. **Select the output.** Keep the plan in the conversation by default. Write a
   named ordinary file if the user asks. Mint a durable Contractor record only
   when the formal level in `SKILL.md` applies; resolve `templates/plan.md` and
   use the durable record contract there.
7. **Check the plan.** Confirm that every requested outcome is covered, every
   listed step is necessary, dependencies are real, and verification proves
   the requested result. Independent review is reserved for an explicit
   request, material uncertainty, or a formal high-risk workflow.

Examples anchor the boundary: a local Docker readiness fix normally gets one
atomic plan with targeted Compose verification; browser persistence discovered
nearby is a follow-up unless readiness depends on it. An irreversible
production data migration gets a durable plan with staged execution, rollback
or recovery evidence, and an explicit gate.

## Closing

If the user asked only for a plan, present it and stop. If they also authorized
the build, continue to `build` without asking for duplicate approval. Never
invoke another verb merely because this one completed.
