#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; CHECK="$HERE/../operation-check.sh"; WRITE="$HERE/../operation-write.sh"; FIX="$HERE/fixtures/migration/clean-operation.md"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-verification-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
R="$T/root"; O="$R/.agents/skilldata/foreman/operations"; mkdir -p "$O"; OUT="$T/out"; awk '{print}' "$FIX" >"$O/release.md"
evidence="$T/evidence.md"; printf '%s\n' '- observed: test gate passed; artifact digest recorded.' >"$evidence"
"$CHECK" --root "$R" --operation foreman/release >"$OUT"; d1="$(fact digest "$OUT")"
"$WRITE" verify --root "$R" --identity foreman/release --expected-digest "$d1" --evidence-file "$evidence" >"$OUT"
has "writer verified" 'status=verified' "$OUT"; "$CHECK" --root "$R" --operation foreman/release >"$OUT"
eq "evidence current" current "$(fact verification "$OUT")"; eq "digest stable" "$d1" "$(fact digest "$OUT")"
has "compact evidence persisted" 'observed: test gate passed' "$O/release.md"; ok test "$(wc -c <"$evidence" | tr -d ' ')" -lt 8192
sed -i.bak '$s/test gate passed/test gate passed again/' "$O/release.md"; rm "$O/release.md.bak"
"$CHECK" --root "$R" --operation foreman/release >"$OUT"; eq "evidence edits excluded" "$d1" "$(fact digest "$OUT")"
sed -i.bak 's/Build the release artifact/Build a changed artifact/' "$O/release.md"; rm "$O/release.md.bak"
"$CHECK" --root "$R" --operation foreman/release >"$OUT"; eq "procedure edit stale" stale "$(fact verification "$OUT")"

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
"$CHECK" --root "$R" --operation foreman/parent >"$OUT"; pd="$(fact digest "$OUT")"
"$WRITE" verify --root "$R" --identity foreman/parent --expected-digest "$pd" --evidence-file "$evidence" >/dev/null
sed -i.bak 's/Build the release artifact/Build a newer artifact/' "$O/child.md"; rm "$O/child.md.bak"
"$CHECK" --root "$R" --operation foreman/parent >"$OUT"; eq "child edit stale parent" stale "$(fact verification "$OUT")"

# Imported source drift also stales the pin.
printf 'native one\n' >"$R/native.txt"; sd="$(shasum -a 256 "$R/native.txt"|awk '{print $1}')"; awk '{print}' "$FIX" >"$O/imported.md"
sed -i.bak "/^status:/a\\
source: native.txt\\
entry-point: release section\\
source-digest: sha256:$sd" "$O/imported.md"; rm "$O/imported.md.bak"
"$CHECK" --root "$R" --operation foreman/imported >"$OUT"; id="$(fact digest "$OUT")"
"$WRITE" verify --root "$R" --identity foreman/imported --expected-digest "$id" --evidence-file "$evidence" >/dev/null
printf 'native two\n' >"$R/native.txt"; "$CHECK" --root "$R" --operation foreman/imported >"$OUT"
eq "import source drift" false "$(fact source_current "$OUT")"; eq "import evidence stale" stale "$(fact verification "$OUT")"

if "$WRITE" verify --root "$R" --identity debugger/diagnostics --expected-digest "$d1" --evidence-file "$evidence" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "foreign evidence proposal" 'status=proposed' "$OUT"; has "foreign write false" 'write=false' "$OUT"

# Promotion binds the reviewed evidence and draft-to-active transition in one replacement.
PR="$T/promote"; PO="$PR/.agents/skilldata/foreman/operations"; mkdir -p "$PO"; cp "$FIX" "$PO/release.md"
pe="$T/promotion-evidence.md"; printf '%s\n' '- observed: release checks passed; artifact digest retained.' >"$pe"
"$CHECK" --root "$PR" --operation foreman/release >"$OUT"; pd="$(fact digest "$OUT")"
raw="$(shasum -a 256 "$PO/release.md"|awk '{print $1}')"; eraw="$(shasum -a 256 "$pe"|awk '{print $1}')"
"$WRITE" promote --root "$PR" --identity foreman/release --expected-digest "$pd" \
  --expected-file-sha256 "$raw" --evidence-file "$pe" --expected-evidence-sha256 "$eraw" >"$OUT"
