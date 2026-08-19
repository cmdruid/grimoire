#!/usr/bin/env bash
# seed-test.sh — the setup mechanics end to end: seed.sh projects the template doctrine
# into a throwaway repo at <workspace>/doctrine, the deployed context.sh serves and
# self-checks the load sets from its new depth, and every advertised failure mode actually
# fails (proven by breaking).
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
expect "seed reports" "seeded: $proj/.dev/doctrine" "$OUT"
expect "seed self-check green" "load sets: OK" "$OUT"

# layout shape: the four stations + core, exactly as the load rule needs them
for rel in core/POLICY.md core/INVARIANTS.md core/GOTCHAS.md core/ROUTING.md \
           design/POLICY.md build/POLICY.md test/POLICY.md review/POLICY.md \
           scripts/context.sh README.md; do
  [ -f "$proj/.dev/doctrine/$rel" ] && pass=$((pass + 1)) || { echo "FAIL: missing $rel" >&2; fail=$((fail + 1)); }
done

# slots filled, none left behind
expect "gate slot filled" "make test" "$proj/.dev/doctrine/core/INVARIANTS.md"
expect_absent "no unfilled gate slot" "<gate>" "$proj/.dev/doctrine/core/INVARIANTS.md"
expect_absent "no unfilled trunk slot" "<trunk>" "$proj/.dev/doctrine/core/ROUTING.md"

# the one install stamp, with the real date (facts from scripts, never guessed) — version
# read from the manifest the same way seed.sh reads it, so a version bump can't false-fail
pack_version="$(awk '/^---$/{n++; next} n==1 && /^version:/{sub(/^version:[[:space:]]*/, ""); print; exit}' "$SKILL/PACK.md")"
expect "stamp version+date" "Seeded from clankshop v${pack_version} on $(date +%Y-%m-%d)." "$proj/.dev/doctrine/README.md"

# --- deployed context.sh -------------------------------------------------------
ctx="$proj/.dev/doctrine/scripts/context.sh"
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

rm "$proj/.dev/doctrine/core/ROUTING.md"
rc=0; "$ctx" --check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "broken load set rc" "2" "$rc"
expect "broken load set names the file" "missing: core/ROUTING.md" "$ERR"

rc=0; "$SKILL/scripts/seed.sh" "$TMP/nosuchdir" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "bad target rc" "2" "$rc"

# --- relocation: context.sh resolves its own root, so the move is transparent --
# context.sh derives its root from its own install location, which is why the loader stays
# NESTED inside doctrine/ rather than sitting at the workspace level: one directory up from
# `<ws>/doctrine/scripts/` is the doctrine home, and every load-set path resolves. At
# `<ws>/scripts/` the same expression would yield `<ws>/` and every load set would miss.
expect_eq "loader root is the doctrine home" \
  "$(cd "$proj/.dev/doctrine" && pwd)" \
  "$(cd "$(dirname "$ctx")/.." && pwd)"

# --- --workspace: a non-default home -------------------------------------------
alt="$TMP/alt"; mkdir -p "$alt"; git init -q "$alt"
"$SKILL/scripts/seed.sh" "$alt" --workspace .workspace >"$OUT" 2>"$ERR"
expect "custom workspace seeds there" "seeded: $alt/.workspace/doctrine" "$OUT"
expect "custom workspace self-check green" "load sets: OK" "$OUT"
expect "non-default home tells the operator to declare it" "agent-workspace: .workspace" "$OUT"
[ -f "$alt/.workspace/doctrine/core/POLICY.md" ] && pass=$((pass + 1)) \
  || { echo "FAIL: custom workspace missing core/POLICY.md" >&2; fail=$((fail + 1)); }
[ -e "$alt/.dev" ] && { echo "FAIL: custom workspace also created the default .dev/" >&2; fail=$((fail + 1)); } \
  || pass=$((pass + 1))

# ...and the DEFAULT home prints no such note: it needs no declaration, which is the whole
# point of moving the seed to where the resolver already looks.
mkdir -p "$TMP/dflt"
"$SKILL/scripts/seed.sh" "$TMP/dflt" >"$TMP/dflt.out" 2>&1
expect_absent "default home prints no declare note" "agent-workspace:" "$TMP/dflt.out"

# --- proven by breaking: the dual refuse arm -----------------------------------
# RED-PROOF for the pathology this relocation exists to remove. A pre-relocation host still
# has a live `.handbook/`; its `<ws>/doctrine` does NOT exist, so the ordinary refuse arm
# cannot see it. Without the legacy arm, seed.sh would happily build a SECOND doctrine tree
# beside the live one — Problem 3, recreated by the fix.
legacy="$TMP/legacy"; mkdir -p "$legacy/.handbook"; git init -q "$legacy"
[ -e "$legacy/.dev/doctrine" ] && { echo "FAIL: fixture precondition — .dev/doctrine exists" >&2; fail=$((fail + 1)); } || pass=$((pass + 1))
rc=0; "$SKILL/scripts/seed.sh" "$legacy" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "pre-relocation host refused rc" "2" "$rc"
expect "refusal names the legacy tree" "$legacy/.handbook exists" "$ERR"
expect "refusal names the move" "git mv .handbook" "$ERR"
[ -e "$legacy/.dev" ] && { echo "FAIL: refused seed still created .dev/" >&2; fail=$((fail + 1)); } || pass=$((pass + 1))

# --- proven by breaking: the dot-valued workspace -------------------------------
dotp="$TMP/dotp"; mkdir -p "$dotp"; git init -q "$dotp"
rc=0; "$SKILL/scripts/seed.sh" "$dotp" --workspace . >"$OUT" 2>"$ERR" || rc=$?
expect_eq "dot workspace refused rc" "2" "$rc"
expect "dot workspace refusal message" "would place doctrine at ./doctrine" "$ERR"
[ -e "$dotp/doctrine" ] && { echo "FAIL: refused seed still created ./doctrine" >&2; fail=$((fail + 1)); } || pass=$((pass + 1))

rc=0; "$SKILL/scripts/seed.sh" "$dotp" --workspace /abs >"$OUT" 2>"$ERR" || rc=$?
expect_eq "absolute workspace refused rc" "2" "$rc"
expect "absolute workspace refusal message" "must be repo-relative" "$ERR"

report "seed-test"
