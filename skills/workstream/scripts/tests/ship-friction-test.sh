#!/usr/bin/env bash
# Friction runs once before readiness and tracked effects invalidate the gate.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-friction.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; trap 'rm -rf "$TMP"' EXIT
init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial; mkdir -p "$ROOT/.streams"
cat >"$ROOT/.streams/CONFIG.md" <<'EOF'
<!-- workstream:defaults@1 -->
mode: delegate
landing: local
ship-cadence: milestone
<!-- /workstream:defaults@1 -->
<!-- workstream:hook:ship-friction@1 -->
execution: isolated-preferred
concurrency: serial

Review the friction and record a bounded debrief.
<!-- /workstream:hook:ship-friction@1 -->
EOF
"$HELPER" "$ROOT" runtime-init friction main friction >"$OUT"; "$HELPER" "$ROOT" unit-begin friction unit unit >"$OUT"
printf 'unit\n' >>"$ROOT/.streams/friction/file"; git -C "$ROOT/.streams/friction" add file; git -C "$ROOT/.streams/friction" commit -qm unit
"$HELPER" "$ROOT" unit-complete friction >"$OUT"; "$HELPER" "$ROOT" ship-prepare friction >"$OUT"
"$HELPER" "$ROOT" friction-add friction agent-intervention >"$OUT"
"$HELPER" "$ROOT" gate-run friction --class full --label friction -- true >"$OUT"
TRACKER="$ROOT/.streams/friction/workstream.tsv"
expect 'friction stops before readiness' $'phase\tfriction' "$TRACKER"
expect 'ship hook is ready' $'name\tship-friction' "$TRACKER"
identity="$(awk -F '\t' '$1=="hook"&&$3=="name"&&$4=="ship-friction"{print $2}' "$TRACKER")"
"$HELPER" "$ROOT" hook-start friction "$identity" --isolation available >"$OUT"
expect 'friction body emitted in isolation envelope' 'Review the friction' "$OUT"
printf 'hook effect\n' >>"$ROOT/.streams/friction/file"; git -C "$ROOT/.streams/friction" add file; git -C "$ROOT/.streams/friction" commit -qm 'record friction effect'
cat >"$TMP/closure" <<'EOF'
status: complete
summary: friction reviewed
effects: file
parent-actions: none
EOF
"$HELPER" "$ROOT" hook-complete friction "$identity" --closure "$TMP/closure" >"$OUT"
"$HELPER" "$ROOT" ship-prepare friction >"$OUT"
expect 'tracked effect returns to gate' 'status=gate-required' "$OUT"
expect 'tracked effect persists gate phase' $'phase\tgate' "$TRACKER"
expect_absent 'stale gate receipt removed' $'gate\t1\t' "$TRACKER"
"$HELPER" "$ROOT" gate-run friction --class full --label friction-rerun -- true >"$OUT"
expect 'completed hook is not replayed' $'state\tcomplete' "$TRACKER"
expect 'regated shipment becomes ready' $'phase\tready-to-land' "$TRACKER"
expect_eq 'one ship hook identity' 1 "$(awk -F '\t' '$1=="hook"&&$3=="name"&&$4=="ship-friction"{n++}END{print n+0}' "$TRACKER")"

ROOT2="$TMP/late"; init_repo "$ROOT2"
printf 'base\n' >"$ROOT2/file"; git -C "$ROOT2" add file; git -C "$ROOT2" commit -qm initial; mkdir -p "$ROOT2/.streams"
cp "$ROOT/.streams/CONFIG.md" "$ROOT2/.streams/CONFIG.md"
"$HELPER" "$ROOT2" runtime-init late main late >"$OUT"; "$HELPER" "$ROOT2" unit-begin late unit unit >"$OUT"
printf 'unit\n' >>"$ROOT2/.streams/late/file"; git -C "$ROOT2/.streams/late" add file; git -C "$ROOT2/.streams/late" commit -qm unit
"$HELPER" "$ROOT2" unit-complete late >"$OUT"; "$HELPER" "$ROOT2" ship-prepare late >"$OUT"
"$HELPER" "$ROOT2" gate-run late --class full --label clean -- true >"$OUT"
LATE_TRACKER="$ROOT2/.streams/late/workstream.tsv"
expect 'clean gate initially reaches readiness' $'phase\tready-to-land' "$LATE_TRACKER"
"$HELPER" "$ROOT2" friction-add late agent-intervention >"$OUT"
expect 'late friction revokes landing readiness' $'phase\tfriction' "$LATE_TRACKER"
expect 'late friction returns to preparation' $'next-action\tprepare-ship' "$LATE_TRACKER"
"$HELPER" "$ROOT2" ship-prepare late >"$OUT"
expect 'late friction activates configured hook' $'state\tready' "$LATE_TRACKER"
expect_absent 'late friction cannot remain landable' $'phase\tready-to-land' "$LATE_TRACKER"
report 'workstream ship friction'
