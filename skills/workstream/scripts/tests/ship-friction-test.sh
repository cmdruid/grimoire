#!/usr/bin/env bash
# Friction runs once before readiness and tracked effects invalidate the gate.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-friction.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial; mkdir -p "$ROOT/.streams"
cat >"$ROOT/.streams/CONFIG.md" <<'EOF'
<!-- workstream:defaults@1 -->
mode: delegate
isolation: worktree
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
"$HELPER" "$ROOT" gate-run friction --class docs --label friction -- true >"$OUT"
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
expect 'tracked effect returns to gate' 'phase=gate' "$OUT"
expect_absent 'stale gate receipt removed' $'gate\t1\t' "$TRACKER"
"$HELPER" "$ROOT" gate-run friction --class docs --label friction-rerun -- true >"$OUT"
expect 'completed hook is not replayed' $'state\tcomplete' "$TRACKER"
expect 'regated shipment becomes ready' $'phase\tready-to-land' "$TRACKER"
expect_eq 'one ship hook identity' 1 "$(awk -F '\t' '$1=="hook"&&$3=="name"&&$4=="ship-friction"{n++}END{print n+0}' "$TRACKER")"
report 'workstream ship friction'
