#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; CENSUS="$HERE/../migration-census.sh"; WRITE="$HERE/../operation-write.sh"; FIX="$HERE/fixtures/migration"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-migration-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
OUT="$T/out"; R="$T/root"; mkdir -p "$R/source/vendor" "$R/source/dist" "$R/.spaces/publisher/operations"
cp "$FIX/source.md" "$R/source/release.md"; printf 'notes only\n' >"$R/source/notes.txt"
printf '\000\001\002' >"$R/source/binary.bin"; printf 'generated file\n' >"$R/source/dist/out.txt"
printf 'vendor procedure\n' >"$R/source/vendor/tool.txt"; printf 'api_key=fixture-secret\n' >"$R/source/secret.txt"
printf 'unsafe pipe\n' >"$R/source/pipe|reason=fake.md"
printf 'unsafe tab\n' >"$R/source/tab"$'\t'"name.md"
printf 'unsafe newline\n' >"$R/source/newline"$'\n'"name.md"
ln -s "$R/source/release.md" "$R/source/link.md"
awk '{print}' "$FIX/clean-operation.md" >"$R/.spaces/publisher/operations/release.md"
source_sum="$(cksum "$R/source/release.md")"; existing_sum="$(cksum "$R/.spaces/publisher/operations/release.md")"

"$CENSUS" --root "$R" --workspace .spaces --source source >"$OUT"
has "text admitted" 'item=source/release.md|digest=sha256:' "$OUT"
has "conforming reported" 'conforming=.spaces/publisher/operations/release.md' <("$CENSUS" --root "$R" --workspace .spaces --source .spaces/publisher/operations/release.md)
for reason in binary generated vendored secret-bearing symlink; do has "skip $reason" "reason=$reason" "$OUT"; done
eq "unsafe paths skipped" 3 "$(grep -c 'reason=unsafe-path' "$OUT")"
lacks "unsafe fact delimiter hidden" 'pipe|reason=fake.md' "$OUT"
lacks "unsafe control path hidden" $'tab\tname.md' "$OUT"
eq "preview write free" 0 "$(find "$R/.spaces/foreman" -type f 2>/dev/null | wc -l | tr -d ' ')"
eq "source unchanged" "$source_sum" "$(cksum "$R/source/release.md")"

mkdir "$T/outside"; printf 'outside\n' >"$T/outside/runbook.md"
if "$CENSUS" --root "$R" --workspace .spaces --source ../outside >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "canonical source boundary" 'reason=source-outside-root' "$OUT"
if "$CENSUS" --root "$R" --workspace .spaces --source 'source/pipe|reason=fake.md' >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "explicit unsafe source path" 'reason=unsafe-source-path' "$OUT"

EMPTY="$R/empty"; mkdir "$EMPTY"; "$CENSUS" --root "$R" --workspace .spaces --source empty >"$OUT"; eq "zero census" 0 "$(fact items "$OUT")"
"$CENSUS" --root "$R" --workspace .spaces --source source/release.md >"$OUT"; eq "one census" 1 "$(fact items "$OUT")"

child="$T/child.md"; awk '{print}' "$FIX/clean-operation.md" >"$child"
workflow="$T/workflow.md"; cat >"$workflow" <<'EOF'
---
schema: foreman/operation@1
title: Release workflow
use-when: Coordinate the migrated release operation.
shape: workflow
status: draft
areas: [delivery]
tags: [release]
---

# Release workflow
## Preconditions
- Candidate exists.
## Steps
1. `foreman/prepare-release`
## Outputs
- Release evidence.
## Verification
- Confirm the child completed.
## Recovery
- Resume the child.
EOF
sd="sha256:$(shasum -a 256 "$R/source/release.md" | awk '{print $1}')"
batch="$T/batch.tsv"; printf 'foreman/prepare-release\t%s\tsource/release.md\t%s\nforeman/release-workflow\t%s\tsource/release.md\t%s\n' "$child" "$sd" "$workflow" "$sd" >"$batch"

BOUND="$T/bound"; mkdir -p "$BOUND/source"; printf 'pipe source\n' >"$BOUND/source/pipe|name.md"
bsd="sha256:$(shasum -a 256 "$BOUND/source/pipe|name.md" | awk '{print $1}')"
printf 'foreman/unsafe-source\t%s\tsource/pipe|name.md\t%s\n' "$child" "$bsd" >"$T/unsafe-source.tsv"
if "$WRITE" migrate-batch --root "$BOUND" --workspace .spaces --batch "$T/unsafe-source.tsv" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "writer rejects fact delimiter source" 'reason=unsafe-source' "$OUT"; ok test ! -e "$BOUND/.spaces"
printf 'foreman/bad-row\t%s\tsource/release.md\t%s\textra\n' "$child" "$sd" >"$T/bad-row.tsv"
if "$WRITE" migrate-batch --root "$R" --workspace .spaces --batch "$T/bad-row.tsv" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "writer rejects extra TSV field" 'reason=bad-batch-row' "$OUT"

