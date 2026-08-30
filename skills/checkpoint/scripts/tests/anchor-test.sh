#!/usr/bin/env bash
# anchor-test.sh — v2-only lifecycle/recovery-anchor classification fixtures.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
ANCHOR_SH="${ANCHOR_SH:-$DIR/../anchor-status.sh}"
TEMPLATE="${ANCHOR_TEMPLATE:-$DIR/../../templates/recovery-anchor.md}"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
OUT="$T/out"

run_status() {
  if bash "$ANCHOR_SH" "$TEMPLATE" "$1" > "$OUT" 2>&1; then rc=0; else rc=$?; fi
}

printf '# Project instructions\n' > "$T/absent.md"
run_status "$T/absent.md"
expect_eq "absent anchor exits 0" 0 "$rc"
expect "absent anchor classified" "anchor_status=absent" "$OUT"

run_status "$T/missing.md"
expect_eq "missing front door is appendable" 0 "$rc"
expect "missing front door classified absent" "anchor_status=absent" "$OUT"
expect "missing front door reported" "anchor_target_missing=true" "$OUT"

{
  printf '# Project instructions\n\n'
  cat "$TEMPLATE"
  printf '\n## Other instructions\n'
} > "$T/current.md"
cp "$T/current.md" "$T/current.before"
run_status "$T/current.md"
expect_eq "current anchor exits 0" 0 "$rc"
expect "current anchor classified" "anchor_status=current" "$OUT"
expect "current anchor begins after project heading" "anchor_begin_line=3" "$OUT"
cmp -s "$T/current.before" "$T/current.md" && pass=$((pass + 1)) || fail=$((fail + 1))

sed 's/Each refresh reports/Every refresh reports/' "$TEMPLATE" > "$T/drift-block"
{
  printf '# Project instructions\n\n'
  cat "$T/drift-block"
} > "$T/drifted.md"
run_status "$T/drifted.md"
expect_eq "drifted v2 exits 0" 0 "$rc"
expect "drifted v2 classified" "anchor_status=drifted-current" "$OUT"
expect "drifted v2 emits exact begin" "anchor_begin_line=3" "$OUT"

{
  printf '# Project instructions\n\n'
  printf '<!-- checkpoint:recovery-anchor@opaque-x -->\n'
  printf '## Arbitrary bounded content\n\nDo not parse me.\n'
  printf '<!-- /checkpoint:recovery-anchor -->\n'
  printf '\n## Other instructions\n\nKeep me.\n'
} > "$T/conflict.md"
run_status "$T/conflict.md"
expect_eq "generic conflict exits 0" 0 "$rc"
expect "generic conflict classified" "anchor_status=conflict" "$OUT"
expect "generic conflict begins at marker" "anchor_begin_line=3" "$OUT"
expect "generic conflict ends at marker" "anchor_end_line=7" "$OUT"
expect_absent "generic conflict never reports opaque suffix" "opaque-x" "$OUT"

{
  printf '# Project instructions\n\n'
  printf '## Checkpoint notes\n\nUnmarked collision.\n'
} > "$T/unmarked-heading.md"
run_status "$T/unmarked-heading.md"
expect_eq "unmarked Checkpoint H2 refuses" 1 "$rc"
expect "unmarked Checkpoint H2 reports error" "anchor_error=reserved-heading" "$OUT"
expect_absent "unmarked Checkpoint H2 emits no extent" "anchor_begin_line=" "$OUT"

{
  printf '# Project instructions\n\n'
  printf '   ## Checkpoint recovery\n\nIndented structural collision.\n'
} > "$T/indented-heading.md"
run_status "$T/indented-heading.md"
expect_eq "three-space-indented Checkpoint H2 refuses" 1 "$rc"
expect "indented Checkpoint H2 reports error" "anchor_error=reserved-heading" "$OUT"

{
  printf '# Project instructions\n\n'
  printf '    ## Checkpoint code example\n'
} > "$T/four-space-code.md"
run_status "$T/four-space-code.md"
expect_eq "four-space-indented Checkpoint example is ignored" 0 "$rc"
expect "indented code remains absent" "anchor_status=absent" "$OUT"

{
  printf '# Project instructions\n\n'
  printf '## Checkpointing notes\n\nPrefix collision.\n'
} > "$T/prefix-heading.md"
run_status "$T/prefix-heading.md"
expect_eq "Checkpoint-prefixed H2 refuses" 1 "$rc"
expect "Checkpoint-prefixed H2 reports error" "anchor_error=reserved-heading" "$OUT"

