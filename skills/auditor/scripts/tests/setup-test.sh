#!/usr/bin/env bash
set -eu
D="$(cd "$(dirname "$0")"&&pwd)";S="$D/../auditor-seed.sh";p=0;f=0
ok(){ if "$@";then p=$((p+1));else echo "FAIL: $*" >&2;f=$((f+1));fi;}
eq(){ if [ "$2" = "$3" ];then p=$((p+1));else echo "FAIL: $1 — want $2 got $3" >&2;f=$((f+1));fi;}
no(){ if [ ! -e "$2" ]&&[ ! -L "$2" ];then p=$((p+1));else echo "FAIL: $1" >&2;f=$((f+1));fi;}
forbidden_clear(){ local r="$1";[ ! -d "$r/.records/reports" ]||[ "$(find "$r/.records/reports" -type f|wc -l|tr -d ' ')" -eq 0 ]||return 1;! grep -q 'Auditor rubric' "$r/AGENTS.md" 2>/dev/null;}
T="$(mktemp -d "${TMPDIR:-/tmp}/auditor-setup.XXXXXX")";trap 'rm -rf "$T"' EXIT;O="$T/out"
R="$T/root";mkdir -p "$R";bash "$S" "$R">"$O";rules="$(find "$R/.spaces/auditor/doctrine/test/workflows/audit/rules" -type f|wc -l|tr -d ' ')";eq "all bundled rules" 12 "$rules";ok test -f "$R/.spaces/auditor/templates/reports.md";no "seed does not invent GUIDE" "$R/.spaces/auditor/doctrine/test/workflows/audit/GUIDE.md";no "seed does not invent metrics" "$R/.spaces/auditor/doctrine/test/workflows/audit/metrics.sh";ok forbidden_clear "$R"
printf '\nCUSTOM\n'>>"$R/.spaces/auditor/templates/reports.md";sum="$(cksum "$R/.spaces/auditor/templates/reports.md")";bash "$S" "$R">"$O";eq "incumbent preserved" "$sum" "$(cksum "$R/.spaces/auditor/templates/reports.md")";ok grep -q writes=0 "$O"
L="$T/legacy";mkdir -p "$L/.records/templates/auditor";printf x>"$L/.records/templates/auditor/reports.md";if bash "$S" "$L">"$O" 2>&1;then f=$((f+1));else p=$((p+1));fi;ok grep -q '/auditor migrate' "$O";no "legacy not adopted" "$L/.spaces/auditor/templates/reports.md"
U="$T/unsafe";mkdir -p "$U/else";ln -s "$U/else" "$U/.spaces";if bash "$S" "$U">"$O" 2>&1;then f=$((f+1));else p=$((p+1));fi;no "unsafe no write" "$U/else/auditor"
X="$T/exchange";mkdir -p "$X/.spaces/auditor" "$X/else";H="$T/h";printf '%s\n' '#!/bin/sh' 'mv "$1/$2/auditor" "$1/held"' 'ln -s "$1/else" "$1/$2/auditor"'>"$H";chmod +x "$H";if AUDITOR_SETUP_TEST_AFTER_PREFLIGHT="$H" bash "$S" "$X">"$O" 2>&1;then f=$((f+1));else p=$((p+1));fi;ok grep -q 'symlinked destination parent' "$O";no "exchange no write" "$X/else/templates"
P="$T/partial";mkdir -p "$P";PH="$T/write-hook";printf '%s\n' '#!/bin/sh' '[ "$4" -eq 1 ] && exit 86' 'exit 0'>"$PH";chmod +x "$PH";if AUDITOR_SETUP_TEST_AFTER_WRITE="$PH" bash "$S" "$P">"$O" 2>&1;then f=$((f+1));else p=$((p+1));fi;ok grep -q 'created=.spaces/auditor/templates/reports.md' "$O";eq "partial leaves one safe asset" 1 "$(find "$P/.spaces/auditor" -type f|wc -l|tr -d ' ')";bash "$S" "$P">"$O";eq "partial rerun completes seed" 13 "$(find "$P/.spaces/auditor" -type f|wc -l|tr -d ' ')"
B="$T/bound";mkdir -p "$B";if AUDITOR_SETUP_TEST_ASSET=BOOTSTRAP.md bash "$S" "$B">/dev/null 2>&1;then f=$((f+1));else p=$((p+1));fi;if AUDITOR_SETUP_TEST_DEST_REL=.spaces/inspector/doctrine/reports.md bash "$S" "$B">/dev/null 2>&1;then f=$((f+1));else p=$((p+1));fi;no "boundary no writes" "$B/.spaces"
# Red-prove both retired-write sentinels: the absence check must fail when each is planted.
mkdir -p "$R/.records/reports";printf x>"$R/.records/reports/2000-01-01-setup-audit.md";if forbidden_clear "$R";then echo 'FAIL: audit-report sentinel invisible' >&2;f=$((f+1));else p=$((p+1));fi;rm "$R/.records/reports/2000-01-01-setup-audit.md"
printf 'Auditor rubric: .spaces/auditor/doctrine/test/workflows/audit/GUIDE.md\n'>"$R/AGENTS.md";if forbidden_clear "$R";then echo 'FAIL: host-pointer sentinel invisible' >&2;f=$((f+1));else p=$((p+1));fi
echo "auditor setup-test: $p passed, $f failed";[ "$f" -eq 0 ]