SUB="$T/subset"; mkdir "$SUB"; cp "$R/source/release.md" "$SUB/source.md"; ssd="sha256:$(shasum -a 256 "$SUB/source.md"|awk '{print $1}')"
printf 'foreman/release-workflow\t%s\tsource.md\t%s\n' "$workflow" "$ssd" >"$T/subset.tsv"
if "$WRITE" migrate-batch --root "$SUB" --workspace .spaces --batch "$T/subset.tsv" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "subset closure refusal" 'reason=incomplete-or-invalid-closure' "$OUT"; ok test ! -e "$SUB/.spaces"

"$WRITE" migrate-batch --root "$R" --workspace .spaces --batch "$batch" >"$OUT"
eq "many candidates written" 2 "$(fact writes "$OUT")"; ok test -f "$R/.spaces/foreman/operations/release-workflow.md"
eq "source still exact" "$source_sum" "$(cksum "$R/source/release.md")"; eq "foreign incumbent exact" "$existing_sum" "$(cksum "$R/.spaces/publisher/operations/release.md")"
ok test ! -e "$R/.spaces/foreman/migrations"; ok test ! -e "$R/.spaces/foreman/manifest.tsv"
"$WRITE" migrate-batch --root "$R" --workspace .spaces --batch "$batch" >"$OUT"; eq "rerun no writes" 0 "$(fact writes "$OUT")"; eq "rerun preserves two" 2 "$(fact preserved_count "$OUT")"

DRIFT="$T/drift"; mkdir "$DRIFT"; cp "$FIX/source.md" "$DRIFT/source.md"
awk '{print}' "$FIX/clean-operation.md" >"$T/drift-candidate.md"
dsd="sha256:$(shasum -a 256 "$DRIFT/source.md"|awk '{print $1}')"; printf 'foreman/drift\t%s\tsource.md\t%s\n' "$T/drift-candidate.md" "$dsd" >"$T/drift.tsv"; printf 'changed\n' >>"$DRIFT/source.md"
if "$WRITE" migrate-batch --root "$DRIFT" --workspace .spaces --batch "$T/drift.tsv" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "source drift" 'reason=source-drift' "$OUT"; ok test ! -e "$DRIFT/.spaces"

PART="$T/partial"; mkdir "$PART"; cp "$FIX/source.md" "$PART/source.md"; psd="sha256:$(shasum -a 256 "$PART/source.md"|awk '{print $1}')"
printf 'foreman/prepare-release\t%s\tsource.md\t%s\nforeman/release-workflow\t%s\tsource.md\t%s\n' "$child" "$psd" "$workflow" "$psd" >"$T/partial.tsv"
hook="$T/stop-after-one.sh"; printf '%s\n' '#!/bin/sh' '[ "$4" -eq 1 ] && exit 86' 'exit 0' >"$hook"; chmod +x "$hook"
if FOREMAN_WRITE_TEST_AFTER_WRITE="$hook" "$WRITE" migrate-batch --root "$PART" --workspace .spaces --batch "$T/partial.tsv" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
eq "partial wrote one" 1 "$(find "$PART/.spaces/foreman/operations" -type f | wc -l | tr -d ' ')"
"$WRITE" migrate-batch --root "$PART" --workspace .spaces --batch "$T/partial.tsv" >"$OUT"; eq "partial rerun remaining" 1 "$(fact writes "$OUT")"; eq "partial converged" 2 "$(find "$PART/.spaces/foreman/operations" -type f | wc -l | tr -d ' ')"

FOREIGN="$T/foreign"; mkdir "$FOREIGN"; cp "$FIX/source.md" "$FOREIGN/source.md"; fsd="sha256:$(shasum -a 256 "$FOREIGN/source.md"|awk '{print $1}')"; printf 'debugger/release\t%s\tsource.md\t%s\n' "$child" "$fsd" >"$T/foreign.tsv"
if "$WRITE" migrate-batch --root "$FOREIGN" --workspace .spaces --batch "$T/foreign.tsv" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "foreign migration refused" 'reason=foreign-owner' "$OUT"; ok test ! -e "$FOREIGN/.spaces"

report migration-test
