# The `debugger` skill

**Status:** Implemented (2026-07-23). Item 2 of the `feature-debugger-refinements` workstream
(brief-sourced, no pre-existing roadmap). Fills a real gap: no grimoire skill owns "a bug just
happened, what now" — `auditor` is static code-quality scoring, `chiropractor` is doc-spine
ergonomics, neither investigates a reported failure.

## Why this is a skill, and why now

Two concrete confirmations that this gap is real, not invented:

1. **`foreman`'s bug lane dead-ends at capture.** `/foreman route`'s bug classification dispatches to
   `/backlog bug` — "diagnose + file a report under the host's bug store." Filing is the *end* of
   that lane today; nothing in the constellation drives the actual root-cause-and-fix work.
2. **`workstream`'s bundled `debug.md` template already points at a discipline that doesn't exist.**
   Its "Starting a debug session" step 1 says *"Diagnose before patching. Reach for a structured
   debugging discipline before proposing a fix"* — generic phrasing, deliberately not naming a
   specific skill (a workstream template must not develop a hard dependency on an unwritten one). It
   now has something concrete to satisfy.

The content is grounded in the `superpowers` plugin's `systematic-debugging` skill (already read this
session): a 4-phase root-cause process and the "3+ failed fixes means the architecture is the
problem, not the bug" heuristic. Both are sound and portable; neither is rewritten here verbatim —
`debugger` restates them in grimoire's own voice (facts-not-verdicts, read-only investigate before any
mutation, human confirms before a fix lands) rather than superpowers' directive "Iron Law" style.

## Disposition (scored against the same three axes as every other skill)

| axis | disposition |
|---|---|
| **Self-init / home** | **None — in-place steward**, same tier and reasoning as `chiropractor`: it investigates and fixes the host project's *own* code in place; there is no private store to scaffold. Confirmed with the human (not durable-home). |
| **Typed edges** | `consumes: tracker-entry` — a filed bug (`/backlog bug`'s output) is legitimate input to investigate. `produces: gate-green-code`, `handoff: gate-green-code` — a debugged, tested fix is the same class of artifact `feature build` produces (the vocabulary already supports multiple producers of one coarse type, same as `design`); `workstream` can land either. |
| **Front-door registration** | **Optional, not implemented** — same call as `chiropractor` (no durable home, no captured items to surface). |

## Placement: inside `clankshop`

Confirmed with the human: `debugger` is an **operational** skill, like `auditor` — every project this
pack deploys onto needs a debugging discipline, unlike `skill-builder`'s meta/toolmaker concern. It
joins the pack's `skills:` manifest (now 11 members) and the composition diagram, in a new
**diagnosis** layer alongside the existing four (it isn't quite `auditor`/`chiropractor`'s
scheduled-audit shape, and it isn't a workflow/engine/delegation/session skill either).

**Not part of "Which audit?"** — that section is specifically about scheduled/broad scoring passes
(code quality, doc ergonomics, dev-system health, skill-library boundaries). `debugger` is
symptom-triggered investigate-and-fix work on a *specific* reported problem, a different shape
entirely; forcing it into that table would blur a real distinction.

## The seams

- **`backlog` → `debugger`** (new dep, mechanically derivable): a filed bug (`tracker-entry`) is
  `debugger`'s input. `/foreman route`'s bug lane updated: file first (`/backlog bug` — the repro
  survives even if nobody drives it yet), then `/debugger` drives the investigation from the filed
  report, or directly from a live symptom if nothing's been filed yet (filing isn't a hard
  prerequisite — `consumes: tracker-entry` is optional input, not a floor).
- **`debugger` → `workstream`** (new dep + a second producer of an existing seam type): a gate-green
  fix lands the same way a gate-green feature does — standalone, or via a stream (including a
  `debug`-template workstream instance, whose "reach for a structured debugging discipline" line now
  has something concrete to point at, generically, at the point of use — not hardcoded into the
  template itself, keeping `workstream` dependency-free of `debugger`'s existence).

## The discipline (adapted from `systematic-debugging`, restated in grimoire's voice)

Four phases, same shape as the source material, with two grimoire-specific changes: every phase is
**read-only until the fix step** (matching every other steward/auditor's "investigate and report,
human confirms before mutating" pattern — `chiropractor`'s `scan → diagnose → adjust`, `architect
reconcile`'s "recommends, never applies"), and evidence-gathering is framed as *"re-verify against
`HEAD`, don't trust an inherited claim"* — the same phrase `feature plan`'s gate already uses, so the
discipline feels native to the library rather than pasted in.

1. **Root-cause investigation** — reproduce it, read the actual error/stack trace in full, check what
   changed recently (`git log`/`git diff`, never assumed), trace data flow backward from the failure
   to its origin. A claim inherited from a bug report or a scout is exactly what gets re-verified here,
   never trusted outright.
2. **Pattern analysis** — find a working analog in the same codebase, diff it against the broken path,
   list every difference (however small).
3. **Hypothesis and minimal test** — one clearly-stated hypothesis, the smallest change that tests it,
   one variable at a time. Didn't work → new hypothesis, not a bigger fix.
4. **Fix the root cause** — a failing test first, then the single fix, then verify. **Three failed
   fixes → stop and question the architecture** (a fix requiring "massive refactoring," each attempt
   surfacing a new symptom elsewhere, is a different problem than the one being patched) — surface
   that to the human rather than attempting a fourth patch.

## Gate

New skill dir + `clankshop.md`/`README.md`/`foreman route.md` wiring — build-relevant (a new `SKILL.md`
is not markdown-only in the doc-linter's narrow sense once it carries an `## Edges` block the lint
parses), full `skills-lint.sh` pass required. Routing-probed against `auditor`, `chiropractor`, and
`skill-builder` (its closest neighbors by any "investigate/fix/audit" reading) before landing.
