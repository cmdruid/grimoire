---
doctype: reports
status: archived
schema: debugger/investigation@1
tags: [foreman, skilldata]
---

# Foreman and skilldata implementation review fixes

## Reproduction

- A proven active operation was rendered as a normal goal, given a matching provisional-root marker,
  and accepted by `goal-compile.sh check` as `provisional=true`.
- A provisional goal targeting `goals/2000-01-01-...` was published with an executable adjacent
  records provider; publication returned `mode=exact-file` and bypassed the provider.
- A global-only fixture containing a bare project path beneath an unknown `cache` kind passed
  Skill-builder lint with `fails=0`.
- The global-skilldata gate skipped complete Skill-builder doctrine and verb files, while its new
  branch tests lacked per-guard mutation proofs.

## Root cause

- Goal validation classified a marker solely from current operation status, without using the goal
  record's draft-versus-published lifecycle to distinguish first publication from later promotion.
- Publication treated an exact path that differed from the provider's current date as permission to
  fall back to raw file mode instead of a preflight refusal.
- Project-path lint used a package-wide global-only exemption instead of classifying each literal by
  scope, and its self-hosting exceptions were whole-file exclusions.

## Evidence

Each scenario reproduced against the implementation before mutation. Failing tests were then added
for a planted marker, records-provider date rollover, a global-only project-kind escape, and concrete
global owners in Skill-builder teaching files. The tests failed on the original branches and passed
after the boundary classifiers changed.

## Fix + verification

- Draft marked goals now require a draft unverified root; only an already-published marked goal may
  accept its digest-stably promoted active root.
- Both start preflight and compiler publication refuse an executable provider whose current path
  differs from the accepted destination.
- Project lint masks only explicitly home-qualified global literals. A narrow declared-global store
  protocol remains recognized without exempting other project paths.
- Skill-builder teaching files are scanned normally; placeholder owners remain naturally inert.
  Every new project/global lint branch now has a counted mutation proof and byte-identical restore.

Verification: Foreman, Skill-builder, repository integration, Checkpoint, and Workstream suites are
green. Skill-builder lint reports `fails=0 warns=3`; records validation, Bash syntax, ShellCheck at
the applicable existing severity floor, and `git diff --check` pass.

## Findings

#### lifecycle-aware-marker-custody — Bind provisional admission to record lifecycle

When metadata excluded from an instruction digest may legitimately change after publication,
validation must distinguish the pre-publication artifact from the immutable published record before
admitting the later state.

#### provider-path-preflight — Reject provider path mismatch before the first write

An exact accepted destination does not authorize bypassing an available publisher. When a provider
cannot mint that destination, refuse during the complete write-set preflight.

#### per-literal-scope-classification — Do not infer path scope from package classification

A package-level global declaration cannot classify every owner-local-looking literal. Determine
project versus global scope from each construction, with only narrow protocol exceptions backed by
the declared global contract.

#### content-bounded-self-hosting — Let placeholders avoid exceptions naturally

Toolmaker doctrine can use syntactically distinct placeholder owners. This keeps teaching examples
inert while allowing ordinary lint to catch concrete owners in the same files.
