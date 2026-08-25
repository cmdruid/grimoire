#!/usr/bin/env bash
# mailbox-test.sh — behavioral proofs for slot minting, patch checks, apply, and reaping.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$DIR/.." && pwd)"
SLOT="$SCRIPTS/mailbox-slot.sh"
APPLY="$SCRIPTS/mailbox-apply.sh"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/mailbox-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
mkdir "$REPO"
REPO="$(cd "$REPO" && pwd -P)"
git -C "$REPO" init -q
git -C "$REPO" config user.name test
git -C "$REPO" config user.email test@example.invalid
printf 'base\n' > "$REPO/example.txt"
git -C "$REPO" add example.txt
git -C "$REPO" commit -qm initial

slot="$($SLOT "$REPO" .patch)"
case "$slot" in "$REPO"/.mailbox/*.patch) pass=$((pass + 1)) ;; *)
  echo "FAIL: slot is not an absolute normalized .patch path: $slot" >&2
  fail=$((fail + 1)) ;;
esac
expect_eq "mailbox directory is ignored" "true" \
  "$(git -C "$REPO" check-ignore -q .mailbox && echo true || echo false)"

second="$($SLOT "$REPO" patch)"
exclude="$(git -C "$REPO" rev-parse --git-path info/exclude)"
case "$exclude" in /*) ;; *) exclude="$REPO/$exclude" ;; esac
expect_eq "exclude registration is idempotent" "1" \
  "$(grep -cFx '.mailbox/' "$exclude")"

printf 'changed\n' > "$REPO/example.txt"
git -C "$REPO" diff > "$slot"
git -C "$REPO" restore example.txt
"$APPLY" "$REPO" "$slot" --check >/dev/null
expect_eq "check preserves slot" "true" "$([ -f "$slot" ] && echo true || echo false)"
expect_file_contains "check leaves tree untouched" "base" "$REPO/example.txt"

"$APPLY" "$REPO" "$slot" >/dev/null
expect_file_contains "apply changes the intended file" "changed" "$REPO/example.txt"
expect_eq "successful apply reaps slot" "false" "$([ -e "$slot" ] && echo true || echo false)"

outside="$TMP/outside.patch"
printf 'not a mailbox patch\n' > "$outside"
if "$APPLY" "$REPO" "$outside" >/dev/null 2>&1; then
  echo "FAIL: outside path was accepted as a mailbox slot" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
expect_eq "outside path is never reaped" "true" "$([ -f "$outside" ] && echo true || echo false)"

bad="$($SLOT "$REPO" patch)"
printf 'invalid patch\n' > "$bad"
if "$APPLY" "$REPO" "$bad" >/dev/null 2>&1; then
  echo "FAIL: invalid patch applied" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
expect_eq "failed patch stays for inspection" "true" "$([ -f "$bad" ] && echo true || echo false)"

mkdir "$REPO/subdir"
if "$SLOT" "$REPO/subdir" patch >/dev/null 2>&1; then
  echo "FAIL: subdirectory accepted as worktree root" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

rm -f "$second"
report "mailbox-test"
