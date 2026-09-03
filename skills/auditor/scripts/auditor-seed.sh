#!/usr/bin/env bash
# auditor-seed.sh <root> — write-only seed for the interactive Auditor setup.
# The setup verb authors GUIDE.md and metrics.sh, then owns commit custody.
set -euo pipefail
die(){ echo "auditor-seed.sh: $*" >&2;exit 2;}
[ "$#" -eq 1 ]||die "usage: auditor-seed.sh <root>"
root="$1";[ -d "$root" ]||die "root is not a directory: $root";root="$(cd "$root"&&pwd -P)";base="$(cd "$(dirname "$0")/.."&&pwd -P)"
[ -z "${AUDITOR_SETUP_TEST_INVOKED_SENTINEL:-}" ] || {
  : > "$AUDITOR_SETUP_TEST_INVOKED_SENTINEL"
  die "instrumented Auditor setup invocation"
}
valid(){ [ -n "$1" ]&&[ "$1" != . ]||return 1;case "$1" in /*)return 1;;esac;case "/$1/" in */../*)return 1;;esac;}
check(){ local r="$1" c="$root" p o="$IFS" m=no;valid "$r"||die "unsafe relative path: $r";IFS=/;for p in $r;do [ -n "$p" ]||continue;c="$c/$p";[ "$m" = no ]||continue;[ ! -L "$c" ]||die "symlinked destination parent: $c";if [ -e "$c" ];then [ -d "$c" ]||die "destination parent is not a directory: $c";else m=yes;fi;done;IFS="$o";}
ensure(){ local r="$1" c="$root" p o="$IFS";IFS=/;for p in $r;do [ -n "$p" ]||continue;c="$c/$p";[ ! -L "$c" ]||die "symlinked destination parent: $c";if [ -e "$c" ];then [ -d "$c" ]||die "destination parent is not a directory: $c";else mkdir "$c";fi;done;IFS="$o";}
schema_free(){ ! awk 'NR==1&&$0=="---"{f=1;next}f&&$0=="---"{exit}f&&/^schema:/{x=1}END{exit !x}' "$1";}
skilldata=.agents/skilldata;rr=.records
assets="templates/reports.md";while IFS= read -r src;do assets="$assets
rules/$(basename "$src")";done < <(find "$base/rules" -maxdepth 1 -type f -name '*.md'|sort)
[ -z "${AUDITOR_SETUP_TEST_ASSET:-}" ]||assets="$assets
$AUDITOR_SETUP_TEST_ASSET";n=0
dest_rel(){ case "$1" in templates/reports.md)printf '%s\n' "$skilldata/auditor/templates/reports.md";;rules/*)printf '%s\n' "$skilldata/auditor/doctrine/test/workflows/audit/$1";;esac;}
while IFS= read -r rel;do [ -n "$rel" ]||continue;case "$rel" in templates/reports.md|rules/*.md);;*)die "asset is not declared for project deployment: $rel";;esac;src="$base/$rel";[ -f "$src" ]&&[ ! -L "$src" ]||die "bad bundled asset: $src";case "$rel" in templates/*)schema_free "$src"||die "bundled project template selects a schema: $src";;esac;dstrel="$(dest_rel "$rel")";[ -z "${AUDITOR_SETUP_TEST_DEST_REL:-}" ]||dstrel="$AUDITOR_SETUP_TEST_DEST_REL";case "$dstrel" in "$skilldata/auditor/templates/reports.md"|"$skilldata/auditor/doctrine/test/workflows/audit/rules/"*.md);;*)die "destination escapes auditor ownership: $dstrel";;esac;check "${dstrel%/*}";dst="$root/$dstrel";[ ! -L "$dst" ]||die "destination is a symlink: $dst";[ ! -e "$dst" ]||[ -f "$dst" ]||die "destination is not a regular file: $dst";if [ -e "$dst" ];then case "$rel" in templates/*)schema_free "$dst"||die "project template selects a schema: $dst";;esac;fi;done <<EOF
$assets
EOF
if [ ! -e "$root/$skilldata/auditor/templates/reports.md" ];then for old in "$root/$rr/templates/auditor/reports.md" "$root/$rr/templates/reports.md";do [ ! -L "$old" ]&&[ ! -e "$old" ]||die "legacy template found; run /auditor migrate $old";done;fi
if [ ! -e "$root/$skilldata/auditor/doctrine/test/workflows/audit/GUIDE.md" ];then for old in "$root/.handbook/test/workflows/audit" "$root/$rr/doctrine/test/workflows/audit" "$root/$rr/doctrine/audit";do [ ! -L "$old" ]&&[ ! -e "$old" ]||die "legacy rubric found; run /auditor migrate $old";done;fi
[ -z "${AUDITOR_SETUP_TEST_AFTER_PREFLIGHT:-}" ]||"$AUDITOR_SETUP_TEST_AFTER_PREFLIGHT" "$root" "$skilldata"
while IFS= read -r rel;do [ -n "$rel" ]||continue;src="$base/$rel";dstrel="$(dest_rel "$rel")";dst="$root/$dstrel";if [ -f "$dst" ]&&[ ! -L "$dst" ];then printf 'preserved=%s\n' "$dstrel";continue;fi;ensure "${dstrel%/*}";check "${dstrel%/*}";[ ! -L "$dst" ]&&[ ! -e "$dst" ]||die "destination changed after preflight: $dst";cp "$src" "$dst";n=$((n+1));printf 'created=%s\n' "$dstrel";[ -z "${AUDITOR_SETUP_TEST_AFTER_WRITE:-}" ]||"$AUDITOR_SETUP_TEST_AFTER_WRITE" "$root" "$skilldata" "$dstrel" "$n";done <<EOF
$assets
EOF
printf 'writes=%s\n' "$n"
