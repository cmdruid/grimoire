#!/usr/bin/env bash
# skill-doc-test.sh — grep gates on the live contractor package.
# Read-only against the skill tree.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

# --- job verbs live in verbs/; SKILL.md does not keep their H2s ---
for v in roadmap plan runbook build; do
  if [ -f "$SKILL/verbs/$v.md" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: missing verbs/$v.md" >&2
    fail=$((fail + 1))
  fi
done

hits=$(grep -E '^## (roadmap|plan|runbook|build) ' "$SKILL/SKILL.md" || true)
if [ -z "$hits" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: SKILL.md still has job-verb H2s:" >&2
  echo "$hits" >&2
  fail=$((fail + 1))
fi

# --- dispatch cites every verb file ---
for v in roadmap plan runbook build; do
  if grep -qF "\`verbs/$v.md\`" "$SKILL/SKILL.md"; then
    pass=$((pass + 1))
  else
    echo "FAIL: SKILL.md does not cite verbs/$v.md" >&2
    fail=$((fail + 1))
  fi
done

# --- plan gate runs this package's ground-check ---
if grep -qF 'scripts/ground-check.sh' "$SKILL/verbs/plan.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: verbs/plan.md does not invoke scripts/ground-check.sh" >&2
  fail=$((fail + 1))
fi

# --- lock-in is plans.md (store-named); plan.md / roadmap.md are body scaffolds ---
if [ -f "$SKILL/templates/plans.md" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: expected templates/plans.md" >&2
  fail=$((fail + 1))
fi
if [ -f "$SKILL/templates/plan.md" ] && [ -f "$SKILL/templates/roadmap.md" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: expected templates/plan.md and templates/roadmap.md body scaffolds" >&2
  fail=$((fail + 1))
fi
if [ ! -e "$SKILL/templates/runbook.md" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: runbook is compiled; expected no templates/runbook.md" >&2
  fail=$((fail + 1))
fi
for f in plans.md plan.md roadmap.md; do
  if grep -qF -- "- \`$f\`" "$SKILL/SKILL.md"; then
    pass=$((pass + 1))
  else
    echo "FAIL: Project templates list does not name $f" >&2
    fail=$((fail + 1))
  fi
done
if grep -qF 'Never deploy `plan.md`' "$SKILL/SKILL.md" \
  && grep -qF '*as* `plans.md`' "$SKILL/SKILL.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: SKILL.md dropped the never-deploy-as-plans.md rule" >&2
  fail=$((fail + 1))
fi

# --- status vocabulary is complete in-package, with no library-only path ---
if grep -qF 'Mint stays `draft`' "$SKILL/SKILL.md" \
  && grep -qF '`published` and `stage: approved`' "$SKILL/SKILL.md" \
  && grep -qF '`stage: implemented`' "$SKILL/SKILL.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: SKILL.md does not carry the complete status/stage vocabulary" >&2
  fail=$((fail + 1))
fi
if grep -qF 'specs/records-front-matter.md' "$SKILL/SKILL.md"; then
  echo "FAIL: standalone contractor package cites a library-only specs path" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
hits=$(grep -n '[Jj]ournal' "$SKILL/SKILL.md" "$SKILL"/verbs/*.md || true)
if [ -z "$hits" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: contractor still names Journal:" >&2
  echo "$hits" >&2
  fail=$((fail + 1))
fi

# --- router completeness ---
if grep -qE '^## Done when' "$SKILL/SKILL.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: SKILL.md has no ## Done when" >&2
  fail=$((fail + 1))
fi
if grep -qE '^## Structure, portability' "$SKILL/SKILL.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: SKILL.md has no ## Structure, portability" >&2
  fail=$((fail + 1))
fi

# --- runbook lands once: a numbered Land-it step, no trailing second mint ---
if grep -qE '^[0-9]+\. \*\*Land it\*\*' "$SKILL/verbs/runbook.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: verbs/runbook.md has no numbered Land-it step" >&2
  fail=$((fail + 1))
fi
hits=$(grep -nE '^Land it per SKILL.md' "$SKILL/verbs/runbook.md" || true)
if [ -z "$hits" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: verbs/runbook.md still has an unnumbered trailing Land-it:" >&2
  echo "$hits" >&2
  fail=$((fail + 1))
fi

# --- bare slash asks ---
if grep -qE '\*\*ask\*\* which verb' "$SKILL/SKILL.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: SKILL.md dropped the bare-slash ask" >&2
  fail=$((fail + 1))
fi

finish
