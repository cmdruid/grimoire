#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"; B="$ROOT/skills/backlog"; pass=0 fail=0
for f in setup repair migrate anchor tracker file query debrief curate; do [ -f "$B/verbs/$f.md" ] && pass=$((pass+1)) || fail=$((fail+1)); done
for f in task issue feedback promote; do [ ! -e "$B/verbs/$f.md" ] && pass=$((pass+1)) || fail=$((fail+1)); done
[ -x "$B/scripts/trackers-anchor.sh" ] && [ -f "$B/templates/agents-pointer.md" ] && [ -f "$B/templates/agents-route.md" ] \
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
for needle in 'base-sha256' 'candidate-sha256' 'complete unified diff' 'explicit human cutover decision' '`--debrief` isn' 'healthy trackers' 'unhealthy tracker layer' 'same-directory atomic rename' 'one path-scoped commit';do grep -qF -- "$needle" "$B/verbs/anchor.md"&&pass=$((pass+1))||fail=$((fail+1));done
for needle in 'skill:backlog' 'previewed base and candidate digests' 'removal without tracker health' 'agents-route.md' 'agents-pointer.md';do grep -qF -- "$needle" "$B/SKILL.md"&&pass=$((pass+1))||fail=$((fail+1));done
for f in tracker file query debrief curate;do grep -qF 'scripts/tracker-runtime-check.sh' "$B/verbs/$f.md"&&pass=$((pass+1))||fail=$((fail+1));done
grep -qF '.trackers/DEBRIEF.md' "$B/verbs/debrief.md"&&pass=$((pass+1))||fail=$((fail+1))
if grep -qF '.agents/skilldata/backlog/hooks/debrief.md' "$B/verbs/debrief.md";then fail=$((fail+1));else pass=$((pass+1));fi
for needle in 'successful debrief in this context' 'do not create a durable cursor'; do grep -qF -- "$needle" "$B/verbs/debrief.md" && pass=$((pass+1)) || fail=$((fail+1)); done
for needle in 'Project Feedback' 'Qualitative development experience whose remedy belongs in this project.';do grep -qF -- "$needle" "$B/suggestions/feedback.md"&&pass=$((pass+1))||fail=$((fail+1));done
for needle in 'Failures' 'Unresolved test, build, and project-tool behavior.' 'one row per failure family';do grep -qF -- "$needle" "$B/suggestions/failures.md"&&pass=$((pass+1))||fail=$((fail+1));done
for needle in '`tasks`, `issues`, `failures`, `feedback`, `routines`' 'all five' 'former four-queue layers' '.setup-selection';do grep -qF -- "$needle" "$B/SKILL.md"&&pass=$((pass+1))||fail=$((fail+1));done
for needle in 'nonempty multi-select' 'Unattended setup' '--trackers <comma-separated-stems>' 'valid only during initialization' 'valid cleanup state' 'any project front-door change was explicitly consented' 'separate anchor transaction';do grep -qF -- "$needle" "$B/verbs/setup.md"&&pass=$((pass+1))||fail=$((fail+1));done
for needle in 'Enable the project debrief route?' 'Default to no' 'Unattended setup without `--debrief` never' "Initialized reconciliation doesn't offer" 'Explicit `--debrief` bypasses only' "public anchor procedure's" 'Report tracker success and anchor' 'never roll back setup or combine their path sets';do grep -qF -- "$needle" "$B/verbs/setup.md"&&pass=$((pass+1))||fail=$((fail+1));done
for needle in 'only after the tracker transaction' 'without folding `.trackers` paths' 'cannot roll back successful setup';do grep -qF -- "$needle" "$B/verbs/anchor.md"&&pass=$((pass+1))||fail=$((fail+1));done
for needle in 'reusable installed skill' 'skill-tagged byproduct' 'remedy belongs in this repository';do grep -qF -- "$needle" "$B/verbs/debrief.md"&&pass=$((pass+1))||fail=$((fail+1));done
for needle in 'Route by the state of the knowledge' 'configured layer has no `failures` queue' 'page the bounded open `failures` population' 'Use `update` for one matching family' 'strongest current evidence';do grep -qF -- "$needle" "$B/verbs/debrief.md"&&pass=$((pass+1))||fail=$((fail+1));done
for needle in 'chosen outcomes to `tasks`' 'unresolved operational sightings to `failures`' 'tracker@2 provider schema does not change';do grep -qF -- "$needle" "$B/SKILL.md"&&pass=$((pass+1))||fail=$((fail+1));done
for needle in 'merge-conflict resolution is the only exception' 'managed README procedure';do grep -qF -- "$needle" "$B/SKILL.md"&&pass=$((pass+1))||fail=$((fail+1));done
grep -qF '/backlog tracker add failures' "$B/verbs/tracker.md"&&pass=$((pass+1))||fail=$((fail+1))
if grep -qF 'agent-feedback' "$B/verbs/debrief.md";then fail=$((fail+1));else pass=$((pass+1));fi
echo "skill-doc-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
