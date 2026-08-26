#!/usr/bin/env bash
# workstream-setup.sh [--write-only] <root> — deploy active templates and empty hook points.
set -euo pipefail
die(){ echo "workstream-setup.sh: $*" >&2;exit 2;};wo=no;case "${1:-}" in --write-only)wo=yes;shift;;esac;[ "$#" -eq 1 ]||die "usage: workstream-setup.sh [--write-only] <root>"
root="$1";[ -d "$root" ]||die "root is not a directory: $root";root="$(cd "$root"&&pwd -P)";base="$(cd "$(dirname "$0")/.."&&pwd -P)"
resolve(){ local k="$1" d="$2" f v="";for f in "$root/AGENTS.md" "$root/CLAUDE.md";do if [ -z "$v" ]&&[ -f "$f" ];then case "$k" in ws)v="$(sed -n -E 's/^agent-workspace:[[:space:]]*//p' "$f"|head -n1|sed 's/[[:space:]]*$//')";;rr)v="$(sed -n -E 's/^(agent-records|records-root):[[:space:]]*//p' "$f"|head -n1|sed 's/[[:space:]]*$//')";;esac;fi;done;printf '%s\n' "${v:-$d}";}
valid(){ [ -n "$1" ]&&[ "$1" != . ]||return 1;case "$1" in /*)return 1;;esac;case "/$1/" in */../*)return 1;;esac;}
check(){ local r="$1" c="$root" p o="$IFS" m=no;valid "$r"||die "unsafe relative path: $r";IFS=/;for p in $r;do [ -n "$p" ]||continue;c="$c/$p";[ "$m" = no ]||continue;[ ! -L "$c" ]||die "symlinked destination parent: $c";if [ -e "$c" ];then [ -d "$c" ]||die "destination parent is not a directory: $c";else m=yes;fi;done;IFS="$o";}
ensure(){ local r="$1" c="$root" p o="$IFS";IFS=/;for p in $r;do [ -n "$p" ]||continue;c="$c/$p";[ ! -L "$c" ]||die "symlinked destination parent: $c";if [ -e "$c" ];then [ -d "$c" ]||die "destination parent is not a directory: $c";else mkdir "$c";fi;done;IFS="$o";}
schema_free(){ ! awk 'NR==1&&$0=="---"{f=1;next}f&&$0=="---"{exit}f&&/^schema:/{x=1}END{exit !x}' "$1";}
ws="$(resolve ws .spaces)";rr="$(resolve rr .records)";valid "$ws"||die "unsafe workspace path: $ws";valid "$rr"||die "unsafe records path: $rr";assets="templates/manifest.md
templates/debrief.md
hooks/feature-completion.md
hooks/after-eventful-ship.md";[ -z "${WORKSTREAM_SETUP_TEST_ASSET:-}" ]||assets="$assets
$WORKSTREAM_SETUP_TEST_ASSET";made=();n=0
while IFS= read -r rel;do [ -n "$rel" ]||continue;case "$rel" in templates/manifest.md|templates/debrief.md|hooks/feature-completion.md|hooks/after-eventful-ship.md);;*)die "asset is not declared for project deployment: $rel";;esac;case "$rel" in templates/*)src="$base/$rel";[ -f "$src" ]&&[ ! -L "$src" ]||die "bad bundled template: $src";schema_free "$src"||die "bundled project template selects a schema: $src";;esac;dstrel="$ws/workstream/$rel";[ -z "${WORKSTREAM_SETUP_TEST_DEST_REL:-}" ]||dstrel="$WORKSTREAM_SETUP_TEST_DEST_REL";case "$dstrel" in "$ws/workstream/$rel");;*)die "destination escapes workstream ownership: $dstrel";;esac;check "${dstrel%/*}";dst="$root/$dstrel";[ ! -L "$dst" ]||die "destination is a symlink: $dst";[ ! -e "$dst" ]||[ -f "$dst" ]||die "destination is not a regular file: $dst";if [ -e "$dst" ];then case "$rel" in templates/*)schema_free "$dst"||die "project template selects a schema: $dst";;esac;else case "$rel" in templates/manifest.md)oldname=plans.md;;templates/debrief.md)oldname=reports.md;;*)oldname="";;esac;if [ -n "$oldname" ];then for old in "$root/$rr/templates/workstream/$oldname" "$root/$rr/templates/$oldname";do [ ! -L "$old" ]&&[ ! -e "$old" ]||die "legacy template found; run /workstream migrate $old";done;fi;fi;done <<EOF
$assets
EOF
if [ "$wo" = no ];then gr="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null||true)";[ -n "$gr" ]&&[ "$(cd "$gr"&&pwd -P)" = "$root" ]||die "standalone setup root must be a Git top level";fi;[ -z "${WORKSTREAM_SETUP_TEST_AFTER_PREFLIGHT:-}" ]||"$WORKSTREAM_SETUP_TEST_AFTER_PREFLIGHT" "$root" "$ws"
while IFS= read -r rel;do [ -n "$rel" ]||continue;dstrel="$ws/workstream/$rel";dst="$root/$dstrel";if [ -f "$dst" ]&&[ ! -L "$dst" ];then printf 'preserved=%s\n' "$dstrel";continue;fi;ensure "${dstrel%/*}";check "${dstrel%/*}";[ ! -L "$dst" ]&&[ ! -e "$dst" ]||die "destination changed after preflight: $dst";case "$rel" in templates/*)cp "$base/$rel" "$dst";;hooks/*): > "$dst";;esac;made+=("$dstrel");n=$((n+1));printf 'created=%s\n' "$dstrel";[ -z "${WORKSTREAM_SETUP_TEST_AFTER_WRITE:-}" ]||"$WORKSTREAM_SETUP_TEST_AFTER_WRITE" "$root" "$ws" "$dstrel" "$n";done <<EOF
$assets
EOF
printf 'writes=%s\n' "${#made[@]}";if [ "${#made[@]}" -gt 0 ];then if [ "$wo" = yes ];then printf 'commit=caller\n';else git -C "$root" add -- "${made[@]}";git -C "$root" commit -m "Workstream: setup" -- "${made[@]}";printf 'committed_count=%s\n' "${#made[@]}";fi;fi
