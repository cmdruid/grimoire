#!/usr/bin/env bash
# trackers.sh — guarded tracker@1 provider for one first-class tracker layer.
set -euo pipefail

die() { echo "reason=$1${2:+ detail=$2}" >&2; exit 2; }
usage() { die usage; }

valid_stem() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]] && [ "$1" != receipts ]; }
valid_consumer() { [[ "$1" =~ ^[a-z0-9][a-z0-9._/-]*$ ]]; }
single_line() { [[ "$1" != *$'\t'* ]] && [[ "$1" != *$'\n'* ]] && [[ "$1" != *$'\r'* ]]; }
valid_time() { [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

case "$0" in /*) SCRIPT_PATH="$0";; *) SCRIPT_PATH="$PWD/$0";; esac
SCRIPT_PARENT="${SCRIPT_PATH%/*}"

guard_provider_path() {
  local project_root logical_root="" candidate physical rel current component old_ifs="$IFS"
  [ ! -L "$SCRIPT_PATH" ] || die symlink "$SCRIPT_PATH"
  [ -f "$SCRIPT_PATH" ] || die noncanonical-provider "$SCRIPT_PATH"
  [ ! -L "$SCRIPT_PARENT" ] || die symlink "$SCRIPT_PARENT"
  [ -d "$SCRIPT_PARENT" ] || die missing-layer "$SCRIPT_PARENT"
  project_root="$(git -C "$SCRIPT_PARENT" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$project_root" ] || return 0
  project_root="$(CDPATH='' cd -P "$project_root" && pwd)"
  candidate="$SCRIPT_PARENT"
  while [ "$candidate" != / ]; do
    physical="$(CDPATH='' cd -P "$candidate" 2>/dev/null && pwd)" || break
    if [ "$physical" = "$project_root" ]; then logical_root="$candidate"; break; fi
    candidate="${candidate%/*}"; [ -n "$candidate" ] || candidate=/
  done
  [ -n "$logical_root" ] || die noncanonical-provider "$SCRIPT_PATH"
  rel="${SCRIPT_PARENT#"$logical_root"/}"; current="$logical_root"
  IFS=/; read -r -a components <<< "$rel"; IFS="$old_ifs"
  for component in "${components[@]}"; do
    [ "$component" != .. ] || die unsafe-provider-path "$SCRIPT_PATH"
    [ -n "$component" ] && [ "$component" != . ] || continue
    current="$current/$component"
    [ ! -L "$current" ] || die symlink "$current"
    [ -d "$current" ] || die missing-layer "$SCRIPT_PARENT"
  done
}

guard_provider_path
TRACKERS="$(CDPATH='' cd -P "$SCRIPT_PARENT" && pwd)"
QUEUE_HEADER=$'id\tcreated\ttext\tevidence'
RECEIPT_HEADER=$'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult'
RECEIPTS="$TRACKERS/receipts.tsv"
[ -f "$RECEIPTS" ] && [ ! -L "$RECEIPTS" ] || die malformed-receipts

validate_receipts() {
  awk -F '\t' -v header="$RECEIPT_HEADER" '
    NR==1 { if ($0 != header) exit 10; next }
    {
      if (NF != 8) exit 11
      if ($1 !~ /^receipt-[1-9][0-9]*$/ || seen[$1]++) exit 12
      if ($2 !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/) exit 13
      if ($3 !~ /^[a-z0-9][a-z0-9._\/-]*$/) exit 14
      if ($4 !~ /^[a-z0-9][a-z0-9-]*$/ || $4 == "receipts") exit 15
      if ($5 !~ ("^" $4 "-[1-9][0-9]*$")) exit 16
      if ($6 != "observed" && $6 != "consumed") exit 17
      if ($6 == "observed" && ($7 != "" || $8 != "")) exit 18
      if ($6 == "consumed" && $7 == "") exit 19
    }
  ' "$RECEIPTS" || die malformed-receipts
}

tracker_file() {
  valid_stem "$1" || die invalid-stem "$1"
  printf '%s/%s.tsv\n' "$TRACKERS" "$1"
}

validate_queue() {
  local stem="$1" file="$2"
  [ -f "$file" ] && [ ! -L "$file" ] || die no-tracker "$stem"
  awk -F '\t' -v header="$QUEUE_HEADER" -v stem="$stem" '
    NR==1 { if ($0 != header) exit 10; next }
    {
      if (NF != 4) exit 11
      if ($1 !~ ("^" stem "-[1-9][0-9]*$") || seen[$1]++) exit 12
      if ($2 !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/) exit 13
      if ($3 == "") exit 14
    }
  ' "$file" || die malformed-tracker "$stem"
}

validate_receipts

fresh_temp() {
  [ ! -L "$1" ] || die symlink "$1"
  [ ! -e "$1" ] || die incompatible-entry "$1"
}

replace_canonical() {
  local tmp="$1" destination="$2" reason="$3"
  guard_provider_path
  [ ! -L "$destination" ] || die symlink "$destination"
  [ -f "$destination" ] || die "$reason"
  mv "$tmp" "$destination"
}

PAGE_TMP=""
cleanup_page_tmp() {
  [ -n "$PAGE_TMP" ] || return 0
  rm -f -- "$PAGE_TMP" 2>/dev/null || true
  PAGE_TMP=""
}

open_page_tmp() {
  PAGE_TMP="$(mktemp "${TMPDIR:-/tmp}/tracker-page-rows.XXXXXX")" || die temp-failure
  trap cleanup_page_tmp EXIT
}

max_suffix() {
  local stem="$1" file="$2"
  awk -F '\t' -v stem="$stem" '
    FNR==NR { if (FNR>1 && $1 ~ ("^" stem "-[1-9][0-9]*$")) { n=$1; sub("^" stem "-", "", n); if (n+0>m)m=n+0 } next }
    FNR>1 && $4==stem { n=$5; sub("^" stem "-", "", n); if (n+0>m)m=n+0 }
    END { print m+0 }
  ' "$file" "$RECEIPTS"
}

next_receipt_id() {
  awk -F '\t' 'NR>1 { n=$1; sub(/^receipt-/,"",n); if(n+0>m)m=n+0 } END{print "receipt-" (m+1)}' "$RECEIPTS"
}

is_consumed() {
  awk -F '\t' -v stem="$1" -v id="$2" 'NR>1 && $4==stem && $5==id && $6=="consumed"{yes=1} END{exit !yes}' "$RECEIPTS"
}

is_observed() {
  awk -F '\t' -v consumer="$1" -v stem="$2" -v id="$3" '
    NR>1 && $3==consumer && $4==stem && $5==id && ($6=="observed" || $6=="consumed"){yes=1}
    END{exit !yes}
  ' "$RECEIPTS"
}

append_receipt() {
  local consumer="$1" stem="$2" item="$3" action="$4" resolution="$5" result="$6" tmp rid
  rid="$(next_receipt_id)"; tmp="$RECEIPTS.tmp.$$"
  fresh_temp "$tmp"
  cp "$RECEIPTS" "$tmp"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$rid" "$(now)" "$consumer" "$stem" "$item" "$action" "$resolution" "$result" >> "$tmp"
  replace_canonical "$tmp" "$RECEIPTS" malformed-receipts
  echo "receipt=$rid"
  echo 'wrote=receipts.tsv'
}

cmd_describe() {
  cat <<'EOF'
schema=tracker@1
queue_header=id<TAB>created<TAB>text<TAB>evidence
receipt_header=id<TAB>created<TAB>consumer<TAB>tracker<TAB>item<TAB>action<TAB>resolution<TAB>result
commands=describe,catalog,create,page,update,observe,consume
page_envelope=schema,tracker,next,--,tsv
cursor=last-returned-id
status=open,consumed,all
write_paths=tracker-relative
EOF
}

cmd_catalog() {
  local file stem open consumed all
  printf 'tracker\topen\tconsumed\tall\n'
  for file in "$TRACKERS"/*.tsv; do
    [ -e "$file" ] || [ -L "$file" ] || continue
    [ ! -L "$file" ] || die symlink "$file"
    [ -f "$file" ] || die invalid-tracker-file "$file"
    stem="$(basename "$file" .tsv)"
    if [ "$stem" = receipts ]; then
      all=$(( $(wc -l < "$file") - 1 )); printf 'receipts\t0\t0\t%s\n' "$all"; continue
    fi
    valid_stem "$stem" || die invalid-tracker-file "$stem"
    validate_queue "$stem" "$file"
    read -r open consumed all < <(awk -F '\t' -v stem="$stem" '
      FNR==NR { if(FNR>1 && $4==stem && $6=="consumed")done[$5]=1; next }
      FNR>1 { all++; if(done[$1])consumed++; else open++ }
      END{print open+0, consumed+0, all+0}
    ' "$RECEIPTS" "$file")
    printf '%s\t%s\t%s\t%s\n' "$stem" "$open" "$consumed" "$all"
  done
}

cmd_create() {
  local stem="" text="" evidence="" file max id tmp
  while [ $# -gt 0 ]; do case "$1" in
    --tracker) stem="${2:-}"; shift 2;; --text) text="${2:-}"; shift 2;;
    --evidence) evidence="${2:-}"; shift 2;; *) usage;; esac; done
  valid_stem "$stem" || die invalid-stem "$stem"
  [ -n "$text" ] && single_line "$text" || die invalid-text
  single_line "$evidence" || die invalid-evidence
  file="$(tracker_file "$stem")"; validate_queue "$stem" "$file"
  max="$(max_suffix "$stem" "$file")"; id="$stem-$((max+1))"; tmp="$file.tmp.$$"
  fresh_temp "$tmp";cp "$file" "$tmp";printf '%s\t%s\t%s\t%s\n' "$id" "$(now)" "$text" "$evidence" >> "$tmp";replace_canonical "$tmp" "$file" no-tracker
  echo "id=$id"; echo "wrote=$stem.tsv"
}

cmd_update() {
  local stem="" id="" text="" evidence="" text_set=false evidence_set=false file tmp found
  while [ $# -gt 0 ]; do case "$1" in
    --tracker) stem="${2:-}"; shift 2;; --id) id="${2:-}"; shift 2;;
    --text) text_set=true; text="${2:-}"; shift 2;;
    --evidence) evidence_set=true; evidence="${2:-}"; shift 2;; *) usage;; esac; done
  valid_stem "$stem" || die invalid-stem "$stem"; [[ "$id" =~ ^$stem-[1-9][0-9]*$ ]] || die invalid-id "$id"
  [ "$text_set" = true ] || [ "$evidence_set" = true ] || usage
  if [ "$text_set" = true ]; then [ -n "$text" ] && single_line "$text" || die invalid-text; fi
  if [ "$evidence_set" = true ]; then single_line "$evidence" || die invalid-evidence; fi
  file="$(tracker_file "$stem")"; validate_queue "$stem" "$file"
  is_consumed "$stem" "$id" && die consumed "$id"
  found="$(awk -F '\t' -v id="$id" 'NR>1&&$1==id{n++}END{print n+0}' "$file")"; [ "$found" -eq 1 ] || die missing-id "$id"
  tmp="$file.tmp.$$"
  fresh_temp "$tmp"
  TRACKER_UPDATE_TEXT="$text" TRACKER_UPDATE_EVIDENCE="$evidence" \
    awk -F '\t' -v OFS='\t' -v id="$id" -v ts="$text_set" -v es="$evidence_set" \
      '{if($1==id){if(ts=="true")$3=ENVIRON["TRACKER_UPDATE_TEXT"];if(es=="true")$4=ENVIRON["TRACKER_UPDATE_EVIDENCE"]}print}' \
      "$file" > "$tmp"
  replace_canonical "$tmp" "$file" no-tracker; echo "wrote=$stem.tsv"
}

cmd_page() {
  local stem="" status="" limit="" after="" consumer="" unobserved=false file rows=0 next="" id created text evidence state
  while [ $# -gt 0 ]; do case "$1" in
    --tracker) stem="${2:-}"; shift 2;; --status) status="${2:-}"; shift 2;;
    --limit) limit="${2:-}"; shift 2;; --after) after="${2:-}"; shift 2;;
    --consumer) consumer="${2:-}"; shift 2;; --unobserved) unobserved=true; shift;; *) usage;; esac; done
  [[ "$limit" =~ ^[1-9][0-9]*$ ]] || die invalid-limit "$limit"
  case "$status" in open|consumed|all) ;; *) die invalid-status "$status";; esac
  if [ "$stem" = receipts ]; then
    [ "$status" = all ] || die receipts-status; [ -z "$consumer" ] && [ "$unobserved" = false ] || die receipts-filter
    echo 'schema=tracker@1'; echo 'tracker=receipts'
    open_page_tmp;tmp_rows="$PAGE_TMP"
    awk -F '\t' -v after="$after" -v limit="$limit" 'BEGIN{go=(after=="")} NR==1{next} !go{if($1==after)go=1;next} go&&n<limit+1{print;n++}' "$RECEIPTS" > "$tmp_rows"
    if [ -n "$after" ] && ! awk -F '\t' -v id="$after" 'NR>1&&$1==id{yes=1}END{exit !yes}' "$RECEIPTS"; then cleanup_page_tmp;die invalid-cursor "$after";fi
    count="$(wc -l < "$tmp_rows"|tr -d ' ')";if [ "$count" -gt "$limit" ];then next="$(awk -F '\t' -v n="$limit" 'NR==n{print $1}' "$tmp_rows")";else next="";fi
    echo "next=$next";echo '--';echo "$RECEIPT_HEADER";head -n "$limit" "$tmp_rows";cleanup_page_tmp;return
  fi
  valid_stem "$stem" || die invalid-stem "$stem"
  if [ "$unobserved" = true ]; then valid_consumer "$consumer" || die invalid-consumer "$consumer"; elif [ -n "$consumer" ]; then die consumer-without-unobserved; fi
  file="$(tracker_file "$stem")"; validate_queue "$stem" "$file"
  if [ -n "$after" ] && ! awk -F '\t' -v id="$after" 'NR>1&&$1==id{yes=1}END{exit !yes}' "$file"; then die invalid-cursor "$after"; fi
  echo 'schema=tracker@1'; echo "tracker=$stem"
  open_page_tmp;tmp_rows="$PAGE_TMP";seen_after=false;[ -z "$after" ]&&seen_after=true
  while IFS=$'\t' read -r id created text evidence; do
    [ "$id" != id ] || continue
    if [ "$seen_after" = false ]; then [ "$id" = "$after" ] && seen_after=true; continue; fi
    if is_consumed "$stem" "$id"; then state=consumed; else state=open; fi
    [ "$status" = all ] || [ "$status" = "$state" ] || continue
    if [ "$unobserved" = true ] && is_observed "$consumer" "$stem" "$id"; then continue; fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$created" "$text" "$evidence" "$state" >> "$tmp_rows"
    rows=$((rows+1)); [ "$rows" -le "$limit" ] || break
  done < "$file"
  if [ "$rows" -gt "$limit" ];then next="$(awk -F '\t' -v n="$limit" 'NR==n{print $1}' "$tmp_rows")";else next="";fi
  echo "next=$next";echo '--';printf '%s\tstatus\n' "$QUEUE_HEADER";head -n "$limit" "$tmp_rows";cleanup_page_tmp
}

parse_receipt_args() {
  CONSUMER=""; STEM=""; RESOLUTION=""; RESULT=""; IDS=()
  while [ $# -gt 0 ]; do case "$1" in
    --consumer) CONSUMER="${2:-}"; shift 2;; --tracker) STEM="${2:-}"; shift 2;;
    --resolution) RESOLUTION="${2:-}"; shift 2;; --result) RESULT="${2:-}"; shift 2;;
    --ids) shift; while [ $# -gt 0 ] && [[ "$1" != --* ]]; do IDS+=("$1"); shift; done;; *) usage;; esac; done
  valid_consumer "$CONSUMER" || die invalid-consumer "$CONSUMER"
  valid_stem "$STEM" || die invalid-stem "$STEM"; [ "${#IDS[@]}" -gt 0 ] || usage
  single_line "$RESOLUTION" && single_line "$RESULT" || die invalid-receipt-text
}

item_exists() { awk -F '\t' -v id="$2" 'NR>1&&$1==id{yes=1}END{exit !yes}' "$1"; }

cmd_observe() {
  local file id
  parse_receipt_args "$@"; [ -z "$RESOLUTION" ] && [ -z "$RESULT" ] || usage
  file="$(tracker_file "$STEM")"; validate_queue "$STEM" "$file"
  for id in "${IDS[@]}"; do
    if ! item_exists "$file" "$id"; then echo "missing=$id"; continue; fi
    if is_observed "$CONSUMER" "$STEM" "$id"; then echo "unchanged=$id"; continue; fi
    append_receipt "$CONSUMER" "$STEM" "$id" observed "" ""
  done
}

cmd_consume() {
  local file id
  parse_receipt_args "$@"; [ -n "$RESOLUTION" ] || die resolution-required
  file="$(tracker_file "$STEM")"; validate_queue "$STEM" "$file"
  for id in "${IDS[@]}"; do
    if ! item_exists "$file" "$id"; then echo "missing=$id"; continue; fi
    if is_consumed "$STEM" "$id"; then echo "already-consumed=$id"; continue; fi
    append_receipt "$CONSUMER" "$STEM" "$id" consumed "$RESOLUTION" "$RESULT"
  done
}

cmd="${1:-}"; [ -n "$cmd" ] || usage; shift
case "$cmd" in
  describe) [ $# -eq 0 ] || usage; cmd_describe;;
  catalog) [ $# -eq 0 ] || usage; cmd_catalog;;
  create) cmd_create "$@";; page) cmd_page "$@";; update) cmd_update "$@";;
  observe) cmd_observe "$@";; consume) cmd_consume "$@";; *) usage;;
esac
