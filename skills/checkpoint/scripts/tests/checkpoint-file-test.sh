#!/usr/bin/env bash
# checkpoint-file-test.sh — single-root identity and mutation fixtures.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/lib.sh"
FILE_SH="${FILE_SH:-$DIR/../checkpoint-file.sh}"

T="$(mktemp -d)"; T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT
OUT="$T/out"

run() {
  if bash "$FILE_SH" "$@" >"$OUT" 2>&1; then rc=0; else rc=$?; fi
}
token_for() { bash "$FILE_SH" token; }
write_doc() { # root token body
  printf '# CHECKPOINT — file: %s/CHECKPOINT.md\n' "$1"
  printf 'checkpoint-token: %s\n\n%s\n' "$2" "$3"
}

if [ -x "$FILE_SH" ]; then pass=$((pass + 1)); else
  echo "FAIL: checkpoint-file.sh is not executable" >&2; fail=$((fail + 1))
fi

token="$(token_for 2>/dev/null || true)"
printf '%s\n' "$token" >"$T/token"
expect_match "token is 128-bit lowercase hex" '^[0-9a-f]{32}$' "$T/token"

# Plain-root create, refresh, admission, claim, and delete.
root="$T/plain"; mkdir "$root"
write_doc "$root" "$token" "FIRST BODY" | bash "$FILE_SH" save "$root" new >"$OUT" 2>&1
expect "create reports handle" "CHECKPOINT — file: $root/CHECKPOINT.md — token: $token" "$OUT"
expect "create writes body" "FIRST BODY" "$root/CHECKPOINT.md"
[ ! -e "$root/CHECKPOINT.md.tmp" ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ ! -e "$root/.CHECKPOINT.lock" ] && pass=$((pass + 1)) || fail=$((fail + 1))

write_doc "$root" "$token" "REFRESHED BODY" | bash "$FILE_SH" save "$root" "$token" >"$OUT" 2>&1
expect "refresh replaces body" "REFRESHED BODY" "$root/CHECKPOINT.md"
expect "refresh preserves token" "checkpoint-token: $token" "$root/CHECKPOINT.md"

before="$T/before"; cp "$root/CHECKPOINT.md" "$before"
other="$(token_for)"
if write_doc "$root" "$other" "CLOBBER" | bash "$FILE_SH" save "$root" new >"$OUT" 2>&1; then rc=0; else rc=$?; fi
expect_eq "second first-save refuses" 1 "$rc"
cmp -s "$before" "$root/CHECKPOINT.md" && pass=$((pass + 1)) || fail=$((fail + 1))

# A foreign-session probe is body/token-free; guarded overwrite replaces only the probed bytes.
foreign="$T/foreign"; mkdir "$foreign"; foreign_token="$(token_for)"
write_doc "$foreign" "$foreign_token" "FOREIGN PRIVATE BODY" |
  bash "$FILE_SH" save "$foreign" new >/dev/null 2>&1
run occupancy "$foreign"
expect_eq "valid foreign occupancy succeeds" 0 "$rc"
expect "valid foreign occupancy classified" "checkpoint_occupancy=valid" "$OUT"
foreign_fingerprint="$(sed -n 's/^checkpoint_fingerprint=//p' "$OUT")"
printf '%s\n' "$foreign_fingerprint" > "$T/foreign-fingerprint"
expect_match "foreign occupancy emits opaque fingerprint" '^[0-9a-f]{64}$' "$T/foreign-fingerprint"
expect_absent "foreign occupancy discloses no body" "FOREIGN PRIVATE BODY" "$OUT"
expect_absent "foreign occupancy discloses no token" "$foreign_token" "$OUT"

cp "$foreign/CHECKPOINT.md" "$T/foreign-before"
foreign_new="$(token_for)"
write_doc "$foreign" "$foreign_new" "REPLACEMENT BODY" |
  bash "$FILE_SH" overwrite "$foreign" "$foreign_fingerprint" > "$OUT" 2>&1
expect "overwrite reports replacement handle" "CHECKPOINT — file: $foreign/CHECKPOINT.md — token: $foreign_new" "$OUT"
expect "overwrite publishes replacement body" "REPLACEMENT BODY" "$foreign/CHECKPOINT.md"
expect_absent "overwrite removes foreign body" "FOREIGN PRIVATE BODY" "$foreign/CHECKPOINT.md"
[ "$foreign_new" != "$foreign_token" ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ ! -e "$foreign/CHECKPOINT.md.tmp" ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ ! -e "$foreign/.CHECKPOINT.lock" ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ ! -e "$foreign/CHECKPOINT.md.bak" ] && pass=$((pass + 1)) || fail=$((fail + 1))

