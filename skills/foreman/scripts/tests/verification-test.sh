#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; CHECK="$HERE/../operation-check.sh"; WRITE="$HERE/../operation-write.sh"; FIX="$HERE/fixtures/migration/clean-operation.md"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-verification-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
R="$T/root"; O="$R/.spaces/foreman/operations"; mkdir -p "$O"; OUT="$T/out"; awk '{print}' "$FIX" >"$O/release.md"
evidence="$T/evidence.md"; printf '%s\n' '- observed: test gate passed; artifact digest recorded.' >"$evidence"
"$CHECK" --root "$R" --workspace .spaces --operation foreman/release >"$OUT"; d1="$(fact digest "$OUT")"
"$WRITE" verify --root "$R" --workspace .spaces --identity foreman/release --expected-digest "$d1" --evidence-file "$evidence" >"$OUT"
has "writer verified" 'status=verified' "$OUT"; "$CHECK" --root "$R" --workspace .spaces --operation foreman/release >"$OUT"
eq "evidence current" current "$(fact verification "$OUT")"; eq "digest stable" "$d1" "$(fact digest "$OUT")"
has "compact evidence persisted" 'observed: test gate passed' "$O/release.md"; ok test "$(wc -c <"$evidence" | tr -d ' ')" -lt 8192
sed -i.bak '$s/test gate passed/test gate passed again/' "$O/release.md"; rm "$O/release.md.bak"
"$CHECK" --root "$R" --workspace .spaces --operation foreman/release >"$OUT"; eq "evidence edits excluded" "$d1" "$(fact digest "$OUT")"
sed -i.bak 's/Build the release artifact/Build a changed artifact/' "$O/release.md"; rm "$O/release.md.bak"
"$CHECK" --root "$R" --workspace .spaces --operation foreman/release >"$OUT"; eq "procedure edit stale" stale "$(fact verification "$OUT")"

# A parent pin changes when a referenced operation changes.
awk '{print}' "$FIX" >"$O/child.md"
cat >"$O/parent.md" <<'EOF'
---
schema: foreman/operation@1
title: Parent
use-when: Verify recursive evidence.
shape: workflow
status: draft
areas: [testing]
tags: [fixture]
---

# Parent
## Preconditions
- Ready.
## Steps
1. `foreman/child`
## Outputs
- Evidence.
## Verification
- Confirm the child.
## Recovery
- Resume the child.
EOF
"$CHECK" --root "$R" --workspace .spaces --operation foreman/parent >"$OUT"; pd="$(fact digest "$OUT")"
"$WRITE" verify --root "$R" --workspace .spaces --identity foreman/parent --expected-digest "$pd" --evidence-file "$evidence" >/dev/null
sed -i.bak 's/Build the release artifact/Build a newer artifact/' "$O/child.md"; rm "$O/child.md.bak"
"$CHECK" --root "$R" --workspace .spaces --operation foreman/parent >"$OUT"; eq "child edit stale parent" stale "$(fact verification "$OUT")"

# Imported source drift also stales the pin.
printf 'native one\n' >"$R/native.txt"; sd="$(shasum -a 256 "$R/native.txt"|awk '{print $1}')"; awk '{print}' "$FIX" >"$O/imported.md"
sed -i.bak "/^status:/a\\
source: native.txt\\
entry-point: release section\\
source-digest: sha256:$sd" "$O/imported.md"; rm "$O/imported.md.bak"
"$CHECK" --root "$R" --workspace .spaces --operation foreman/imported >"$OUT"; id="$(fact digest "$OUT")"
"$WRITE" verify --root "$R" --workspace .spaces --identity foreman/imported --expected-digest "$id" --evidence-file "$evidence" >/dev/null
printf 'native two\n' >"$R/native.txt"; "$CHECK" --root "$R" --workspace .spaces --operation foreman/imported >"$OUT"
eq "import source drift" false "$(fact source_current "$OUT")"; eq "import evidence stale" stale "$(fact verification "$OUT")"

if "$WRITE" verify --root "$R" --workspace .spaces --identity debugger/diagnostics --expected-digest "$d1" --evidence-file "$evidence" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "foreign evidence proposal" 'status=proposed' "$OUT"; has "foreign write false" 'write=false' "$OUT"

report verification-test
