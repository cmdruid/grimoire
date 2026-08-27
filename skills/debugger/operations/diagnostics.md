---
schema: foreman/operation@1
title: Debugger diagnostics
use-when: A host needs a repeatable procedure for collecting evidence before forming a debugging hypothesis.
shape: procedure
status: active
areas: [development, testing]
tags: [debugging, diagnostics, root-cause]
verified-against: sha256:a3af089492eed0b76bd4b0ef6ba5a5c6bb67baebc10f0e8140cac928fb85be6b
---

# Debugger diagnostics

## Preconditions

- A specific bug, failed test, broken build, or unexpected behavior is observable.

## Procedure

1. Reproduce the behavior and capture the complete error or unexpected output.
2. Record evidence at each component boundary before deciding which component is at fault.
3. Trace the first incorrect value backward to its source.
4. State one falsifiable root-cause hypothesis and run the smallest test that can refute it.
5. Report the reproduction, evidence, confirmed cause, and proposed fix; do not apply the fix without
   approval.

## Outputs

- A confirmed root cause or a sharply bounded unknown with the evidence gathered.
- One proposed fix only after the evidence supports it.

## Verification

- Confirm the report identifies the reproduction, boundary evidence, hypothesis test, and root cause.

## Recovery

- If the hypothesis fails, keep the evidence, choose the next upstream boundary, and form one new
  falsifiable hypothesis.

## Verification evidence

- Bundled procedure reviewed against Debugger's investigation contract on 2026-08-26.
