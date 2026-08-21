#!/usr/bin/env bash
# hooks-fill-test.sh — red-proofs 6, 8, 11, 12. Drives hooks-glue.sh and
# hooks.sh compile, not setup.md / create.md. Patient-zero: mktemp only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
WS="$(cd "$SKILL/../workstream" && pwd)"
. "$DIR/lib.sh"

GLUE="$SKILL/scripts/hooks-glue.sh"
HOOKS_SH="$WS/scripts/hooks.sh"
SKELETON="$WS/templates/hooks.md"
HANDOFF_TPL="$WS/templates/workstream-handoff.md"
SETUP_MD="$SKILL/verbs/setup.md"
KNOWN=(--known "feature-completion=Feature completion" --known "after-eventful-ship=After eventful ship")

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"
ERR="$TMP/err"

hash_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}
fact() { sed -n -E "s/^$1=//p" "$2" | head -n 1; }
tree_sum() {
  (cd "$1" && find . -type f | sort | while IFS= read -r f; do hash_of "$f"; done)
}

# --- 6. Setup materialize + fill + incumbent ---------------------------------
hooks_dir="$TMP/p6/hooks"
mkdir -p "$hooks_dir"
hooks6="$hooks_dir/workstream.md"
rc=0; "$GLUE" fill --file "$hooks6" --skeleton "$SKELETON" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "6a fill-create rc" "0" "$rc"
expect_eq "6a status filled" "filled" "$(fact status "$OUT")"
expect "6a Feature completion filled" "/backlog debrief" "$hooks6"
expect "6a After eventful ship filled" "/backlog debrief" "$hooks6"

# 6b: present non-empty Feature completion; empty sibling still filled
inc="$TMP/p6b/hooks"
mkdir -p "$inc"
inc_f="$inc/workstream.md"
printf '%s\n' '# workstream hooks' '' \
  '## Feature completion' '' \
  'keep-me' '' \
  '## After eventful ship' >"$inc_f"
rc=0; "$GLUE" fill --file "$inc_f" --skeleton "$SKELETON" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "6b fill rc" "0" "$rc"
expect "6b incumbent Feature completion" "keep-me" "$inc_f"
expect "6b empty sibling filled" "/backlog debrief" "$inc_f"
# Feature completion body still keep-me (not overwritten)
fc_body=$(awk '/^## Feature completion$/{p=1;next} /^## /{p=0} p' "$inc_f")
case "$fc_body" in *keep-me*) pass=$((pass + 1)) ;; *)
  echo "FAIL: 6b Feature completion body lost keep-me" >&2; fail=$((fail + 1));;
esac

# 6c: face-only (no ../workstream sibling)
face="$TMP/face-only/clankshop"
mkdir -p "$face/scripts" "$face/verbs"
cp "$SKILL/scripts/hooks-glue.sh" "$face/scripts/hooks-glue.sh"
chmod +x "$face/scripts/hooks-glue.sh"
rc=0; "$face/scripts/hooks-glue.sh" presence --clankshop-dir "$face" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "6c presence rc" "0" "$rc"
expect_eq "6c presence false" "false" "$(fact presence "$OUT")"
missing_skel="$face/../workstream/templates/hooks.md"
rc=0; "$face/scripts/hooks-glue.sh" fill --file "$TMP/face-only/hooks/workstream.md" \
  --skeleton "$missing_skel" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "6c fill noop rc" "0" "$rc"
expect_eq "6c status noop" "noop" "$(fact status "$OUT")"
[ ! -e "$TMP/face-only/hooks/workstream.md" ] && pass=$((pass + 1)) || {
  echo "FAIL: 6c created a hooks file" >&2; fail=$((fail + 1)); }

# 6d: whitespace-only body is empty
wsd="$TMP/p6d/hooks"
mkdir -p "$wsd"
wsf="$wsd/workstream.md"
printf '%s\n' '# workstream hooks' '' \
  '## Feature completion' ' ' \
  '## After eventful ship' 'already' >"$wsf"
