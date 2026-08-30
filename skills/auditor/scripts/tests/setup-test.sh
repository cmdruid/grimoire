#!/usr/bin/env bash
set -eu
D="$(cd "$(dirname "$0")"&&pwd)";S="$D/../auditor-seed.sh";p=0;f=0
ok(){ if "$@";then p=$((p+1));else echo "FAIL: $*" >&2;f=$((f+1));fi;}
eq(){ if [ "$2" = "$3" ];then p=$((p+1));else echo "FAIL: $1 — want $2 got $3" >&2;f=$((f+1));fi;}
no(){ if [ ! -e "$2" ]&&[ ! -L "$2" ];then p=$((p+1));else echo "FAIL: $1" >&2;f=$((f+1));fi;}
forbidden_clear(){ local r="$1";[ ! -d "$r/.records/reports" ]||[ "$(find "$r/.records/reports" -type f|wc -l|tr -d ' ')" -eq 0 ]||return 1;! grep -q 'Auditor rubric' "$r/AGENTS.md" 2>/dev/null;}
T="$(mktemp -d "${TMPDIR:-/tmp}/auditor-setup.XXXXXX")";trap 'rm -rf "$T"' EXIT;O="$T/out"
R="$T/root";mkdir -p "$R";bash "$S" "$R">"$O";rules="$(find "$R/.spaces/auditor/doctrine/test/workflows/audit/rules" -type f|wc -l|tr -d ' ')";eq "all bundled rules" 13 "$rules";ok test -f "$R/.spaces/auditor/templates/reports.md";no "seed does not invent GUIDE" "$R/.spaces/auditor/doctrine/test/workflows/audit/GUIDE.md";no "seed does not invent metrics" "$R/.spaces/auditor/doctrine/test/workflows/audit/metrics.sh";ok forbidden_clear "$R"
printf '\nCUSTOM\n'>>"$R/.spaces/auditor/templates/reports.md";sum="$(cksum "$R/.spaces/auditor/templates/reports.md")";bash "$S" "$R">"$O";eq "incumbent preserved" "$sum" "$(cksum "$R/.spaces/auditor/templates/reports.md")";ok grep -q writes=0 "$O"
L="$T/legacy";mkdir -p "$L/.records/templates/auditor";printf x>"$L/.records/templates/auditor/reports.md";if bash "$S" "$L">"$O" 2>&1;then f=$((f+1));else p=$((p+1));fi;ok grep -q '/auditor migrate' "$O";no "legacy not adopted" "$L/.spaces/auditor/templates/reports.md"
U="$T/unsafe";mkdir -p "$U/else";ln -s "$U/else" "$U/.spaces";if bash "$S" "$U">"$O" 2>&1;then f=$((f+1));else p=$((p+1));fi;no "unsafe no write" "$U/else/auditor"
X="$T/exchange";mkdir -p "$X/.spaces/auditor" "$X/else";H="$T/h";printf '%s\n' '#!/bin/sh' 'mv "$1/$2/auditor" "$1/held"' 'ln -s "$1/else" "$1/$2/auditor"'>"$H";chmod +x "$H";if AUDITOR_SETUP_TEST_AFTER_PREFLIGHT="$H" bash "$S" "$X">"$O" 2>&1;then f=$((f+1));else p=$((p+1));fi;ok grep -q 'symlinked destination parent' "$O";no "exchange no write" "$X/else/templates"
P="$T/partial";mkdir -p "$P";PH="$T/write-hook";printf '%s\n' '#!/bin/sh' '[ "$4" -eq 1 ] && exit 86' 'exit 0'>"$PH";chmod +x "$PH";if AUDITOR_SETUP_TEST_AFTER_WRITE="$PH" bash "$S" "$P">"$O" 2>&1;then f=$((f+1));else p=$((p+1));fi;ok grep -q 'created=.spaces/auditor/templates/reports.md' "$O";eq "partial leaves one safe asset" 1 "$(find "$P/.spaces/auditor" -type f|wc -l|tr -d ' ')";bash "$S" "$P">"$O";eq "partial rerun completes seed" 14 "$(find "$P/.spaces/auditor" -type f|wc -l|tr -d ' ')"

