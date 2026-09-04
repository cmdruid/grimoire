---
doctype: reports
status: published
schema: auditor/audit@1
tags: [audit]
---

# Audit: Grimoire source-code proportionality

Grimoire is moderately affected by complexity contagion, but the cost is concentrated rather than
systemic. The managed-vendor work preserves real security and recovery guarantees. Four narrower
changes can remove disproportionate ceremony and repeated work without weakening those guarantees.

This report adapts the repository-root [`RUBRIC.md`](../../RUBRIC.md) to project source code. It is
not a standard Auditor pass: Grimoire intentionally has no deployed Auditor rubric, so this report
uses no aggregate score and does not claim per-dimension calibration. The audited implementation is
the change from `263b28c` through `361f8e2`.

## Default path

An ordinary linked reconciliation still follows the existing CLI → world → plan → apply path and
does not plan managed-vendor mutation. Project world loading does, however, observe a vendor path
for every locked skill ([`world.rs`](../../crates/grimoire-core/src/world.rs#L140)). That probe is a
bounded cost to watch, not an evidenced defect by itself.

## Keep

- Preserve exact vendor receipts and offline restoration. These establish the product's committed,
  reproducible projection rather than optional ceremony.
- Preserve descriptor-held, no-follow vendor mutation. The component-by-component directory
  handling in [`apply.rs`](../../crates/grimoire-core/src/apply.rs#L2197) protects the custody
  boundary against path replacement.
- Preserve journaled rollback and roll-forward behavior. The crash matrix exercises every vendor
  publication prefix and verifies restoration of the complete prior state
  ([`vendor_lifecycle.rs`](../../crates/grimoire-core/tests/vendor_lifecycle.rs#L273)).

## Remove or demote

- **Harmful — remove duplicate vendor-trust approval.** `source trust ALIAS --vendor` is already an
  explicit authorization, but `GrantVendor` is also classified as destructive
  ([`plan.rs`](../../crates/grimoire-core/src/plan.rs#L210)). The shared apply boundary then demands
  another prompt ([`command.rs`](../../crates/grimoire/src/command.rs#L656)), while the grammar
  rejects `--yes` for this command ([`cli_grammar.rs`](../../crates/grimoire/tests/cli_grammar.rs#L62)).
  The end-to-end test confirms the prompt ([`vendor_offline.rs`](../../crates/grimoire/tests/vendor_offline.rs#L147)).
- **Needs work — isolate vendor projection planning.** `plan()` now spans 912 lines, from line 359
  through line 1270, compared with 656 lines at `263b28c`. Extract the vendor-specific projection
  calculation behind a typed result so the general planner retains orchestration rather than all
  projection mechanics.
- **Needs work — eliminate the verifier's third tree walk.** Strict skill verification first calls
  the canonical scanner and then starts another entry pass
  ([`scan.rs`](../../crates/grimoire-pack/src/inventory/scan.rs#L260)). The boundary test records
  three complete 100,001-entry traversals ([`bounded_skill_tree.rs`](../../crates/grimoire-pack/src/inventory/tests/bounded_skill_tree.rs#L49)).
  Fold strict mode and `.git` checks into an existing collected-entry pass while keeping the same
  bounded, no-follow behavior.
- **Needs work — demote the pinned self-host proof.** The root dogfood test starts a full repository
  clone and install/check/uninstall scenario ([`root_dogfood.rs`](../../crates/grimoire/tests/root_dogfood.rs#L34))
  and took 217.86 seconds on a warm build. Keep it as an explicit deep or release proof; use the
  focused behavioral and recovery suites on the default path.

## Scope risks

- The audited change spans 84 files with 6,464 insertions and 387 deletions. That breadth is partly
  warranted by carrying five projection states through model, planner, application, reporting, CLI,
  TUI, and tests, but future projection changes can easily reopen every layer.
- Vendor safety rules can leak into linked-only work if shared orchestration treats the highest-risk
  projection as the default. Keep vendor-specific checks behind the projection boundary.
- The custody and recovery code recently caught real symlink, traversal, and transaction defects.
  Simplification that removes those invariants would be false economy.

## Smallest remediation

1. In `crates/grimoire-core/src/plan.rs`, stop treating `TrustChange::GrantVendor` as destructive;
   retain trust-byte, lock, and transaction revalidation.
2. Extract only vendor projection planning from `plan()` into a focused helper with a typed result.
3. Rework `scan_skill_tree()` so strict validation reuses already collected entries instead of
   initiating a third traversal.
4. Move `root_dogfood` out of the default gate and into an explicit deep or release gate.

Do not broaden this remediation into a transaction rewrite, a new abstraction layer, or adjacent
cleanup.

## Regression scenarios

- **Bounded task:** Reconcile an already-trusted linked skill in project scope. It must avoid vendor
  traversal beyond the existing bounded state probe, require no extra approval, and run only
  focused checks.
- **High-risk task:** Replace a managed vendor projection across every crash point. It must preserve
  exact before/after receipts, reject foreign replacement, and recover through descriptor-held,
  journaled operations.

## Verification evidence

- `cargo test -p skill-grimoire --test mixed_projection --test vendor_offline --test vendor_plan_render`
  passed in 2.20 seconds.
- `cargo test -p grimoire-core --test vendor_tracer --test vendor_apply --test vendor_lifecycle`
  passed in 12.17 seconds, including compilation.
- `root_dogfood` passed, but the Rust harness took 217.86 seconds.

The findings remain in this report until the project chooses whether to promote them into its
remediation workflow.
