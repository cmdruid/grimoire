#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; BASE="$(CDPATH='' cd -P "$HERE/../.." && pwd)"; CHECK="$HERE/../operation-check.sh"; GOAL="$HERE/../goal-compile.sh"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-composition-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
R="$T/root"; O="$R/.spaces/foreman/operations"; mkdir -p "$O"; OUT="$T/out"
make_proc() { cat >"$1" <<EOF
---
schema: foreman/operation@1
title: $2
use-when: Compose the $3 step.
shape: procedure
status: draft
areas: [testing]
tags: [composition]
---

# $2
## Preconditions
- Ready.
## Procedure
1. Perform $3.
## Outputs
- $3 evidence.
## Verification
- Confirm $3.
## Recovery
- Retry $3 safely.
EOF
}
activate() {
  id="$1"; file="$O/${id#*/}.md"; "$CHECK" --root "$R" --operation "$id" >"$OUT" || return 1; d="$(fact digest "$OUT")"
  sed -i.bak -e 's/status: draft/status: active/' -e "/^tags:/a\\
verified-against: $d" "$file"; rm "$file.bak"
}
make_proc "$O/first.md" First first; make_proc "$O/second.md" Second second; activate foreman/first; activate foreman/second
cat >"$O/sequence.md" <<'EOF'
---
schema: foreman/operation@1
title: Ordered sequence
use-when: Run the composed sequence.
shape: workflow
status: draft
areas: [testing]
tags: [composition]
---

# Ordered sequence
## Preconditions
- Ready.
## Steps
1. `foreman/second`
2. `foreman/first`
## Outputs
- Both results.
## Verification
- Confirm both results.
## Recovery
- Resume the failed operation.
EOF
activate foreman/sequence
"$GOAL" render --root "$R" --operation foreman/sequence --objective 'Exercise ordered composition' --output "$T/goal.md" >"$OUT"
second_line="$(grep -n '### `foreman/second`' "$T/goal.md"|head -n1|cut -d: -f1)"; first_line="$(grep -n '### `foreman/first`' "$T/goal.md"|head -n1|cut -d: -f1)"
ok test "$second_line" -lt "$first_line"
eq "nested closure count" 3 "$(fact operations "$OUT")"

sed -i.bak 's/foreman\/first/foreman\/missing/' "$O/sequence.md"; rm "$O/sequence.md.bak"
if "$CHECK" --root "$R" --operation foreman/sequence >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "missing closure rejected" missing-operation "$OUT"
sed -i.bak 's/foreman\/missing/foreman\/sequence/' "$O/sequence.md"; rm "$O/sequence.md.bak"
if "$CHECK" --root "$R" --operation foreman/sequence >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "cycle rejected" cycle "$OUT"

for needle in 'duplicated instruction' 'ordered list' 'Missing references' 'Nested workflows' \
  'Do not copy a referenced body' 'mutable step state'; do has "compose rule $needle" "$needle" "$BASE/verbs/compose.md"; done
report composition-test
