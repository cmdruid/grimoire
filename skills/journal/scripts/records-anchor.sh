#!/usr/bin/env bash
# records-anchor.sh preview|apply --root <absolute-root> [--confirmed]
# Install one absent-only project pointer to the fixed records-layer guide.
set -euo pipefail

die(){ echo "records-anchor.sh: $*" >&2;exit 2;}
refuse(){ echo "reason=$1${2:+ detail=$2}" >&2;exit 2;}
usage(){ die 'usage: records-anchor.sh preview|apply --root <absolute-root> [--confirmed]';}

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
README_TEMPLATE="$SKILL/templates/records-readme-block.md"
README_STATUS="$SKILL/scripts/records-readme-status.sh"
PROVIDER_SOURCE="$SKILL/scripts/records.sh"
[ -f "$POINTER" ]&&[ ! -L "$POINTER" ]&&[ -f "$README_TEMPLATE" ]&&[ ! -L "$README_TEMPLATE" ]&&
  [ -x "$README_STATUS" ]&&[ -f "$PROVIDER_SOURCE" ]&&[ ! -L "$PROVIDER_SOURCE" ]||die 'package resources unavailable'
if [ "$(grep -cFx '## Project records' "$POINTER")" -ne 1 ] ||
  [ "$(grep -cF '.records/README.md' "$POINTER")" -ne 1 ] ||
  grep -qF '<!--' "$POINTER";then
  die 'invalid pointer template'
fi

layer="$root/.records";ledger="$layer/history.tsv";provider="$layer/records.sh"
readme="$layer/README.md";target="$root/AGENTS.md";intent="$root/.spaces/journal/setup.intent"

readme_fact(){ printf '%s\n' "$1"|sed -n "s/^$2=//p"|head -n1;}
validate_layer(){
  [ ! -e "$intent" ]&&[ ! -L "$intent" ]||refuse setup-required
  [ -d "$layer" ]&&[ ! -L "$layer" ]||refuse setup-required
  [ -f "$ledger" ]&&[ ! -L "$ledger" ]||refuse setup-required
  if ! { [ -f "$provider" ]&&[ ! -L "$provider" ]&&[ -x "$provider" ]&&
    cmp -s "$PROVIDER_SOURCE" "$provider"; };then
    refuse repair-required
  fi
  readme_facts="$($README_STATUS "$README_TEMPLATE" "$readme")"||refuse repair-required
  [ "$(readme_fact "$readme_facts" readme_status)" = current ]||refuse repair-required
}

classify_target(){
  [ ! -L "$target" ]||refuse invalid-target AGENTS.md
  if [ ! -e "$target" ];then target_state=absent;action=create;return;fi
  [ -f "$target" ]&&[ -r "$target" ]&&[ -w "$target" ]||refuse invalid-target AGENTS.md
  target_state=present
  if grep -qF '.records/README.md' "$target";then action=noop;return;fi
  if grep -qxF '## Project records' "$target";then refuse reserved-heading '## Project records';fi
  action=append
}

validate_layer
classify_target
initial_target_state="$target_state"
snapshot="$(mktemp "${TMPDIR:-/tmp}/journal-anchor-target.XXXXXX")"
candidate=""
cleanup(){ rm -f "$snapshot" ${candidate:+"$candidate"}; }
trap cleanup EXIT
if [ "$target_state" = present ];then cp "$target" "$snapshot";else : >"$snapshot";fi

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
if [ "$action" != noop ];then
  echo 'content-begin'
  cat "$POINTER"
  echo 'content-end'
fi
echo 'ready=yes'
[ "$mode" = apply ]||exit 0
[ "$action" != noop ]||exit 0

if [ -n "${JOURNAL_ANCHOR_TEST_AFTER_PREFLIGHT:-}" ];then
  [ -x "$JOURNAL_ANCHOR_TEST_AFTER_PREFLIGHT" ]||die 'test hook is not executable'
  "$JOURNAL_ANCHOR_TEST_AFTER_PREFLIGHT" "$root"
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
  mode_bits="$(stat -f '%Lp' "$target" 2>/dev/null||stat -c '%a' "$target")"
  chmod "$mode_bits" "$candidate"
else
  cp "$POINTER" "$candidate"
  chmod 644 "$candidate"
fi

validate_layer
verify_target_unchanged
[ -f "$candidate" ]&&[ ! -L "$candidate" ]||refuse unsafe-temporary AGENTS.md
mv "$candidate" "$target";candidate=""
echo 'wrote=AGENTS.md'
