#!/usr/bin/env bash
# repair-test.sh — narrow initialized-layer repair and write-set proofs.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

STANDUP="$SKILL/scripts/standup.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-repair-test.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

setup_layer() {
  layer_root="$1"
  mkdir -p "$layer_root"
  "$STANDUP" setup "$layer_root" >/dev/null
  "$STANDUP" finalize "$layer_root"
}

repair_layer() {
  "$STANDUP" repair "$1"
}

assert_protected() {
  protected_root="$1"
  expect "ledger canary preserved" "ledger-canary" "$protected_root/.records/history.tsv"
  expect "record canary preserved" "record-canary" "$protected_root/.records/notes/keep.md"
  expect "unowned README prose preserved" "project-readme-canary" "$protected_root/.records/README.md"
}

base="$TMP/base"
setup_layer "$base"
printf '%s\n' 'ledger-canary' >"$base/.records/history.tsv"
mkdir -p "$base/.records/notes"
printf '%s\n' 'record-canary' >"$base/.records/notes/keep.md"
printf '%s\n' 'project-readme-canary' >>"$base/.records/README.md"

rm "$base/.records/records.sh"
rc=0; repair_layer "$base" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "missing provider repair rc" "0" "$rc"
expect "missing provider reported" "wrote: .records/records.sh" "$OUT"
expect_absent "missing provider repair does not report README" "wrote: .records/README.md" "$OUT"
[ -x "$base/.records/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: missing provider was not restored" >&2; fail=$((fail + 1)); }
assert_protected "$base"

chmod -x "$base/.records/records.sh"
rc=0; repair_layer "$base" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "non-executable provider repair rc" "0" "$rc"
expect "non-executable provider reported" "wrote: .records/records.sh" "$OUT"
[ -x "$base/.records/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: repair did not restore executable mode" >&2; fail=$((fail + 1)); }
assert_protected "$base"

printf '%s\n' '# stale-provider' >>"$base/.records/records.sh"
rc=0; repair_layer "$base" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "byte-stale provider repair rc" "0" "$rc"
expect_absent "byte-stale provider removed" "# stale-provider" "$base/.records/records.sh"
assert_protected "$base"

rc=0; repair_layer "$base" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "clean repair rc" "0" "$rc"
expect_absent "clean repair reports no writes" "wrote:" "$OUT"
[ ! -e "$base/.spaces/journal/setup.intent" ] && pass=$((pass + 1)) || {
  echo "FAIL: repair created a setup intent" >&2; fail=$((fail + 1)); }

# An absent block is appended without replacing the prior generated pointer or
# surrounding project prose; a stale block is refreshed in place.
absent="$TMP/absent-block"
setup_layer "$absent"
cat >"$absent/.records/README.md" <<'EOF'
# Project records

project-prefix
`.spaces/journal/scripts/records.sh` is the query and lifecycle engine;
every invocation passes `--root <root>`. It is the
sole writer of `history.tsv`, the closure ledger.
project-suffix
EOF
cp "$absent/.records/README.md" "$TMP/absent.before"
repair_layer "$absent" >"$OUT" 2>"$ERR"
expect "absent block reported" "wrote: .records/README.md" "$OUT"
expect "repair keeps prior pointer" ".spaces/journal/scripts/records.sh" "$absent/.records/README.md"
expect "repair keeps prefix" "project-prefix" "$absent/.records/README.md"
expect "repair keeps suffix" "project-suffix" "$absent/.records/README.md"
expect "repair appends managed block" "<!-- journal:records-tool BEGIN -->" "$absent/.records/README.md"

sed -i.bak 's/## Use the records tool/## Stale records tool/' "$absent/.records/README.md"
rm "$absent/.records/README.md.bak"
repair_layer "$absent" >"$OUT" 2>"$ERR"
expect "stale block reported" "wrote: .records/README.md" "$OUT"
expect_absent "stale block removed" "## Stale records tool" "$absent/.records/README.md"
expect "stale block preserves prefix" "project-prefix" "$absent/.records/README.md"

# Refreshing the owned block must not synthesize a final newline in an
# unowned suffix that did not have one.
no_final_newline="$TMP/no-final-newline"
setup_layer "$no_final_newline"
printf 'TAIL_CANARY' >>"$no_final_newline/.records/README.md"
sed -i.bak 's/## Use the records tool/## Stale records tool/' \
  "$no_final_newline/.records/README.md"
rm "$no_final_newline/.records/README.md.bak"
repair_layer "$no_final_newline" >"$OUT" 2>"$ERR"
expect_eq "managed refresh preserves unowned EOF byte" "89" \
  "$(tail -c 1 "$no_final_newline/.records/README.md" | od -An -tuC | tr -d '[:space:]')"
printf 'TAIL_CANARY' >"$TMP/no-final-newline.expected"
tail -c 11 "$no_final_newline/.records/README.md" >"$TMP/no-final-newline.actual"
if cmp -s "$TMP/no-final-newline.expected" "$TMP/no-final-newline.actual"; then
  pass=$((pass + 1))
