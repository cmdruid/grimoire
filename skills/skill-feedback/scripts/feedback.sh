#!/usr/bin/env bash
set -euo pipefail

umask 077
HEADER=$'id\tcreated_at\tupdated_at\tskill\tskill_ref\tinvocation\tkind\tsummary\tincident\tconsequence\tsuggestion\tproject_ref\tstatus\tdisposition\tresolution\tresult_ref'
DATA_DIR=""
DATA_FILE=""
LOCK_DIR=""
LOCK_OWNED=no
TEMP_FILE=""
QUERY_ROWS=""
QUERY_SORTED=""
QUERY_SELECTED=""
REQUEST_FILE=""

reason() {
  printf 'reason=%s action=%s\n' "$1" "$2" >&2
  exit 2
}

usage() { reason usage 'check-command'; }

cleanup() {
  [ -z "$QUERY_ROWS" ] || rm -f -- "$QUERY_ROWS"
  [ -z "$QUERY_SORTED" ] || rm -f -- "$QUERY_SORTED"
  [ -z "$QUERY_SELECTED" ] || rm -f -- "$QUERY_SELECTED"
  [ -z "$REQUEST_FILE" ] || rm -f -- "$REQUEST_FILE"
  if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ] && [ ! -L "$TEMP_FILE" ]; then
    rm -f -- "$TEMP_FILE"
  fi
  if [ "$LOCK_OWNED" = yes ] && [ -d "$LOCK_DIR" ] && [ ! -L "$LOCK_DIR" ]; then
    rm -f -- "$LOCK_DIR/pid"
    rmdir -- "$LOCK_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT HUP INT TERM

