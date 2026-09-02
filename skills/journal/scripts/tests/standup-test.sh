#!/usr/bin/env bash
# standup-test.sh — setup order, safety, README ownership, and neutral check route.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
SKILL="$(cd "$DIR/../.." && pwd)"; STANDUP="$SKILL/scripts/standup.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-standup.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

fresh="$TMP/fresh"; mkdir -p "$fresh"
"$STANDUP" setup "$fresh" >"$OUT" 2>"$ERR"
expect "provider reported" 'wrote: .records/records.sh' "$OUT"
expect "ledger reported" 'wrote: .records/history.tsv' "$OUT"
expect "README reported" 'wrote: .records/README.md' "$OUT"
cmp -s "$SKILL/scripts/records.sh" "$fresh/.records/records.sh" && pass=$((pass + 1)) || fail=$((fail + 1))
cmp -s "$SKILL/templates/records-readme-block.md" "$fresh/.records/README.md" && pass=$((pass + 1)) || fail=$((fail + 1))
[ ! -d "$fresh/.records/notes" ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ ! -e "$fresh/.spaces" ] && pass=$((pass + 1)) || fail=$((fail + 1))

incumbent="$TMP/incumbent"; mkdir -p "$incumbent/.records"
printf '# Project records prose without final newline' >"$incumbent/.records/README.md"
cp "$incumbent/.records/README.md" "$TMP/incumbent.before"
"$STANDUP" setup "$incumbent" >"$OUT" 2>"$ERR"
head -c "$(wc -c <"$TMP/incumbent.before" | tr -d '[:space:]')" \
  "$incumbent/.records/README.md" >"$TMP/incumbent.prefix"
cmp -s "$TMP/incumbent.before" "$TMP/incumbent.prefix" && pass=$((pass + 1)) || {
  echo 'FAIL: setup changed incumbent README bytes' >&2; fail=$((fail + 1)); }
expect "managed block appended" '<!-- journal:records-tool BEGIN -->' "$incumbent/.records/README.md"

failure="$TMP/check-failure"; mkdir -p "$failure/.records/notes"
printf '%s\n' '---' 'doctype: notes' 'status: published' 'tags: []' '---' '# Missing schema' \
  >"$failure/.records/notes/2026-09-02-invalid.md"
"$STANDUP" setup "$failure" >"$OUT" 2>"$ERR"
expect "neutral check route" 'records check failed — tool layer is current; action=/journal curate' "$ERR"
expect_absent "neutral route does not prescribe migration" 'migrate verb' "$ERR"

for unsafe_name in records provider ledger readme; do
  root="$TMP/unsafe-$unsafe_name"; mkdir -p "$root/.records" "$root/target"
  case "$unsafe_name" in
    records) rm -rf "$root/.records"; ln -s "$root/target" "$root/.records" ;;
    provider) ln -s "$root/target" "$root/.records/records.sh" ;;
    ledger) ln -s "$root/target" "$root/.records/history.tsv" ;;
    readme) ln -s "$root/target" "$root/.records/README.md" ;;
  esac
  rc=0; "$STANDUP" setup "$root" >"$OUT" 2>"$ERR" || rc=$?
  expect_eq "unsafe $unsafe_name refuses" 2 "$rc"
  if [ "$unsafe_name" != provider ]; then
    [ ! -e "$root/.records/records.sh" ] && pass=$((pass + 1)) || {
      echo "FAIL: unsafe $unsafe_name wrote provider" >&2; fail=$((fail + 1)); }
  fi
done

race="$TMP/race"; mkdir -p "$race" "$TMP/race-target"
hook="$TMP/swap-parent.sh"
printf '%s\n' '#!/bin/sh' 'ln -s "$3" "$1/.records"' >"$hook"
# Supply the external target through a wrapper because the production hook has a fixed signature.
sed -i.bak "s|\$3|$TMP/race-target|" "$hook"; rm "$hook.bak"; chmod 755 "$hook"
rc=0; JOURNAL_SETUP_TEST_AFTER_PREFLIGHT="$hook" "$STANDUP" setup "$race" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "parent swap refuses" 2 "$rc"
[ -z "$(find "$TMP/race-target" -mindepth 1 -print -quit)" ] && pass=$((pass + 1)) || {
  echo 'FAIL: parent swap escaped records root' >&2; fail=$((fail + 1)); }

report standup-test