# A twelve-rule incumbent receives only the absent leaf. GUIDE and metrics stay host-owned, and
# the leaf remains inactive until the owner explicitly indexes it.
W="$T/twelve-rule";mkdir -p "$W";bash "$S" "$W">"$O"
WD="$W/.spaces/auditor/doctrine/test/workflows/audit"
if [ -f "$WD/rules/complexity.md" ];then rm "$WD/rules/complexity.md";fi
printf '%s\n' '# incumbent guide' '| Readability | `rules/readability.md` | `READ` |' >"$WD/GUIDE.md"
printf '%s\n' '#!/bin/sh' 'echo incumbent-metrics' >"$WD/metrics.sh"
printf '%s\n' 'CUSTOM READABILITY' >>"$WD/rules/readability.md"
guide_sum="$(cksum "$WD/GUIDE.md")";metrics_sum="$(cksum "$WD/metrics.sh")";rule_sum="$(cksum "$WD/rules/readability.md")"
bash "$S" "$W">"$O"
eq "brownfield seeds one absent leaf" 1 "$(sed -n 's/^writes=//p' "$O")"
ok test -f "$WD/rules/complexity.md"
eq "brownfield guide preserved" "$guide_sum" "$(cksum "$WD/GUIDE.md")"
eq "brownfield metrics preserved" "$metrics_sum" "$(cksum "$WD/metrics.sh")"
eq "brownfield customized rule preserved" "$rule_sum" "$(cksum "$WD/rules/readability.md")"
if grep -q 'rules/complexity.md' "$WD/GUIDE.md";then f=$((f+1));else p=$((p+1));fi

rubric_active(){ grep -qF '| Complexity | `rules/complexity.md` | `CPLX` |' "$1/GUIDE.md"; }
adopt_complexity(){
  local home="$1" decision="$2"
  [ "$decision" = approved ] || return 2
  printf '%s\n' '| Complexity | `rules/complexity.md` | `CPLX` |' >>"$home/GUIDE.md"
  printf '%s\n' '# calibrated complexity adapter' >>"$home/metrics.sh"
  printf '%s\n' '<calibrated analyzer recipe>' >>"$home/rules/complexity.md"
}
if adopt_complexity "$WD" pending;then f=$((f+1));else p=$((p+1));fi
eq "pending decision preserves guide" "$guide_sum" "$(cksum "$WD/GUIDE.md")"
eq "pending decision preserves metrics" "$metrics_sum" "$(cksum "$WD/metrics.sh")"
adopt_complexity "$WD" approved
ok rubric_active "$WD"
if [ "$guide_sum" != "$(cksum "$WD/GUIDE.md")" ];then p=$((p+1));else f=$((f+1));fi
if [ "$metrics_sum" != "$(cksum "$WD/metrics.sh")" ];then p=$((p+1));else f=$((f+1));fi
B="$T/bound";mkdir -p "$B";if AUDITOR_SETUP_TEST_ASSET=BOOTSTRAP.md bash "$S" "$B">/dev/null 2>&1;then f=$((f+1));else p=$((p+1));fi;if AUDITOR_SETUP_TEST_DEST_REL=.spaces/inspector/doctrine/reports.md bash "$S" "$B">/dev/null 2>&1;then f=$((f+1));else p=$((p+1));fi;no "boundary no writes" "$B/.spaces"
# Red-prove both retired-write sentinels: the absence check must fail when each is planted.
mkdir -p "$R/.records/reports";printf x>"$R/.records/reports/2000-01-01-setup-audit.md";if forbidden_clear "$R";then echo 'FAIL: audit-report sentinel invisible' >&2;f=$((f+1));else p=$((p+1));fi;rm "$R/.records/reports/2000-01-01-setup-audit.md"
printf 'Auditor rubric: .spaces/auditor/doctrine/test/workflows/audit/GUIDE.md\n'>"$R/AGENTS.md";if forbidden_clear "$R";then echo 'FAIL: host-pointer sentinel invisible' >&2;f=$((f+1));else p=$((p+1));fi
echo "auditor setup-test: $p passed, $f failed";[ "$f" -eq 0 ]
