#!/usr/bin/env bash
# Reconfig adopts project policy only at a quiescent boundary and preserves old receipts.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"; # shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-reconfig.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"; trap 'rm -rf "$TMP"' EXIT
init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init config main config >"$OUT"; "$HELPER" "$ROOT" operator-note config 'Preserve this note.' >"$OUT"
"$HELPER" "$ROOT" unit-begin config old old >"$OUT"; printf 'old\n' >>"$ROOT/.streams/config/file"; git -C "$ROOT/.streams/config" add file; git -C "$ROOT/.streams/config" commit -qm old; "$HELPER" "$ROOT" unit-complete config >"$OUT"
TRACKER="$ROOT/.streams/config/workstream.tsv"; old_receipt="$(awk -F '\t' '$1=="hook"&&$3=="fingerprint"{print $4;exit}' "$TRACKER")"
cat >"$ROOT/.streams/CONFIG.md" <<'EOF'
<!-- workstream:defaults@1 -->
mode: delegate
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
"$HELPER" "$ROOT" reconfig config --mode manual --ship-cadence per-track >"$OUT"
expect 'explicit mode records provenance' $'mode\tmanual\texplicit' "$ROOT/.streams/config/WORKSTREAM.md"
expect 'explicit cadence records provenance' $'ship-cadence\tper-track\texplicit' "$ROOT/.streams/config/WORKSTREAM.md"
"$HELPER" "$ROOT" reconfig config >"$OUT"
expect 'implicit adoption preserves explicit mode' $'mode\tmanual\texplicit' "$ROOT/.streams/config/WORKSTREAM.md"
"$HELPER" "$ROOT" reconfig config --inherit mode --inherit ship-cadence >"$OUT"
expect 'inherit restores project mode' $'mode\tdelegate\tproject' "$ROOT/.streams/config/WORKSTREAM.md"
expect 'inherit restores project cadence' $'ship-cadence\tper-stage\tproject' "$ROOT/.streams/config/WORKSTREAM.md"
if "$HELPER" "$ROOT" reconfig config --mode manual --inherit mode >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi

"$HELPER" "$ROOT" unit-begin config new new >"$OUT"
if "$HELPER" "$ROOT" reconfig config >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
printf 'new\n' >>"$ROOT/.streams/config/file"; git -C "$ROOT/.streams/config" add file; git -C "$ROOT/.streams/config" commit -qm new; "$HELPER" "$ROOT" unit-complete config >"$OUT"
expect 'future unit adopts new hook' 'hook_state=ready' "$OUT"
if "$HELPER" "$ROOT" reconfig config >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
identity="$(awk -F '\t' '$1=="hook"&&$3=="state"&&$4=="ready"{print $2;exit}' "$TRACKER")"
"$HELPER" "$ROOT" hook-start config "$identity" --isolation unavailable >"$OUT"
cat >"$TMP/closure" <<'EOF'
status: complete
summary: Hook complete.
effects: none
parent-actions: none
EOF
"$HELPER" "$ROOT" hook-complete config "$identity" --closure "$TMP/closure" >"$OUT"

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

sed 's/ship-cadence: per-stage/ship-cadence: milestone/' "$ROOT/.streams/CONFIG.md" >"$TMP/config-race"; cp "$TMP/config-race" "$ROOT/.streams/CONFIG.md"
contract_before="$(shasum -a 256 "$ROOT/.streams/config/WORKSTREAM.md" | awk '{print $1}')"
tracker_before="$(shasum -a 256 "$TRACKER" | awk '{print $1}')"
cat >"$TMP/config-mutator.sh" <<'EOF'
#!/usr/bin/env bash
printf '\n# concurrent config edit\n' >>"$1"
EOF
chmod +x "$TMP/config-mutator.sh"
if WORKSTREAM_TEST_BEFORE_RECONFIG_CONFIG_RECHECK="$TMP/config-mutator.sh" "$HELPER" "$ROOT" reconfig config >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'config race is detected' 'configuration changed during reconfig' "$ERR"
expect_eq 'config race preserves runbook' "$contract_before" "$(shasum -a 256 "$ROOT/.streams/config/WORKSTREAM.md" | awk '{print $1}')"
expect_eq 'config race preserves tracker' "$tracker_before" "$(shasum -a 256 "$TRACKER" | awk '{print $1}')"

runbook_before="$(shasum -a 256 "$ROOT/.streams/config/WORKSTREAM.md" | awk '{print $1}')"
tracker_before="$(shasum -a 256 "$TRACKER" | awk '{print $1}')"
cat >"$TMP/runbook-mutator.sh" <<'EOF'
#!/usr/bin/env bash
printf '\nConcurrent operator appendix.\n' >>"$1"
EOF
chmod +x "$TMP/runbook-mutator.sh"
if WORKSTREAM_TEST_AFTER_RUNBOOK_SNAPSHOT="$TMP/runbook-mutator.sh" "$HELPER" "$ROOT" reconfig config >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'runbook race is detected' 'runbook changed during reconfig' "$ERR"
expect 'runbook race preserves concurrent prose' 'Concurrent operator appendix.' "$ROOT/.streams/config/WORKSTREAM.md"
expect_eq 'runbook race writes no tracker transaction' "$tracker_before" "$(shasum -a 256 "$TRACKER" | awk '{print $1}')"
if [ "$runbook_before" != "$(shasum -a 256 "$ROOT/.streams/config/WORKSTREAM.md" | awk '{print $1}')" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

awk '{ print } $0=="mode: delegate" { print "isolation: worktree" }' "$ROOT/.streams/CONFIG.md" >"$TMP/topology"; cp "$TMP/topology" "$ROOT/.streams/CONFIG.md"
if "$HELPER" "$ROOT" reconfig config >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'retired config field is rejected' 'configuration violates workstream config@1' "$ERR"
expect_absent 'retired config field never enters the runbook' $'isolation\t' "$ROOT/.streams/config/WORKSTREAM.md"

ROOT2="$TMP/unknown-option"; init_repo "$ROOT2"
printf 'base\n' >"$ROOT2/file"; git -C "$ROOT2" add file; git -C "$ROOT2" commit -qm initial; mkdir -p "$ROOT2/.streams"
sed -n 'p' "$DIR/../../templates/streams-config.md" >"$ROOT2/.streams/CONFIG.md"
if "$HELPER" "$ROOT2" runtime-init explicit main explicit --isolation worktree >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'retired create option is unknown' 'unknown runtime-init option: --isolation' "$ERR"
if [ ! -e "$ROOT2/.streams/explicit" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
report 'workstream reconfig'
