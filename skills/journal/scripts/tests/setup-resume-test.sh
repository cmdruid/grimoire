#!/usr/bin/env bash
# setup-resume-test.sh — stateless interruption recovery and bounded custody.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
SKILL="$(cd "$DIR/../.." && pwd)"; STANDUP="$SKILL/scripts/standup.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-setup-resume.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

init_repo() {
  mkdir -p "$1"; git -C "$1" init -q
  git -C "$1" config user.name Fixture; git -C "$1" config user.email fixture@example.invalid
  printf 'seed\n' >"$1/.seed"; git -C "$1" add .seed; git -C "$1" commit -qm seed
}
commit_layer() { git -C "$1" add .records; git -C "$1" commit -qm layer; }
expect_file() {
  if [ -f "$2" ]; then pass=$((pass + 1)); else
    echo "FAIL: $1 — missing $2" >&2; fail=$((fail + 1))
  fi
}

for stop in provider ledger readme; do
  root="$TMP/stop-$stop"; init_repo "$root"; rc=0
  JOURNAL_SETUP_TEST_STOP_AFTER="$stop" "$STANDUP" setup "$root" >"$OUT" 2>"$ERR" || rc=$?
  expect_eq "$stop interruption rc" 86 "$rc"
  expect_file "$stop publishes provider" "$root/.records/records.sh"
  cmp -s "$SKILL/scripts/records.sh" "$root/.records/records.sh" && pass=$((pass + 1)) || {
    echo "FAIL: $stop left partial provider" >&2; fail=$((fail + 1)); }
  [ ! -e "$root/.spaces" ] && pass=$((pass + 1)) || {
    echo "FAIL: $stop created private setup state" >&2; fail=$((fail + 1)); }
  case "$stop" in
    provider)
      [ ! -e "$root/.records/history.tsv" ] && [ ! -e "$root/.records/README.md" ] &&
        pass=$((pass + 1)) || { echo 'FAIL: provider stop crossed the ledger boundary' >&2; fail=$((fail + 1)); }
      ;;
    ledger)
      [ -f "$root/.records/history.tsv" ] && [ ! -e "$root/.records/README.md" ] &&
        pass=$((pass + 1)) || { echo 'FAIL: ledger stop published README too early' >&2; fail=$((fail + 1)); }
      ;;
    readme)
      [ -f "$root/.records/history.tsv" ] && [ -f "$root/.records/README.md" ] &&
        pass=$((pass + 1)) || { echo 'FAIL: README stop omitted a prior boundary' >&2; fail=$((fail + 1)); }
      ;;
  esac
  "$STANDUP" setup "$root" >"$OUT" 2>"$ERR"
  expect "provider recovered after $stop" 'reconciled: .records/records.sh' "$OUT"
  if [ "$stop" != provider ]; then
    expect "ledger recovered after $stop" 'reconciled: .records/history.tsv' "$OUT"
  fi
  if [ "$stop" = readme ]; then
    expect "README recovered after $stop" 'reconciled: .records/README.md' "$OUT"
  fi
  cmp -s "$SKILL/templates/records-readme-block.md" "$root/.records/README.md" &&
    pass=$((pass + 1)) || { echo "FAIL: $stop fresh README is not block-only" >&2; fail=$((fail + 1)); }
  [ ! -s "$root/.records/history.tsv" ] && pass=$((pass + 1)) || {
    echo "FAIL: $stop ledger is not empty" >&2; fail=$((fail + 1)); }
done

tracked="$TMP/tracked"; init_repo "$tracked"; "$STANDUP" setup "$tracked" --write-only >/dev/null
commit_layer "$tracked"; rm "$tracked/.records/history.tsv"; rc=0
"$STANDUP" setup "$tracked" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "tracked ledger loss rc" 2 "$rc"
expect_eq "tracked ledger route" 'reason=ledger-recovery-required action=git-restore' "$(cat "$ERR")"

