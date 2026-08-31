#!/usr/bin/env bash
# migrate-trackers.sh preview|apply --root <root> [--source <repo-relative>] [--confirmed]
#
# One bounded brownfield converter: exact tracker@1 TSV state to tracker@2.
# Ordinary setup and runtime remain legacy-blind. Git is the recovery surface.
set -euo pipefail

die(){ echo "migrate-trackers.sh: $*" >&2;exit 2;}
refuse(){ echo "reason=$1${2:+ detail=$2}" >&2;exit 2;}
usage(){ die 'usage: migrate-trackers.sh preview|apply --root <root> [--source <repo-relative>] [--confirmed]';}
valid_rel(){
  [ -n "$1" ]||return 1
  case "$1" in .|/*|*$'\n'*|*$'\r'*|*$'\t'*)return 1;;esac
  case "/$1/" in */../*|*/./*|*//*)return 1;;esac
}
valid_stem(){ [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]&&[ "$1" != receipts ];}
literal(){ printf ':(literal)%s' "$1";}

mode="${1:-}";[ -n "$mode" ]||usage;shift
case "$mode" in preview|apply);;*)usage;;esac
root="";source_arg="";confirmed=no
while [ "$#" -gt 0 ];do
  case "$1" in
    --root)[ "$#" -ge 2 ]||usage;root="$2";shift 2;;
    --source)[ "$#" -ge 2 ]||usage;source_arg="$2";shift 2;;
    --confirmed)confirmed=yes;shift;;
    *)usage;;
  esac
done
[ -n "$root" ]||usage
[ "$mode" = apply ]||[ "$confirmed" = no ]||usage
[ "$mode" = preview ]||[ "$confirmed" = yes ]||refuse confirmation-required
case "$root" in /*);;*)refuse root-not-absolute "$root";;esac
[ -d "$root" ]&&[ ! -L "$root" ]||refuse invalid-root "$root"
root="$(CDPATH='' cd -P "$root"&&pwd)"
git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null||true)"
[ -n "$git_root" ]||refuse git-required
git_root="$(CDPATH='' cd -P "$git_root"&&pwd)"
[ "$git_root" = "$root" ]||refuse root-not-git-top-level "$git_root"
[ -n "$(git -C "$root" branch --show-current)" ]||refuse detached-head

SKILL="$(CDPATH='' cd -P "$(dirname "$0")/.."&&pwd)"
SETUP="$SKILL/scripts/backlog-setup.sh"
SCOPED="$SKILL/scripts/scoped-commit.sh"
README_STATUS="$SKILL/scripts/tracker-readme-status.sh"
README_TEMPLATE="$SKILL/templates/trackers-readme-block.md"
[ -x "$SETUP" ]&&[ -x "$SCOPED" ]&&[ -x "$README_STATUS" ]||die 'package helpers unavailable'

source="${source_arg:-.trackers}"
valid_rel "$source"||refuse invalid-source "$source"
source_abs="$root/$source"
destination=.trackers
destination_abs="$root/$destination"
QUEUE_HEADER=$'id\tcreated\ttext\tevidence'
RECEIPT_HEADER=$'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult'
inventory=();queues=();migration_started=no;tmp_files=()

cleanup(){
  rc=$?;trap - EXIT
  for tmp in ${tmp_files[@]+"${tmp_files[@]}"};do [ -z "$tmp" ]||rm -f -- "$tmp";done
  if [ "$rc" -ne 0 ]&&[ "$migration_started" = yes ];then
    echo 'migration stopped after the first move; inspect or revert this ordinary Git diff:' >&2
    git -C "$root" status --short >&2||true
    git -C "$root" diff --binary HEAD -- . >&2||true
  fi
  exit "$rc"
}
trap cleanup EXIT

check_chain(){
  local rel="$1" current="$root" part old_ifs="$IFS"
  IFS=/;read -r -a parts <<<"$rel";IFS="$old_ifs"
  for part in "${parts[@]}";do
    current="$current/$part"
    [ ! -L "$current" ]||refuse symlink-source "${current#"$root"/}"
  done
}

validate_queue(){
  local stem="$1" file="$2"
  awk -F '\t' -v header="$QUEUE_HEADER" -v stem="$stem" '
    NR==1{if($0!=header)exit 10;next}
    {if(NF!=4||$1!~("^"stem"-[1-9][0-9]*$")||seen[$1]++||$2!~/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/||$3=="")exit 11}
  ' "$file"||refuse malformed-tracker "$stem"
}

validate_receipts(){
  awk -F '\t' -v header="$RECEIPT_HEADER" '
    NR==1{if($0!=header)exit 10;next}
    {if(NF!=8||$1!~/^receipt-[1-9][0-9]*$/||seen[$1]++||$2!~/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/||$3!~/^[a-z0-9][a-z0-9._\/-]*$/||$4!~/^[a-z0-9][a-z0-9-]*$/||$4=="receipts"||$5!~("^"$4"-[1-9][0-9]*$")||($6!="observed"&&$6!="consumed")||($6=="observed"&&($7!=""||$8!=""))||($6=="consumed"&&$7==""))exit 11}
  ' "$source_abs/receipts.tsv"||refuse malformed-receipts
}

validate_prompt(){
  local prompt="$source_abs/DEBRIEF.md" stem headings
  [ "$(sed -n '1p' "$prompt")" = '# Backlog debrief routing' ]||refuse malformed-prompt
  [ "$(sed -n '2p' "$prompt")" = '' ]||refuse malformed-prompt
  [ "$(sed -n '3p' "$prompt")" = 'Edit each section to match this project. Debrief reads this file; the generic tracker API does not.' ]||refuse malformed-prompt
  [ -z "$(sed -n '4p' "$prompt")" ]||refuse malformed-prompt
  headings="$(sed -n 's/^## //p' "$prompt")"
  while IFS= read -r stem;do
    [ -z "$stem" ]&&continue
    valid_stem "$stem"||refuse malformed-prompt "$stem"
    [ "$(grep -cFx -- "## $stem" "$prompt"||true)" -eq 1 ]||refuse malformed-prompt "$stem"
    [ -f "$source_abs/$stem.tsv" ]||refuse malformed-prompt "$stem"
  done <<<"$headings"
  for stem in ${queues[@]+"${queues[@]}"};do
    [ "$(grep -cFx -- "## $stem" "$prompt"||true)" -eq 1 ]||refuse malformed-prompt "$stem"
  done
}

preflight(){
  local entry rel base stem ignored readme_facts readme_state
  inventory=();queues=()
  [ -z "$(git -C "$root" status --porcelain --untracked-files=all)" ]||refuse dirty-worktree
  check_chain "$source"
  [ -d "$source_abs" ]&&[ ! -L "$source_abs" ]||refuse source-not-directory "$source"
  if [ "$source" != .trackers ];then
    [ ! -e "$destination_abs" ]&&[ ! -L "$destination_abs" ]||refuse destination-present "$destination"
  else
    [ ! -e "$source_abs/tables" ]&&[ ! -L "$source_abs/tables" ]||refuse mixed-source tables
    [ ! -e "$source_abs/history.tsv" ]&&[ ! -L "$source_abs/history.tsv" ]||refuse mixed-source history.tsv
  fi
  [ -z "$(find "$source_abs" -type l -print -quit)" ]||refuse symlink-source "$source"
  ignored="$(git -C "$root" ls-files --others --ignored --exclude-standard -- "$(literal "$source")"||true)"
  [ -z "$ignored" ]||{ printf '%s\n' "$ignored"|sed 's/^/foreign=/' >&2;refuse ignored-source-entry;}

  shopt -s nullglob dotglob
  entries=("$source_abs"/*)
  shopt -u nullglob dotglob
  [ "${#entries[@]}" -gt 0 ]||refuse empty-source "$source"
  for entry in "${entries[@]}";do
    rel="${entry#"$root"/}";base="${entry##*/}";inventory+=("$rel")
    [ -f "$entry" ]&&[ ! -L "$entry" ]||refuse mixed-source "$rel"
    git -C "$root" ls-files --error-unmatch -- "$(literal "$rel")" >/dev/null 2>&1||refuse untracked-source-entry "$rel"
    case "$base" in
      README.md|DEBRIEF.md) ;;
      trackers.sh)
        [ -x "$entry" ]||refuse malformed-provider "$rel"
        [ "$(sed -n '1p' "$entry")" = '#!/usr/bin/env bash' ]||refuse malformed-provider "$rel"
        grep -qxF 'schema=tracker@1' "$entry"||refuse malformed-provider "$rel"
        ;;
      receipts.tsv) ;;
      *.tsv)
        stem="${base%.tsv}";valid_stem "$stem"||refuse mixed-source "$rel"
        validate_queue "$stem" "$entry";queues+=("$stem")
        ;;
      *)refuse mixed-source "$rel";;
    esac
  done
  for base in README.md DEBRIEF.md trackers.sh receipts.tsv;do
    [ -f "$source_abs/$base" ]&&[ ! -L "$source_abs/$base" ]||refuse missing-source-entry "$base"
  done
  validate_receipts
  validate_prompt
  readme_facts="$("$README_STATUS" "$README_TEMPLATE" "$source_abs/README.md")"||refuse malformed-readme
  readme_state="$(printf '%s\n' "$readme_facts"|sed -n 's/^readme_status=//p')"
  [ "$readme_state" != malformed ]||refuse malformed-readme
}