resolve_paths() {
  case "${HOME:-}" in /*) ;; *) reason invalid-home 'set-absolute-HOME' ;; esac
  [ -d "$HOME" ] || reason invalid-home 'set-existing-HOME'
  local physical
  physical="$(CDPATH='' cd -P -- "$HOME" 2>/dev/null && pwd -P)" ||
    reason invalid-home 'set-resolvable-HOME'
  DATA_DIR="$physical/.agents/skilldata/skill-feedback"
  DATA_FILE="$DATA_DIR/feedback.tsv"
  LOCK_DIR="$DATA_FILE.lock"
}

check_dir_entry() {
  local path="$1"
  [ ! -L "$path" ] || reason unsafe-path 'remove-symlink'
  if [ -e "$path" ]; then
    [ -d "$path" ] || reason incompatible-path 'remove-nondirectory'
  fi
}

check_file_entry() {
  [ ! -L "$DATA_FILE" ] || reason unsafe-path 'remove-symlink'
  if [ -e "$DATA_FILE" ]; then
    [ -f "$DATA_FILE" ] || reason incompatible-path 'remove-nonregular-file'
  fi
}

check_prefix() {
  local home agents skilldata
  home="${DATA_DIR%/.agents/skilldata/skill-feedback}"
  agents="$home/.agents"
  skilldata="$agents/skilldata"
  check_dir_entry "$agents"
  check_dir_entry "$skilldata"
  check_dir_entry "$DATA_DIR"
  check_file_entry
  [ ! -L "$LOCK_DIR" ] || reason unsafe-path 'remove-symlink'
  if [ -e "$LOCK_DIR" ] && [ ! -d "$LOCK_DIR" ]; then
    reason incompatible-path 'remove-invalid-lock'
  fi
}

ensure_layout() {
  local home agents skilldata
  home="${DATA_DIR%/.agents/skilldata/skill-feedback}"
  agents="$home/.agents"
  skilldata="$agents/skilldata"
  check_prefix
  if [ ! -d "$agents" ]; then mkdir -m 700 -- "$agents" || reason write-failed 'inspect-parent'; fi
  check_prefix
  if [ ! -d "$skilldata" ]; then mkdir -m 700 -- "$skilldata" || reason write-failed 'inspect-parent'; fi
  check_prefix
  if [ ! -d "$DATA_DIR" ]; then mkdir -m 700 -- "$DATA_DIR" || reason write-failed 'inspect-parent'; fi
  check_prefix
}

try_remove_stale_lock() {
  [ -d "$LOCK_DIR" ] && [ ! -L "$LOCK_DIR" ] || return 1
  [ -f "$LOCK_DIR/pid" ] && [ ! -L "$LOCK_DIR/pid" ] || return 1
  local entries pid
  entries="$(find "$LOCK_DIR" -mindepth 1 -maxdepth 1 -print 2>/dev/null | wc -l | tr -d '[:space:]')" || return 1
  [ "$entries" = 1 ] || return 1
  IFS= read -r pid < "$LOCK_DIR/pid" || return 1
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  if ps -p "$pid" >/dev/null 2>&1; then return 1; fi
  rm -f -- "$LOCK_DIR/pid" || return 1
  rmdir -- "$LOCK_DIR" || return 1
}

acquire_lock() {
  local allow_stale="${1:-no}" attempts=0
  while [ "$attempts" -lt 50 ]; do
    check_prefix
    if mkdir -m 700 -- "$LOCK_DIR" 2>/dev/null; then
      printf '%s\n' "$$" > "$LOCK_DIR/pid"
      chmod 600 "$LOCK_DIR/pid"
      LOCK_OWNED=yes
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 0.1
  done
  if [ "$allow_stale" = yes ] && try_remove_stale_lock; then
    check_prefix
    if mkdir -m 700 -- "$LOCK_DIR" 2>/dev/null; then
      printf '%s\n' "$$" > "$LOCK_DIR/pid"
      chmod 600 "$LOCK_DIR/pid"
      LOCK_OWNED=yes
      return 0
    fi
  fi
  reason feedback-busy retry
}

require_iconv() {
  command -v iconv >/dev/null 2>&1 || reason validator-unavailable 'install-iconv'
}

valid_utf8_value() {
  require_iconv
  LC_ALL=C printf '%s' "$1" | LC_ALL=C iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1
}

validate_utf8_file() {
  require_iconv
  LC_ALL=C iconv -f UTF-8 -t UTF-8 "$1" >/dev/null 2>&1 ||
    reason invalid-store 'repair-manually'
}

valid_utc_timestamp() {
  local value="$1" digits year month day hour minute second max_day
  [ "${#value}" -eq 20 ] || return 1
  [ "${value:4:1}" = - ] && [ "${value:7:1}" = - ] &&
    [ "${value:10:1}" = T ] && [ "${value:13:1}" = : ] &&
    [ "${value:16:1}" = : ] && [ "${value:19:1}" = Z ] || return 1
  digits="${value:0:4}${value:5:2}${value:8:2}${value:11:2}${value:14:2}${value:17:2}"
  case "$digits" in *[!0-9]*) return 1 ;; esac
  year=$((10#${value:0:4})); month=$((10#${value:5:2})); day=$((10#${value:8:2}))
  hour=$((10#${value:11:2})); minute=$((10#${value:14:2})); second=$((10#${value:17:2}))
  [ "$month" -ge 1 ] && [ "$month" -le 12 ] || return 1
  case "$month" in
    2)
      max_day=28
      if [ $((year % 400)) -eq 0 ] || { [ $((year % 4)) -eq 0 ] && [ $((year % 100)) -ne 0 ]; }; then
        max_day=29
      fi
      ;;
    4|6|9|11) max_day=30 ;;
    *) max_day=31 ;;
  esac
  [ "$day" -ge 1 ] && [ "$day" -le "$max_day" ] &&
    [ "$hour" -le 23 ] && [ "$minute" -le 59 ] && [ "$second" -le 60 ] || return 1
  if [ "$second" -eq 60 ]; then
    [ "$hour" -eq 23 ] && [ "$minute" -eq 59 ] && [ "$day" -eq "$max_day" ] &&
      { [ "$month" -eq 6 ] || [ "$month" -eq 12 ]; } || return 1
  fi
  return 0
}

current_utc() {
  local now
  if [ -n "${SKILL_FEEDBACK_TEST_UTC_NOW:-}" ]; then
    now="$SKILL_FEEDBACK_TEST_UTC_NOW"
    valid_utc_timestamp "$now" || reason test-hook-invalid retry
  else
    now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" || reason clock-unavailable retry
  fi
  printf '%s\n' "$now"
}

validate_file() {
  local file="$1" last
  [ -f "$file" ] && [ ! -L "$file" ] || reason invalid-store 'run-setup'
  validate_utf8_file "$file"
  last="$(tail -c 1 "$file" 2>/dev/null | od -An -tuC | tr -d '[:space:]')"
  [ "$last" = 10 ] || reason invalid-store 'repair-manually'
  if LC_ALL=C tr -d '\t\n' <"$file" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    reason invalid-store 'repair-manually'
  fi
  LC_ALL=C awk -F '\t' -v header="$HEADER" '
    function hex(s,n) { return length(s)==n && s !~ /[^0-9a-f]/ }
    function digits(s) { return s != "" && s !~ /[^0-9]/ }
    function leap(y) { return (y%4==0 && y%100!=0) || y%400==0 }
    function month_days(y,m) {
      if(m==2) return leap(y) ? 29 : 28
      if(m==4 || m==6 || m==9 || m==11) return 30
      return 31
    }
    function valid_parts(y,m,d,h,n,second) {
      if(!digits(y) || !digits(m) || !digits(d) || !digits(h) ||
         !digits(n) || !digits(second)) return 0
      y+=0; m+=0; d+=0; h+=0; n+=0; second+=0
      if(!(m>=1 && m<=12 && d>=1 && d<=month_days(y,m) &&
           h<=23 && n<=59 && second<=60)) return 0
      if(second==60 && !(h==23 && n==59 && d==month_days(y,m) &&
                         (m==6 || m==12))) return 0
      return 1
    }
    function timestamp(s) {
      return length(s)==20 && substr(s,5,1)=="-" && substr(s,8,1)=="-" &&
        substr(s,11,1)=="T" && substr(s,14,1)==":" && substr(s,17,1)==":" &&
        substr(s,20,1)=="Z" && valid_parts(substr(s,1,4),substr(s,6,2),
        substr(s,9,2),substr(s,12,2),substr(s,15,2),substr(s,18,2))
    }
    function basic_timestamp(s) {
      return length(s)==16 && substr(s,9,1)=="T" && substr(s,16,1)=="Z" &&
        valid_parts(substr(s,1,4),substr(s,5,2),substr(s,7,2),
        substr(s,10,2),substr(s,12,2),substr(s,14,2))
    }
    function feedback_id(s) {
      return length(s)==28 && substr(s,1,3)=="SF-" && substr(s,12,1)=="T" &&
        substr(s,19,1)=="Z" && substr(s,20,1)=="-" &&
        basic_timestamp(substr(s,4,16)) && hex(substr(s,21),8)
    }
    function slug(s) {
      return s ~ /^[a-z0-9][a-z0-9-]*[a-z0-9]$/ || s ~ /^[a-z0-9]$/
    }
    function encoded_len(s,    i,c,n,nextc) {
      n=0
      for(i=1;i<=length(s);i++) {
        c=substr(s,i,1)
        if(c ~ /[[:cntrl:]]/) return -1
        if(c=="\\") {
          if(i==length(s)) return -1
          nextc=substr(s,i+1,1)
          if(nextc!="\\" && nextc!="t" && nextc!="r" && nextc!="n") return -1
          i++
        }
        n++
      }
      return n
    }
    function safe_ref(s) {
      if(s=="") return 1
      if(substr(s,1,1)=="/" || s ~ /(^|\/)\.\.(\/|$)/) return 0
      return encoded_len(s)>=0 && length(s)<=512
    }
    NR==1 { if($0!=header || NF!=16) exit 10; next }
    {
      if(NF!=16 || length($0)+1>8192 || !feedback_id($1) || seen[$1]++) exit 11
      if(!timestamp($2) || !timestamp($3) || !slug($4)) exit 12
      if($5!="unknown" && !(substr($5,1,15)=="content-sha256:" && hex(substr($5,16),64))) exit 13
      if($6=="" || ($7!="friction" && $7!="gap" && $7!="win" && $7!="new-skill")) exit 14
      if(encoded_len($8)<1 || encoded_len($8)>240 || encoded_len($9)<1 || encoded_len($9)>2000 ||
         encoded_len($10)<1 || encoded_len($10)>2000 || encoded_len($11)<1 || encoded_len($11)>2000) exit 15
      if($12!="" && !(substr($12,1,13)=="local-sha256:" && hex(substr($12,14),16))) exit 16
      if($13=="open") {
        if($14!="" || $15!="" || $16!="") exit 17
      } else if($13=="resolved") {
        if($14!="applied" && $14!="preserved" && $14!="already-addressed" &&
           $14!="rejected" && $14!="stale" && $14!="duplicate") exit 18
        if(encoded_len($15)<1 || encoded_len($15)>2000 || !safe_ref($16)) exit 19
        if(($14=="applied" || $14=="preserved" || $14=="already-addressed" || $14=="duplicate") && $16=="") exit 20
      } else exit 21
    }
    END { if(NR<1) exit 22 }
  ' "$file" >/dev/null 2>&1 || reason invalid-store 'repair-manually'
}

ensure_file_locked() {
  check_prefix
  if [ ! -e "$DATA_FILE" ]; then
    TEMP_FILE="$(mktemp "$DATA_DIR/.feedback.tsv.tmp.XXXXXX")" || reason write-failed retry
    chmod 600 "$TEMP_FILE"
    printf '%s\n' "$HEADER" > "$TEMP_FILE"
    validate_file "$TEMP_FILE"
    check_prefix
    [ ! -e "$DATA_FILE" ] || reason concurrent-change retry
    mv -- "$TEMP_FILE" "$DATA_FILE"
    TEMP_FILE=""
  fi
  validate_file "$DATA_FILE"
}

byte_length() { LC_ALL=C printf '%s' "$1" | wc -c | tr -d '[:space:]'; }

valid_raw_text() {
  local value="$1" limit="$2" stripped
  [ -n "$value" ] || return 1
  valid_utf8_value "$value" || return 1
  [ "$(byte_length "$value")" -le "$limit" ] || return 1
  stripped="$(LC_ALL=C printf '%s' "$value" | tr -d '\t\r\n')"
  ! LC_ALL=C printf '%s' "$stripped" | grep -q '[[:cntrl:]]'
}

encode_text() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//$'\t'/\\t}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\n'/\\n}"
  printf '%s' "$value"
}

valid_slug() {
  case "$1" in ''|*[!a-z0-9-]*|-*|*-) return 1 ;; *) return 0 ;; esac
}

valid_hex() {
  local value="$1" length="$2"
  [ "${#value}" -eq "$length" ] || return 1
  case "$value" in *[!0-9a-f]*) return 1 ;; *) return 0 ;; esac
}

valid_skill_ref() {
  [ "$1" = unknown ] && return 0
  case "$1" in content-sha256:*) valid_hex "${1#content-sha256:}" 64 ;; *) return 1 ;; esac
}

valid_project_ref() {
  [ -z "$1" ] && return 0
  case "$1" in local-sha256:*) valid_hex "${1#local-sha256:}" 16 ;; *) return 1 ;; esac
}

valid_feedback_id() {
  local value="$1" date_part time_part hex_part timestamp
  [ "${#value}" -eq 28 ] || return 1
  [ "${value#SF-}" != "$value" ] || return 1
  date_part="${value:3:8}"; time_part="${value:12:6}"; hex_part="${value:20:8}"
  [ "${value:11:1}" = T ] && [ "${value:18:1}" = Z ] && [ "${value:19:1}" = - ] || return 1
  case "$date_part$time_part" in *[!0-9]*) return 1 ;; esac
  valid_hex "$hex_part" 8 || return 1
  timestamp="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}T${time_part:0:2}:${time_part:2:2}:${time_part:4:2}Z"
  valid_utc_timestamp "$timestamp"
}

valid_result_ref() {
  local value="$1" stripped
  valid_utf8_value "$value" || return 1
  [ "$(byte_length "$value")" -le 512 ] || return 1
  stripped="$(LC_ALL=C printf '%s' "$value" | tr -d '\t\r\n')"
  ! LC_ALL=C printf '%s' "$stripped" | grep -q '[[:cntrl:]]' || return 1
  case "$value" in /*|..|../*|*/../*|*/..) return 1 ;; esac
  return 0
}

