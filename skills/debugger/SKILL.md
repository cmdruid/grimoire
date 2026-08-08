---
name: debugger
description: "Root-cause a bug, test failure, build break, or unexpected behavior before proposing any fix -- never patch a symptom. Reproduce it, read the actual error/stack trace in full, trace data flow backward to its origin, form one testable hypothesis, verify it with the smallest possible change, then fix the root cause. If three or more minimal fixes fail to resolve it, stop and question whether the architecture itself is the problem before attempting a fourth patch -- that pattern means a different problem than the one being treated. Use when a test fails, a bug is reported, behavior is unexpected, a build breaks, or a fix is about to be proposed before the cause is actually understood."
---

# debugger -- root-cause before you patch

## Overview

Investigate a reported or observed failure to its **root cause** before touching any code. Read-only
by default; propose the smallest fix that tests the hypothesis, and land it only after the human
confirms. An **instrument**: the procedure is tool-like and the operator owns the judgment — what
to investigate, whether the verdict warrants a fix, when to stop. The discipline runs anywhere;
on a framework installation it additionally writes its findings to the report store and follows
the deployed playbook (below).

**Inputs and refusals.** It accepts a **routed report or a live symptom** — a filed bug report is
welcome input when one exists, never a required floor; it **never enumerates the `bugs/` store**
looking for work (a store is not a queue). A routed report whose linked tracker entry is
**paused** is refused with the pause fact — a ticket owns that item until it resolves. On an
**unstamped root** (no installation block) the fix-landing and report-writing halves are
unavailable: emit `unstamped`, point at the clankshop onramps, and investigate read-only at most.

**The playbook.** Where the installation carries `.handbook/testing/DIAGNOSTICS.md`, consult it
first — symptom → first moves; it frequently short-circuits Phase 1. An investigation that
navigates a symptom the playbook doesn't cover is a playbook gap worth flagging (the verification
steward tends that chapter).

## When to Use

- A test fails, a build breaks, or behavior is wrong or unexpected.
- A fix is about to be proposed before the failure is actually understood.
- **Especially** under time pressure, when "just one quick fix" seems obvious, or after a fix already
  didn't work -- these are exactly the conditions that make guessing tempting and systematic
  investigation pay off most.
- NOT a scheduled code-quality pass and NOT a doc-ergonomics pass -- this is triggered by a specific
  symptom, not a broad scoring sweep.

## The Iron Rule

**No fix without root-cause investigation first.** A fix proposed before Phase 1 is complete is a
guess, not a fix -- even when it happens to work, because you won't know *why* it worked or whether it
also broke something else.

## The Four Phases

Complete each phase before moving to the next. Every phase through Phase 3 is **read-only** -- nothing
gets edited until Phase 4, and Phase 4's fix lands only after the human confirms (the same
investigate-then-confirm shape every steward in this library uses: read, report, human decides).

### Phase 1 -- Root-cause investigation

1. **Read the error completely.** The full stack trace, every warning, exact line numbers and file
   paths -- not just the last line. It frequently names the actual cause.
2. **Reproduce it reliably.** If it won't reproduce on demand, gather more evidence before doing
   anything else -- don't guess ahead of a reproduction.
3. **Re-verify against `HEAD`, don't trust an inherited claim.** Check what actually changed recently
   (`git log` / `git diff` against the suspect path, read fresh -- never assumed, never taken from a
   bug report or a scout's summary at face value). A claim inherited from a filed report or another
   agent's finding is exactly what this step re-verifies; a plausible inherited claim can point at a
   bug that doesn't exist, and refuting it here is far cheaper than fixing it.
4. **In a multi-component system, gather evidence at each boundary before guessing which one is at
   fault** -- log or print what enters and leaves each stage (a build step, a service call, a config
   load) once, then read the evidence to see where it actually breaks, before investigating that one
   stage in depth.
5. **Trace data flow backward from the failure.** Where does the bad value first appear? What produced
   it? Keep tracing upward until you reach the actual source -- fix there, never at the symptom site.

### Phase 2 -- Pattern analysis

1. **Find a working analog.** Locate similar code in the same project that works correctly.
2. **Diff against it, completely.** Read the whole reference, not a skim -- a partial read of a
   pattern guarantees a partial (and wrong) application of it.
3. **List every difference**, however small it seems. Don't discard one as "surely irrelevant" without
   checking.

### Phase 3 -- Hypothesis and minimal test

1. **State one hypothesis explicitly**: "X is the root cause because Y." Vague suspicion isn't a
   hypothesis.
2. **Test it with the smallest possible change** -- one variable, not a bundle of adjustments.
3. **Confirmed → Phase 4. Refuted → a new hypothesis**, not another fix stacked on top of this one.
4. **Genuinely don't know?** Say so. Don't paper over the gap with a plausible-sounding guess.

### Phase 4 -- Fix the root cause

1. **Write a failing test first** -- the smallest reproduction, automated if the project has a test
   framework, a one-off script if it doesn't. This must exist before the fix, not after.
2. **Make the one fix** the hypothesis identified. No bundled refactoring, no "while I'm here"
   improvements -- a second change in the same commit makes a failed fix unfalsifiable.
3. **Verify**: the new test passes, nothing else broke, the original symptom is actually gone (not
   just quieter).
4. **Confirm with the human before landing.** State the root cause, the fix, and the verification --
   the same report-then-confirm gate every read-only-by-default skill in this library uses before it
   mutates anything.
5. **If the fix doesn't resolve it, count.** Fewer than three attempts → back to Phase 1 with what was
   just learned. **Three or more failed fixes → stop.** That pattern -- each attempt revealing a new
   problem somewhere else, or needing progressively larger changes to hold together -- means the
   architecture is the actual problem, not a fix waiting to be found. Surface that to the human rather
   than attempting a fourth patch; it is a design conversation, not another debugging cycle.

## Report Format

State plainly: the reproduction, the root cause (not the symptom), the evidence that confirms it (not
just the fix that happened to work), the fix, and how it was verified. If Phase 4 hit the three-fix
threshold, say so explicitly and name the architectural question instead of a fix.

**On a framework installation, the durable record is a report file:**
`.records/reports/investigation-<YYYY-MM-DD>-<slug>.md` from this skill's
`templates/investigation.md` — frontmatter floor (`type: investigation`, `id` = the filename stem
verbatim, `date`, `source`, optional `processed:`), the report body above, and a keyed
`#### <key> — <title>` heading per actionable finding (the lessons slice the improvement loop
drains; keys match `[a-z0-9-]+`, unique within the report). If the target filename already exists,
suffix the slug deterministically (`-2`, `-3`, …) **before first publication**; never rename
after. Commit it trunk-side, scoped, alongside the linked entry's completion where one applies.

## Boundaries

- **An instrument, not a role.** The four-phase procedure is the tool; the operator (whoever the
  bug lane dispatched — often driven by a human or a routing walk) owns the judgment around it.
  It stewards no chapter and keeps no seat.
- **Not a scheduled code-quality or doc-ergonomics pass.** Symptom-triggered investigation of one
  reported problem, not a broad scoring sweep across a codebase or a doc spine.
- **No private home.** Nothing is scaffolded or stored between sessions -- each investigation is
  independent. The durable outputs are the report file (above) and any tracker captures the
  installation's record schema names; a verification-depth or flake *judgment* question belongs
  to the verification role, not here.
