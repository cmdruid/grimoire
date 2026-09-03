#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"; B="$ROOT/skills/backlog"; pass=0 fail=0
for f in setup repair migrate anchor tracker file query debrief curate; do [ -f "$B/verbs/$f.md" ] && pass=$((pass+1)) || fail=$((fail+1)); done
for f in task issue feedback promote; do [ ! -e "$B/verbs/$f.md" ] && pass=$((pass+1)) || fail=$((fail+1)); done
[ -x "$B/scripts/trackers-anchor.sh" ] && [ -f "$B/templates/agents-pointer.md" ] \
  && pass=$((pass+1)) || fail=$((fail+1))
for f in "$B/scripts/tracker-api.sh" "$B/scripts/record-"mint.sh "$B/templates/"trackers.md; do [ ! -e "$f" ] && pass=$((pass+1)) || fail=$((fail+1)); done
for f in "$B/scripts/trackers.sh" "$B/scripts/tracker-layer-status.sh" "$B/scripts/tracker-runtime-check.sh" "$B/scripts/tracker-readme-status.sh" "$B/templates/trackers-readme-block.md"; do [ -f "$f" ] && pass=$((pass+1)) || fail=$((fail+1)); done
[ -x "$B/scripts/tracker-runtime-check.sh" ]&&pass=$((pass+1))||fail=$((fail+1))
for f in "$B/templates/debrief-anchor.md" "$B/scripts/route-status.sh" "$B/scripts/register-route.sh"; do [ ! -e "$f" ] && pass=$((pass+1)) || fail=$((fail+1)); done
if rg -n '/backlog (task|issue|feedback|promote)([^a-z-]|$)' "$ROOT/skills" >/dev/null; then fail=$((fail+1)); else pass=$((pass+1)); fi
for needle in '.trackers' 'trackers.sh' '/backlog query' '/backlog repair' '/backlog anchor' 'produces: tracker'; do grep -qF -- "$needle" "$B/SKILL.md" && pass=$((pass+1)) || fail=$((fail+1)); done
for needle in 'tracker@2' 'tables/<stem>.tsv' 'history.tsv';do grep -qF -- "$needle" "$B/SKILL.md"&&pass=$((pass+1))||fail=$((fail+1));done
for needle in 'scripts/migrate-trackers.sh preview' 'explicit confirmation' 'row order' 'non-ID byte' 'Git diff';do grep -qF -- "$needle" "$B/verbs/migrate.md"&&pass=$((pass+1))||fail=$((fail+1));done
grep -qF '/backlog migrate' "$B/verbs/setup.md"&&pass=$((pass+1))||fail=$((fail+1))
for f in tracker file query debrief curate;do grep -qF 'scripts/tracker-runtime-check.sh' "$B/verbs/$f.md"&&pass=$((pass+1))||fail=$((fail+1));done
grep -qF '.trackers/DEBRIEF.md' "$B/verbs/debrief.md"&&pass=$((pass+1))||fail=$((fail+1))
if grep -qF '.agents/skilldata/backlog/hooks/debrief.md' "$B/verbs/debrief.md";then fail=$((fail+1));else pass=$((pass+1));fi
for needle in 'successful debrief in this context' 'do not create a durable cursor'; do grep -qF -- "$needle" "$B/verbs/debrief.md" && pass=$((pass+1)) || fail=$((fail+1)); done
for needle in 'serialized custodial continuation' 'completed-unit identity' 'commit evidence' 'prior successful debrief receipt' 'one scoped commit'; do grep -qF -- "$needle" "$B/verbs/debrief.md" && pass=$((pass+1)) || fail=$((fail+1)); done
for needle in 'Project Feedback' 'Development-experience observations whose remedy belongs in this project.';do grep -qF -- "$needle" "$B/suggestions/feedback.md"&&pass=$((pass+1))||fail=$((fail+1));done
for needle in 'reusable installed skill' 'skill-tagged byproduct' 'remedy belongs in this repository';do grep -qF -- "$needle" "$B/verbs/debrief.md"&&pass=$((pass+1))||fail=$((fail+1));done
if grep -qF 'skill-feedback' "$B/verbs/debrief.md";then fail=$((fail+1));else pass=$((pass+1));fi
echo "skill-doc-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
