---
title: Debugger diagnostics
use-when: A host needs a repeatable procedure for collecting evidence before forming a debugging hypothesis.
---

# Debugger diagnostics

1. Reproduce the reported behavior and capture the complete error or unexpected output.
2. Record evidence at each component boundary before deciding which component is at fault.
3. Trace the first incorrect value backward to its source.
4. State one falsifiable root-cause hypothesis and run the smallest test that can refute it.
5. Report the reproduction, evidence, confirmed cause, and proposed fix; do not apply the fix without
   approval.
