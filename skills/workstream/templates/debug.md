---
kind: workstream-template
---

# Debug intake brief

## Mission

Reproduce one observed failure, trace it to a root cause, implement the smallest durable correction,
and verify the behavior with the strongest available oracle.

## Unit discipline

- Define one bounded defect or diagnostic improvement per unit.
- Diagnose before patching. Preserve the reproduction, relevant evidence, and causal explanation.
- Prefer a temporal or behavior-level oracle when a static snapshot cannot expose the failure.
- Run the host's relevant gate and any focused end-to-end check before completing the unit.
- Capture a newly discovered but independent defect through the host follow-up lane; do not silently
  enlarge the current unit.

## Project pointers

- Reproduction and diagnostics: `<project: debugging runbook>`
- Source ownership: `<project: repository map>`
- Verification: `<project: test and build policy>`