managed="$TMP/managed"; mkdir -p "$managed/.records"
sed -n 'p' "$SKILL/templates/records-readme-block.md" >"$managed/.records/README.md"; rc=0
"$STANDUP" setup "$managed" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "managed witness rc" 2 "$rc"
expect_eq "managed witness route" 'reason=ledger-recovery-required action=human-review' "$(cat "$ERR")"

archived="$TMP/archived"; mkdir -p "$archived/.records/notes"
printf '%s\n' '---' 'doctype: notes' 'status: archived' 'schema: notepad/note@1' 'tags: []' \
  '---' '# Closed' >"$archived/.records/notes/2026-09-02-closed.md"
rc=0; "$STANDUP" setup "$archived" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "archived witness rc" 2 "$rc"
expect_eq "archived witness route" 'reason=ledger-recovery-required action=human-review' "$(cat "$ERR")"

brownfield="$TMP/brownfield"; mkdir -p "$brownfield/.records/notes"
printf '%s\n' '---' 'doctype: notes' 'status: published' 'schema: notepad/note@1' 'tags: []' \
  '---' '# Live' >"$brownfield/.records/notes/2026-09-02-live.md"
ln -s "$TMP/nowhere" "$brownfield/.spaces"
"$STANDUP" setup "$brownfield" >"$OUT" 2>"$ERR"
expect_file "generic brownfield gets ledger" "$brownfield/.records/history.tsv"
expect "generic brownfield reports ledger" 'wrote: .records/history.tsv' "$OUT"

non_git="$TMP/non-git"; mkdir -p "$non_git"
"$STANDUP" setup "$non_git" >"$OUT" 2>"$ERR"
expect "non-Git reports current write" 'wrote: .records/records.sh' "$OUT"
expect_absent "non-Git cannot recover earlier custody" 'reconciled:' "$OUT"

dirty="$TMP/dirty"; init_repo "$dirty"; "$STANDUP" setup "$dirty" --write-only >/dev/null
commit_layer "$dirty"
printf '\nPROJECT_CANARY\n' >>"$dirty/.records/README.md"
sed -i.bak 's/## Use the records tool/## Stale records tool/' "$dirty/.records/README.md"
rm "$dirty/.records/README.md.bak"; rc=0
"$STANDUP" setup "$dirty" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "unowned README custody rc" 2 "$rc"
expect "unowned README custody route" 'reason=commit-custody-required detail=.records/README.md' "$ERR"
expect "unowned README survives" PROJECT_CANARY "$dirty/.records/README.md"

write_only="$TMP/write-only"; init_repo "$write_only"; "$STANDUP" setup "$write_only" --write-only >/dev/null
commit_layer "$write_only"
printf '\nPROJECT_CANARY\n' >>"$write_only/.records/README.md"
sed -i.bak 's/## Use the records tool/## Stale records tool/' "$write_only/.records/README.md"
rm "$write_only/.records/README.md.bak"
"$STANDUP" setup "$write_only" --write-only >"$OUT" 2>"$ERR"
expect "write-only reports current README" 'wrote: .records/README.md' "$OUT"
expect_absent "write-only does not infer custody" 'reconciled:' "$OUT"

dirty_ledger="$TMP/dirty-ledger"; init_repo "$dirty_ledger"
"$STANDUP" setup "$dirty_ledger" --write-only >/dev/null; commit_layer "$dirty_ledger"
printf 'project-ledger-edit\n' >>"$dirty_ledger/.records/history.tsv"; rc=0
"$STANDUP" setup "$dirty_ledger" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "dirty incumbent ledger custody rc" 2 "$rc"
expect "dirty incumbent ledger custody route" \
  'reason=commit-custody-required detail=.records/history.tsv' "$ERR"
expect "dirty incumbent ledger remains inspectable" project-ledger-edit \
  "$dirty_ledger/.records/history.tsv"

