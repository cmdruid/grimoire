#!/usr/bin/env bash
# trackers-anchor.sh — preview and apply Backlog's managed project debrief route.
set -euo pipefail

die(){ echo "trackers-anchor.sh: $*" >&2;exit 2;}
refuse(){ echo "reason=$1${2:+ detail=$2}" >&2;exit 2;}
usage(){ die 'usage: trackers-anchor.sh preview|apply --root <absolute-root> [--remove] [--confirmed --base-sha256 <digest-or-absent> --candidate-sha256 <digest>]';}

sha256_file(){
  if command -v shasum >/dev/null 2>&1;then shasum -a 256 "$1"|awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1;then sha256sum "$1"|awk '{print $1}'
  else refuse sha256-unavailable
  fi
}
valid_digest(){ [[ "$1" =~ ^[0-9a-f]{64}$ ]];}

command_name="${1:-}";[ -n "$command_name" ]||usage;shift
case "$command_name" in preview|apply);;*)usage;;esac
root='';remove=no;confirmed=no;base_arg='';candidate_arg=''
while [ $# -gt 0 ];do case "$1" in
  --root)[ $# -ge 2 ]||usage;root="$2";shift 2;;
  --remove)[ "$remove" = no ]||usage;remove=yes;shift;;
  --confirmed)[ "$command_name" = apply ]&&[ "$confirmed" = no ]||usage;confirmed=yes;shift;;
  --base-sha256)[ "$command_name" = apply ]&&[ -z "$base_arg" ]&&[ $# -ge 2 ]||usage;base_arg="$2";shift 2;;
  --candidate-sha256)[ "$command_name" = apply ]&&[ -z "$candidate_arg" ]&&[ $# -ge 2 ]||usage;candidate_arg="$2";shift 2;;
  *)usage;;esac;done
[ -n "$root" ]||usage
if [ "$command_name" = preview ];then
  [ "$confirmed" = no ]&&[ -z "$base_arg" ]&&[ -z "$candidate_arg" ]||usage
else
  [ "$confirmed" = yes ]&&[ -n "$base_arg" ]&&valid_digest "$candidate_arg"||refuse confirmation-required
  [ "$base_arg" = absent ]||valid_digest "$base_arg"||usage