rc=0; "$GLUE" fill --file "$wsf" --skeleton "$SKELETON" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "6d rc" "0" "$rc"
expect "6d whitespace Feature completion filled" "/backlog debrief" "$wsf"
expect "6d sibling already left" "already" "$wsf"

# 6e: relative --file; parent missing
fake="$TMP/fake-wt"
mkdir -p "$fake"
rc=0
(
  cd "$fake" || exit 1
  "$GLUE" fill --file hooks/workstream.md --skeleton "$SKELETON"
) >"$OUT" 2>"$ERR" || rc=$?
expect_eq "6e relative rc" "2" "$rc"
np="$TMP/no-parent/hooks/workstream.md"
rc=0; "$GLUE" fill --file "$np" --skeleton "$SKELETON" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "6e no-parent rc" "0" "$rc"
expect_eq "6e status no-parent" "no-parent" "$(fact status "$OUT")"
[ ! -d "$TMP/no-parent" ] && pass=$((pass + 1)) || {
  echo "FAIL: 6e mkdir of missing parent" >&2; fail=$((fail + 1)); }

# --- 8. Primary path: fill then compile into this hand-off: ------------------
root8="$TMP/root8"
mkdir -p "$root8/.dev/hooks" "$root8/.workstreams/demo"
hooks8="$root8/.dev/hooks/workstream.md"
ho8="$root8/.workstreams/demo/WORKSTREAM.md"
cp "$HANDOFF_TPL" "$ho8"
rc=0; "$GLUE" fill --file "$hooks8" --skeleton "$SKELETON" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "8 fill rc" "0" "$rc"
rc=0; "$HOOKS_SH" compile --file "$hooks8" --handoff "$ho8" --root "$root8" \
  "${KNOWN[@]}" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "8 compile rc" "0" "$rc"
"$HOOKS_SH" compiled-get --handoff "$ho8" >"$OUT"
expect "8 compiled Feature completion" "/backlog debrief" "$OUT"
n_debrief=$(grep -cF '/backlog debrief' "$OUT" || true)
expect_eq "8 both ids compiled" "2" "$n_debrief"
[ ! -e "$root8/WORKSTREAM.md" ] && pass=$((pass + 1)) || {
  echo "FAIL: 8 planted <root>/WORKSTREAM.md" >&2; fail=$((fail + 1)); }

# --- 11. Already-seeded: seed.sh refuses; fill; check green ------------------
JOURNAL="$(cd "$SKILL/../journal" && pwd)"
proj11="$TMP/proj11"
mkdir -p "$proj11"
git -C "$TMP" init -q proj11 2>/dev/null || git init -q "$proj11"
"$SKILL/scripts/seed.sh" "$proj11" --gate 'make test' --trunk main >"$OUT" 2>"$ERR"
expect "11 seed green" "load sets: OK" "$OUT"
rc=0; "$SKILL/scripts/seed.sh" "$proj11" --gate 'make test' --trunk main \
  >"$OUT" 2>"$ERR" || rc=$?
if [ "$rc" -ne 0 ]; then
  pass=$((pass + 1))
else
  echo "FAIL: 11 seed.sh did not refuse re-seed" >&2; fail=$((fail + 1))
fi
"$JOURNAL/scripts/standup.sh" "$proj11" >/dev/null 2>&1 || true
printf '%s\n' '# door' '' 'See .dev/doctrine/README.md' >"$proj11/AGENTS.md"

# 11a: HOOKS absent
hooks11="$proj11/.dev/hooks/workstream.md"
mkdir -p "$proj11/.dev/hooks"
[ ! -e "$hooks11" ] || rm -f "$hooks11"
rc=0; "$GLUE" fill --file "$hooks11" --skeleton "$SKELETON" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "11a fill rc" "0" "$rc"
expect_eq "11a status filled" "filled" "$(fact status "$OUT")"
rc=0; "$GLUE" check --file "$hooks11" --presence true >"$OUT" 2>"$ERR" || rc=$?
expect_eq "11a check rc" "0" "$rc"
expect_eq "11a finding false" "false" "$(fact finding "$OUT")"

