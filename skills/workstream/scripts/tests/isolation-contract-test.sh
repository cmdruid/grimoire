#!/usr/bin/env bash
# Capability policy resolves before instructions are exposed; no dispatcher is implied.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-isolation.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"
trap 'rm -rf "$TMP"' EXIT
init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial; mkdir -p "$ROOT/.streams"

write_config() {
  local execution="$1" concurrency="$2"
  cat >"$ROOT/.streams/CONFIG.md" <<EOF
<!-- workstream:defaults@1 -->
mode: delegate
landing: local
ship-cadence: milestone
<!-- /workstream:defaults@1 -->
<!-- workstream:hook:feature-completion@1 -->
execution: $execution
concurrency: $concurrency

Perform isolated evidence work.
<!-- /workstream:hook:feature-completion@1 -->
EOF
}

make_ready() {
  local stream="$1"
  "$HELPER" "$ROOT" runtime-init "$stream" main "$stream" >"$OUT"
  "$HELPER" "$ROOT" unit-begin "$stream" unit "Unit $stream" >"$OUT"
  printf '%s\n' "$stream" >"$ROOT/.streams/$stream/$stream"
  git -C "$ROOT/.streams/$stream" add "$stream"; git -C "$ROOT/.streams/$stream" commit -qm "change $stream"
  "$HELPER" "$ROOT" unit-complete "$stream" >"$OUT"
  awk -F '\t' '$1=="hook"&&$3=="name"{print $2}' "$ROOT/.streams/$stream/workstream.tsv"
}

write_config isolated-required serial
required_id="$(make_ready required)"
if "$HELPER" "$ROOT" hook-start required "$required_id" --isolation unavailable >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'required refusal leaves ready' $'state\tready' "$ROOT/.streams/required/workstream.tsv"
expect_absent 'required refusal hides body' 'Perform isolated' "$OUT"
"$HELPER" "$ROOT" hook-start required "$required_id" --isolation available >"$OUT"
expect 'required uses isolation' 'execution=isolated' "$OUT"

write_config isolated-preferred parallel-preferred
parallel_id="$(make_ready parallel)"
"$HELPER" "$ROOT" hook-start parallel "$parallel_id" --isolation available >"$OUT"
expect 'parallel preference resolves to serial isolation' 'execution=isolated' "$OUT"
expect_absent 'helper does not claim parallel dispatch' 'execution=parallel' "$OUT"

write_config isolated-preferred parallel-preferred
fallback_id="$(make_ready fallback)"
"$HELPER" "$ROOT" hook-start fallback "$fallback_id" --isolation unavailable >"$OUT"
expect 'parallel-preferred fallback is inline' 'execution=inline' "$OUT"

write_config inline parallel-preferred
if "$HELPER" "$ROOT" runtime-init invalid main invalid >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
if [ ! -e "$ROOT/.streams/invalid" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

report 'workstream isolation contract'