random_hex() {
  if [ -n "${SKILL_FEEDBACK_TEST_RANDOM_SOURCE:-}" ]; then
    [ -x "$SKILL_FEEDBACK_TEST_RANDOM_SOURCE" ] || reason random-unavailable retry
    "$SKILL_FEEDBACK_TEST_RANDOM_SOURCE"
  else
    od -An -N4 -tx1 /dev/urandom | tr -d ' \n'
  fi
}

cmd_describe() {
  [ "$#" -eq 0 ] || usage
  printf '%s\n' 'schema=skill-feedback@1' \
    'store=.agents/skilldata/skill-feedback/feedback.tsv' \
    'commands=describe,init,capture,query,resolve'
}

cmd_init() {
  [ "$#" -eq 0 ] || usage
  resolve_paths
  ensure_layout
  acquire_lock yes
  ensure_file_locked
  chmod 700 "$DATA_DIR"
  chmod 600 "$DATA_FILE"
  printf 'status=ready\n'
}

cmd_capture() {
  local skill="" skill_ref="" invocation="" kind="" summary="" incident="" consequence="" suggestion="" project_ref=""
  local seen_skill=no seen_ref=no seen_invocation=no seen_kind=no seen_summary=no seen_incident=no seen_consequence=no seen_suggestion=no seen_project=no
  while [ "$#" -gt 0 ]; do
    [ "$#" -ge 2 ] || usage
    case "$1" in
      --skill) [ "$seen_skill" = no ] || usage; skill="$2"; seen_skill=yes ;;
      --skill-ref) [ "$seen_ref" = no ] || usage; skill_ref="$2"; seen_ref=yes ;;
      --invocation) [ "$seen_invocation" = no ] || usage; invocation="$2"; seen_invocation=yes ;;
      --kind) [ "$seen_kind" = no ] || usage; kind="$2"; seen_kind=yes ;;
      --summary) [ "$seen_summary" = no ] || usage; summary="$2"; seen_summary=yes ;;
      --incident) [ "$seen_incident" = no ] || usage; incident="$2"; seen_incident=yes ;;
      --consequence) [ "$seen_consequence" = no ] || usage; consequence="$2"; seen_consequence=yes ;;
      --suggestion) [ "$seen_suggestion" = no ] || usage; suggestion="$2"; seen_suggestion=yes ;;
      --project-ref) [ "$seen_project" = no ] || usage; project_ref="$2"; seen_project=yes ;;
      *) usage ;;
    esac
    shift 2
  done
  [ "$seen_skill$seen_ref$seen_invocation$seen_kind$seen_summary$seen_incident$seen_consequence$seen_suggestion" = yesyesyesyesyesyesyesyes ] || usage
  valid_slug "$skill" || reason invalid-skill 'use-lowercase-kebab-case'
  valid_skill_ref "$skill_ref" || reason invalid-skill-ref 'recompute-reference'
  valid_raw_text "$invocation" 240 || reason invalid-invocation 'provide-short-invocation'
  case "$kind" in friction|gap|win|new-skill) ;; *) reason invalid-kind 'use-declared-kind' ;; esac
  valid_raw_text "$summary" 240 || reason invalid-summary 'shorten-summary'
  valid_raw_text "$incident" 2000 || reason invalid-incident 'revise-observation'
  valid_raw_text "$consequence" 2000 || reason invalid-consequence 'revise-observation'
  valid_raw_text "$suggestion" 2000 || reason invalid-suggestion 'revise-observation'
  valid_project_ref "$project_ref" || reason invalid-project-ref 'recompute-reference'

  local enc_invocation enc_summary enc_incident enc_consequence enc_suggestion now id_time id hex
  enc_invocation="$(encode_text "$invocation")"
  enc_summary="$(encode_text "$summary")"
  enc_incident="$(encode_text "$incident")"
  enc_consequence="$(encode_text "$consequence")"
  enc_suggestion="$(encode_text "$suggestion")"
  resolve_paths
  ensure_layout
  acquire_lock no
  ensure_file_locked
  now="$(current_utc)"
  id_time="${now//-/}"
  id_time="${id_time//:/}"
  while :; do
    hex="$(random_hex)"
    valid_hex "$hex" 8 || reason random-unavailable retry
    id="SF-$id_time-$hex"
    if ! LC_ALL=C awk -F '\t' -v id="$id" 'NR>1 && $1==id { found=1 } END { exit found?0:1 }' "$DATA_FILE"; then break; fi
  done
  TEMP_FILE="$(mktemp "$DATA_DIR/.feedback.tsv.tmp.XXXXXX")" || reason write-failed retry
  chmod 600 "$TEMP_FILE"
  cp -- "$DATA_FILE" "$TEMP_FILE"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\topen\t\t\t\n' \
    "$id" "$now" "$now" "$skill" "$skill_ref" "$enc_invocation" "$kind" "$enc_summary" \
    "$enc_incident" "$enc_consequence" "$enc_suggestion" "$project_ref" >> "$TEMP_FILE"
  validate_file "$TEMP_FILE"
  if [ -n "${SKILL_FEEDBACK_TEST_BEFORE_RENAME:-}" ]; then
    [ -x "$SKILL_FEEDBACK_TEST_BEFORE_RENAME" ] || reason test-hook-invalid retry
    "$SKILL_FEEDBACK_TEST_BEFORE_RENAME" "$DATA_FILE" "$TEMP_FILE"
  fi
  check_prefix
  validate_file "$DATA_FILE"
  mv -- "$TEMP_FILE" "$DATA_FILE"
  TEMP_FILE=""
  printf 'captured=%s\ncount=1\n' "$id"
}

