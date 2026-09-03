#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; INDEX="$HERE/../operations-index.sh"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-index-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
reserved_owner="draft""s"
public_layer_name="track""ers"
R="$T/root"; mkdir -p "$R/.agents/skilldata/alpha/operations" "$R/.agents/skilldata/beta/operations" "$R/.agents/skilldata/$reserved_owner/operations" "$R/.agents/skilldata/$public_layer_name/operations"; OUT="$T/out"

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
make_op "$R/.agents/skilldata/alpha/operations/build.md" Build draft build
make_op "$R/.agents/skilldata/beta/operations/release.md" Release draft delivery
make_op "$R/.agents/skilldata/beta/operations/old.md" Old deprecated old
make_op "$R/.agents/skilldata/$reserved_owner/operations/hidden.md" Hidden draft hidden
make_op "$R/.agents/skilldata/$public_layer_name/operations/visible.md" Visible draft visible
printf '# Native instructions\n' >"$R/.agents/skilldata/alpha/operations/native.md"
cp "$R/.agents/skilldata/alpha/operations/build.md" "$R/.agents/skilldata/alpha/operations/BAD.md"
mkdir -p "$R/.agents/skilldata/alpha/cache/deep"
printf 'UNRELATED_KIND_CANARY\n' >"$R/.agents/skilldata/alpha/cache/deep/bad.txt"

"$INDEX" list --root "$R" >"$OUT"
eq "default hides deprecated" 4 "$(fact matches "$OUT")"
has "lists direct identity" 'operation=alpha/build|' "$OUT"
has "kind-shaped owner remains valid" 'operation=drafts/hidden|' "$OUT"
has "trackers remains a valid owner name" 'operation=trackers/visible|' "$OUT"
lacks "body not emitted" 'BODY-MUST-NOT-LEAK' "$OUT"
eq "malformed unrelated sibling kinds are inert" 1 "$(fact malformed "$OUT")"
eq "native reported" 1 "$(fact native_candidates "$OUT")"
eq "bad identity malformed" 1 "$(fact malformed "$OUT")"

"$INDEX" search --root "$R" --query delivery >"$OUT"
eq "direct topical lookup" 1 "$(fact matches "$OUT")"; has "release result" 'operation=beta/release|' "$OUT"
"$INDEX" search --root "$R" --query work >"$OUT"
eq "ambiguous search" 4 "$(fact matches "$OUT")"
"$INDEX" search --root "$R" --query absent >"$OUT"
eq "absent search" 0 "$(fact matches "$OUT")"
"$INDEX" list --root "$R" --include-deprecated >"$OUT"
eq "explicit deprecated" 5 "$(fact matches "$OUT")"

mkdir -p "$T/outside/operations" "$T/symlink-root/.agents"
ln -s "$T/outside" "$T/symlink-root/.agents/skilldata"
if "$INDEX" list --root "$T/symlink-root" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "symlinked skilldata root refuses" 'reason=symlink-skilldata-root' "$OUT"

report operations-index-test