run occupancy "$foreign"; same_fingerprint="$(sed -n 's/^checkpoint_fingerprint=//p' "$OUT")"
cp "$foreign/CHECKPOINT.md" "$T/foreign-same-token-before"
if write_doc "$foreign" "$foreign_new" "SAME TOKEN" |
  bash "$FILE_SH" overwrite "$foreign" "$same_fingerprint" > "$OUT" 2>&1; then rc=0; else rc=$?; fi
expect_eq "overwrite requires a fresh token" 1 "$rc"
cmp -s "$T/foreign-same-token-before" "$foreign/CHECKPOINT.md" && pass=$((pass + 1)) || fail=$((fail + 1))

missing="$T/missing-occupancy"; mkdir "$missing"
run occupancy "$missing"
expect_eq "missing occupancy refuses" 1 "$rc"
expect_absent "missing occupancy emits no fingerprint" "checkpoint_fingerprint=" "$OUT"

malformed="$T/malformed-occupancy"; mkdir "$malformed"
printf 'MALFORMED PRIVATE BODY\ncheckpoint-token: %s\n' "$foreign_token" > "$malformed/CHECKPOINT.md"
run occupancy "$malformed"
expect_eq "malformed occupancy refuses" 1 "$rc"
expect_absent "malformed occupancy discloses no body" "MALFORMED PRIVATE BODY" "$OUT"
expect_absent "malformed occupancy discloses no token" "$foreign_token" "$OUT"

symlinked="$T/symlinked-occupancy"; mkdir "$symlinked"
printf 'SYMLINK PRIVATE BODY\n' > "$symlinked/private"
ln -s private "$symlinked/CHECKPOINT.md"
run occupancy "$symlinked"
expect_eq "symlink occupancy refuses" 1 "$rc"
expect_absent "symlink occupancy discloses no body" "SYMLINK PRIVATE BODY" "$OUT"

# Overwrite revalidates the probed fingerprint after the complete candidate has been read.
overwrite_race="$T/overwrite-race"; mkdir "$overwrite_race"
overwrite_old="$(token_for)"; overwrite_new="$(token_for)"
write_doc "$overwrite_race" "$overwrite_old" ORIGINAL |
  bash "$FILE_SH" save "$overwrite_race" new >/dev/null 2>&1
run occupancy "$overwrite_race"
overwrite_fingerprint="$(sed -n 's/^checkpoint_fingerprint=//p' "$OUT")"
mkfifo "$overwrite_race/input.fifo"
bash "$FILE_SH" overwrite "$overwrite_race" "$overwrite_fingerprint" < "$overwrite_race/input.fifo" \
  > "$T/overwrite-race.out" 2>&1 & overwrite_pid=$!
exec 4>"$overwrite_race/input.fifo"
tries=0
while [ ! -f "$overwrite_race/CHECKPOINT.md.tmp" ] && [ "$tries" -lt 100 ]; do sleep 0.01; tries=$((tries + 1)); done
if [ -f "$overwrite_race/CHECKPOINT.md.tmp" ]; then pass=$((pass + 1)); else
  echo "FAIL: overwrite fixture never reached candidate render" >&2; fail=$((fail + 1))
fi
write_doc "$overwrite_race" "$overwrite_old" "FOREIGN CHANGE DURING OVERWRITE" > "$overwrite_race/CHECKPOINT.md"
write_doc "$overwrite_race" "$overwrite_new" "OVERWRITE CANDIDATE" >&4
exec 4>&-
if wait "$overwrite_pid"; then overwrite_rc=0; else overwrite_rc=$?; fi
expect_eq "overwrite refuses a target changed after probe" 1 "$overwrite_rc"
expect "changed overwrite preserves foreign body" "FOREIGN CHANGE DURING OVERWRITE" "$overwrite_race/CHECKPOINT.md"
expect_absent "changed overwrite does not publish candidate" "OVERWRITE CANDIDATE" "$overwrite_race/CHECKPOINT.md"
[ ! -e "$overwrite_race/CHECKPOINT.md.tmp" ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ ! -e "$overwrite_race/.CHECKPOINT.lock" ] && pass=$((pass + 1)) || fail=$((fail + 1))

