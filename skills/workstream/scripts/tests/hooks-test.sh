#!/usr/bin/env bash
# hooks-test.sh — red-proofs 1, 3, 4, 5 plus missing-file / fence / materialize cwd.
# Patient-zero: fixtures in mktemp only. Never touch the library tree.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

HOOKS_SH="$(cd "$DIR/.." && pwd)/hooks.sh"
SKELETON="$(cd "$DIR/../.." && pwd)/templates/hooks.md"
KNOWN=(--known "feature-completion=Feature completion" --known "after-eventful-ship=After eventful ship")

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"
ERR="$TMP/err"

parse() { # parse <file>
  "$HOOKS_SH" parse --file "$1" "${KNOWN[@]}"
}

fact() { # fact <key> <file>
  sed -n -E "s/^$1=//p" "$2" | head -n 1
}

hash_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

# --- 1. Empty parse ----------------------------------------------------------
empty="$TMP/empty.md"
cp "$SKELETON" "$empty"
rc=0; parse "$empty" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "1 empty parse rc" "0" "$rc"
expect_eq "1 hook_feature_completion empty" "empty" "$(fact hook_feature_completion "$OUT")"
expect_eq "1 hook_after_eventful_ship empty" "empty" "$(fact hook_after_eventful_ship "$OUT")"
h=$(fact hash "$OUT")
if [ -n "$h" ] && [ "$h" != none ]; then
  pass=$((pass + 1))
else
  echo "FAIL: 1 hash nonempty — got: $h" >&2
  fail=$((fail + 1))
fi
expect_eq "1 status ok" "ok" "$(fact status "$OUT")"

# Whitespace-only body is empty after strip; disable strip → filled.
wsbody="$TMP/ws.md"
printf '%s\n' '# workstream hooks' '' 'Empty section = no extra glue command.' '' \
  '## Feature completion' ' ' '## After eventful ship' >"$wsbody"
rc=0; parse "$wsbody" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "1 whitespace body rc" "0" "$rc"
expect_eq "1 whitespace body is empty after strip" "empty" "$(fact hook_feature_completion "$OUT")"

before=$(grep -cF 'STRIP_WS_SITE' "$HOOKS_SH" || true)
expect_eq "1 strip site present before disable" "1" "$before"
orig_sum=$(hash_of "$HOOKS_SH")
cutsh="$TMP/hooks-nostrip.sh"
cp "$HOOKS_SH" "$cutsh"
chmod +x "$cutsh"
# Disable the strip: identity fallback.
sed -e 's/^STRIP_WS=1/STRIP_WS=0/' "$HOOKS_SH" >"$cutsh"
chmod +x "$cutsh"
after=$(grep -cF 'STRIP_WS=1' "$cutsh" || true)
expect_eq "1 strip disabled (STRIP_WS=1 gone)" "0" "$after"
rc=0; "$cutsh" parse --file "$wsbody" "${KNOWN[@]}" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "1 disabled-strip rc" "0" "$rc"
expect_eq "1 whitespace body is filled without strip" "filled" "$(fact hook_feature_completion "$OUT")"
# Restore is the original file (we mutated a copy).
after_sum=$(hash_of "$HOOKS_SH")
expect_eq "1 hooks.sh byte-identical after restore" "$orig_sum" "$after_sum"

# --- 1b. --file missing ------------------------------------------------------
rc=0; parse "$TMP/no-such-hooks.md" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "1b missing rc" "0" "$rc"
expect_eq "1b status missing" "missing" "$(fact status "$OUT")"
expect_eq "1b hash none" "none" "$(fact hash "$OUT")"
expect_eq "1b keys empty" "empty" "$(fact hook_feature_completion "$OUT")"

before=$(grep -cF 'MISSING_FILE_BRANCH' "$HOOKS_SH" || true)
expect_eq "1b missing-file branch present" "1" "$before"
cp "$HOOKS_SH" "$cutsh"
sed -e 's/^  HANDLE_MISSING=1/  HANDLE_MISSING=0/' "$HOOKS_SH" >"$cutsh"
chmod +x "$cutsh"
after=$(grep -cF 'MISSING_FILE_BRANCH' "$cutsh" || true)
expect_eq "1b marker still in copy (assignment flipped)" "$before" "$after"
rc=0; "$cutsh" parse --file "$TMP/no-such-hooks.md" "${KNOWN[@]}" >"$OUT" 2>"$ERR" || rc=$?
if [ "$rc" -ne 0 ]; then
  pass=$((pass + 1))
else
  st=$(fact status "$OUT")
  if [ "$st" = missing ]; then
    echo "FAIL: 1b disabled missing-file still reported status=missing rc=0" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
fi
expect_eq "1b hooks.sh byte-identical after restore" "$orig_sum" "$(hash_of "$HOOKS_SH")"

# --- 3. Duplicate H2 ---------------------------------------------------------
dup="$TMP/dup.md"
printf '%s\n' '# workstream hooks' '' \
  '## Feature completion' '' \
  '## Feature completion' '' \
  '## After eventful ship' >"$dup"
