<!-- backlog:trackers-tool BEGIN -->
## Use the tracker tool

This block is Backlog's current package-owned `tracker@1` tool contract. Project guidance outside
these markers may describe local practice, but it does not redefine the canonical provider.

`README.md` is this local guide. Each `<stem>.tsv` is current queue state, and `receipts.tsv` is the
shared observation and consumption ledger. Git owns history, merge, recovery, and rollback.
Adjacent executable `trackers.sh` is the sole writer for queue rows and receipts.
Direct TSV inspection is allowed; never hand-edit queue or receipt bytes.

Run commands from this tracker-root directory through adjacent `./trackers.sh`:

```sh
./trackers.sh describe
./trackers.sh catalog
./trackers.sh page --tracker tasks --status open --limit 20
./trackers.sh create --tracker tasks --text "Describe the follow-up" --evidence "path-or-reference"
./trackers.sh update --tracker tasks --id tasks-1 --text "Sharpened follow-up" --evidence "path-or-reference"
./trackers.sh observe --consumer example/review --tracker tasks --ids tasks-1
./trackers.sh consume --consumer example/review --tracker tasks --ids tasks-1 --resolution "Resolved" --result "path-or-reference"
```

`describe`, `catalog`, and bounded `page` are read-only. Mutation uses stable consumer keys;
`consume` requires a resolution; evidence and result references are optional. Mutation output names
tracker-root-relative `wrote=` paths for caller-owned commit custody.

If `./trackers.sh` is missing, non-executable, or does not describe exactly `schema=tracker@1`, stop.
Do not hand-repair it and do not run the bundled provider against project data. Run
`/backlog repair`; use `/backlog setup` only when the tracker layer has not been initialized.
<!-- backlog:trackers-tool END -->
