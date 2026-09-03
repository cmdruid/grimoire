# `setup [<root>]` — interactively calibrate Auditor's project surface

Auditor setup is optional, time-intensive, and deliberately excluded from an initial Clankshop
configuration sweep. Ask separately before starting it.

1. Resolve `<root>` and the project instructions. Run package-local `scripts/auditor-seed.sh
   <root>` to deploy `templates/reports.md` plus the generic `rules/*.md` rubric leaves absent-only.
   The deployer preflights the complete owned set, immediately rechecks parents, preserves every
   incumbent, and refuses recognized legacy content with `/auditor migrate <source-path>`.
2. Follow `BOOTSTRAP.md`'s decision walk with the user. Author only
   `.agents/skilldata/auditor/doctrine/test/workflows/audit/GUIDE.md`, `metrics.sh`, native rule
   files, and edits to the seeded generic rules. Run metrics to validate its mechanics; the output is
   not an audit report.
   When rerunning setup against an incumbent twelve-rule rubric, the seed may add the absent
   Complexity leaf but must preserve `GUIDE.md`, `metrics.sh`, and every incumbent rule byte-for-byte.
   Ask whether to adopt Complexity. Calibrate and index it only after the
   owner explicitly approves adoption.
   Otherwise report the seeded leaf as inactive and leave the incumbent guide and metrics unchanged.
   Setup is not complete until one of those two dispositions is explicit; ordinary passes never
   score an unindexed leaf.
3. Do not run an audit pass, mint a `reports/` record, select findings, or write a pointer into the
   host's document index or routing surface. The first audit is a separate explicit invocation.
4. Validate the rubric and report template. Standalone setup makes one pathspec-scoped commit over
   exactly the reported seed and authored rubric paths. If a caller explicitly places this deferred
   setup inside a larger sweep, remain write-only; a no-op rerun makes no commit.

Done when the report template and calibrated rubric are valid, all writes are Auditor-owned, and no
audit report or host pointer exists because of setup.
