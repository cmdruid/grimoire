#!/usr/bin/env bash
# Save changes only the bounded semantic note and is race-safe/idempotent.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-note.XXXXXX")"; TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"; OUT="$TMP/out"; ERR="$TMP/err"
trap 'rm -rf "$TMP"' EXIT
init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"; git -C "$ROOT" add file; git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init notes main notes >"$OUT"
RUNBOOK="$ROOT/.streams/notes/WORKSTREAM.md"; TRACKER="$ROOT/.streams/notes/workstream.tsv"
tracker_before="$(shasum -a 256 "$TRACKER" | awk '{print $1}')"
contract_before="$(awk '/^<!-- workstream:(identity|policy)@1 -->$/ || /^<!-- workstream:hook:(feature-completion|ship-friction)@1 -->$/{inside=1} inside{print} /^<!-- \/workstream:(identity|policy)@1 -->$/ || /^<!-- \/workstream:hook:(feature-completion|ship-friction)@1 -->$/{inside=0}' "$RUNBOOK" | shasum -a 256 | awk '{print $1}')"
"$HELPER" "$ROOT" operator-note notes 'Resume with the parser boundary.' >"$OUT"
expect 'note save reports saved' 'status=saved' "$OUT"
"$HELPER" "$ROOT" read notes >"$OUT"; expect 'read projects note' 'operator_note=Resume with the parser boundary.' "$OUT"
expect_eq 'note save leaves tracker untouched' "$tracker_before" "$(shasum -a 256 "$TRACKER" | awk '{print $1}')"
contract_after="$(awk '/^<!-- workstream:(identity|policy)@1 -->$/ || /^<!-- workstream:hook:(feature-completion|ship-friction)@1 -->$/{inside=1} inside{print} /^<!-- \/workstream:(identity|policy)@1 -->$/ || /^<!-- \/workstream:hook:(feature-completion|ship-friction)@1 -->$/{inside=0}' "$RUNBOOK" | shasum -a 256 | awk '{print $1}')"
expect_eq 'note is outside contract hash' "$contract_before" "$contract_after"
runbook_before="$(shasum -a 256 "$RUNBOOK" | awk '{print $1}')"
"$HELPER" "$ROOT" operator-note notes 'Resume with the parser boundary.' >"$OUT"
expect 'same note converges' 'status=unchanged' "$OUT"
expect_eq 'idempotent save preserves bytes' "$runbook_before" "$(shasum -a 256 "$RUNBOOK" | awk '{print $1}')"

cp "$RUNBOOK" "$TMP/runbook-before-race"
cat >"$TMP/race.sh" <<'EOF'
#!/usr/bin/env bash
printf '\nconcurrent prose\n' >>"$1"
EOF
chmod +x "$TMP/race.sh"
if WORKSTREAM_TEST_BEFORE_RUNBOOK_REPLACE="$TMP/race.sh" "$HELPER" "$ROOT" operator-note notes 'A different note' >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect_absent 'racing save does not install candidate' 'operator-note	A different note' "$RUNBOOK"
cp "$TMP/runbook-before-race" "$RUNBOOK"
if "$HELPER" "$ROOT" operator-note notes $'bad\tnote' >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
wide=''; index=0
while [ "$index" -lt 2049 ]; do wide="${wide}é"; index=$((index + 1)); done
if "$HELPER" "$ROOT" operator-note notes "$wide" >"$OUT" 2>"$ERR"; then fail=$((fail + 1)); else pass=$((pass + 1)); fi
expect 'multibyte note uses byte ceiling' '1..4096 bytes' "$ERR"

report 'workstream operator note'
