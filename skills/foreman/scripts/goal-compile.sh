#!/usr/bin/env bash
# Compile an active operation closure and publish an immutable goal record.
set -euo pipefail
usage() {
  cat >&2 <<'EOF'
usage:
  goal-compile.sh render --root <root> --workspace <relative> --operation <owner/stem> --objective <one-line> --output <file>
  goal-compile.sh publish --root <root> --workspace <relative> --records-root <relative> --input <file>
EOF
  exit 2
}
die() { echo "status=refused"; echo "reason=$1"; exit 1; }
sha256_file() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1"|awk '{print $1}'; else sha256sum "$1"|awk '{print $1}'; fi; }
valid_rel() { [ -n "$1" ] && [ "$1" != . ] || return 1; case "$1" in /*|*//*|*/../*|../*|*/..) return 1;; esac; }
valid_records_rel() { [ -n "$1" ] || return 1; case "$1" in /*|*//*|*/../*|../*|*/..) return 1;; esac; }
ensure_safe_dir() {
  local rel="$1" cur="$root" part oldifs="$IFS"
  [ "$rel" = . ] && return 0
  valid_records_rel "$rel" || die unsafe-records-root
  IFS=/
  for part in $rel; do
    [ -n "$part" ] || continue; cur="$cur/$part"
    [ ! -L "$cur" ] || { IFS="$oldifs"; die symlink-records-root; }
    if [ -e "$cur" ]; then [ -d "$cur" ] || { IFS="$oldifs"; die non-directory-records-root; }; else mkdir "$cur"; fi
  done
  IFS="$oldifs"
}
slugify() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-\{1,\}//' -e 's/-\{1,\}$//'; }
fm_get() { awk -v key="$2" 'NR==1&&$0=="---"{fm=1;next} fm&&$0=="---"{exit} fm&&index($0,key ":")==1{v=substr($0,length(key)+2);sub(/^[ \t]*/,"",v);print v;exit}' "$1"; }
section_body() {
  awk -v h="## $2" '$0==h{emit=1;next} emit&&/^## /{exit} emit{print}' "$1" |
    awk 'NF{for(i=1;i<=blanks;i++)print "";blanks=0;print;next}{blanks++}'
}

mode="${1:-}"; [ -n "$mode" ] || usage; shift
root=""; workspace=""; records_root=""; operation=""; objective=""; output=""; input=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || usage; root="$2"; shift 2;;
    --workspace) [ "$#" -ge 2 ] || usage; workspace="$2"; shift 2;;
    --records-root) [ "$#" -ge 2 ] || usage; records_root="$2"; shift 2;;
    --operation) [ "$#" -ge 2 ] || usage; operation="$2"; shift 2;;
    --objective) [ "$#" -ge 2 ] || usage; objective="$2"; shift 2;;
    --output) [ "$#" -ge 2 ] || usage; output="$2"; shift 2;;
    --input) [ "$#" -ge 2 ] || usage; input="$2"; shift 2;;
    *) usage;;
  esac
done
[ -n "$root" ] && [ -n "$workspace" ] || usage; [ -d "$root" ] || usage
root="$(CDPATH='' cd -P "$root" && pwd)"; valid_rel "$workspace" || usage
script_dir="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; checker="$script_dir/operation-check.sh"; template="$script_dir/../templates/goal.md"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/foreman-goal.XXXXXX")"; trap 'rm -rf "$tmp"' EXIT HUP INT TERM

if [ "$mode" = render ]; then
  [ -n "$operation" ] && [ -n "$objective" ] && [ -n "$output" ] || usage
  case "$objective" in *$'\n'*|*$'\r'*) die multiline-objective;; esac
  [ ! -e "$output" ] && [ ! -L "$output" ] || die output-exists
  sources="$tmp/sources"; source_material="$tmp/source-material"; runbook="$tmp/runbook"; verify="$tmp/verify"; recovery="$tmp/recovery"; seen="$tmp/seen"
  : >"$sources"; : >"$source_material"; : >"$runbook"; : >"$verify"; : >"$recovery"; : >"$seen"
  walk() {
    local identity="$1" stack="$2" facts path shape digest ref source_digest
    facts="$tmp/facts.$(printf '%s' "$1" | tr '/' '_')"
    case "$stack" in *"|$identity|"*) die cyclic-closure;; esac
    "$checker" --root "$root" --workspace "$workspace" --operation "$identity" >"$facts" || die invalid-closure
    [ "$(sed -n 's/^goal_eligible=//p' "$facts")" = true ] || die ineligible-operation
    path="$(sed -n 's/^path=//p' "$facts")"; shape="$(sed -n 's/^shape=//p' "$facts")"; digest="$(sed -n 's/^digest=//p' "$facts")"
    if ! grep -qxF "$identity" "$seen"; then
      echo "$identity" >>"$seen"; printf -- '- `%s` — `%s` — `%s`\n' "$identity" "$digest" "${path#"$root"/}" >>"$sources"
      printf 'operation=%s\ndigest=%s\n' "$identity" "$digest" >>"$source_material"
      source_digest="$(fm_get "$path" source-digest)"; [ -z "$source_digest" ] || printf 'import=%s\n' "$source_digest" >>"$source_material"
    fi
    if [ "$shape" = procedure ]; then
      printf '\n### `%s`\n\nSource: `%s`\n\n' "$identity" "${path#"$root"/}" >>"$runbook"
      section_body "$path" Preconditions >>"$runbook"; printf '\n\n' >>"$runbook"
      section_body "$path" Procedure >>"$runbook"; printf '\n' >>"$runbook"
      printf '\n### `%s`\n\n' "$identity" >>"$verify"; section_body "$path" Verification >>"$verify"; printf '\n' >>"$verify"
      printf '\n### `%s`\n\n' "$identity" >>"$recovery"; section_body "$path" Recovery >>"$recovery"; printf '\n' >>"$recovery"
    else
      while IFS= read -r ref; do [ -n "$ref" ] && walk "$ref" "$stack|$identity|"; done <<EOF