cmd_query() {
  local skill="" status=open limit=20 order=newest format=human include_project=no
  local seen_skill=no seen_status=no seen_limit=no seen_order=no seen_format=no seen_include=no
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --skill|--status|--limit|--order|--format)
        [ "$#" -ge 2 ] || usage
        case "$1" in
          --skill) [ "$seen_skill" = no ] || usage; skill="$2"; seen_skill=yes ;;
          --status) [ "$seen_status" = no ] || usage; status="$2"; seen_status=yes ;;
          --limit) [ "$seen_limit" = no ] || usage; limit="$2"; seen_limit=yes ;;
          --order) [ "$seen_order" = no ] || usage; order="$2"; seen_order=yes ;;
          --format) [ "$seen_format" = no ] || usage; format="$2"; seen_format=yes ;;
        esac
        shift 2 ;;
      --include-project-ref)
        [ "$seen_include" = no ] || usage; include_project=yes; seen_include=yes; shift ;;
      *) usage ;;
    esac
  done
  [ -z "$skill" ] || valid_slug "$skill" || reason invalid-skill 'use-lowercase-kebab-case'
  case "$status" in open|resolved) ;; *) usage ;; esac
  case "$limit" in ''|*[!0-9]*) usage ;; esac
  [ "$limit" -ge 1 ] && [ "$limit" -le 100 ] || usage
  case "$order" in newest|oldest) ;; *) usage ;; esac
  case "$format" in human|tsv) ;; *) usage ;; esac
  [ "$include_project" = no ] || [ "$format" = tsv ] || usage
  resolve_paths
  check_prefix
  [ -e "$DATA_FILE" ] || reason feedback-not-initialized 'run-setup-or-capture'
  validate_file "$DATA_FILE"

  local count
  QUERY_ROWS="$(mktemp "${TMPDIR:-/tmp}/skill-feedback-query.XXXXXX")"
  QUERY_SORTED="$(mktemp "${TMPDIR:-/tmp}/skill-feedback-sort.XXXXXX")"
  QUERY_SELECTED="$(mktemp "${TMPDIR:-/tmp}/skill-feedback-page.XXXXXX")"
  LC_ALL=C awk -F '\t' -v skill="$skill" -v status="$status" 'NR>1 && (skill=="" || $4==skill) && $13==status' "$DATA_FILE" > "$QUERY_ROWS"
  if [ "$order" = newest ]; then
    LC_ALL=C sort -t $'\t' -k2,2r -k1,1r "$QUERY_ROWS" > "$QUERY_SORTED"
  else
    LC_ALL=C sort -t $'\t' -k2,2 -k1,1 "$QUERY_ROWS" > "$QUERY_SORTED"
  fi
  head -n "$limit" "$QUERY_SORTED" > "$QUERY_SELECTED"
  count="$(wc -l < "$QUERY_SELECTED" | tr -d '[:space:]')"
  if [ "$format" = tsv ]; then
    printf '%s\n' "$HEADER"
    if [ "$include_project" = yes ]; then cat "$QUERY_SELECTED"; else
      LC_ALL=C awk -F '\t' 'BEGIN{OFS="\t"}{$12="";print}' "$QUERY_SELECTED"
    fi
  else
    LC_ALL=C awk -F '\t' '
      function decode(s,    out,i,c,n) {
        out=""
        for(i=1;i<=length(s);i++) {
          c=substr(s,i,1)
          if(c=="\\") {
            n=substr(s,++i,1)
            if(n=="t") out=out "\t"; else if(n=="r") out=out "\r";
            else if(n=="n") out=out "\n"; else out=out "\\"
          } else out=out c
        }
        return out
      }
      {
        print "id=" $1
        print "created_at=" $2
        print "skill=" $4
        print "skill_ref=" $5
        print "invocation=" decode($6)
        print "kind=" $7
        print "summary=" decode($8)
        print "incident=" decode($9)
        print "consequence=" decode($10)
        print "suggestion=" decode($11)
        print "status=" $13
        if($13=="resolved") { print "disposition=" $14; print "resolution=" decode($15); print "result_ref=" decode($16) }
        print "--"
      }
    ' "$QUERY_SELECTED"
  fi
  printf 'count=%s\n' "$count"
  rm -f -- "$QUERY_ROWS" "$QUERY_SORTED" "$QUERY_SELECTED"
  QUERY_ROWS=""; QUERY_SORTED=""; QUERY_SELECTED=""
}

