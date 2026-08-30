#!/usr/bin/env bash
# tracker-layer-status.sh setup|repair|runtime --root <root> --workspace <W> --records-root <R> --trackers-root <T>
set -euo pipefail

die(){ echo "reason=$1${2:+ detail=$2}" >&2;exit 2;}
valid_rel(){ local v="$1" c o="$IFS";[ -n "$v" ]&&[ "$v" != . ]||return 1;[[ "$v" != /* && "$v" != */ && "$v" != *//* && "$v" != *$'\n'* && "$v" != *$'\t'* ]]||return 1;IFS=/;read -r -a a <<<"$v";IFS="$o";for c in "${a[@]}";do [ -n "$c" ]&&[ "$c" != . ]&&[ "$c" != .. ]||return 1;done;}
valid_stem(){ [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]&&[ "$1" != receipts ];}

MODE="${1:-}";shift||true
case "$MODE" in setup|repair|runtime);;*)die usage;;esac
ROOT="";WS="";RR="";TR=""
while [ $# -gt 0 ];do case "$1" in
  --root)ROOT="${2:-}";shift 2;;--workspace)WS="${2:-}";shift 2;;
  --records-root)RR="${2:-}";shift 2;;--trackers-root)TR="${2:-}";shift 2;;*)die usage;;esac;done
case "$ROOT" in /*);;*)die unsafe-root;;esac
[ -d "$ROOT" ]||die unsafe-root
ROOT="$(CDPATH='' cd -P "$ROOT"&&pwd)"
valid_rel "$WS"||die unsafe-workspace "$WS";valid_rel "$RR"||die unsafe-records-root "$RR";valid_rel "$TR"||die unsafe-trackers-root "$TR"

SKILL="$(CDPATH='' cd -P "$(dirname "$0")/.."&&pwd)"
LAYER="$ROOT/$TR";PROVIDER="$LAYER/trackers.sh";SOURCE="$SKILL/scripts/trackers.sh"
README="$LAYER/README.md";LEDGER="$LAYER/receipts.tsv";PROMPT="$ROOT/$WS/backlog/hooks/debrief.md"
README_STATUS="$SKILL/scripts/tracker-readme-status.sh";README_TEMPLATE="$SKILL/templates/trackers-readme-block.md"
QUEUE_HEADER=$'id\tcreated\ttext\tevidence'
RECEIPT_HEADER=$'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult'

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

receipt_state=absent
if [ -L "$LEDGER" ]||{ [ -e "$LEDGER" ]&&[ ! -f "$LEDGER" ];};then receipt_state=malformed
elif [ -f "$LEDGER" ];then
  if awk -F '\t' -v header="$RECEIPT_HEADER" '
    NR==1{if($0!=header)exit 10;next}
    {if(NF!=8||$1!~/^receipt-[1-9][0-9]*$/||seen[$1]++||$2!~/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/||$3!~/^[a-z0-9][a-z0-9._\/-]*$/||$4!~/^[a-z0-9][a-z0-9-]*$/||$4=="receipts"||$5!~("^"$4"-[1-9][0-9]*$")||($6!="observed"&&$6!="consumed")||($6=="observed"&&($7!=""||$8!=""))||($6=="consumed"&&$7==""))exit 11}
  ' "$LEDGER";then receipt_state=valid;else receipt_state=malformed;fi
fi

queue_state=valid;queue_count=0;prefix_queue_state=valid
if [ -e "$LAYER" ];then
  [ -d "$LAYER" ]&&[ ! -L "$LAYER" ]||die unsafe-trackers-root "$TR"
  shopt -s nullglob
  for file in "$LAYER"/*.tsv;do
    stem="$(basename "$file" .tsv)";[ "$stem" = receipts ]&&continue
    queue_count=$((queue_count+1))
    if [ -L "$file" ]||[ ! -f "$file" ]||! valid_stem "$stem";then queue_state=malformed;prefix_queue_state=invalid;continue;fi
    if ! awk -F '\t' -v header="$QUEUE_HEADER" -v stem="$stem" '
      NR==1{if($0!=header)exit 10;next}
      {if(NF!=4||$1!~("^"stem"-[1-9][0-9]*$")||seen[$1]++||$2!~/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/||$3=="")exit 11}
    ' "$file";then queue_state=malformed;fi
    case "$stem" in tasks|issues|feedback|routines);;*)prefix_queue_state=invalid;;esac
    [ "$(wc -l <"$file"|tr -d ' ')" -eq 1 ]||prefix_queue_state=invalid
    [ "$(head -n1 "$file")" = "$QUEUE_HEADER" ]||prefix_queue_state=invalid
  done
  shopt -u nullglob
fi

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
    previous=0
    while IFS= read -r stem;do
      [ -z "$stem" ]&&continue
      case "$stem" in tasks)rank=1;;issues)rank=2;;feedback)rank=3;;routines)rank=4;;*)rank=0;prompt_state=invalid;;esac
      [ "$rank" -gt "$previous" ]||prompt_state=invalid;previous="$rank"
      [ "$(grep -cFx -- "## $stem" "$PROMPT"||true)" -eq 1 ]||prompt_state=invalid
      [ -f "$LAYER/$stem.tsv" ]||prompt_state=invalid
    done <<<"$headings"
  fi
fi

head_has_ledger=false
if git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1;then
  head_path="$(git -C "$ROOT" ls-tree -r --name-only HEAD -- "$TR/receipts.tsv" 2>/dev/null||true)"
  [ "$head_path" = "$TR/receipts.tsv" ]&&head_has_ledger=true
fi

layer_status=ambiguous;recovery_action=human-review
if [ "$receipt_state" = valid ]&&[ "$queue_state" = valid ];then
  layer_status=initialized
  if [ "$MODE" = runtime ]&&[ "$provider_status" != current ];then recovery_action=repair;else recovery_action=none;fi
elif [ "$receipt_state" = malformed ]||[ "$queue_state" = malformed ];then
  layer_status=ambiguous;recovery_action=human-review
elif [ "$head_has_ledger" = true ];then
  layer_status=ledger-loss;recovery_action=git-restore
elif [ "$readme_status" = current ]||[ "$readme_status" = drifted ];then
  layer_status=ledger-loss;recovery_action=human-review
elif [ "$readme_status" = malformed ]||[ "$prefix_queue_state" != valid ]||[ "$prompt_state" != valid ]||{ [ "$provider_status" != absent ]&&[ "$provider_status" != current ];};then
  layer_status=ambiguous;recovery_action=human-review
else
  recognized=false
  [ "$provider_status" != absent ]&&recognized=true
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
