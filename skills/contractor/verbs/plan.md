# `plan` · the tracer-bullet implementation plan

Turn the approved spec (or one roadmap phase) into a plan an implementer
executes: **thin end-to-end slices**, each proving the path through the whole
system before the next widens it — not horizontal layers that integrate only at
the end. Re-ground against the live tree before writing.

Open decision branches belong in a grill on the spec, not here. If the spec is
unsettled, stop and send those branches back.

## Procedure

1. **Resolve the input.** An approved spec, or one phase of a roadmap the user
   names. Missing → ask. A raw conversation with no spec → not this verb.
2. **Summon context** per SKILL.md *One environment probe* (build station on a
   workshop host).
3. **Slice tracer-first.** Slice 1 is the thinnest change that exercises the
   riskiest/newest path end to end (a green unit test can hide a blank render —
   verify a *new* render/tech path visually in isolation; a reused, proven path
   where only wiring is new needs only a wiring test). Later slices widen
   coverage; each is independently testable and committable, with **blocking
   edges declared** between slices that genuinely depend on each other.
   **When the acceptance bar is subjective** (art, UX, feel), slice 1 is an
   **owner-gated concept sample** — one from-scratch instance the human approves
   *before* any propagation slice (a v1 that passed every technical gate has
   been rejected whole on taste, wasting the propagation).
4. **The plan gate — re-verify against `HEAD`** (a spec ages well; the literal
   code it cites ages fast): re-read every load-bearing signature / path /
   count against the worktree's `HEAD` before sizing. A claim **inherited from a
   scout, sub-agent, or queued item** is exactly what this gate re-verifies,
   never trusts. **Ground as the plan's literal Task 0** — a read-only
   sweep of every queued item's symbols/files against the done trail and
   live code, not a mental "does this still look right" pass. Dispatch a
   sub-agent when the host can; otherwise run the same sweep inline.
   Two claim-specific verdicts: an **"is X still used"** claim
   needs narrow-then-compile — grep produces the candidate list, the
   compiler/dead-code analysis issues the verdict (a complete grep has
   confidently named test-only callers as live); and a **prior-art check** —
   search capability-wide for an existing implementation before sizing new
   work. `scripts/ground-check.sh` `<root> <spec>` lists the rooted path /
   `file:line` references that no longer resolve (facts, not a verdict: you
   still re-read the signatures — **a reference that *resolves* can still point
   at the wrong code**; the script proves the path exists, never that the line
   supports the prose). **Re-measure before you size** — run the real tool
   against `HEAD`; a snapshot count is a guess. Name the host's load-bearing
   gotchas (workshop: `core/GOTCHAS.md`) in the plan's Global Constraints.
5. **Writing discipline** — exact file paths; complete code in every slice (no
   "add error handling", no "similar to slice N"); **a verification step per
   slice** (command + expected result); DRY, YAGNI, red-first. Two shape rules:
   a **new shared public type pins its derives/traits** alongside its fields
   (parallel implementers otherwise each invent a bridge around the missing
   ones); and an **exploratory/spike slice** is a legitimate distinct shape —
   when the slice's point is to *discover* an algorithm, write it as a v0
   implementation + an **objective probe as the acceptance test** + a bounded
   measure-and-iterate loop with a stated convergence target and an
   escalate/fallback branch, instead of pretending the answer is known and
   faking complete code.
6. **Self-review** — spec→plan coverage (every requirement maps to a slice —
   list gaps), placeholder scan, type/name consistency. Add a slice for any
   uncovered requirement.
7. **Land it** per SKILL.md *Shared discipline*. Resolve `plans.md` via the
   project-templates rule, then mint `records.sh new plans --template <resolved>
   --title "<title> — Implementation Plan"` when the tool exists; else
   file-mode from that same resolved path into the agent-records `plans/` home
   (SKILL.md destination rule), naming the file `YYYY-MM-DD-<slug>.md` (the
   record shape). Either way set `tags: [plan]` and replace the
   body with the plan scaffold filled in from the resolved `plan.md` (bundled
   shape: `templates/plan.md`).

Output: the implementation plan. Tell the human where it is and what you
need (read it, waive review, or change it). Then **stop**. The next verb
is `review` then `build` unless they waive review — that sequence is
yours to offer, not the opening of the reply. The host lane still lands
the result; `build` walks the slices. For a multi-slice plan, running
`review` first is recommended by default — its value is **bimodal, and
both modes pay**: either an independent grounded pass catches must-fix
defects before any code, or it independently corroborates the plan's
own flagged uncertainties, de-risking building every slice in one pass
— and there is no cheap way to know in advance which mode a given plan
will get.