$(section_body "$path" Steps | sed -n -E 's/^[0-9]+\. `([^`]*)`.*/\1/p')
EOF
    fi
  }
  walk "$operation" '|'
  source_digest="sha256:$(sha256_file "$source_material")"; title="# Goal: $objective"; resume="/foreman goal resume goals/$(date +%Y-%m-%d)-$(slugify "$objective").md"
  rendered_body="$tmp/body"
  while IFS= read -r line; do
    case "$line" in
      '{{TITLE}}') printf '%s\n' "$title";;
      '{{OBJECTIVE}}') printf '%s\n' "$objective";;
      '{{SOURCES}}') cat "$sources";;
      'Source digest: `{{SOURCE_DIGEST}}`') printf 'Source digest: `%s`\n' "$source_digest";;
      '{{RUNBOOK}}') cat "$runbook";;
      '{{VERIFICATION}}') cat "$verify";;
      '{{RECOVERY}}') cat "$recovery";;
      'Run `{{RESUME}}` from the state owner'"'"'s current context.') printf 'Run `%s` from the state owner'"'"'s current context.\n' "$resume";;
      *) printf '%s\n' "$line";;
    esac
  done <"$template" >"$rendered_body"
  {
    printf '%s\n' '---' 'doctype: goals' 'status: draft' 'schema: foreman/goal@1' 'tags: [foreman, goal]' '---' ''
    cat "$rendered_body"
  } >"$output"
  echo "status=rendered"; echo "record_path=goals/$(date +%Y-%m-%d)-$(slugify "$objective").md"; echo "source_digest=$source_digest"; echo "operations=$(wc -l <"$seen" | tr -d ' ')"
  exit 0
fi

[ "$mode" = publish ] || usage
[ -n "$records_root" ] && [ -n "$input" ] || usage; valid_records_rel "$records_root" || usage
[ -f "$input" ] && [ ! -L "$input" ] || die bad-input
[ "$(fm_get "$input" doctype)" = goals ] && [ "$(fm_get "$input" status)" = draft ] && [ "$(fm_get "$input" schema)" = foreman/goal@1 ] || die bad-goal-record
title="$(awk '/^# Goal: /{print substr($0,9);exit}' "$input")"; [ -n "$title" ] || die missing-goal-title
rel="goals/$(date +%Y-%m-%d)-$(slugify "$title").md"; dest="$root/$records_root/$rel"
[ ! -e "$dest" ] && [ ! -L "$dest" ] || die goal-exists
body="$tmp/body"; awk 'NR==1&&$0=="---"{fm=1;next} fm&&$0=="---"{fm=0;next} !fm{if(!started&&$0=="")next;started=1;print}' "$input" >"$body"
engine="$root/$workspace/journal/scripts/records.sh"
ensure_safe_dir "$records_root"
if [ -x "$engine" ]; then
  path="$("$engine" --root "$root" --records-root "$records_root" new goals --schema foreman/goal@1 --template "$body" --title "$title" --tag foreman --tag goal)"
  [ "$path" = "$dest" ] || die staged-path-mismatch
  "$engine" --root "$root" --records-root "$records_root" touch "$rel" --status published >/dev/null
  publish_mode='records'
else
  dir="${dest%/*}"; ensure_safe_dir "$records_root/goals"
  candidate="$tmp/published"; awk 'NR==1&&$0=="---"{fm=1} fm&&/^status:/{print "status: published";next}{print}' "$input" >"$candidate"
  replacement="$(mktemp "$dir/.foreman-goal.XXXXXX")"; cp "$candidate" "$replacement"; chmod 644 "$replacement"; mv "$replacement" "$dest"
  publish_mode='file'
fi
echo "status=published"; echo "path=$rel"; echo "mode=$publish_mode"
