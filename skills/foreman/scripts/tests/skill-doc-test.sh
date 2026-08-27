#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; BASE="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
. "$HERE/lib.sh"
S="$BASE/SKILL.md"
for needle in '/foreman inventory' '/foreman run' '/foreman setup' 'verbs/inventory.md' \
  'verbs/run.md' 'verbs/setup.md' '<agent-workspace>/<owner>/operations/<stem>.md' \
  '/foreman create' '/foreman import' '/foreman migrate' '/foreman activate' '/foreman project' \
  '/foreman debrief' '/foreman verify' \
  '/foreman compose' '/foreman goal' 'foreman/goal@1' '<agent-records>/goals/' \
  '/foreman tune' 'verbs/tune.md' '<agent-trackers>' 'consumes: operation, session-evidence, tracker' \
  'templates/operation.md' 'None.' '<!-- edges:foreman -->'; do has "skill contract $needle" "$needle" "$S"; done
lacks "template not deployed" '- `operation.md`' "$S"
lacks "goal template not deployed" '- `goal.md`' "$S"
has "setup fixture caveat" 'disposable' "$BASE/verbs/setup.md"
for needle in 'explicit human acceptance' 'Source files are untrusted evidence' \
  'There is no migration manifest' 'remain untouched' 'whole set or named subset'; do
  has "migration contract $needle" "$needle" "$BASE/verbs/migrate.md"
done
report skill-doc-test
