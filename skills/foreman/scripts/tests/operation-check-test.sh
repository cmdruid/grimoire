#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; CHECK="$HERE/../operation-check.sh"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-check-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
R="$T/root"; O="$R/.spaces/foreman/operations"; mkdir -p "$O"; OUT="$T/out"

procedure() { # path, title, body
  file="$1"; title="$2"; body="$3"
  cat >"$file" <<EOF
---
schema: foreman/operation@1
title: $title
use-when: Exercise the operation checker.
shape: procedure
status: draft
areas: [testing]
tags: [fixture]
---

# $title

## Preconditions

- Fixture exists.

## Procedure

1. $body

## Outputs

- Evidence.

## Verification

- Confirm evidence.

## Recovery

- Restore the fixture.
EOF
}

procedure "$O/child.md" Child 'write child output.'
"$CHECK" --root "$R" --operation foreman/child >"$OUT"
eq "procedure valid" true "$(fact valid "$OUT")"
d1="$(fact digest "$OUT")"

cat >>"$O/child.md" <<'EOF'

## Verification evidence

- A compact result that must not affect instruction identity.
EOF
"$CHECK" --root "$R" --operation foreman/child >"$OUT"
eq "evidence excluded" "$d1" "$(fact digest "$OUT")"
sed -i.bak 's/write child output/write changed child output/' "$O/child.md"; rm "$O/child.md.bak"
"$CHECK" --root "$R" --operation foreman/child >"$OUT"
d2="$(fact digest "$OUT")"; ok test "$d1" != "$d2"

cat >"$O/parent.md" <<'EOF'
---
schema: foreman/operation@1
title: Parent
use-when: Exercise nested digest propagation.
shape: workflow
status: draft
areas: [testing]
tags: [fixture]
---

# Parent

## Preconditions

- Fixture exists.

## Steps

1. `foreman/child` — follow the child first.

## Outputs

- Child evidence.

## Verification

- Confirm the child completed.

## Recovery

- Resume from the child.
EOF
"$CHECK" --root "$R" --operation foreman/parent >"$OUT"
p1="$(fact digest "$OUT")"; eq "workflow valid" true "$(fact valid "$OUT")"
sed -i.bak 's/write changed child output/write newest child output/' "$O/child.md"; rm "$O/child.md.bak"
"$CHECK" --root "$R" --operation foreman/parent >"$OUT"
ok test "$p1" != "$(fact digest "$OUT")"

sed -i.bak 's/foreman\/child/foreman\/missing/' "$O/parent.md"; rm "$O/parent.md.bak"
if "$CHECK" --root "$R" --operation foreman/parent >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "missing reference" 'missing-operation' "$OUT"

sed -i.bak 's/foreman\/missing/foreman\/parent/' "$O/parent.md"; rm "$O/parent.md.bak"
if "$CHECK" --root "$R" --operation foreman/parent >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "cycle rejected" 'cycle' "$OUT"

printf 'native v1\n' >"$R/native.txt"; sd="$(shasum -a 256 "$R/native.txt" | awk '{print $1}')"
procedure "$O/imported.md" Imported 'follow the native source.'
sed -i.bak "/^status:/a\\
source: native.txt\\
entry-point: section one\\
source-digest: sha256:$sd" "$O/imported.md"; rm "$O/imported.md.bak"
"$CHECK" --root "$R" --operation foreman/imported >"$OUT"
eq "import source current" true "$(fact source_current "$OUT")"; i1="$(fact digest "$OUT")"
printf 'native v2\n' >"$R/native.txt"
"$CHECK" --root "$R" --operation foreman/imported >"$OUT"
eq "import drift" false "$(fact source_current "$OUT")"; ok test "$i1" != "$(fact digest "$OUT")"

procedure "$O/bad.md" Bad 'fail shape.'
sed -i.bak 's/shape: procedure/shape: workflow/' "$O/bad.md"; rm "$O/bad.md.bak"
if "$CHECK" --root "$R" --operation foreman/bad >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "malformed shape" 'workflow-shape-mismatch' "$OUT"

report operation-check-test