has "promotion transition" 'transition=draft-to-active' "$OUT"; has "promotion status" 'status: active' "$PO/release.md"
has "promotion evidence" 'release checks passed' "$PO/release.md"
"$CHECK" --root "$PR" --operation foreman/release >"$OUT"
eq "promoted current" current "$(fact verification "$OUT")"; eq "promoted eligible" true "$(fact goal_eligible "$OUT")"
promoted_raw="$(shasum -a 256 "$PO/release.md"|awk '{print $1}')"
if "$WRITE" promote --root "$PR" --identity foreman/release --expected-digest "$pd" \
  --expected-file-sha256 "$promoted_raw" --evidence-file "$pe" --expected-evidence-sha256 "$eraw" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "repeat promotion refused" 'reason=status-not-draft' "$OUT"
eq "repeat preserves bytes" "$promoted_raw" "$(shasum -a 256 "$PO/release.md"|awk '{print $1}')"

# Evidence, destination, source, ownership, and staging races all refuse without a writer-side partial state.
fresh_promotion() { # root stem
  mkdir -p "$1/.agents/skilldata/foreman/operations"; cp "$FIX" "$1/.agents/skilldata/foreman/operations/$2.md"
  "$CHECK" --root "$1" --operation "foreman/$2" >"$T/fresh.out"
  fresh_digest="$(fact digest "$T/fresh.out")"
  fresh_raw="$(shasum -a 256 "$1/.agents/skilldata/foreman/operations/$2.md"|awk '{print $1}')"
}

ER="$T/evidence-race"; fresh_promotion "$ER" release; before="$fresh_raw"
EHOOK="$T/evidence-race.sh"; printf '%s\n' '#!/bin/sh' 'printf "changed\\n" >>"$4"' >"$EHOOK"; chmod +x "$EHOOK"
if FOREMAN_WRITE_TEST_PROMOTE_BEFORE_REPLACE="$EHOOK" "$WRITE" promote --root "$ER" --identity foreman/release \
  --expected-digest "$fresh_digest" --expected-file-sha256 "$fresh_raw" --evidence-file "$pe" --expected-evidence-sha256 "$eraw" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "evidence race refused" 'reason=evidence-drift' "$OUT"
eq "evidence race preserves operation" "$before" "$(shasum -a 256 "$ER/.agents/skilldata/foreman/operations/release.md"|awk '{print $1}')"
printf '%s\n' '- observed: release checks passed; artifact digest retained.' >"$pe"; eraw="$(shasum -a 256 "$pe"|awk '{print $1}')"

DR="$T/destination-race"; fresh_promotion "$DR" release
DHOOK="$T/destination-race.sh"; printf '%s\n' '#!/bin/sh' 'printf "destination-race\\n" >>"$1/$2/foreman/operations/release.md"' >"$DHOOK"; chmod +x "$DHOOK"
if FOREMAN_WRITE_TEST_PROMOTE_BEFORE_REPLACE="$DHOOK" "$WRITE" promote --root "$DR" --identity foreman/release \
  --expected-digest "$fresh_digest" --expected-file-sha256 "$fresh_raw" --evidence-file "$pe" --expected-evidence-sha256 "$eraw" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "destination race refused" 'reason=destination-drift' "$OUT"; lacks "destination race not promoted" 'status: active' "$DR/.agents/skilldata/foreman/operations/release.md"

SR="$T/stage-interrupt"; fresh_promotion "$SR" release; before="$fresh_raw"
SHOOK="$T/stage-interrupt.sh"; printf '%s\n' '#!/bin/sh' 'exit 86' >"$SHOOK"; chmod +x "$SHOOK"
if FOREMAN_WRITE_TEST_PROMOTE_AFTER_STAGE="$SHOOK" "$WRITE" promote --root "$SR" --identity foreman/release \
  --expected-digest "$fresh_digest" --expected-file-sha256 "$fresh_raw" --evidence-file "$pe" --expected-evidence-sha256 "$eraw" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
eq "stage interruption preserves bytes" "$before" "$(shasum -a 256 "$SR/.agents/skilldata/foreman/operations/release.md"|awk '{print $1}')"
eq "stage interruption cleans replacement" 0 "$(find "$SR/.agents/skilldata/foreman/operations" -name '.foreman-promote.*'|wc -l|tr -d ' ')"

