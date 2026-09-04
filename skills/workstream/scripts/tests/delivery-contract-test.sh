#!/usr/bin/env bash
# Local delivery persists running before mutation and recovers from observation.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-delivery.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init delivery main delivery >"$OUT"; "$HELPER" "$ROOT" unit-begin delivery unit unit >"$OUT"
printf 'unit\n' >>"$ROOT/.streams/delivery/file"; git -C "$ROOT/.streams/delivery" add file; git -C "$ROOT/.streams/delivery" commit -qm unit
"$HELPER" "$ROOT" unit-complete delivery >"$OUT"; "$HELPER" "$ROOT" ship-prepare delivery >"$OUT"; "$HELPER" "$ROOT" gate-run delivery --class full --label gate -- true >"$OUT"
target_before="$(git -C "$ROOT" rev-parse main)"
cat >"$TMP/interrupt.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/interrupt.sh"
if WORKSTREAM_TEST_AFTER_DELIVERY_RUNNING="$TMP/interrupt.sh" "$HELPER" "$ROOT" land-advance delivery --authority confirmed >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect_absent 'acquired local interruption is not lock contention' 'status=landing-busy' "$OUT"
expect 'running receipt precedes mutation' $'state\trunning' "$ROOT/.streams/delivery/workstream.tsv"
expect_eq 'interruption leaves target unchanged' "$target_before" "$(git -C "$ROOT" rev-parse main)"
"$HELPER" "$ROOT" land-advance delivery --authority confirmed >"$OUT"
expect 'recovered delivery lands' 'status=landed' "$OUT"
expect 'observed advance persists' $'state\tadvanced' "$ROOT/.streams/delivery/workstream.tsv"
landed="$(git -C "$ROOT" rev-parse main)"
"$HELPER" "$ROOT" land-advance delivery --authority confirmed >"$OUT"
expect 'land retry observes completion' 'status=already-landed' "$OUT"
expect_eq 'target advances only once' "$landed" "$(git -C "$ROOT" rev-parse main)"
"$HELPER" "$ROOT" delivery-classify delivery >"$OUT"; expect 'advanced destination classifies complete' 'classifier=complete' "$OUT"

LINKED="$TMP/linked"; init_repo "$LINKED"
printf 'base\n' >"$LINKED/file"; git -C "$LINKED" add file; git -C "$LINKED" commit -qm initial
"$HELPER" "$LINKED" runtime-init linked main linked >"$OUT"; "$HELPER" "$LINKED" unit-begin linked unit unit >"$OUT"
printf 'unit\n' >>"$LINKED/.streams/linked/file"; git -C "$LINKED/.streams/linked" add file; git -C "$LINKED/.streams/linked" commit -qm unit
"$HELPER" "$LINKED" unit-complete linked >"$OUT"; "$HELPER" "$LINKED" ship-prepare linked >"$OUT"; "$HELPER" "$LINKED" gate-run linked --class full --label gate -- true >"$OUT"
candidate="$(git -C "$LINKED/.streams/linked" rev-parse HEAD)"; "$HELPER" "$LINKED" land-advance linked --authority confirmed >"$OUT"
expect_eq 'linked local landing advances the target' "$candidate" "$(git -C "$LINKED" rev-parse main)"
expect_eq 'linked local landing retains worktree custody' stream/linked "$(git -C "$LINKED/.streams/linked" branch --show-current)"
"$HELPER" "$LINKED" ship-finalize linked >"$OUT"; expect 'linked local shipment finalizes' 'status=finalized' "$OUT"

