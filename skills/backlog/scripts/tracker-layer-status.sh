#!/usr/bin/env bash
# tracker-layer-status.sh setup|repair|runtime --root <root>
set -euo pipefail

die(){ echo "reason=$1${2:+ detail=$2}" >&2;exit 2;}
valid_stem(){ [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]];}

MODE="${1:-}";shift||true
case "$MODE" in setup|repair|runtime);;*)die usage;;esac
ROOT="";TR=.trackers
while [ $# -gt 0 ];do case "$1" in
  --root)ROOT="${2:-}";shift 2;;*)die usage;;esac;done
case "$ROOT" in /*);;*)die unsafe-root;;esac
[ -d "$ROOT" ]||die unsafe-root
ROOT="$(CDPATH='' cd -P "$ROOT"&&pwd)"

SKILL="$(CDPATH='' cd -P "$(dirname "$0")/.."&&pwd)"
LAYER="$ROOT/$TR";TABLES="$LAYER/tables";PROVIDER="$LAYER/trackers.sh";SOURCE="$SKILL/scripts/trackers.sh"
README="$LAYER/README.md";HISTORY="$LAYER/history.tsv";PROMPT="$LAYER/DEBRIEF.md";MARKER="$TABLES/.gitkeep"
README_STATUS="$SKILL/scripts/tracker-readme-status.sh";README_TEMPLATE="$SKILL/templates/trackers-readme-block.md"
QUEUE_HEADER=$'id\tcreated\ttext\tevidence'
HISTORY_HEADER=$'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult'

provider_status=absent
if [ -L "$PROVIDER" ]||{ [ -e "$PROVIDER" ]&&[ ! -f "$PROVIDER" ];};then provider_status=invalid
elif [ -f "$PROVIDER" ];then
  if [ ! -x "$PROVIDER" ];then provider_status=non-executable
  elif cmp -s "$SOURCE" "$PROVIDER";then provider_status=current
  else provider_status=drifted
  fi
fi

readme_facts="$("$README_STATUS" "$README_TEMPLATE" "$README")"||die readme-classifier
readme_status="$(printf '%s\n' "$readme_facts"|sed -n 's/^readme_status=//p')"
[ -n "$readme_status" ]||die readme-classifier

history_state=absent
if [ -L "$HISTORY" ]||{ [ -e "$HISTORY" ]&&[ ! -f "$HISTORY" ];};then history_state=malformed
elif [ -f "$HISTORY" ];then
  if awk -F '\t' -v header="$HISTORY_HEADER" '
    NR==1{if($0!=header)exit 10;next}
    {if(NF!=8||$1!~/^event-[1-9][0-9]*$/||seen[$1]++||$2!~/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/||$3!~/^[a-z0-9][a-z0-9._\/-]*$/||$4!~/^[a-z0-9][a-z0-9-]*$/||$5!~("^"$4"-[1-9][0-9]*$")||($6!="observed"&&$6!="consumed")||($6=="observed"&&($7!=""||$8!=""))||($6=="consumed"&&$7==""))exit 11}
  ' "$HISTORY";then history_state=valid;else history_state=malformed;fi
fi

queue_state=valid;queue_count=0;prefix_queue_state=valid;legacy_root_state=absent;tables_state=absent
if [ -e "$LAYER" ];then
  [ -d "$LAYER" ]&&[ ! -L "$LAYER" ]||die unsafe-trackers-root "$TR"
  shopt -s nullglob
  for file in "$LAYER"/*.tsv;do
    [ "$file" = "$HISTORY" ]&&continue
    legacy_root_state=present
  done
  if [ -L "$TABLES" ]||{ [ -e "$TABLES" ]&&[ ! -d "$TABLES" ];};then
    tables_state=malformed;queue_state=malformed;prefix_queue_state=invalid
  elif [ -d "$TABLES" ];then
    tables_state=valid
    if [ -e "$MARKER" ]||[ -L "$MARKER" ];then
      [ -f "$MARKER" ]&&[ ! -L "$MARKER" ]&&[ ! -s "$MARKER" ]||{ queue_state=malformed;prefix_queue_state=invalid; }
    fi
    for file in "$TABLES"/*.tsv;do
      stem="$(basename "$file" .tsv)";queue_count=$((queue_count+1))
      if [ -L "$file" ]||[ ! -f "$file" ]||! valid_stem "$stem";then queue_state=malformed;prefix_queue_state=invalid;continue;fi
      if ! awk -F '\t' -v header="$QUEUE_HEADER" -v stem="$stem" '
        NR==1{if($0!=header)exit 10;next}
        {if(NF!=4||$1!~("^"stem"-[1-9][0-9]*$")||seen[$1]++||$2!~/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/||$3=="")exit 11}
      ' "$file";then queue_state=malformed;fi
      case "$stem" in tasks|issues|feedback|routines);;*)prefix_queue_state=invalid;;esac
      [ "$(wc -l <"$file"|tr -d ' ')" -eq 1 ]||prefix_queue_state=invalid
      [ "$(head -n1 "$file")" = "$QUEUE_HEADER" ]||prefix_queue_state=invalid
    done
  fi
  shopt -u nullglob
fi
[ "$legacy_root_state" = absent ]||{ queue_state=malformed;prefix_queue_state=invalid; }

prompt_state=valid
prompt_seen=false
if [ "$MODE" = setup ];then
  [ -e "$PROMPT" ]&&prompt_seen=true
  if [ -L "$PROMPT" ]||{ [ -e "$PROMPT" ]&&[ ! -f "$PROMPT" ];};then prompt_state=invalid
  elif [ -f "$PROMPT" ];then
    [ "$queue_count" -gt 0 ]||prompt_state=invalid
    [ "$(sed -n '1p' "$PROMPT")" = '# Backlog debrief routing' ]||prompt_state=invalid
    [ "$(sed -n '2p' "$PROMPT")" = '' ]||prompt_state=invalid
    [ "$(sed -n '3p' "$PROMPT")" = 'Edit each section to match this project. Debrief reads this file; the generic tracker API does not.' ]||prompt_state=invalid
    fourth="$(sed -n '4p' "$PROMPT")";[ -z "$fourth" ]||prompt_state=invalid
    headings="$(sed -n 's/^## //p' "$PROMPT")"
    while IFS= read -r stem;do
      [ -z "$stem" ]&&continue
      valid_stem "$stem"||prompt_state=invalid
      [ "$(grep -cFx -- "## $stem" "$PROMPT"||true)" -eq 1 ]||prompt_state=invalid
      [ -f "$TABLES/$stem.tsv" ]||prompt_state=invalid
    done <<<"$headings"
  fi
fi

head_has_history=false
if git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1;then
  head_path="$(git -C "$ROOT" ls-tree -r --name-only HEAD -- "$TR/history.tsv" 2>/dev/null||true)"
  [ "$head_path" = "$TR/history.tsv" ]&&head_has_history=true
fi

layer_status=ambiguous;recovery_action=human-review
if [ "$history_state" = valid ]&&[ "$tables_state" = valid ]&&[ "$queue_state" = valid ];then
  layer_status=initialized
  if [ "$MODE" = runtime ]&&[ "$provider_status" != current ];then recovery_action=repair;else recovery_action=none;fi
elif [ "$history_state" = malformed ]||[ "$queue_state" = malformed ];then
  layer_status=ambiguous;recovery_action=human-review
elif [ "$head_has_history" = true ];then
  layer_status=ledger-loss;recovery_action=git-restore
elif [ "$readme_status" = current ]||[ "$readme_status" = drifted ];then
  layer_status=ledger-loss;recovery_action=human-review
elif [ "$readme_status" = malformed ]||[ "$prefix_queue_state" != valid ]||[ "$prompt_state" != valid ]||{ [ "$provider_status" != absent ]&&[ "$provider_status" != current ];};then
  layer_status=ambiguous;recovery_action=human-review
else
  recognized=false
  [ "$provider_status" != absent ]&&recognized=true
  [ "$tables_state" != absent ]&&recognized=true
  [ "$queue_count" -gt 0 ]&&recognized=true
  [ "$readme_status" != absent ]&&recognized=true
  [ "$prompt_seen" = true ]&&recognized=true
  if [ "$recognized" = false ];then layer_status=absent;else layer_status=resumable-prefix;fi
  if [ "$MODE" = setup ];then recovery_action=none;else recovery_action=setup;fi
fi

echo "layer_status=$layer_status"
echo "provider_status=$provider_status"
echo "readme_status=$readme_status"
echo "recovery_action=$recovery_action"
