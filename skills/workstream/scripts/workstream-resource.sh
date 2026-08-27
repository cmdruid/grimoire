#!/usr/bin/env bash
# Atomic repository-local resource claims for Workstream.
#
# Scripts compute facts; the resource verb owns judgment and hand-off edits.
set -euo pipefail
set -f
export LC_ALL=C

usage() {
  cat >&2 <<'EOF'
usage:
  workstream-resource.sh acquire <root> <stream> <branch> <handoff> <resource> <intent>
  workstream-resource.sh status <root> [<resource>]
  workstream-resource.sh validate <root> <stream> <handoff>
  workstream-resource.sh release <root> <stream> <handoff> <resource>
  workstream-resource.sh release-all <root> <stream> <handoff>
  workstream-resource.sh break <root> <resource> <expected-oid>
  workstream-resource.sh rollback <root> <resource> <expected-oid>
EOF
  exit 2
}

operation="${1:-}"
[ -n "$operation" ] || usage
shift

scratch="$(mktemp -d "${TMPDIR:-/tmp}/workstream-resource.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

repo=""
oid_len=0
locks_file="$scratch/locks"
meta_file="$scratch/meta"

emit_error() {
  printf 'operation=%s\n' "$operation"
  [ "$#" -lt 1 ] || printf 'resource=%s\n' "$1"
  printf 'state=%s\n' "$2"
  [ "$#" -lt 3 ] || printf 'reason=%s\n' "$3"
}

