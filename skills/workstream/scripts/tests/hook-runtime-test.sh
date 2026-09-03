#!/usr/bin/env bash
# Hook bodies are exposed only after the durable ready-to-running transition.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-hook.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"
trap 'rm -rf "$TMP"' EXIT

init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial; mkdir -p "$ROOT/.streams"
cat >"$ROOT/.streams/CONFIG.md" <<'EOF'
<!-- workstream:defaults@1 -->
mode: delegate
isolation: worktree
landing: local
ship-cadence: milestone
<!-- /workstream:defaults@1 -->
<!-- workstream:hook:feature-completion@1 -->
execution: isolated-preferred
concurrency: serial

/backlog debrief
Inspect the completed unit.
<!-- /workstream:hook:feature-completion@1 -->
EOF
"$HELPER" "$ROOT" runtime-init hooked main hooked >"$OUT"
"$HELPER" "$ROOT" unit-begin hooked hook 'Hooked unit' >"$OUT"
printf 'change\n' >>"$ROOT/.streams/hooked/file"; git -C "$ROOT/.streams/hooked" add file; git -C "$ROOT/.streams/hooked" commit -qm 'hooked change'
"$HELPER" "$ROOT" unit-complete hooked >"$OUT"
expect 'active hook is ready' 'hook_state=ready' "$OUT"
expect 'active hook becomes next action' 'next_action=feature-hook' "$OUT"
TRACKER="$ROOT/.streams/hooked/workstream.tsv"
identity="$(awk -F= '$1=="hook_identity" {print $2}' "$OUT")"
expect 'completion exposes hook identity' 'hook_identity=hooked/' "$OUT"
expect 'emitted identity names durable receipt' $'hook\t'"$identity"$'\tname\tfeature-completion' "$TRACKER"
"$HELPER" "$ROOT" read hooked >"$OUT"
expect_absent 'ordinary read hides body' '/backlog debrief' "$OUT"
expect 'recovery read exposes hook identity' "hook_identity=$identity" "$OUT"
expect 'recovery read exposes hook state' 'hook_state=ready' "$OUT"
expect 'ready receipt is durable' $'state\tready' "$TRACKER"
if "$HELPER" "$ROOT" unit-begin hooked next 'Next unit' >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
if "$HELPER" "$ROOT" ship-prepare hooked >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi

"$HELPER" "$ROOT" hook-start hooked "$identity" --isolation unavailable >"$OUT"
expect 'preferred isolation falls back inline' 'execution=inline' "$OUT"
expect 'fallback is declared' 'fallback=inline' "$OUT"
expect 'one body is exposed' '/backlog debrief' "$OUT"
expect 'receipt is running before return' $'state\trunning' "$TRACKER"
if "$HELPER" "$ROOT" hook-start hooked "$identity" --isolation available >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi

cat >"$TMP/blocked.closure" <<'EOF'
status: blocked
summary: provider unavailable
effects: none
parent-actions: retry later
EOF
if "$HELPER" "$ROOT" hook-complete hooked "$identity" --closure "$TMP/blocked.closure" >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'blocked child stays running' $'state\trunning' "$TRACKER"

cat >"$TMP/bad.closure" <<'EOF'
summary: wrong order
status: complete
effects: none
parent-actions: none
EOF
if "$HELPER" "$ROOT" hook-complete hooked "$identity" --closure "$TMP/bad.closure" >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'malformed closure stays running' $'state\trunning' "$TRACKER"

cat >"$TMP/done.closure" <<'EOF'
status: complete
summary: debrief recorded
effects: none
parent-actions: none
EOF
"$HELPER" "$ROOT" hook-complete hooked "$identity" --closure "$TMP/done.closure" >"$OUT"
expect 'hook completes' 'status=complete' "$OUT"
expect 'complete receipt is durable' $'state\tcomplete' "$TRACKER"
expect 'closure evidence is digested' $'evidence-sha256\t' "$TRACKER"
if "$HELPER" "$ROOT" hook-complete hooked "$identity" --closure "$TMP/done.closure" >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi

report 'workstream hook runtime'
