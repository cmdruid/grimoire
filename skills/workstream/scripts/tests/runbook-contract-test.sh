#!/usr/bin/env bash
# Configuration compilation and runbook/tracker contract recovery.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-runbook.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"
trap 'rm -rf "$TMP"' EXIT

init_repo "$ROOT"
printf 'fixture\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
mkdir -p "$ROOT/.streams"

write_valid_config() {
  cat >"$ROOT/.streams/CONFIG.md" <<'EOF'
# project prose
<!-- workstream:defaults@1 -->
mode: delegate
landing: local
ship-cadence: milestone
<!-- /workstream:defaults@1 -->

<!-- workstream:hook:feature-completion@1 -->
execution: isolated-preferred
concurrency: parallel-preferred

/backlog debrief
Return only durable closure evidence.
<!-- /workstream:hook:feature-completion@1 -->
EOF
}

write_valid_config
"$HELPER" "$ROOT" runtime-init compiled main 'Compiled purpose' >"$OUT"
RUNBOOK="$ROOT/.streams/compiled/WORKSTREAM.md"; TRACKER="$ROOT/.streams/compiled/workstream.tsv"
expect 'project mode compiled' $'mode\tdelegate\tproject' "$RUNBOOK"
expect 'hook execution compiled' $'execution\tisolated-preferred' "$RUNBOOK"
expect 'opaque hook body preserved' '/backlog debrief' "$RUNBOOK"
"$HELPER" "$ROOT" read compiled >"$OUT"
expect 'read emits purpose' 'purpose=Compiled purpose' "$OUT"
expect_absent 'read hides inactive hook body' '/backlog debrief' "$OUT"

literal_note='literal\nkeep\tbytes'
"$HELPER" "$ROOT" operator-note compiled "$literal_note" >"$OUT"
expect 'operator note preserves literal backslashes' $'operator-note\tliteral\\nkeep\\tbytes' "$RUNBOOK"
expect_eq 'operator note remains one field row' 1 "$(grep -cF $'operator-note\tliteral\\nkeep\\tbytes' "$RUNBOOK")"

printf '\nProject-authored appendix.\n' >>"$RUNBOOK"
"$HELPER" "$ROOT" state compiled >"$OUT"
expect 'authored prose is outside contract hash' 'schema=workstream-state@1' "$OUT"

cp "$TRACKER" "$TMP/tracker-base"
pending="$(printf 'a%.0s' {1..64})"
awk -F '\t' -v p="$pending" 'BEGIN{OFS="\t"} $1=="meta"&&$3=="runbook-contract-sha256"{print "meta","-","pending-runbook-contract-sha256",p} {print}' "$TRACKER" >"$TMP/pending"
cp "$TMP/pending" "$TRACKER"
if "$HELPER" "$ROOT" state compiled >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
"$HELPER" "$ROOT" contract-recover compiled >"$OUT"
expect 'old runbook rolls pending hash back' 'outcome=rolled-back' "$OUT"
expect_absent 'pending row removed' 'pending-runbook-contract-sha256' "$TRACKER"

cp "$RUNBOOK" "$TMP/runbook-old"
awk 'BEGIN{FS=OFS="\t"} $1=="mode"&&$2=="delegate"{$2="manual"} {print}' "$RUNBOOK" >"$TMP/runbook-new"
contract="$TMP/contract"
awk '/^<!-- workstream:(identity|policy)@1 -->$/ || /^<!-- workstream:hook:(feature-completion|ship-friction)@1 -->$/ {inside=1} inside{print} /^<!-- \/workstream:(identity|policy)@1 -->$/ || /^<!-- \/workstream:hook:(feature-completion|ship-friction)@1 -->$/ {inside=0}' "$TMP/runbook-new" >"$contract"
new_hash="$(shasum -a 256 "$contract" | awk '{print $1}')"
awk -F '\t' -v p="$new_hash" 'BEGIN{OFS="\t"} $1=="meta"&&$3=="runbook-contract-sha256"{print "meta","-","pending-runbook-contract-sha256",p} {print}' "$TRACKER" >"$TMP/pending-new"
cp "$TMP/pending-new" "$TRACKER"; cp "$TMP/runbook-new" "$RUNBOOK"
"$HELPER" "$ROOT" contract-recover compiled >"$OUT"
expect 'new runbook promotes pending hash' 'outcome=promoted' "$OUT"
expect 'promoted hash is authoritative' $'runbook-contract-sha256\t'"$new_hash" "$TRACKER"
"$HELPER" "$ROOT" state compiled >"$OUT"
expect 'promoted contract admits' 'schema=workstream-state@1' "$OUT"

cp "$TRACKER" "$TMP/good-tracker"; cp "$RUNBOOK" "$TMP/good-runbook"
write_valid_config
sed 's/workstream:defaults@1/workstream:defaults@2/' "$ROOT/.streams/CONFIG.md" >"$TMP/bad-version"
cp "$TMP/bad-version" "$ROOT/.streams/CONFIG.md"
if "$HELPER" "$ROOT" runtime-init bad-version main bad >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
if [ ! -e "$ROOT/.streams/bad-version" ] && ! git -C "$ROOT" show-ref --verify --quiet refs/heads/stream/bad-version; then pass=$((pass + 1)); else fail=$((fail + 1)); fi

write_valid_config
sed 's/landing: local/landing: push/' "$ROOT/.streams/CONFIG.md" >"$TMP/bad-combo"; cp "$TMP/bad-combo" "$ROOT/.streams/CONFIG.md"
"$HELPER" "$ROOT" runtime-init push-config main push >"$OUT"
expect 'linked stream accepts configured push landing' $'landing\tpush\tproject' "$ROOT/.streams/push-config/WORKSTREAM.md"

report 'workstream runbook contract'