handle="CHECKPOINT — file: $root/CHECKPOINT.md — token: $token"
run admit "$root" "$handle"
expect_eq "matching recovery handle admits" 0 "$rc"
expect "admission reports match" "token_match=true" "$OUT"
expect "admission emits body" "REFRESHED BODY" "$OUT"

wrong="00000000000000000000000000000000"; [ "$wrong" != "$token" ] || wrong="11111111111111111111111111111111"
run admit "$root" "CHECKPOINT — file: $root/CHECKPOINT.md — token: $wrong"
expect_eq "wrong recovery token refuses" 1 "$rc"
expect "wrong recovery token reports false" "token_match=false" "$OUT"
expect_absent "wrong recovery token discloses no body" "REFRESHED BODY" "$OUT"
expect_absent "wrong recovery token discloses no stored token" "$token" "$OUT"

run admit "$root" "CHECKPOINT — file: $T/other/CHECKPOINT.md — token: $token"
expect_eq "wrong recovery path refuses" 1 "$rc"
expect_absent "wrong recovery path discloses no body" "REFRESHED BODY" "$OUT"
run admit "$root" "CHECKPOINT — file: $root/CHECKPOINT.md"
expect_eq "handle without token refuses" 1 "$rc"
run admit "$root" "$handle $handle"
expect_eq "multiple handles refuse" 1 "$rc"

run inspect "$root"
expect_eq "explicit inspect succeeds" 0 "$rc"
expect "inspect emits body" "REFRESHED BODY" "$OUT"
fingerprint="$(sed -n 's/^checkpoint_fingerprint=//p' "$OUT")"
printf '%s\n' "$fingerprint" >"$T/fingerprint"
expect_match "inspect emits fingerprint" '^[0-9a-f]{64}$' "$T/fingerprint"

run claim "$root" "$token" "$fingerprint"
expect_eq "confirmed claim succeeds" 0 "$rc"
new_token="$(sed -n 's/^checkpoint_token=//p' "$OUT")"
[ "$new_token" != "$token" ] && pass=$((pass + 1)) || fail=$((fail + 1))
expect "claim preserves body" "REFRESHED BODY" "$root/CHECKPOINT.md"
run match "$root" "$handle"
expect_eq "old handle is revoked" 1 "$rc"
expect_absent "revoked handle discloses no body" "REFRESHED BODY" "$OUT"

new_handle="CHECKPOINT — file: $root/CHECKPOINT.md — token: $new_token"
run match "$root" "$new_handle"
expect_eq "new handle owns file" 0 "$rc"

# A Resume claim changes exactly the token bytes, including when the body has no final newline.
byte_root="$T/byte-claim"; mkdir "$byte_root"; byte_token="$(token_for)"
printf '# CHECKPOINT — file: %s/CHECKPOINT.md\ncheckpoint-token: %s\n\nBODY-WITHOUT-NEWLINE' \
  "$byte_root" "$byte_token" | bash "$FILE_SH" save "$byte_root" new >/dev/null 2>&1
cp "$byte_root/CHECKPOINT.md" "$T/byte-before"
run inspect "$byte_root"; byte_fingerprint="$(sed -n 's/^checkpoint_fingerprint=//p' "$OUT")"
run claim "$byte_root" "$byte_token" "$byte_fingerprint"
expect_eq "byte-exact claim succeeds" 0 "$rc"
{
  IFS= read -r byte_title
  IFS= read -r
  printf '%s\n' "$byte_title"
  printf 'checkpoint-token: %s\n' "$byte_token"
  cat
} < "$byte_root/CHECKPOINT.md" > "$T/byte-normalized"
if cmp -s "$T/byte-before" "$T/byte-normalized"; then pass=$((pass + 1)); else
  echo "FAIL: claim changed bytes outside line 2's token" >&2; fail=$((fail + 1))
fi

# A changed file invalidates the Resume fingerprint.
run inspect "$root"; stale_fingerprint="$(sed -n 's/^checkpoint_fingerprint=//p' "$OUT")"
write_doc "$root" "$new_token" "CHANGED AFTER READ" | bash "$FILE_SH" save "$root" "$new_token" >/dev/null 2>&1
run claim "$root" "$new_token" "$stale_fingerprint"
expect_eq "changed Resume candidate refuses claim" 1 "$rc"
expect "failed claim preserves current token" "checkpoint-token: $new_token" "$root/CHECKPOINT.md"