cmd_resolve() {
  local ids=() dispositions=() resolutions=() refs=() actions=()
  local id disposition resolution result_ref encoded_resolution encoded_ref prior j found status old_disposition old_resolution old_ref
  [ "$#" -gt 0 ] || usage
  while [ "$#" -gt 0 ]; do
    [ "$1" = --entry ] && [ "$#" -ge 5 ] || usage
    id="$2"; disposition="$3"; resolution="$4"; result_ref="$5"
    valid_feedback_id "$id" || reason invalid-id 'check-entry'
    case "$disposition" in applied|preserved|already-addressed|rejected|stale|duplicate) ;; *) reason invalid-disposition 'check-entry' ;; esac
    valid_raw_text "$resolution" 2000 || reason invalid-resolution 'check-entry'
    valid_result_ref "$result_ref" || reason invalid-result-ref 'check-entry'
    case "$disposition" in
      applied|preserved|already-addressed|duplicate) [ -n "$result_ref" ] || reason result-ref-required 'check-entry' ;;
    esac
    for prior in "${ids[@]+"${ids[@]}"}"; do [ "$prior" != "$id" ] || reason duplicate-id 'deduplicate-request'; done
    ids+=("$id"); dispositions+=("$disposition"); resolutions+=("$resolution"); refs+=("$result_ref")
    shift 5
  done

  resolve_paths
  check_prefix
  [ -e "$DATA_FILE" ] || reason feedback-not-initialized 'run-setup-or-capture'
  acquire_lock no
  validate_file "$DATA_FILE"
  REQUEST_FILE="$(mktemp "$DATA_DIR/.feedback.resolve.XXXXXX")" || reason write-failed retry
  chmod 600 "$REQUEST_FILE"
  j=0
  while [ "$j" -lt "${#ids[@]}" ]; do
    id="${ids[$j]}"; disposition="${dispositions[$j]}"
    encoded_resolution="$(encode_text "${resolutions[$j]}")"; encoded_ref="$(encode_text "${refs[$j]}")"
    found="$(LC_ALL=C awk -F '\t' -v id="$id" 'NR>1 && $1==id{print $13 "\t" $14 "\t" $15 "\t" $16; found=1} END{if(!found)exit 1}' "$DATA_FILE")" || reason missing-id 'refresh-query'
    IFS=$'\t' read -r status old_disposition old_resolution old_ref <<< "$found"
    if [ "$status" = open ]; then
      actions+=(resolved)
    elif [ "$status" = resolved ] && [ "$old_disposition" = "$disposition" ] && [ "$old_resolution" = "$encoded_resolution" ] && [ "$old_ref" = "$encoded_ref" ]; then
      actions+=(unchanged)
    else
      reason conflicting-resolution 'refresh-query'
    fi
    printf '%s\t%s\t%s\t%s\n' "$id" "$disposition" "$encoded_resolution" "$encoded_ref" >> "$REQUEST_FILE"
    j=$((j + 1))
  done

  local change_count=0 now
  for prior in "${actions[@]}"; do [ "$prior" != resolved ] || change_count=$((change_count + 1)); done
  if [ "$change_count" -gt 0 ]; then
    now="$(current_utc)"
    TEMP_FILE="$(mktemp "$DATA_DIR/.feedback.tsv.tmp.XXXXXX")" || reason write-failed retry
    chmod 600 "$TEMP_FILE"
    LC_ALL=C awk -F '\t' -v OFS='\t' -v now="$now" '
      NR==FNR { disposition[$1]=$2; resolution[$1]=$3; result[$1]=$4; next }
      FNR==1 { print; next }
      $1 in disposition && $13=="open" {
        $3=now; $13="resolved"; $14=disposition[$1]; $15=resolution[$1]; $16=result[$1]
      }
      { print }
    ' "$REQUEST_FILE" "$DATA_FILE" > "$TEMP_FILE"
    validate_file "$TEMP_FILE"
    if [ -n "${SKILL_FEEDBACK_TEST_BEFORE_RENAME:-}" ]; then
      [ -x "$SKILL_FEEDBACK_TEST_BEFORE_RENAME" ] || reason test-hook-invalid retry
      "$SKILL_FEEDBACK_TEST_BEFORE_RENAME" "$DATA_FILE" "$TEMP_FILE"
    fi
    check_prefix
    validate_file "$DATA_FILE"
    mv -- "$TEMP_FILE" "$DATA_FILE"
    TEMP_FILE=""
  fi
  rm -f -- "$REQUEST_FILE"; REQUEST_FILE=""
  j=0
  while [ "$j" -lt "${#ids[@]}" ]; do
    printf '%s=%s\n' "${actions[$j]}" "${ids[$j]}"
    j=$((j + 1))
  done
  printf 'count=%s\n' "${#ids[@]}"
}

command="${1:-}"
[ -n "$command" ] || usage
shift
case "$command" in
  describe) cmd_describe "$@" ;;
  init) cmd_init "$@" ;;
  capture) cmd_capture "$@" ;;
  query) cmd_query "$@" ;;
  resolve) cmd_resolve "$@" ;;
  *) usage ;;
esac