rc=0; parse "$dup" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "3 duplicate rc" "2" "$rc"
expect_eq "3 status fail" "fail" "$(fact status "$OUT")"

# --- 4. Unknown H2 -----------------------------------------------------------
unk="$TMP/unk.md"
printf '%s\n' '# workstream hooks' '' \
  '## Feature completion' '' \
  '## Other' '' \
  '## After eventful ship' >"$unk"
rc=0; parse "$unk" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "4 unknown rc" "0" "$rc"
expect_eq "4 unknown=Other" "Other" "$(fact unknown "$OUT")"
expect_eq "4 known still empty" "empty" "$(fact hook_feature_completion "$OUT")"
expect_eq "4 sibling still empty" "empty" "$(fact hook_after_eventful_ship "$OUT")"

unk2="$TMP/unk2.md"
printf '%s\n' '# workstream hooks' '' \
  '## Feature completion' '' \
  '## Other' '' \
  '## Extra' '' \
  '## After eventful ship' >"$unk2"
rc=0; parse "$unk2" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "4 two extras rc" "0" "$rc"
expect_eq "4 unknown=Other,Extra" "Other,Extra" "$(fact unknown "$OUT")"

# --- 4b. Fenced ## Other is not unknown --------------------------------------
fenced="$TMP/fenced.md"
printf '%s\n' '# workstream hooks' '' \
  '```' '## Other' '```' '' \
  '## Feature completion' '' \
  '## After eventful ship' >"$fenced"
rc=0; parse "$fenced" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "4b fenced rc" "0" "$rc"
expect_eq "4b unknown empty" "" "$(fact unknown "$OUT")"
expect_eq "4b status ok not fail" "ok" "$(fact status "$OUT")"

# --- 5. Overwrite refuse from a foreign cwd ----------------------------------
plant="$TMP/project/hooks"
mkdir -p "$plant"
planted="$plant/workstream.md"
printf '%s\n' '# workstream hooks' '' \
  '## Feature completion' '' \
  'do-not-clobber' '' \
  '## After eventful ship' >"$planted"
sum_before=$(hash_of "$planted")
fake="$TMP/fake-worktree"
mkdir -p "$fake"
rc=0
(
  cd "$fake" || exit 1
  "$HOOKS_SH" materialize --file "$planted" --skeleton "$SKELETON"
) >"$OUT" 2>"$ERR" || rc=$?
expect_eq "5 materialize present rc" "0" "$rc"
expect_eq "5 status present" "present" "$(fact status "$OUT")"
expect_eq "5 checksum unchanged" "$sum_before" "$(hash_of "$planted")"

# Created from a foreign cwd when parent exists and file is absent.
created_parent="$TMP/project2/hooks"
mkdir -p "$created_parent"
created="$created_parent/workstream.md"
rc=0
(
  cd "$fake" || exit 1
  "$HOOKS_SH" materialize --file "$created" --skeleton "$SKELETON"
) >"$OUT" 2>"$ERR" || rc=$?
expect_eq "5 created rc" "0" "$rc"
expect_eq "5 status created" "created" "$(fact status "$OUT")"
[ -f "$created" ] && pass=$((pass + 1)) || {
  echo "FAIL: 5 created file missing" >&2; fail=$((fail + 1)); }
rc=0; parse "$created" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "5 created parse rc" "0" "$rc"
expect_eq "5 created keys empty" "empty" "$(fact hook_feature_completion "$OUT")"
expect_eq "5 created sibling empty" "empty" "$(fact hook_after_eventful_ship "$OUT")"

# --- 5b. Relative --file -----------------------------------------------------
rc=0
(
  cd "$fake" || exit 1
  "$HOOKS_SH" materialize --file hooks/workstream.md --skeleton "$SKELETON"
) >"$OUT" 2>"$ERR" || rc=$?
expect_eq "5b relative hooks/ rc" "2" "$rc"
rc=0
(
  cd "$fake" || exit 1
  "$HOOKS_SH" materialize --file .dev/hooks/workstream.md --skeleton "$SKELETON"
) >"$OUT" 2>"$ERR" || rc=$?
expect_eq "5b relative .dev/hooks/ rc" "2" "$rc"

# --- 5c. Parent missing, no mkdir --------------------------------------------
missing_parent="$TMP/no-such-home/hooks/workstream.md"
rc=0; "$HOOKS_SH" materialize --file "$missing_parent" --skeleton "$SKELETON" \
  >"$OUT" 2>"$ERR" || rc=$?
expect_eq "5c no-parent rc" "0" "$rc"
expect_eq "5c status no-parent" "no-parent" "$(fact status "$OUT")"
[ ! -d "$TMP/no-such-home" ] && pass=$((pass + 1)) || {
  echo "FAIL: 5c created missing parent directory" >&2; fail=$((fail + 1)); }

# compile stubs exit 2
rc=0; "$HOOKS_SH" compile --file "$empty" --handoff "$TMP/h.md" "${KNOWN[@]}" \
  >"$OUT" 2>"$ERR" || rc=$?
expect_eq "compile stub rc" "2" "$rc"

report "hooks-test.sh"
