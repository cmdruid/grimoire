#!/usr/bin/env bash
set -euo pipefail

umask 077
HEADER=$'id\tcreated_at\tupdated_at\torigin\tsubject_type\tsubject\tsubject_ref\tinvocation\tkind\tsummary\tstatement\tincident\tconsequence\tsuggestion\tredacted\tproject_ref\tstatus\tdisposition\tresolution\tresult_ref'
DATA_DIR="" DATA_FILE="" LOCK_DIR="" LOCK_OWNED=no TEMP_FILE=""
QUERY_ROWS="" QUERY_SORTED="" QUERY_SELECTED=""
MUTATION_STATE=idle MUTATION_KIND="" MUTATION_ID="" MUTATION_DISPOSITION=""
MUTATION_RESOLUTION="" MUTATION_REF="" MUTATION_SUCCESS_OUTPUT=""

# References are stored encoded, so direct arguments are encoded and checked
# by this same byte-oriented grammar before any row reaches the store.
REFERENCE_AWK='
  function decoded_len(s, i,c,n,nextc){n=0;for(i=1;i<=length(s);i++){c=substr(s,i,1);if(c~/[[:cntrl:]]/)return -1;if(c=="\\"){if(i==length(s))return -1;nextc=substr(s,i+1,1);if(nextc!="\\"&&nextc!="t"&&nextc!="r"&&nextc!="n")return -1;i++}n++}return n}
  function decoded_ref(s, i,c,nextc,out){out="";for(i=1;i<=length(s);i++){c=substr(s,i,1);if(c=="\\"){nextc=substr(s,++i,1);if(nextc=="t")out=out "\t";else if(nextc=="r")out=out "\r";else if(nextc=="n")out=out "\n";else out=out "\\"}else out=out c}return out}
  function ref_sep(c){return c=="/"||c=="\\"}
  function has_parent_segment(s, i,before,after){for(i=1;i<length(s);i++){if(substr(s,i,2)!="..")continue;before=i==1?"":substr(s,i-1,1);after=i+1==length(s)?"":substr(s,i+2,1);if((before==""||ref_sep(before))&&(after==""||ref_sep(after)))return 1}return 0}
  function safe_ref(s,limit, d,lower){
    if(decoded_len(s)<1||decoded_len(s)>limit)return 0
    d=decoded_ref(s);lower=tolower(d)
    if(index(d,"\t")||index(d,"\r")||index(d,"\n"))return 0
    if(substr(d,1,1)=="/"||substr(d,1,1)=="\\"||substr(d,1,1)=="~")return 0
    if(length(d)>=3&&substr(d,1,1)~/[A-Za-z]/&&substr(d,2,1)==":"&&ref_sep(substr(d,3,1)))return 0
    if(lower~/^file:/||has_parent_segment(d))return 0
    return 1
  }
'

reason(){ printf 'reason=%s action=%s\n' "$1" "$2" >&2; exit 2; }
usage(){ reason usage check-command; }

mutation_commit_visible(){
  [ -f "$DATA_FILE" ] && [ ! -L "$DATA_FILE" ] || return 1
  case "$MUTATION_KIND" in
    capture)
      LC_ALL=C awk -F '\t' -v id="$MUTATION_ID" \
        'NR>1&&$1==id&&$17=="open"{n++}END{exit n==1?0:1}' "$DATA_FILE" \
        >/dev/null 2>&1
      ;;
    close)
      LC_ALL=C awk -F '\t' -v id="$MUTATION_ID" -v d="$MUTATION_DISPOSITION" \
        -v r="$MUTATION_RESOLUTION" -v ref="$MUTATION_REF" \
        'NR>1&&$1==id&&$17=="closed"&&$18==d&&$19==r&&$20==ref{n++}END{exit n==1?0:1}' \
        "$DATA_FILE" >/dev/null 2>&1
      ;;
    *) return 1;;
  esac
}

emit_mutation_success(){ printf '%s' "$MUTATION_SUCCESS_OUTPUT"; }

cleanup(){
  [ -z "$QUERY_ROWS" ] || rm -f -- "$QUERY_ROWS" >/dev/null 2>&1 || true
  [ -z "$QUERY_SORTED" ] || rm -f -- "$QUERY_SORTED" >/dev/null 2>&1 || true
  [ -z "$QUERY_SELECTED" ] || rm -f -- "$QUERY_SELECTED" >/dev/null 2>&1 || true
  if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ] && [ ! -L "$TEMP_FILE" ]; then
    rm -f -- "$TEMP_FILE" >/dev/null 2>&1 || true
  fi
  if [ "$LOCK_OWNED" = yes ] && [ -d "$LOCK_DIR" ] && [ ! -L "$LOCK_DIR" ]; then
    rm -f -- "$LOCK_DIR/pid" >/dev/null 2>&1 || true
    rmdir -- "$LOCK_DIR" 2>/dev/null || true
  fi
}
on_signal(){
  trap - HUP INT TERM
  case "$MUTATION_STATE" in
    committed) emit_mutation_success; exit 0;;
    renaming)
      if mutation_commit_visible; then emit_mutation_success; exit 0; fi
      reason interrupted inspect-store
      ;;
    *) reason interrupted retry;;
  esac
}
trap cleanup EXIT
trap on_signal HUP INT TERM