clean="$TMP/clean"; init_repo "$clean"; "$STANDUP" setup "$clean" --write-only >/dev/null
commit_layer "$clean"; "$STANDUP" setup "$clean" >"$OUT" 2>"$ERR"
expect_absent "clean setup reports no write" 'wrote:' "$OUT"
expect_absent "clean setup reports no recovery" 'reconciled:' "$OUT"

copy_reconciler() {
  destination="$1"
  mkdir -p "$destination/scripts" "$destination/templates"
  cp "$STANDUP" "$destination/scripts/standup.sh"
  cp "$SKILL/scripts/records.sh" "$destination/scripts/records.sh"
  cp "$SKILL/scripts/records-layer-status.sh" "$destination/scripts/records-layer-status.sh"
  cp "$SKILL/scripts/records-readme-status.sh" "$destination/scripts/records-readme-status.sh"
  sed -n 'p' "$SKILL/templates/records-readme-block.md" \
    >"$destination/templates/records-readme-block.md"
  chmod 755 "$destination/scripts/"*.sh
}

order_mutant="$TMP/order-mutant"; copy_reconciler "$order_mutant"
order_script="$order_mutant/scripts/standup.sh"
expect_eq "ledger creation mutation target is unique" 1 \
  "$(grep -Fc 'if [ "$mode" = setup ] && [ ! -e "$ledger" ]; then' "$order_script")"
expect_eq "ledger publication gate mutation target is unique" 1 \
  "$(grep -Fc '[ -f "$ledger" ] && [ ! -L "$ledger" ] || refuse setup-required' "$order_script")"
sed -i.bak 's/if \[ "$mode" = setup \] && \[ ! -e "$ledger" \]; then/if false; then/' "$order_script"
rm "$order_script.bak"
sed -i.bak "s#\[ -f \"\$ledger\" \] && \[ ! -L \"\$ledger\" \] || refuse setup-required '/journal setup'#true#" "$order_script"
rm "$order_script.bak"
order_root="$TMP/order-root"; mkdir -p "$order_root"
"$order_script" setup "$order_root" >"$OUT" 2>"$ERR"
if [ -e "$order_root/.records/README.md" ] && [ ! -e "$order_root/.records/history.tsv" ]; then
  pass=$((pass + 1))
else
  echo 'FAIL: README-after-ledger mutation did not turn its fixture red' >&2; fail=$((fail + 1))
fi

ledger_mutant="$TMP/ledger-custody-mutant"; copy_reconciler "$ledger_mutant"
ledger_script="$ledger_mutant/scripts/standup.sh"
expect_eq "ledger custody mutation target is unique" 1 \
  "$(grep -Fc 'if head_has "$ledger_rel" || [ ! -f "$ledger" ] || [ -L "$ledger" ] || [ -s "$ledger" ]; then' "$ledger_script")"
sed -i.bak 's/if head_has "$ledger_rel" || \[ ! -f "$ledger" \] || \[ -L "$ledger" \] || \[ -s "$ledger" \]; then/if false; then/' "$ledger_script"
rm "$ledger_script.bak"
rc=0; "$ledger_script" setup "$dirty_ledger" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "ledger-custody mutation exposes bad acceptance" 0 "$rc"

readme_mutant="$TMP/readme-custody-mutant"; copy_reconciler "$readme_mutant"
readme_script="$readme_mutant/scripts/standup.sh"
expect_eq "README custody mutation target is unique" 1 \
  "$(grep -Fc '"$readme_rel") readme_change_owned ||' "$readme_script")"
sed -i.bak 's/"$readme_rel") readme_change_owned || { IFS=$old_ifs; refuse_detail commit-custody-required "$candidate"; } ;;/"$readme_rel") true ;;/' "$readme_script"
rm "$readme_script.bak"
rc=0; "$readme_script" setup "$dirty" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "README-custody mutation exposes bad acceptance" 0 "$rc"

report setup-resume-test
