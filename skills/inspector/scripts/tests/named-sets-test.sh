#!/usr/bin/env bash
# shellcheck disable=SC2016 # Markdown code spans are literal throughout this fixture.
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
REVIEW="$SKILL/verbs/review.md"
ROUTER="$SKILL/SKILL.md"
SETUP="$SKILL/verbs/setup.md"
pass=0 fail=0
has() { if grep -qF -- "$2" "$1"; then pass=$((pass + 1)); else echo "FAIL $3" >&2; fail=$((fail + 1)); fi; }
missing() { if grep -qF -- "$2" "$1"; then echo "FAIL $3" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi; }

has "$ROUTER" '.agents/skilldata/inspector/invariants/<name>.md' "invariant path missing"
has "$ROUTER" '.agents/skilldata/inspector/lenses/<name>.md' "lens path missing"
has "$ROUTER" '[a-z0-9]+(-[a-z0-9]+)*' "kebab name token missing"
has "$ROUTER" 'Default none' "default-none rule missing"
has "$REVIEW" 'Unnamed look-again does not re-attach' "look-again re-attaches named sets"
has "$REVIEW" 'Unknown name → ask' "unknown named set does not ask"
has "$ROUTER" 'never treats `invariants/` or `lenses/`' "kind-detect may treat named sets as kinds"
has "$REVIEW" 'non-blocking note unless' "lens on light is blocking"
has "$SETUP" 'does not create `invariants/` or `lenses/`' "setup still plants named-set dirs"

echo "named-sets-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
