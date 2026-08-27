#!/usr/bin/env bash
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
HELPER="$SKILL/scripts/workstream-resource.sh"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-resource-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/repo"
WT="$TMP/skill-wt"
HANDOFF="$WT/WORKSTREAM.md"

git init -q -b main "$ROOT"
git -C "$ROOT" config user.email test@example.invalid
git -C "$ROOT" config user.name Test
printf 'seed\n' > "$ROOT/README.md"
git -C "$ROOT" add README.md
git -C "$ROOT" commit -qm seed
git -C "$ROOT" worktree add -qb stream/skill "$WT" main

write_handoff() {
  cat > "$HANDOFF" <<EOF
# skill — workstream hand-off

## Coordinates
- stream:        skill
- branch:        stream/skill
- integration-target: main
- worktree:      $WT
- root checkout: $ROOT
- this hand-off: $HANDOFF

## Resource locks
$1

## Queue state
- Current feature: fixture.
EOF
}

write_handoff ""
before_root="$(git -C "$ROOT" status --short)"
before_wt="$(git -C "$WT" status --short)"

acquire_out="$TMP/acquire.out"
if "$HELPER" acquire "$ROOT" skill stream/skill "$HANDOFF" ducat-dev config-a > "$acquire_out"; then
  pass=$((pass + 1))
else
  echo "FAIL: acquire succeeds" >&2
  fail=$((fail + 1))
fi
expect "acquire reports state" 'state=acquired' "$acquire_out"
oid="$(sed -n 's/^oid=//p' "$acquire_out")"
expect_eq "acquire returns one oid" 1 "$([ -n "$oid" ] && echo 1 || echo 0)"

write_handoff "resource-lock: ducat-dev $oid"
validate_out="$TMP/validate.out"
if "$HELPER" validate "$ROOT" skill "$HANDOFF" > "$validate_out"; then
  pass=$((pass + 1))
else
  echo "FAIL: matching hand-off validates" >&2
  fail=$((fail + 1))
fi
expect "validate reports one held" 'held_count=1' "$validate_out"

for checkout in "$ROOT" "$WT"; do
  status_out="$TMP/status-$(basename "$checkout").out"
  if "$HELPER" status "$checkout" ducat-dev > "$status_out"; then
    pass=$((pass + 1))
  else
    echo "FAIL: status succeeds from $checkout" >&2
    fail=$((fail + 1))
  fi
  expect "status reports holder from $(basename "$checkout")" 'owner=skill' "$status_out"
done

expect_eq "claim leaves root clean" "$before_root" "$(git -C "$ROOT" status --short)"
expect_eq "claim leaves worktree clean" "$before_wt" "$(git -C "$WT" status --short)"

wrong_oid="$(printf 'wrong token' | git -C "$ROOT" hash-object -w --stdin)"
wrong_out="$TMP/wrong.out"
if "$HELPER" rollback "$ROOT" ducat-dev "$wrong_oid" > "$wrong_out" 2>&1; then
  echo "FAIL: wrong-token rollback rejected" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
expect_eq "wrong token preserves claim" "$oid" "$(git -C "$ROOT" rev-parse refs/workstream-resources/ducat-dev)"

release_out="$TMP/release.out"
if "$HELPER" release "$ROOT" skill "$HANDOFF" ducat-dev > "$release_out"; then
  pass=$((pass + 1))
else
  echo "FAIL: release succeeds" >&2
  fail=$((fail + 1))
fi
expect "release reports state" 'state=released' "$release_out"
write_handoff ""
expect_eq "released ref absent" 1 "$(git -C "$ROOT" show-ref --verify --quiet refs/workstream-resources/ducat-dev; echo $?)"

report "resource-test.sh"
