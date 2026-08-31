#!/usr/bin/env bash
# skill-doc-test.sh — guard explicit catalog setup and read-only report generation.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)/SKILL.md"
. "$DIR/lib.sh"

expect "setup is an explicit surface" "/analyst setup" "$SKILL"
expect "normal report generation stays read-only" \
  "read-only toward the project during report generation" "$SKILL"
expect_absent "lazy deployment is retired" 'Deploy is **lazy**' "$SKILL"
expect_absent "normal engine does not invoke deploy" \
  'Run `scripts/analyst-deploy.sh <root>` first' "$SKILL"
expect "tracker provider is first class" '.trackers' "$SKILL"
expect "tracker contract is current" 'tracker@2' "$SKILL"
expect "legacy homes stay dark" 'never probed' "$SKILL"

report "analyst skill docs"
