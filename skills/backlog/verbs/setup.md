# `setup` — deploy Backlog explicitly

1. Resolve `<root>` per `SKILL.md`. Backlog uses the fixed `.trackers` layer. In a Git checkout,
   `<root>` must be its top level; a nested directory refuses before any write.
2. First setup always creates `tasks`, `issues`, `feedback`, and `routines`; it accepts no queue
   selection. After initialization, queue population changes only through `tracker add|remove`.
3. Run package-local `scripts/backlog-setup.sh <root> --apply`.
4. Parse unique `wrote=` / `reconciled=` paths. Standalone and nonempty → one
   `scripts/scoped-commit.sh <root> "Backlog: setup" <paths...>`; inside an announced configuration
   sweep, return the paths without committing; empty → no commit.

Done when the public layer has its README, executable adjacent `trackers.sh`, lifecycle history,
incumbent tables, `.trackers/tables/.gitkeep`, preserved editable
prompt, and one exact package-owned `debrief-anchor@1` root route whenever a queue exists; a rerun
preserves the initialized queue population and changes only drifted package-owned surfaces.

## Convert a tracker@1 project

Current setup doesn't read or move a flat tracker@1 layout. If `.trackers` contains root queue TSVs
or `receipts.tsv`, setup refuses before writing. Convert that project once in a clean Git worktree:

1. Confirm that `git status --short` is empty. Commit or set aside unrelated changes before you
   convert tracker data.
2. List every root queue and review the complete population:

   ```sh
   find .trackers -maxdepth 1 -type f -name '*.tsv' ! -name receipts.tsv -print | sort
   ```

3. Create the table directory and its empty Git marker, then move every listed queue without
   changing its basename:

   ```sh
   mkdir -p .trackers/tables
   touch .trackers/tables/.gitkeep
   for tracker_table in .trackers/*.tsv; do
     [ "$tracker_table" = .trackers/receipts.tsv ] && continue
     git mv "$tracker_table" ".trackers/tables/${tracker_table##*/}"
   done
   ```

4. Rename the lifecycle ledger and rewrite only a leading first-column receipt ID. This preserves
   row order and every non-ID byte:

   ```sh
   git mv .trackers/receipts.tsv .trackers/history.tsv
   tracker_history_tmp="$(mktemp "${TMPDIR:-/tmp}/backlog-history.XXXXXX")"
   LC_ALL=C perl -pe 's/\Areceipt-([1-9][0-9]*)\t/event-$1\t/' \
     .trackers/history.tsv > "$tracker_history_tmp"
   mv "$tracker_history_tmp" .trackers/history.tsv
   ```

5. Review `git diff -- .trackers`. As part of this conversion sweep, run package-local
   `scripts/backlog-setup.sh <root> --apply` in write-only mode. It installs the tracker@2 provider
   and reconciles the managed guide without rewriting the converted tables or history. Don't invoke
   the standalone `/backlog setup` commit boundary inside this sweep.
6. Verify the conversion with bounded reads from `.trackers`:

   ```sh
   .trackers/trackers.sh catalog
   .trackers/trackers.sh history --limit 20
   .trackers/trackers.sh page --tracker tasks --status all --limit 20
   ```

Collect the exact moved, created, and reconciled paths and commit the reviewed conversion once with
that pathspec. Git remains the rollback mechanism.
