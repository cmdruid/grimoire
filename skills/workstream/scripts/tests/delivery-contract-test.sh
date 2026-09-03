#!/usr/bin/env bash
# Local delivery persists running before mutation and recovers from observation.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-delivery.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init delivery main delivery >"$OUT"; "$HELPER" "$ROOT" unit-begin delivery unit unit >"$OUT"
printf 'unit\n' >>"$ROOT/.streams/delivery/file"; git -C "$ROOT/.streams/delivery" add file; git -C "$ROOT/.streams/delivery" commit -qm unit
"$HELPER" "$ROOT" unit-complete delivery >"$OUT"; "$HELPER" "$ROOT" ship-prepare delivery >"$OUT"; "$HELPER" "$ROOT" gate-run delivery --class docs --label gate -- true >"$OUT"
target_before="$(git -C "$ROOT" rev-parse main)"
cat >"$TMP/interrupt.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/interrupt.sh"
if WORKSTREAM_TEST_AFTER_DELIVERY_RUNNING="$TMP/interrupt.sh" "$HELPER" "$ROOT" land-advance delivery --authority confirmed >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
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

INPLACE="$TMP/inplace"; git init -q -b main "$INPLACE"; git -C "$INPLACE" config user.name test; git -C "$INPLACE" config user.email test@example.invalid
printf 'base\n' >"$INPLACE/file"; git -C "$INPLACE" add file; git -C "$INPLACE" commit -qm initial
mkdir -p "$INPLACE/.streams"; sed 's/isolation: worktree/isolation: in-place/' "$DIR/../../templates/streams-config.md" >"$INPLACE/.streams/CONFIG.md"
"$HELPER" "$INPLACE" runtime-init inplace main inplace >"$OUT"; "$HELPER" "$INPLACE" unit-begin inplace unit unit >"$OUT"
printf 'unit\n' >>"$INPLACE/file"; git -C "$INPLACE" add file; git -C "$INPLACE" commit -qm unit
"$HELPER" "$INPLACE" unit-complete inplace >"$OUT"; "$HELPER" "$INPLACE" ship-prepare inplace >"$OUT"; "$HELPER" "$INPLACE" gate-run inplace --class docs --label gate -- true >"$OUT"
candidate="$(git -C "$INPLACE" rev-parse HEAD)"; "$HELPER" "$INPLACE" land-advance inplace --authority confirmed >"$OUT"
expect_eq 'in-place local landing advances target by ref' "$candidate" "$(git -C "$INPLACE" rev-parse main)"
expect_eq 'in-place local landing retains stream custody' stream/inplace "$(git -C "$INPLACE" branch --show-current)"
"$HELPER" "$INPLACE" ship-finalize inplace >"$OUT"; expect 'in-place local shipment finalizes' 'status=finalized' "$OUT"

REMOTE="$TMP/push-remote.git"; PUSHROOT="$TMP/push"; git init -q --bare "$REMOTE"; git init -q -b main "$PUSHROOT"
git -C "$PUSHROOT" config user.name test; git -C "$PUSHROOT" config user.email test@example.invalid
printf 'base\n' >"$PUSHROOT/file"; git -C "$PUSHROOT" add file; git -C "$PUSHROOT" commit -qm initial; git -C "$PUSHROOT" remote add origin "$REMOTE"; git -C "$PUSHROOT" push -qu origin main
UPSTREAM="$TMP/upstream"; git clone -q -b main "$REMOTE" "$UPSTREAM"; git -C "$UPSTREAM" config user.name test; git -C "$UPSTREAM" config user.email test@example.invalid
printf 'upstream\n' >"$UPSTREAM/upstream"; git -C "$UPSTREAM" add upstream; git -C "$UPSTREAM" commit -qm upstream; git -C "$UPSTREAM" push -q origin main
remote_before="$(git -C "$UPSTREAM" rev-parse HEAD)"
mkdir -p "$PUSHROOT/.streams"; sed -e 's/isolation: worktree/isolation: in-place/' -e 's/landing: local/landing: push/' "$DIR/../../templates/streams-config.md" >"$PUSHROOT/.streams/CONFIG.md"
"$HELPER" "$PUSHROOT" runtime-init pushed main pushed >"$OUT"; "$HELPER" "$PUSHROOT" unit-begin pushed unit unit >"$OUT"
printf 'unit\n' >>"$PUSHROOT/file"; git -C "$PUSHROOT" add file; git -C "$PUSHROOT" commit -qm unit
"$HELPER" "$PUSHROOT" unit-complete pushed >"$OUT"; "$HELPER" "$PUSHROOT" ship-prepare pushed >"$OUT"; "$HELPER" "$PUSHROOT" gate-run pushed --class docs --label gate -- true >"$OUT"
if git -C "$PUSHROOT" merge-base --is-ancestor "$remote_before" HEAD; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
candidate="$(git -C "$PUSHROOT" rev-parse HEAD)"
if WORKSTREAM_TEST_AFTER_REMOTE_RUNNING="$TMP/interrupt.sh" "$HELPER" "$PUSHROOT" land-advance pushed --authority confirmed >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'remote running receipt precedes push' $'remote-target\tstate\trunning' "$PUSHROOT/.streams/pushed/workstream.tsv"
expect 'both push destinations were recorded before mutation' $'remote-target\texpected-tip\t'"$remote_before" "$PUSHROOT/.streams/pushed/workstream.tsv"
"$HELPER" "$PUSHROOT" land-advance pushed --authority confirmed >"$OUT"
expect_eq 'push advances local target' "$candidate" "$(git -C "$PUSHROOT" rev-parse main)"
expect_eq 'push advances remote target' "$candidate" "$(git -C "$PUSHROOT" ls-remote --heads origin refs/heads/main | awk '{print $1}')"
"$HELPER" "$PUSHROOT" delivery-classify pushed >"$OUT"; expect 'two destinations classify complete' 'classifier=complete' "$OUT"
report 'workstream delivery contract'
