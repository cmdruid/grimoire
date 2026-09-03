#!/usr/bin/env bash
# PR-style delivery waits for observed integration before finalization.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-pr.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
REMOTE="$TMP/remote.git"; git init -q --bare "$REMOTE"
init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial; git -C "$ROOT" remote add origin "$REMOTE"; git -C "$ROOT" push -qu origin main
"$HELPER" "$ROOT" runtime-init pr main pr --landing pr >"$OUT"; "$HELPER" "$ROOT" unit-begin pr unit unit >"$OUT"
printf 'unit\n' >>"$ROOT/.streams/pr/file"; git -C "$ROOT/.streams/pr" add file; git -C "$ROOT/.streams/pr" commit -qm unit
"$HELPER" "$ROOT" unit-complete pr >"$OUT"
base="$(git -C "$ROOT" rev-parse main)"; tree="$(git -C "$ROOT" rev-parse "$base^{tree}")"
remote_update="$(printf 'remote target update\n' | git -C "$ROOT/.streams/pr" commit-tree "$tree" -p "$base")"
git -C "$ROOT/.streams/pr" push -q origin "$remote_update:refs/heads/main"
"$HELPER" "$ROOT" ship-prepare pr >"$OUT"; "$HELPER" "$ROOT" gate-run pr --class full --label gate -- true >"$OUT"
target_before="$(git -C "$ROOT" rev-parse main)"
expect_eq 'PR preparation leaves a stale clean primary untouched' "$base" "$target_before"
printf 'primary wip\n' >"$ROOT/primary-wip"
git -C "$ROOT/.streams/pr" push -qu origin stream/pr
"$HELPER" "$ROOT" pr-await pr --authority confirmed --reference 'fixture-pr-1' >"$OUT"
expect 'PR records awaiting merge' 'status=awaiting-merge' "$OUT"
expect_eq 'PR preparation leaves target unchanged' "$target_before" "$(git -C "$ROOT" rev-parse main)"
if "$HELPER" "$ROOT" pr-verify pr >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'unmerged PR remains waiting' 'next_action=await-merge' "$OUT"
candidate="$(git -C "$ROOT/.streams/pr" rev-parse HEAD)"; git -C "$ROOT/.streams/pr" push -q origin "$candidate:refs/heads/main"
"$HELPER" "$ROOT" pr-verify pr >"$OUT"
expect 'observed merge reaches postflight' 'status=merged' "$OUT"
expect 'PR observation keeps postflight active' $'outcome\tactive' "$ROOT/.streams/pr/workstream.tsv"
expect 'PR observation records the remote target' $'remote-target\tstate\tadvanced' "$ROOT/.streams/pr/workstream.tsv"
expect_absent 'PR observation does not invent local synchronization' $'local-target\tstate' "$ROOT/.streams/pr/workstream.tsv"
expect_eq 'PR leaves local target unchanged' "$target_before" "$(git -C "$ROOT" rev-parse main)"
tracker_hash="$(shasum -a 256 "$ROOT/.streams/pr/workstream.tsv" | awk '{print $1}')"
if "$HELPER" "$ROOT" land-advance pr --authority confirmed >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'dirty PR postflight refuses primary synchronization' 'primary checkout is not completely clean' "$ERR"
expect_eq 'dirty refusal preserves postflight receipts' "$tracker_hash" "$(shasum -a 256 "$ROOT/.streams/pr/workstream.tsv" | awk '{print $1}')"
if "$HELPER" "$ROOT" ship-finalize pr >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'unreconciled PR cannot finalize' 'shipment has not landed' "$ERR"
rm "$ROOT/primary-wip"
READY="$TMP/acquired.fifo"; RELEASE="$TMP/release.fifo"; mkfifo "$READY" "$RELEASE"
cat >"$TMP/hold-postflight.sh" <<'EOF'
#!/usr/bin/env bash
printf 'acquired\n' >"$WORKSTREAM_TEST_PR_READY"
IFS= read -r _ <"$WORKSTREAM_TEST_PR_RELEASE"
EOF
chmod +x "$TMP/hold-postflight.sh"
WORKSTREAM_TEST_PR_READY="$READY" WORKSTREAM_TEST_PR_RELEASE="$RELEASE" \
  WORKSTREAM_TEST_AFTER_LANDING_ACQUIRED="$TMP/hold-postflight.sh" \
  "$HELPER" "$ROOT" land-advance pr --authority confirmed >"$TMP/postflight-owner.out" 2>"$TMP/postflight-owner.err" &
owner_pid=$!
IFS= read -r acquired <"$READY"; expect_eq 'authorized PR postflight acquires the lease' acquired "$acquired"
cp "$ROOT/.streams/pr/workstream.tsv" "$TMP/postflight-busy.tsv"
if "$HELPER" "$ROOT" land-advance pr --authority confirmed >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'PR contention is immediate' 'status=landing-busy' "$OUT"
expect 'PR contention preserves the postflight action' 'next_action=postflight' "$OUT"
if cmp -s "$TMP/postflight-busy.tsv" "$ROOT/.streams/pr/workstream.tsv"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: PR contention changed receipts' >&2; fi
printf 'release\n' >"$RELEASE"
if wait "$owner_pid"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: authorized PR postflight owner did not finish' >&2; fi
expect 'authorized PR postflight synchronizes the primary' 'status=landed' "$TMP/postflight-owner.out"
expect_eq 'PR postflight advances local target to observed remote' "$(git -C "$ROOT/.streams/pr" ls-remote --heads origin refs/heads/main | awk '{print $1}')" "$(git -C "$ROOT" rev-parse main)"
"$HELPER" "$ROOT" ship-finalize pr >"$OUT"; expect 'reconciled PR finalizes' 'status=finalized' "$OUT"
"$HELPER" "$ROOT" close-check pr >"$OUT"; expect 'remote PR containment permits close' 'ahead=0' "$OUT"
report 'workstream PR delivery'
