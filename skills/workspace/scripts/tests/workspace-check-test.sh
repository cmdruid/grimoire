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
run_check "$case_root" .dev .records
expect_eq "absent workspace passes" 0 "$rc"
expect "absent state" "state=absent" "$OUT"

fresh split-valid
mkdir -p \
  "$case_root/.dev/alpha/doctrine/nested" \
  "$case_root/.dev/alpha/hooks" \
  "$case_root/.dev/beta/scripts" \
  "$case_root/.dev/beta/templates/nested" \
  "$case_root/.dev/gamma/trackers" \
  "$case_root/.dev/delta/flows"
printf '# policy\n' >"$case_root/.dev/alpha/doctrine/nested/policy.md"
printf '# hook\n' >"$case_root/.dev/alpha/hooks/after.md"
printf '#!/usr/bin/env bash\n' >"$case_root/.dev/beta/scripts/run.sh"
chmod +x "$case_root/.dev/beta/scripts/run.sh"
printf '# template\n' >"$case_root/.dev/beta/templates/nested/item.md"
printf 'id\tstate\n' >"$case_root/.dev/gamma/trackers/tasks.tsv"
printf '# flow\n' >"$case_root/.dev/delta/flows/release.md"
run_check "$case_root" .dev .records
expect_eq "valid split tree passes" 0 "$rc"
expect "split mode" "mode=split" "$OUT"
expect "split no failures" "fails=0" "$OUT"

for retired in doctrine hooks scripts templates trackers flows; do
  fresh "retired-$retired"
  mkdir -p "$case_root/.dev/$retired"
  run_check "$case_root" .dev .records
  expect_eq "retired $retired fails" 1 "$rc"
  expect "retired $retired reason" "reason=retired-top-level-kind" "$OUT"
done

fresh unknown-kind
mkdir -p "$case_root/.dev/alpha/cache"
run_check "$case_root" .dev .records
expect_eq "unknown kind fails" 1 "$rc"
expect "unknown kind reason" "reason=unknown-kind" "$OUT"

fresh direct-owner-file
mkdir -p "$case_root/.dev/alpha"
printf 'bad\n' >"$case_root/.dev/alpha/direct.md"
run_check "$case_root" .dev .records
expect_eq "direct owner file fails" 1 "$rc"
expect "direct owner reason" "reason=direct-owner-file" "$OUT"

fresh direct-workspace-file
mkdir -p "$case_root/.dev"
printf 'bad\n' >"$case_root/.dev/direct.md"
run_check "$case_root" .dev .records
expect_eq "direct workspace file fails" 1 "$rc"
expect "direct workspace reason" "reason=direct-workspace-file" "$OUT"

fresh invalid-owner
mkdir -p "$case_root/.dev/Bad_Owner/hooks"
printf '# hook\n' >"$case_root/.dev/Bad_Owner/hooks/x.md"
run_check "$case_root" .dev .records
expect_eq "invalid owner fails" 1 "$rc"
expect "invalid owner reason" "reason=invalid-owner" "$OUT"

fresh malformed-kinds
mkdir -p \
  "$case_root/.dev/a/doctrine" \
  "$case_root/.dev/b/hooks/nested" \
  "$case_root/.dev/c/scripts" \
  "$case_root/.dev/d/templates" \
  "$case_root/.dev/e/trackers/nested" \
  "$case_root/.dev/f/flows"
printf 'bad\n' >"$case_root/.dev/a/doctrine/policy.txt"
printf '#!/usr/bin/env bash\n' >"$case_root/.dev/c/scripts/run.sh"
printf '# template\n' >"$case_root/.dev/d/templates/item.md"
ln -s "$case_root/.dev/d/templates/item.md" "$case_root/.dev/d/templates/link.md"
printf 'bad\n' >"$case_root/.dev/f/flows/release.txt"
run_check "$case_root" .dev .records
expect_eq "malformed kind trees fail" 1 "$rc"
for reason in markdown-required direct-files-only script-not-executable symlink-entry; do
  expect "malformed reason $reason" "reason=$reason" "$OUT"
done

fresh owner-symlink
mkdir -p "$case_root/source/hooks" "$case_root/.dev"
printf '# hook\n' >"$case_root/source/hooks/x.md"
ln -s "$case_root/source" "$case_root/.dev/alpha"
run_check "$case_root" .dev .records
expect_eq "symlink owner fails" 1 "$rc"
expect "symlink owner reason" "reason=symlink-owner" "$OUT"

fresh kind-symlink
mkdir -p "$case_root/source" "$case_root/.dev/alpha"
ln -s "$case_root/source" "$case_root/.dev/alpha/hooks"
run_check "$case_root" .dev .records
expect_eq "symlink kind fails" 1 "$rc"
expect "symlink kind reason" "reason=symlink-kind" "$OUT"

fresh coincident
mkdir -p "$case_root/.dev/bugs" "$case_root/.dev/alpha/hooks"
printf 'closed\n' >"$case_root/.dev/history.tsv"
printf '%s\n' '---' 'doctype: bugs' '---' >"$case_root/.dev/bugs/one.md"
printf '# hook\n' >"$case_root/.dev/alpha/hooks/x.md"
run_check "$case_root" .dev .dev
expect_eq "coincident roots pass" 0 "$rc"
expect "coincident mode" "mode=coincident" "$OUT"
expect "record store warns" "reason=coincident-unknown" "$OUT"

fresh coincident-retired
retired="$case_root/.dev/"hooks
mkdir -p "$retired"
run_check "$case_root" .dev .dev
expect_eq "coincident retired kind fails" 1 "$rc"
expect "coincident retired reason" "reason=retired-top-level-kind" "$OUT"

fresh bad-root-escape
run_check "$case_root" ../escape .records
expect_eq "root escape fails" 2 "$rc"
expect "root escape error" "invalid workspace path" "$ERR"

finish