make_temp(){ mktemp "$1" 2>/dev/null || reason write-failed retry; }
set_private_mode(){ chmod "$1" "$2" >/dev/null 2>&1 || reason write-failed retry; }
copy_for_write(){ cp -- "$1" "$2" >/dev/null 2>&1 || reason write-failed retry; }
rename_for_write(){ mv -- "$1" "$2" >/dev/null 2>&1 || reason write-failed retry; }

commit_mutation(){
  MUTATION_STATE=renaming
  if ! mv -- "$TEMP_FILE" "$DATA_FILE" >/dev/null 2>&1; then
    MUTATION_STATE=idle
    reason write-failed retry
  fi
  MUTATION_STATE=committed
  TEMP_FILE=""
}

finish_mutation(){
  trap '' HUP INT TERM
  emit_mutation_success
  MUTATION_STATE=idle
}

resolve_paths(){
  case "${HOME:-}" in /*) ;; *) reason invalid-home set-absolute-HOME;; esac
  [ -d "$HOME" ] || reason invalid-home set-existing-HOME
  local physical
  physical="$(CDPATH='' cd -P -- "$HOME" 2>/dev/null && pwd -P)" ||
    reason invalid-home set-resolvable-HOME
  DATA_DIR="$physical/.agents/skilldata/agent-feedback"
  DATA_FILE="$DATA_DIR/feedback.tsv"
  LOCK_DIR="$DATA_FILE.lock"
}

check_dir_entry(){
  local path="$1"
  [ ! -L "$path" ] || reason unsafe-path remove-symlink
  if [ -e "$path" ]; then [ -d "$path" ] || reason incompatible-path remove-nondirectory; fi
}

check_prefix(){
  local home agents skilldata
  home="${DATA_DIR%/.agents/skilldata/agent-feedback}"
  agents="$home/.agents"; skilldata="$agents/skilldata"
  check_dir_entry "$agents"; check_dir_entry "$skilldata"; check_dir_entry "$DATA_DIR"
  [ ! -L "$DATA_FILE" ] || reason unsafe-path remove-symlink
  if [ -e "$DATA_FILE" ]; then [ -f "$DATA_FILE" ] || reason incompatible-path remove-nonregular-file; fi
  [ ! -L "$LOCK_DIR" ] || reason unsafe-path remove-symlink
  if [ -e "$LOCK_DIR" ] && [ ! -d "$LOCK_DIR" ]; then reason incompatible-path remove-invalid-lock; fi
}

ensure_layout(){
  local home agents skilldata
  home="${DATA_DIR%/.agents/skilldata/agent-feedback}"
  agents="$home/.agents"; skilldata="$agents/skilldata"
  check_prefix
  if [ ! -d "$agents" ]; then mkdir -m 700 -- "$agents" 2>/dev/null || reason write-failed inspect-parent; fi
  check_prefix
  if [ ! -d "$skilldata" ]; then mkdir -m 700 -- "$skilldata" 2>/dev/null || reason write-failed inspect-parent; fi
  check_prefix
  if [ ! -d "$DATA_DIR" ]; then mkdir -m 700 -- "$DATA_DIR" 2>/dev/null || reason write-failed inspect-parent; fi
  check_prefix
}

try_remove_stale_lock(){
  [ -d "$LOCK_DIR" ] && [ ! -L "$LOCK_DIR" ] || return 1
  [ -f "$LOCK_DIR/pid" ] && [ ! -L "$LOCK_DIR/pid" ] || return 1
  local entries pid pid_lines last
  entries="$(find "$LOCK_DIR" -mindepth 1 -maxdepth 1 -print 2>/dev/null | wc -l | tr -d '[:space:]')" || return 1
  [ "$entries" = 1 ] || return 1
  pid_lines="$(wc -l <"$LOCK_DIR/pid" | tr -d '[:space:]')" || return 1
  last="$(tail -c 1 "$LOCK_DIR/pid" 2>/dev/null | od -An -tuC | tr -d '[:space:]')" || return 1
  [ "$pid_lines" = 1 ] && [ "$last" = 10 ] || return 1
  IFS= read -r pid <"$LOCK_DIR/pid" || return 1
  case "$pid" in ''|*[!0-9]*) return 1;; esac
  if ps -p "$pid" >/dev/null 2>&1; then return 1; fi
  rm -f -- "$LOCK_DIR/pid" >/dev/null 2>&1 || return 1
  rmdir -- "$LOCK_DIR" >/dev/null 2>&1 || return 1
}

acquire_lock(){
  local allow_stale="${1:-no}" attempts=0
  while [ "$attempts" -lt 50 ]; do
    check_prefix
    if mkdir -m 700 -- "$LOCK_DIR" 2>/dev/null; then
      LOCK_OWNED=yes
      { printf '%s\n' "$$" >"$LOCK_DIR/pid"; } 2>/dev/null || reason write-failed retry
      set_private_mode 600 "$LOCK_DIR/pid"
      return 0
    fi
    attempts=$((attempts + 1)); sleep 0.1 2>/dev/null || reason interrupted retry
  done
  if [ "$allow_stale" = yes ] && try_remove_stale_lock; then
    check_prefix
    if mkdir -m 700 -- "$LOCK_DIR" 2>/dev/null; then
      LOCK_OWNED=yes
      { printf '%s\n' "$$" >"$LOCK_DIR/pid"; } 2>/dev/null || reason write-failed retry
      set_private_mode 600 "$LOCK_DIR/pid"
      return 0
    fi
  fi
  reason feedback-busy retry
}

require_iconv(){ command -v iconv >/dev/null 2>&1 || reason validator-unavailable install-iconv; }
valid_utf8_value(){ require_iconv; LC_ALL=C printf '%s' "$1" | LC_ALL=C iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; }
validate_utf8_file(){ require_iconv; LC_ALL=C iconv -f UTF-8 -t UTF-8 "$1" >/dev/null 2>&1 || reason invalid-store repair-manually; }
byte_length(){ LC_ALL=C printf '%s' "$1" | wc -c | tr -d '[:space:]'; }

valid_utc_timestamp(){
  local value="$1" digits year month day hour minute second max_day
  [ "${#value}" -eq 20 ] || return 1
  [ "${value:4:1}" = - ] && [ "${value:7:1}" = - ] && [ "${value:10:1}" = T ] &&
    [ "${value:13:1}" = : ] && [ "${value:16:1}" = : ] && [ "${value:19:1}" = Z ] || return 1
  digits="${value:0:4}${value:5:2}${value:8:2}${value:11:2}${value:14:2}${value:17:2}"
  case "$digits" in *[!0-9]*) return 1;; esac
  year=$((10#${value:0:4})); month=$((10#${value:5:2})); day=$((10#${value:8:2}))
  hour=$((10#${value:11:2})); minute=$((10#${value:14:2})); second=$((10#${value:17:2}))
  [ "$month" -ge 1 ] && [ "$month" -le 12 ] || return 1
  case "$month" in
    2) max_day=28; if [ $((year % 400)) -eq 0 ] || { [ $((year % 4)) -eq 0 ] && [ $((year % 100)) -ne 0 ]; }; then max_day=29; fi;;
    4|6|9|11) max_day=30;;
    *) max_day=31;;
  esac
  [ "$day" -ge 1 ] && [ "$day" -le "$max_day" ] && [ "$hour" -le 23 ] &&
    [ "$minute" -le 59 ] && [ "$second" -le 60 ] || return 1
  if [ "$second" -eq 60 ]; then
    [ "$hour" -eq 23 ] && [ "$minute" -eq 59 ] && [ "$day" -eq "$max_day" ] &&
      { [ "$month" -eq 6 ] || [ "$month" -eq 12 ]; } || return 1
  fi
}

current_utc(){
  local now
  if [ -n "${AGENT_FEEDBACK_TEST_UTC_NOW:-}" ]; then
    now="$AGENT_FEEDBACK_TEST_UTC_NOW"; valid_utc_timestamp "$now" || reason test-hook-invalid retry
  else
    now="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)" || reason clock-unavailable retry
  fi
  printf '%s\n' "$now"
}

valid_slug(){ case "$1" in ''|*[!a-z0-9-]*|-*|*-) return 1;; *) return 0;; esac; }
valid_hex(){ local value="$1" length="$2"; [ "${#value}" -eq "$length" ] || return 1; case "$value" in *[!0-9a-f]*) return 1;; esac; }

valid_raw_text(){
  local value="$1" limit="$2" stripped
  [ -n "$value" ] || return 1
  valid_utf8_value "$value" || return 1
  [ "$(byte_length "$value")" -le "$limit" ] || return 1
  stripped="$(LC_ALL=C printf '%s' "$value" | tr -d '\t\r\n')"
  ! LC_ALL=C printf '%s' "$stripped" | grep -q '[[:cntrl:]]'
}
valid_optional_text(){ [ -z "$1" ] || valid_raw_text "$1" "$2"; }

valid_reference(){
  local value="$1" limit="$2" stripped encoded
  valid_raw_text "$value" "$limit" || return 1
  stripped="$(LC_ALL=C printf '%s' "$value" | tr -d '\t\r\n')"
  ! LC_ALL=C printf '%s' "$stripped" | grep -q '[[:cntrl:]]' || return 1
  encoded="$(encode_text "$value")"
  LC_ALL=C printf '%s\n' "$encoded" | LC_ALL=C awk -v limit="$limit" "$REFERENCE_AWK
    { exit safe_ref(\$0,limit) ? 0 : 1 }
  "
}
valid_subject_ref(){ [ "$1" = unknown ] || valid_reference "$1" 512; }
valid_project_ref(){ [ -z "$1" ] && return 0; case "$1" in local-sha256:*) valid_hex "${1#local-sha256:}" 16;; *) return 1;; esac; }

valid_feedback_id(){
  local value="$1" date_part time_part hex_part timestamp
  [ "${#value}" -eq 28 ] && [ "${value#AF-}" != "$value" ] || return 1
  date_part="${value:3:8}"; time_part="${value:12:6}"; hex_part="${value:20:8}"
  [ "${value:11:1}" = T ] && [ "${value:18:1}" = Z ] && [ "${value:19:1}" = - ] || return 1
  case "$date_part$time_part" in *[!0-9]*) return 1;; esac
  valid_hex "$hex_part" 8 || return 1
  timestamp="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}T${time_part:0:2}:${time_part:2:2}:${time_part:4:2}Z"
  valid_utc_timestamp "$timestamp"
}

encode_text(){
  local value="$1"
  value="${value//\\/\\\\}"; value="${value//$'\t'/\\t}"; value="${value//$'\r'/\\r}"; value="${value//$'\n'/\\n}"
  printf '%s' "$value"
}

validate_file(){
  local file="$1" last
  [ -f "$file" ] && [ ! -L "$file" ] || reason invalid-store run-setup
  validate_utf8_file "$file"
  last="$({ tail -c 1 "$file" | od -An -tuC | tr -d '[:space:]'; } 2>/dev/null)" ||
    reason invalid-store repair-manually
  [ "$last" = 10 ] || reason invalid-store repair-manually
  if { LC_ALL=C tr -d '\t\n' <"$file" | LC_ALL=C grep -q '[[:cntrl:]]'; } 2>/dev/null; then reason invalid-store repair-manually; fi
  LC_ALL=C awk -F '\t' -v header="$HEADER" '
    function hex(s,n){return length(s)==n && s !~ /[^0-9a-f]/}
    function digits(s){return s!="" && s !~ /[^0-9]/}
    function leap(y){return (y%4==0 && y%100!=0)||y%400==0}
    function mdays(y,m){if(m==2)return leap(y)?29:28;if(m==4||m==6||m==9||m==11)return 30;return 31}
    function parts(y,m,d,h,n,s){
      if(!digits(y)||!digits(m)||!digits(d)||!digits(h)||!digits(n)||!digits(s))return 0
      y+=0;m+=0;d+=0;h+=0;n+=0;s+=0
      if(!(m>=1&&m<=12&&d>=1&&d<=mdays(y,m)&&h<=23&&n<=59&&s<=60))return 0
      return s!=60||(h==23&&n==59&&d==mdays(y,m)&&(m==6||m==12))
    }
    function timestamp(s){return length(s)==20&&substr(s,5,1)=="-"&&substr(s,8,1)=="-"&&substr(s,11,1)=="T"&&substr(s,14,1)==":"&&substr(s,17,1)==":"&&substr(s,20,1)=="Z"&&parts(substr(s,1,4),substr(s,6,2),substr(s,9,2),substr(s,12,2),substr(s,15,2),substr(s,18,2))}
    function basic(s){return length(s)==16&&substr(s,9,1)=="T"&&substr(s,16,1)=="Z"&&parts(substr(s,1,4),substr(s,5,2),substr(s,7,2),substr(s,10,2),substr(s,12,2),substr(s,14,2))}
    function feedback_id(s){return length(s)==28&&substr(s,1,3)=="AF-"&&substr(s,12,1)=="T"&&substr(s,19,1)=="Z"&&substr(s,20,1)=="-"&&basic(substr(s,4,16))&&hex(substr(s,21),8)}
    function slug(s){return s~/^[a-z0-9][a-z0-9-]*[a-z0-9]$/||s~/^[a-z0-9]$/}
    '"$REFERENCE_AWK"'
    NR==1{if($0!=header||NF!=20)exit 10;next}
    {
      if(NF!=20||length($0)+1>32768||!feedback_id($1)||seen[$1]++)exit 11
      if(!timestamp($2)||!timestamp($3)||($4!="agent"&&$4!="human"))exit 12
      if($5!="skill"&&$5!="agent"&&$5!="harness"&&$5!="tool"&&$5!="workflow")exit 13
      if(!slug($6)||length($6)>120||($7!="unknown"&&!safe_ref($7,512))||decoded_len($8)<1||decoded_len($8)>240)exit 14
      if($9!="friction"&&$9!="gap"&&$9!="win"&&$9!="request")exit 15
      if(decoded_len($10)<1||decoded_len($10)>240||decoded_len($11)<1||decoded_len($11)>4000)exit 16
      d12=decoded_len($12);d13=decoded_len($13);d14=decoded_len($14)
      if(d12<0||d13<0||d14<0||d12>2000||d13>2000||d14>2000)exit 17
      if($4=="agent"&&(decoded_len($12)<1||decoded_len($13)<1||decoded_len($14)<1))exit 18
      if($15!="yes"&&$15!="no")exit 19
      if($16!=""&&!(substr($16,1,13)=="local-sha256:"&&hex(substr($16,14),16)))exit 20
      if($17=="open") {if($2!=$3||$18!=""||$19!=""||$20!="")exit 21}
      else if($17=="closed") {
        if($18!="addressed"&&$18!="preserved"&&$18!="declined"&&$18!="stale"&&$18!="duplicate")exit 22
        if(decoded_len($19)<1||decoded_len($19)>2000)exit 23
        if($20!=""&&!safe_ref($20,2000))exit 24
        if(($18=="addressed"||$18=="preserved"||$18=="duplicate")&&$20=="")exit 25
      } else exit 26
    }
    END{if(NR<1)exit 27}
  ' "$file" >/dev/null 2>&1 || reason invalid-store repair-manually
}

ensure_file_locked(){
  check_prefix
  if [ ! -e "$DATA_FILE" ]; then
    TEMP_FILE="$(make_temp "$DATA_DIR/.agent-feedback.tsv.tmp.XXXXXX")"
    set_private_mode 600 "$TEMP_FILE"
    { printf '%s\n' "$HEADER" >"$TEMP_FILE"; } 2>/dev/null || reason write-failed retry
    validate_file "$TEMP_FILE"
    check_prefix; [ ! -e "$DATA_FILE" ] || reason concurrent-change retry
    rename_for_write "$TEMP_FILE" "$DATA_FILE"; TEMP_FILE=""
  fi
  validate_file "$DATA_FILE"
}

random_hex(){
  if [ -n "${AGENT_FEEDBACK_TEST_RANDOM_SOURCE:-}" ]; then
    [ -x "$AGENT_FEEDBACK_TEST_RANDOM_SOURCE" ] || reason random-unavailable retry
    "$AGENT_FEEDBACK_TEST_RANDOM_SOURCE" 2>/dev/null || reason random-unavailable retry
  else
    { od -An -N4 -tx1 /dev/urandom | tr -d ' \n'; } 2>/dev/null || reason random-unavailable retry
  fi
}

cmd_describe(){
  [ "$#" -eq 0 ] || usage
  printf '%s\n' 'schema=agent-feedback@1' 'store=.agents/skilldata/agent-feedback/feedback.tsv' 'commands=describe,init,capture,query,close'
}

cmd_init(){
  [ "$#" -eq 0 ] || usage
  resolve_paths; ensure_layout; acquire_lock yes; ensure_file_locked
  set_private_mode 700 "$DATA_DIR"; set_private_mode 600 "$DATA_FILE"; printf 'status=ready\n'
}

cmd_capture(){
  local origin="" subject_type="" subject="" subject_ref="" invocation="" kind="" summary="" statement=""
  local incident="" consequence="" suggestion="" redacted="" project_ref=""
  local so=no st=no ss=no sr=no si=no sk=no sm=no sw=no sn=no sc=no sg=no sd=no sp=no
  while [ "$#" -gt 0 ]; do
    [ "$#" -ge 2 ] || usage
    case "$1" in
      --origin) [ "$so" = no ] || usage; origin="$2"; so=yes;;
      --subject-type) [ "$st" = no ] || usage; subject_type="$2"; st=yes;;
      --subject) [ "$ss" = no ] || usage; subject="$2"; ss=yes;;
      --subject-ref) [ "$sr" = no ] || usage; subject_ref="$2"; sr=yes;;
      --invocation) [ "$si" = no ] || usage; invocation="$2"; si=yes;;
      --kind) [ "$sk" = no ] || usage; kind="$2"; sk=yes;;
      --summary) [ "$sm" = no ] || usage; summary="$2"; sm=yes;;
      --statement) [ "$sw" = no ] || usage; statement="$2"; sw=yes;;
      --incident) [ "$sn" = no ] || usage; incident="$2"; sn=yes;;
      --consequence) [ "$sc" = no ] || usage; consequence="$2"; sc=yes;;
      --suggestion) [ "$sg" = no ] || usage; suggestion="$2"; sg=yes;;
      --redacted) [ "$sd" = no ] || usage; redacted="$2"; sd=yes;;
      --project-ref) [ "$sp" = no ] || usage; project_ref="$2"; sp=yes;;
      *) usage;;
    esac
    shift 2
  done
  [ "$so$st$ss$sr$si$sk$sm$sw$sn$sc$sg$sd" = yesyesyesyesyesyesyesyesyesyesyesyes ] || usage
  case "$origin" in agent|human) ;; *) reason invalid-origin use-declared-origin;; esac
  case "$subject_type" in skill|agent|harness|tool|workflow) ;; *) reason invalid-subject-type use-declared-subject-type;; esac
  valid_slug "$subject" && [ "$(byte_length "$subject")" -le 120 ] || reason invalid-subject use-lowercase-kebab-case
  valid_subject_ref "$subject_ref" || reason invalid-subject-ref recompute-reference
  valid_raw_text "$invocation" 240 || reason invalid-invocation provide-short-invocation
  case "$kind" in friction|gap|win|request) ;; *) reason invalid-kind use-declared-kind;; esac
  valid_raw_text "$summary" 240 || reason invalid-summary shorten-summary
  valid_raw_text "$statement" 4000 || reason invalid-statement revise-feedback
  valid_optional_text "$incident" 2000 || reason invalid-incident revise-feedback
  valid_optional_text "$consequence" 2000 || reason invalid-consequence revise-feedback
  valid_optional_text "$suggestion" 2000 || reason invalid-suggestion revise-feedback
  if [ "$origin" = agent ]; then
    [ -n "$incident" ] && [ -n "$consequence" ] && [ -n "$suggestion" ] || reason incomplete-agent-feedback revise-feedback
  fi
  case "$redacted" in yes|no) ;; *) reason invalid-redacted use-yes-or-no;; esac
  valid_project_ref "$project_ref" || reason invalid-project-ref recompute-reference

  local now id_time hex id collision_attempts=0 collision_free=no collision
  local e_ref e_inv e_summary e_statement e_incident e_consequence e_suggestion
  e_ref="$(encode_text "$subject_ref")"; e_inv="$(encode_text "$invocation")"; e_summary="$(encode_text "$summary")"
  e_statement="$(encode_text "$statement")"; e_incident="$(encode_text "$incident")"
  e_consequence="$(encode_text "$consequence")"; e_suggestion="$(encode_text "$suggestion")"
  resolve_paths; ensure_layout; acquire_lock no; ensure_file_locked
  now="$(current_utc)"; id_time="${now//-/}"; id_time="${id_time//:/}"
  while [ "$collision_attempts" -lt 100 ]; do
    collision_attempts=$((collision_attempts + 1))
    hex="$(random_hex)"; valid_hex "$hex" 8 || reason random-unavailable retry; id="AF-$id_time-$hex"
    collision="$(LC_ALL=C awk -F '\t' -v id="$id" 'NR>1&&$1==id{found=1}END{print found?"yes":"no"}' "$DATA_FILE" 2>/dev/null)" ||
      reason read-failed retry
    if [ "$collision" = no ]; then
      collision_free=yes
      break
    fi
  done
  [ "$collision_free" = yes ] || reason id-collision retry
  TEMP_FILE="$(make_temp "$DATA_DIR/.agent-feedback.tsv.tmp.XXXXXX")"
  set_private_mode 600 "$TEMP_FILE"; copy_for_write "$DATA_FILE" "$TEMP_FILE"
  { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\topen\t\t\t\n' \
    "$id" "$now" "$now" "$origin" "$subject_type" "$subject" "$e_ref" "$e_inv" "$kind" "$e_summary" \
    "$e_statement" "$e_incident" "$e_consequence" "$e_suggestion" "$redacted" "$project_ref" >>"$TEMP_FILE"; } 2>/dev/null || reason write-failed retry
  validate_file "$TEMP_FILE"
  if [ -n "${AGENT_FEEDBACK_TEST_BEFORE_RENAME:-}" ]; then
    [ -x "$AGENT_FEEDBACK_TEST_BEFORE_RENAME" ] || reason test-hook-invalid retry
    "$AGENT_FEEDBACK_TEST_BEFORE_RENAME" "$DATA_FILE" "$TEMP_FILE" 2>/dev/null || reason interrupted retry
  fi
  check_prefix; validate_file "$DATA_FILE"
  MUTATION_KIND=capture; MUTATION_ID="$id"
  printf -v MUTATION_SUCCESS_OUTPUT 'captured=%s\ncount=1\nredacted=%s\n' "$id" "$redacted"
  commit_mutation
  finish_mutation
}

cmd_query(){
  local origin="" subject_type="" subject="" status=open limit=20 order=newest format=human include_project=no
  local so=no st=no ss=no sx=no sl=no sr=no sf=no si=no
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --origin|--subject-type|--subject|--status|--limit|--order|--format)
        [ "$#" -ge 2 ] || usage
        case "$1" in
          --origin) [ "$so" = no ] || usage; origin="$2"; so=yes;;
          --subject-type) [ "$st" = no ] || usage; subject_type="$2"; st=yes;;
          --subject) [ "$ss" = no ] || usage; subject="$2"; ss=yes;;
          --status) [ "$sx" = no ] || usage; status="$2"; sx=yes;;
          --limit) [ "$sl" = no ] || usage; limit="$2"; sl=yes;;
          --order) [ "$sr" = no ] || usage; order="$2"; sr=yes;;
          --format) [ "$sf" = no ] || usage; format="$2"; sf=yes;;
        esac
        shift 2;;
      --include-project-ref) [ "$si" = no ] || usage; include_project=yes; si=yes; shift;;
      *) usage;;
    esac
  done
  if [ "$so" = yes ]; then case "$origin" in agent|human) ;; *) usage;; esac; fi
  if [ "$st" = yes ]; then case "$subject_type" in skill|agent|harness|tool|workflow) ;; *) usage;; esac; fi
  if [ "$ss" = yes ]; then
    valid_slug "$subject" && [ "$(byte_length "$subject")" -le 120 ] || usage
  fi
  case "$status" in open|closed) ;; *) usage;; esac
  case "$limit" in ''|*[!0-9]*) usage;; esac
  [ "$limit" -ge 1 ] && [ "$limit" -le 100 ] || usage
  case "$order" in newest|oldest) ;; *) usage;; esac
  case "$format" in human|tsv) ;; *) usage;; esac
  [ "$include_project" = no ] || [ "$format" = tsv ] || usage
  resolve_paths; check_prefix
  [ -e "$DATA_FILE" ] || reason feedback-not-initialized run-setup-or-capture
  validate_file "$DATA_FILE"
  QUERY_ROWS="$(make_temp "${TMPDIR:-/tmp}/agent-feedback-query.XXXXXX")"
  QUERY_SORTED="$(make_temp "${TMPDIR:-/tmp}/agent-feedback-sort.XXXXXX")"
  QUERY_SELECTED="$(make_temp "${TMPDIR:-/tmp}/agent-feedback-page.XXXXXX")"
  { LC_ALL=C awk -F '\t' -v o="$origin" -v t="$subject_type" -v s="$subject" -v x="$status" \
    'NR>1&&(o==""||$4==o)&&(t==""||$5==t)&&(s==""||$6==s)&&$17==x' "$DATA_FILE" >"$QUERY_ROWS"; } 2>/dev/null || reason read-failed retry
  if [ "$order" = newest ]; then
    { LC_ALL=C sort -t $'\t' -k2,2r -k1,1r "$QUERY_ROWS" >"$QUERY_SORTED"; } 2>/dev/null || reason read-failed retry
  else
    { LC_ALL=C sort -t $'\t' -k2,2 -k1,1 "$QUERY_ROWS" >"$QUERY_SORTED"; } 2>/dev/null || reason read-failed retry
  fi
  { head -n "$limit" "$QUERY_SORTED" >"$QUERY_SELECTED"; } 2>/dev/null || reason read-failed retry
  if [ "$format" = tsv ]; then
    printf '%s\n' "$HEADER"
    if [ "$include_project" = yes ]; then cat "$QUERY_SELECTED" 2>/dev/null || reason read-failed retry
    else LC_ALL=C awk -F '\t' 'BEGIN{OFS="\t"}{$16="";print}' "$QUERY_SELECTED" 2>/dev/null || reason read-failed retry; fi
  else
    LC_ALL=C awk -F '\t' '
      function decode(s,out,i,c,n){out="";for(i=1;i<=length(s);i++){c=substr(s,i,1);if(c=="\\"){n=substr(s,++i,1);if(n=="t")out=out"\t";else if(n=="r")out=out"\r";else if(n=="n")out=out"\n";else out=out"\\"}else out=out c}return out}
      {print "id="$1;print "created_at="$2;print "updated_at="$3;print "origin="$4;print "subject_type="$5;print "subject="$6;print "subject_ref="decode($7);print "invocation="decode($8);print "kind="$9;print "summary="decode($10);print "statement="decode($11);print "incident="decode($12);print "consequence="decode($13);print "suggestion="decode($14);print "redacted="$15;print "status="$17;print "disposition="$18;print "resolution="decode($19);print "result_ref="decode($20);print "--"}
    ' "$QUERY_SELECTED" 2>/dev/null || reason read-failed retry
  fi
  rm -f -- "$QUERY_ROWS" "$QUERY_SORTED" "$QUERY_SELECTED" >/dev/null 2>&1 || reason cleanup-failed retry
  QUERY_ROWS=""; QUERY_SORTED=""; QUERY_SELECTED=""
}

cmd_close(){
  local id="" disposition="" resolution="" result_ref=""
  local si=no sd=no sr=no sf=no
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --id|--as|--reason|--result-ref)
        [ "$#" -ge 2 ] || usage
        case "$1" in
          --id) [ "$si" = no ] || usage; id="$2"; si=yes;;
          --as) [ "$sd" = no ] || usage; disposition="$2"; sd=yes;;
          --reason) [ "$sr" = no ] || usage; resolution="$2"; sr=yes;;
          --result-ref) [ "$sf" = no ] || usage; result_ref="$2"; sf=yes;;
        esac
        shift 2;;
      *) usage;;
    esac
  done
  [ "$si$sd$sr" = yesyesyes ] || usage
  valid_feedback_id "$id" || reason invalid-id check-entry
  case "$disposition" in addressed|preserved|declined|stale|duplicate) ;; *) reason invalid-disposition check-entry;; esac
  valid_raw_text "$resolution" 2000 || reason invalid-resolution check-entry
  [ "$sf" = no ] || valid_reference "$result_ref" 2000 || reason invalid-result-ref check-entry
  case "$disposition" in addressed|preserved|duplicate) [ -n "$result_ref" ] || reason result-ref-required check-entry;; esac
  local encoded_resolution encoded_ref found status old_disposition old_resolution old_ref now action
  encoded_resolution="$(encode_text "$resolution")"; encoded_ref="$(encode_text "$result_ref")"
  resolve_paths; check_prefix; [ -e "$DATA_FILE" ] || reason feedback-not-initialized run-setup-or-capture
  acquire_lock no; validate_file "$DATA_FILE"
  found="$(LC_ALL=C awk -F '\t' -v id="$id" 'NR>1&&$1==id{print $17"\t"$18"\t"$19"\t"$20}' "$DATA_FILE" 2>/dev/null)" ||
    reason read-failed retry
  [ -n "$found" ] || reason missing-id refresh-query
  IFS=$'\t' read -r status old_disposition old_resolution old_ref <<<"$found"
  if [ "$status" = open ]; then action=closed
  elif [ "$status" = closed ] && [ "$old_disposition" = "$disposition" ] && [ "$old_resolution" = "$encoded_resolution" ] && [ "$old_ref" = "$encoded_ref" ]; then action=unchanged
  else reason conflicting-close refresh-query; fi
  if [ "$action" = closed ]; then
    now="$(current_utc)"; TEMP_FILE="$(make_temp "$DATA_DIR/.agent-feedback.tsv.tmp.XXXXXX")"
    set_private_mode 600 "$TEMP_FILE"
    { LC_ALL=C awk -F '\t' -v OFS='\t' -v id="$id" -v now="$now" -v d="$disposition" -v r="$encoded_resolution" -v ref="$encoded_ref" \
      'NR==1{print;next}$1==id&&$17=="open"{$3=now;$17="closed";$18=d;$19=r;$20=ref}{print}' "$DATA_FILE" >"$TEMP_FILE"; } 2>/dev/null || reason write-failed retry
    validate_file "$TEMP_FILE"
    if [ -n "${AGENT_FEEDBACK_TEST_BEFORE_RENAME:-}" ]; then
      [ -x "$AGENT_FEEDBACK_TEST_BEFORE_RENAME" ] || reason test-hook-invalid retry
      "$AGENT_FEEDBACK_TEST_BEFORE_RENAME" "$DATA_FILE" "$TEMP_FILE" 2>/dev/null || reason interrupted retry
    fi
    check_prefix; validate_file "$DATA_FILE"
    MUTATION_KIND=close; MUTATION_ID="$id"; MUTATION_DISPOSITION="$disposition"
    MUTATION_RESOLUTION="$encoded_resolution"; MUTATION_REF="$encoded_ref"
    printf -v MUTATION_SUCCESS_OUTPUT 'closed=%s\ncount=1\n' "$id"
    commit_mutation
    finish_mutation
    return
  fi
  printf '%s=%s\ncount=1\n' "$action" "$id"
}

command="${1:-}"; [ -n "$command" ] || usage; shift
case "$command" in
  describe) cmd_describe "$@";;
  init) cmd_init "$@";;
  capture) cmd_capture "$@";;
  query) cmd_query "$@";;
  close) cmd_close "$@";;
  *) usage;;
esac
