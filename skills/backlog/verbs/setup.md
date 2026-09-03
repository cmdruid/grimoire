# `setup [--trackers <stems>] [--debrief]` — deploy Backlog explicitly

1. Resolve `<root>` per `SKILL.md`. Backlog uses the fixed `.trackers` layer. In a Git checkout,
   `<root>` must be its top level; a nested directory refuses before any write.
2. Before interaction, run package-local `scripts/tracker-layer-status.sh setup --root <root>` and
   retain whether this invocation is completing first initialization or reconciling an already
   initialized layer.
   An initialized layer preserves its queue population and skips selection. A valid interrupted
   selection or valid cleanup state resumes its recorded set without prompting; a recognized no-intent
   legacy prefix resumes the former `tasks,issues,feedback,routines` set.
3. For an absent layer, run package-local `scripts/backlog-setup.sh <root> --list`. Attended setup
   presents those five rows as one nonempty multi-select, all selected by default. Unattended setup
   selects all five. Explicit `--trackers <comma-separated-stems>` bypasses only this choice; the
   helper validates and normalizes it, and it is valid only during initialization.
4. Run package-local `scripts/backlog-setup.sh <root> --apply [--trackers <selection>]`. `--debrief`
   is never passed to the deterministic tracker helper.
5. Parse unique `wrote=` / `reconciled=` / `removed=` paths. Standalone and nonempty → one
   `scripts/scoped-commit.sh <root> "Backlog: setup" <paths...>`; inside an announced configuration
   sweep, return the paths without committing; empty → no commit. Finish this tracker transaction
   and its custody result before beginning any front-door operation.
6. After a completed first initialization in an attended session, run the public anchor procedure's
   preview and show its complete install candidate, then ask **Enable the project debrief route?**
   Default to no. Unattended setup without `--debrief` never inspects or changes `AGENTS.md`.
   Initialized reconciliation doesn't offer the route.
7. Explicit `--debrief` bypasses only the route choice and confirmation. After fresh or initialized
   tracker reconciliation, invoke the public anchor procedure's canonical install or refresh path;
   retain its preview, digest, malformed-state, concurrency, and competing-route gates. A competing
   behavioral route still requires a human cutover decision. Report tracker success and anchor
   refusal, failure, or commit failure separately; never roll back setup or combine their path sets.

Done when a fresh public layer contains exactly the selected subset of
`tasks,issues,failures,feedback,routines`, its matching prompt sections, README, executable adjacent
`trackers.sh`, lifecycle history, and `.trackers/tables/.gitkeep`; no `.setup-selection` or reserved
temporary remains; any project front-door change was explicitly consented and completed through the
separate anchor transaction; and a rerun preserves an initialized queue population while changing
only drifted package-owned surfaces.

Setup intentionally does not read or move tracker@1 state. When it refuses a flat tracker@1 layout,
use `/backlog migrate`; migration remains the only legacy reader.
