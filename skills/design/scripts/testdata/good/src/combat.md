---
distilled_through_adr: 0003
distilled_through_commit: abc123
distilled_through_date: 2026-07-13
---
# Combat — Standing Spec
## Contract (BINDING)
- Purpose: deterministic damage.
- Acceptance: scenario combat_smoke.ron passes; damage is byte-identical across two seeded runs.
## Reference Architecture (DISPOSABLE)
- see src/lib.rs:1