emit_preview(){
  echo "mode=$mode";echo "source=$source";echo "destination=$destination"
  for rel in "${inventory[@]}";do echo "path=$rel";done
  echo "paths=${#inventory[@]}"
}

preflight
emit_preview
[ "$mode" = apply ]||{ echo 'ready=yes';exit 0;}
preflight
migration_started=yes

if [ "$source" != .trackers ];then
  git -C "$root" mv -- "$source" .trackers
  source_abs="$destination_abs"
fi
mkdir "$destination_abs/tables"
for stem in ${queues[@]+"${queues[@]}"};do
  git -C "$root" mv -- ".trackers/$stem.tsv" ".trackers/tables/$stem.tsv"
done
git -C "$root" mv -- .trackers/receipts.tsv .trackers/history.tsv
history_tmp="$(mktemp "${TMPDIR:-/tmp}/backlog-history.XXXXXX")";tmp_files+=("$history_tmp")
LC_ALL=C perl -pe 's/\Areceipt-([1-9][0-9]*)\t/event-$1\t/' "$destination_abs/history.tsv">"$history_tmp"
mv "$history_tmp" "$destination_abs/history.tsv"

if [ -n "${BACKLOG_MIGRATE_TEST_AFTER_MOVE:-}" ];then
  [ -x "$BACKLOG_MIGRATE_TEST_AFTER_MOVE" ]||refuse test-hook
  "$BACKLOG_MIGRATE_TEST_AFTER_MOVE" "$root" "$source" "$destination"
