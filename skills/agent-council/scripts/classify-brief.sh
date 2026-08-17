#!/usr/bin/env bash
# classify-brief.sh <target>
# Facts only. Never a verdict. Never recommends convening.
# Prints:
#   target=<absolute or empty>
#   workdir=<absolute cwd for seats, or empty>
#   readable=true|false
#   kind=skill|spec|other|unreadable
#   brief=skill|spec|generic|
#   reason=<short token>
set -u

target=""
workdir=""
readable="false"
kind="unreadable"
brief=""
reason="unreadable"

emit() {
  printf 'target=%s\n' "$target"
  printf 'workdir=%s\n' "$workdir"
  printf 'readable=%s\n' "$readable"
  printf 'kind=%s\n' "$kind"
  printf 'brief=%s\n' "$brief"
  printf 'reason=%s\n' "$reason"
}

abs_dir() {
  (cd "$1" && pwd)
}

abs_file() {
  local dir base
  dir="$(cd "$(dirname "$1")" && pwd)"
  base="$(basename "$1")"
  printf '%s/%s\n' "$dir" "$base"
}

extract_fm() {
  awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++; if(n==1) next; if(n==2) exit} n==1{print}' "$1"
}

doctype_of() {
  printf '%s\n' "$1" | sed -n 's/^doctype:[[:space:]]*//p' | head -n 1 \
    | sed 's/^["'\'']//; s/["'\'']$//; s/[[:space:]]*$//'
}

has_founding_tag() {
  printf '%s\n' "$1" | grep -qE '^tags:[[:space:]]*\[([^]]*[[:space:]])?founding([,[:space:]\]]|$)' \
    || printf '%s\n' "$1" | grep -qE '^[[:space:]]*-[[:space:]]*founding[[:space:]]*$'
}

raw="${1:-}"
if [ -z "$raw" ] || [ ! -e "$raw" ]; then
  emit
  exit 0
fi

if [ -d "$raw" ]; then
  target="$(abs_dir "$raw")"
  if [ -f "$target/SKILL.md" ]; then
    readable="true"
    kind="skill"
    brief="skill"
    workdir="$target"
    reason="skill-dir"
    emit
    exit 0
  fi
  readable="true"
  kind="other"
  brief="generic"
  workdir="$target"
  reason="fallback"
  emit
  exit 0
fi

if [ ! -f "$raw" ] && [ ! -r "$raw" ]; then
  emit
  exit 0
fi

abs="$(abs_file "$raw")"
parent="$(cd "$(dirname "$abs")" && pwd)"

if [ "$(basename "$abs")" = "SKILL.md" ]; then
  target="$parent"
  workdir="$parent"
  readable="true"
  kind="skill"
  brief="skill"
  reason="skill-file"
  emit
  exit 0
fi

fm="$(extract_fm "$abs")"
dt="$(doctype_of "$fm")"
if [ "$dt" = "design" ] || [ "$dt" = "spec" ] || has_founding_tag "$fm"; then
  target="$abs"
  workdir="$parent"
  readable="true"
  kind="spec"
  brief="spec"
  if [ "$dt" = "design" ] || [ "$dt" = "spec" ]; then
    reason="doctype"
  else
    reason="founding-tag"
  fi
  emit
  exit 0
fi

target="$abs"
workdir="$parent"
readable="true"
kind="other"
brief="generic"
reason="fallback"
emit
exit 0
