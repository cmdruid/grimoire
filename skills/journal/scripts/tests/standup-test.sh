#!/usr/bin/env bash
# standup-test.sh — records-root deployment, refresh, and safe-parent proofs.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

STANDUP="$SKILL/scripts/standup.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"
ERR="$TMP/err"

run_default() {
  "$STANDUP" setup "$1" || return $?
  if [ -f "$1/.spaces/journal/setup.intent" ]; then
    "$STANDUP" finalize "$1"
  fi
}

# The engine and data substrate share the public records root.
proj="$TMP/project"
mkdir -p "$proj"
rc=0; run_default "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "standup rc" "0" "$rc"
expect "standup self-check" "records check: OK (0 records)" "$OUT"
[ -x "$proj/.records/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: staged engine missing" >&2; fail=$((fail + 1)); }
[ -f "$proj/.records/history.tsv" ] && pass=$((pass + 1)) || {
  echo "FAIL: ledger missing" >&2; fail=$((fail + 1)); }
expect "README discovers colocated engine" "beside this README is the query and lifecycle engine" "$proj/.records/README.md"
expect "README shows fixed invocation" ".records/records.sh list" "$proj/.records/README.md"
expect_absent "README has no root selector" "--records-root" "$proj/.records/README.md"
expect "README explains check" "check\` validates record metadata" "$proj/.records/README.md"
expect "README protects ledger" "Never edit \`history.tsv\` by hand" "$proj/.records/README.md"
expect "README owns refreshable block" "<!-- journal:records-tool BEGIN -->" "$proj/.records/README.md"

rc=0; run_default "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "zero-write rerun rc" "0" "$rc"
expect_absent "zero-write rerun reports no write" "wrote:" "$OUT"
[ ! -e "$proj/.spaces/journal/setup.intent" ] && pass=$((pass + 1)) || {
  echo "FAIL: clean setup created an intent" >&2; fail=$((fail + 1)); }

# Initialized reconciliation restores a missing or non-executable provider but
# never changes an incumbent ledger or a writer-owned record.
printf '%s\n' 'ledger-canary' >"$proj/.records/history.tsv"
mkdir -p "$proj/.records/notes"
printf '%s\n' 'record-canary' >"$proj/.records/notes/keep.md"
chmod -x "$proj/.records/records.sh"
rc=0; run_default "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "non-executable provider repair rc" "0" "$rc"
expect "non-executable provider reports write" "wrote: .records/records.sh" "$OUT"
[ -x "$proj/.records/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: provider executable mode was not restored" >&2; fail=$((fail + 1)); }
expect "non-executable repair preserves ledger" "ledger-canary" "$proj/.records/history.tsv"
expect "non-executable repair preserves record" "record-canary" "$proj/.records/notes/keep.md"
rm "$proj/.records/records.sh"
rc=0; run_default "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "missing provider restoration rc" "0" "$rc"
expect "missing provider reports write" "wrote: .records/records.sh" "$OUT"
expect "missing provider preserves ledger" "ledger-canary" "$proj/.records/history.tsv"
expect "missing provider preserves record" "record-canary" "$proj/.records/notes/keep.md"

# Re-run preserves project substrate and refreshes package bytes.
printf '%s\n' 'keep-ledger' > "$proj/.records/history.tsv"
printf '%s\n' 'project readme' > "$proj/.records/README.md"
printf '%s\n' '# drift' >> "$proj/.records/records.sh"
rc=0; run_default "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "refresh rc" "0" "$rc"
expect_absent "refresh removes drift" "# drift" "$proj/.records/records.sh"
expect "refresh preserves ledger" "keep-ledger" "$proj/.records/history.tsv"
expect "refresh preserves README" "project readme" "$proj/.records/README.md"
expect "refresh appends owned block" "<!-- journal:records-tool BEGIN -->" "$proj/.records/README.md"
expect "refresh adds current path" ".records/records.sh list" "$proj/.records/README.md"

sed -i.bak 's/## Use the records tool/## Stale records tool/' "$proj/.records/README.md"
rm "$proj/.records/README.md.bak"
rc=0; run_default "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "managed README refresh rc" "0" "$rc"
expect "managed README refresh reports write" "wrote: .records/README.md" "$OUT"
expect_absent "managed README drift removed" "## Stale records tool" "$proj/.records/README.md"
expect "managed README surrounding prose survives refresh" "project readme" "$proj/.records/README.md"

rc=0; run_default "$proj" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "managed README zero-write rerun rc" "0" "$rc"
expect_absent "managed README zero-write rerun" "wrote:" "$OUT"

