#!/usr/bin/env bash
# Reconfig adopts project policy only at a quiescent boundary and preserves old receipts.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-reconfig.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
git init -q -b main "$ROOT"; git -C "$ROOT" config user.name test; git -C "$ROOT" config user.email test@example.invalid
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init config main config >"$OUT"; "$HELPER" "$ROOT" operator-note config 'Preserve this note.' >"$OUT"
"$HELPER" "$ROOT" unit-begin config old old >"$OUT"; printf 'old\n' >>"$ROOT/.streams/config/file"; git -C "$ROOT/.streams/config" add file; git -C "$ROOT/.streams/config" commit -qm old; "$HELPER" "$ROOT" unit-complete config >"$OUT"
TRACKER="$ROOT/.streams/config/workstream.tsv"; old_receipt="$(awk -F '\t' '$1=="hook"&&$3=="fingerprint"{print $4;exit}' "$TRACKER")"
cat >"$ROOT/.streams/CONFIG.md" <<'EOF'
<!-- workstream:defaults@1 -->
mode: delegate
isolation: worktree
landing: local
ship-cadence: per-stage
<!-- /workstream:defaults@1 -->
<!-- workstream:hook:feature-completion@1 -->
execution: isolated-preferred
concurrency: serial

Run the new hook body.
<!-- /workstream:hook:feature-completion@1 -->
EOF
"$HELPER" "$ROOT" reconfig config >"$OUT"
expect 'reconfig applies' 'status=applied' "$OUT"
expect 'operator note survives' $'operator-note\tPreserve this note.' "$ROOT/.streams/config/WORKSTREAM.md"
expect 'new hook body compiled' 'Run the new hook body.' "$ROOT/.streams/config/WORKSTREAM.md"
expect 'old receipt retains fingerprint' $'fingerprint\t'"$old_receipt" "$TRACKER"

"$HELPER" "$ROOT" unit-begin config new new >"$OUT"; printf 'new\n' >>"$ROOT/.streams/config/file"; git -C "$ROOT/.streams/config" add file; git -C "$ROOT/.streams/config" commit -qm new; "$HELPER" "$ROOT" unit-complete config >"$OUT"
expect 'future unit adopts new hook' 'hook_state=ready' "$OUT"

sed 's/Run the new hook body./Run the replacement hook body./' "$ROOT/.streams/CONFIG.md" >"$TMP/config-next"; cp "$TMP/config-next" "$ROOT/.streams/CONFIG.md"
cat >"$TMP/interrupt.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/interrupt.sh"
if WORKSTREAM_TEST_AFTER_RECONFIG_PENDING="$TMP/interrupt.sh" "$HELPER" "$ROOT" reconfig config >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'interruption leaves pending hash' 'pending-runbook-contract-sha256' "$TRACKER"
"$HELPER" "$ROOT" reconfig config >"$OUT"
expect 'reconfig retry converges' 'status=applied' "$OUT"
expect_absent 'pending hash clears' 'pending-runbook-contract-sha256' "$TRACKER"
expect 'replacement body adopted' 'Run the replacement hook body.' "$ROOT/.streams/config/WORKSTREAM.md"

sed 's/isolation: worktree/isolation: in-place/' "$ROOT/.streams/CONFIG.md" >"$TMP/topology"; cp "$TMP/topology" "$ROOT/.streams/CONFIG.md"
if "$HELPER" "$ROOT" reconfig config >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'topology refusal preserves worktree coordinate' $'isolation\tworktree' "$ROOT/.streams/config/WORKSTREAM.md"
report 'workstream reconfig'
