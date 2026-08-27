---
schema: foreman/operation@1
title: Prepare a release
use-when: A release candidate needs its pre-publish checks.
shape: procedure
status: draft
areas: [delivery, testing]
tags: [release, fixture]
---

# Prepare a release

## Preconditions

- A release candidate exists.

## Procedure

1. Run the project test gate.
2. Build the release artifact.
3. Confirm its checksum.

## Outputs

- A checked release artifact.

## Verification

- Confirm the test gate passed and the checksum is recorded.

## Recovery

- Preserve the failing evidence and return to the failed check.
