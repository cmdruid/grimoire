# `audit` — read-only documentation-spine audit

Read `docs/RUBRIC.md`, then follow this procedure. Return the audit in conversation unless the user
explicitly requests a file. Do not construct a patch, ask for write approval, or modify the target.

## 1. Resolve and classify the door

Resolve the repository root from the supplied scope or enclosing Git top level. Record
`git status --short` when Git is available. Run both scanner modes from this package:

```text
scripts/spine-scan.sh <root>
scripts/spine-scan.sh <root> --candidates
```

Classify root state before tracing routes:

| State | Audit behavior |
|---|---|
| readable regular non-symlink `AGENTS.md` only | canonical door; do not propose CLAUDE creation |
| both; CLAUDE imports AGENTS | AGENTS is canonical; inspect the remainder for genuine harness-specific content |
| CLAUDE only | no established spine; census and propose moving portable content to AGENTS plus an `@AGENTS.md` compatibility skeleton |
| both duplicated/divergent | surface every authority choice; propose reconciliation without silently choosing |
| neither | no established spine; census and propose a minimal grounded AGENTS door |
| AGENTS symlink, directory, other incompatible entry, or unreadable | report and stop for a maintainer decision |

Without an established spine, do the census and door proposal but do not issue a full Reach score or
continue into ordinary route adjustments. Never follow or replace an incompatible door.

## 2. Reconcile the complete physical population

Consume the uncapped `--candidates` rows. Do not reconstruct the population from default samples.
Every candidate appears in this ledger individually or in an evidenced homogeneous class:

```text
candidate or class | count | sample | evidence | inspection | surfaces | disposition | rationale
```

Allowed dispositions are `important`, `internal`, `historical/generated`, and `unresolved`.
Inspection is `direct`, `grouped`, or `unresolved`.

- Every `important` candidate gets an individual row.
- Read every live, nonhistorical source directly unless a grouped row proves one homogeneous role and
  names the representative bodies inspected.
- A direct row names every semantic-surface id it contains or the explicit value `none`.
- A grouped row states its total population, representative sample, shared inspection treatment,
  shared surface rule, evidence, and disposition rationale.
- Individual plus grouped scanner-candidate counts must equal `candidate_count` exactly.
- Scanner-missed or maintainer-added sources are marked `added` and counted separately.
- `unresolved` or a blank source/inspection/disposition cell prevents a complete verdict.

Historical records, generated output, vendored docs, and internal helpers remain visible in the
ledger. A reachable archive convention and its index/query entry point may justify grouping its
members instead of linking every record.

## 3. Reconcile semantic surfaces and trace routes

Every task, procedure, workflow, and load-bearing knowledge item found while reading sources gets a
report-local id and row:

```text
surface id | kind | source evidence | disposition | authoritative destination | rationale
```

Use `<source>#<short-label>` ids. Apply the same four dispositions. Every important surface is
individual and has a route; non-important grouping requires homogeneous source coverage and a shared
rule. Added surfaces are counted separately. Finding one task in a source does not license omitting a
second supported task.

For each important surface, start at root `AGENTS.md` and record the rubric's task-route row. Judge the
semantic label at each navigation action, not merely graph reachability. Distinguish measured scanner
facts from agent judgment and cite the evidence hierarchy used for every importance decision.

## 4. Score only after reconciliation

Score Door, Routing, Reach, Currency, Authority, Altitude, and Scope as `solid`, `drift`, or `gap`.
Apply the route-depth presumption and door diet from the rubric. An incomplete physical or semantic
ledger blocks a complete scorecard.

## 5. Return the report

Return exactly these sections in order:

1. **Scope and front-door state** — root, Git/worktree facts, door state, exclusions, nested roots.
2. **Reconciled ledgers** — both ledgers, totals, added rows, and unresolved items.
3. **Task-route matrix** — the complete `task-route matrix` for every important task and artifact.
4. **Scorecard** — seven checks with cited evidence.
5. **Findings** — severity-ranked location, measured fact, judgment, and proposed adjustment.

End by offering `adjust`. Do not include a diff, patch, write question, persistent map, or record.