# Refresh revalidates the target after the complete candidate has been read.
stale="$T/stale-refresh"; mkdir "$stale"; stale_token="$(token_for)"
write_doc "$stale" "$stale_token" ORIGINAL | bash "$FILE_SH" save "$stale" new >/dev/null 2>&1
mkfifo "$stale/input.fifo"
bash "$FILE_SH" save "$stale" "$stale_token" < "$stale/input.fifo" > "$T/stale.out" 2>&1 & stale_pid=$!
exec 3>"$stale/input.fifo"
tries=0
while [ ! -f "$stale/CHECKPOINT.md.tmp" ] && [ "$tries" -lt 100 ]; do sleep 0.01; tries=$((tries + 1)); done
if [ -f "$stale/CHECKPOINT.md.tmp" ]; then pass=$((pass + 1)); else
  echo "FAIL: refresh fixture never reached candidate render" >&2; fail=$((fail + 1))
fi
write_doc "$stale" "$stale_token" "FOREIGN CHANGE" > "$stale/CHECKPOINT.md"
write_doc "$stale" "$stale_token" "REFRESH CANDIDATE" >&3
exec 3>&-
if wait "$stale_pid"; then stale_rc=0; else stale_rc=$?; fi
expect_eq "refresh refuses a target changed during candidate render" 1 "$stale_rc"
expect "changed refresh preserves ownership token" "checkpoint-token: $stale_token" "$stale/CHECKPOINT.md"
expect "changed refresh leaves foreign body" "FOREIGN CHANGE" "$stale/CHECKPOINT.md"
[ ! -e "$stale/CHECKPOINT.md.tmp" ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ ! -e "$stale/.CHECKPOINT.lock" ] && pass=$((pass + 1)) || fail=$((fail + 1))

# First creation never clobbers a target that appears while the candidate is being rendered.
appeared="$T/appeared"; mkdir "$appeared"; appeared_token="$(token_for)"
mkfifo "$appeared/input.fifo"
bash "$FILE_SH" save "$appeared" new < "$appeared/input.fifo" > "$T/appeared.out" 2>&1 & appeared_pid=$!
exec 3>"$appeared/input.fifo"
tries=0
while [ ! -f "$appeared/CHECKPOINT.md.tmp" ] && [ "$tries" -lt 100 ]; do sleep 0.01; tries=$((tries + 1)); done
if [ -f "$appeared/CHECKPOINT.md.tmp" ]; then pass=$((pass + 1)); else
  echo "FAIL: create fixture never reached candidate render" >&2; fail=$((fail + 1))
fi
printf 'INCUMBENT TARGET\n' > "$appeared/CHECKPOINT.md"
write_doc "$appeared" "$appeared_token" "NEW CANDIDATE" >&3
exec 3>&-
if wait "$appeared_pid"; then appeared_rc=0; else appeared_rc=$?; fi
expect_eq "first creation refuses a target that appeared" 1 "$appeared_rc"
expect "first creation preserves appeared target" "INCUMBENT TARGET" "$appeared/CHECKPOINT.md"
expect_absent "first creation does not publish candidate" "NEW CANDIDATE" "$appeared/CHECKPOINT.md"
[ ! -e "$appeared/CHECKPOINT.md.tmp" ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ ! -e "$appeared/.CHECKPOINT.lock" ] && pass=$((pass + 1)) || fail=$((fail + 1))

# A terminating signal aborts the transaction; cleanup never returns to the mutation.
signal_root="$T/signal"; mkdir "$signal_root" "$T/slow-bin"; signal_token="$(token_for)"
write_doc "$signal_root" "$signal_token" SIGNAL | bash "$FILE_SH" save "$signal_root" new >/dev/null 2>&1
run inspect "$signal_root"; signal_fingerprint="$(sed -n 's/^checkpoint_fingerprint=//p' "$OUT")"
if command -v shasum >/dev/null 2>&1; then hash_name=shasum; real_hash="$(command -v shasum)"
else hash_name=sha256sum; real_hash="$(command -v sha256sum)"; fi
{
  printf '#!/bin/sh\n'
  printf ': > "$SLOW_HASH_READY"\n'
  printf 'sleep 1\n'
  printf 'exec %s "$@"\n' "$real_hash"
} > "$T/slow-bin/$hash_name"
chmod +x "$T/slow-bin/$hash_name"
SLOW_HASH_READY="$T/hash.ready" PATH="$T/slow-bin:$PATH" \
  bash "$FILE_SH" claim "$signal_root" "$signal_token" "$signal_fingerprint" > "$T/signal.out" 2>&1 & signal_pid=$!