else
  echo "FAIL: managed refresh changed the unowned EOF suffix" >&2; fail=$((fail + 1))
fi

# Shell metacharacters in the project path retain a runnable, bounded repair.
custom="$TMP/team's [project] \$pace"
setup_layer "$custom"
rm "$custom/.records/records.sh"
repair_layer "$custom" >"$OUT" 2>"$ERR"
expect "spaced-project repair reports provider" "wrote: .records/records.sh" "$OUT"
[ -x "$custom/.records/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: fixed-path provider was not restored" >&2; fail=$((fail + 1)); }

# Every entry refusal happens before provider or README mutation.
missing_ledger="$TMP/missing-ledger"
setup_layer "$missing_ledger"
rm "$missing_ledger/.records/history.tsv" "$missing_ledger/.records/records.sh"
rc=0; repair_layer "$missing_ledger" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "missing ledger refusal rc" "2" "$rc"
expect "missing ledger directs setup" "run /journal setup" "$ERR"
[ ! -e "$missing_ledger/.records/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: missing ledger allowed provider repair" >&2; fail=$((fail + 1)); }

active="$TMP/active-intent"
setup_layer "$active"
rm "$active/.records/records.sh"
rc=0
JOURNAL_SETUP_TEST_STOP_AFTER=intent "$STANDUP" setup "$active" \
 >"$OUT" 2>"$ERR" || rc=$?
expect_eq "active intent fixture stop rc" "86" "$rc"
rc=0; repair_layer "$active" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "active intent repair refusal rc" "2" "$rc"
expect "active intent directs setup" "run /journal setup" "$ERR"
[ ! -e "$active/.records/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: repair resumed an active setup" >&2; fail=$((fail + 1)); }
"$STANDUP" setup "$active" >/dev/null
"$STANDUP" finalize "$active"

malformed="$TMP/malformed"
setup_layer "$malformed"
rm "$malformed/.records/records.sh"
printf '%s\n' '<!-- journal:records-tool BEGIN -->' >"$malformed/.records/README.md"
rc=0; repair_layer "$malformed" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "malformed marker repair refusal rc" "2" "$rc"
[ ! -e "$malformed/.records/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: malformed markers allowed provider repair" >&2; fail=$((fail + 1)); }

for unsafe_kind in root provider readme; do
  unsafe="$TMP/unsafe-$unsafe_kind"
  setup_layer "$unsafe"
  rm "$unsafe/.records/records.sh"
  mkdir -p "$unsafe/elsewhere"
  case "$unsafe_kind" in
    root) mv "$unsafe/.records" "$unsafe/held-records"; ln -s "$unsafe/elsewhere" "$unsafe/.records" ;;
    provider) ln -s "$unsafe/elsewhere" "$unsafe/.records/records.sh" ;;
    readme) rm "$unsafe/.records/README.md"; mkdir "$unsafe/.records/README.md" ;;
  esac
  rc=0; repair_layer "$unsafe" >"$OUT" 2>"$ERR" || rc=$?
  expect_eq "unsafe $unsafe_kind repair refusal rc" "2" "$rc"
done

# A canary at the prior path proves repair never derives, validates, removes,
# or rewrites it, even while restoring both allowed paths.
canary="$TMP/prior-canary"
setup_layer "$canary"
mkdir -p "$canary/.spaces/journal/scripts"
printf '%s\n' 'prior-provider-canary' >"$canary/.spaces/journal/scripts/records.sh"
printf '%s\n' 'outside block names .spaces/journal/scripts/records.sh' >>"$canary/.records/README.md"
rm "$canary/.records/records.sh"
repair_layer "$canary" >"$OUT" 2>"$ERR"
expect "prior provider canary preserved" "prior-provider-canary" \
  "$canary/.spaces/journal/scripts/records.sh"
expect "prior path prose preserved" "outside block names .spaces/journal/scripts/records.sh" \
  "$canary/.records/README.md"

# The aggregate Git diff is exactly the two allowed repair paths.
bounded="$TMP/bounded"
setup_layer "$bounded"
mkdir -p "$bounded/.records/notes" "$bounded/.spaces/journal/scripts" "$bounded/.trackers/tables"
printf '%s\n' 'ledger-byte' >"$bounded/.records/history.tsv"
printf '%s\n' 'record-byte' >"$bounded/.records/notes/keep.md"
printf '%s\n' 'prior-byte' >"$bounded/.spaces/journal/scripts/records.sh"
printf '%s\n' 'tracker-byte' >"$bounded/.trackers/tables/tasks.tsv"
git -C "$bounded" init -q
git -C "$bounded" config user.name Fixture
git -C "$bounded" config user.email fixture@example.invalid
git -C "$bounded" add -- .
git -C "$bounded" commit -qm baseline
printf '%s\n' '# stale-provider' >>"$bounded/.records/records.sh"
sed -i.bak 's/## Use the records tool/## Stale records tool/' "$bounded/.records/README.md"
rm "$bounded/.records/README.md.bak"
git -C "$bounded" add -- .records/records.sh .records/README.md
git -C "$bounded" commit -qm 'Commit stale managed repair surfaces'
repair_layer "$bounded" >"$OUT" 2>"$ERR"
git -C "$bounded" diff --name-only | sort >"$TMP/bounded.paths"
printf '%s\n' '.records/README.md' '.records/records.sh' >"$TMP/bounded.expected"
if cmp -s "$TMP/bounded.expected" "$TMP/bounded.paths"; then
  pass=$((pass + 1))
