#!/usr/bin/env bash
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"; SETUP="$HERE/../debugger-setup.sh"; pass=0 fail=0
eq(){ if [ "$2" = "$3" ]; then pass=$((pass+1)); else echo "FAIL: $1 — want <$2>, got <$3>" >&2; fail=$((fail+1)); fi; }
has(){ if grep -qF -- "$2" "$3"; then pass=$((pass+1)); else echo "FAIL: $1 — missing $2" >&2; fail=$((fail+1)); fi; }
no(){ if [ ! -e "$2" ] && [ ! -L "$2" ]; then pass=$((pass+1)); else echo "FAIL: $1 — exists $2" >&2; fail=$((fail+1)); fi; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/debugger-setup.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT

ROOT="$TMP/root"; mkdir -p "$ROOT"; OUT="$TMP/out"
bash "$SETUP" --write-only "$ROOT" >"$OUT"
eq "fresh asset count" 3 "$(find "$ROOT/.agents/skilldata/debugger" -type f | wc -l | tr -d ' ')"
for file in bugs.md investigation.md; do test -f "$ROOT/.agents/skilldata/debugger/templates/$file" && pass=$((pass+1)) || fail=$((fail+1)); done
has "operation schema" 'schema: foreman/operation@1' "$ROOT/.agents/skilldata/debugger/operations/diagnostics.md"
has "operation evidence" 'verified-against: sha256:' "$ROOT/.agents/skilldata/debugger/operations/diagnostics.md"
has "direct procedure" '## Procedure' "$ROOT/.agents/skilldata/debugger/operations/diagnostics.md"
no "no schema deployment" "$ROOT/.agents/skilldata/debugger/schemas"
no "no record shell" "$ROOT/.agents/skilldata/debugger/templates/reports.md"
CUSTOM='PROJECT CUSTOM'; printf '\n%s\n' "$CUSTOM" >> "$ROOT/.agents/skilldata/debugger/templates/bugs.md"
SUM="$(cksum "$ROOT/.agents/skilldata/debugger/templates/bugs.md")"; bash "$SETUP" --write-only "$ROOT" >"$OUT"
eq "incumbent preserved" "$SUM" "$(cksum "$ROOT/.agents/skilldata/debugger/templates/bugs.md")"
has "rerun zero writes" 'writes=0' "$OUT"

LEG="$TMP/legacy"; mkdir -p "$LEG/.records/templates/debugger"; printf '# Legacy\n' > "$LEG/.records/templates/debugger/bugs.md"
if bash "$SETUP" --write-only "$LEG" >"$OUT" 2>&1; then echo 'FAIL: legacy accepted' >&2; fail=$((fail+1)); else pass=$((pass+1)); fi
has "legacy migrate route" '/debugger migrate' "$OUT"
no "legacy not adopted" "$LEG/.agents/skilldata/debugger/templates/bugs.md"

UNSAFE="$TMP/unsafe"; mkdir -p "$UNSAFE/elsewhere" "$UNSAFE/.agents"; ln -s "$UNSAFE/elsewhere" "$UNSAFE/.agents/skilldata"
if bash "$SETUP" --write-only "$UNSAFE" >"$OUT" 2>&1; then echo 'FAIL: unsafe parent accepted' >&2; fail=$((fail+1)); else pass=$((pass+1)); fi
no "unsafe writes nothing through link" "$UNSAFE/elsewhere/debugger"

RACE="$TMP/race"; mkdir -p "$RACE/.agents/skilldata/debugger" "$RACE/elsewhere"; HOOK="$TMP/preflight.sh"
printf '%s\n' '#!/bin/sh' 'mv "$1/$2/debugger" "$1/held"' 'ln -s "$1/elsewhere" "$1/$2/debugger"' > "$HOOK"; chmod +x "$HOOK"
if DEBUGGER_SETUP_TEST_AFTER_PREFLIGHT="$HOOK" bash "$SETUP" --write-only "$RACE" >"$OUT" 2>&1; then echo 'FAIL: exchanged parent accepted' >&2; fail=$((fail+1)); else pass=$((pass+1)); fi
has "immediate recheck cause" 'symlinked destination parent' "$OUT"
no "recheck writes nothing through link" "$RACE/elsewhere/templates"

PART="$TMP/partial"; mkdir -p "$PART"; PHOOK="$TMP/partial.sh"
printf '%s\n' '#!/bin/sh' '[ "$4" -ne 1 ] && exit 0' 'mv "$1/$2/debugger/templates" "$1/held-templates"' 'ln -s "$1/elsewhere" "$1/$2/debugger/templates"' > "$PHOOK"; chmod +x "$PHOOK"; mkdir -p "$PART/elsewhere"
if DEBUGGER_SETUP_TEST_AFTER_WRITE="$PHOOK" bash "$SETUP" --write-only "$PART" >"$OUT" 2>&1; then echo 'FAIL: partial exchange accepted' >&2; fail=$((fail+1)); else pass=$((pass+1)); fi
has "partial reports completed path" 'created=.agents/skilldata/debugger/templates/bugs.md' "$OUT"
mv "$PART/.agents/skilldata/debugger/templates" "$PART/bad-link"; mv "$PART/held-templates" "$PART/.agents/skilldata/debugger/templates"
bash "$SETUP" --write-only "$PART" >"$OUT"
eq "partial rerun converges" 3 "$(find "$PART/.agents/skilldata/debugger" -type f | wc -l | tr -d ' ')"

GITROOT="$TMP/git"; mkdir -p "$GITROOT"; git -C "$GITROOT" init -q; git -C "$GITROOT" config user.name Fixture; git -C "$GITROOT" config user.email fixture@example.invalid
printf '# Fixture\n' > "$GITROOT/README.md"; git -C "$GITROOT" add README.md; git -C "$GITROOT" commit -qm init
bash "$SETUP" "$GITROOT" >"$OUT"
eq "standalone commit exact paths" "$(printf '%s\n' .agents/skilldata/debugger/operations/diagnostics.md .agents/skilldata/debugger/templates/bugs.md .agents/skilldata/debugger/templates/investigation.md)" "$(git -C "$GITROOT" show --pretty='' --name-only HEAD | sed '/^$/d' | sort)"
HEAD1="$(git -C "$GITROOT" rev-parse HEAD)"; bash "$SETUP" "$GITROOT" >"$OUT"; eq "standalone no-op makes no commit" "$HEAD1" "$(git -C "$GITROOT" rev-parse HEAD)"

BOUND="$TMP/bound"; mkdir -p "$BOUND"
if DEBUGGER_SETUP_TEST_ASSET='templates/package-only.md' bash "$SETUP" --write-only "$BOUND" >/dev/null 2>&1; then echo 'FAIL: package-only accepted' >&2; fail=$((fail+1)); else pass=$((pass+1)); fi
if DEBUGGER_SETUP_TEST_DEST_REL='.agents/skilldata/notepad/templates/bugs.md' bash "$SETUP" --write-only "$BOUND" >/dev/null 2>&1; then echo 'FAIL: sibling dest accepted' >&2; fail=$((fail+1)); else pass=$((pass+1)); fi

echo "debugger setup-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