# Retired root selectors refuse before writing, and noncanonical canaries are ignored.
for selector in --records-root --workspace-root --trackers-root --workspace; do
  rejected="$TMP/rejected-${selector#--}"; mkdir -p "$rejected/custom"
  printf 'NONCANONICAL_CANARY\n' >"$rejected/custom/keep"
  rc=0; "$STANDUP" setup "$rejected" "$selector" custom >"$OUT" 2>"$ERR" || rc=$?
  expect_eq "$selector refusal rc" "1" "$rc"
  expect "noncanonical canary preserved" "NONCANONICAL_CANARY" "$rejected/custom/keep"
  [ ! -e "$rejected/.records" ] && pass=$((pass + 1)) || fail=$((fail + 1))
done

# Upgrade the prior generated pointer without disturbing its surrounding prose,
# and remove the obsolete workspace-staged package engine.
upgrade="$TMP/upgrade"
mkdir -p "$upgrade/.records" "$upgrade/.spaces/journal/scripts"
cp "$SKILL/scripts/records.sh" "$upgrade/.spaces/journal/scripts/records.sh"
chmod +x "$upgrade/.spaces/journal/scripts/records.sh"
cat > "$upgrade/.records/README.md" <<'EOF'
# Records

Keep this project note.
`.spaces/journal/scripts/records.sh` is the query and lifecycle engine;
every invocation passes `--root <root>`. It is the
sole writer of `history.tsv`, the closure ledger.

Keep this footer.
EOF
rc=0; run_default "$upgrade" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "legacy tool upgrade rc" "0" "$rc"
expect_absent "legacy README pointer removed" ".spaces/journal/scripts/records.sh" "$upgrade/.records/README.md"
expect "legacy README surrounding prose kept" "Keep this project note." "$upgrade/.records/README.md"
expect "legacy README footer kept" "Keep this footer." "$upgrade/.records/README.md"
expect "legacy README block installed" "<!-- journal:records-tool BEGIN -->" "$upgrade/.records/README.md"
[ ! -e "$upgrade/.spaces/journal/scripts/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: legacy workspace tool remains" >&2; fail=$((fail + 1)); }
[ -x "$upgrade/.records/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: upgraded records-root tool missing" >&2; fail=$((fail + 1)); }

# Replacing the exact legacy pointer must also preserve an unowned suffix's
# lack of a final newline.
upgrade_eof="$TMP/upgrade-eof"
mkdir -p "$upgrade_eof/.records" "$upgrade_eof/.spaces/journal/scripts"
cp "$SKILL/scripts/records.sh" "$upgrade_eof/.spaces/journal/scripts/records.sh"
chmod +x "$upgrade_eof/.spaces/journal/scripts/records.sh"
printf '%s\n' '# Records' '' \
  '`.spaces/journal/scripts/records.sh` is the query and lifecycle engine;' \
  'every invocation passes `--root <root>`. It is the' \
  'sole writer of `history.tsv`, the closure ledger.' >"$upgrade_eof/.records/README.md"
printf 'LEGACY_TAIL_CANARY' >>"$upgrade_eof/.records/README.md"
run_default "$upgrade_eof" >"$OUT" 2>"$ERR"
expect_eq "legacy pointer replacement preserves unowned EOF byte" "89" \
  "$(tail -c 1 "$upgrade_eof/.records/README.md" | od -An -tuC | tr -d '[:space:]')"
printf 'LEGACY_TAIL_CANARY' >"$TMP/upgrade-eof.expected"
tail -c 18 "$upgrade_eof/.records/README.md" >"$TMP/upgrade-eof.actual"
if cmp -s "$TMP/upgrade-eof.expected" "$TMP/upgrade-eof.actual"; then
  pass=$((pass + 1))
else
  echo "FAIL: legacy pointer replacement changed the unowned EOF suffix" >&2
  fail=$((fail + 1))
fi

# Generated-looking prose for a different resolved path is project content,
# not the exact prior pointer owned by this setup.
foreign="$TMP/foreign-pointer"
mkdir -p "$foreign/.records"
cat >"$foreign/.records/README.md" <<'EOF'
# Records

`.other/journal/scripts/records.sh` is the query and lifecycle engine;
every invocation passes `--root <root>`. It is the
sole writer of `history.tsv`, the closure ledger.
EOF
run_default "$foreign" >"$OUT" 2>"$ERR"
expect "foreign generated-looking pointer preserved" ".other/journal/scripts/records.sh" \
  "$foreign/.records/README.md"

