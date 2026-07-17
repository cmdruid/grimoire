# `/architect check` — validate seed health

Runs the read-only fact-computing script, then **you** judge the facts. See `docs/DOCTRINE.md`
for the durability gradient and the two-tier spec this validates against.

## Run it

```bash
bash <skill-dir>/scripts/architect-check.sh <project>/design [<repo-root>]
```

- `<repo-root>` (default `<design-dir>/..`) is where `src/…:NN` reference-arch pointers resolve
  against — pass the actual repo root if `design/` doesn't sit directly above it.
- Exit **1** iff `spine_complete=false` or any `contract:<sys>=false`; everything else is
  advisory and doesn't affect the exit code.

## Read the facts, don't just relay the exit code

The script emits clean `key=value` facts, per-system where namespaced `key:<system>=…`:

| fact | means |
|---|---|
| `spine_complete` / `spine_missing` | required root files (`VISION`/`PHILOSOPHY`/`GLOSSARY`/`MAP`) present |
| `contract:<sys>` | the system has a `## Contract (BINDING)` heading — **no contract = not rebuildable** |
| `refarch:<sys>` | the system has a `## Reference Architecture` heading |
| `baseline_adr:<sys>` / `baseline_date:<sys>` | the `distilled_through_*` stamp — how stale the reference-arch snapshot is |
| `acceptance_placeholder:<sys>=true` | the Acceptance bullet is still `<...>`/TBD/TODO, not concrete |
| `drift:<sys>=<pointer>` | a `src/…:NN` reference-arch pointer whose target is missing or shorter than `NN` lines |
| `map_orphan=<sys>` | a `src/<sys>.md` spec not indexed in `MAP.md` |
| `map_dangling=<name>` | a `MAP.md` row naming a spec file that doesn't exist |

Turn each into a judgment, don't auto-fix:

- **`drift:*` / `acceptance_placeholder:*` → flag to the human/caller, don't silently patch.**
  Drift means the reference-arch snapshot rotted since it was last distilled; a placeholder
  acceptance means there is no concrete gate a rebuild could pass — both need a real editorial
  pass, not a mechanical fill-in.
- **A stale `baseline_date:<sys>` relative to the project's current ADRs → recommend `/architect
  distill`** for that system, rather than hand-patching the reference-arch tier yourself.
- **`spine_missing` / `contract:<sys>=false` → these are the hard blockers** (the exit-1
  conditions): a rebuild has no constitution, or no binding contract, to work from.
- **`map_orphan` / `map_dangling` → seam-graph hygiene**, cheap to fix (add the row / drop the
  reference) but not urgent unless something is about to consume `MAP.md`.

## The one thing this script cannot tell you

**This script is necessary but not sufficient.** It catches *structural* rot — missing spine,
missing contract, drift, stale baselines, placeholder acceptance, MAP gaps — because those are
all mechanically checkable. It **cannot** tell you whether a spec that passes every check is
actually *sufficient to rebuild from*: a contract can be present, concrete, and driftless while
still omitting the one invariant that made the old system work. Passing `check` is a floor, not a
verdict of sufficiency.

The real semantic gate is the **fresh-agent read-test**: hand an agent *only* the spec (no ADR
access, no chat history, no the-author-remembers context) and confirm it can act on it —
correctly, without guessing. `check` is what you run cheaply and often; the read-test is the
expensive, occasional proof that the seed actually holds up. See `docs/DOCTRINE.md` § Sufficiency,
and its circularity for why a rebuild that reverse-engineers gaps out of the old code doesn't
count as evidence either.
