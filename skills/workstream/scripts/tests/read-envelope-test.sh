#!/usr/bin/env bash
# Common helper responses stay compact and do not expose internal state.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-envelope.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"
OUT="$TMP/out"
trap 'rm -rf "$TMP"' EXIT

git init -q -b main "$ROOT"
git -C "$ROOT" config user.name 'Workstream Test'
git -C "$ROOT" config user.email 'workstream@example.invalid'
printf 'fixture\n' >"$ROOT/file.txt"
git -C "$ROOT" add file.txt
git -C "$ROOT" commit -qm initial

assert_envelope() {
  local label="$1" file="$2" lines longest
  lines="$(awk 'NF{count++} END{print count+0}' "$file")"
  longest="$(awk '{if(length($0)>max)max=length($0)} END{print max+0}' "$file")"
  if [ "$lines" -le 12 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label has $lines nonempty lines" >&2; fi
  if [ "$longest" -le 1024 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label has a $longest-byte line" >&2; fi
  expect_absent "$label hides tracker header" $'record\tid\tfield\tvalue' "$file"
  expect_absent "$label hides hook body" 'feature-completion' "$file"
  expect_absent "$label hides tabular rows" $'meta\t-\t' "$file"
}

"$HELPER" "$ROOT" runtime-init concise main 'Keep runtime reads concise' >"$OUT"
assert_envelope 'runtime-init' "$OUT"
"$HELPER" "$ROOT" state concise >"$OUT"
assert_envelope 'state' "$OUT"
expect 'state identifies schema' 'schema=workstream-state@1' "$OUT"
expect 'state emits one action' 'next_action=define-unit' "$OUT"
expect_eq 'state has one next-action row' 1 "$(grep -c '^next_action=' "$OUT")"

scaffold_bytes="$(wc -c <"$ROOT/.streams/concise/WORKSTREAM.md" | tr -d ' ')"
if [ "$scaffold_bytes" -le 4000 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: generated runbook is $scaffold_bytes bytes" >&2; fi

report 'workstream read envelope'
