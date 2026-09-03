#!/usr/bin/env bash
# The repository-wide landing lease is non-blocking, process-scoped, and non-durable.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-landing-lease.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT

prepare_local_stream() { # root stream
  local root="$1" stream="$2"
  init_repo "$root"
  printf 'base\n' >"$root/file"; git -C "$root" add file; git -C "$root" commit -qm initial
  "$HELPER" "$root" runtime-init "$stream" main "$stream" >"$OUT"
  "$HELPER" "$root" unit-begin "$stream" unit unit >"$OUT"
  printf 'unit\n' >>"$root/.streams/$stream/file"
  git -C "$root/.streams/$stream" add file; git -C "$root/.streams/$stream" commit -qm unit
  "$HELPER" "$root" unit-complete "$stream" >"$OUT"
  "$HELPER" "$root" ship-prepare "$stream" >"$OUT"
  "$HELPER" "$root" gate-run "$stream" --class full --label gate -- true >"$OUT"
}

prepare_local_stream "$ROOT" lease
TRACKER="$ROOT/.streams/lease/workstream.tsv"
CANDIDATE="$(git -C "$ROOT/.streams/lease" rev-parse HEAD)"
TARGET_BEFORE="$(git -C "$ROOT" rev-parse main)"
READY="$TMP/acquired.fifo"; RELEASE="$TMP/release.fifo"; mkfifo "$READY" "$RELEASE"
cat >"$TMP/hold-lock.sh" <<'EOF'
#!/usr/bin/env bash
printf 'acquired\n' >"$WORKSTREAM_TEST_LEASE_READY"
IFS= read -r _ <"$WORKSTREAM_TEST_LEASE_RELEASE"
EOF
chmod +x "$TMP/hold-lock.sh"

WORKSTREAM_TEST_LEASE_READY="$READY" WORKSTREAM_TEST_LEASE_RELEASE="$RELEASE" \
  WORKSTREAM_TEST_AFTER_LANDING_ACQUIRED="$TMP/hold-lock.sh" \
  "$HELPER" "$ROOT" land-advance lease --authority confirmed >"$TMP/owner.out" 2>"$TMP/owner.err" &
owner_pid=$!
IFS= read -r acquired <"$READY"
expect_eq 'first concurrent transaction acquires the lease' acquired "$acquired"
cp "$TRACKER" "$TMP/tracker-before-busy"
if "$HELPER" "$ROOT" land-advance lease --authority confirmed >"$TMP/busy.out" 2>"$TMP/busy.err"; then
  fail=$((fail + 1)); echo 'FAIL: concurrent landing did not report contention' >&2
else
  pass=$((pass + 1))
fi
expect 'contender reports the bounded busy outcome' 'status=landing-busy' "$TMP/busy.out"
expect 'contender retains the landing action' 'next_action=land' "$TMP/busy.out"
if cmp -s "$TMP/tracker-before-busy" "$TRACKER"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: contention changed preparation evidence' >&2; fi
expect_eq 'contention leaves the target unchanged' "$TARGET_BEFORE" "$(git -C "$ROOT" rev-parse main)"
printf 'release\n' >"$RELEASE"
if wait "$owner_pid"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: acquired transaction did not finish' >&2; fi
expect 'the acquired transaction lands' 'status=landed' "$TMP/owner.out"
expect_eq 'exactly one concurrent transaction advances the target' "$CANDIDATE" "$(git -C "$ROOT" rev-parse main)"

COMMON="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)"
if [ -f "$COMMON/workstream-landing.lock" ] && [ ! -L "$COMMON/workstream-landing.lock" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: lease file is not a safe shared-Git file' >&2; fi
if awk -F '\t' '$3~/^(owner|consent|authority|lease|pid)$/ { found=1 } END { exit found ? 0 : 1 }' "$TRACKER"; then
  fail=$((fail + 1)); echo 'FAIL: lease ownership or consent entered the tracker' >&2
else
  pass=$((pass + 1))
fi

case "$(uname -s)" in Darwin|FreeBSD|NetBSD|OpenBSD|DragonFly) conflict_rc=75 ;; *) conflict_rc=1 ;; esac
cat >"$TMP/fail-after-acquire.sh" <<'EOF'
#!/usr/bin/env bash
exit "$WORKSTREAM_TEST_LEASE_FAILURE"
EOF
chmod +x "$TMP/fail-after-acquire.sh"
cp "$TRACKER" "$TMP/tracker-before-child-failure"
if WORKSTREAM_TEST_LEASE_FAILURE="$conflict_rc" WORKSTREAM_TEST_AFTER_LANDING_ACQUIRED="$TMP/fail-after-acquire.sh" \
  "$HELPER" "$ROOT" land-advance lease --authority confirmed >"$TMP/child-failure.out" 2>"$TMP/child-failure.err"; then
  fail=$((fail + 1)); echo 'FAIL: acquired child failure returned success' >&2
