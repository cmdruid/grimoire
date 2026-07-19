#!/usr/bin/env bash
# register-route-drift.sh <skills-root>
#
# Facts, not verdicts: compares every deployed skills/<name>/scripts/register-route.sh
# against skill-builder's own reference copy (register-route.sh, alongside this
# script), and reports whether each is in FUNCTIONAL sync -- comment lines
# stripped first, since each skill's own header comment legitimately differs
# (BL-6: duplication is the correct, self-containment-preserving design; this
# script is what turns "stay in sync by convention" into a checked fact).
#
# Only skills that actually bundle a register-route.sh are compared (durable-home
# tier); a skill with none is not a candidate and is silently skipped.
set -euo pipefail

root="${1:?usage: register-route-drift.sh <skills-root>}"
skills_dir="$root/skills"
self_dir="$(cd "$(dirname "$0")" && pwd)"
own_skill_dir="$(cd "$self_dir/.." && pwd)"
reference="$self_dir/register-route.sh"

[ -f "$reference" ] || { echo "FAIL: no reference register-route.sh at $reference"; exit 1; }
[ -d "$skills_dir" ] || { echo "FAIL: no skills/ under $root"; exit 1; }

ref_body="$(grep -v '^[[:space:]]*#' "$reference")"
checked=0
drift=0

for sk in "$skills_dir"/*/; do
  name="$(basename "$sk")"
  f="$sk/scripts/register-route.sh"
  [ -f "$f" ] || continue
  [ "$(cd "$sk" && pwd)" = "$own_skill_dir" ] && continue   # skip comparing skill-builder's own copy to itself
  checked=$((checked + 1))
  body="$(grep -v '^[[:space:]]*#' "$f")"
  if [ "$body" = "$ref_body" ]; then
    echo "ok: $name"
  else
    drift=$((drift + 1))
    echo "drift: $name (functional body differs from skill-builder's reference copy)"
    diff <(printf '%s\n' "$ref_body") <(printf '%s\n' "$body") | sed 's/^/  /' || true
  fi
done

echo "checked=$checked drift=$drift"
