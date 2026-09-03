#!/usr/bin/env bash
# Custody-enforcing writer for Foreman-owned operations.
# shellcheck disable=SC2016 # Markdown backticks in the workflow-reference regex are literal.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage:
  operation-write.sh put --root <root> --identity foreman/<stem> --candidate <file>
  operation-write.sh migrate-batch --root <root> --batch <tsv> [--deny-list <file>]
  operation-write.sh lifecycle --root <root> --identity <owner/stem> --status active|deprecated --expected-digest sha256:<digest>
  operation-write.sh verify --root <root> --identity <owner/stem> --expected-digest sha256:<digest> --evidence-file <file>
  operation-write.sh promote --root <root> --identity foreman/<stem> --expected-digest sha256:<digest> --expected-file-sha256 <hex> --evidence-file <file> --expected-evidence-sha256 <hex>
  operation-write.sh doctrine --root <root> --stem <stem> --candidate <file> [--deny-list <file>]
EOF
  exit 2
}
die() { echo "status=refused"; echo "reason=$1"; exit 1; }
sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else die sha256-tool-missing
  fi
}
protocol_safe_path() {
  [ -n "$1" ] || return 1
  case "$1" in *'|'*|*$'\n'*) return 1 ;; esac
  if LC_ALL=C printf '%s' "$1" | grep -q '[[:cntrl:]]'; then return 1; fi
  return 0
}
valid_relative() {
  [ -n "$1" ] && [ "$1" != . ] || return 1
  protocol_safe_path "$1" || return 1
  case "$1" in /*|*//*|*/./*|./*|*/.|*/../*|../*|*/..) return 1 ;; esac
}
valid_identity() { printf '%s\n' "$1" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*/[a-z0-9]+(-[a-z0-9]+)*$'; }
fm_get() {
  awk -v key="$2" 'NR==1&&$0=="---"{fm=1;next} fm&&$0=="---"{exit}
    fm&&index($0,key ":")==1 {v=substr($0,length(key)+2);sub(/^[ \t]*/,"",v);print v;exit}' "$1"
}
section_body() {
  awk -v h="## $2" '$0==h{emit=1;next} emit&&/^## /{exit} emit{print}' "$1"
}
check_chain() {
  local rel="$1" cur="$root" part oldifs="$IFS" missing=false
  valid_relative "$rel" || die unsafe-destination
  IFS=/
  for part in $rel; do
    [ -n "$part" ] || continue; cur="$cur/$part"; [ "$missing" = false ] || continue
    [ ! -L "$cur" ] || { IFS="$oldifs"; die symlink-destination-parent; }
    if [ -e "$cur" ]; then [ -d "$cur" ] || { IFS="$oldifs"; die non-directory-destination-parent; }; else missing=true; fi
  done
  IFS="$oldifs"
}
ensure_chain() {
  local rel="$1" cur="$root" part oldifs="$IFS"
  IFS=/
  for part in $rel; do
    [ -n "$part" ] || continue; cur="$cur/$part"
    [ ! -L "$cur" ] || { IFS="$oldifs"; die symlink-destination-parent; }
    if [ -e "$cur" ]; then [ -d "$cur" ] || { IFS="$oldifs"; die non-directory-destination-parent; }; else mkdir "$cur"; fi
  done
  IFS="$oldifs"
}
source_file_for() {
  local rel="$1" path parent base canonical_parent
  valid_relative "$rel" || die unsafe-source
  path="$root/$rel"
  [ -f "$path" ] && [ ! -L "$path" ] || die source-drift
  parent="$(dirname "$path")"; base="$(basename "$path")"
  canonical_parent="$(CDPATH='' cd -P "$parent" 2>/dev/null && pwd)" || die source-drift
  SOURCE_FILE="$canonical_parent/$base"
  case "$SOURCE_FILE" in "$root"/*) ;; *) die unsafe-source ;; esac
  [ -f "$SOURCE_FILE" ] && [ ! -L "$SOURCE_FILE" ] || die source-drift
}
destination_for() {
  local identity="$1" owner="${1%%/*}" stem="${1#*/}" rel
  rel="$skilldata/$owner/operations/$stem.md"
  [ -z "${FOREMAN_WRITE_TEST_DEST_REL:-}" ] || rel="$FOREMAN_WRITE_TEST_DEST_REL"
  [ "$rel" = "$skilldata/foreman/operations/$stem.md" ] || die foreign-destination
  DEST_REL="$rel"
}
validate_candidate_shape() {
  local candidate="$1"
  [ "$(fm_get "$candidate" status)" = draft ] || die migration-must-write-draft
  [ -z "$(fm_get "$candidate" verified-against)" ] || die draft-carries-verification
}
atomic_copy() {
  local candidate="$1" dest="$2" dir tmpfile
  dir="${dest%/*}"; ensure_chain "${dir#"$root"/}"; check_chain "${dir#"$root"/}"
  [ ! -L "$dest" ] && [ ! -e "$dest" ] || die destination-changed
  tmpfile="$(mktemp "$dir/.foreman-write.XXXXXX")"
  cp "$candidate" "$tmpfile"; chmod 644 "$tmpfile"; mv "$tmpfile" "$dest"
}

