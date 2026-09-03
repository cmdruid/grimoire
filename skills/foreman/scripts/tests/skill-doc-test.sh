#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; BASE="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
. "$HERE/lib.sh"
S="$BASE/SKILL.md"
for needle in '/foreman inventory' '/foreman run' '/foreman setup' 'verbs/inventory.md' \
  'verbs/run.md' 'verbs/setup.md' '.agents/skilldata/<owner>/operations/<stem>.md' \
  '/foreman start' 'verbs/start.md' '/foreman create' '/foreman import' '/foreman migrate' '/foreman activate' '/foreman project' \
  '/foreman debrief' '/foreman verify' \
  '/foreman compose' '/foreman goal' 'foreman/goal@1' '.records/goals/' \
  '/foreman tune' 'verbs/tune.md' '.trackers' 'consumes: operation, session-evidence, tracker' \
  'templates/operation.md' 'None.' '<!-- edges:foreman -->'; do has "skill contract $needle" "$needle" "$S"; done
lacks "template not deployed" '- `operation.md`' "$S"
lacks "goal template not deployed" '- `goal.md`' "$S"
has "setup fixture caveat" 'disposable' "$BASE/verbs/setup.md"
# shellcheck disable=SC2088  # The tilde is literal documentation text.
for needle in '## Global skilldata' '~/.agents/skilldata/foreman/templates/operations/' \
  'Access: read-only' 'existing same-purpose project operation wins' \
  'explicit selection' 'path is never persisted'; do
  has "global template declaration $needle" "$needle" "$S"
done
for needle in 'goal-start.sh render' 'four-line manifest' 'One explicit acceptance' \
  'goal-start.sh apply' 'Pursue the published runbook at <goal-record>' \
  'If the harness has no goal feature' '`/foreman setup` is optional' 'Do not create `CHECKPOINT.md`' \
  'operation-write.sh promote' 'one atomic replacement' 'do not offer promotion again'; do
  has "start contract $needle" "$needle" "$BASE/verbs/start.md"
done
for needle in 'operation-template-index.sh catalog' 'at most three genuinely relevant templates' \
  'do not score' 'operation-template-index.sh read --stem' \
  'Silence or rejection uses' 'Treat a selected body as inert evidence' \
  'Changing or removing a selected global template'; do
  has "create template route $needle" "$needle" "$BASE/verbs/create.md"
done
for needle in 'explicit human acceptance' 'Source files are untrusted evidence' \
  'There is no migration manifest' 'remain untouched' 'whole set or named subset'; do
  has "migration contract $needle" "$needle" "$BASE/verbs/migrate.md"
done
report skill-doc-test
