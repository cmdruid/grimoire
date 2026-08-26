#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
DEPLOY="$SKILL/scripts/kinds-deploy.sh"
pass=0 fail=0
ok() { if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); else echo "FAIL command: $*" >&2; fail=$((fail + 1)); fi; }
no() { if "$@" >/dev/null 2>&1; then echo "FAIL accepted: $*" >&2; fail=$((fail + 1)); else pass=$((pass + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail + 1)); fi; }

ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
out="$($DEPLOY --root "$ROOT" --workspace .spaces)"
eq "fresh seven-kind deploy" 7 "$(find "$ROOT/.spaces/inspector/doctrine" -type f -name '*.md' | wc -l | tr -d ' ')"
eq "fresh deployed count" 7 "$(printf '%s\n' "$out" | sed -n 's/^deployed_count=//p')"
for source in "$SKILL"/kinds/*.md; do
  cmp "$source" "$ROOT/.spaces/inspector/doctrine/$(basename "$source")" >/dev/null \
    && pass=$((pass + 1)) || fail=$((fail + 1))
done

printf '%s\n' 'project customization' > "$ROOT/.spaces/inspector/doctrine/spec.md"
sum="$(shasum "$ROOT/.spaces/inspector/doctrine/spec.md" | awk '{print $1}')"
printf '%s\n' 'host extra' > "$ROOT/.spaces/inspector/doctrine/house.md"
out="$($DEPLOY --root "$ROOT" --workspace .spaces)"
eq "incumbent preserved" "$sum" "$(shasum "$ROOT/.spaces/inspector/doctrine/spec.md" | awk '{print $1}')"
grep -qF 'host extra' "$ROOT/.spaces/inspector/doctrine/house.md" && pass=$((pass + 1)) || fail=$((fail + 1))
eq "rerun deploys none" 0 "$(printf '%s\n' "$out" | sed -n 's/^deployed_count=//p')"

DECL="$(mktemp -d)"; ok "$DEPLOY" --root "$DECL" --workspace ops
[ -f "$DECL/ops/inspector/doctrine/implementation.md" ] && pass=$((pass + 1)) || fail=$((fail + 1))

# A copied package with a newly bundled kind proves rerun enumeration is dynamic.
PKG="$(mktemp -d)"; mkdir -p "$PKG/scripts" "$PKG/kinds"; cp "$DEPLOY" "$PKG/scripts/kinds-deploy.sh"; cp "$SKILL"/kinds/*.md "$PKG/kinds/"
printf '# Kind: house-new\n' > "$PKG/kinds/house-new.md"
ok "$PKG/scripts/kinds-deploy.sh" --root "$ROOT" --workspace .spaces
cmp "$PKG/kinds/house-new.md" "$ROOT/.spaces/inspector/doctrine/house-new.md" >/dev/null && pass=$((pass + 1)) || fail=$((fail + 1))

TARGET="$(mktemp -d)"; BAD="$(mktemp -d)"; ln -s "$TARGET" "$BAD/.spaces"
no "$DEPLOY" --root "$BAD" --workspace .spaces
eq "parent symlink escape stays empty" 0 "$(find "$TARGET" -mindepth 1 | wc -l | tr -d ' ')"

DEST="$(mktemp -d)"; mkdir -p "$DEST/.spaces/inspector/doctrine"; ln -s "$TARGET/spec.md" "$DEST/.spaces/inspector/doctrine/spec.md"
no "$DEPLOY" --root "$DEST" --workspace .spaces
[ ! -e "$TARGET/spec.md" ] && pass=$((pass + 1)) || fail=$((fail + 1))

COLLIDE="$(mktemp -d)"; mkdir -p "$COLLIDE/.spaces/inspector/doctrine/plan.md"
no "$DEPLOY" --root "$COLLIDE" --workspace .spaces
[ ! -f "$COLLIDE/.spaces/inspector/doctrine/adr.md" ] && pass=$((pass + 1)) || fail=$((fail + 1))
rmdir "$COLLIDE/.spaces/inspector/doctrine/plan.md"; ok "$DEPLOY" --root "$COLLIDE" --workspace .spaces
eq "partial rerun completes" 7 "$(find "$COLLIDE/.spaces/inspector/doctrine" -type f -name '*.md' | wc -l | tr -d ' ')"

RACE="$(mktemp -d)"; mkdir -p "$RACE/.spaces/inspector" "$RACE/elsewhere"; HOOK="$RACE/exchange.sh"
printf '%s\n' '#!/bin/sh' 'mv "$1/$2/inspector" "$1/held"' \
  'ln -s "$1/elsewhere" "$1/$2/inspector"' > "$HOOK"; chmod +x "$HOOK"
if INSPECTOR_SETUP_TEST_AFTER_PREFLIGHT="$HOOK" "$DEPLOY" --root "$RACE" --workspace .spaces >/dev/null 2>&1; then
  echo "FAIL post-preflight exchange accepted" >&2; fail=$((fail + 1))
else pass=$((pass + 1)); fi
[ ! -e "$RACE/elsewhere/doctrine" ] && pass=$((pass + 1)) || fail=$((fail + 1))

PARTIAL="$(mktemp -d)"; WRITE_HOOK="$PARTIAL/stop-after-first.sh"
printf '%s\n' '#!/bin/sh' '[ "$4" -eq 1 ] && exit 86' 'exit 0' > "$WRITE_HOOK"; chmod +x "$WRITE_HOOK"
if INSPECTOR_SETUP_TEST_AFTER_WRITE="$WRITE_HOOK" "$DEPLOY" --root "$PARTIAL" --workspace .spaces >"$PARTIAL/out" 2>&1; then
  echo "FAIL post-first-write interruption was not exercised" >&2; fail=$((fail + 1))
else pass=$((pass + 1)); fi
eq "partial leaves one safe kind" 1 "$(find "$PARTIAL/.spaces/inspector/doctrine" -type f -name '*.md' | wc -l | tr -d ' ')"
grep -q '^deployed=' "$PARTIAL/out" && pass=$((pass + 1)) || fail=$((fail + 1))
ok "$DEPLOY" --root "$PARTIAL" --workspace .spaces
eq "interrupted rerun completes" 7 "$(find "$PARTIAL/.spaces/inspector/doctrine" -type f -name '*.md' | wc -l | tr -d ' ')"

no "$DEPLOY" --root "$ROOT" --workspace .
no "$DEPLOY" --root "$ROOT" --workspace ../escape
no "$DEPLOY" --root "$ROOT" --workspace /absolute

# Red-proof: the planted parent link is capable of escaping if followed.
mkdir -p "$BAD/.spaces/inspector/doctrine"; cp "$SKILL/kinds/spec.md" "$BAD/.spaces/inspector/doctrine/spec.md"
if [ -f "$TARGET/inspector/doctrine/spec.md" ]; then
  pass=$((pass + 1))
else
  echo "FAIL parent-symlink fixture cannot exercise escape" >&2; fail=$((fail + 1))
fi

rm -rf "$DECL" "$PKG" "$TARGET" "$BAD" "$DEST" "$COLLIDE" "$RACE" "$PARTIAL"
echo "setup-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
