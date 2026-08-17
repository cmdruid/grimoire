---
name: debugger
description: "Root-cause a bug, test failure, build break, or unexpected behavior before proposing any fix -- never patch a symptom. Reproduce it, read the actual error/stack trace in full, trace data flow backward to its origin, form one testable hypothesis, verify it with the smallest possible change, then fix the root cause. If three or more minimal fixes fail to resolve it, stop and question whether the architecture itself is the problem before attempting a fourth patch -- that pattern means a different problem than the one being treated. Use when a test fails, a bug is reported, behavior is unexpected, a build breaks, or a fix is about to be proposed before the cause is actually understood."
---

# debugger -- root-cause before you patch

## Overview

Investigate a reported or observed failure to its **root cause** before writing a fix. An
**instrument**: the procedure is tool-like and the operator owns the judgment — what to
investigate, whether the verdict warrants a fix, when to stop. The discipline runs anywhere;
the probe below adds the playbook and the durable report when a workshop is present.

**Inputs and refusals.** It accepts a **routed report or a live symptom** — a filed bug report is
welcome input when one exists, never a required floor; it **never enumerates the `bugs/` store**
looking for work (a store is not a queue). If the routed report or its linked bug points at an
open `tickets/` record, refuse with that fact — a ticket owns the item until it resolves. Follow
the links; on a workshop host, `records.sh list --type tickets --status open` is the lookup. No
link → continue. A live symptom with no routed report is not this refuse.

## One environment probe (at entry)

Does `<root>/.handbook/README.md` exist and carry the clankshop install stamp (a line matching
`Seeded from clankshop`)? That single fact picks the homes; nothing else is probed.

- **Workshop present** → consult `.handbook/test/workflows/diagnostics.md` when that file exists
  (symptom → first moves; a miss is a playbook gap — the test station tends that playbook). The
  durable report is a `reports` record (*Report Format*). Records root is the declared
  `records-root:`, else `.records/`.
- **Unstamped** → emit `unstamped`, point at the clankshop onramps, and investigate through
  Phase 3 plus the conversational report only. No report mint. Do not enter Phase 4.

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

## Mutation policy

Phases 1–3 do not write the failing test or the fix. Prefer evidence that is already there: the
stack, a reproduction, `git log` / `git diff`, a working analog, one runtime input. If that cannot
answer the current question, one temporary probe (a log line or a one-variable flip) is allowed —
revert it before the report; it is not the fix. Then report the root cause, the evidence, and the
proposed fix, and **stop**. Phase 4 starts only after the human confirms the root cause and that a
fix should land.

## The Four Phases

Complete each phase before moving to the next. Mutation policy above is the edit rule for every
phase.

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
   fault** -- read what enters and leaves each stage from existing logs or output (a build step, a
   service call, a config load). If that evidence is missing, one temporary probe, then revert
   (*Mutation policy*). Read the evidence, then investigate the broken stage in depth.
5. **Trace data flow backward from the failure.** Where does the bad value first appear? What produced
   it? Keep tracing upward until you reach the actual source -- fix there, never at the symptom site.

### Phase 2 -- Pattern analysis

1. **Find a working analog.** Locate similar code in the same project that works correctly. After a
   bounded search with none, record `no analog` and continue to Phase 3.
2. **Diff against it, completely.** Skip if `no analog`. Read the whole reference, not a skim -- a
   partial read of a pattern guarantees a partial (and wrong) application of it.
3. **List every difference**, however small it seems. Skip if `no analog`. Don't discard one as
   "surely irrelevant" without checking.

### Phase 3 -- Hypothesis and minimal test

1. **State one hypothesis explicitly**: "X is the root cause because Y." Vague suspicion isn't a
   hypothesis.
2. **Test it with the smallest possible change** -- preferably one runtime input, one variable, not
   a bundle. A code probe is last resort and is not the fix (*Mutation policy*).
3. **Confirmed → report and stop** (*Report Format*). Human confirms → Phase 4. **Refuted → a new
   hypothesis**, not another fix stacked on top of this one.
4. **Genuinely don't know?** Say so. Don't paper over the gap with a plausible-sounding guess.

### Phase 4 -- Fix the root cause

Entered only after the human confirmed the root cause and that a fix should land. Unstamped: do
not enter. Human declined: stop — the report is the output.

1. **Write a failing test first** -- the smallest reproduction, automated if the project has a test
   framework, a one-off script if it doesn't. This must exist before the fix, not after.
2. **Make the one fix** the hypothesis identified. No bundled refactoring, no "while I'm here"
   improvements -- a second change in the same commit makes a failed fix unfalsifiable.
3. **Verify**: the new test passes, nothing else broke, the original symptom is actually gone (not
   just quieter).
4. **Land** the failing test and the one fix.
5. **If the fix doesn't resolve it, count.** Fewer than three attempts → back to Phase 1 with what was
   just learned. **Three or more failed fixes → stop.** That pattern -- each attempt revealing a new
   problem somewhere else, or needing progressively larger changes to hold together -- means the
   architecture is the actual problem, not a fix waiting to be found. Surface that to the human rather
   than attempting a fourth patch; it is a design conversation, not another debugging cycle.

## Report Format

State plainly: the reproduction, the root cause (not the symptom), the evidence that confirms it,
and the proposed fix (not yet applied). Stop for confirm. After Phase 4, add how it was verified.
If Phase 4 hit the three-fix threshold, say so explicitly and name the architectural question
instead of a fix.

**Workshop present:** the durable record is a reports record. Mint it with
`<records-root>/scripts/records.sh new reports --title "<investigation title>"` — the tool owns
naming and front-matter (`.records/reports/YYYY-MM-DD-<slug>.md`, doctype/status/created stamped,
collisions suffixed automatically; never hand-stamp) — then fill the body from this skill's
`templates/investigation.md` (the body scaffold: reproduction, root cause, evidence,
fix + verification, then a keyed `#### <key> — <title>` heading per actionable finding a
downstream debrief/curate pass reads; keys match `[a-z0-9-]+`, unique within the report). Close
it `consumed` (`records.sh done`) when its substance lands somewhere durable, and link it from a
tracker line only when one exists. Commit it trunk-side, scoped, alongside the linked entry's
completion where one applies.

## Done when

- **Ticket-owned refuse:** stopped with the open-ticket fact.
- **Unstamped:** conversational report of reproduction, root cause, evidence, and proposed fix.
  No mint. No Phase 4.
- **Human declined the fix:** the report stands; no Phase 4.
- **Workshop, fix landed:** failing test + one fix + verified + landed; reports record filled;
  closed `consumed` when its substance has a durable home; linked from a tracker line only when
  one exists.
- **Three-fix stop:** stopped; architectural question named; no fourth patch.

## Boundaries

- **An instrument, not a role.** The four-phase procedure is the tool; the operator (whoever the
  bug lane dispatched — often driven by a human or a routing walk) owns the judgment around it.
  It stewards no chapter and keeps no seat.
- **Not a scheduled code-quality or doc-ergonomics pass.** Symptom-triggered investigation of one
  reported problem, not a broad scoring sweep across a codebase or a doc spine.
- **No private home.** Nothing is scaffolded or stored between sessions -- each investigation is
  independent. The durable outputs are the conversational report, the workshop report file (above)
  when one was minted, and any tracker captures the installation's record schema names; a
  verification-depth or flake *judgment* question belongs to the verification role, not here.
