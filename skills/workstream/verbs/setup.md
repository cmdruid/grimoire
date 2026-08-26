# `setup [<root>]` — deploy active Workstream templates and hook points

Run package-local `scripts/workstream-setup.sh <root>` standalone, or add `--write-only` inside an
announced configuration sweep. It preflights and immediately rechecks the complete owned write set,
then deploys absent-only:

- `templates/manifest.md`
- `templates/debrief.md`
- `hooks/feature-completion.md`
- `hooks/after-eventful-ship.md`

The hook files start at exactly zero bytes, so missing and empty remain behaviorally identical.
Valid incumbents win; recognized `plans.md` and `reports.md` legacy templates refuse with
`/workstream migrate <source-path>`. Hand-off, compaction, coordinator, debug, and design templates
remain package-only. Standalone setup commits exactly its reported writes once; sweep mode is
write-only and a no-op rerun makes no commit.

Done when the four active assets are present, hooks remain disabled until authored, and no
package-only, schema, record-shell, or sibling path changed.
