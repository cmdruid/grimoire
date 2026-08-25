#!/usr/bin/env bash
# flows-door-test.sh — red-proofs 5, 8–11, 13. Patient-zero: mktemp only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

DOOR="$SKILL/scripts/flows-door.sh"
TMP=$(mktemp -d)
restore() {
  [ -f "$TMP/door.bak" ] && mv "$TMP/door.bak" "$DOOR"
  rm -rf "$TMP"
}
trap restore EXIT
OUT="$TMP/out"
ERR="$TMP/err"

write_agents() {
  local dest="$1"; shift
  mkdir -p "$(dirname "$dest")"
  printf '%s\n' "$@" > "$dest"
}

# --- 5. Door pointer initial --------------------------------------------------
p5="$TMP/p5"
mkdir -p "$p5"
write_agents "$p5/AGENTS.md" \
  '# AGENTS.md' \
  '' \
  'Some existing content.'
rc=0; "$DOOR" apply --root "$p5" --workspace .spaces >"$OUT" 2>"$ERR" || rc=$?
expect_eq "5 apply rc" "0" "$rc"
expect "5 pointer path literal" ".spaces/*/flows/" "$p5/AGENTS.md"
expect "5 pointer sentence" "not loaded until one is selected." "$p5/AGENTS.md"
expect_absent "5 no shopbook in body" "shopbook" "$p5/AGENTS.md"
expect_absent "5 no ROUTING table" "build/workflows" "$p5/AGENTS.md"
expect "5 existing content kept" "Some existing content." "$p5/AGENTS.md"
rc=0; "$DOOR" check --root "$p5" --workspace .spaces >"$OUT" 2>"$ERR" || rc=$?
expect_eq "5 check rc" "0" "$rc"
expect_eq "5 block ok" "ok" "$(fact block "$OUT")"
expect_eq "5 drift false" "false" "$(fact drift "$OUT")"
sum5=$(hash_of "$p5/AGENTS.md")
mkdir -p "$p5/.spaces/shopbook/flows"
printf 'extra\n' > "$p5/.spaces/shopbook/flows/host-only.md"
rc=0; "$DOOR" check --root "$p5" --workspace .spaces >"$OUT" 2>"$ERR" || rc=$?
expect_eq "5 extra dest check rc" "0" "$rc"
expect_eq "5 extra dest drift false" "false" "$(fact drift "$OUT")"
expect_eq "5 extra dest door checksum" "$sum5" "$(hash_of "$p5/AGENTS.md")"

# --- 8. Pointer apply / wrong path -------------------------------------------
p8="$TMP/p8"
mkdir -p "$p8"
write_agents "$p8/AGENTS.md" '# AGENTS.md'
rc=0; "$DOOR" apply --root "$p8" --workspace dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "8 apply rc" "0" "$rc"
expect "8 body contains owner-first glob" "dev/*/flows/" "$p8/AGENTS.md"
expect_absent "8 body has no default workspace" ".spaces/*/flows/" "$p8/AGENTS.md"
rc=0; "$DOOR" check --root "$p8" --workspace dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "8 check rc" "0" "$rc"
awk '
  /pointer_line=/ && /ws\/\*\/flows/ {
    print "pointer_line=\"Project procedures live under \\`.spaces/*/flows/\\` and are not loaded until one is selected.\""
    next
  }
  { print }
' "$DOOR" > "$TMP/door-hardcoded.sh"
chmod +x "$TMP/door-hardcoded.sh"
p8b="$TMP/p8b"
mkdir -p "$p8b"
write_agents "$p8b/AGENTS.md" '# AGENTS.md'
rc=0; bash "$TMP/door-hardcoded.sh" apply --root "$p8b" --workspace dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "8 disabled-sub apply rc" "0" "$rc"
rc=0; bash "$TMP/door-hardcoded.sh" check --root "$p8b" --workspace dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "8 disabled-sub check stays 1" "1" "$rc"