# 11b: present empty known H2s — fill bodies, do not recreate structure
printf '%s\n' '# workstream hooks' 'custom-chrome' '' \
  '## Feature completion' '' \
  '## After eventful ship' >"$hooks11"
rc=0; "$GLUE" fill --file "$hooks11" --skeleton "$SKELETON" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "11b fill rc" "0" "$rc"
expect "11b chrome preserved" "custom-chrome" "$hooks11"
expect "11b bodies filled" "/backlog debrief" "$hooks11"
rc=0; "$GLUE" check --file "$hooks11" --presence true >"$OUT" 2>"$ERR" || rc=$?
expect_eq "11b finding false" "false" "$(fact finding "$OUT")"

# Guard prose: STOP green-list, resume parenthetical, range (1–6)
expect "11 Guard unfinished hooks in setup.md" "unfinished hooks" "$SETUP_MD"
expect "11 Guard range (1–6)" "(1–6)" "$SETUP_MD"
resume_hits=$(grep -cE 'records layer absent, unfinished hooks' "$SETUP_MD" || true)
if [ "$resume_hits" -ge 1 ]; then
  pass=$((pass + 1))
else
  echo "FAIL: 11 resume parenthetical missing unfinished hooks" >&2
  fail=$((fail + 1))
fi
# Disable resume-parenthetical, confirm grep no longer matches, restore (copy).
cp "$SETUP_MD" "$TMP/setup-cut.md"
awk '/records layer absent, unfinished hooks/ { gsub(/, unfinished hooks/, ""); } { print }' \
  "$SETUP_MD" > "$TMP/setup-cut.md"
cut_hits=$(grep -cE 'records layer absent, unfinished hooks' "$TMP/setup-cut.md" || true)
expect_eq "11 disabled resume parenthetical gone" "0" "$cut_hits"
expect "11 original setup.md still has it" "records layer absent, unfinished hooks" "$SETUP_MD"

# --- 12. Check presence vs write ---------------------------------------------
# 12a: face-only, --presence false
sum_face=$(tree_sum "$face")
rc=0; "$face/scripts/hooks-glue.sh" check --file "$TMP/face-only/hooks/workstream.md" \
  --presence false >"$OUT" 2>"$ERR" || rc=$?
expect_eq "12a check rc" "0" "$rc"
expect_eq "12a finding false" "false" "$(fact finding "$OUT")"
expect_eq "12a tree checksum" "$sum_face" "$(tree_sum "$face")"

# 12b: skeleton present, empty headings → finding true, checksum unchanged
empty12="$TMP/p12b/hooks"
mkdir -p "$empty12"
e12="$empty12/workstream.md"
cp "$SKELETON" "$e12"
sum12=$(hash_of "$e12")
rc=0; "$GLUE" check --file "$e12" --presence true >"$OUT" 2>"$ERR" || rc=$?
expect_eq "12b check rc" "0" "$rc"
expect_eq "12b finding true" "true" "$(fact finding "$OUT")"
expect_eq "12b name setup" "/clankshop setup" "$(fact name "$OUT")"
expect_eq "12b checksum unchanged" "$sum12" "$(hash_of "$e12")"

# 12c: Feature completion omitted, After filled → no setup-named finding
omit="$TMP/p12c/hooks"
mkdir -p "$omit"
o12="$omit/workstream.md"
printf '%s\n' '# workstream hooks' '' \
  '## After eventful ship' '' \
  '/backlog debrief' >"$o12"
sum12c=$(hash_of "$o12")
rc=0; "$GLUE" check --file "$o12" --presence true >"$OUT" 2>"$ERR" || rc=$?
expect_eq "12c check rc" "0" "$rc"
expect_eq "12c finding false" "false" "$(fact finding "$OUT")"
expect_eq "12c checksum unchanged" "$sum12c" "$(hash_of "$o12")"

report "hooks-fill-test.sh"
