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

write_owner_handoff() { # path owner lock-line
  local path="$1" owner="$2" lock_line="$3"
  cat > "$path" <<EOF
# $owner — workstream hand-off

## Coordinates
- stream:        $owner
- branch:        stream/$owner
- root checkout: $ROOT
- this hand-off: $path

## Resource locks
$lock_line

## Queue state
EOF
}

break_ref() { # resource
  local resource="$1" live
  live="$(git -C "$ROOT" show-ref --verify --hash "refs/workstream-resources/$resource")"
  "$HELPER" break "$ROOT" "$resource" "$live" >/dev/null
}

# Distinct names do not contend.
write_handoff ""
for resource in alpha-dev beta-dev; do
  out="$TMP/$resource.out"
  if "$HELPER" acquire "$ROOT" skill stream/skill "$HANDOFF" "$resource" config-a > "$out"; then
    pass=$((pass + 1))
  else
    echo "FAIL: distinct resource $resource acquired" >&2
    fail=$((fail + 1))
  fi
done
break_ref alpha-dev
break_ref beta-dev

# Same-owner acquire is idempotent only with the canonical token in the hand-off.
idem_out="$TMP/idem.out"
"$HELPER" acquire "$ROOT" skill stream/skill "$HANDOFF" idem-dev config-a > "$idem_out"
idem_oid="$(sed -n 's/^oid=//p' "$idem_out")"
write_handoff "resource-lock: idem-dev $idem_oid"
idem_again="$TMP/idem-again.out"
if "$HELPER" acquire "$ROOT" skill stream/skill "$HANDOFF" idem-dev config-a > "$idem_again"; then
  pass=$((pass + 1))
else
  echo "FAIL: exact same-owner acquire is idempotent" >&2
  fail=$((fail + 1))
fi
expect "idempotent acquire reports ownership" 'already_owned=true' "$idem_again"
write_handoff ""
if "$HELPER" acquire "$ROOT" skill stream/skill "$HANDOFF" idem-dev config-a > "$TMP/idem-missing.out"; then
  echo "FAIL: same owner without canonical token halts" >&2
  fail=$((fail + 1))
else
  expect_eq "same owner missing token exits malformed" 2 "$?"
fi
break_ref idem-dev

# Production compare-and-swap yields one winner; the deliberately unguarded mutant yields two.
RACE_A="$TMP/race-a.md"
RACE_B="$TMP/race-b.md"
write_owner_handoff "$RACE_A" race-a ""
write_owner_handoff "$RACE_B" race-b ""
run_race() { # helper resource out-prefix
  local helper="$1" resource="$2" prefix="$3" p1 p2
  "$helper" acquire "$ROOT" race-a stream/race-a "$RACE_A" "$resource" config-a > "$prefix-a.out" & p1=$!
  "$helper" acquire "$ROOT" race-b stream/race-b "$RACE_B" "$resource" config-b > "$prefix-b.out" & p2=$!
  wait "$p1"; race_rc_a=$?
  wait "$p2"; race_rc_b=$?
}
run_race "$HELPER" race-dev "$TMP/production"
production_successes=0
production_held=0
[ "$race_rc_a" -eq 0 ] && production_successes=$((production_successes + 1))
[ "$race_rc_b" -eq 0 ] && production_successes=$((production_successes + 1))
[ "$race_rc_a" -eq 1 ] && production_held=$((production_held + 1))
[ "$race_rc_b" -eq 1 ] && production_held=$((production_held + 1))
expect_eq "exactly one production contender succeeds" 1 "$production_successes"
expect_eq "exactly one production contender is held" 1 "$production_held"
break_ref race-dev

mutant="$TMP/workstream-resource-mutant.sh"
backup="$TMP/workstream-resource-original.sh"
cp "$HELPER" "$backup"
target='update-ref "$ref" "$new_oid" "$zero"'
expect_eq "red-proof target occurs once" 1 "$(grep -cF "$target" "$HELPER")"
sed 's/update-ref "$ref" "$new_oid" "$zero"/update-ref "$ref" "$new_oid"/' "$HELPER" > "$mutant"
chmod +x "$mutant"
run_race "$mutant" mutant-dev "$TMP/mutant"
mutant_successes=0
[ "$race_rc_a" -eq 0 ] && mutant_successes=$((mutant_successes + 1))
[ "$race_rc_b" -eq 0 ] && mutant_successes=$((mutant_successes + 1))
expect_eq "unguarded mutant proves both contenders can win" 2 "$mutant_successes"
break_ref mutant-dev
cp "$backup" "$mutant"
expect_eq "mutant restoration is byte-identical" 0 "$(cmp "$HELPER" "$mutant"; echo $?)"

