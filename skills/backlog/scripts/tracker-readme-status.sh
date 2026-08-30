#!/usr/bin/env bash
# tracker-readme-status.sh <template> <README> — classify Backlog's managed README block.
set -euo pipefail

die(){ echo "reason=$1${2:+ detail=$2}" >&2;exit 2;}
[ "$#" -eq 2 ]||die usage
template="$1";readme="$2"
begin='<!-- backlog:trackers-tool BEGIN -->'
end='<!-- backlog:trackers-tool END -->'
[ -f "$template" ]&&[ ! -L "$template" ]||die invalid-template "$template"
[ "$(head -n 1 "$template")" = "$begin" ]&&[ "$(tail -n 1 "$template")" = "$end" ]&&
  [ "$(grep -cFx -- "$begin" "$template")" -eq 1 ]&&[ "$(grep -cFx -- "$end" "$template")" -eq 1 ]||die invalid-template "$template"
[ ! -L "$readme" ]||die symlink "$readme"
if [ ! -e "$readme" ];then echo 'readme_status=absent';exit 0;fi
[ -f "$readme" ]||die incompatible-entry "$readme"

facts="$(awk -v begin="$begin" -v end="$end" '
  $0==begin { begins++; if(state!=0) bad=1; state=1; if(!first)first=NR }
  $0==end { ends++; if(state!=1) bad=1; state=2; last=NR }
  END { print begins+0, ends+0, bad+0, first+0, last+0, state+0 }
' "$readme")"
read -r begins ends bad first last state <<<"$facts"
if [ "$begins" -eq 0 ]&&[ "$ends" -eq 0 ];then echo 'readme_status=absent';exit 0;fi
if [ "$begins" -ne 1 ]||[ "$ends" -ne 1 ]||[ "$bad" -ne 0 ]||[ "$state" -ne 2 ]||[ "$first" -gt "$last" ];then
  echo 'readme_status=malformed'
  echo 'readme_reason=markers'
  exit 0
fi
tmp="$(mktemp "${TMPDIR:-/tmp}/backlog-readme-block.XXXXXX")";trap 'rm -f "$tmp"' EXIT
sed -n "${first},${last}p" "$readme">"$tmp"
if cmp -s "$template" "$tmp";then status=current;else status=drifted;fi
echo "readme_status=$status"
echo "readme_begin_line=$first"
echo "readme_end_line=$last"
