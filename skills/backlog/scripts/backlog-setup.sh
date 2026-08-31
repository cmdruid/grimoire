#!/usr/bin/env bash
# backlog-setup.sh — reconcile Backlog's tracker layer and administer queues.
set -euo pipefail

die(){ echo "reason=$1${2:+ detail=$2}" >&2;exit 2;}
die_action(){ echo "reason=$1 action=$2" >&2;exit 2;}
valid_stem(){ [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]];}

ROOT="${1:-}";[ -n "$ROOT" ]||die usage;shift
TR=.trackers;mode="";stem=""
while [ $# -gt 0 ];do case "$1" in
  --list)mode=list;shift;;
  --apply)mode=setup;shift;[ $# -eq 0 ]||die queue-selection-retired;;
  repair)mode=repair;shift;[ $# -eq 0 ]||die usage;;
  tracker-add|tracker-remove)mode="$1";stem="${2:-}";shift 2;[ $# -eq 0 ]||die usage;;
  *)die usage;;esac;done
case "$ROOT" in /*);;*)die unsafe-root;;esac;[ -d "$ROOT" ]||die unsafe-root
ROOT="$(CDPATH='' cd -P "$ROOT"&&pwd)"
GIT_ROOT="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null||true)"
if [ -n "$GIT_ROOT" ];then GIT_ROOT="$(CDPATH='' cd -P "$GIT_ROOT"&&pwd)";[ "$GIT_ROOT" = "$ROOT" ]||die noncanonical-project-root "$GIT_ROOT";fi

SKILL="$(CDPATH='' cd -P "$(dirname "$0")/.."&&pwd)"
SOURCE="$SKILL/scripts/trackers.sh";CLASSIFIER="$SKILL/scripts/tracker-layer-status.sh"
README_STATUS="$SKILL/scripts/tracker-readme-status.sh";README_TEMPLATE="$SKILL/templates/trackers-readme-block.md"
REG="$SKILL/scripts/register-route.sh";LAYER="$ROOT/$TR";TABLES="$LAYER/tables";PROVIDER="$LAYER/trackers.sh"
HISTORY="$LAYER/history.tsv";MARKER="$TABLES/.gitkeep";README="$LAYER/README.md";PROMPT="$LAYER/DEBRIEF.md";DOOR="$ROOT/AGENTS.md"
QUEUE_HEADER=$'id\tcreated\ttext\tevidence';HISTORY_HEADER=$'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult'
[ -n "$mode" ]||die usage
if [ "$mode" = list ];then
  printf '%s\n' $'stem=feedback\ttitle=Feedback\tuse-when="Developer-experience friction and observations."' $'stem=issues\ttitle=Issues\tuse-when="Project problems, risks, and limitations."' $'stem=routines\ttitle=Routines\tuse-when="Repeatable responses to recognizable development triggers."' $'stem=tasks\ttitle=Tasks\tuse-when="Work someone should build or change."';exit
fi
case "$mode" in tracker-add|tracker-remove)valid_stem "$stem"||die invalid-stem "$stem";;esac

check_parent(){ local rel="$1" cur="$ROOT" c o="$IFS";IFS=/;read -r -a a <<<"$rel";IFS="$o";for c in "${a[@]}";do cur="$cur/$c";[ ! -L "$cur" ]||die symlink "$cur";[ ! -e "$cur" ]||[ -d "$cur" ]||die incompatible-entry "$cur";done;}
check_file(){ [ ! -L "$1" ]||die symlink "$1";[ ! -e "$1" ]||[ -f "$1" ]||die incompatible-entry "$1";}
ensure_tree(){ local rel="$1" cur="$ROOT" c o="$IFS";IFS=/;read -r -a a <<<"$rel";IFS="$o";for c in "${a[@]}";do cur="$cur/$c";[ ! -L "$cur" ]||die symlink "$cur";if [ -e "$cur" ];then [ -d "$cur" ]||die incompatible-entry "$cur";else mkdir "$cur";fi;done;}
fresh_tmp(){ [ ! -L "$1" ]||die symlink "$1";[ ! -e "$1" ]||die incompatible-entry "$1";}

classifier_mode="$mode"
case "$classifier_mode" in tracker-add|tracker-remove)classifier_mode=runtime;;esac
facts="$("$CLASSIFIER" "$classifier_mode" --root "$ROOT")"
fact(){ printf '%s\n' "$facts"|sed -n "s/^$1=//p"|head -n1;}
layer_status="$(fact layer_status)";provider_status="$(fact provider_status)";readme_state="$(fact readme_status)";recovery="$(fact recovery_action)"
[ -n "$layer_status" ]&&[ -n "$provider_status" ]&&[ -n "$readme_state" ]&&[ -n "$recovery" ]||die classifier

case "$mode:$layer_status" in
  setup:absent|setup:resumable-prefix|setup:initialized|tracker-add:initialized|tracker-remove:initialized|repair:initialized);;
  *:ledger-loss)die_action ledger-recovery-required "$recovery";;
  setup:ambiguous|tracker-add:ambiguous|tracker-remove:ambiguous|repair:ambiguous)die ambiguous-state human-review;;
  repair:*)die_action setup-required '/backlog setup';;
  tracker-add:*|tracker-remove:*)die_action setup-required '/backlog setup';;
  *)die_action setup-required '/backlog setup';;
esac
[ "$readme_state" != malformed ]||die malformed-readme-markers
case "$mode" in tracker-add|tracker-remove)[ "$provider_status" = current ]||die_action repair-required '/backlog repair';;esac

# Complete preflight before the first durable write.
check_parent "$TR";check_parent "$TR/tables";check_file "$PROVIDER";check_file "$HISTORY";check_file "$MARKER";check_file "$README"
layer_preexisted=false;[ -d "$LAYER" ]&&layer_preexisted=true
if [ "$mode" != repair ];then
  check_file "$PROMPT";check_file "$DOOR"
  "$REG" preflight --root "$ROOT" >/dev/null
fi
if [ "$mode" = tracker-remove ];then [ -f "$TABLES/$stem.tsv" ]&&[ ! -L "$TABLES/$stem.tsv" ]||die no-tracker "$stem";fi
if [ "$mode" = tracker-add ];then check_file "$TABLES/$stem.tsv";[ ! -e "$TABLES/$stem.tsv" ]||die incumbent "$stem";fi
[ -z "${BACKLOG_SETUP_TEST_AFTER_PREFLIGHT:-}" ]||{ [ -x "$BACKLOG_SETUP_TEST_AFTER_PREFLIGHT" ]||die test-hook;"$BACKLOG_SETUP_TEST_AFTER_PREFLIGHT" "$ROOT" "$TR";}

writes=0;reported=""
already_reported(){ grep -qxF -- "$1" <<<"$reported" 2>/dev/null;}
report(){
  local kind="$1" path="$2"
  if ! already_reported "$kind=$path";then
    reported+="${reported:+$'\n'}$kind=$path";echo "$kind=$path"
  fi
  if [ "$kind" = wrote ]||[ "$kind" = removed ];then
    writes=$((writes+1))
    [ -z "${BACKLOG_SETUP_TEST_AFTER_WRITE:-}" ]||{ [ -x "$BACKLOG_SETUP_TEST_AFTER_WRITE" ]||die test-hook;"$BACKLOG_SETUP_TEST_AFTER_WRITE" "$ROOT" "$TR" "$path" "$writes";}
  fi
}
head_differs(){
  local rel="$1"
  if ! git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1;then return 0;fi
  if ! git -C "$ROOT" cat-file -e "HEAD:$rel" 2>/dev/null;then return 0;fi
  git -C "$ROOT" diff --quiet HEAD -- "$rel" 2>/dev/null&&return 1
  return 0
}
report_exact_reconciled(){ local path="$1" expected="$2" rel;rel="${path#"$ROOT"/}";[ -f "$path" ]&&cmp -s "$expected" "$path"&&head_differs "$rel"&&report reconciled "$rel"||true;}
render_readme(){
  local input="$1" output="$2" block_facts block_status begin end last
  if [ "$input" = - ];then block_status=absent
  else block_facts="$("$README_STATUS" "$README_TEMPLATE" "$input")";block_status="$(printf '%s\n' "$block_facts"|sed -n 's/^readme_status=//p')";fi
  case "$block_status" in
    absent)
      if [ "$input" = - ];then printf '%s\n\n' '# Project trackers' 'Public tracker@2 tables and their shared lifecycle history.'>"$output"
      else cp "$input" "$output";if [ -s "$input" ];then last="$(tail -c 1 "$input"|od -An -tuC|tr -d '[:space:]')";[ "$last" = 10 ]||printf '\n'>>"$output";printf '\n'>>"$output";fi;fi
      cat "$README_TEMPLATE">>"$output"
      ;;
    current|drifted)
      begin="$(printf '%s\n' "$block_facts"|sed -n 's/^readme_begin_line=//p')";end="$(printf '%s\n' "$block_facts"|sed -n 's/^readme_end_line=//p')"
      if [ "$begin" -gt 1 ];then head -n "$((begin-1))" "$input">"$output";else :>"$output";fi
      cat "$README_TEMPLATE">>"$output";tail -n "+$((end+1))" "$input">>"$output"
      ;;
    *)die commit-custody-required "$TR/README.md";;
  esac
}
report_readme_reconciled(){
  local rel="$TR/README.md" head_file expected
  [ -f "$README" ]&&[ "$readme_state" = current ]&&head_differs "$rel"||return 0
  head_file="$(mktemp "${TMPDIR:-/tmp}/backlog-readme-head.XXXXXX")";expected="$(mktemp "${TMPDIR:-/tmp}/backlog-readme-expected.XXXXXX")"
  if git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1&&git -C "$ROOT" cat-file -e "HEAD:$rel" 2>/dev/null;then
    git -C "$ROOT" show "HEAD:$rel">"$head_file";render_readme "$head_file" "$expected"
  else render_readme - "$expected";fi
  if cmp -s "$expected" "$README";then rm -f "$head_file" "$expected";report reconciled "$rel";return 0;fi
  rm -f "$head_file" "$expected";die commit-custody-required "$rel"
}
if [ "$mode" = setup ];then
  report_exact_reconciled "$MARKER" /dev/null
  report_exact_reconciled "$PROVIDER" "$SOURCE"
  tmp_header="$(mktemp "${TMPDIR:-/tmp}/backlog-queue-header.XXXXXX")";printf '%s\n' "$QUEUE_HEADER">"$tmp_header"
  for s in tasks issues feedback routines;do report_exact_reconciled "$TABLES/$s.tsv" "$tmp_header";done
  tmp_history="$(mktemp "${TMPDIR:-/tmp}/backlog-history-header.XXXXXX")";printf '%s\n' "$HISTORY_HEADER">"$tmp_history";report_exact_reconciled "$HISTORY" "$tmp_history"
  report_readme_reconciled
  tmp_prompt="$(mktemp "${TMPDIR:-/tmp}/backlog-prompt.XXXXXX")";printf '%s\n' '# Backlog debrief routing' '' 'Edit each section to match this project. Debrief reads this file; the generic tracker API does not.'>"$tmp_prompt"
  if [ -f "$PROMPT" ];then
    for s in tasks issues feedback routines;do
      if grep -qFx -- "## $s" "$PROMPT";then printf '\n'>>"$tmp_prompt";awk 'BEGIN{p=0}/^## /{p=1}p{print}' "$SKILL/suggestions/$s.md">>"$tmp_prompt";fi
    done
    report_exact_reconciled "$PROMPT" "$tmp_prompt"
  fi
  prompt_will_change=false
  if [ "$layer_status" != initialized ];then prompt_will_change=true
  elif [ -f "$PROMPT" ];then
    shopt -s nullglob
    for file in "$TABLES"/*.tsv;do s="$(basename "$file" .tsv)";[ "$(grep -cFx -- "## $s" "$PROMPT"||true)" -gt 0 ]||prompt_will_change=true;done
    shopt -u nullglob
  fi
  if [ "$prompt_will_change" = true ]&&[ -f "$PROMPT" ]&&head_differs "$TR/DEBRIEF.md"&&! cmp -s "$tmp_prompt" "$PROMPT";then die commit-custody-required "$TR/DEBRIEF.md";fi
  tmp_door="$(mktemp "${TMPDIR:-/tmp}/backlog-door.XXXXXX")";printf '# Agent instructions\n\n## Skill routes (self-registered)\n\n'>"$tmp_door";cat "$SKILL/templates/debrief-anchor.md">>"$tmp_door";report_exact_reconciled "$DOOR" "$tmp_door"
  rm -f "$tmp_header" "$tmp_history" "$tmp_prompt" "$tmp_door"
fi

require_layer(){ check_parent "$TR";[ -d "$LAYER" ]&&[ ! -L "$LAYER" ]||die vanished-tracker-root "$TR";}
require_tables(){ require_layer;[ -d "$TABLES" ]&&[ ! -L "$TABLES" ]||die vanished-tables-root "$TR/tables";}
require_prompt_parent(){ require_layer;}
if [ "$layer_preexisted" = true ];then require_layer
elif [ "$mode" = setup ];then ensure_tree "$TR"
else die vanished-tracker-root "$TR";fi
if [ "$mode" = setup ];then ensure_tree "$TR/tables";else require_tables;fi

require_destination_parent(){ case "$1" in "$TABLES"/*)require_tables;;*)require_layer;;esac;}
write_atomic(){ local dest="$1" src="$2" rel tmp;rel="${dest#"$ROOT"/}";require_destination_parent "$dest";tmp="$dest.tmp.$$";fresh_tmp "$tmp";cp "$src" "$tmp";require_destination_parent "$dest";check_file "$dest";mv "$tmp" "$dest";report wrote "$rel";}
write_line_atomic(){ local dest="$1" line="$2" rel tmp;rel="${dest#"$ROOT"/}";require_destination_parent "$dest";tmp="$dest.tmp.$$";fresh_tmp "$tmp";printf '%s\n' "$line">"$tmp";require_destination_parent "$dest";check_file "$dest";mv "$tmp" "$dest";report wrote "$rel";}
write_empty_atomic(){ local dest="$1" rel tmp;rel="${dest#"$ROOT"/}";require_destination_parent "$dest";tmp="$dest.tmp.$$";fresh_tmp "$tmp";:>"$tmp";require_destination_parent "$dest";check_file "$dest";mv "$tmp" "$dest";report wrote "$rel";}

install_provider(){
  if [ ! -f "$PROVIDER" ]||! cmp -s "$SOURCE" "$PROVIDER";then write_atomic "$PROVIDER" "$SOURCE";fi
  require_layer;if [ ! -x "$PROVIDER" ];then chmod +x "$PROVIDER";report wrote "$TR/trackers.sh";fi
}
ensure_prompt(){ if [ ! -f "$PROMPT" ];then require_prompt_parent;tmp="$PROMPT.tmp.$$";fresh_tmp "$tmp";printf '%s\n' '# Backlog debrief routing' '' 'Edit each section to match this project. Debrief reads this file; the generic tracker API does not.'>"$tmp";require_prompt_parent;check_file "$PROMPT";mv "$tmp" "$PROMPT";report wrote "$TR/DEBRIEF.md";fi;}
module_count(){ [ -f "$PROMPT" ]||{ echo 0;return;};grep -cFx -- "## $1" "$PROMPT"||true;}
append_module(){
  local s="$1" src="$2" before module
  ensure_prompt;[ "$(module_count "$s")" -eq 0 ]||return 0;require_prompt_parent
  before="$(mktemp "${TMPDIR:-/tmp}/backlog-prompt-before.XXXXXX")";module="$(mktemp "${TMPDIR:-/tmp}/backlog-prompt-module.XXXXXX")";cp "$PROMPT" "$before"
  if [ -f "$src" ];then awk 'BEGIN{p=0}/^## /{p=1}p{print}' "$src">"$module";else printf '## %s\n\nDescribe which finished-work leftovers belong in `%s`.\n' "$s" "$s">"$module";fi
  tmp="$PROMPT.tmp.$$";fresh_tmp "$tmp"
  awk -v target="$s" -v module="$module" '
    function rank(v){return v=="tasks"?1:v=="issues"?2:v=="feedback"?3:v=="routines"?4:99}
    function emit( line){while((getline line < module)>0)print line;close(module)}
    BEGIN{target_rank=rank(target)}
    /^## /&&!done&&rank(substr($0,4))>target_rank{
      if(have&&previous!="")print previous
      print "";emit();print "";done=1;have=0
    }
    {if(have)print previous;previous=$0;have=1}
    END{if(have)print previous;if(!done){print "";emit()}}
  ' "$before">"$tmp"
  require_prompt_parent;check_file "$PROMPT";if ! cmp -s "$before" "$PROMPT";then rm -f "$before" "$module" "$tmp";die concurrent-project-edit "$TR/DEBRIEF.md";fi
  mv "$tmp" "$PROMPT";rm -f "$before" "$module";report wrote "$TR/DEBRIEF.md"
}
remove_module(){ local s="$1" before;[ -f "$PROMPT" ]&&[ "$(module_count "$s")" -gt 0 ]||return 0;require_prompt_parent;before="$(mktemp "${TMPDIR:-/tmp}/backlog-prompt-before.XXXXXX")";cp "$PROMPT" "$before";tmp="$PROMPT.tmp.$$";fresh_tmp "$tmp";awk -v h="## $s" '/^## /{skip=($0==h)}!skip{print}' "$before">"$tmp";require_prompt_parent;check_file "$PROMPT";if ! cmp -s "$before" "$PROMPT";then rm -f "$before" "$tmp";die concurrent-project-edit "$TR/DEBRIEF.md";fi;mv "$tmp" "$PROMPT";rm -f "$before";report wrote "$TR/DEBRIEF.md";}
create_queue(){ local s="$1" src="$2" file;file="$TABLES/$s.tsv";if [ ! -f "$file" ];then write_line_atomic "$file" "$QUEUE_HEADER";fi;require_tables;append_module "$s" "$src";}
validate_prehistory(){
  local s headings prefix_facts prefix_status
  require_layer;require_prompt_parent;check_file "$PROVIDER";[ -x "$PROVIDER" ]&&cmp -s "$SOURCE" "$PROVIDER"||die malformed-provider
  for s in tasks issues feedback routines;do
    check_file "$TABLES/$s.tsv";[ -f "$TABLES/$s.tsv" ]&&[ "$(wc -l <"$TABLES/$s.tsv"|tr -d ' ')" -eq 1 ]&&[ "$(head -n 1 "$TABLES/$s.tsv")" = "$QUEUE_HEADER" ]||die malformed-tracker "$s"
    [ -f "$PROMPT" ]&&[ "$(grep -cFx -- "## $s" "$PROMPT"||true)" -eq 1 ]||die malformed-prompt "$s"
  done
  headings="$(sed -n 's/^## //p' "$PROMPT")"
  while IFS= read -r s;do case "$s" in tasks|issues|feedback|routines);;*)die malformed-prompt "$s";;esac;done <<<"$headings"
  prefix_facts="$("$CLASSIFIER" setup --root "$ROOT")";prefix_status="$(printf '%s\n' "$prefix_facts"|sed -n 's/^layer_status=//p')"
  [ "$prefix_status" = resumable-prefix ]||die malformed-prefix "$prefix_status"
}

validate_provider(){
  require_layer;[ -x "$PROVIDER" ]&&[ ! -L "$PROVIDER" ]&&cmp -s "$SOURCE" "$PROVIDER"||die malformed-provider
  description="$("$PROVIDER" describe)"||die malformed-provider
  schema_lines="$(printf '%s\n' "$description"|sed -n '/^schema=/p')"
  [ "$schema_lines" = 'schema=tracker@2' ]||die malformed-provider
  "$PROVIDER" catalog >/dev/null||die malformed-provider
}
reconcile_readme(){
  local snapshot existed=false
  require_layer;readme_facts="$("$README_STATUS" "$README_TEMPLATE" "$README")";status="$(printf '%s\n' "$readme_facts"|sed -n 's/^readme_status=//p')"
  [ "$status" != malformed ]||die malformed-readme-markers
  [ "$status" != current ]||return 0
  snapshot="$(mktemp "${TMPDIR:-/tmp}/backlog-readme-before.XXXXXX")";if [ -f "$README" ];then cp "$README" "$snapshot";existed=true;fi
  tmp="$README.tmp.$$";fresh_tmp "$tmp";if [ "$existed" = true ];then render_readme "$snapshot" "$tmp";else render_readme - "$tmp";fi
  [ -z "${BACKLOG_SETUP_TEST_BEFORE_README_RENAME:-}" ]||{ [ -x "$BACKLOG_SETUP_TEST_BEFORE_README_RENAME" ]||die test-hook;"$BACKLOG_SETUP_TEST_BEFORE_README_RENAME" "$ROOT" "$TR";}
  require_layer;check_file "$README"
  if { [ "$existed" = true ]&&{ [ ! -f "$README" ]||! cmp -s "$snapshot" "$README";}; }||{ [ "$existed" = false ]&&[ -e "$README" ];};then rm -f "$snapshot" "$tmp";die concurrent-project-edit "$TR/README.md";fi
  mv "$tmp" "$README";rm -f "$snapshot";report wrote "$TR/README.md"
}

if [ "$mode" = repair ];then
  install_provider;validate_provider;reconcile_readme
elif [ "$mode" = setup ];then
  if [ ! -f "$MARKER" ];then write_empty_atomic "$MARKER";fi
  install_provider
  if [ "$layer_status" = initialized ];then
    shopt -s nullglob
    for file in "$TABLES"/*.tsv;do s="$(basename "$file" .tsv)";src="$SKILL/suggestions/$s.md";[ -f "$src" ]||src="";append_module "$s" "$src";done
    shopt -u nullglob
  else
    for s in tasks issues feedback routines;do create_queue "$s" "$SKILL/suggestions/$s.md";done
    if [ ! -f "$HISTORY" ];then validate_prehistory;write_line_atomic "$HISTORY" "$HISTORY_HEADER";fi
  fi
  validate_provider;reconcile_readme
elif [ "$mode" = tracker-add ];then
  validate_provider;create_queue "$stem" "$( [ -f "$SKILL/suggestions/$stem.md" ]&&printf '%s' "$SKILL/suggestions/$stem.md"||true )"
else
  validate_provider;require_tables;rm "$TABLES/$stem.tsv";report removed "$TR/tables/$stem.tsv";require_tables;remove_module "$stem"
fi

if [ "$mode" != repair ];then
  require_layer
  count=0;shopt -s nullglob;for file in "$TABLES"/*.tsv;do count=$((count+1));done;shopt -u nullglob
  if [ "$count" -gt 0 ];then "$REG" ensure --root "$ROOT";else "$REG" remove --root "$ROOT";fi
fi

# Final validation after the last reported write.
final_mode=setup;[ "$mode" = repair ]&&final_mode=repair
final_facts="$("$CLASSIFIER" "$final_mode" --root "$ROOT")"
[ "$(printf '%s\n' "$final_facts"|sed -n 's/^layer_status=//p')" = initialized ]||die final-validation
validate_provider
if [ "$mode" != repair ];then "$REG" preflight --root "$ROOT" >/dev/null;fi
