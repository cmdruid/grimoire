#!/usr/bin/env bash
# trackers-anchor.sh preview|apply --root <absolute-root> [--confirmed]
# Install one absent-only project pointer to the fixed tracker-layer guide.
set -euo pipefail

die(){ echo "trackers-anchor.sh: $*" >&2;exit 2;}
refuse(){ echo "reason=$1${2:+ detail=$2}" >&2;exit 2;}
usage(){ die 'usage: trackers-anchor.sh preview|apply --root <absolute-root> [--confirmed]';}

mode="${1:-}";[ -n "$mode" ]||usage;shift
case "$mode" in preview|apply);;*)usage;;esac
root="";confirmed=no
while [ "$#" -gt 0 ];do
  case "$1" in
    --root)[ "$#" -ge 2 ]||usage;root="$2";shift 2;;
    --confirmed)confirmed=yes;shift;;
    *)usage;;
  esac
done
[ -n "$root" ]||usage
[ "$mode" = apply ]||[ "$confirmed" = no ]||usage
[ "$mode" = preview ]||[ "$confirmed" = yes ]||refuse confirmation-required
case "$root" in /*);;*)refuse root-not-absolute "$root";;esac
[ -d "$root" ]&&[ ! -L "$root" ]||refuse invalid-root "$root"
root="$(CDPATH='' cd -P "$root"&&pwd)"
git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null||true)"
[ -n "$git_root" ]||refuse git-required
git_root="$(CDPATH='' cd -P "$git_root"&&pwd)"
[ "$git_root" = "$root" ]||refuse root-not-git-top-level "$git_root"
[ -n "$(git -C "$root" branch --show-current)" ]||refuse detached-head

SKILL="$(CDPATH='' cd -P "$(dirname "$0")/.."&&pwd)"
POINTER="$SKILL/templates/agents-pointer.md"
README_TEMPLATE="$SKILL/templates/trackers-readme-block.md"
README_STATUS="$SKILL/scripts/tracker-readme-status.sh"
RUNTIME="$SKILL/scripts/tracker-runtime-check.sh"
PROVIDER_SOURCE="$SKILL/scripts/trackers.sh"
[ -f "$POINTER" ]&&[ ! -L "$POINTER" ]&&[ -f "$README_TEMPLATE" ]&&[ ! -L "$README_TEMPLATE" ]&&
  [ -x "$README_STATUS" ]&&[ -x "$RUNTIME" ]&&[ -f "$PROVIDER_SOURCE" ]&&[ ! -L "$PROVIDER_SOURCE" ]||die 'package resources unavailable'
if [ "$(grep -cFx '## Project trackers' "$POINTER")" -ne 1 ] ||
  [ "$(grep -cF '.trackers/README.md' "$POINTER")" -ne 1 ] ||
  grep -qF '<!--' "$POINTER";then
  die 'invalid pointer template'
fi

layer="$root/.trackers";readme="$layer/README.md";target="$root/AGENTS.md"
fact(){ printf '%s\n' "$1"|sed -n "s/^$2=//p"|head -n1;}
validate_layer(){
  runtime_facts="$($RUNTIME --root "$root")"
  provider="$(fact "$runtime_facts" provider)"
  if ! { [ "$provider" = "$layer/trackers.sh" ]&&[ -f "$provider" ]&&[ ! -L "$provider" ]&&
    [ -x "$provider" ]&&cmp -s "$PROVIDER_SOURCE" "$provider"; };then
    refuse repair-required
  fi
  readme_facts="$($README_STATUS "$README_TEMPLATE" "$readme")"||refuse repair-required
  [ "$(fact "$readme_facts" readme_status)" = current ]||refuse repair-required
}
classify_target(){
  [ ! -L "$target" ]||refuse invalid-target AGENTS.md
  if [ ! -e "$target" ];then target_state=absent;action=create;return;fi
  [ -f "$target" ]&&[ -r "$target" ]&&[ -w "$target" ]||refuse invalid-target AGENTS.md
  target_state=present
  if grep -qF '.trackers/README.md' "$target";then action=noop;return;fi
  if grep -qxF '## Project trackers' "$target";then refuse reserved-heading '## Project trackers';fi
  action=append
}

validate_layer
classify_target
initial_target_state="$target_state"
snapshot="$(mktemp "${TMPDIR:-/tmp}/backlog-anchor-target.XXXXXX")";candidate=""
cleanup(){ rm -f "$snapshot" ${candidate:+"$candidate"}; }
trap cleanup EXIT
if [ "$target_state" = present ];then cp "$target" "$snapshot";else :>"$snapshot";fi

verify_target_unchanged(){
  classify_target
  [ "$target_state" = "$initial_target_state" ]||refuse concurrent-project-edit AGENTS.md
  if [ "$initial_target_state" = present ];then
    cmp -s "$snapshot" "$target"||refuse concurrent-project-edit AGENTS.md
  else
    [ ! -e "$target" ]&&[ ! -L "$target" ]||refuse concurrent-project-edit AGENTS.md
  fi
}

printf 'action=%s\npath=AGENTS.md\n' "$action"
if [ "$action" != noop ];then echo 'content-begin';cat "$POINTER";echo 'content-end';fi
echo 'ready=yes'
[ "$mode" = apply ]||exit 0
[ "$action" != noop ]||exit 0

if [ -n "${BACKLOG_ANCHOR_TEST_AFTER_PREFLIGHT:-}" ];then
  [ -x "$BACKLOG_ANCHOR_TEST_AFTER_PREFLIGHT" ]||die 'test hook is not executable'
  "$BACKLOG_ANCHOR_TEST_AFTER_PREFLIGHT" "$root"
fi
validate_layer
verify_target_unchanged

candidate="$(mktemp "$root/.AGENTS.md.anchor.XXXXXX")"||refuse unsafe-temporary AGENTS.md
[ -f "$candidate" ]&&[ ! -L "$candidate" ]||refuse unsafe-temporary AGENTS.md
if [ "$initial_target_state" = present ];then
  cat "$snapshot">"$candidate"
  if [ -s "$snapshot" ];then
    last_byte="$(tail -c 1 "$snapshot"|od -An -tuC|tr -d '[:space:]')"
    if [ "$last_byte" = 10 ];then printf '\n';else printf '\n\n';fi >>"$candidate"
  fi
  cat "$POINTER">>"$candidate"
  mode_bits="$(stat -f '%Lp' "$target" 2>/dev/null||stat -c '%a' "$target")";chmod "$mode_bits" "$candidate"
else cp "$POINTER" "$candidate";chmod 644 "$candidate";fi

validate_layer
verify_target_unchanged
[ -f "$candidate" ]&&[ ! -L "$candidate" ]||refuse unsafe-temporary AGENTS.md
mv "$candidate" "$target";candidate=""
echo 'wrote=AGENTS.md'