# A provider copied outside `.records` refuses to operate.
noncanonical="$TMP/noncanonical-provider"
mkdir -p "$noncanonical/other"; cp "$SKILL/scripts/records.sh" "$noncanonical/other/records.sh"; chmod +x "$noncanonical/other/records.sh"
rc=0; "$noncanonical/other/records.sh" list >"$OUT" 2>"$ERR" || rc=$?
expect_eq "noncanonical provider refusal rc" "2" "$rc"

# Malformed ownership markers refuse before any tool-layer write.
malformed="$TMP/malformed"
mkdir -p "$malformed/.records"
printf '%s\n' '# Records' '<!-- journal:records-tool BEGIN -->' > "$malformed/.records/README.md"
rc=0; run_default "$malformed" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "malformed README block rc" "2" "$rc"
expect "malformed README block finding" "malformed journal records-tool block" "$ERR"
[ ! -e "$malformed/.records/records.sh" ] && [ ! -e "$malformed/.records/history.tsv" ] \
  && pass=$((pass + 1)) || {
    echo "FAIL: malformed README allowed partial tool-layer writes" >&2; fail=$((fail + 1)); }

for marker_case in duplicate nested reversed unmatched-end; do
  marker_root="$TMP/marker-$marker_case"
  mkdir -p "$marker_root/.records"
  case "$marker_case" in
    duplicate) printf '%s\n' '<!-- journal:records-tool BEGIN -->' '<!-- journal:records-tool END -->' \
      '<!-- journal:records-tool BEGIN -->' '<!-- journal:records-tool END -->' >"$marker_root/.records/README.md" ;;
    nested) printf '%s\n' '<!-- journal:records-tool BEGIN -->' '<!-- journal:records-tool BEGIN -->' \
      '<!-- journal:records-tool END -->' '<!-- journal:records-tool END -->' >"$marker_root/.records/README.md" ;;
    reversed) printf '%s\n' '<!-- journal:records-tool END -->' \
      '<!-- journal:records-tool BEGIN -->' >"$marker_root/.records/README.md" ;;
    unmatched-end) printf '%s\n' '<!-- journal:records-tool END -->' >"$marker_root/.records/README.md" ;;
  esac
  rc=0; run_default "$marker_root" >"$OUT" 2>"$ERR" || rc=$?
  expect_eq "$marker_case marker refusal rc" "2" "$rc"
  [ ! -e "$marker_root/.records/records.sh" ] && [ ! -e "$marker_root/.records/history.tsv" ] \
    && pass=$((pass + 1)) || {
      echo "FAIL: $marker_case markers allowed a tool-layer write" >&2; fail=$((fail + 1)); }
done

# Red-prove every malformed-marker fixture by disabling the one marker parser
# in a copied helper. Each formerly refusing fixture must then reach a tool
# write, while the live helper remains byte-identical.
marker_mutation_skill="$TMP/marker-mutation/journal"
mkdir -p "$marker_mutation_skill/scripts"
cp "$STANDUP" "$TMP/marker-live.before"
cp "$STANDUP" "$marker_mutation_skill/scripts/standup.sh"
cp "$SKILL/scripts/records.sh" "$marker_mutation_skill/scripts/records.sh"
marker_needle='validate_markers() {'
expect_eq "marker parser mutation target count" "1" \
  "$(grep -Fxc -- "$marker_needle" "$marker_mutation_skill/scripts/standup.sh")"
awk -v needle="$marker_needle" '
  $0 == needle { print; print "  readme_begins=0; return 0"; changed++; next }
  { print }
  END { if (changed != 1) exit 1 }
