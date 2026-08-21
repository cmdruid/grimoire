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

HANDOFF_TPL="$(cd "$DIR/../.." && pwd)/templates/workstream-handoff.md"
CREATE_MD="$(cd "$DIR/../.." && pwd)/verbs/create.md"
count_h2() { grep -cE '^## Hooks \(compiled\)' "$1" || true; }

# --- 2. Filled body compiles into --handoff ----------------------------------
filled="$TMP/filled.md"
printf '%s\n' '# workstream hooks' '' \
  '## Feature completion' '' \
  '/backlog debrief' '' \
  '## After eventful ship' >"$filled"
rc=0; parse "$filled" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "2 parse filled rc" "0" "$rc"
expect_eq "2 hook_feature_completion filled" "filled" "$(fact hook_feature_completion "$OUT")"
ho2="$TMP/handoff-2.md"
cp "$HANDOFF_TPL" "$ho2"
rc=0; "$HOOKS_SH" compile --file "$filled" --handoff "$ho2" "${KNOWN[@]}" \
  >"$OUT" 2>"$ERR" || rc=$?
expect_eq "2 compile rc" "0" "$rc"
"$HOOKS_SH" compiled-get --handoff "$ho2" >"$OUT"
expect "2 compiled inlines Feature completion body" "/backlog debrief" "$OUT"
expect "2 compiled lists after-eventful-ship (empty)" "after-eventful-ship:" "$OUT"
expect "2 compiled (empty) sibling" "(empty)" "$OUT"
expect "2 Delegation route survives" "## Delegation route" "$ho2"
expect_eq "2 exactly one compiled H2" "1" "$(count_h2 "$ho2")"

# --- 7. Stamp-fill deletion; empty compile stays (empty) ---------------------
create_hits=$(grep -cF 'Seeded from clankshop' "$CREATE_MD" || true)
expect_eq "7 create.md Seeded-from count is 0" "0" "$create_hits"
ho7="$TMP/handoff-7.md"
cp "$HANDOFF_TPL" "$ho7"
rc=0; "$HOOKS_SH" compile --file "$empty" --handoff "$ho7" "${KNOWN[@]}" \
  >"$OUT" 2>"$ERR" || rc=$?
expect_eq "7 empty compile rc" "0" "$rc"
"$HOOKS_SH" compiled-get --handoff "$ho7" >"$OUT"
expect "7 empty feature-completion" "feature-completion:" "$OUT"
expect "7 empty bodies are (empty)" "(empty)" "$OUT"
expect_absent "7 no /backlog debrief in compiled span" "/backlog debrief" "$OUT"
# Disable: restore a fill paragraph on a COPY; count ≥1. Original stays 0.
cp "$CREATE_MD" "$TMP/create-restored.md"
printf '\nStamp present → Seeded from clankshop fill.\n' >> "$TMP/create-restored.md"
restored_hits=$(grep -cF 'Seeded from clankshop' "$TMP/create-restored.md" || true)
if [ "$restored_hits" -ge 1 ]; then
  pass=$((pass + 1))
else
  echo "FAIL: 7 restored fill paragraph count was $restored_hits" >&2
  fail=$((fail + 1))
fi
expect_eq "7 original create.md still 0 after copy restore" "0" \
  "$(grep -cF 'Seeded from clankshop' "$CREATE_MD" || true)"

# --- 9. In-place compile target ----------------------------------------------
tmp_root="$TMP/inplace-root"
mkdir -p "$tmp_root/.workstreams/demo"
ho9="$tmp_root/.workstreams/demo/WORKSTREAM.md"
cp "$HANDOFF_TPL" "$ho9"
hooks9="$tmp_root/.dev/hooks/workstream.md"
mkdir -p "$tmp_root/.dev/hooks"
cp "$SKELETON" "$hooks9"
rc=0; "$HOOKS_SH" compile --file "$hooks9" --handoff "$ho9" --root "$tmp_root" \
  "${KNOWN[@]}" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "9 in-place compile rc" "0" "$rc"
