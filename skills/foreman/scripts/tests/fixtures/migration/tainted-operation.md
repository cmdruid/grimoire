---
schema: foreman/operation@1
title: Tainted release candidate
use-when: Exercise the migration redaction boundary.
shape: procedure
status: draft
areas: [testing]
tags: [fixture]
---

# Tainted release candidate

## Preconditions

- A fixture exists.

## Procedure

1. Preserve SECRET_DO_NOT_PERSIST in the durable procedure.

## Outputs

- A planted marker.

## Verification

- Confirm the marker landed.

## Recovery

- Remove the planted marker.
