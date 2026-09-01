# Project trackers

Public tracker@2 tables and their shared lifecycle history.

<!-- backlog:trackers-tool BEGIN -->
## Use the tracker tool

This README and the adjacent executable `trackers.sh` are the complete ordinary-use interface to
the local `tracker@2` layer. You don't need the Backlog skill to inspect queues, create or update
items, or record observation and consumption. Project guidance outside this managed block can
describe local practice, but it doesn't redefine the provider contract.

Each `tables/<stem>.tsv` holds the source rows for one queue. Those source rows for one queue can
change only through `create` and `update`; lifecycle events never rewrite or remove them.
`history.tsv` is the shared observation and consumption ledger. Direct TSV inspection is allowed,
but never hand-edit either kind of TSV: adjacent `trackers.sh` is their sole writer. Git owns file
history, merge, recovery, and rollback.

Run the provider from the project root through its fixed `.trackers/` path:

```sh
.trackers/trackers.sh describe
.trackers/trackers.sh catalog
.trackers/trackers.sh history --limit 20
.trackers/trackers.sh page --tracker tasks --status open --limit 20
.trackers/trackers.sh page --tracker tasks --status open --limit 20 --after tasks-20
.trackers/trackers.sh page --tracker tasks --status open --limit 20 --consumer example/review --unobserved
.trackers/trackers.sh create --tracker tasks --text "Describe the follow-up" --evidence "path-or-reference"
.trackers/trackers.sh update --tracker tasks --id tasks-1 --text "Sharpened follow-up" --evidence "path-or-reference"
.trackers/trackers.sh observe --consumer example/review --tracker tasks --ids tasks-1
.trackers/trackers.sh consume --consumer example/review --tracker tasks --ids tasks-1 --resolution "Resolved" --result "path-or-reference"
```

`describe` prints the schema and command capabilities. `catalog` reports `open`, `consumed`, and
`all` counts for every queue. `page` requires `--tracker`, `--status open|consumed|all`, and a
positive `--limit`; `history` requires a positive `--limit`. Both return `next=`. Pass that last
returned item or event ID back with `--after` only when another page is needed. An empty `next=`
means the page is complete.

State is derived rather than rewritten in the queue table. An item is open until any consumer
records a `consumed` event for it. Consumption is terminal for that tracker item across all
consumers, preserves the source row, and requires a nonempty `--resolution`; `--result` is optional.
Observation is consumer-scoped and idempotent: the same stable `--consumer` key observing the same
item again returns `unchanged=` instead of adding another event. Use `--consumer KEY --unobserved`
together on `page` to hide items already observed or consumed by that consumer. A consumed item can
still appear to another consumer under `--status consumed|all --unobserved` until that consumer has
its own lifecycle event.

`create` requires a nonempty single-line `--text`; `--evidence` is optional. `update` changes an open
item's text, evidence, or both. `observe` and `consume` accept one or more IDs after `--ids`; missing
IDs are reported without inventing rows. Mutations print tracker-root-relative `wrote=` paths plus
item or event facts when applicable. Prefix those paths with `.trackers/`, inspect the Git diff, and
commit only the reported files in the checkout that owns them.

`.trackers/DEBRIEF.md` is editable routing guidance for completed-work sweeps. The generic provider
doesn't read it. Queue creation and removal, setup, repair, brownfield migration, and debrief routing
remain Backlog maintenance or judgment work.

If `.trackers/trackers.sh` is missing, non-executable, byte-stale, or doesn't describe exactly
`schema=tracker@2`, use `/backlog repair`; use `/backlog setup` only when the layer is uninitialized.
If the Backlog skill isn't available, stop and report the maintenance requirement. Don't improvise
provider bytes, TSV edits, queue administration, migration, or debrief routing.
<!-- backlog:trackers-tool END -->