fi

setup_out="$(mktemp "${TMPDIR:-/tmp}/backlog-migrate-setup.XXXXXX")";tmp_files+=("$setup_out")
if ! "$SETUP" "$root" --apply >"$setup_out";then cat "$setup_out";die 'Backlog setup failed after migration';fi
cat "$setup_out"
provider="$destination_abs/trackers.sh"
[ -x "$provider" ]||die 'current provider missing after migration'
[ "$("$provider" describe|sed -n 's/^schema=//p')" = tracker@2 ]||die 'current provider validation failed'
"$provider" catalog >/dev/null
"$provider" history --limit 1 >/dev/null
for stem in ${queues[@]+"${queues[@]}"};do "$provider" page --tracker "$stem" --status all --limit 1 >/dev/null;done

pathspecs=("$(literal .trackers)")
if [ "$source" != .trackers ];then pathspecs+=("$(literal "$source")");fi
git -C "$root" reset -q HEAD -- "${pathspecs[@]}"
"$SCOPED" "$root" 'Backlog: migrate tracker@1 to tracker@2' "${pathspecs[@]}"
[ -z "$(git -C "$root" status --porcelain --untracked-files=all)" ]||die 'migration commit left a dirty worktree'
echo "committed=$(git -C "$root" rev-parse HEAD)"
migration_started=no