if "$WRITE" promote --root "$SR" --identity debugger/release --expected-digest "$fresh_digest" \
  --expected-file-sha256 "$fresh_raw" --evidence-file "$pe" --expected-evidence-sha256 "$eraw" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "foreign promotion proposed" 'status=proposed' "$OUT"; has "foreign promotion writes nothing" 'write=false' "$OUT"

IR="$T/import-race"; fresh_promotion "$IR" imported; printf 'native one\n' >"$IR/native.txt"
isd="$(shasum -a 256 "$IR/native.txt"|awk '{print $1}')"
sed -i.bak "/^status:/a\\
source: native.txt\\
entry-point: release section\\
source-digest: sha256:$isd" "$IR/.agents/skilldata/foreman/operations/imported.md"; rm "$IR/.agents/skilldata/foreman/operations/imported.md.bak"
"$CHECK" --root "$IR" --operation foreman/imported >"$OUT"; current_import_digest="$(fact digest "$OUT")"
import_raw="$(shasum -a 256 "$IR/.agents/skilldata/foreman/operations/imported.md"|awk '{print $1}')"; printf 'native two\n' >"$IR/native.txt"
"$CHECK" --root "$IR" --operation foreman/imported >"$OUT"; drift_digest="$(fact digest "$OUT")"
if "$WRITE" promote --root "$IR" --identity foreman/imported --expected-digest "$drift_digest" \
  --expected-file-sha256 "$import_raw" --evidence-file "$pe" --expected-evidence-sha256 "$eraw" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "source drift refused" 'reason=source-drift' "$OUT"; ok test -n "$current_import_digest"

CR="$T/child-race"; CO="$CR/.agents/skilldata/foreman/operations"; mkdir -p "$CO"; cp "$FIX" "$CO/child.md"
"$CHECK" --root "$CR" --operation foreman/child >"$OUT"; child_digest="$(fact digest "$OUT")"
sed -i.bak -e 's/status: draft/status: active/' -e "/^tags:/a\\
verified-against: $child_digest" "$CO/child.md"; rm "$CO/child.md.bak"
cat >"$CO/parent.md" <<'EOF'
---
schema: foreman/operation@1
title: Parent promotion
use-when: Validate a child immediately before promotion.
shape: workflow
status: draft
areas: [testing]
tags: [promotion]
---

# Parent promotion
## Preconditions
- Ready.
## Steps
1. `foreman/child`
## Outputs
- Child output.
## Verification
- Confirm child output.
## Recovery
- Resume the child.
EOF
"$CHECK" --root "$CR" --operation foreman/parent >"$OUT"; child_parent_digest="$(fact digest "$OUT")"
child_parent_raw="$(shasum -a 256 "$CO/parent.md"|awk '{print $1}')"
CHOOK="$T/child-race.sh"; printf '%s\n' '#!/bin/sh' 'sed -i.bak "s/shape: procedure/shape: invalid/" "$1/$2/foreman/operations/child.md"' 'rm "$1/$2/foreman/operations/child.md.bak"' >"$CHOOK"; chmod +x "$CHOOK"
if FOREMAN_WRITE_TEST_PROMOTE_BEFORE_REPLACE="$CHOOK" "$WRITE" promote --root "$CR" --identity foreman/parent \
  --expected-digest "$child_parent_digest" --expected-file-sha256 "$child_parent_raw" --evidence-file "$pe" --expected-evidence-sha256 "$eraw" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "child invalidation refused" 'reason=invalid-operation' "$OUT"
eq "child invalidation preserves parent" "$child_parent_raw" "$(shasum -a 256 "$CO/parent.md"|awk '{print $1}')"

CIR="$T/ineligible-child"; CIO="$CIR/.agents/skilldata/foreman/operations"; mkdir -p "$CIO"
cp "$FIX" "$CIO/child.md"; cp "$CO/parent.md" "$CIO/parent.md"
"$CHECK" --root "$CIR" --operation foreman/parent >"$OUT"; ineligible_parent_digest="$(fact digest "$OUT")"
ineligible_parent_raw="$(shasum -a 256 "$CIO/parent.md"|awk '{print $1}')"
if "$WRITE" promote --root "$CIR" --identity foreman/parent --expected-digest "$ineligible_parent_digest" \
  --expected-file-sha256 "$ineligible_parent_raw" --evidence-file "$pe" --expected-evidence-sha256 "$eraw" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "ineligible child refused" 'reason=ineligible-child' "$OUT"
