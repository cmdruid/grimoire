# Performance -- audit rule
> Do hot paths avoid asymptotic or structural waste?

Part of the <project> code audit rubric (see `../GUIDE.md`). Issue theme: `PERF`.

## Why it matters

This dimension guards against *structural* waste: an allocation or an O(n^2) scan
that is architecturally locked in and cannot be fixed by tuning a constant.
Micro-optimizations (shaving nanoseconds off a math call) are not audit findings --
they belong in a dedicated profiling or benchmarking workflow.

Structural waste takes two forms:
1. **Per-iteration allocations in hot loops** -- a data structure allocated and
   immediately discarded inside the main loop or a frequently-called system inflates
   memory pressure even when each allocation is small.
2. **Asymptotic waste** -- an O(n^2) or O(n^3) scan over a dataset that grows with
   user input (world size, item count, frame count) is a latent performance cliff
   that will eventually be hit as the application scales.

For real measurement, use the project's benchmark harness. Greps surface
*candidates* only -- never file a PERF finding without a measurement.

## Scoring anchors (1-5)

- 5 -- No avoidable per-iteration allocations in hot-loop systems. Core processing
  is O(n) in the relevant input size. The benchmark harness shows stable baselines
  across passes.
- 4 -- One small per-iteration allocation exists (e.g., a collection in a hot
  system) but is bounded and cheap; no asymptotic structural waste. Bench baseline
  is stable.
- 3 -- One clear structural issue: a data structure allocated inside a hot system
  that could be pre-allocated as a reusable resource; or a large-data clone inside
  a frequently-called task on every invocation. No O(n^2) scan.
- 2 -- Multiple per-iteration allocations in hot systems; or a full data clone on
  every major operation. The benchmark shows measurable regression from a prior pass.
- 1 -- Structural O(n^2) over the primary data collection in the hottest path; or
  every iteration re-clones all loaded data. The application stutters at moderate
  scale.

## Decision logic

1. Run the hot-path allocation grep (see Anti-patterns). Focus on files in the
   core processing modules and functions registered in the main application loop.
2. For each allocation hit, identify whether it is:
   - Inside a function only called at startup or on a one-time event -> **skip**.
   - Inside the main application loop (or a function called from one) ->
     **candidate**.
   - Inside an async or background task (runs per-work-item, not per-frame) ->
     **candidate only if the allocation is proportional to the collection count,
     not a fixed per-invocation cost**.
3. For each clone / copy inside a hot-path module, identify the type being copied.
   A reference-counted pointer clone (pointer copy) is free; a full data-structure
   clone is structural waste.
4. Look for nested loops over the primary data collection. A loop-inside-a-loop
   that both iterate over the same large collection is an O(n^2) candidate.
5. Never file a PERF finding without measuring. Run the benchmark harness and
   compare to the recorded baseline. See the project's performance documentation
   for the measurement procedure.
6. Score against the anchors; use the lower anchor when two fit.
7. Refute against Known false-positives before filing.

## Anti-patterns (greppable smells)

```<shell>
<language: find per-iteration allocation candidates (new collection / new map) in hot-path modules.>
<language: find clone/copy calls in the hot-path module -- triage: is it a pointer copy or a data copy?>
<language: find the main-loop / update-system registrations -- check which functions in this list do per-iteration allocation.>
<language: find nested loops over the primary data collection (O(n^2) candidate).>
<language: find collect/to-array calls inside hot-path functions (allocation via iterator).>
```

## Calibrated examples

_(Empty until the audit blueprint's Select-exemplars step pins real units.)_

## Known false-positives

- **Reference-counted pointer clones.** Cloning a shared/reference-counted handle
  is an atomic pointer increment, not a data copy. Many clone calls in a hot-path
  module may be on reference-counted wrappers dispatched to async tasks. Check the
  type before flagging.
- **Allocations in one-time initialization.** A collection allocation in a
  one-time constructor or initializer is not a per-iteration allocation.
  Check whether the call site is inside the main application loop.
- **Background-task allocations that are unavoidable.** An async background task
  that allocates its output buffer once per work item is expected and correct: it
  is bounded to one output per item. Do not flag it.
- **Processing-function buffer allocations.** Allocating output buffers at the
  start of a per-work-item processing function is expected. The benchmark harness
  is the correct tool to track whether these grow unexpectedly.
- **String allocation in error paths.** String allocation in an error handler is
  not a hot-path concern.

## How to quantify

<language: count collection allocations in hot-path modules; count clone/copy calls in
the hottest module (proxy for data-copy vs pointer-copy ratio); record benchmark baseline
(run the bench harness; do not guess the number). Report as:
`hot-path allocs: N; hot-path clones: C; bench baseline: see logs/`.
A PERF finding must cite a bench number or a profiler trace -- never file on grep output alone.>

## Exemplars

_(Pin during the audit blueprint's Select-exemplars step. The host's filled
exemplars live in its deployed GUIDE.md's pinned-exemplars section.)_