{
  printf '# Project instructions\n\n'
  printf '````markdown\n## Checkpoint example\n````\n'
} > "$T/long-fence-only.md"
run_status "$T/long-fence-only.md"
expect_eq "Checkpoint H2 inside long fence is ignored" 0 "$rc"
expect "long fenced example remains absent" "anchor_status=absent" "$OUT"

{
  printf '# Project instructions\n\n'
  printf '````markdown\n## Checkpoint example\n```\n## Checkpoint still fenced\n````\n'
} > "$T/short-fence-close.md"
run_status "$T/short-fence-close.md"
expect_eq "shorter fence does not close long fence" 0 "$rc"
expect "content behind short close remains absent" "anchor_status=absent" "$OUT"

{
  printf '# Project instructions\n\n'
  printf '~~~~markdown\n## Checkpoint example\n````\n## Checkpoint still fenced\n~~~~\n'
} > "$T/mismatched-fence-close.md"
run_status "$T/mismatched-fence-close.md"
expect_eq "different fence marker does not close fence" 0 "$rc"
expect "content behind different marker remains absent" "anchor_status=absent" "$OUT"

{
  printf '# Project instructions\n\n'
  printf '````markdown\n## Checkpoint example\n````\n\n'
  printf '## Checkpoint recovery\n\nCollision after closed long fence.\n'
} > "$T/long-fence-then-heading.md"
run_status "$T/long-fence-then-heading.md"
expect_eq "Checkpoint H2 after closed long fence refuses" 1 "$rc"
expect "post-fence Checkpoint H2 reports error" "anchor_error=reserved-heading" "$OUT"

{
  printf '# Project instructions\n'
  printf '<!-- checkpoint:recovery-anchor@opaque-x -->\n'
} > "$T/unmatched-begin.md"
run_status "$T/unmatched-begin.md"
expect_eq "unmatched begin refuses" 1 "$rc"
expect_absent "unmatched begin emits no extent" "anchor_begin_line=" "$OUT"

{
  printf '# Project instructions\n'
  printf '<!-- /checkpoint:recovery-anchor -->\n'
} > "$T/unmatched-end.md"
run_status "$T/unmatched-end.md"
expect_eq "unmatched end refuses" 1 "$rc"
expect_absent "unmatched end emits no extent" "anchor_begin_line=" "$OUT"

{
  cat "$TEMPLATE"
  printf '\n'
  cat "$TEMPLATE"
} > "$T/duplicate.md"
run_status "$T/duplicate.md"
expect_eq "duplicate anchor refuses" 1 "$rc"
expect_absent "duplicate anchor emits no extent" "anchor_begin_line=" "$OUT"

{
  printf '<!-- checkpoint:recovery-anchor@opaque-a -->\n'
  printf '<!-- checkpoint:recovery-anchor@opaque-b -->\n'
  printf '<!-- /checkpoint:recovery-anchor -->\n'
} > "$T/nested.md"
run_status "$T/nested.md"
expect_eq "nested markers refuse" 1 "$rc"
expect_absent "nested markers emit no extent" "anchor_begin_line=" "$OUT"

{
  printf '<!-- /checkpoint:recovery-anchor -->\n'
  printf '<!-- checkpoint:recovery-anchor@opaque-x -->\n'
} > "$T/inverted.md"
run_status "$T/inverted.md"
expect_eq "inverted markers refuse" 1 "$rc"
expect_absent "inverted markers emit no extent" "anchor_begin_line=" "$OUT"

{
  printf '<!-- checkpoint:recovery-anchor@opaque-x -->\n'
  printf 'bounded\n'
  printf '<!-- /checkpoint:recovery-anchor -->\n'
  printf '## Checkpoint extra\n'
} > "$T/mixed.md"
run_status "$T/mixed.md"
expect_eq "heading outside bounded block refuses" 1 "$rc"
expect_absent "mixed content emits no extent" "anchor_begin_line=" "$OUT"

mkdir "$T/invalid"
run_status "$T/invalid"
expect_eq "directory target refuses" 1 "$rc"
expect "directory target reports invalid" "anchor_error=invalid-target" "$OUT"
printf '# private\n' > "$T/private.md"; ln -s private.md "$T/symlink.md"
run_status "$T/symlink.md"
expect_eq "symlink target refuses" 1 "$rc"

cp "$TEMPLATE" "$T/invalid-template.md"
sed -i.bak '1s/@2/@broken/' "$T/invalid-template.md"
if bash "$ANCHOR_SH" "$T/invalid-template.md" "$T/absent.md" > "$OUT" 2>&1; then rc=0; else rc=$?; fi
expect_eq "invalid template refuses" 2 "$rc"
expect "invalid template reports error" "anchor_error=invalid-template" "$OUT"

finish "checkpoint anchor"