tries=0
while [ ! -e "$T/hash.ready" ] && [ "$tries" -lt 100 ]; do sleep 0.01; tries=$((tries + 1)); done
kill -TERM "$signal_pid"
if wait "$signal_pid"; then signal_rc=0; else signal_rc=$?; fi
expect_eq "TERM aborts claim" 143 "$signal_rc"
expect "terminated claim preserves token" "checkpoint-token: $signal_token" "$signal_root/CHECKPOINT.md"
expect_absent "terminated claim emits no ownership handle" "CHECKPOINT — file:" "$T/signal.out"
[ ! -e "$signal_root/CHECKPOINT.md.tmp" ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ ! -e "$signal_root/.CHECKPOINT.lock" ] && pass=$((pass + 1)) || fail=$((fail + 1))

# Incumbent coordination artifacts are never deleted.
printf 'USER TEMP\n' >"$root/CHECKPOINT.md.tmp"
if write_doc "$root" "$new_token" "NO WRITE" | bash "$FILE_SH" save "$root" "$new_token" >"$OUT" 2>&1; then rc=0; else rc=$?; fi
expect_eq "incumbent temporary path refuses" 1 "$rc"
expect "incumbent temporary path untouched" "USER TEMP" "$root/CHECKPOINT.md.tmp"
rm "$root/CHECKPOINT.md.tmp"
mkdir "$root/.CHECKPOINT.lock"
run delete "$root" "$new_token"
expect_eq "lock contention refuses" 1 "$rc"
[ -f "$root/CHECKPOINT.md" ] && pass=$((pass + 1)) || fail=$((fail + 1))
rmdir "$root/.CHECKPOINT.lock"
run delete "$root" "$new_token"
expect_eq "owned delete succeeds" 0 "$rc"
[ ! -e "$root/CHECKPOINT.md" ] && pass=$((pass + 1)) || fail=$((fail + 1))

# Invalid documents and unsafe target shapes never disclose or overwrite.
bad="$T/bad"; mkdir "$bad"; bad_token="$(token_for)"
{
  printf '# WRONG — file: %s/CHECKPOINT.md\n' "$bad"
  printf 'checkpoint-token: %s\n\nBAD BODY\n' "$bad_token"
} | if bash "$FILE_SH" save "$bad" new >"$OUT" 2>&1; then echo 0 >"$T/badrc"; else echo $? >"$T/badrc"; fi
expect_eq "wrong title refuses save" 1 "$(cat "$T/badrc")"
[ ! -e "$bad/CHECKPOINT.md.tmp" ] && pass=$((pass + 1)) || fail=$((fail + 1))
[ ! -e "$bad/.CHECKPOINT.lock" ] && pass=$((pass + 1)) || fail=$((fail + 1))
{
  printf '# CHECKPOINT — file: %s/CHECKPOINT.md\n\n' "$bad"
  printf 'checkpoint-token: %s\nSECRET LATE TOKEN\n' "$bad_token"
} >"$bad/CHECKPOINT.md"
run admit "$bad" "CHECKPOINT — file: $bad/CHECKPOINT.md — token: $bad_token"
expect_eq "token outside line 2 refuses" 1 "$rc"
expect_absent "late token body is not disclosed" "SECRET LATE TOKEN" "$OUT"
rm "$bad/CHECKPOINT.md"; printf 'SYMLINK SECRET\n' >"$bad/elsewhere"; ln -s elsewhere "$bad/CHECKPOINT.md"
run inspect "$bad"
expect_eq "symlink target refuses inspect" 1 "$rc"
expect_absent "symlink target body is not disclosed" "SYMLINK SECRET" "$OUT"

# Two simultaneous first saves produce one winner.
race="$T/race"; mkdir "$race"
t1="$(token_for)"; t2="$(token_for)"
(if write_doc "$race" "$t1" ONE | bash "$FILE_SH" save "$race" new >"$T/r1" 2>&1; then echo 0 >"$T/rc1"; else echo $? >"$T/rc1"; fi) & p1=$!
(if write_doc "$race" "$t2" TWO | bash "$FILE_SH" save "$race" new >"$T/r2" 2>&1; then echo 0 >"$T/rc2"; else echo $? >"$T/rc2"; fi) & p2=$!
wait "$p1"; wait "$p2"
sum=$(( $(cat "$T/rc1") + $(cat "$T/rc2") ))
expect_eq "competing saves have one winner" 1 "$sum"

