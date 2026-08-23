#!/usr/bin/env bash
# skill-doc-test.sh — grep gates on the live architect package.
# Read-only against the skill tree.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

# --- spine verbs live in verbs/; SKILL.md does not keep their H2s ---
for v in brainstorm grill spec; do
  if [ -f "$SKILL/verbs/$v.md" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: missing verbs/$v.md" >&2
    fail=$((fail + 1))
  fi
done

hits=$(grep -E '^## (brainstorm|grill|spec) ' "$SKILL/SKILL.md" || true)
if [ -z "$hits" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: SKILL.md still has spine verb H2s:" >&2
  echo "$hits" >&2
  fail=$((fail + 1))
fi

# --- dispatch cites every verb file (lint check 6 coverage) ---
for v in brainstorm grill spec new deploy; do
  if grep -qF "\`verbs/$v.md\`" "$SKILL/SKILL.md"; then
    pass=$((pass + 1))
  else
    echo "FAIL: SKILL.md does not cite verbs/$v.md" >&2
    fail=$((fail + 1))
  fi
done

# --- spec self-review runs this package's ground-check ---
if grep -qF 'scripts/ground-check.sh' "$SKILL/verbs/spec.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: verbs/spec.md does not invoke scripts/ground-check.sh" >&2
  fail=$((fail + 1))
fi

# --- lock-in template is specs.md (store-named; not spec.md) ---
if [ -f "$SKILL/templates/specs.md" ] && [ ! -e "$SKILL/templates/spec.md" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: expected templates/specs.md and no templates/spec.md" >&2
  fail=$((fail + 1))
fi
if grep -qF -- '- `specs.md`' "$SKILL/SKILL.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: Project templates list does not name specs.md" >&2
  fail=$((fail + 1))
fi

# --- no design.md stub changelog ---
hits=$(grep -n 'design.md was a front-matter' "$SKILL/SKILL.md" || true)
if [ -z "$hits" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: SKILL.md still carries the design.md stub footnote:" >&2
  echo "$hits" >&2
  fail=$((fail + 1))
fi

# --- description is trigger, not process summary ---
desc=$(awk 'BEGIN{p=0} /^---$/{c++; next} c==1 && /^description:/{p=1} c>=2{exit} p{print}' "$SKILL/SKILL.md")
if printf '%s' "$desc" | grep -qE 'Turns an idea|grill is the interview primitive'; then
  echo "FAIL: description still summarizes the process:" >&2
  echo "$desc" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

finish