' "$marker_mutation_skill/scripts/standup.sh" >"$marker_mutation_skill/scripts/standup.sh.tmp"
mv "$marker_mutation_skill/scripts/standup.sh.tmp" "$marker_mutation_skill/scripts/standup.sh"
chmod +x "$marker_mutation_skill/scripts/standup.sh" "$marker_mutation_skill/scripts/records.sh"
for marker_case in duplicate nested reversed unmatched-end; do
  marker_root="$TMP/marker-$marker_case"
  rc=0
  "$marker_mutation_skill/scripts/standup.sh" setup "$marker_root" \
 >"$OUT" 2>"$ERR" || rc=$?
  if [ "$rc" -eq 0 ] && [ -x "$marker_root/.records/records.sh" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: $marker_case marker mutation did not red-prove its refusal" >&2
    fail=$((fail + 1))
  fi
done
if cmp -s "$TMP/marker-live.before" "$STANDUP"; then pass=$((pass + 1)); else
  echo "FAIL: marker mutations changed the live helper" >&2; fail=$((fail + 1)); fi

# Setup is a hard cut: it reports legacy records but never migrates them while
# reading or refreshing the tool layer.
mig="$TMP/migrate"
mkdir -p "$mig/.records/notes"
today=$(date +%Y-%m-%d)
printf '%s\n' '---' 'doctype: notes' 'status: open' "created: $today" "updated: $today" \
  'tags: []' '---' '' '# Old status' > "$mig/.records/notes/$today-old.md"
run_default "$mig" >"$OUT" 2>"$ERR"
expect_absent "setup performs no implicit migration" "migrated=" "$OUT"
expect "setup reports legacy check failure" "records check failed" "$ERR"
expect "legacy status is untouched" "status: open" "$mig/.records/notes/$today-old.md"

# Unsafe records parents fail before any writes.
unsafe="$TMP/unsafe"
mkdir -p "$unsafe/real"
ln -s "$unsafe/real" "$unsafe/.records"
rc=0
"$STANDUP" setup "$unsafe" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "records symlink rejected" "2" "$rc"
[ ! -e "$unsafe/real/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: records symlink target mutated" >&2; fail=$((fail + 1)); }

unsafe_workspace="$TMP/unsafe-workspace"
mkdir -p "$unsafe_workspace/real"
ln -s "$unsafe_workspace/real" "$unsafe_workspace/.spaces"
rc=0
"$STANDUP" setup "$unsafe_workspace" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "workspace symlink rejected" "2" "$rc"
[ ! -e "$unsafe_workspace/.records" ] && pass=$((pass + 1)) || {
  echo "FAIL: unsafe workspace allowed records writes" >&2; fail=$((fail + 1)); }

for unsafe_entry in provider ledger readme legacy; do
  unsafe_root="$TMP/unsafe-$unsafe_entry"
  mkdir -p "$unsafe_root/.records" "$unsafe_root/.spaces/journal/scripts" "$unsafe_root/elsewhere"
  case "$unsafe_entry" in
    provider) ln -s "$unsafe_root/elsewhere" "$unsafe_root/.records/records.sh" ;;
    ledger) mkdir "$unsafe_root/.records/history.tsv" ;;
    readme) ln -s "$unsafe_root/elsewhere" "$unsafe_root/.records/README.md" ;;
    legacy) ln -s "$unsafe_root/elsewhere" "$unsafe_root/.spaces/journal/scripts/records.sh" ;;
  esac
  rc=0; run_default "$unsafe_root" >"$OUT" 2>"$ERR" || rc=$?
  expect_eq "unsafe $unsafe_entry rejected" "2" "$rc"
  [ ! -e "$unsafe_root/.spaces/journal/setup.intent" ] && pass=$((pass + 1)) || {
    echo "FAIL: unsafe $unsafe_entry created a setup intent" >&2; fail=$((fail + 1)); }
done

# Exchange the records root after preflight; the immediate creation/write
# recheck must refuse without following it.
race="$TMP/race"
mkdir -p "$race/.records" "$race/elsewhere"
hook="$TMP/journal-exchange.sh"
printf '%s\n' '#!/bin/sh' 'mv "$1/$2" "$1/held-records"' \
  'ln -s "$1/elsewhere" "$1/$2"' > "$hook"
chmod +x "$hook"
rc=0
JOURNAL_SETUP_TEST_AFTER_PREFLIGHT="$hook" run_default "$race" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "post-preflight exchange rejected" "2" "$rc"
[ ! -e "$race/elsewhere/records.sh" ] && pass=$((pass + 1)) || {
  echo "FAIL: journal wrote through exchanged records root" >&2; fail=$((fail + 1)); }

# Stop after staging the engine, then prove the completed path is reported and
# a clean rerun finishes the ledger and README.
partial="$TMP/partial"
mkdir -p "$partial"
write_hook="$TMP/journal-stop-after-first.sh"
printf '%s\n' '#!/bin/sh' '[ "$4" -eq 1 ] && exit 86' 'exit 0' > "$write_hook"
chmod +x "$write_hook"
rc=0
JOURNAL_SETUP_TEST_AFTER_WRITE="$write_hook" run_default "$partial" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "post-first-write interruption exercised" "86" "$rc"
expect "partial reports staged engine" "wrote: .records/records.sh" "$OUT"
[ ! -e "$partial/.records/history.tsv" ] && pass=$((pass + 1)) || fail=$((fail + 1))
rc=0; run_default "$partial" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "partial rerun rc" "0" "$rc"
[ -f "$partial/.records/history.tsv" ] && [ -f "$partial/.records/README.md" ] \
  && pass=$((pass + 1)) || fail=$((fail + 1))

report "standup-test"