# --- 9. Malformed refuse ------------------------------------------------------
p9="$TMP/p9"
mkdir -p "$p9"
write_agents "$p9/AGENTS.md" \
  '# AGENTS.md' \
  '<!-- flows BEGIN -->' \
  'incomplete'
sum9=$(hash_of "$p9/AGENTS.md")
rc=0; "$DOOR" apply --root "$p9" --workspace .spaces >"$OUT" 2>"$ERR" || rc=$?
expect_eq "9 apply rc (no-op stop)" "0" "$rc"
expect_eq "9 apply writes nothing" "$sum9" "$(hash_of "$p9/AGENTS.md")"
rc=0; "$DOOR" check --root "$p9" --workspace .spaces >"$OUT" 2>"$ERR" || rc=$?
expect_eq "9 check rc" "1" "$rc"
expect_eq "9 block malformed" "malformed" "$(fact block "$OUT")"

# --- 10. No AGENTS.md / claude-only ------------------------------------------
p10="$TMP/p10"
mkdir -p "$p10"
rc=0; "$DOOR" apply --root "$p10" --workspace .spaces >"$OUT" 2>"$ERR" || rc=$?
expect_eq "10 absent apply rc" "0" "$rc"
[ ! -e "$p10/AGENTS.md" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 10 apply created AGENTS.md" >&2; fail=$((fail + 1)); }
[ ! -e "$p10/CLAUDE.md" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 10 apply created CLAUDE.md" >&2; fail=$((fail + 1)); }
rc=0; "$DOOR" check --root "$p10" --workspace .spaces >"$OUT" 2>"$ERR" || rc=$?
expect_eq "10 absent check rc" "1" "$rc"
expect_eq "10 door_class absent" "absent" "$(fact door_class "$OUT")"

p10c="$TMP/p10c"
mkdir -p "$p10c"
printf '# CLAUDE.md\n' > "$p10c/CLAUDE.md"
sum10c=$(hash_of "$p10c/CLAUDE.md")
rc=0; "$DOOR" apply --root "$p10c" --workspace .spaces >"$OUT" 2>"$ERR" || rc=$?
expect_eq "10 claude-only apply rc" "0" "$rc"
[ ! -e "$p10c/AGENTS.md" ] && pass=$((pass + 1)) \
  || { echo "FAIL: 10 claude-only created AGENTS.md" >&2; fail=$((fail + 1)); }
expect_eq "10 CLAUDE.md untouched" "$sum10c" "$(hash_of "$p10c/CLAUDE.md")"
rc=0; "$DOOR" check --root "$p10c" --workspace .spaces >"$OUT" 2>"$ERR" || rc=$?
expect_eq "10 claude-only check rc" "1" "$rc"
expect_eq "10 door_class claude-only" "claude-only" "$(fact door_class "$OUT")"

# --- 11. No oven --------------------------------------------------------------
p11="$TMP/p11"
mkdir -p "$p11"
write_agents "$p11/AGENTS.md" \
  '# AGENTS.md' \
  '<!-- skill:shopbook BEGIN -->' \
  'keep-me' \
  '<!-- skill:shopbook END -->'
rc=0; "$DOOR" apply --root "$p11" --workspace .spaces >"$OUT" 2>"$ERR" || rc=$?
expect_eq "11 apply rc" "0" "$rc"
expect "11 oven span kept" "<!-- skill:shopbook BEGIN -->" "$p11/AGENTS.md"
expect "11 oven body kept" "keep-me" "$p11/AGENTS.md"
expect "11 pointer also present" ".spaces/*/flows/" "$p11/AGENTS.md"
expect "11 oven END kept" "<!-- skill:shopbook END -->" "$p11/AGENTS.md"
sum11b=$(hash_of "$p11/AGENTS.md")
rc=0; "$DOOR" apply --root "$p11" --workspace .spaces >"$OUT" 2>"$ERR" || rc=$?
expect_eq "11 second apply rc" "0" "$rc"
expect_eq "11 second apply checksum" "$sum11b" "$(hash_of "$p11/AGENTS.md")"

report "flows-door-test"
