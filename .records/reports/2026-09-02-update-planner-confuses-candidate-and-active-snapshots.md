---
doctype: reports
status: archived
schema: debugger/investigation@1
tags: []
---

# Update planner confuses candidate and active snapshots

## Reproduction

After the CLI mutation fixture uses a canonical temporary root,
`RUSTC_WRAPPER= cargo test -p skill-grimoire --test cli_mutations
install_update_frozen_and_uninstall_share_the_transaction_path -- --nocapture` installs the initial
pack successfully, fetches a new candidate, then returns exit 3 from `update --yes`.

## Root cause

`load_world` constructs `WorldState.snapshots` from candidate-preferred `source_states`. The planner
uses `world.snapshots` both as its default resolution input and as the active lock-owned snapshot
view. Once a newer candidate exists, it therefore mistakes the candidate target for the incumbent
link target. The actual old links are reported as drift, no repoint action is produced, the new
source never enters `activating_sources`, and its absent immutable snapshot becomes a blocker.

## Evidence

The printed core plan contains a `source_advance` lock replacement but also `link-drift` for both
links and `snapshot-store-absent` for the candidate. Its link preconditions show the links still
point at the old store key. Tracing backward shows `incumbent_target` reads `world.snapshots`, while
`load_world` filled that map from the new candidate. Synthetic planner tests did not expose the
problem because `WorldState::with_candidate` does not replace their `snapshots` map.

## Fix + verification

Production `load_world` now constructs `snapshots` as the active snapshot view: locked snapshots
first, with candidates only for declarations not represented in the lock. Planner store/trust
selection likewise prefers an explicitly selected candidate, then the locked state, then an
unlocked source observation. The existing red CLI scenario now performs the candidate update,
materializes the new snapshot, and repoints both links. Slice 4's exact core/app tests and the
workspace check also passed.

## Findings

#### active-candidate-separation — Keep active and candidate snapshot views distinct

Production observation must not project a newer candidate into the map used for active
lock-ownership checks or ordinary reconciliation. Candidate selection belongs only to initial
unlocked-source resolution and explicit update requests.
