#!/usr/bin/env bash
# Session span is helper-owned, contract-hash-neutral, and copied through reconfig.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-session.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"
OUT="$TMP/out"
ERR="$TMP/err"
trap 'rm -rf "$TMP"' EXIT

init_repo "$ROOT"
printf 'base\n' >"$ROOT/file"
git -C "$ROOT" add file
git -C "$ROOT" commit -qm initial
"$HELPER" "$ROOT" runtime-init sess main sess >"$OUT"
RUNBOOK="$ROOT/.streams/sess/WORKSTREAM.md"
expect 'create emits session open marker' '<!-- workstream:session@1 -->' "$RUNBOOK"
expect 'create emits session close marker' '<!-- /workstream:session@1 -->' "$RUNBOOK"
"$HELPER" "$ROOT" read sess >"$OUT"
expect 'new stream session is empty' 'session=empty' "$OUT"
expect 'new stream has no completed units' 'completed:-' "$OUT"

contract_before="$(awk -F '\t' '$1=="meta"&&$3=="runbook-contract-sha256"{print $4}' "$ROOT/.streams/sess/workstream.tsv")"
cat >"$TMP/body.md" <<'EOF'
last-updated: 2026-09-04
TL;DR: Keep the session span.
next: define the first unit
EOF
"$HELPER" "$ROOT" session-set sess --body "$TMP/body.md" --note 'define the first unit' >"$OUT"
expect 'session-set reports saved' 'status=saved' "$OUT"
expect 'session-set reports present' 'session=present' "$OUT"
expect 'session body is in the runbook' 'Keep the session span.' "$RUNBOOK"
expect 'operator-note follows --note' $'operator-note\tdefine the first unit' "$RUNBOOK"
contract_after="$(awk -F '\t' '$1=="meta"&&$3=="runbook-contract-sha256"{print $4}' "$ROOT/.streams/sess/workstream.tsv")"
expect_eq 'session-set does not change contract hash' "$contract_before" "$contract_after"
"$HELPER" "$ROOT" read sess >"$OUT"
expect 'read reports session present' 'session=present' "$OUT"
expect 'read echoes operator note' 'operator_note=define the first unit' "$OUT"

if "$HELPER" "$ROOT" session-set sess --body "$TMP/body.md" --note 'define the first unit' >/dev/null 2>"$ERR"; then
  :
fi
: >"$TMP/empty.md"
if "$HELPER" "$ROOT" session-set sess --body "$TMP/empty.md" --note 'x' >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1))
  echo 'FAIL: empty session body was accepted' >&2
else
  pass=$((pass + 1))
fi
expect 'empty body is refused' 'session body is empty' "$ERR"

printf '<!-- workstream:session@1 -->\n' >"$TMP/nested.md"
if "$HELPER" "$ROOT" session-set sess --body "$TMP/nested.md" --note 'x' >"$OUT" 2>"$ERR"; then
  fail=$((fail + 1))
  echo 'FAIL: nested session marker was accepted' >&2
else
  pass=$((pass + 1))
fi

"$HELPER" "$ROOT" reconfig sess --landing push >"$OUT"
expect 'reconfig applies' 'status=applied' "$OUT"
expect 'reconfig preserves session body' 'Keep the session span.' "$RUNBOOK"
"$HELPER" "$ROOT" read sess >"$OUT"
expect 'session remains present after reconfig' 'session=present' "$OUT"

"$HELPER" "$ROOT" unit-begin sess first 'First unit' >"$OUT"
printf 'one\n' >>"$ROOT/.streams/sess/file"
git -C "$ROOT/.streams/sess" add file
git -C "$ROOT/.streams/sess" commit -qm first
"$HELPER" "$ROOT" unit-complete sess >"$OUT"
"$HELPER" "$ROOT" read sess >"$OUT"
expect 'read names completed units' 'completed:1/first/1/First unit' "$OUT"

chmod 644 "$RUNBOOK"
"$HELPER" "$ROOT" repair sess >"$OUT"
expect 'repair preserves session body' 'Keep the session span.' "$RUNBOOK"

report 'workstream session span'
