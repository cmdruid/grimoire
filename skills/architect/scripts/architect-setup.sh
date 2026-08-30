#!/usr/bin/env bash
# architect-setup.sh [--write-only] <root> — deploy active Architect templates.
set -euo pipefail
die(){ echo "architect-setup.sh: $*" >&2; exit 2; }; usage(){ die "usage: architect-setup.sh [--write-only] <root>"; }
wo=no; case "${1:-}" in --write-only) wo=yes; shift;; esac; [ "$#" -eq 1 ] || usage
root="$1"; [ -d "$root" ] || die "root is not a directory: $root"; root="$(cd "$root" && pwd -P)"
base="$(cd "$(dirname "$0")/.." && pwd -P)"
valid(){ [ -n "$1" ]&&[ "$1" != . ]||return 1; case "$1" in /*)return 1;;esac; case "/$1/" in */../*)return 1;;esac; }
check(){ local rel="$1" cur="$root" p old="$IFS" miss=no; valid "$rel"||die "unsafe relative path: $rel"; IFS=/; for p in $rel; do [ -n "$p" ]||continue; cur="$cur/$p"; [ "$miss" = no ]||continue; [ ! -L "$cur" ]||die "symlinked destination parent: $cur"; if [ -e "$cur" ];then [ -d "$cur" ]||die "destination parent is not a directory: $cur";else miss=yes;fi; done; IFS="$old"; }
ensure(){ local rel="$1" cur="$root" p old="$IFS"; IFS=/; for p in $rel; do [ -n "$p" ]||continue; cur="$cur/$p"; [ ! -L "$cur" ]||die "symlinked destination parent: $cur"; if [ -e "$cur" ];then [ -d "$cur" ]||die "destination parent is not a directory: $cur";else mkdir "$cur";fi; done; IFS="$old"; }
schema_free(){ ! awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f&&/^schema:/{x=1} END{exit !x}' "$1"; }
ws=.spaces; rr=.records
files="adr.md
specs.md"; [ -z "${ARCHITECT_SETUP_TEST_ASSET:-}" ]||files="$files
$ARCHITECT_SETUP_TEST_ASSET"; made=(); n=0
while IFS= read -r f; do [ -n "$f" ]||continue; case "$f" in adr.md|specs.md);;*)die "asset is not declared for project deployment: $f";;esac; src="$base/templates/$f"; [ -f "$src" ]&&[ ! -L "$src" ]||die "bad bundled template: $src"; schema_free "$src"||die "bundled project template selects a schema: $src"; rel="$ws/architect/templates/$f"; [ -z "${ARCHITECT_SETUP_TEST_DEST_REL:-}" ]||rel="$ARCHITECT_SETUP_TEST_DEST_REL"; case "$rel" in "$ws/architect/templates/$f");;*)die "destination escapes architect ownership: $rel";;esac; check "${rel%/*}"; dst="$root/$rel"; [ ! -L "$dst" ]||die "destination is a symlink: $dst"; [ ! -e "$dst" ]||[ -f "$dst" ]||die "destination is not a regular file: $dst"; if [ -e "$dst" ];then schema_free "$dst"||die "project template selects a schema: $dst";else for old in "$root/$rr/templates/architect/$f" "$root/$rr/templates/$f";do [ ! -L "$old" ]&&[ ! -e "$old" ]||die "legacy template found; run /architect migrate $old";done;fi; done <<EOF
$files
EOF
if [ "$wo" = no ];then gr="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null||true)"; [ -n "$gr" ]&&[ "$(cd "$gr"&&pwd -P)" = "$root" ]||die "standalone setup root must be a Git top level";fi
[ -z "${ARCHITECT_SETUP_TEST_AFTER_PREFLIGHT:-}" ]||"$ARCHITECT_SETUP_TEST_AFTER_PREFLIGHT" "$root" "$ws"
while IFS= read -r f;do [ -n "$f" ]||continue; src="$base/templates/$f"; rel="$ws/architect/templates/$f"; dst="$root/$rel"; if [ -f "$dst" ]&&[ ! -L "$dst" ];then printf 'preserved=%s\n' "$rel";continue;fi; ensure "${rel%/*}";check "${rel%/*}";[ ! -L "$dst" ]&&[ ! -e "$dst" ]||die "destination changed after preflight: $dst";cp "$src" "$dst";made+=("$rel");n=$((n+1));printf 'created=%s\n' "$rel";[ -z "${ARCHITECT_SETUP_TEST_AFTER_WRITE:-}" ]||"$ARCHITECT_SETUP_TEST_AFTER_WRITE" "$root" "$ws" "$rel" "$n";done <<EOF
$files
EOF
printf 'writes=%s\n' "${#made[@]}";if [ "${#made[@]}" -gt 0 ];then if [ "$wo" = yes ];then printf 'commit=caller\n';else git -C "$root" add -- "${made[@]}";git -C "$root" commit -m "Architect: setup" -- "${made[@]}";printf 'committed_count=%s\n' "${#made[@]}";fi;fi