fi
case "$root" in /*);;*)refuse root-not-absolute "$root";;esac
[ -d "$root" ]&&[ ! -L "$root" ]||refuse invalid-root "$root"
root="$(CDPATH='' cd -P "$root"&&pwd)"
git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null||true)";[ -n "$git_root" ]||refuse git-required
git_root="$(CDPATH='' cd -P "$git_root"&&pwd)";[ "$git_root" = "$root" ]||refuse root-not-git-top-level "$git_root"
[ -n "$(git -C "$root" branch --show-current)" ]||refuse detached-head

SKILL="$(CDPATH='' cd -P "$(dirname "$0")/.."&&pwd)"
ROUTE="$SKILL/templates/agents-route.md";LEGACY="$SKILL/templates/agents-pointer.md"
README_TEMPLATE="$SKILL/templates/trackers-readme-block.md";README_STATUS="$SKILL/scripts/tracker-readme-status.sh"
RUNTIME="$SKILL/scripts/tracker-runtime-check.sh";PROVIDER_SOURCE="$SKILL/scripts/trackers.sh"
stamp=''
if [ "$remove" = no ];then
  for resource in "$ROUTE" "$LEGACY" "$README_TEMPLATE" "$PROVIDER_SOURCE";do [ -f "$resource" ]&&[ ! -L "$resource" ]||die 'package resources unavailable';done
  [ -x "$README_STATUS" ]&&[ -x "$RUNTIME" ]||die 'package resources unavailable'
  ROUTE_BEGIN='<!-- skill:backlog BEGIN built-against:__BUILT_AGAINST__ -->';ROUTE_END='<!-- skill:backlog END -->'
  [ "$(head -n1 "$ROUTE")" = "$ROUTE_BEGIN" ]&&[ "$(tail -n1 "$ROUTE")" = "$ROUTE_END" ]&&
    [ "$(grep -cF '__BUILT_AGAINST__' "$ROUTE")" -eq 1 ]&&[ "$(grep -cF '<!-- skill:backlog BEGIN' "$ROUTE")" -eq 1 ]&&
    [ "$(grep -cFx "$ROUTE_END" "$ROUTE")" -eq 1 ]||die 'invalid route template'
  stamp="$(git -C "$SKILL" log -1 --format=%h -- . 2>/dev/null||true)";[ -n "$stamp" ]||stamp='unversioned'
fi
HEADING='## Skill routes (self-registered)';BEGIN_PREFIX='<!-- skill:backlog BEGIN built-against:';END_MARK='<!-- skill:backlog END -->'
target="$root/AGENTS.md";layer="$root/.trackers";readme="$layer/README.md"

validate_target(){
  [ ! -L "$target" ]||refuse invalid-target AGENTS.md
  if [ -e "$target" ];then [ -f "$target" ]&&[ -r "$target" ]&&[ -w "$target" ]||refuse invalid-target AGENTS.md;fi
}
current_identity(){ if [ -f "$target" ];then sha256_file "$target";else printf 'absent\n';fi;}
fact(){ printf '%s\n' "$1"|sed -n "s/^$2=//p"|head -n1;}
validate_layer(){
  runtime_facts="$($RUNTIME --root "$root")"
  provider="$(fact "$runtime_facts" provider)"
  [ "$provider" = "$layer/trackers.sh" ]&&[ -f "$provider" ]&&[ ! -L "$provider" ]&&[ -x "$provider" ]&&cmp -s "$PROVIDER_SOURCE" "$provider"||refuse repair-required
  readme_facts="$($README_STATUS "$README_TEMPLATE" "$readme")"||refuse repair-required
  [ "$(fact "$readme_facts" readme_status)" = current ]||refuse repair-required
}

analyze_front_door(){
  local input="$1" output="$2"
  awk -v heading="$HEADING" -v begin_prefix="$BEGIN_PREFIX" -v end_mark="$END_MARK" '
    function fence_candidate(s, spaces,c,n) {
      spaces=0;while(spaces<3&&substr(s,spaces+1,1)==" ")spaces++;s=substr(s,spaces+1);c=substr(s,1,1)
      if(c!="`"&&c!="~")return 0;n=0;while(substr(s,n+1,1)==c)n++;if(n<3)return 0
      candidate_char=c;candidate_len=n;candidate_rest=substr(s,n+1);return 1
    }
    BEGIN{fence=0;headings=0;begins=0;ends=0;invalid=0;heading_line=0;begin_line=0;end_line=0;next_h2=0;legacy_headings=0;legacy_line=0}
    {
      scan=$0;sub(/\r$/, "", scan)
      if(fence_candidate(scan)){
        if(!fence){if(candidate_char=="~"||index(candidate_rest,"`")==0){fence=1;fence_char=candidate_char;fence_len=candidate_len;next}}
        else if(candidate_char==fence_char&&candidate_len>=fence_len&&candidate_rest~/^[ \t]*$/){fence=0;next}
      }
      if(fence)next
      if(scan==heading){headings++;heading_line=NR;next}
      if(scan=="## Project trackers"){legacy_headings++;legacy_line=NR}
      if(index(scan,"<!-- skill:backlog BEGIN")>0){
        if(index(scan,begin_prefix)==1&&scan~/^<!-- skill:backlog BEGIN built-against:[A-Za-z0-9._-]+ -->$/){begins++;begin_line=NR}else invalid++
        next
      }
      if(index(scan,"<!-- skill:backlog END")>0){if(scan==end_mark){ends++;end_line=NR}else invalid++;next}
      if(heading_line>0&&next_h2==0&&NR>heading_line&&scan~/^##[[:space:]]/)next_h2=NR
    }
    END{printf "headings=%d\nheading_line=%d\nbegins=%d\nbegin_line=%d\nends=%d\nend_line=%d\nnext_h2=%d\ninvalid=%d\nlegacy_headings=%d\nlegacy_line=%d\n",headings,heading_line,begins,begin_line,ends,end_line,next_h2,invalid,legacy_headings,legacy_line}
  ' "$input">"$output"
}

validate_analysis(){
  local facts="$1" headings begins ends invalid heading_line begin_line end_line next_h2
  headings="$(fact "$facts" headings)";begins="$(fact "$facts" begins)";ends="$(fact "$facts" ends)";invalid="$(fact "$facts" invalid)"
  heading_line="$(fact "$facts" heading_line)";begin_line="$(fact "$facts" begin_line)";end_line="$(fact "$facts" end_line)";next_h2="$(fact "$facts" next_h2)"
  [ "$headings" -le 1 ]||refuse duplicate-reserved-heading
  [ "$invalid" -eq 0 ]&&[ "$begins" -eq "$ends" ]&&[ "$begins" -le 1 ]||refuse malformed-owned-block
  if [ "$begins" -eq 1 ];then
    [ "$begin_line" -lt "$end_line" ]||refuse malformed-owned-block
    [ "$headings" -eq 1 ]&&[ "$heading_line" -lt "$begin_line" ]||refuse owned-block-outside-reserved-section
    if [ "$next_h2" -gt 0 ];then [ "$end_line" -lt "$next_h2" ]||refuse owned-block-outside-reserved-section;fi
  fi
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/backlog-anchor.XXXXXX")";DEST_TMP=''
cleanup(){ [ -z "$DEST_TMP" ]||rm -f "$DEST_TMP";rm -rf "$WORK";}
trap cleanup EXIT HUP INT TERM
CURRENT="$WORK/current";MIGRATED="$WORK/migrated";BLOCK="$WORK/block";CANDIDATE="$WORK/candidate";ANALYSIS="$WORK/analysis";SECOND="$WORK/second"
[ "$remove" = yes ]||sed "s/__BUILT_AGAINST__/$stamp/g" "$ROUTE">"$BLOCK"

snapshot_current(){ validate_target;if [ -f "$target" ];then cp "$target" "$CURRENT";else :>"$CURRENT";fi;}
migrate_legacy(){
  local input="$1" output="$2" facts legacy_count legacy_line snippet tail_state
  analyze_front_door "$input" "$ANALYSIS";facts="$(cat "$ANALYSIS")";validate_analysis "$facts"
  legacy_count="$(fact "$facts" legacy_headings)";legacy_line="$(fact "$facts" legacy_line)"
  if [ "$legacy_count" -eq 1 ];then
    snippet="$WORK/legacy-snippet";sed -n "${legacy_line},$((legacy_line+2))p" "$input">"$snippet"
    tail_state="$(awk -v start="$((legacy_line+3))" 'NR>=start{line=$0;sub(/\r$/, "", line);if(line~/^##[[:space:]]/)exit;if(line!=""){print "content";exit}}' "$input")"
    if cmp -s "$snippet" "$LEGACY"&&[ -z "$tail_state" ];then awk -v first="$legacy_line" 'NR<first||NR>first+2' "$input">"$output";return;fi
  fi
  cp "$input" "$output"
}
render_candidate(){
  local input="$1" output="$2" base facts headings heading_line begins begin_line end_line next_h2 last
  if [ "$remove" = yes ];then cp "$input" "$MIGRATED";else migrate_legacy "$input" "$MIGRATED";fi;base="$MIGRATED"
  analyze_front_door "$base" "$ANALYSIS";facts="$(cat "$ANALYSIS")";validate_analysis "$facts"
  headings="$(fact "$facts" headings)";heading_line="$(fact "$facts" heading_line)";begins="$(fact "$facts" begins)";begin_line="$(fact "$facts" begin_line)";end_line="$(fact "$facts" end_line)";next_h2="$(fact "$facts" next_h2)"
  if [ "$remove" = yes ];then
    action=remove
    if [ "$begins" -eq 0 ];then cp "$base" "$output";else head -n "$((begin_line-1))" "$base">"$output";tail -n "+$((end_line+1))" "$base">>"$output";fi
  elif [ "$begins" -eq 1 ];then
    action=refresh;head -n "$((begin_line-1))" "$base">"$output";cat "$BLOCK">>"$output";tail -n "+$((end_line+1))" "$base">>"$output"
  elif [ "$headings" -eq 1 ];then
    action=install
    if [ "$next_h2" -gt 0 ];then head -n "$((next_h2-1))" "$base">"$output";cat "$BLOCK">>"$output";printf '\n'>>"$output";tail -n "+$next_h2" "$base">>"$output"
    else cp "$base" "$output";[ ! -s "$output" ]||printf '\n'>>"$output";cat "$BLOCK">>"$output";fi
  else
    action=install;cp "$base" "$output";if [ -s "$output" ];then last="$(tail -c1 "$output"|od -An -tuC|tr -d '[:space:]')";[ "$last" = 10 ]&&printf '\n'>>"$output"||printf '\n\n'>>"$output";fi
    printf '%s\n\n' "$HEADING">>"$output";cat "$BLOCK">>"$output"
  fi
}

[ "$remove" = yes ]||validate_layer
snapshot_current;base_identity="$(current_identity)";render_candidate "$CURRENT" "$CANDIDATE"
if cmp -s "$CURRENT" "$CANDIDATE";then status=noop;else status=change;fi
candidate_identity="$(sha256_file "$CANDIDATE")"
printf 'action=%s\nstatus=%s\npath=AGENTS.md\nbase-sha256=%s\ncandidate-sha256=%s\n' "$action" "$status" "$base_identity" "$candidate_identity"
if [ "$status" = change ];then diff -u --label 'AGENTS.md:current' --label 'AGENTS.md:proposed' "$CURRENT" "$CANDIDATE"||true;fi
[ "$command_name" = apply ]||exit 0
[ "$base_arg" = "$base_identity" ]||refuse base-changed AGENTS.md
[ "$candidate_arg" = "$candidate_identity" ]||refuse candidate-changed AGENTS.md
[ -z "${BACKLOG_ANCHOR_TEST_AFTER_PREFLIGHT:-}" ]||{ [ -x "$BACKLOG_ANCHOR_TEST_AFTER_PREFLIGHT" ]||die 'test hook is not executable';"$BACKLOG_ANCHOR_TEST_AFTER_PREFLIGHT" "$root";}
[ "$remove" = yes ]||validate_layer
validate_target;[ "$(current_identity)" = "$base_arg" ]||refuse concurrent-project-edit AGENTS.md
snapshot_current;render_candidate "$CURRENT" "$SECOND";[ "$(sha256_file "$SECOND")" = "$candidate_arg" ]||refuse candidate-changed AGENTS.md
if cmp -s "$CURRENT" "$SECOND";then printf 'status=noop\n';exit 0;fi
DEST_TMP="$(mktemp "$root/.AGENTS.md.backlog.XXXXXX")"||refuse unsafe-temporary AGENTS.md
[ -f "$DEST_TMP" ]&&[ ! -L "$DEST_TMP" ]||refuse unsafe-temporary AGENTS.md
cp "$SECOND" "$DEST_TMP"
if [ -f "$target" ];then mode_bits="$(stat -f '%Lp' "$target" 2>/dev/null||stat -c '%a' "$target")";chmod "$mode_bits" "$DEST_TMP";else chmod 644 "$DEST_TMP";fi
validate_target;[ "$(current_identity)" = "$base_arg" ]||refuse concurrent-project-edit AGENTS.md
[ "$(sha256_file "$DEST_TMP")" = "$candidate_arg" ]||refuse candidate-changed AGENTS.md
mv "$DEST_TMP" "$target";DEST_TMP=''
if [ "$remove" = yes ];then echo 'removed=AGENTS.md';else echo 'wrote=AGENTS.md';fi
