#!/usr/bin/env bash
# anchor-test.sh — versioned recovery-anchor classification fixtures.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
ANCHOR_SH="${ANCHOR_SH:-$DIR/../anchor-status.sh}"
TEMPLATE="${ANCHOR_TEMPLATE:-$DIR/../../templates/recovery-anchor.md}"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
OUT="$T/out"

run_status() {
  if bash "$ANCHOR_SH" "$TEMPLATE" "$1" > "$OUT" 2>&1; then
    rc=0
  else
    rc=$?
  fi
}

printf '# Project instructions\n' > "$T/absent.md"
run_status "$T/absent.md"
expect_eq "absent anchor exits 0" 0 "$rc"
expect "absent anchor classified" "anchor_status=absent" "$OUT"

{
  printf '# Project instructions\n\n'
  printf '## Checkpoint recovery\n\n'
  printf 'If `CHECKPOINT.md` exists, read it in full after compaction.\n'
} > "$T/legacy.md"
run_status "$T/legacy.md"
expect_eq "legacy anchor exits 0" 0 "$rc"
expect "legacy anchor classified" "anchor_status=obsolete-unversioned" "$OUT"
expect "legacy anchor begins at its H2" "anchor_begin_line=3" "$OUT"
expect "legacy anchor ends at EOF" "anchor_end_line=5" "$OUT"

{
  printf '# Project instructions\n\n'
  printf '## Checkpoint recovery\n\nLegacy body.\n\n'
  printf '## Other instructions\n\nKeep me.\n'
} > "$T/legacy-bounded.md"
run_status "$T/legacy-bounded.md"
expect_eq "bounded legacy anchor exits 0" 0 "$rc"
expect "bounded legacy anchor begins at its H2" "anchor_begin_line=3" "$OUT"
expect "bounded legacy anchor stops before next H2" "anchor_end_line=6" "$OUT"

{
  printf '# Project instructions\n\n'
  cat "$TEMPLATE"
  printf '\n## Other instructions\n'
} > "$T/current.md"
cp "$T/current.md" "$T/current.before"
run_status "$T/current.md"
expect_eq "current anchor exits 0" 0 "$rc"
expect "current anchor classified" "anchor_status=current" "$OUT"
if cmp -s "$T/current.before" "$T/current.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: status probe mutated the front door" >&2
  fail=$((fail + 1))
fi

sed 's/Presence of root/Presence of local/' "$TEMPLATE" > "$T/drift-block"
{
  printf '# Project instructions\n\n'
  cat "$T/drift-block"
} > "$T/drifted.md"
run_status "$T/drifted.md"
expect_eq "drifted anchor exits 0" 0 "$rc"
expect "drifted anchor classified" "anchor_status=drifted-current" "$OUT"

sed 's/recovery-anchor@1/recovery-anchor@2/' "$TEMPLATE" > "$T/v2-block"
{
  printf '# Project instructions\n\n'
  cat "$T/v2-block"
} > "$T/v2.md"
run_status "$T/v2.md"
expect_eq "other-version anchor exits 0" 0 "$rc"
expect "other-version anchor is obsolete" "anchor_status=obsolete-versioned" "$OUT"

{
  printf '# Project instructions\n\n'
  printf '<!-- checkpoint:recovery-anchor@1 -->\n'
  printf '## Checkpoint recovery\n'
} > "$T/malformed.md"
run_status "$T/malformed.md"
expect_eq "malformed anchor exits 1" 1 "$rc"
expect "malformed anchor classified" "anchor_status=malformed" "$OUT"

{
  printf '<!-- /checkpoint:recovery-anchor -->\n'
  sed '$d' "$TEMPLATE"
} > "$T/inverted.md"
run_status "$T/inverted.md"
expect_eq "inverted boundaries exit 1" 1 "$rc"
expect "inverted boundaries are malformed" "anchor_status=malformed" "$OUT"

{
  printf '<!-- checkpoint:recovery-anchor@1 -->\n'
  printf 'No heading in this block.\n'
  printf '<!-- /checkpoint:recovery-anchor -->\n'
  printf '## Checkpoint recovery\n'
} > "$T/heading-outside.md"
run_status "$T/heading-outside.md"
expect_eq "heading outside boundaries exits 1" 1 "$rc"
expect "heading outside boundaries is malformed" "anchor_status=malformed" "$OUT"

{
  cat "$TEMPLATE"
  printf '\n'
  cat "$TEMPLATE"
} > "$T/duplicate.md"
run_status "$T/duplicate.md"
expect_eq "duplicate anchor exits 1" 1 "$rc"
expect "duplicate anchor classified" "anchor_status=duplicate" "$OUT"

run_status "$T/missing.md"
expect_eq "missing front door exits 0" 0 "$rc"
expect "missing front door classified" "anchor_status=missing" "$OUT"

mkdir "$T/invalid"
run_status "$T/invalid"
expect_eq "invalid front door exits 1" 1 "$rc"
expect "invalid front door classified" "anchor_status=invalid" "$OUT"

finish "checkpoint anchor"
