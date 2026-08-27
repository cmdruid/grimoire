#!/usr/bin/env bash
# Validate one operation and compute its recursive instruction digest.
set -u

usage() {
  echo "usage: operation-check.sh --root <root> --workspace <relative> --operation <owner/stem> [--candidate <owner/stem>=<file>]..." >&2
  exit 2
}

root=""; workspace=""; requested=""; candidate_specs=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || usage; root="$2"; shift 2 ;;
    --workspace) [ "$#" -ge 2 ] || usage; workspace="$2"; shift 2 ;;
    --operation) [ "$#" -ge 2 ] || usage; requested="$2"; shift 2 ;;
    --candidate) [ "$#" -ge 2 ] || usage; candidate_specs="$candidate_specs
$2"; shift 2 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done
[ -n "$root" ] && [ -n "$workspace" ] && [ -n "$requested" ] || usage
[ -d "$root" ] || { echo "error=root-not-directory"; exit 2; }
root="$(CDPATH='' cd -P "$root" && pwd)"

valid_relative() {
  [ -n "$1" ] && [ "$1" != . ] || return 1
  case "$1" in /*|*//*|*/./*|./*|*/.|*/../*|../*|*/..) return 1 ;; esac
}
valid_identity() {
  printf '%s\n' "$1" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*/[a-z0-9]+(-[a-z0-9]+)*$'
}
valid_relative "$workspace" || { echo "error=unsafe-workspace"; exit 2; }
valid_identity "$requested" || { echo "identity=$requested"; echo "valid=false"; echo "reason=bad-identity"; exit 1; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/foreman-operation-check.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
errors="$tmp/errors"
: >"$errors"
cache_key() { printf '%s\n' "$1" | tr '/' '_'; }

while IFS= read -r spec; do
  [ -n "$spec" ] || continue
  candidate_identity="${spec%%=*}"; candidate_file="${spec#*=}"
  [ "$candidate_identity" != "$spec" ] && valid_identity "$candidate_identity" \
    || { echo "error=bad-candidate-identity"; exit 2; }
  [ -f "$candidate_file" ] && [ ! -L "$candidate_file" ] \
    || { echo "error=bad-candidate-file"; exit 2; }
  printf '%s\n' "$candidate_file" >"$tmp/candidate_$(cache_key "$candidate_identity")"
done <<EOF
$candidate_specs
EOF

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else echo "sha256-tool-missing" >&2; return 2
  fi
}

operation_path() {
  local owner="${1%%/*}" stem="${1#*/}"
  local candidate
  candidate="$tmp/candidate_$(cache_key "$1")"
  if [ -f "$candidate" ]; then cat "$candidate"; return; fi
  printf '%s/%s/%s/operations/%s.md\n' "$root" "$workspace" "$owner" "$stem"
}
record_error() { printf '%s:%s\n' "$1" "$2" >>"$errors"; }

fm_get() {
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 && $0 == "---" { fm=1; next }
    fm && $0 == "---" { exit }
    fm && index($0, key ":") == 1 {
      v=substr($0,length(key)+2); sub(/^[ \t]*/,"",v); sub(/[ \t]*$/,"",v)
      if (v ~ /^".*"$/) { v=substr(v,2,length(v)-2); gsub(/\\"/,"\"",v) }
      print v; exit
    }
  ' "$file"
}

section() {
  awk -v heading="## $2" '
    $0 == heading { emit=1; print; next }
    emit && /^## / { exit }
    emit && /^[[:space:]]*$/ { blanks++; next }
    emit {
      while (blanks > 0) { print ""; blanks-- }
      print
    }
  ' "$1"
}

section_count() { grep -cFx -- "## $2" "$1" || true; }

validate_array() {
  local value="$1" item oldifs="$IFS"
  case "$value" in \[*\]) ;; *) return 1 ;; esac
  value="${value#\[}"; value="${value%\]}"
  [ -n "$value" ] || return 1
  IFS=,
  for item in $value; do
    item="$(printf '%s' "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    printf '%s\n' "$item" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || { IFS="$oldifs"; return 1; }
  done
  IFS="$oldifs"
}