# Git roots receive narrow local excludes; nested names remain visible.
gitroot="$T/git"; git init -q -b main "$gitroot"
git -C "$gitroot" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
gtoken="$(token_for)"
write_doc "$gitroot" "$gtoken" GIT | bash "$FILE_SH" save "$gitroot" new >"$OUT" 2>&1
expect "root checkpoint ignore installed" "/CHECKPOINT.md" "$gitroot/.git/info/exclude"
expect "root temp ignore installed" "/CHECKPOINT.md.tmp" "$gitroot/.git/info/exclude"
if git -C "$gitroot" check-ignore -q CHECKPOINT.md &&
  git -C "$gitroot" check-ignore -q CHECKPOINT.md.tmp; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
mkdir "$gitroot/nested"; printf x >"$gitroot/nested/CHECKPOINT.md"
if git -C "$gitroot" check-ignore -q nested/CHECKPOINT.md; then fail=$((fail + 1)); else pass=$((pass + 1)); fi

# A missing local exclude is lazily recreated, and linked worktrees mutate through the common dir.
noexclude="$T/noexclude"; git init -q -b main "$noexclude"
git -C "$noexclude" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
rm "$noexclude/.git/info/exclude"; noexclude_token="$(token_for)"
write_doc "$noexclude" "$noexclude_token" NOEXCLUDE | bash "$FILE_SH" save "$noexclude" new > "$OUT" 2>&1
expect "missing exclude is recreated" "/CHECKPOINT.md" "$noexclude/.git/info/exclude"
expect "recreated exclude covers temp" "/CHECKPOINT.md.tmp" "$noexclude/.git/info/exclude"

linkbase="$T/link-base"; linked="$T/linked"; git init -q -b main "$linkbase"
git -C "$linkbase" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$linkbase" worktree add -q -b linked "$linked" main
linked_token="$(token_for)"
write_doc "$linked" "$linked_token" LINKED | bash "$FILE_SH" save "$linked" new > "$OUT" 2>&1
expect "linked save writes checkpoint" "LINKED" "$linked/CHECKPOINT.md"
expect "linked save uses common exclude" "/CHECKPOINT.md" "$linkbase/.git/info/exclude"
linked_admin="$(git -C "$linked" rev-parse --absolute-git-dir)"
[ ! -e "$linked_admin/checkpoint.lock" ] && pass=$((pass + 1)) || fail=$((fail + 1))

# Tracked state and stream custody refuse before checkpoint-side mutation.
git -C "$gitroot" add -f CHECKPOINT.md
git -C "$gitroot" -c user.email=t@t -c user.name=t commit -qm 'track checkpoint' -- CHECKPOINT.md
run inspect "$gitroot"
expect_eq "tracked checkpoint refuses read" 1 "$rc"
expect_absent "tracked checkpoint body is not disclosed" "GIT" "$OUT"

stream="$T/stream"; git init -q -b main "$stream"
git -C "$stream" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
printf '# stream\n' >"$stream/WORKSTREAM.md"; stoken="$(token_for)"
if write_doc "$stream" "$stoken" STREAM | bash "$FILE_SH" save "$stream" new >"$OUT" 2>&1; then rc=0; else rc=$?; fi
expect_eq "workstream-owned root refuses save" 1 "$rc"
expect_absent "workstream refusal creates no checkpoint" "CHECKPOINT — file:" "$OUT"
expect_absent "workstream refusal creates no ignore" "/CHECKPOINT.md" "$stream/.git/info/exclude"
printf '/CHECKPOINT.md\n/CHECKPOINT.md.tmp\n' >> "$stream/.git/info/exclude"
write_doc "$stream" "$stoken" "STREAM PRIVATE BODY" > "$stream/CHECKPOINT.md"
run match "$stream" "CHECKPOINT — file: $stream/CHECKPOINT.md — token: $stoken"
expect_eq "workstream-owned root refuses ownership read" 1 "$rc"
expect "workstream ownership read reports false" "token_match=false" "$OUT"
expect_absent "workstream ownership read discloses no body" "STREAM PRIVATE BODY" "$OUT"

finish "checkpoint file"