REMOTE="$TMP/push-remote.git"; PUSHROOT="$TMP/push"; git init -q --bare "$REMOTE"; init_repo "$PUSHROOT"
printf 'base\n' >"$PUSHROOT/file"; git -C "$PUSHROOT" add file; git -C "$PUSHROOT" commit -qm initial; git -C "$PUSHROOT" remote add origin "$REMOTE"; git -C "$PUSHROOT" push -qu origin main
UPSTREAM="$TMP/upstream"; git clone -q -b main "$REMOTE" "$UPSTREAM"; configure_repo "$UPSTREAM"
printf 'upstream\n' >"$UPSTREAM/upstream"; git -C "$UPSTREAM" add upstream; git -C "$UPSTREAM" commit -qm upstream; git -C "$UPSTREAM" push -q origin main
remote_before="$(git -C "$UPSTREAM" rev-parse HEAD)"
"$HELPER" "$PUSHROOT" runtime-init pushed main pushed --landing push >"$OUT"; "$HELPER" "$PUSHROOT" unit-begin pushed unit unit >"$OUT"
printf 'unit\n' >>"$PUSHROOT/.streams/pushed/file"; git -C "$PUSHROOT/.streams/pushed" add file; git -C "$PUSHROOT/.streams/pushed" commit -qm unit
"$HELPER" "$PUSHROOT" unit-complete pushed >"$OUT"; "$HELPER" "$PUSHROOT" ship-prepare pushed >"$OUT"; "$HELPER" "$PUSHROOT" gate-run pushed --class full --label gate -- true >"$OUT"
if git -C "$PUSHROOT/.streams/pushed" merge-base --is-ancestor "$remote_before" HEAD; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
candidate="$(git -C "$PUSHROOT/.streams/pushed" rev-parse HEAD)"
push_tracker="$PUSHROOT/.streams/pushed/workstream.tsv"; cp "$push_tracker" "$TMP/push-before-dirty.tsv"
local_before_dirty="$(git -C "$PUSHROOT" rev-parse main)"; remote_before_dirty="$(git -C "$PUSHROOT/.streams/pushed" ls-remote --heads origin refs/heads/main | awk '{print $1}')"
printf 'primary wip\n' >"$PUSHROOT/primary-wip"
if "$HELPER" "$PUSHROOT" land-advance pushed --authority confirmed >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'dirty push primary refuses before either destination' 'primary checkout is not completely clean' "$ERR"
expect_eq 'dirty push refusal preserves local target' "$local_before_dirty" "$(git -C "$PUSHROOT" rev-parse main)"
expect_eq 'dirty push refusal preserves remote target' "$remote_before_dirty" "$(git -C "$PUSHROOT/.streams/pushed" ls-remote --heads origin refs/heads/main | awk '{print $1}')"
if cmp -s "$TMP/push-before-dirty.tsv" "$push_tracker"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: dirty push refusal changed receipts' >&2; fi
rm "$PUSHROOT/primary-wip"
if WORKSTREAM_TEST_AFTER_REMOTE_RUNNING="$TMP/interrupt.sh" "$HELPER" "$PUSHROOT" land-advance pushed --authority confirmed >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect_absent 'acquired remote interruption is not lock contention' 'status=landing-busy' "$OUT"
expect 'remote running receipt precedes push' $'remote-target\tstate\trunning' "$PUSHROOT/.streams/pushed/workstream.tsv"
expect 'both push destinations were recorded before mutation' $'remote-target\texpected-tip\t'"$remote_before" "$PUSHROOT/.streams/pushed/workstream.tsv"
"$HELPER" "$PUSHROOT" land-advance pushed --authority confirmed >"$OUT"
expect_eq 'push advances local target' "$candidate" "$(git -C "$PUSHROOT" rev-parse main)"
expect_eq 'push advances remote target' "$candidate" "$(git -C "$PUSHROOT" ls-remote --heads origin refs/heads/main | awk '{print $1}')"
expect_eq 'push leaves primary on its target branch' main "$(git -C "$PUSHROOT" branch --show-current)"
expect_eq 'push aligns the primary index to the candidate' "$(git -C "$PUSHROOT" rev-parse "$candidate^{tree}")" "$(git -C "$PUSHROOT" write-tree)"
expect_eq 'push leaves the complete primary clean' '' "$(git -C "$PUSHROOT" status --porcelain --untracked-files=all)"
"$HELPER" "$PUSHROOT" delivery-classify pushed >"$OUT"; expect 'two destinations classify complete' 'classifier=complete' "$OUT"
tree="$(git -C "$PUSHROOT" rev-parse "$candidate^{tree}")"; descendant="$(printf 'remote follow-up\n' | git -C "$PUSHROOT" commit-tree "$tree" -p "$candidate")"
git -C "$PUSHROOT" push -q origin "$descendant:refs/heads/main"
"$HELPER" "$PUSHROOT" ship-finalize pushed >"$OUT"
expect 'remote descendant still permits finalization' 'status=finalized' "$OUT"
report 'workstream delivery contract'