check_one() {
  local identity="$1" stack="$2" key file fm_close schema title use_when shape status areas tags
  local source entry source_digest verified imported=no source_current=true current_source_digest=""
  local required heading procedure_n steps_n refs ref expected n canonical digest child_key child_digest
  key="$(cache_key "$identity")"
  if [ -f "$tmp/$key.done" ]; then return 0; fi
  case "$stack" in *"|$identity|"*) record_error "$identity" cycle; return 1 ;; esac
  file="$(operation_path "$identity")"
  if [ -L "$file" ] || [ ! -f "$file" ]; then record_error "$identity" missing-operation; return 1; fi
  if [ ! -f "$tmp/candidate_$key" ]; then
    case "$file" in "$root/$workspace/"*) ;; *) record_error "$identity" escaped-operation; return 1 ;; esac
  fi

  if [ "$(sed -n '1p' "$file")" != "---" ]; then record_error "$identity" missing-front-matter; return 1; fi
  fm_close="$(awk 'NR>1 && $0=="---" {print NR; exit}' "$file")"
  if [ -z "$fm_close" ]; then record_error "$identity" malformed-front-matter; return 1; fi

  # The schema is deliberately closed. Duplicate and unknown keys are malformed.
  if ! awk -v end="$fm_close" '
    NR>1 && NR<end {
      if ($0 !~ /^[a-z][a-z0-9-]*:[ \t]*[^[:space:]].*$/) exit 1
      key=$0; sub(/:.*/,"",key)
      if (seen[key]++) exit 1
      if (key !~ /^(schema|title|use-when|shape|status|areas|tags|source|entry-point|source-digest|verified-against)$/) exit 1
    }
  ' "$file"; then record_error "$identity" invalid-front-matter-field; return 1; fi

  schema="$(fm_get "$file" schema)"; title="$(fm_get "$file" title)"
  use_when="$(fm_get "$file" use-when)"; shape="$(fm_get "$file" shape)"
  status="$(fm_get "$file" status)"; areas="$(fm_get "$file" areas)"; tags="$(fm_get "$file" tags)"
  for required in schema title use_when shape status areas tags; do
    eval "value=\${$required}"
    [ -n "$value" ] || { record_error "$identity" "missing-$required"; return 1; }
  done
  [ "$schema" = foreman/operation@1 ] || { record_error "$identity" bad-schema; return 1; }
  case "$shape" in procedure|workflow) ;; *) record_error "$identity" bad-shape; return 1 ;; esac
  case "$status" in draft|active|deprecated) ;; *) record_error "$identity" bad-status; return 1 ;; esac
  validate_array "$areas" || { record_error "$identity" bad-areas; return 1; }
  validate_array "$tags" || { record_error "$identity" bad-tags; return 1; }

  source="$(fm_get "$file" source)"; entry="$(fm_get "$file" entry-point)"
  source_digest="$(fm_get "$file" source-digest)"; verified="$(fm_get "$file" verified-against)"
  if [ -n "$source$entry$source_digest" ]; then
    imported=yes
    [ -n "$source" ] && [ -n "$entry" ] && [ -n "$source_digest" ] \
      || { record_error "$identity" incomplete-import; return 1; }
    valid_relative "$source" || { record_error "$identity" unsafe-source; return 1; }
    printf '%s\n' "$source_digest" | grep -Eq '^sha256:[0-9a-f]{64}$' \
      || { record_error "$identity" bad-source-digest; return 1; }
    if [ -L "$root/$source" ] || [ ! -f "$root/$source" ]; then
      source_current=false
      current_source_digest="sha256:missing"
    else
      current_source_digest="sha256:$(sha256_file "$root/$source")" || return 1
      [ "$current_source_digest" = "$source_digest" ] || source_current=false
    fi
  fi
  if [ -n "$verified" ]; then
    printf '%s\n' "$verified" | grep -Eq '^sha256:[0-9a-f]{64}$' \
      || { record_error "$identity" bad-verified-against; return 1; }
  fi

  for heading in Preconditions Outputs Verification Recovery; do
    [ "$(section_count "$file" "$heading")" -eq 1 ] \
      || { record_error "$identity" "bad-section-$heading"; return 1; }
  done
  procedure_n="$(section_count "$file" Procedure)"; steps_n="$(section_count "$file" Steps)"
  if [ "$shape" = procedure ]; then
    [ "$procedure_n" -eq 1 ] && [ "$steps_n" -eq 0 ] \
      || { record_error "$identity" procedure-shape-mismatch; return 1; }
  else
    [ "$steps_n" -eq 1 ] && [ "$procedure_n" -eq 0 ] \
      || { record_error "$identity" workflow-shape-mismatch; return 1; }
  fi
  [ "$(section_count "$file" 'Verification evidence')" -le 1 ] \
    || { record_error "$identity" duplicate-verification-evidence; return 1; }

  refs=""
  if [ "$shape" = workflow ]; then
    refs="$(section "$file" Steps | awk '
      NR==1 {next}
      /^[[:space:]]*$/ {next}
      /^[0-9]+\. `/ {
        if (!match($0,/^[0-9]+\. `[a-z0-9]+(-[a-z0-9]+)*\/[a-z0-9]+(-[a-z0-9]+)*`/)) exit 2
        line=$0; sub(/\..*/,"",line); print "N=" line
        ref=substr($0,RSTART,RLENGTH); sub(/^[0-9]+\. `/,"",ref); sub(/`.*$/,"",ref); print "R=" ref
        next
      }
      /^[0-9]+\./ {exit 2}
    ' 2>/dev/null)" || { record_error "$identity" malformed-step; return 1; }
    expected=1
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      case "$ref" in
        N=*) n="${ref#N=}"; [ "$n" -eq "$expected" ] || { record_error "$identity" unordered-step; return 1; }; expected=$((expected + 1)) ;;
        R=*)
          ref="${ref#R=}"; check_one "$ref" "$stack|$identity|" || return 1 ;;
      esac
    done <<EOF
$refs
EOF
    [ "$expected" -gt 1 ] || { record_error "$identity" empty-workflow; return 1; }
  fi

  canonical="$tmp/$key.canonical"
  {
    printf 'schema=%s\ntitle=%s\nuse-when=%s\nshape=%s\nareas=%s\ntags=%s\n' \
      "$schema" "$title" "$use_when" "$shape" "$areas" "$tags"
    if [ "$imported" = yes ]; then
      printf 'source=%s\nentry-point=%s\nsource-digest=%s\n' "$source" "$entry" "$current_source_digest"
    fi
    for heading in Preconditions Procedure Steps Outputs Verification Recovery; do
      [ "$(section_count "$file" "$heading")" -eq 1 ] && section "$file" "$heading"
    done
    if [ "$shape" = workflow ]; then
      while IFS= read -r ref; do
        case "$ref" in R=*)
          ref="${ref#R=}"; child_key="$(cache_key "$ref")"; child_digest="$(cat "$tmp/$child_key.digest")"
          printf 'child=%s@%s\n' "$ref" "$child_digest" ;;
        esac
      done <<EOF
$refs
EOF
    fi
  } >"$canonical"
  digest="sha256:$(sha256_file "$canonical")" || return 1
  printf '%s\n' "$digest" >"$tmp/$key.digest"
  printf '%s\n' "$title" >"$tmp/$key.title"
  printf '%s\n' "$use_when" >"$tmp/$key.use_when"
  printf '%s\n' "$shape" >"$tmp/$key.shape"
  printf '%s\n' "$status" >"$tmp/$key.status"
  printf '%s\n' "$areas" >"$tmp/$key.areas"
  printf '%s\n' "$tags" >"$tmp/$key.tags"
  printf '%s\n' "$source_current" >"$tmp/$key.source_current"
  printf '%s\n' "$verified" >"$tmp/$key.verified"
  : >"$tmp/$key.done"
}

if ! check_one "$requested" "|"; then
  echo "identity=$requested"
  echo "path=$(operation_path "$requested")"
  echo "valid=false"
  sed 's/^/reason=/' "$errors"
  exit 1
fi

key="$(cache_key "$requested")"
digest="$(cat "$tmp/$key.digest")"; verified="$(cat "$tmp/$key.verified")"
status="$(cat "$tmp/$key.status")"; source_current="$(cat "$tmp/$key.source_current")"
verification=missing
[ -n "$verified" ] && verification=stale
[ -n "$verified" ] && [ "$verified" = "$digest" ] && [ "$source_current" = true ] && verification=current
goal_eligible=false
[ "$status" = active ] && [ "$verification" = current ] && goal_eligible=true
echo "identity=$requested"
echo "path=$(operation_path "$requested")"
echo "valid=true"
echo "title=$(cat "$tmp/$key.title")"
echo "use_when=$(cat "$tmp/$key.use_when")"
echo "shape=$(cat "$tmp/$key.shape")"
echo "status=$status"
echo "areas=$(cat "$tmp/$key.areas")"
echo "tags=$(cat "$tmp/$key.tags")"
echo "digest=$digest"
echo "source_current=$source_current"
echo "verification=$verification"
echo "goal_eligible=$goal_eligible"