mode="${1:-}"; [ -n "$mode" ] || usage; shift
root=""; skilldata=.agents/skilldata; identity=""; candidate=""; batch=""; deny_list=""; new_status=""; expected_digest=""; evidence_file=""; stem=""
expected_file_sha256=""; expected_evidence_sha256=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || usage; root="$2"; shift 2 ;;
    --identity) [ "$#" -ge 2 ] || usage; identity="$2"; shift 2 ;;
    --candidate) [ "$#" -ge 2 ] || usage; candidate="$2"; shift 2 ;;
    --batch) [ "$#" -ge 2 ] || usage; batch="$2"; shift 2 ;;
    --deny-list) [ "$#" -ge 2 ] || usage; deny_list="$2"; shift 2 ;;
    --status) [ "$#" -ge 2 ] || usage; new_status="$2"; shift 2 ;;
    --expected-digest) [ "$#" -ge 2 ] || usage; expected_digest="$2"; shift 2 ;;
    --expected-file-sha256) [ "$#" -ge 2 ] || usage; expected_file_sha256="$2"; shift 2 ;;
    --evidence-file) [ "$#" -ge 2 ] || usage; evidence_file="$2"; shift 2 ;;
    --expected-evidence-sha256) [ "$#" -ge 2 ] || usage; expected_evidence_sha256="$2"; shift 2 ;;
    --stem) [ "$#" -ge 2 ] || usage; stem="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$root" ] || usage
[ -d "$root" ] || usage; root="$(CDPATH='' cd -P "$root" && pwd)"
script_dir="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"; checker="$script_dir/operation-check.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/foreman-operation-write.XXXXXX")"; replacement=""
cleanup() { rm -rf "$tmp"; [ -z "$replacement" ] || rm -f "$replacement"; }
trap cleanup EXIT HUP INT TERM
filtered_deny="$tmp/deny"; : >"$filtered_deny"
if [ -n "$deny_list" ]; then
  [ -f "$deny_list" ] && [ ! -L "$deny_list" ] || die bad-deny-list
  sed '/^[[:space:]]*$/d' "$deny_list" >"$filtered_deny"
fi
candidate_tainted() { [ -s "$filtered_deny" ] && grep -F -f "$filtered_deny" "$1" >/dev/null; }
validate_goal_children() {
  local root_identity="$1" seen="$tmp/promotion-children-seen"
  : >"$seen"
  walk_goal_child() {
    local child_identity="$1" root_node="$2" facts path shape ref key
    grep -qxF "$child_identity" "$seen" && return 0
    printf '%s\n' "$child_identity" >>"$seen"
    key="$(printf '%s' "$child_identity" | tr '/' '_')"
    facts="$tmp/promotion-child-$key"
    "$checker" --root "$root" --operation "$child_identity" >"$facts" || die invalid-child
    if [ "$root_node" = no ]; then
      [ "$(sed -n 's/^goal_eligible=//p' "$facts")" = true ] || die ineligible-child
    fi
    path="$(sed -n 's/^path=//p' "$facts")"; shape="$(sed -n 's/^shape=//p' "$facts")"
    if [ "$shape" = workflow ]; then
      while IFS= read -r ref; do
        [ -n "$ref" ] && walk_goal_child "$ref" no
      done <<EOF
$(section_body "$path" Steps | sed -n -E 's/^[0-9]+\. `([^`]*)`.*/\1/p')
EOF
    fi
  }
  walk_goal_child "$root_identity" yes
}

