#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$HERE/../.." && pwd)"
pass=0
fail=0

ok(){ pass=$((pass + 1)); }
bad(){ echo "FAIL: $*" >&2; fail=$((fail + 1)); }

class_hits(){
  local root="$1" class="$2" pattern
  case "$class" in
    spawn) pattern='Task tool|codex exec --model' ;;
    return) pattern='## Deliverable|## Byproducts|DONE_WITH_CONCERNS' ;;
    model) pattern='/delegate[^[:cntrl:]]*(model-routing table|per-phase model map)|model-matched pieces.*mailbox' ;;
    provider) pattern='rate-limit/5xx/timeout|quota/limit/unavailable|fallback ladder' ;;
    *) return 2 ;;
  esac
  rg -n "$pattern" \
    "$root/SKILL.md" \
    "$root/flow.md" \
    "$root/verbs/create.md" \
    "$root/verbs/load.md" \
    "$root/templates/workstream-handoff.md"
}

contract_ok(){
  local root="$1" class
  grep -q 'submit each suitable bounded work-unit to' "$root/flow.md" &&
    grep -q 'validate its returned result' "$root/flow.md" &&
    grep -q 'execute that' "$root/flow.md" &&
    grep -q 'unit inline' "$root/flow.md" &&
    grep -q 'main session is the sole writer' "$root/templates/workstream-handoff.md" &&
    grep -q 'Pre-confirm the phase model map' "$root/verbs/create.md" &&
    grep -q '/delegate.*worktree' "$root/SKILL.md" || return 1
  for class in spawn return model provider; do
    if class_hits "$root" "$class" >/dev/null; then return 1; fi
  done
}

if contract_ok "$SKILL"; then ok; else bad 'live Workstream seam contract'; fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/workstream-seam.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
fixture="$tmp/workstream"
cp -R "$SKILL" "$fixture"
target="$fixture/flow.md"
cp "$target" "$tmp/flow.before"

classes=(spawn return model provider)
plants=(
  'Spawn mechanism: use the Task tool.'
  'Return protocol: ## Deliverable / ## Status / ## Byproducts.'
  "Use /delegate's model-routing table."
  'Fallback ladder: rate-limit/5xx/timeout then quota/limit/unavailable.'
)

for i in "${!classes[@]}"; do
  class="${classes[$i]}"
  plant="${plants[$i]}"
  printf '\n%s\n' "$plant" >> "$target"
  count="$(grep -R -F -x "$plant" "$fixture/SKILL.md" "$fixture/flow.md" "$fixture/verbs" "$fixture/templates" | wc -l | tr -d ' ')"
  if [ "$count" = 1 ]; then ok; else bad "$class plant count was $count"; fi
  if class_hits "$fixture" "$class" >/dev/null && ! contract_ok "$fixture"; then
    ok
  else
    bad "$class guard stayed green"
  fi
  cp "$tmp/flow.before" "$target"
  if cmp -s "$tmp/flow.before" "$target"; then ok; else bad "$class restore drifted"; fi
  if contract_ok "$fixture"; then ok; else bad "$class restored fixture stayed red"; fi
done

echo "seam-contract-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
