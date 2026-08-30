#!/usr/bin/env bash
set -u
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; WRITE="$HERE/../operation-write.sh"; FIX="$HERE/fixtures/migration"
. "$HERE/lib.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/foreman-redaction-test.XXXXXX")"; trap 'rm -rf "$T"' EXIT
R="$T/root"; mkdir -p "$R"; cp "$FIX/source.md" "$R/source.md"; sd="sha256:$(shasum -a 256 "$R/source.md"|awk '{print $1}')"; OUT="$T/out"
deny="$T/deny"; printf 'SECRET_DO_NOT_PERSIST\n' >"$deny"
printf 'foreman/clean\t%s\tsource.md\t%s\n' "$FIX/clean-operation.md" "$sd" >"$T/clean.tsv"
"$WRITE" migrate-batch --root "$R" --batch "$T/clean.tsv" --deny-list "$deny" >"$OUT"
ok test -f "$R/.spaces/foreman/operations/clean.md"
printf 'foreman/tainted\t%s\tsource.md\t%s\n' "$FIX/tainted-operation.md" "$sd" >"$T/tainted.tsv"
if "$WRITE" migrate-batch --root "$R" --batch "$T/tainted.tsv" --deny-list "$deny" >"$OUT"; then fail=$((fail+1)); else pass=$((pass+1)); fi
has "taint refused" 'reason=tainted-candidate' "$OUT"; ok test ! -e "$R/.spaces/foreman/operations/tainted.md"
lacks "deny bytes absent from output" 'SECRET_DO_NOT_PERSIST' "$OUT"
if rg -l 'SECRET_DO_NOT_PERSIST' "$R/.spaces" >/dev/null 2>&1; then fail=$((fail+1)); else pass=$((pass+1)); fi

# Red-proof: disabling exactly one writer condition admits the planted marker.
broken="$T/broken-writer.sh"; cp "$WRITE" "$broken"; cp "$HERE/../operation-check.sh" "$T/operation-check.sh"; before="$(grep -c 'grep -F -f.*row_candidate' "$broken")"
sed -i.bak 's/if \[ -s "$filtered_deny" \] && grep -F -f/if false \&\& grep -F -f/' "$broken"; rm "$broken.bak"
after="$(grep -c 'if false.*grep -F -f' "$broken")"; eq "redaction mutation applied" 1 "$before"; eq "redaction guard disabled" 1 "$after"; chmod +x "$broken"
"$broken" migrate-batch --root "$R" --batch "$T/tainted.tsv" --deny-list "$deny" >/dev/null
has "disabled guard plants marker" 'SECRET_DO_NOT_PERSIST' "$R/.spaces/foreman/operations/tainted.md"

report migration-redaction-test
