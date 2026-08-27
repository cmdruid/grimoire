#!/usr/bin/env bash
# tracker-api.sh — guarded tracker@1 provider for one first-class tracker layer.
set -euo pipefail

die() { echo "reason=$1${2:+ detail=$2}" >&2; exit 2; }
usage() { die usage; }

valid_rel() {
  local value="$1" component old_ifs="$IFS"
  [ -n "$value" ] && [ "$value" != . ] || return 1
  case "$value" in /*) return 1 ;; esac
  IFS=/; read -r -a components <<< "$value"; IFS="$old_ifs"
  for component in "${components[@]}"; do
    [ -n "$component" ] && [ "$component" != . ] && [ "$component" != .. ] || return 1
  done
}

valid_stem() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]] && [ "$1" != receipts ]; }
valid_consumer() { [[ "$1" =~ ^[a-z0-9][a-z0-9._/-]*$ ]]; }
single_line() { [[ "$1" != *$'\t'* ]] && [[ "$1" != *$'\n'* ]] && [[ "$1" != *$'\r'* ]]; }
valid_time() { [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

ROOT=""; RR_REL=""; WS_REL=""; TR_REL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --records-root) RR_REL="${2:-}"; shift 2 ;;
    --workspace) WS_REL="${2:-}"; shift 2 ;;
    --trackers-root) TR_REL="${2:-}"; shift 2 ;;
    *) break ;;
  esac
done
[ -n "$ROOT" ] && [ -n "$RR_REL" ] && [ -n "$WS_REL" ] && [ -n "$TR_REL" ] && [ $# -gt 0 ] || usage
case "$ROOT" in /*) ;; *) die unsafe-root "$ROOT" ;; esac
[ -d "$ROOT" ] || die unsafe-root "$ROOT"
ROOT="$(CDPATH='' cd -P "$ROOT" && pwd)"
valid_rel "$RR_REL" || die unsafe-records-root "$RR_REL"
valid_rel "$WS_REL" || die unsafe-workspace "$WS_REL"
valid_rel "$TR_REL" || die unsafe-trackers-root "$TR_REL"

overlap() {
  [ "$1" = "$2" ] || [[ "$1" == "$2/"* ]] || [[ "$2" == "$1/"* ]]
}
overlap "$TR_REL" "$RR_REL" && die overlapping-roots "$TR_REL:$RR_REL"
overlap "$TR_REL" "$WS_REL" && die overlapping-roots "$TR_REL:$WS_REL"
overlap "$RR_REL" "$WS_REL" && die overlapping-roots "$RR_REL:$WS_REL"

safe_existing_tree() {
  local rel="$1" current="$ROOT" component old_ifs="$IFS"
  IFS=/; read -r -a components <<< "$rel"; IFS="$old_ifs"
  for component in "${components[@]}"; do
    current="$current/$component"
    [ ! -L "$current" ] || die symlink "$current"
    [ -d "$current" ] || die missing-layer "$rel"
  done
}

safe_existing_tree "$TR_REL"
TRACKERS="$ROOT/$TR_REL"
SCRIPT_DIR="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
[ "$SCRIPT_DIR" = "$TRACKERS" ] || die noncanonical-provider "$SCRIPT_DIR"
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
  cp "$RECEIPTS" "$tmp"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$rid" "$(now)" "$consumer" "$stem" "$item" "$action" "$resolution" "$result" >> "$tmp"
  mv "$tmp" "$RECEIPTS"
  echo "receipt=$rid"
  echo "wrote=${RECEIPTS#"$ROOT"/}"
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
EOF
}

cmd_catalog() {
  local file stem open consumed all
  printf 'tracker\topen\tconsumed\tall\n'
  for file in "$TRACKERS"/*.tsv; do
    [ -f "$file" ] || continue
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
  cp "$file" "$tmp"; printf '%s\t%s\t%s\t%s\n' "$id" "$(now)" "$text" "$evidence" >> "$tmp"; mv "$tmp" "$file"
  echo "id=$id"; echo "wrote=${file#"$ROOT"/}"
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
  awk -F '\t' -v OFS='\t' -v id="$id" -v ts="$text_set" -v es="$evidence_set" -v text="$text" -v evidence="$evidence" \
    '{if($1==id){if(ts=="true")$3=text;if(es=="true")$4=evidence}print}' "$file" > "$tmp"
  mv "$tmp" "$file"; echo "wrote=${file#"$ROOT"/}"
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
    tmp_rows="${TMPDIR:-/tmp}/tracker-page-rows.$$"; : > "$tmp_rows"
    awk -F '\t' -v after="$after" -v limit="$limit" 'BEGIN{go=(after=="")} NR==1{next} !go{if($1==after)go=1;next} go&&n<limit+1{print;n++}' "$RECEIPTS" > "$tmp_rows"
    if [ -n "$after" ] && ! awk -F '\t' -v id="$after" 'NR>1&&$1==id{yes=1}END{exit !yes}' "$RECEIPTS"; then rm "$tmp_rows"; die invalid-cursor "$after"; fi
    count="$(wc -l < "$tmp_rows"|tr -d ' ')";if [ "$count" -gt "$limit" ];then next="$(awk -F '\t' -v n="$limit" 'NR==n{print $1}' "$tmp_rows")";else next="";fi
    echo "next=$next"; echo '--'; echo "$RECEIPT_HEADER"; head -n "$limit" "$tmp_rows"; rm "$tmp_rows"; return
  fi
  valid_stem "$stem" || die invalid-stem "$stem"
  if [ "$unobserved" = true ]; then valid_consumer "$consumer" || die invalid-consumer "$consumer"; elif [ -n "$consumer" ]; then die consumer-without-unobserved; fi
  file="$(tracker_file "$stem")"; validate_queue "$stem" "$file"
  if [ -n "$after" ] && ! awk -F '\t' -v id="$after" 'NR>1&&$1==id{yes=1}END{exit !yes}' "$file"; then die invalid-cursor "$after"; fi
  echo 'schema=tracker@1'; echo "tracker=$stem"
  tmp_rows="${TMPDIR:-/tmp}/tracker-page-rows.$$"; : > "$tmp_rows"; seen_after=false; [ -z "$after" ] && seen_after=true
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
  echo "next=$next"; echo '--'; printf '%s\tstatus\n' "$QUEUE_HEADER"; head -n "$limit" "$tmp_rows"; rm "$tmp_rows"
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

cmd="$1"; shift
case "$cmd" in
  describe) [ $# -eq 0 ] || usage; cmd_describe;;
  catalog) [ $# -eq 0 ] || usage; cmd_catalog;;
  create) cmd_create "$@";; page) cmd_page "$@";; update) cmd_update "$@";;
  observe) cmd_observe "$@";; consume) cmd_consume "$@";; *) usage;;
esac
