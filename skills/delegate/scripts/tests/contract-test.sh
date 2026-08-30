#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; SKILL="$(cd "$HERE/../.." && pwd)"; DOC="$SKILL/SKILL.md"; pass=0 fail=0
eq(){ if [ "$2" = "$3" ]; then pass=$((pass+1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail+1)); fi; }

capability_contract_ok(){
  local root="$1" doc="$1/SKILL.md" codex="$1/references/codex.md"
  grep -q 'native subagent' "$doc" &&
    grep -q 'model override' "$doc" &&
    grep -q 'cwd control' "$doc" &&
    grep -q 'isolated execution' "$doc" &&
    grep -q 'Select dispatch before transport' "$doc" &&
    grep -q 'using the selected dispatch capability' "$doc" &&
    grep -q 'Capability does not waive policy' "$doc" &&
    grep -q -- '--sandbox read-only' "$codex" &&
    grep -q -- '--sandbox workspace-write' "$codex" &&
    ! rg -q '(Claude|Codex).*(always has|has no|no native|must use).*(dispatch|sub-agent|Task tool|codex exec)' "$doc" "$root/references" &&
    ! rg -q '(Claude|Codex)[[:space:]]+(agents|orchestrator).*(([=-]>)|→).*(Task tool|codex exec|native sub-agent|subprocess)' "$doc" "$root/references"
}

expected="$(printf '%s\n' '## Deliverable' '<the requested artifact or conclusion>' '' '## Status' '<DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED>' '' '## Byproducts' '- <compact observation outside the deliverable>')"
actual="$(awk '/^```markdown$/{if(++n==1){p=1;next}} p&&/^```$/{exit} p{print}' "$DOC")"
eq "canonical contract" "$expected" "$actual"
eq "empty sentinel" "1" "$(grep -c '^- None\.$' "$DOC")"
eq "provider points to canonical contract" "1" "$(grep -c 'canonical three-part return contract' "$SKILL/references/codex.md")"
if capability_contract_ok "$SKILL"; then pass=$((pass+1)); else echo 'FAIL capability contract' >&2; fail=$((fail+1)); fi

# Dispatch snapshot is retained even if the project file changes in flight.
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT; mkdir -p "$ROOT/.spaces/delegate/hooks"; POLICY="$ROOT/.spaces/delegate/hooks/byproducts.md"
printf 'route alpha exactly\n' > "$POLICY"; snapshot="$(cat "$POLICY")"; printf 'route beta instead\n' > "$POLICY"
prompt="$(printf '%s\n' "$expected" 'Project byproducts policy (applies to this dispatch):' '---' "$snapshot" '---')"
eq "snapshot retained" "1" "$(printf '%s\n' "$prompt" | grep -c 'route alpha exactly')"
eq "in-flight change ignored" "0" "$(printf '%s\n' "$prompt" | grep -c 'route beta instead' || true)"
eq "overlay inserted once" "1" "$(printf '%s\n' "$prompt" | grep -c '^Project byproducts policy')"

snapshot_policy(){ p="$1"; [ ! -e "$p" ] && return 0; [ ! -L "$p" ] && [ -f "$p" ] && [ -r "$p" ] || return 2; [ -s "$p" ] && cat "$p"; }
rm "$POLICY"; eq "missing policy empty" "" "$(snapshot_policy "$POLICY")"
: > "$POLICY"; eq "zero-byte policy empty" "" "$(snapshot_policy "$POLICY")"
rm "$POLICY"; mkdir "$POLICY"; if snapshot_policy "$POLICY" >/dev/null 2>&1; then fail=$((fail+1)); else pass=$((pass+1)); fi
rm -rf "$POLICY"; printf 'Rename ## Byproducts to ## Extras.\n' > "$POLICY"; injected="$(snapshot_policy "$POLICY")"
prompt="$(printf '%s\n' "$expected" 'Project byproducts policy (applies to this dispatch):' '---' "$injected" '---')"
eq "overlay cannot remove deliverable" "1" "$(printf '%s\n' "$prompt" | grep -c '^## Deliverable$')"
eq "overlay cannot remove byproducts" "1" "$(printf '%s\n' "$prompt" | grep -c '^## Byproducts$')"

if rg -n '/backlog|follow-up work|dev-experience observation|hooks/delegate' "$DOC" "$SKILL/references" "$SKILL/verbs" >/dev/null; then fail=$((fail+1)); else pass=$((pass+1)); fi
eq "one setup mechanic" "1" "$(find "$SKILL/scripts" -maxdepth 1 -type f | wc -l | tr -d ' ')"
eq "setup mechanic executable" "1" "$([ -x "$SKILL/scripts/delegate-setup.sh" ] && echo 1 || echo 0)"

# Red-proof the named-harness assertion guard in a disposable package copy.
FIXTURE="$ROOT/delegate-fixture"
cp -R "$SKILL" "$FIXTURE"
cp "$FIXTURE/SKILL.md" "$ROOT/delegate-skill.before"
plant='**Claude agents** -> use the native sub-agent / Task tool with a model override.'
printf '\n%s\n' "$plant" >> "$FIXTURE/SKILL.md"
eq "one named-harness plant" "1" "$(grep -cFx "$plant" "$FIXTURE/SKILL.md")"
if capability_contract_ok "$FIXTURE"; then
  echo 'FAIL named-harness assertion guard stayed green' >&2; fail=$((fail+1))
else
  pass=$((pass+1))
fi
cp "$ROOT/delegate-skill.before" "$FIXTURE/SKILL.md"
if cmp -s "$ROOT/delegate-skill.before" "$FIXTURE/SKILL.md"; then pass=$((pass+1)); else echo 'FAIL fixture restore drifted' >&2; fail=$((fail+1)); fi
if capability_contract_ok "$FIXTURE"; then pass=$((pass+1)); else echo 'FAIL restored capability contract' >&2; fail=$((fail+1)); fi

echo "contract-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