else
  echo "FAIL: repair diff escaped the two-path write set" >&2
  cat "$TMP/bounded.paths" >&2
  fail=$((fail + 1))
fi

# Counted mutation red proofs for repair's two unique entry guards.
cp "$STANDUP" "$TMP/standup.before"
mutation_skill="$TMP/mutation/journal"
mkdir -p "$mutation_skill/scripts"
cp "$STANDUP" "$mutation_skill/scripts/standup.sh"
cp "$SKILL/scripts/records.sh" "$mutation_skill/scripts/records.sh"
cp "$SKILL/scripts/records-readme-status.sh" \
  "$mutation_skill/scripts/records-readme-status.sh"
cp -R "$SKILL/templates" "$mutation_skill/templates"
needle='  [ -f "$ledger" ] && [ ! -L "$ledger" ] || die "records layer is not initialized; run /journal setup"'
expect_eq "repair ledger mutation target count" "1" \
  "$(grep -Fxc -- "$needle" "$mutation_skill/scripts/standup.sh")"
awk -v needle="$needle" '$0 == needle { print "  :"; changed++; next } { print } END { if (changed != 1) exit 1 }' \
  "$mutation_skill/scripts/standup.sh" >"$mutation_skill/scripts/standup.sh.tmp"
mv "$mutation_skill/scripts/standup.sh.tmp" "$mutation_skill/scripts/standup.sh"
chmod +x "$mutation_skill/scripts/standup.sh" "$mutation_skill/scripts/records.sh"
rc=0
"$mutation_skill/scripts/standup.sh" repair "$missing_ledger" \
 >"$OUT" 2>"$ERR" || rc=$?
if [ "$rc" -eq 0 ] && [ -x "$missing_ledger/.records/records.sh" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: missing-ledger mutation did not prove the repair guard" >&2; fail=$((fail + 1))
fi
if cmp -s "$TMP/standup.before" "$STANDUP"; then pass=$((pass + 1)); else
  echo "FAIL: repair mutation changed the live helper" >&2; fail=$((fail + 1)); fi

active_mutation_root="$TMP/active-mutation"
setup_layer "$active_mutation_root"
rm "$active_mutation_root/.records/records.sh"
rc=0
JOURNAL_SETUP_TEST_STOP_AFTER=intent "$STANDUP" setup "$active_mutation_root" \
 >"$OUT" 2>"$ERR" || rc=$?
expect_eq "active mutation fixture stop rc" "86" "$rc"
active_mutation_skill="$TMP/active-mutation-skill/journal"
mkdir -p "$active_mutation_skill/scripts"
cp "$STANDUP" "$active_mutation_skill/scripts/standup.sh"
cp "$SKILL/scripts/records.sh" "$active_mutation_skill/scripts/records.sh"
cp "$SKILL/scripts/records-readme-status.sh" \
  "$active_mutation_skill/scripts/records-readme-status.sh"
cp -R "$SKILL/templates" "$active_mutation_skill/templates"
needle='  [ ! -e "$intent" ] && [ ! -L "$intent" ] || die "active setup intent; run /journal setup"'
expect_eq "repair active-intent mutation target count" "1" \
  "$(grep -Fxc -- "$needle" "$active_mutation_skill/scripts/standup.sh")"
awk -v needle="$needle" '$0 == needle { print "  :"; changed++; next } { print } END { if (changed != 1) exit 1 }' \
  "$active_mutation_skill/scripts/standup.sh" >"$active_mutation_skill/scripts/standup.sh.tmp"
mv "$active_mutation_skill/scripts/standup.sh.tmp" "$active_mutation_skill/scripts/standup.sh"
chmod +x "$active_mutation_skill/scripts/standup.sh" "$active_mutation_skill/scripts/records.sh"
rc=0
"$active_mutation_skill/scripts/standup.sh" repair "$active_mutation_root" \
 >"$OUT" 2>"$ERR" || rc=$?
if [ "$rc" -eq 0 ] && [ -x "$active_mutation_root/.records/records.sh" ]; then
  pass=$((pass + 1))
else
  echo "FAIL: active-intent mutation did not prove the repair guard" >&2; fail=$((fail + 1))
fi
if cmp -s "$TMP/standup.before" "$STANDUP"; then pass=$((pass + 1)); else
  echo "FAIL: active-intent mutation changed the live helper" >&2; fail=$((fail + 1)); fi

report "repair-test"
