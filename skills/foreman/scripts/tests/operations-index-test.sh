#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; INDEX="$HERE/../operations-index.sh"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-index-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
R="$T/root"; mkdir -p "$R/.spaces/alpha/operations" "$R/.spaces/beta/operations"; OUT="$T/out"

make_op() { # path title status token
cat >"$1" <<EOF
---
schema: foreman/operation@1
title: $2
use-when: Use this for $4 work.
shape: procedure
status: $3
areas: [development]
tags: [$4]
---

# $2
BODY-MUST-NOT-LEAK

## Preconditions
- Ready.
## Procedure
1. Do the work.
## Outputs
- Result.
## Verification
- Check result.
## Recovery
- Retry safely.
EOF
}
make_op "$R/.spaces/alpha/operations/build.md" Build draft build
make_op "$R/.spaces/beta/operations/release.md" Release draft delivery
make_op "$R/.spaces/beta/operations/old.md" Old deprecated old
printf '# Native instructions\n' >"$R/.spaces/alpha/operations/native.md"
cp "$R/.spaces/alpha/operations/build.md" "$R/.spaces/alpha/operations/BAD.md"

"$INDEX" list --root "$R" --workspace .spaces >"$OUT"
eq "default hides deprecated" 2 "$(fact matches "$OUT")"
has "lists direct identity" 'operation=alpha/build|' "$OUT"
lacks "body not emitted" 'BODY-MUST-NOT-LEAK' "$OUT"
eq "native reported" 1 "$(fact native_candidates "$OUT")"
eq "bad identity malformed" 1 "$(fact malformed "$OUT")"

"$INDEX" search --root "$R" --workspace .spaces --query delivery >"$OUT"
eq "direct topical lookup" 1 "$(fact matches "$OUT")"; has "release result" 'operation=beta/release|' "$OUT"
"$INDEX" search --root "$R" --workspace .spaces --query work >"$OUT"
eq "ambiguous search" 2 "$(fact matches "$OUT")"
"$INDEX" search --root "$R" --workspace .spaces --query absent >"$OUT"
eq "absent search" 0 "$(fact matches "$OUT")"
"$INDEX" list --root "$R" --workspace .spaces --include-deprecated >"$OUT"
eq "explicit deprecated" 3 "$(fact matches "$OUT")"

report operations-index-test
