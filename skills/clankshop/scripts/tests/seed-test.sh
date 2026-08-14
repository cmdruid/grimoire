#!/usr/bin/env bash
# seed-test.sh — the setup mechanics end to end: seed.sh projects the template handbook
# into a throwaway repo, the deployed context.sh serves and self-checks the load sets,
# and every advertised failure mode actually fails (proven by breaking).
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/clankshop-seed-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

proj="$TMP/proj"
mkdir -p "$proj"
git init -q "$proj"

# --- greenfield seed -----------------------------------------------------------
"$SKILL/scripts/seed.sh" "$proj" --gate 'make test' --trunk main >"$OUT" 2>"$ERR"
expect "seed reports" "seeded: $proj/.handbook" "$OUT"
expect "seed self-check green" "load sets: OK" "$OUT"

# layout shape: the four stations + core, exactly as the load rule needs them
for rel in core/POLICY.md core/INVARIANTS.md core/GOTCHAS.md core/ROUTING.md \
           design/POLICY.md build/POLICY.md test/POLICY.md review/POLICY.md \
           scripts/context.sh README.md; do
  [ -f "$proj/.handbook/$rel" ] && pass=$((pass + 1)) || { echo "FAIL: missing $rel" >&2; fail=$((fail + 1)); }
done

# slots filled, none left behind
expect "gate slot filled" "make test" "$proj/.handbook/core/INVARIANTS.md"
expect_absent "no unfilled gate slot" "<gate>" "$proj/.handbook/core/INVARIANTS.md"
expect_absent "no unfilled trunk slot" "<trunk>" "$proj/.handbook/core/ROUTING.md"

# the one install stamp, with the real date (facts from scripts, never guessed) — version
# read from the manifest the same way seed.sh reads it, so a version bump can't false-fail
pack_version="$(awk '/^---$/{n++; next} n==1 && /^version:/{sub(/^version:[[:space:]]*/, ""); print; exit}' "$SKILL/PACK.md")"
expect "stamp version+date" "Seeded from clankshop v${pack_version} on $(date +%Y-%m-%d)." "$proj/.handbook/README.md"

# --- deployed context.sh -------------------------------------------------------
ctx="$proj/.handbook/scripts/context.sh"
"$ctx" build --list >"$OUT"
expect "list order: core first" "core/POLICY.md" "$OUT"
expect "list order: station last" "build/POLICY.md" "$OUT"
expect_eq "load set is 5 files" "5" "$(wc -l < "$OUT" | tr -d ' ')"

"$ctx" foreman --list >"$ERR"
expect_eq "persona alias = station" "$(cat "$OUT")" "$(cat "$ERR")"

"$ctx" guardian >"$OUT"
expect "render headers" "===> test/POLICY.md" "$OUT"
expect "render content" "You are the guardian." "$OUT"

# --- proven by breaking --------------------------------------------------------
rc=0; "$SKILL/scripts/seed.sh" "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "re-seed refused rc" "2" "$rc"
expect "re-seed refusal message" "refusing" "$ERR"

rc=0; "$ctx" nosuchstation >"$OUT" 2>"$ERR" || rc=$?
expect_eq "bad station rc" "1" "$rc"

rm "$proj/.handbook/core/ROUTING.md"
rc=0; "$ctx" --check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "broken load set rc" "2" "$rc"
expect "broken load set names the file" "missing: core/ROUTING.md" "$ERR"

rc=0; "$SKILL/scripts/seed.sh" "$TMP/nosuchdir" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "bad target rc" "2" "$rc"

report "seed-test"
