#!/usr/bin/env bash
# backlog-setup.sh — deploy and administer Backlog's first-class tracker layer.
set -eo pipefail

die(){ echo "reason=$1${2:+ detail=$2}" >&2;exit 2;}
valid_rel(){ local v="$1" c o="$IFS";[ -n "$v" ]&&[ "$v" != . ]||return 1;case "$v" in /*)return 1;;esac;IFS=/;read -r -a a <<<"$v";IFS="$o";for c in "${a[@]}";do [ -n "$c" ]&&[ "$c" != . ]&&[ "$c" != .. ]||return 1;done;}
valid_stem(){ [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]&&[ "$1" != receipts ];}
overlap(){ [ "$1" = "$2" ]||[[ "$1" == "$2/"* ]]||[[ "$2" == "$1/"* ]];}

ROOT="${1:-}";[ -n "$ROOT" ]||die usage;shift
WS="";RR="";TR="";TR_EXPLICIT=false;mode="";stems=();custom=();stem=""
while [ $# -gt 0 ];do case "$1" in
  --workspace)WS="${2:-}";shift 2;;--records-root)RR="${2:-}";shift 2;;
  --trackers-root)TR="${2:-}";TR_EXPLICIT=true;shift 2;;--list)mode=list;shift;;
  --apply)mode=apply;shift;target=builtin;while [ $# -gt 0 ];do if [ "$1" = --custom ];then target=custom;shift;continue;fi;if [ "$target" = builtin ];then stems+=("$1");else custom+=("$1");fi;shift;done;;
  tracker-add|tracker-remove)mode="$1";stem="${2:-}";shift 2;;*)die usage;;esac;done
case "$ROOT" in /*);;*)die unsafe-root;;esac;[ -d "$ROOT" ]||die unsafe-root;ROOT="$(CDPATH='' cd -P "$ROOT"&&pwd)"
[ -n "$WS" ]||WS=.spaces;[ -n "$RR" ]||RR=.records
valid_rel "$WS"||die unsafe-workspace "$WS";valid_rel "$RR"||die unsafe-records-root "$RR"

resolve_decl(){ local f v="";for f in "$ROOT/AGENTS.md" "$ROOT/CLAUDE.md";do if [ -z "$v" ]&&[ -f "$f" ];then v="$(sed -n -E 's/^agent-trackers:[[:space:]]*//p' "$f"|head -n1|sed 's/[[:space:]]*$//')";fi;done;printf '%s\n' "$v";}
decl="$(resolve_decl)"
if [ "$TR_EXPLICIT" = true ];then valid_rel "$TR"||die unsafe-trackers-root "$TR";[ -z "$decl" ]||[ "$decl" = "$TR" ]||die trackers-root-conflict "$decl:$TR"
else TR="${decl:-.trackers}";valid_rel "$TR"||die unsafe-trackers-root "$TR";fi
overlap "$TR" "$WS"&&die overlapping-roots "$TR:$WS";overlap "$TR" "$RR"&&die overlapping-roots "$TR:$RR";overlap "$WS" "$RR"&&die overlapping-roots "$WS:$RR"

SKILL="$(CDPATH='' cd -P "$(dirname "$0")/.."&&pwd)";SRC="$SKILL/scripts/tracker-api.sh";REG="$SKILL/scripts/register-route.sh"
LAYER="$ROOT/$TR";API="$LAYER/tracker-api.sh";RECEIPTS="$LAYER/receipts.tsv";README="$LAYER/README.md";PROMPT="$ROOT/$WS/backlog/hooks/debrief.md";DOOR="$ROOT/AGENTS.md"
QUEUE_HEADER=$'id\tcreated\ttext\tevidence';RECEIPT_HEADER=$'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult'

if [ "$TR_EXPLICIT" = true ]&&[ -z "$decl" ]&&[ "$TR" != .trackers ]&&[ -d "$ROOT/.trackers" ];then die trackers-root-conflict .trackers;fi
[ -n "$mode" ]||die usage
if [ "$mode" = list ];then
  printf '%s\n' $'stem=feedback\ttitle=Feedback\tuse-when="Developer-experience friction and observations."' $'stem=issues\ttitle=Issues\tuse-when="Project problems, risks, and limitations."' $'stem=routines\ttitle=Routines\tuse-when="Repeatable responses to recognizable development triggers."' $'stem=tasks\ttitle=Tasks\tuse-when="Work someone should build or change."';exit
fi
if [ "$mode" = apply ]&&[ "${#stems[@]}" -eq 0 ]&&[ "${#custom[@]}" -eq 0 ];then stems=(tasks issues feedback routines);fi
if [ "$mode" = tracker-add ]||[ "$mode" = tracker-remove ];then valid_stem "$stem"||die invalid-stem "$stem";fi
for s in "${stems[@]}" "${custom[@]}";do [ -z "$s" ]||valid_stem "$s"||die invalid-stem "$s";done

check_parent(){ local rel="$1" cur="$ROOT" c o="$IFS";IFS=/;read -r -a a <<<"$rel";IFS="$o";for c in "${a[@]}";do cur="$cur/$c";[ ! -L "$cur" ]||die symlink "$cur";[ ! -e "$cur" ]||[ -d "$cur" ]||die incompatible-entry "$cur";done;}
check_file(){ [ ! -L "$1" ]||die symlink "$1";[ ! -e "$1" ]||[ -f "$1" ]||die incompatible-entry "$1";}
ensure_tree(){ local rel="$1" cur="$ROOT" c o="$IFS";IFS=/;read -r -a a <<<"$rel";IFS="$o";for c in "${a[@]}";do cur="$cur/$c";[ ! -L "$cur" ]||die symlink "$cur";if [ -e "$cur" ];then [ -d "$cur" ]||die incompatible-entry "$cur";else mkdir "$cur";fi;done;IFS="$o";}

# Complete preflight: parents, destinations, route shape, and incumbent schemas.
check_parent "$TR";check_parent "$WS/backlog/hooks";check_file "$API";check_file "$RECEIPTS";check_file "$README";check_file "$PROMPT";check_file "$DOOR"
"$REG" preflight --root "$ROOT" --workspace "$WS" --trackers-root "$TR" >/dev/null
if [ -f "$RECEIPTS" ];then [ "$(head -n1 "$RECEIPTS")" = "$RECEIPT_HEADER" ]||die malformed-receipts;fi
if [ "$mode" = tracker-remove ];then [ -f "$LAYER/$stem.tsv" ]&&[ ! -L "$LAYER/$stem.tsv" ]||die no-tracker "$stem";fi
if [ "$mode" = apply ]||[ "$mode" = tracker-add ];then for s in "${stems[@]}" "${custom[@]}" "$stem";do [ -n "$s" ]||continue;check_file "$LAYER/$s.tsv";if [ -f "$LAYER/$s.tsv" ];then [ "$(head -n1 "$LAYER/$s.tsv")" = "$QUEUE_HEADER" ]||die malformed-tracker "$s";fi;done;fi
[ -z "${BACKLOG_SETUP_TEST_AFTER_PREFLIGHT:-}" ]||{ [ -x "$BACKLOG_SETUP_TEST_AFTER_PREFLIGHT" ]||die test-hook;"$BACKLOG_SETUP_TEST_AFTER_PREFLIGHT" "$ROOT" "$TR";}

writes=0
report_write(){ writes=$((writes+1));echo "wrote=$1";[ -z "${BACKLOG_SETUP_TEST_AFTER_WRITE:-}" ]||{ [ -x "$BACKLOG_SETUP_TEST_AFTER_WRITE" ]||die test-hook;"$BACKLOG_SETUP_TEST_AFTER_WRITE" "$ROOT" "$TR" "$1" "$writes";};}
report_remove(){ writes=$((writes+1));echo "removed=$1";}
ensure_tree "$TR";ensure_tree "$WS/backlog/hooks"

if [ "$TR_EXPLICIT" = true ]&&[ -z "$decl" ]&&[ "$TR" != .trackers ];then
  tmp="$DOOR.tmp.$$";if [ -f "$DOOR" ];then cp "$DOOR" "$tmp";else printf '# Agent instructions\n' >"$tmp";fi
  printf '\nagent-trackers: %s\n' "$TR" >>"$tmp";mv "$tmp" "$DOOR";report_write AGENTS.md
fi
if [ ! -f "$README" ];then
  printf '%s\n' '# Project trackers' '' 'This directory is the project tracker@1 layer. Queue TSVs are current state; receipts.tsv records observations and consumption. Use tracker-api.sh for catalog, paging, and mutation. Git owns history and recovery.' >"$README";report_write "${README#"$ROOT"/}"
fi
if [ ! -f "$RECEIPTS" ];then printf '%s\n' "$RECEIPT_HEADER" >"$RECEIPTS";report_write "${RECEIPTS#"$ROOT"/}";fi
if [ ! -f "$API" ] || ! cmp -s "$SRC" "$API";then cp "$SRC" "$API";chmod +x "$API";report_write "${API#"$ROOT"/}";elif [ ! -x "$API" ];then chmod +x "$API";report_write "${API#"$ROOT"/}";fi

ensure_prompt(){ if [ ! -f "$PROMPT" ];then printf '%s\n' '# Backlog debrief routing' '' 'Edit each section to match this project. Debrief reads this file; the generic tracker API does not.' >"$PROMPT";report_write "${PROMPT#"$ROOT"/}";fi;}
module_count(){ [ -f "$PROMPT" ]||{ echo 0;return;};grep -cFx -- "## $1" "$PROMPT"||true;}
append_module(){ local s="$1" src="$2";ensure_prompt;[ "$(module_count "$s")" -eq 0 ]||return 0;printf '\n' >>"$PROMPT";if [ -f "$src" ];then awk 'BEGIN{p=0}/^## /{p=1}p{print}' "$src" >>"$PROMPT";else printf '## %s\n\nDescribe which finished-work leftovers belong in `%s`.\n' "$s" "$s" >>"$PROMPT";fi;report_write "${PROMPT#"$ROOT"/}";}
remove_module(){ local s="$1" tmp;if [ ! -f "$PROMPT" ]||[ "$(module_count "$s")" -eq 0 ];then return;fi;tmp="$PROMPT.tmp.$$";awk -v h="## $s" '/^## /{skip=($0==h)}!skip{print}' "$PROMPT" >"$tmp";mv "$tmp" "$PROMPT";report_write "${PROMPT#"$ROOT"/}";}
create_queue(){ local s="$1" src="$2" file;file="$LAYER/$s.tsv";if [ ! -f "$file" ];then printf '%s\n' "$QUEUE_HEADER" >"$file";report_write "${file#"$ROOT"/}";fi;append_module "$s" "$src";}

if [ "$mode" = apply ];then
  for s in "${stems[@]}";do src="$SKILL/suggestions/$s.md";[ -f "$src" ]||die unknown-stem "$s";create_queue "$s" "$src";done
  for s in "${custom[@]}";do create_queue "$s" "";done
elif [ "$mode" = tracker-add ];then
  [ ! -e "$LAYER/$stem.tsv" ]||die incumbent "$stem";src="$SKILL/suggestions/$stem.md";[ -f "$src" ]||src="";create_queue "$stem" "$src"
else
  rm "$LAYER/$stem.tsv";report_remove "$TR/$stem.tsv";remove_module "$stem"
fi

count=0;for f in "$LAYER"/*.tsv;do [ -f "$f" ]||continue;[ "$(basename "$f")" = receipts.tsv ]||count=$((count+1));done
stamp="$(git -C "$SKILL" log -1 --format=%h -- . 2>/dev/null||true)";[ -n "$stamp" ]||stamp="v0-$(date +%Y-%m-%d)"
if [ "$count" -gt 0 ];then "$REG" ensure --root "$ROOT" --workspace "$WS" --trackers-root "$TR" --stamp "$stamp";elif grep -q '^<!-- skill:backlog BEGIN' "$DOOR" 2>/dev/null;then "$REG" remove --root "$ROOT" --workspace "$WS" --trackers-root "$TR";fi
