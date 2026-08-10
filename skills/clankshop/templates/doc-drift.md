---
type: doc-drift
id: doc-drift-<YYYY-MM-DD>-<slug>   # = the filename stem, verbatim; suffix -2/-3 on collision BEFORE first publication, never rename after
date: <YYYY-MM-DD>
source: <what triggered the audit — "scheduled audit", an improvement-item ID from `calibrate`, a user ask>
processed: []                        # finding keys the improvement loop has drained; a YAML list, never a boolean
---

# Doc-drift report — <slug>

## Scope

<What was audited: the root, which spines (outer + nested), which dimensions were in scope.>

## Scorecard

<The entry-door checks + 12-dimension lines, as printed to the conversation — solid | drift |
gap with one-line rationales.>

## Findings

<One keyed heading per accepted finding — the key matches `[a-z0-9-]+` and is unique in this
report; the improvement loop cites `<report-id>#<key>` and stamps `processed:` when drained.
Rank gap first, then drift. Each carries location, the triaged evidence (the partitioned count,
not the raw one), and the concrete adjustment.>

#### <finding-key> — <title>

<dimension · location · severity · issue · adjustment>
