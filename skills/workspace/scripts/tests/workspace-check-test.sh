#!/usr/bin/env bash
set -u
# shellcheck disable=SC2034,SC2154  # CHECK/rc cross the sourced test library

DIR="$(CDPATH='' cd "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd "$DIR/../.." && pwd)"
CHECK="$SKILL/scripts/workspace-check.sh"
export CHECK
rc=0
# shellcheck disable=SC1091  # resolved from this package
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/workspace-check-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"
ERR="$TMP/err"

fresh() {
  case_root="$TMP/$1"
  mkdir -p "$case_root"
}

fresh absent
run_check "$case_root" .spaces .records
expect_eq "absent workspace passes" 0 "$rc"
expect "absent state" "state=absent" "$OUT"

fresh split-valid
mkdir -p \
  "$case_root/.spaces/alpha/doctrine/nested" \
  "$case_root/.spaces/alpha/drafts/nested" \
  "$case_root/.spaces/alpha/hooks" \
  "$case_root/.spaces/beta/scripts" \
  "$case_root/.spaces/beta/templates/nested" \
  "$case_root/.trackers" \
  "$case_root/.spaces/delta/operations"
printf '# policy\n' >"$case_root/.spaces/alpha/doctrine/nested/policy.md"
printf '# idea\n' >"$case_root/.spaces/alpha/drafts/nested/idea.md"
printf '# hook\n' >"$case_root/.spaces/alpha/hooks/after.md"
printf '#!/usr/bin/env bash\n' >"$case_root/.spaces/beta/scripts/run.sh"
chmod +x "$case_root/.spaces/beta/scripts/run.sh"
printf '# template\n' >"$case_root/.spaces/beta/templates/nested/item.md"
printf 'id\tstate\n' >"$case_root/.trackers/tasks.tsv"
printf '# operation\n' >"$case_root/.spaces/delta/operations/release.md"
run_check "$case_root" .spaces .records
expect_eq "valid split tree passes" 0 "$rc"
expect "fixed mode" "mode=fixed" "$OUT"
expect "split no failures" "fails=0" "$OUT"

for retired in doctrine drafts hooks operations scripts templates; do
  fresh "retired-$retired"
  mkdir -p "$case_root/.spaces/$retired"
  run_check "$case_root" .spaces .records
  expect_eq "retired $retired fails" 1 "$rc"
  expect "retired $retired reason" "reason=retired-top-level-kind" "$OUT"
done

fresh owner-local-trackers
owner_local_tracker="$case_root/.spaces/gamma/""trackers"
mkdir -p "$owner_local_tracker"
run_check "$case_root" .spaces .records
expect_eq "owner-local trackers fail" 1 "$rc"
expect "owner-local trackers reason" "reason=unknown-kind" "$OUT"

fresh unknown-kind
mkdir -p "$case_root/.spaces/alpha/cache"
run_check "$case_root" .spaces .records
expect_eq "unknown kind fails" 1 "$rc"
expect "unknown kind reason" "reason=unknown-kind" "$OUT"

fresh direct-owner-file
mkdir -p "$case_root/.spaces/alpha"
printf 'bad\n' >"$case_root/.spaces/alpha/direct.md"
run_check "$case_root" .spaces .records
expect_eq "direct owner file fails" 1 "$rc"
expect "direct owner reason" "reason=direct-owner-file" "$OUT"

fresh direct-workspace-file
mkdir -p "$case_root/.spaces"
printf 'bad\n' >"$case_root/.spaces/direct.md"
run_check "$case_root" .spaces .records
expect_eq "direct workspace file fails" 1 "$rc"
expect "direct workspace reason" "reason=direct-workspace-file" "$OUT"

fresh invalid-owner
mkdir -p "$case_root/.spaces/Bad_Owner/hooks"
printf '# hook\n' >"$case_root/.spaces/Bad_Owner/hooks/x.md"
run_check "$case_root" .spaces .records
expect_eq "invalid owner fails" 1 "$rc"
expect "invalid owner reason" "reason=invalid-owner" "$OUT"

fresh malformed-kinds
mkdir -p \
  "$case_root/.spaces/a/doctrine" \
  "$case_root/.spaces/a/drafts" \
  "$case_root/.spaces/b/hooks/nested" \
  "$case_root/.spaces/c/scripts" \
  "$case_root/.spaces/d/templates" \
  "$case_root/.spaces/f/operations"
printf 'bad\n' >"$case_root/.spaces/a/doctrine/policy.txt"
printf 'bad\n' >"$case_root/.spaces/a/drafts/idea.txt"
printf '#!/usr/bin/env bash\n' >"$case_root/.spaces/c/scripts/run.sh"
printf '# template\n' >"$case_root/.spaces/d/templates/item.md"
ln -s "$case_root/.spaces/d/templates/item.md" "$case_root/.spaces/d/templates/link.md"
printf 'bad\n' >"$case_root/.spaces/f/operations/release.txt"
run_check "$case_root" .spaces .records
expect_eq "malformed kind trees fail" 1 "$rc"
for reason in markdown-required direct-files-only script-not-executable symlink-entry; do
  expect "malformed reason $reason" "reason=$reason" "$OUT"
done

fresh owner-symlink
mkdir -p "$case_root/source/hooks" "$case_root/.spaces"
printf '# hook\n' >"$case_root/source/hooks/x.md"
ln -s "$case_root/source" "$case_root/.spaces/alpha"
run_check "$case_root" .spaces .records
expect_eq "symlink owner fails" 1 "$rc"
expect "symlink owner reason" "reason=symlink-owner" "$OUT"

fresh kind-symlink
mkdir -p "$case_root/source" "$case_root/.spaces/alpha"
ln -s "$case_root/source" "$case_root/.spaces/alpha/hooks"
run_check "$case_root" .spaces .records
expect_eq "symlink kind fails" 1 "$rc"
expect "symlink kind reason" "reason=symlink-kind" "$OUT"

# Noncanonical content is ignored; retired selectors refuse without changing it.
fresh noncanonical-canary
mkdir -p "$case_root/dev/alpha/hooks"; printf 'CANARY\n'>"$case_root/dev/alpha/hooks/x.md"
run_check "$case_root" dev .records
expect_eq "noncanonical canary does not affect fixed workspace" 0 "$rc"
expect "fixed workspace remains absent" "state=absent" "$OUT"
rc=0; "$CHECK" --root "$case_root" --workspace dev >"$OUT" 2>"$ERR" || rc=$?
expect_eq "retired workspace selector refuses" 2 "$rc"
expect "noncanonical canary preserved" "CANARY" "$case_root/dev/alpha/hooks/x.md"

fresh symlink-workspace
mkdir -p "$case_root/outside"; ln -s "$case_root/outside" "$case_root/.spaces"
run_check "$case_root" .spaces .records
expect_eq "symlink workspace fails" 1 "$rc"
expect "symlink workspace reason" "reason=symlink-workspace" "$OUT"

finish