init_repo() {
  [ "$#" -eq 1 ] || usage
  local supplied="$1" physical top empty_oid
  case "$supplied" in
    /*) ;;
    *) emit_error "" invalid-root absolute-path-required; return 2 ;;
  esac
  [ -d "$supplied" ] || { emit_error "" invalid-root not-a-directory; return 2; }
  physical="$(cd -P "$supplied" && pwd -P)"
  if ! top="$(git -C "$physical" rev-parse --show-toplevel 2>/dev/null)"; then
    emit_error "" invalid-root not-a-git-worktree
    return 2
  fi
  top="$(cd -P "$top" && pwd -P)"
  [ "$top" = "$physical" ] || {
    emit_error "" invalid-root not-worktree-toplevel
    return 2
  }
  repo="$physical"
  empty_oid="$(printf '' | git -C "$repo" hash-object --stdin)"
  oid_len="${#empty_oid}"
  [ "$oid_len" -gt 0 ] || {
    emit_error "" invalid-root unknown-object-format
    return 2
  }
}

valid_resource() {
  local value="$1" bytes
  bytes="$(printf '%s' "$value" | wc -c | tr -d ' ')"
  [ "$bytes" -ge 1 ] && [ "$bytes" -le 63 ] &&
    printf '%s\n' "$value" | grep -Eq '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'
}

valid_stream() {
  printf '%s\n' "$1" | grep -Eq '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'
}

valid_oid() {
  local value="$1"
  [ "${#value}" -eq "$oid_len" ] && printf '%s\n' "$value" | grep -Eq '^[0-9a-f]+$'
}

valid_abs_path() {
  case "$1" in
    /*) return 0 ;;
    *) return 1 ;;
  esac
}

valid_text() {
  local value="$1" max="$2" bytes
  bytes="$(printf '%s' "$value" | wc -c | tr -d ' ')"
  [ "$bytes" -ge 1 ] && [ "$bytes" -le "$max" ] || return 1
  if printf '%s' "$value" | grep -q '[[:cntrl:]]'; then
    return 1
  fi
}

valid_epoch() {
  local value="$1"
  [ "${#value}" -le 18 ] &&
    printf '%s\n' "$value" | grep -Eq '^(0|[1-9][0-9]*)$'
}

valid_rfc3339_utc() {
  local value="$1" parsed
  printf '%s\n' "$value" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' || return 1
  if parsed="$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$value" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)"; then
    [ "$parsed" = "$value" ]
    return
  fi
  if parsed="$(date -u -d "$value" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)"; then
    [ "$parsed" = "$value" ]
    return
  fi
  return 1
}

file_has_forbidden_control() {
  od -An -t u1 "$1" | awk '
    {
      for (i = 1; i <= NF; i++) {
        if (($i < 32 && $i != 10) || $i == 127) bad = 1
      }
    }
    END { exit bad ? 0 : 1 }
  '
}

file_has_nul() {
  od -An -t u1 "$1" | awk '
    {
      for (i = 1; i <= NF; i++) {
        if ($i == 0) found = 1
      }
    }
    END { exit found ? 0 : 1 }
  '
}

validate_identity() {
  local stream="$1" branch="$2" handoff="$3"
  valid_stream "$stream" || return 1
  [ "$branch" = "stream/$stream" ] || return 1
  valid_abs_path "$handoff" || return 1
  return 0
}

parse_handoff() {
  local handoff="$1" missing_mode="${2:-require-section}" sections section_file line resource oid duplicate
  : > "$locks_file"
  valid_abs_path "$handoff" || return 1
  [ -f "$handoff" ] && [ ! -L "$handoff" ] || return 1
  if file_has_nul "$handoff"; then
    return 1
  fi
  sections="$(grep -c '^## Resource locks$' "$handoff" || true)"
  if [ "$sections" = 0 ]; then
    [ "$missing_mode" = "allow-empty" ] || return 1
    ! grep -q '^resource-lock:' "$handoff" || return 1
    return 0
  fi
  [ "$sections" = 1 ] || return 1
  section_file="$scratch/section"
  awk '
    /^## Resource locks$/ { inside=1; next }
    inside && /^## / { exit }
    inside { print }
  ' "$handoff" > "$section_file"
  if file_has_forbidden_control "$section_file"; then
    return 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      resource-lock:*)
        set -- $line
        [ "$#" -eq 3 ] && [ "$1" = "resource-lock:" ] || return 1
        resource="$2"
        oid="$3"
        valid_resource "$resource" && valid_oid "$oid" || return 1
        duplicate="$(awk -F '\t' -v resource="$resource" '$1 == resource { n++ } END { print n + 0 }' "$locks_file")"
        [ "$duplicate" -eq 0 ] || return 1
        printf '%s\t%s\n' "$resource" "$oid" >> "$locks_file"
        ;;
    esac
  done < "$section_file"
  sort -o "$locks_file" "$locks_file"
}

lock_oid() {
  awk -F '\t' -v resource="$1" '$1 == resource { print $2 }' "$locks_file"
}

ref_oid() {
  git -C "$repo" show-ref --verify --hash "refs/workstream-resources/$1" 2>/dev/null
}

claim_parse_v1() {
  local expected_resource="$1" oid="$2" type last lines
  local l1 l2 l3 l4 l5 l6 l7 l8 l9
  META_RESOURCE=""
  META_OWNER=""
  META_BRANCH=""
  META_HANDOFF=""
  META_INTENT=""
  META_EPOCH=""
  META_AT=""
  META_NONCE=""
  valid_resource "$expected_resource" && valid_oid "$oid" || return 1
  if ! type="$(git -C "$repo" cat-file -t "$oid" 2>/dev/null)"; then
    return 1
  fi
  [ "$type" = blob ] || return 1
  git -C "$repo" cat-file blob "$oid" > "$meta_file"
  [ -s "$meta_file" ] || return 1
  if file_has_forbidden_control "$meta_file"; then
    return 1
  fi
  last="$(tail -c 1 "$meta_file" | od -An -t u1 | tr -d ' ')"
  [ "$last" = 10 ] || return 1
  lines="$(wc -l < "$meta_file" | tr -d ' ')"
  [ "$lines" = 9 ] || return 1
  l1="$(sed -n '1p' "$meta_file")"
  l2="$(sed -n '2p' "$meta_file")"
  l3="$(sed -n '3p' "$meta_file")"
  l4="$(sed -n '4p' "$meta_file")"
  l5="$(sed -n '5p' "$meta_file")"
  l6="$(sed -n '6p' "$meta_file")"
  l7="$(sed -n '7p' "$meta_file")"
  l8="$(sed -n '8p' "$meta_file")"
  l9="$(sed -n '9p' "$meta_file")"
  [ "$l1" = version=1 ] || return 1
  case "$l2" in resource=*) META_RESOURCE="${l2#resource=}" ;; *) return 1 ;; esac
  case "$l3" in owner=*) META_OWNER="${l3#owner=}" ;; *) return 1 ;; esac
  case "$l4" in branch=*) META_BRANCH="${l4#branch=}" ;; *) return 1 ;; esac
  case "$l5" in handoff=*) META_HANDOFF="${l5#handoff=}" ;; *) return 1 ;; esac
  case "$l6" in intent=*) META_INTENT="${l6#intent=}" ;; *) return 1 ;; esac
  case "$l7" in acquired_epoch=*) META_EPOCH="${l7#acquired_epoch=}" ;; *) return 1 ;; esac
  case "$l8" in acquired_at=*) META_AT="${l8#acquired_at=}" ;; *) return 1 ;; esac
  case "$l9" in nonce=*) META_NONCE="${l9#nonce=}" ;; *) return 1 ;; esac
  [ "$META_RESOURCE" = "$expected_resource" ] || return 1
  valid_stream "$META_OWNER" || return 1
  [ "$META_BRANCH" = "stream/$META_OWNER" ] || return 1
  valid_abs_path "$META_HANDOFF" || return 1
  valid_text "$META_INTENT" 256 || return 1
  valid_epoch "$META_EPOCH" || return 1
  valid_rfc3339_utc "$META_AT" || return 1
  valid_text "$META_NONCE" 512 || return 1
  return 0
}

emit_claim() {
  local oid="$1" now age
  now="$(date +%s)"
  age=$((now - META_EPOCH))
  [ "$age" -ge 0 ] || age=0
  printf 'owner=%s\n' "$META_OWNER"
  printf 'branch=%s\n' "$META_BRANCH"
  printf 'handoff=%s\n' "$META_HANDOFF"
  printf 'intent=%s\n' "$META_INTENT"
  printf 'acquired_at=%s\n' "$META_AT"
  printf 'age_seconds=%s\n' "$age"
  printf 'oid=%s\n' "$oid"
}

emit_singular_header() {
  printf 'operation=%s\nresource=%s\nstate=%s\n' "$operation" "$1" "$2"
}

status_one() {
  local resource="$1" oid
  if ! oid="$(ref_oid "$resource")"; then
    emit_singular_header "$resource" free
    printf 'held=false\n'
    return 1
  fi
  if ! claim_parse_v1 "$resource" "$oid"; then
    emit_singular_header "$resource" malformed
    printf 'held=true\noid=%s\n' "$oid"
    return 2
  fi
  emit_singular_header "$resource" held
  printf 'held=true\n'
  emit_claim "$oid"
}

status_all() {
  local refs="$scratch/refs" line ref resource oid count=0 malformed=0
  git -C "$repo" for-each-ref --format='%(refname) %(objectname)' refs/workstream-resources/ | sort > "$refs"
  printf 'operation=status\n'
  while IFS=' ' read -r ref oid || [ -n "$ref" ]; do
    [ -n "$ref" ] || continue
    resource="${ref#refs/workstream-resources/}"
    count=$((count + 1))
    if claim_parse_v1 "$resource" "$oid"; then
      printf 'resource-lock=%s %s\n' "$resource" "$oid"
      printf 'holder=%s %s %s\n' "$resource" "$META_OWNER" "$META_INTENT"
    else
      malformed=$((malformed + 1))
      printf 'malformed-resource=%s %s\n' "$resource" "$oid"
    fi
  done < "$refs"
  printf 'held_count=%s\n' "$count"
  printf 'malformed_count=%s\n' "$malformed"
  if [ "$malformed" -gt 0 ]; then
    printf 'state=malformed\n'
    return 2
  fi
  printf 'state=ok\n'
}

acquire() {
  [ "$#" -eq 6 ] || usage
  local root="$1" stream="$2" branch="$3" handoff="$4" resource="$5" intent="$6"
  local oid declared nonce_path nonce epoch acquired_at new_oid zero ref
  init_repo "$root" || return $?
  validate_identity "$stream" "$branch" "$handoff" && valid_resource "$resource" && valid_text "$intent" 256 || {
    emit_error "$resource" invalid-input identity-or-intent
    return 2
  }
  parse_handoff "$handoff" || {
    emit_error "$resource" malformed handoff-resource-locks
    return 2
  }
  declared="$(lock_oid "$resource")"
  if oid="$(ref_oid "$resource")"; then
    if ! claim_parse_v1 "$resource" "$oid"; then
      emit_singular_header "$resource" malformed
      printf 'acquired=false\nheld=true\noid=%s\n' "$oid"
      return 2
    fi
    if [ "$META_OWNER" = "$stream" ] && [ "$META_HANDOFF" = "$handoff" ]; then
      if [ "$declared" = "$oid" ]; then
        emit_singular_header "$resource" held
        printf 'acquired=false\nheld=true\nalready_owned=true\n'
        emit_claim "$oid"
        return 0
      fi
      emit_singular_header "$resource" inconsistent
      printf 'acquired=false\nheld=true\nalready_owned=false\n'
      emit_claim "$oid"
      return 2
    fi
    emit_singular_header "$resource" held
    printf 'acquired=false\nheld=true\nalready_owned=false\n'
    emit_claim "$oid"
    return 1
  fi
  [ -z "$declared" ] || {
    emit_singular_header "$resource" inconsistent
    printf 'acquired=false\nheld=false\ndeclared_oid=%s\n' "$declared"
    return 2
  }
  nonce_path="$(mktemp "${TMPDIR:-/tmp}/workstream-resource-nonce.XXXXXX")"
  nonce="$(basename "$nonce_path")"
  rm -f "$nonce_path"
  epoch="$(date +%s)"
  acquired_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'version=1\nresource=%s\nowner=%s\nbranch=%s\nhandoff=%s\nintent=%s\nacquired_epoch=%s\nacquired_at=%s\nnonce=%s\n' \
    "$resource" "$stream" "$branch" "$handoff" "$intent" "$epoch" "$acquired_at" "$nonce" > "$meta_file"
  new_oid="$(git -C "$repo" hash-object -w --stdin < "$meta_file")"
  zero="$(printf '%*s' "$oid_len" '' | tr ' ' '0')"
  ref="refs/workstream-resources/$resource"
  if git -C "$repo" update-ref "$ref" "$new_oid" "$zero" 2>/dev/null; then
    emit_singular_header "$resource" acquired
    printf 'acquired=true\nheld=true\nalready_owned=false\noid=%s\n' "$new_oid"
    return 0
  fi
  if ! oid="$(ref_oid "$resource")"; then
    emit_singular_header "$resource" changed
    printf 'acquired=false\nheld=false\n'
    return 1
  fi
  if ! claim_parse_v1 "$resource" "$oid"; then
    emit_singular_header "$resource" malformed
    printf 'acquired=false\nheld=true\noid=%s\n' "$oid"
    return 2
  fi
  emit_singular_header "$resource" held
  printf 'acquired=false\nheld=true\nalready_owned=false\n'
  emit_claim "$oid"
  return 1
}

validate_sets() {
  local stream="$1" handoff="$2" live="$scratch/live" refs="$scratch/refs"
  local resource expected oid ref
  : > "$live"
  parse_handoff "$handoff" allow-empty || return 1
  while IFS="$(printf '\t')" read -r resource expected || [ -n "$resource" ]; do
    [ -n "$resource" ] || continue
    if ! oid="$(ref_oid "$resource")"; then
      return 1
    fi
    [ "$oid" = "$expected" ] || return 1
    claim_parse_v1 "$resource" "$oid" || return 1
    [ "$META_OWNER" = "$stream" ] && [ "$META_HANDOFF" = "$handoff" ] || return 1
  done < "$locks_file"
  git -C "$repo" for-each-ref --format='%(refname) %(objectname)' refs/workstream-resources/ | sort > "$refs"
  while IFS=' ' read -r ref oid || [ -n "$ref" ]; do
    [ -n "$ref" ] || continue
    resource="${ref#refs/workstream-resources/}"
    if claim_parse_v1 "$resource" "$oid"; then
      if [ "$META_OWNER" = "$stream" ]; then
        [ "$META_HANDOFF" = "$handoff" ] || return 1
        printf '%s\t%s\n' "$resource" "$oid" >> "$live"
      fi
    elif awk -F '\t' -v resource="$resource" '$1 == resource { found=1 } END { exit !found }' "$locks_file"; then
      return 1
    fi
  done < "$refs"
  sort -o "$live" "$live"
  cmp -s "$locks_file" "$live"
}

validate_cmd() {
  [ "$#" -eq 3 ] || usage
  local root="$1" stream="$2" handoff="$3" resource oid count=0
  init_repo "$root" || return $?
  valid_stream "$stream" && valid_abs_path "$handoff" || {
    emit_error "" invalid-input identity
    return 2
  }
  if ! validate_sets "$stream" "$handoff"; then
    printf 'operation=validate\nstate=inconsistent\nvalid=false\n'
    return 2
  fi
  printf 'operation=validate\nstate=valid\nvalid=true\n'
  while IFS="$(printf '\t')" read -r resource oid || [ -n "$resource" ]; do
    [ -n "$resource" ] || continue
    claim_parse_v1 "$resource" "$oid"
    printf 'held_resource=%s\nheld_intent=%s %s\n' "$resource" "$resource" "$META_INTENT"
    count=$((count + 1))
  done < "$locks_file"
  printf 'held_count=%s\n' "$count"
}

release_one() {
  [ "$#" -eq 4 ] || usage
  local root="$1" stream="$2" handoff="$3" resource="$4" expected oid
  init_repo "$root" || return $?
  valid_stream "$stream" && valid_abs_path "$handoff" && valid_resource "$resource" || {
    emit_error "$resource" invalid-input identity
    return 2
  }
  parse_handoff "$handoff" || {
    emit_error "$resource" malformed handoff-resource-locks
    return 2
  }
  expected="$(lock_oid "$resource")"
  if [ -z "$expected" ]; then
    if ! oid="$(ref_oid "$resource")"; then
      emit_singular_header "$resource" free
      printf 'released=false\nalready_free=true\n'
      return 0
    fi
    if claim_parse_v1 "$resource" "$oid" && [ "$META_OWNER" != "$stream" ]; then
      emit_singular_header "$resource" not-owned
      printf 'released=false\nalready_free=false\n'
      emit_claim "$oid"
      return 1
    fi
    emit_singular_header "$resource" inconsistent
    printf 'released=false\nalready_free=false\noid=%s\n' "$oid"
    return 2
  fi
  if ! oid="$(ref_oid "$resource")"; then
    emit_singular_header "$resource" inconsistent
    printf 'released=false\ndeclared_oid=%s\n' "$expected"
    return 2
  fi
  if [ "$oid" != "$expected" ] || ! claim_parse_v1 "$resource" "$oid" ||
     [ "$META_OWNER" != "$stream" ] || [ "$META_HANDOFF" != "$handoff" ]; then
    emit_singular_header "$resource" inconsistent
    printf 'released=false\ndeclared_oid=%s\nlive_oid=%s\n' "$expected" "$oid"
    return 2
  fi
  if git -C "$repo" update-ref -d "refs/workstream-resources/$resource" "$expected" 2>/dev/null; then
    emit_singular_header "$resource" released
    printf 'released=true\nalready_free=false\noid=%s\n' "$expected"
    return 0
  fi
  emit_singular_header "$resource" changed
  printf 'released=false\nalready_free=false\nexpected_oid=%s\n' "$expected"
  if oid="$(ref_oid "$resource")"; then printf 'surviving_oid=%s\n' "$oid"; fi
  return 1
}

release_all() {
  [ "$#" -eq 3 ] || usage
  local root="$1" stream="$2" handoff="$3" count txn resource oid
  init_repo "$root" || return $?
  valid_stream "$stream" && valid_abs_path "$handoff" || {
    emit_error "" invalid-input identity
    return 2
  }
  if ! validate_sets "$stream" "$handoff"; then
    printf 'operation=release-all\nstate=inconsistent\nreleased=0\n'
    return 2
  fi
  count="$(wc -l < "$locks_file" | tr -d ' ')"
  if [ "$count" -eq 0 ]; then
    printf 'operation=release-all\nstate=released\nreleased=0\n'
    return 0
  fi
  txn="$scratch/transaction"
  printf 'start\n' > "$txn"
  while IFS="$(printf '\t')" read -r resource oid || [ -n "$resource" ]; do
    [ -n "$resource" ] || continue
    printf 'delete refs/workstream-resources/%s %s\n' "$resource" "$oid" >> "$txn"
  done < "$locks_file"
  printf 'prepare\ncommit\n' >> "$txn"
  if git -C "$repo" update-ref --stdin < "$txn" >/dev/null 2>&1; then
    printf 'operation=release-all\nstate=released\nreleased=%s\n' "$count"
    return 0
  fi
  printf 'operation=release-all\nstate=changed\nreleased=0\n'
  return 1
}

exact_delete() {
  [ "$#" -eq 3 ] || usage
  local root="$1" resource="$2" expected="$3" oid displaced_state=malformed
  init_repo "$root" || return $?
  valid_resource "$resource" && valid_oid "$expected" || {
    emit_error "$resource" invalid-input expected-oid
    return 2
  }
  if ! oid="$(ref_oid "$resource")"; then
    emit_singular_header "$resource" absent
    printf 'deleted=false\nexpected_oid=%s\n' "$expected"
    return 1
  fi
  if [ "$oid" != "$expected" ]; then
    emit_singular_header "$resource" changed
    printf 'deleted=false\nexpected_oid=%s\nsurviving_oid=%s\n' "$expected" "$oid"
    return 1
  fi
  if claim_parse_v1 "$resource" "$oid"; then displaced_state=held; fi
  if git -C "$repo" update-ref -d "refs/workstream-resources/$resource" "$expected" 2>/dev/null; then
    if [ "$operation" = break ]; then
      emit_singular_header "$resource" broken
    else
      emit_singular_header "$resource" rolled-back
    fi
    printf 'deleted=true\ndisplaced_state=%s\noid=%s\n' "$displaced_state" "$oid"
    [ "$displaced_state" != held ] || emit_claim "$oid"
    return 0
  fi
  emit_singular_header "$resource" changed
  printf 'deleted=false\nexpected_oid=%s\n' "$expected"
  if oid="$(ref_oid "$resource")"; then printf 'surviving_oid=%s\n' "$oid"; fi
  return 1
}

case "$operation" in
  acquire) acquire "$@" ;;
  status)
    [ "$#" -eq 1 ] || [ "$#" -eq 2 ] || usage
    init_repo "$1" || exit $?
    if [ "$#" -eq 2 ]; then
      valid_resource "$2" || { emit_error "$2" invalid-input resource; exit 2; }
      status_one "$2"
    else
      status_all
    fi
    ;;
  validate) validate_cmd "$@" ;;
  release) release_one "$@" ;;
  release-all) release_all "$@" ;;
  break|rollback) exact_delete "$@" ;;
  *) usage ;;
esac