eq "ineligible child preserves parent" "$ineligible_parent_raw" "$(shasum -a 256 "$CIO/parent.md"|awk '{print $1}')"

EMPTY="$T/empty-evidence"; : >"$EMPTY"
if "$WRITE" promote --root "$SR" --identity foreman/release --expected-digest "$fresh_digest" \
  --expected-file-sha256 "$fresh_raw" --evidence-file "$EMPTY" --expected-evidence-sha256 "$(shasum -a 256 "$EMPTY"|awk '{print $1}')" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "incomplete evidence refused" 'reason=bad-evidence' "$OUT"

# Red-proof the final evidence recheck and the one-file atomic replacement independently.
BROKEN="$T/broken"; mkdir -p "$BROKEN"; cp "$WRITE" "$BROKEN/operation-write.sh"; cp "$CHECK" "$BROKEN/operation-check.sh"; chmod +x "$BROKEN/"*.sh
cp "$BROKEN/operation-write.sh" "$T/writer.before"
region="$T/recheck-region"; sed -n '/FOREMAN_WRITE_TEST_PROMOTE_BEFORE_REPLACE/,/mv "$replacement" "$file"/p' "$BROKEN/operation-write.sh" >"$region"
eq "evidence recheck target unique" 1 "$(grep -c '\[ "$(sha256_file "$evidence_file")" = "$expected_evidence_sha256" \] || die evidence-drift' "$region")"
sed -i.bak '/FOREMAN_WRITE_TEST_PROMOTE_BEFORE_REPLACE/,/mv "$replacement" "$file"/ s/\[ "$(sha256_file "$evidence_file")" = "$expected_evidence_sha256" \] || die evidence-drift/: # evidence recheck disabled/' "$BROKEN/operation-write.sh"; rm "$BROKEN/operation-write.sh.bak"
BR="$T/broken-recheck"; fresh_promotion "$BR" release; printf '%s\n' '- observed: release checks passed; artifact digest retained.' >"$pe"; eraw="$(shasum -a 256 "$pe"|awk '{print $1}')"
if FOREMAN_WRITE_TEST_PROMOTE_BEFORE_REPLACE="$EHOOK" "$BROKEN/operation-write.sh" promote --root "$BR" --identity foreman/release \
  --expected-digest "$fresh_digest" --expected-file-sha256 "$fresh_raw" --evidence-file "$pe" --expected-evidence-sha256 "$eraw" >"$OUT"; then pass=$((pass+1)); else fail=$((fail+1)); fi
has "disabled recheck lets stale preview land" 'status: active' "$BR/.agents/skilldata/foreman/operations/release.md"
cp "$T/writer.before" "$BROKEN/operation-write.sh"; ok cmp -s "$T/writer.before" "$BROKEN/operation-write.sh"

eq "atomic replacement target unique" 1 "$(grep -c 'mv "$replacement" "$file"; replacement=""' "$BROKEN/operation-write.sh")"
sed -i.bak 's#    mv "$replacement" "$file"; replacement=""#    head -n 8 "$replacement" >"$file"; false; replacement=""#' "$BROKEN/operation-write.sh"; rm "$BROKEN/operation-write.sh.bak"
AR="$T/broken-atomic"; fresh_promotion "$AR" release; before="$fresh_raw"
if "$BROKEN/operation-write.sh" promote --root "$AR" --identity foreman/release --expected-digest "$fresh_digest" \
  --expected-file-sha256 "$fresh_raw" --evidence-file "$pe" --expected-evidence-sha256 "$(shasum -a 256 "$pe"|awk '{print $1}')" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
ok test "$before" != "$(shasum -a 256 "$AR/.agents/skilldata/foreman/operations/release.md"|awk '{print $1}')"
cp "$T/writer.before" "$BROKEN/operation-write.sh"; ok cmp -s "$T/writer.before" "$BROKEN/operation-write.sh"

report verification-test