else
  pass=$((pass + 1))
fi
expect_absent 'an acquired child exit is not contention' 'status=landing-busy' "$TMP/child-failure.out"
if cmp -s "$TMP/tracker-before-child-failure" "$TRACKER"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: acquisition-hook failure changed the tracker' >&2; fi
"$HELPER" "$ROOT" land-advance lease --authority confirmed >"$OUT"
expect 'normal retry acquires after handled failure' 'status=already-landed' "$OUT"

SIGNAL_READY="$TMP/signal-ready.fifo"; mkfifo "$SIGNAL_READY"
cat >"$TMP/stop-after-acquire.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$PPID" >"$WORKSTREAM_TEST_LEASE_READY"
kill -STOP "$PPID"
EOF
chmod +x "$TMP/stop-after-acquire.sh"
WORKSTREAM_TEST_LEASE_READY="$SIGNAL_READY" WORKSTREAM_TEST_AFTER_LANDING_ACQUIRED="$TMP/stop-after-acquire.sh" \
  "$HELPER" "$ROOT" land-advance lease --authority confirmed >"$TMP/signaled.out" 2>"$TMP/signaled.err" &
signal_wrapper=$!
IFS= read -r transaction_pid <"$SIGNAL_READY"
kill -KILL "$transaction_pid"
if wait "$signal_wrapper"; then fail=$((fail + 1)); echo 'FAIL: terminated transaction returned success' >&2; else pass=$((pass + 1)); fi
"$HELPER" "$ROOT" land-advance lease --authority confirmed >"$OUT"
expect 'signal termination releases the lease' 'status=already-landed' "$OUT"

NOLOCK_ROOT="$TMP/no-lock"; prepare_local_stream "$NOLOCK_ROOT" unsupported
NOLOCK_TRACKER="$NOLOCK_ROOT/.streams/unsupported/workstream.tsv"
NOLOCK_COMMON="$(git -C "$NOLOCK_ROOT" rev-parse --path-format=absolute --git-common-dir)"
cp "$NOLOCK_TRACKER" "$TMP/tracker-before-unsupported"
mkdir "$TMP/path-without-lock"
cat >"$TMP/path-without-lock/uname" <<'EOF'
#!/bin/sh
printf 'UnsupportedOS\n'
EOF
chmod +x "$TMP/path-without-lock/uname"
if PATH="$TMP/path-without-lock" /bin/bash "$HELPER" "$NOLOCK_ROOT" land-advance missing --authority confirmed >"$TMP/unsupported.out" 2>"$TMP/unsupported.err"; then
  fail=$((fail + 1)); echo 'FAIL: landing without a supported lock primitive succeeded' >&2
else
  pass=$((pass + 1))
fi
expect 'missing lock capability has an ordinary diagnostic' 'landing requires the flock primitive' "$TMP/unsupported.err"
if cmp -s "$TMP/tracker-before-unsupported" "$NOLOCK_TRACKER"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: missing lock capability changed the tracker' >&2; fi
if [ ! -e "$NOLOCK_COMMON/workstream-landing.lock" ] && [ ! -L "$NOLOCK_COMMON/workstream-landing.lock" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: missing lock capability created a lease file' >&2; fi

ln -s "$TMP/unsafe-target" "$NOLOCK_COMMON/workstream-landing.lock"
if "$HELPER" "$NOLOCK_ROOT" land-advance unsupported --authority confirmed >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1)); echo 'FAIL: symlinked landing lock was accepted' >&2
else
  pass=$((pass + 1))
fi
expect 'unsafe lock path is rejected' 'landing lock path is unsafe' "$ERR"
if cmp -s "$TMP/tracker-before-unsupported" "$NOLOCK_TRACKER"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: unsafe lock path changed the tracker' >&2; fi

wait_word='sle''ep'
landing_source="$(sed -n '/^landing_lock_path()/,/^cmd_sync()/p' "$HELPER")"
if printf '%s\n' "$landing_source" | grep -Eq "(^|[;&|[:space:]])${wait_word}([;&|[:space:]]|$)"; then
  fail=$((fail + 1)); echo 'FAIL: landing lease implementation waits for ownership' >&2
else
  pass=$((pass + 1))
fi

report 'workstream landing lease'
