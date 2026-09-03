---
doctype: reports
status: archived
schema: debugger/investigation@1
tags: [backlog, anchor, recovery]
---

# Backlog selection and anchor review findings

## Reproduction

In copied throwaway packages, install a managed Backlog route, remove
`templates/agents-route.md`, and run `trackers-anchor.sh preview --remove`. The helper exits 2
with `package resources unavailable`.

Separately, interrupt selected setup after publishing `.setup-selection`, add
`.trackers/foreign.txt`, and rerun setup. Status reports `resumable-prefix`; setup succeeds,
removes the intent, and retains the unexplained file.

Review the anchor fixture matrix for removal beside missing, stale, and malformed tracker layers
and for deletion of `AGENTS.md` after preflight. Only stale history and concurrent content edits
are currently exercised.

## Root cause

`trackers-anchor.sh` validates and renders install-only package resources unconditionally before
branching on removal. `tracker-layer-status.sh` inventories selected TSVs and reserved selection
temporaries but not all entries in the transient layer. The anchor test rewrite also removed the
prior concurrent-deletion fixture and collapsed the required unhealthy-layer matrix to one stale
ledger case.

## Evidence

The isolated removal probe failed only after moving `agents-route.md` aside. The selected-prefix
probe classified a valid intent plus `foreign.txt` as resumable and completed with the foreign
file intact. Direct inspection shows unconditional resource checks at the anchor helper's package
preflight and no general entry inventory in the tracker classifier. The approved plan explicitly
requires removal-only front-door custody, extra-file ambiguity, missing/stale/malformed removal
fixtures, and concurrent-deletion coverage.

## Fix + verification

Added regression fixtures for removal with a missing layer, malformed history, missing install-only
route template, and concurrent `AGENTS.md` deletion. Added selected-intent and legacy-prefix fixtures
with an unexplained file and proved both preserve the evidence while refusing recovery.

Moved route-template, legacy-template, tracker-runtime, README-status, and package-stamp validation
behind the install/refresh path so removal depends only on Git/root/front-door custody and owned-block
parsing. Extended transient-layer classification with an exact root/table inventory; unexplained
entries now make a valid-selection or history-absent prefix ambiguous without affecting initialized
custom layers.

Before the fixes, `anchor-test.sh` reported 87 passes and one failure for damaged-package removal;
`setup-resume-test.sh` reported 510 passes and five failures for the two unexplained-entry cases and
their preservation checks. After the fixes they reported 88/0 and 515/0 respectively. The complete
Backlog package suite, all three repository Backlog contracts, configure-clankshop, the skill-builder
suite, shellcheck, and `git diff --check` passed. Skill lint reported `fails=0` and only the same three
documented Foreman warnings.

## Findings

#### removal-resource-coupling — Removal depends on install-only package resources

Keep removal usable when tracker state or non-removal package resources are damaged.

#### transient-extra-files — Selection recovery ignores unexplained entries

Treat any entry outside the exact transient setup population as ambiguous without deleting it.

#### anchor-matrix-gaps — Required removal and deletion fixtures are absent

Restore concurrent-deletion coverage and exercise removal beside missing, stale, and malformed
tracker layers.
