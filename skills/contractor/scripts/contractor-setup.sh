#!/usr/bin/env bash
# contractor-setup.sh [--write-only] <root> — deploy active Contractor templates.
set -euo pipefail
die(){ echo "contractor-setup.sh: $*" >&2;exit 2;};wo=no;case "${1:-}" in --write-only)wo=yes;shift;;esac;[ "$#" -eq 1 ]||die "usage: contractor-setup.sh [--write-only] <root>"
root="$1";[ -d "$root" ]||die "root is not a directory: $root";root="$(cd "$root"&&pwd -P)";base="$(cd "$(dirname "$0")/.."&&pwd -P)"
valid(){ [ -n "$1" ]&&[ "$1" != . ]||return 1;case "$1" in /*)return 1;;esac;case "/$1/" in */../*)return 1;;esac;}
check(){ local r="$1" c="$root" p o="$IFS" m=no;valid "$r"||die "unsafe relative path: $r";IFS=/;for p in $r;do [ -n "$p" ]||continue;c="$c/$p";[ "$m" = no ]||continue;[ ! -L "$c" ]||die "symlinked destination parent: $c";if [ -e "$c" ];then [ -d "$c" ]||die "destination parent is not a directory: $c";else m=yes;fi;done;IFS="$o";}
ensure(){ local r="$1" c="$root" p o="$IFS";IFS=/;for p in $r;do [ -n "$p" ]||continue;c="$c/$p";[ ! -L "$c" ]||die "symlinked destination parent: $c";if [ -e "$c" ];then [ -d "$c" ]||die "destination parent is not a directory: $c";else mkdir "$c";fi;done;IFS="$o";}
schema_free(){ ! awk 'NR==1&&$0=="---"{f=1;next}f&&$0=="---"{exit}f&&/^schema:/{x=1}END{exit !x}' "$1";}
skilldata=.agents/skilldata;rr=.records;files="plan.md
roadmap.md";[ -z "${CONTRACTOR_SETUP_TEST_ASSET:-}" ]||files="$files
$CONTRACTOR_SETUP_TEST_ASSET";made=();n=0
while IFS= read -r f;do [ -n "$f" ]||continue;case "$f" in plan.md|roadmap.md);;*)die "asset is not declared for project deployment: $f";;esac;src="$base/templates/$f";[ -f "$src" ]&&[ ! -L "$src" ]||die "bad bundled template: $src";schema_free "$src"||die "bundled project template selects a schema: $src";rel="$skilldata/contractor/templates/$f";[ -z "${CONTRACTOR_SETUP_TEST_DEST_REL:-}" ]||rel="$CONTRACTOR_SETUP_TEST_DEST_REL";case "$rel" in "$skilldata/contractor/templates/$f");;*)die "destination escapes contractor ownership: $rel";;esac;check "${rel%/*}";dst="$root/$rel";[ ! -L "$dst" ]||die "destination is a symlink: $dst";[ ! -e "$dst" ]||[ -f "$dst" ]||die "destination is not a regular file: $dst";if [ -e "$dst" ];then schema_free "$dst"||die "project template selects a schema: $dst";else for old in "$root/$rr/templates/contractor/$f" "$root/$rr/templates/$f";do [ ! -L "$old" ]&&[ ! -e "$old" ]||die "legacy template found; run /contractor migrate $old";done;fi;done <<EOF
$files
EOF
if [ "$wo" = no ];then gr="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null||true)";[ -n "$gr" ]&&[ "$(cd "$gr"&&pwd -P)" = "$root" ]||die "standalone setup root must be a Git top level";fi;[ -z "${CONTRACTOR_SETUP_TEST_AFTER_PREFLIGHT:-}" ]||"$CONTRACTOR_SETUP_TEST_AFTER_PREFLIGHT" "$root" "$skilldata"
while IFS= read -r f;do [ -n "$f" ]||continue;src="$base/templates/$f";rel="$skilldata/contractor/templates/$f";dst="$root/$rel";if [ -f "$dst" ]&&[ ! -L "$dst" ];then printf 'preserved=%s\n' "$rel";continue;fi;ensure "${rel%/*}";check "${rel%/*}";[ ! -L "$dst" ]&&[ ! -e "$dst" ]||die "destination changed after preflight: $dst";cp "$src" "$dst";made+=("$rel");n=$((n+1));printf 'created=%s\n' "$rel";[ -z "${CONTRACTOR_SETUP_TEST_AFTER_WRITE:-}" ]||"$CONTRACTOR_SETUP_TEST_AFTER_WRITE" "$root" "$skilldata" "$rel" "$n";done <<EOF
$files
EOF
printf 'writes=%s\n' "${#made[@]}";if [ "${#made[@]}" -gt 0 ];then if [ "$wo" = yes ];then printf 'commit=caller\n';else git -C "$root" add -- "${made[@]}";git -C "$root" commit -m "Contractor: setup" -- "${made[@]}";printf 'committed_count=%s\n' "${#made[@]}";fi;fi