# Old claims remain held; malformed claims fail closed and only exact-OID break clears them.
OLD_HANDOFF="$TMP/old.md"
write_owner_handoff "$OLD_HANDOFF" old-owner ""
nonce_file="$(mktemp "${TMPDIR:-/tmp}/resource-old.XXXXXX")"
old_nonce="$(basename "$nonce_file")"
rm -f "$nonce_file"
old_blob="$(printf 'version=1\nresource=old-dev\nowner=old-owner\nbranch=stream/old-owner\nhandoff=%s\nintent=old-config\nacquired_epoch=1\nacquired_at=1970-01-01T00:00:01Z\nnonce=%s\n' "$OLD_HANDOFF" "$old_nonce" | git -C "$ROOT" hash-object -w --stdin)"
git -C "$ROOT" update-ref refs/workstream-resources/old-dev "$old_blob"
old_status="$TMP/old-status.out"
"$HELPER" status "$ROOT" old-dev > "$old_status"
expect "old claim stays held" 'state=held' "$old_status"
expect "old claim reports diagnostic age" 'age_seconds=' "$old_status"
if "$HELPER" acquire "$ROOT" skill stream/skill "$HANDOFF" old-dev fresh > "$TMP/old-acquire.out"; then
  echo "FAIL: old claim blocks acquisition" >&2
  fail=$((fail + 1))
else
  expect_eq "old claim is expected contention" 1 "$?"
fi
break_ref old-dev

malformed_oid="$(printf 'version=2\nresource=bad-dev\n' | git -C "$ROOT" hash-object -w --stdin)"
git -C "$ROOT" update-ref refs/workstream-resources/bad-dev "$malformed_oid"
if "$HELPER" status "$ROOT" bad-dev > "$TMP/malformed-status.out"; then
  echo "FAIL: malformed status fails closed" >&2
  fail=$((fail + 1))
else
  expect_eq "malformed status exits 2" 2 "$?"
fi
expect "malformed status preserves held state" 'held=true' "$TMP/malformed-status.out"
if "$HELPER" acquire "$ROOT" skill stream/skill "$HANDOFF" bad-dev config-a > "$TMP/malformed-acquire.out"; then
  echo "FAIL: malformed claim blocks acquire" >&2
  fail=$((fail + 1))
else
  expect_eq "malformed acquire exits 2" 2 "$?"
fi
if "$HELPER" break "$ROOT" bad-dev "$malformed_oid" > "$TMP/malformed-break.out"; then
  pass=$((pass + 1))
else
  echo "FAIL: exact break clears malformed ref" >&2
  fail=$((fail + 1))
fi
expect "break reports malformed displacement" 'displaced_state=malformed' "$TMP/malformed-break.out"

# Object-format handling derives the OID length from the fixture repository.
SHA_ROOT="$TMP/sha256"
if git init -q --object-format=sha256 "$SHA_ROOT" 2>/dev/null; then
  SHA_HANDOFF="$SHA_ROOT/WORKSTREAM.md"
  cat > "$SHA_HANDOFF" <<EOF
## Resource locks

## Queue state
EOF
  sha_out="$TMP/sha.out"
  if "$HELPER" acquire "$SHA_ROOT" sha-stream stream/sha-stream "$SHA_HANDOFF" sha-dev config-a > "$sha_out"; then
    pass=$((pass + 1))
  else
    echo "FAIL: sha256 acquire succeeds" >&2
    fail=$((fail + 1))
  fi
  sha_oid="$(sed -n 's/^oid=//p' "$sha_out")"
  expect_eq "sha256 oid length is repository-derived" 64 "${#sha_oid}"
  "$HELPER" break "$SHA_ROOT" sha-dev "$sha_oid" >/dev/null
else
  echo "sha256 unavailable: host Git lacks --object-format=sha256"
fi

report "resource-test.sh"