expect "9 compiled span at this hand-off" "## Hooks (compiled)" "$ho9"
expect "9 rel path under --root" "hooks-compiled: .dev/hooks/workstream.md @" "$ho9"
[ ! -e "$tmp_root/WORKSTREAM.md" ] && pass=$((pass + 1)) || {
  echo "FAIL: 9 planted <root>/WORKSTREAM.md" >&2; fail=$((fail + 1)); }

# --- 10. Preserve compiled-put after template rewrite ------------------------
ho10="$TMP/handoff-10.md"
cp "$HANDOFF_TPL" "$ho10"
rc=0; "$HOOKS_SH" compile --file "$filled" --handoff "$ho10" "${KNOWN[@]}" \
  >"$OUT" 2>"$ERR" || rc=$?
expect_eq "10 compile rc" "0" "$rc"
"$HOOKS_SH" compiled-get --handoff "$ho10" >"$TMP/span-10"
pre10=$(hash_of "$TMP/span-10")
cp "$HANDOFF_TPL" "$ho10"
"$HOOKS_SH" compiled-put --handoff "$ho10" <"$TMP/span-10"
"$HOOKS_SH" compiled-get --handoff "$ho10" >"$TMP/span-10-after"
expect_eq "10 span byte-identical after put" "$pre10" "$(hash_of "$TMP/span-10-after")"
expect "10 Delegation route after put" "## Delegation route" "$ho10"
expect_eq "10 exactly one compiled H2 after put" "1" "$(count_h2 "$ho10")"
expect "10 filled body survived put" "/backlog debrief" "$TMP/span-10-after"

before=$(grep -cF 'COMPILED_PUT_SITE' "$HOOKS_SH" || true)
expect_eq "10 compiled-put site present" "1" "$before"
cutput="$TMP/hooks-noput.sh"
sed -e 's/^  COMPILED_PUT=1/  COMPILED_PUT=0/' "$HOOKS_SH" >"$cutput"
chmod +x "$cutput"
ho10b="$TMP/handoff-10-disable.md"
cp "$HANDOFF_TPL" "$ho10b"
"$HOOKS_SH" compile --file "$filled" --handoff "$ho10b" "${KNOWN[@]}" >/dev/null
cp "$HANDOFF_TPL" "$ho10b"
"$cutput" compiled-put --handoff "$ho10b" <"$TMP/span-10"
expect_absent "10 disable put loses filled body" "/backlog debrief" "$ho10b"
expect_eq "10 hooks.sh unchanged after disable copy" "$orig_sum" "$(hash_of "$HOOKS_SH")"

# --- 10b. Empty put is no-op -------------------------------------------------
ho_empty_put="$TMP/handoff-10b.md"
cp "$HANDOFF_TPL" "$ho_empty_put"
: | "$HOOKS_SH" compiled-put --handoff "$ho_empty_put"
expect_eq "10b empty put on placeholder: one compiled H2" "1" \
  "$(count_h2 "$ho_empty_put")"
expect "10b Delegation route after empty put" "## Delegation route" "$ho_empty_put"

ho_no_span="$TMP/handoff-10b-none.md"
# Strip any compiled heading from a copy so the span is absent.
awk '
  $0 ~ /^##[ \t]+Hooks \(compiled\)/ { skip=1; next }
  skip && $0 ~ /^##[ \t]+[^ \t]/ { skip=0 }
  skip { next }
  { print }
' "$HANDOFF_TPL" >"$ho_no_span"
expect_eq "10b stripped copy has no compiled H2" "0" "$(count_h2 "$ho_no_span")"
: | "$HOOKS_SH" compiled-put --handoff "$ho_no_span"
expect_eq "10b empty put on absent span adds none" "0" "$(count_h2 "$ho_no_span")"

report "hooks-test.sh"
