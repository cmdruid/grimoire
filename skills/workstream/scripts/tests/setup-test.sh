#!/usr/bin/env bash
set -eu
D="$(cd "$(dirname "$0")"&&pwd)";S="$D/../workstream-setup.sh";H="$D/../hooks.sh";p=0;f=0
ok(){ if "$@";then p=$((p+1));else echo "FAIL: $*" >&2;f=$((f+1));fi;}
eq(){ if [ "$2" = "$3" ];then p=$((p+1));else echo "FAIL: $1" >&2;f=$((f+1));fi;}
no(){ if [ ! -e "$2" ]&&[ ! -L "$2" ];then p=$((p+1));else echo "FAIL: $1" >&2;f=$((f+1));fi;}
T="$(mktemp -d "${TMPDIR:-/tmp}/workstream-setup.XXXXXX")";trap 'rm -rf "$T"' EXIT;O="$T/out"
R="$T/root";mkdir -p "$R";bash "$S" --write-only "$R">"$O"
eq "four active assets" 4 "$(find "$R/.spaces/workstream" -type f|wc -l|tr -d ' ')"
for file in manifest.md debrief.md;do ok test -f "$R/.spaces/workstream/templates/$file";done
eq "feature hook empty" 0 "$(wc -c<"$R/.spaces/workstream/hooks/feature-completion.md"|tr -d ' ')"
eq "ship hook empty" 0 "$(wc -c<"$R/.spaces/workstream/hooks/after-eventful-ship.md"|tr -d ' ')"
bash "$H" parse --dir "$R/.spaces/workstream/hooks" --known feature-completion --known after-eventful-ship>"$O"
ok grep -q 'hook_feature_completion=empty' "$O";ok grep -q 'hook_after_eventful_ship=empty' "$O"
for x in workstream-handoff.md compaction-anchor.md coordinator.md debug.md design.md;do no "package-only $x" "$R/.spaces/workstream/templates/$x";done
no "no schemas" "$R/.spaces/workstream/schemas"
printf 'project hook\n'>"$R/.spaces/workstream/hooks/feature-completion.md";sum="$(cksum "$R/.spaces/workstream/hooks/feature-completion.md")";bash "$S" --write-only "$R">"$O"
eq "hook incumbent preserved" "$sum" "$(cksum "$R/.spaces/workstream/hooks/feature-completion.md")";ok grep -q writes=0 "$O"
L="$T/legacy";mkdir -p "$L/.records/templates/workstream";printf x>"$L/.records/templates/workstream/plans.md"
if bash "$S" --write-only "$L">"$O" 2>&1;then f=$((f+1));else p=$((p+1));fi;ok grep -q '/workstream migrate' "$O";no "legacy not adopted" "$L/.spaces/workstream/templates/manifest.md"
U="$T/unsafe";mkdir -p "$U/else";ln -s "$U/else" "$U/.spaces"
if bash "$S" --write-only "$U">"$O" 2>&1;then f=$((f+1));else p=$((p+1));fi;no "unsafe no write" "$U/else/workstream"
X="$T/exchange";mkdir -p "$X/.spaces/workstream" "$X/else";PH="$T/ph";printf '%s\n' '#!/bin/sh' 'mv "$1/$2/workstream" "$1/held"' 'ln -s "$1/else" "$1/$2/workstream"'>"$PH";chmod +x "$PH"
if WORKSTREAM_SETUP_TEST_AFTER_PREFLIGHT="$PH" bash "$S" --write-only "$X">"$O" 2>&1;then f=$((f+1));else p=$((p+1));fi;ok grep -q 'symlinked destination parent' "$O";no "exchange no write" "$X/else/templates"
P="$T/partial";mkdir -p "$P";WH="$T/write-hook";printf '%s\n' '#!/bin/sh' '[ "$4" -eq 1 ] && exit 86' 'exit 0'>"$WH";chmod +x "$WH"
if WORKSTREAM_SETUP_TEST_AFTER_WRITE="$WH" bash "$S" --write-only "$P">"$O" 2>&1;then f=$((f+1));else p=$((p+1));fi;ok grep -q 'created=.spaces/workstream/templates/manifest.md' "$O";bash "$S" --write-only "$P">"$O";eq "partial rerun converges" 4 "$(find "$P/.spaces/workstream" -type f|wc -l|tr -d ' ')"
G="$T/git";mkdir -p "$G";git -C "$G" init -q;git -C "$G" config user.name Fixture;git -C "$G" config user.email fixture@example.invalid;printf '# Fixture\n'>"$G/README.md";git -C "$G" add README.md;git -C "$G" commit -qm init;bash "$S" "$G">"$O";eq "standalone commit exact paths" "$(printf '%s\n' .spaces/workstream/hooks/after-eventful-ship.md .spaces/workstream/hooks/feature-completion.md .spaces/workstream/templates/debrief.md .spaces/workstream/templates/manifest.md)" "$(git -C "$G" show --pretty='' --name-only HEAD|sed '/^$/d'|sort)";head="$(git -C "$G" rev-parse HEAD)";bash "$S" "$G">"$O";eq "standalone no-op makes no commit" "$head" "$(git -C "$G" rev-parse HEAD)"
B="$T/bound";mkdir -p "$B"
if WORKSTREAM_SETUP_TEST_ASSET=templates/coordinator.md bash "$S" --write-only "$B">/dev/null 2>&1;then f=$((f+1));else p=$((p+1));fi
if WORKSTREAM_SETUP_TEST_DEST_REL=.spaces/contractor/templates/manifest.md bash "$S" --write-only "$B">/dev/null 2>&1;then f=$((f+1));else p=$((p+1));fi
no "boundary no writes" "$B/.spaces"
echo "workstream setup-test: $p passed, $f failed";[ "$f" -eq 0 ]
