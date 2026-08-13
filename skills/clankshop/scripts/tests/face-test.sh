#!/usr/bin/env bash
# face-test.sh — the face's own assembly: every verb the SKILL.md router names resolves
# to a real file, every verb file is routed, and the bundled seed passes its own
# contract test (the seed mirrors a deployed .handbook, so context.sh runs in place).
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/clankshop-face-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"

# router rows -> files
for v in setup migrate check persona; do
  [ -f "$SKILL/verbs/$v.md" ] && pass=$((pass + 1)) || { echo "FAIL: router names verbs/$v.md but it is missing" >&2; fail=$((fail + 1)); }
  grep -qF "verbs/$v.md" "$SKILL/SKILL.md" && pass=$((pass + 1)) || { echo "FAIL: SKILL.md does not route verbs/$v.md" >&2; fail=$((fail + 1)); }
done

# files -> router rows (no orphan verbs)
for f in "$SKILL"/verbs/*.md; do
  b="verbs/$(basename "$f")"
  grep -qF "$b" "$SKILL/SKILL.md" && pass=$((pass + 1)) || { echo "FAIL: $b exists but SKILL.md never cites it" >&2; fail=$((fail + 1)); }
done

# scripts the verbs lean on exist and parse
for s in seed.sh migrate-scan.sh; do
  [ -f "$SKILL/scripts/$s" ] && pass=$((pass + 1)) || { echo "FAIL: scripts/$s missing" >&2; fail=$((fail + 1)); }
  bash -n "$SKILL/scripts/$s" && pass=$((pass + 1)) || { echo "FAIL: scripts/$s does not parse" >&2; fail=$((fail + 1)); }
done

# the seed self-checks: context.sh resolves its handbook root as seed/ itself
"$SKILL/seed/scripts/context.sh" --check >"$OUT"
expect "seed's own load sets green" "load sets: OK" "$OUT"

# seed carries no v1 machinery vocabulary
for needle in "spine-doc" "doctrine-version:" "steward:" "skill:.*BEGIN"; do
  if grep -rqE "$needle" "$SKILL/seed"; then
    echo "FAIL: v1 vocabulary '$needle' present in seed/" >&2; fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
done

report "face-test"