case "$mode" in
  put)
    [ -n "$identity" ] && [ -n "$candidate" ] || usage
    valid_identity "$identity" || die bad-identity
    [ "${identity%%/*}" = foreman ] || die foreign-owner
    [ -f "$candidate" ] && [ ! -L "$candidate" ] || die bad-candidate
    candidate_tainted "$candidate" && die tainted-candidate
    validate_candidate_shape "$candidate"
    "$checker" --root "$root" --operation "$identity" \
      --candidate "$identity=$candidate" >"$tmp/check" || die invalid-candidate
    destination_for "$identity"; dest_rel="$DEST_REL"; check_chain "${dest_rel%/*}"; dest="$root/$dest_rel"
    [ ! -L "$dest" ] || die symlink-destination
    if [ -e "$dest" ]; then
      [ -f "$dest" ] || die non-file-destination
      if cmp -s "$candidate" "$dest"; then echo "status=preserved"; echo "path=$dest_rel"; echo "writes=0"; exit 0; fi
      die incumbent-conflict
    fi
    atomic_copy "$candidate" "$dest"
    echo "status=created"; echo "path=$dest_rel"; echo "writes=1"
    ;;
  migrate-batch)
    [ -n "$batch" ] && [ -f "$batch" ] && [ ! -L "$batch" ] || usage
    awk -F '\t' 'NF && NF != 4 {exit 1}' "$batch" || die bad-batch-row
    specs=(); rows="$tmp/rows"; : >"$rows"; seen="$tmp/seen"; : >"$seen"
    while IFS="$(printf '\t')" read -r row_identity row_candidate row_source row_source_digest extra; do
      [ -n "$row_identity$row_candidate$row_source$row_source_digest$extra" ] || continue
      [ -z "$extra" ] || die bad-batch-row
      valid_identity "$row_identity" || die bad-identity
      [ "${row_identity%%/*}" = foreman ] || die foreign-owner
      grep -qxF "$row_identity" "$seen" && die duplicate-candidate
      echo "$row_identity" >>"$seen"
      protocol_safe_path "$row_candidate" || die unsafe-candidate-path
      [ -f "$row_candidate" ] && [ ! -L "$row_candidate" ] || die bad-candidate
      source_file_for "$row_source"; source_file="$SOURCE_FILE"
      [ "$row_source_digest" = "sha256:$(sha256_file "$source_file")" ] || die source-drift
      validate_candidate_shape "$row_candidate"
      if [ -s "$filtered_deny" ] && grep -F -f "$filtered_deny" "$row_candidate" >/dev/null; then die tainted-candidate; fi
      destination_for "$row_identity"; dest_rel="$DEST_REL"; check_chain "${dest_rel%/*}"; dest="$root/$dest_rel"
      [ ! -L "$dest" ] || die symlink-destination
      if [ -e "$dest" ]; then [ -f "$dest" ] || die non-file-destination; cmp -s "$row_candidate" "$dest" || die incumbent-conflict; fi
      specs+=(--candidate "$row_identity=$row_candidate")
      printf '%s\t%s\t%s\t%s\t%s\n' "$row_identity" "$row_candidate" "$row_source" "$row_source_digest" "$dest_rel" >>"$rows"
    done <"$batch"
    [ -s "$rows" ] || { echo "status=empty"; echo "writes=0"; exit 0; }
    while IFS="$(printf '\t')" read -r row_identity row_candidate row_source row_source_digest dest_rel; do
      "$checker" --root "$root" --operation "$row_identity" "${specs[@]}" >"$tmp/check" \
        || die incomplete-or-invalid-closure
    done <"$rows"
    writes=0; preserved=0
    while IFS="$(printf '\t')" read -r row_identity row_candidate row_source row_source_digest dest_rel; do
      source_file_for "$row_source"; source_file="$SOURCE_FILE"
      [ "$row_source_digest" = "sha256:$(sha256_file "$source_file")" ] || die source-drift
      check_chain "${dest_rel%/*}"; dest="$root/$dest_rel"
      if [ -f "$dest" ] && [ ! -L "$dest" ]; then
        cmp -s "$row_candidate" "$dest" || die destination-drift
        preserved=$((preserved + 1)); echo "preserved=$dest_rel"; continue
      fi
      [ ! -e "$dest" ] && [ ! -L "$dest" ] || die destination-drift
      atomic_copy "$row_candidate" "$dest"; writes=$((writes + 1)); echo "created=$dest_rel"
      if [ -n "${FOREMAN_WRITE_TEST_AFTER_WRITE:-}" ]; then
        "$FOREMAN_WRITE_TEST_AFTER_WRITE" "$root" "$skilldata" "$row_identity" "$writes"
      fi
    done <"$rows"
    echo "status=applied"; echo "writes=$writes"; echo "preserved_count=$preserved"
    ;;
  lifecycle)
    [ -n "$identity" ] && [ -n "$new_status" ] && [ -n "$expected_digest" ] || usage
    valid_identity "$identity" || die bad-identity
    case "$new_status" in active|deprecated) ;; *) die bad-transition ;; esac
    if [ "${identity%%/*}" != foreman ]; then
      echo "status=proposed"; echo "identity=$identity"; echo "requested_transition=$new_status"; echo "write=false"; exit 1
    fi
    "$checker" --root "$root" --operation "$identity" >"$tmp/check" || die invalid-operation
    [ "$(sed -n 's/^digest=//p' "$tmp/check")" = "$expected_digest" ] || die operation-drift
    if [ "$new_status" = active ]; then [ "$(sed -n 's/^verification=//p' "$tmp/check")" = current ] || die stale-verification; fi
    file="$(sed -n 's/^path=//p' "$tmp/check")"; before="$(sha256_file "$file")"
    candidate="$tmp/lifecycle.md"
    awk -v status="$new_status" 'NR==1&&$0=="---"{fm=1} fm&&/^status:/{print "status: " status;next} {print}' "$file" >"$candidate"
    "$checker" --root "$root" --operation "$identity" \
      --candidate "$identity=$candidate" >"$tmp/recheck" || die invalid-transition-result
    [ "$(sha256_file "$file")" = "$before" ] || die destination-drift
    [ -z "${FOREMAN_WRITE_TEST_BEFORE_REPLACE:-}" ] || "$FOREMAN_WRITE_TEST_BEFORE_REPLACE" "$root" "$skilldata" "$identity"
    check_chain "$skilldata/foreman/operations"; [ ! -L "$file" ] && [ -f "$file" ] || die destination-drift
    [ "$(sha256_file "$file")" = "$before" ] || die destination-drift
    replacement="$(mktemp "${file%/*}/.foreman-lifecycle.XXXXXX")"; cp "$candidate" "$replacement"; chmod 644 "$replacement"; mv "$replacement" "$file"
    echo "status=updated"; echo "identity=$identity"; echo "transition=$new_status"; echo "writes=1"
    ;;
  verify)
    [ -n "$identity" ] && [ -n "$expected_digest" ] && [ -n "$evidence_file" ] || usage
    valid_identity "$identity" || die bad-identity
    [ -f "$evidence_file" ] && [ ! -L "$evidence_file" ] && [ -s "$evidence_file" ] || die bad-evidence
    [ "$(wc -c <"$evidence_file" | tr -d ' ')" -le 8192 ] || die evidence-too-large
    grep -Eq '^## |^---$' "$evidence_file" && die unsafe-evidence-shape
    if [ "${identity%%/*}" != foreman ]; then
      echo "status=proposed"; echo "identity=$identity"; echo "requested_verification=$expected_digest"; echo "evidence_file=$evidence_file"; echo "write=false"; exit 1
    fi
    "$checker" --root "$root" --operation "$identity" >"$tmp/check" || die invalid-operation
    [ "$(sed -n 's/^digest=//p' "$tmp/check")" = "$expected_digest" ] || die operation-drift
    [ "$(sed -n 's/^source_current=//p' "$tmp/check")" = true ] || die source-drift
    file="$(sed -n 's/^path=//p' "$tmp/check")"; before="$(sha256_file "$file")"; candidate="$tmp/verified.md"
    awk -v digest="$expected_digest" '
      NR==1&&$0=="---" {fm=1; print; next}
      fm&&/^verified-against:/ {print "verified-against: " digest; seen=1; next}
      fm&&$0=="---" {if(!seen) print "verified-against: " digest; fm=0; print; next}
      $0=="## Verification evidence" {skip=1; next}
      skip&&/^## / {skip=0}
      !skip {print}
    ' "$file" >"$candidate"
    while [ -s "$candidate" ] && [ "$(tail -c 1 "$candidate" | od -An -tx1 | tr -d ' \n')" != 0a ]; do printf '\n' >>"$candidate"; done
    printf '\n## Verification evidence\n\n' >>"$candidate"; awk '{print}' "$evidence_file" >>"$candidate"
    "$checker" --root "$root" --operation "$identity" --candidate "$identity=$candidate" >"$tmp/recheck" \
      || die invalid-verification-result
    [ "$(sed -n 's/^verification=//p' "$tmp/recheck")" = current ] || die evidence-not-bound
    [ "$(sha256_file "$file")" = "$before" ] || die destination-drift
    check_chain "$skilldata/foreman/operations"; replacement="$(mktemp "${file%/*}/.foreman-verify.XXXXXX")"
    cp "$candidate" "$replacement"; chmod 644 "$replacement"; mv "$replacement" "$file"
    echo "status=verified"; echo "identity=$identity"; echo "verified_against=$expected_digest"; echo "writes=1"
    ;;
  promote)
    [ -n "$identity" ] && [ -n "$expected_digest" ] && [ -n "$expected_file_sha256" ] &&
      [ -n "$evidence_file" ] && [ -n "$expected_evidence_sha256" ] || usage
    valid_identity "$identity" || die bad-identity
    if [ "${identity%%/*}" != foreman ]; then
      echo "status=proposed"; echo "identity=$identity"; echo "requested_promotion=$expected_digest"
      echo "write=false"; exit 1
    fi
    printf '%s\n' "$expected_digest" | grep -Eq '^sha256:[0-9a-f]{64}$' || die bad-expected-digest
    printf '%s\n%s\n' "$expected_file_sha256" "$expected_evidence_sha256" |
      grep -Eqv '^[0-9a-f]{64}$' && die bad-expected-raw-digest
    [ -f "$evidence_file" ] && [ ! -L "$evidence_file" ] && [ -s "$evidence_file" ] || die bad-evidence
    [ "$(wc -c <"$evidence_file" | tr -d ' ')" -le 8192 ] || die evidence-too-large
    grep -Eq '^## |^---$' "$evidence_file" && die unsafe-evidence-shape
    [ "$(sha256_file "$evidence_file")" = "$expected_evidence_sha256" ] || die evidence-drift
    "$checker" --root "$root" --operation "$identity" >"$tmp/promote-check" || die invalid-operation
    [ "$(sed -n 's/^digest=//p' "$tmp/promote-check")" = "$expected_digest" ] || die operation-drift
    [ "$(sed -n 's/^source_current=//p' "$tmp/promote-check")" = true ] || die source-drift
    [ "$(sed -n 's/^status=//p' "$tmp/promote-check")" = draft ] || die status-not-draft
    validate_goal_children "$identity"
    file="$(sed -n 's/^path=//p' "$tmp/promote-check")"
    [ "$(sha256_file "$file")" = "$expected_file_sha256" ] || die operation-file-drift
    promoted="$tmp/promoted.md"
    awk -v digest="$expected_digest" '
      NR==1&&$0=="---" {fm=1; print; next}
      fm&&/^status:/ {print "status: active"; next}
      fm&&/^verified-against:/ {print "verified-against: " digest; seen=1; next}
      fm&&$0=="---" {if(!seen) print "verified-against: " digest; fm=0; print; next}
      $0=="## Verification evidence" {skip=1; next}
      skip&&/^## / {skip=0}
      !skip {print}
    ' "$file" >"$promoted"
    while [ -s "$promoted" ] && [ "$(tail -c 1 "$promoted" | od -An -tx1 | tr -d ' \n')" != 0a ]; do printf '\n' >>"$promoted"; done
    printf '\n## Verification evidence\n\n' >>"$promoted"; awk '{print}' "$evidence_file" >>"$promoted"
    "$checker" --root "$root" --operation "$identity" --candidate "$identity=$promoted" >"$tmp/promote-result" || die invalid-promotion-result
    [ "$(sed -n 's/^digest=//p' "$tmp/promote-result")" = "$expected_digest" ] || die promotion-changed-digest
    [ "$(sed -n 's/^verification=//p' "$tmp/promote-result")" = current ] || die evidence-not-bound
    [ "$(sed -n 's/^goal_eligible=//p' "$tmp/promote-result")" = true ] || die promotion-not-goal-eligible
    check_chain "$skilldata/foreman/operations"
    replacement="$(mktemp "${file%/*}/.foreman-promote.XXXXXX")"
    cp "$promoted" "$replacement"; chmod 644 "$replacement"
    if [ -n "${FOREMAN_WRITE_TEST_PROMOTE_AFTER_STAGE:-}" ]; then
      "$FOREMAN_WRITE_TEST_PROMOTE_AFTER_STAGE" "$root" "$skilldata" "$identity" "$replacement"
    fi
    if [ -n "${FOREMAN_WRITE_TEST_PROMOTE_BEFORE_REPLACE:-}" ]; then
      "$FOREMAN_WRITE_TEST_PROMOTE_BEFORE_REPLACE" "$root" "$skilldata" "$identity" "$evidence_file"
    fi
    check_chain "$skilldata/foreman/operations"
    [ ! -L "$file" ] && [ -f "$file" ] || die destination-drift
    [ "$(sha256_file "$file")" = "$expected_file_sha256" ] || die destination-drift
    [ -f "$evidence_file" ] && [ ! -L "$evidence_file" ] || die evidence-drift
    [ "$(sha256_file "$evidence_file")" = "$expected_evidence_sha256" ] || die evidence-drift
    "$checker" --root "$root" --operation "$identity" >"$tmp/promote-final-check" || die invalid-operation
    [ "$(sed -n 's/^digest=//p' "$tmp/promote-final-check")" = "$expected_digest" ] || die operation-drift
    [ "$(sed -n 's/^source_current=//p' "$tmp/promote-final-check")" = true ] || die source-drift
    [ "$(sed -n 's/^status=//p' "$tmp/promote-final-check")" = draft ] || die status-not-draft
    validate_goal_children "$identity"
    mv "$replacement" "$file"; replacement=""
    echo "status=promoted"; echo "identity=$identity"; echo "verified_against=$expected_digest"
    echo "transition=draft-to-active"; echo "writes=1"
    ;;
  doctrine)
    [ -n "$stem" ] && [ -n "$candidate" ] || usage
    printf '%s\n' "$stem" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || die bad-stem
    [ -f "$candidate" ] && [ ! -L "$candidate" ] && [ -s "$candidate" ] || die bad-candidate
    candidate_tainted "$candidate" && die tainted-candidate
    dest_rel="$skilldata/foreman/doctrine/$stem.md"; check_chain "${dest_rel%/*}"; dest="$root/$dest_rel"
    [ ! -L "$dest" ] || die symlink-destination
    if [ -e "$dest" ]; then
      [ -f "$dest" ] || die non-file-destination
      if cmp -s "$candidate" "$dest"; then echo "status=preserved"; echo "path=$dest_rel"; echo "writes=0"; exit 0; fi
      die incumbent-conflict
    fi
    atomic_copy "$candidate" "$dest"
    echo "status=created"; echo "path=$dest_rel"; echo "writes=1"
    ;;
  *) usage ;;
esac
