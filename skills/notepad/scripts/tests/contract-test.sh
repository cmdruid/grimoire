#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/../.." && pwd)"
pass=0
fail=0

ok(){ pass=$((pass + 1)); }
bad(){ echo "FAIL: $*" >&2; fail=$((fail + 1)); }

contract_ok(){
  local doc="$1/SKILL.md"
  grep -q '^- produces: note ' "$doc" &&
    grep -q '^- handoff: — ' "$doc" &&
    grep -q 'write-only sweeps return .*path=.* / .*rel=.* inline to their caller' "$doc" &&
    grep -q '^- consumes: note ' "$doc" &&
    ! grep -q '^- handoff: note' "$doc"
}

if contract_ok "$SKILL"; then ok; else bad 'live Notepad edge contract'; fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/notepad-contract.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
fixture="$tmp/notepad"
cp -R "$SKILL" "$fixture"
cp "$fixture/SKILL.md" "$tmp/SKILL.before"
plant='- handoff: note — write-only sweep: skip scoped-commit; return path= / rel='
printf '\n%s\n' "$plant" >> "$fixture/SKILL.md"
count="$(grep -cFx -- "$plant" "$fixture/SKILL.md")"
if [ "$count" = 1 ]; then ok; else bad "old-handoff plant count was $count"; fi
if contract_ok "$fixture"; then bad 'old-handoff guard stayed green'; else ok; fi
cp "$tmp/SKILL.before" "$fixture/SKILL.md"
if cmp -s "$tmp/SKILL.before" "$fixture/SKILL.md"; then ok; else bad 'fixture restore drifted'; fi
if contract_ok "$fixture"; then ok; else bad 'restored Notepad contract stayed red'; fi

echo "contract-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
