#!/usr/bin/env bash
# Repository boundary guard for Backlog's single debrief-anchor dispatcher.
set -u

SCRIPT_ROOT="$(CDPATH='' cd -P "$(dirname "$0")/../.." && pwd)"
ROOT="${1:-$SCRIPT_ROOT}"
case "$ROOT" in /*) ;; *) echo 'FAIL: root must be absolute' >&2; exit 2 ;; esac
[ -d "$ROOT" ] || { echo 'FAIL: root missing' >&2; exit 2; }
pass=0
fail=0

pass_one() { pass=$((pass + 1)); }
fail_one() { echo "FAIL: $*" >&2; fail=$((fail + 1)); }

guard_lifecycle_dispatch() {
  if rg -n -i --glob '!scripts/tests/**' \
    '(/backlog[[:space:]]+debrief|backlog[[:space:]]+debrief|backlog-setup\.sh|skills/backlog/)' \
    "$ROOT/skills/checkpoint" "$ROOT/skills/workstream"; then
    return 1
  fi
}

guard_commit_markers() {
  if rg -n -- \
    '(--stamp|built-against:.*\$|(^|[^[:alnum:]_])stamp=.*(git|date))' \
    "$ROOT/skills/backlog/scripts/backlog-setup.sh" \
    "$ROOT/skills/backlog/scripts/register-route.sh" \
    "$ROOT/skills/backlog/scripts/route-status.sh"; then
    return 1
  fi
}

if guard_lifecycle_dispatch; then pass_one; else fail_one 'Checkpoint or Workstream dispatches Backlog'; fi
if guard_commit_markers; then pass_one; else fail_one 'live Backlog route code constructs a commit-derived marker'; fi

if [ "${BACKLOG_ANCHOR_CONTRACT_SKIP_RED:-}" = 1 ]; then
  [ "$fail" -eq 0 ]
  exit
fi

# Red-prove both absence guards against a copied live-source population, then
# restore the copied fixture and verify its bytes and green result.
T="$(mktemp -d "${TMPDIR:-/tmp}/backlog-anchor-repo-contract.XXXXXX")"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/root/skills"
cp -R "$ROOT/skills/checkpoint" "$T/root/skills/checkpoint"
cp -R "$ROOT/skills/workstream" "$T/root/skills/workstream"
mkdir -p "$T/root/skills/backlog"
cp -R "$ROOT/skills/backlog/scripts" "$T/root/skills/backlog/scripts"

lifecycle_source="$ROOT/skills/workstream/SKILL.md"
lifecycle_copy="$T/root/skills/workstream/SKILL.md"
cp "$lifecycle_source" "$T/lifecycle.before"
printf '\nPlant: run `/backlog debrief` here.\n' >> "$lifecycle_copy"
count="$(grep -Fxc 'Plant: run `/backlog debrief` here.' "$lifecycle_copy" || true)"
if [ "$count" -eq 1 ]; then pass_one; else fail_one "lifecycle plant count want=1 got=$count"; fi
if BACKLOG_ANCHOR_CONTRACT_SKIP_RED=1 bash "$0" "$T/root" > "$T/lifecycle-red.out" 2>&1; then
  fail_one 'lifecycle dispatch guard stayed green on planted invocation'
else
  pass_one
fi
cp "$lifecycle_source" "$lifecycle_copy"
if cmp -s "$lifecycle_source" "$lifecycle_copy" && cmp -s "$lifecycle_source" "$T/lifecycle.before"; then
  pass_one
else
  fail_one 'lifecycle fixture/source restore was not byte-exact'
fi
if BACKLOG_ANCHOR_CONTRACT_SKIP_RED=1 bash "$0" "$T/root" >/dev/null 2>&1; then pass_one; else fail_one 'restored lifecycle fixture did not return green'; fi

marker_source="$ROOT/skills/backlog/scripts/backlog-setup.sh"
marker_copy="$T/root/skills/backlog/scripts/backlog-setup.sh"
cp "$marker_source" "$T/marker.before"
printf '\nstamp="$(git -C "$ROOT" log -1 --format=%%h)" # planted prohibited marker derivation\n' >> "$marker_copy"
count="$(grep -Fxc 'stamp="$(git -C "$ROOT" log -1 --format=%h)" # planted prohibited marker derivation' "$marker_copy" || true)"
if [ "$count" -eq 1 ]; then pass_one; else fail_one "marker plant count want=1 got=$count"; fi
if BACKLOG_ANCHOR_CONTRACT_SKIP_RED=1 bash "$0" "$T/root" > "$T/marker-red.out" 2>&1; then
  fail_one 'commit-marker guard stayed green on planted derivation'
else
  pass_one
fi
cp "$marker_source" "$marker_copy"
if cmp -s "$marker_source" "$marker_copy" && cmp -s "$marker_source" "$T/marker.before"; then
  pass_one
else
  fail_one 'marker fixture/source restore was not byte-exact'
fi
if BACKLOG_ANCHOR_CONTRACT_SKIP_RED=1 bash "$0" "$T/root" >/dev/null 2>&1; then pass_one; else fail_one 'restored marker fixture did not return green'; fi

echo "backlog-anchor-contract-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
