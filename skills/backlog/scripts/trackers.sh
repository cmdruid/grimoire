#!/usr/bin/env bash
# trackers.sh — the sole writer for Backlog-owned living TSV trackers.
set -euo pipefail

die() { echo "reason=$1${2:+ detail=$2}" >&2; exit 2; }
usage() { die usage; }

valid_rel() {
  [ -n "$1" ] || return 1
  case "$1" in /*) return 1 ;; esac
  case "/$1/" in */../*) return 1 ;; esac
}
valid_stem() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; }
valid_date() { [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; }
valid_link() { [ -z "$1" ] || valid_rel "$1"; }

ROOT=""; WS_REL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ $# -ge 2 ] || usage; ROOT="$2"; shift 2 ;;
    --workspace) [ $# -ge 2 ] || usage; WS_REL="$2"; shift 2 ;;
    *) break ;;
  esac
done
[ -n "$ROOT" ] && [ -n "$WS_REL" ] && [ $# -gt 0 ] || usage
case "$ROOT" in /*) ;; *) die unsafe-root "$ROOT" ;; esac
[ -d "$ROOT" ] || die unsafe-root "$ROOT"
ROOT="$(cd "$ROOT" && pwd)"
valid_rel "$WS_REL" || die unsafe-workspace "$WS_REL"

SKILL="$(cd "$(dirname "$0")/.." && pwd)"
WS="$ROOT/$WS_REL"
BASE="$WS/backlog"
TRACKERS="$BASE/trackers"
COOKBOOK="$BASE/hooks/debrief.md"
HEADER=$'id\tstatus\tcreated\tcompleted\ttext\tlink'

safe_tree() {
  local rel="$1" current="$ROOT" segment old_ifs
  valid_rel "$rel" || die unsafe-path "$rel"
  old_ifs="$IFS"; IFS=/
  for segment in $rel; do
    [ -n "$segment" ] || continue
    current="$current/$segment"
    [ ! -L "$current" ] || die symlink "$current"
    [ ! -e "$current" ] || [ -d "$current" ] || die incompatible-entry "$current"
    [ -d "$current" ] || mkdir "$current"
  done
  IFS="$old_ifs"
}

safe_read_path() {
  local rel="$1" current="$ROOT" segment old_ifs
  old_ifs="$IFS"; IFS=/
  for segment in $rel; do
    [ -n "$segment" ] || continue
    current="$current/$segment"
    [ ! -L "$current" ] || die symlink "$current"
    [ ! -e "$current" ] || [ -d "$current" ] || die incompatible-entry "$current"
  done
  IFS="$old_ifs"
}

prepare_write() {
  safe_tree "$WS_REL/backlog/trackers"
  safe_tree "$WS_REL/backlog/hooks"
  [ ! -L "$COOKBOOK" ] || die symlink "$COOKBOOK"
  [ ! -e "$COOKBOOK" ] || [ -f "$COOKBOOK" ] || die incompatible-entry "$COOKBOOK"
}

tracker_path() { valid_stem "$1" || die invalid-stem "$1"; printf '%s/%s.tsv\n' "$TRACKERS" "$1"; }

validate_tracker() {
  local stem="$1" file="$2"
  [ -f "$file" ] || die no-tracker "$stem"
  [ ! -L "$file" ] || die symlink "$file"
  awk -F '\t' -v stem="$stem" -v header="$HEADER" '
    NR==1 { if ($0 != header) exit 10; next }
    /^# highwater=[0-9]+$/ { if (seen_hw++) exit 11; hw=substr($0,13)+0; next }
    /^# migrated=[^[:space:]].*$/ { v=$0; sub(/^# migrated=/,"",v); if (migrated[v]++) exit 24; next }
    /^#/ { exit 12 }
    {
      if (NF != 6) exit 13
      if ($1 !~ ("^" stem "-[1-9][0-9]*$")) exit 14
      if (seen[$1]++) exit 15
      n=$1; sub("^" stem "-", "", n); if (n+0 > max) max=n+0
      if ($2 != "open" && $2 != "done") exit 16
      if ($3 !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) exit 17
      if ($2 == "open" && $4 != "") exit 18
      if ($2 == "done" && $4 !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) exit 19
      if ($5 == "") exit 20
      if ($6 ~ /^\// || ("/" $6 "/") ~ /\/\.\.\//) exit 21
    }
    END { if (NR < 1) exit 22; if (seen_hw && hw < max) exit 23; print max+0, (seen_hw ? hw : max)+0 }
  ' "$file" || die malformed-tracker "$stem"
}

create_tracker() {
  local stem="$1" file
  prepare_write; file="$(tracker_path "$stem")"
  [ ! -e "$file" ] || return 0
  printf '%s\n# highwater=0\n' "$HEADER" > "$file"
  echo "wrote=${file#"$ROOT"/}"
}

# Import normalized legacy rows through the sole writer. Input rows have five
# TSV fields: status, created, completed, text, link. IDs are allocated above
# the existing high-water mark and the source receipt makes replay a no-op.
cmd_migrate_import() {
  local stem="" source="" rows="" file facts max hw count=0 next tmp
  while [ $# -gt 0 ]; do case "$1" in
    --tracker) stem="${2:-}"; shift 2;; --source) source="${2:-}"; shift 2;;
    --rows) rows="${2:-}"; shift 2;; *) usage;; esac; done
  valid_stem "$stem" || die invalid-stem "$stem"
  valid_rel "$source" || die unsafe-source "$source"
  [ -f "$rows" ] && [ ! -L "$rows" ] || die no-rows "$rows"
  file="$(tracker_path "$stem")"; facts="$(validate_tracker "$stem" "$file")"; read -r max hw <<< "$facts"
  if grep -qxF -- "# migrated=$source" "$file"; then echo "changes=0"; return; fi
  awk -F '\t' '
    NF!=5 {exit 10}
    $1!="open" && $1!="done" {exit 11}
    $2!~/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ {exit 12}
    $1=="open" && $3!="" {exit 13}
    $1=="done" && $3!~/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ {exit 14}
    $4=="" || $4~/[\t\n]/ {exit 15}
    $5~/^\// || ("/"$5"/")~/\/\.\.\// {exit 16}
  ' "$rows" || die malformed-migration-rows "$rows"
  count="$(wc -l < "$rows" | tr -d ' ')"
  [ "$count" -gt 0 ] || die empty-migration "$rows"
  (( hw > max )) && next=$((hw+1)) || next=$((max+1))
  tmp="$file.tmp.$$"
  awk -F '\t' -v OFS='\t' -v hw="$((next+count-1))" -v receipt="# migrated=$source" '
    NR==1 {print; print "# highwater="hw; print receipt; next}
    /^# highwater=/ {next}
    {print}
  ' "$file" > "$tmp"
  awk -F '\t' -v OFS='\t' -v stem="$stem" -v start="$next" '{print stem "-" (start+NR-1),$1,$2,$3,$4,$5}' "$rows" >> "$tmp"
  mv "$tmp" "$file"
  echo "changes=$count"; echo "wrote=${file#"$ROOT"/}"
}

module_count() {
  local stem="$1"
  [ -f "$COOKBOOK" ] || { echo 0; return; }
  awk -v h="## $stem" '$0==h {n++} END {print n+0}' "$COOKBOOK"
}

append_module() {
  local stem="$1" source="${2:-}" tmp
  prepare_write
  [ "$(module_count "$stem")" -eq 0 ] || return 0
  tmp="$COOKBOOK.tmp.$$"
  if [ -f "$COOKBOOK" ]; then cp "$COOKBOOK" "$tmp"; else : > "$tmp"; fi
  [ ! -s "$tmp" ] || printf '\n' >> "$tmp"
  if [[ "$source" == builtin:* ]]; then
    builtin="${source#builtin:}"
    printf '## %s\n\n' "$builtin" >> "$tmp"
    case "$builtin" in
      tasks) echo 'File concrete, cold-actionable work that changes the project. Keep one outcome per item.' >> "$tmp" ;;
      issues) echo 'File what is wrong or risky, where it bites, and any evidence a future reader needs.' >> "$tmp" ;;
      feedback) echo 'File concrete friction or a useful observation from doing the work, including the affected skill or workflow.' >> "$tmp" ;;
    esac
  elif [ -n "$source" ]; then
    awk 'BEGIN{p=0} /^## /{p=1} p{print}' "$source" >> "$tmp"
  else
    printf "## %s\n\nDescribe which finished-work leftovers belong in \`%s\`.\n" "$stem" "$stem" >> "$tmp"
  fi
  mv "$tmp" "$COOKBOOK"
  echo "wrote=${COOKBOOK#"$ROOT"/}"
}

remove_module() {
  local stem="$1" tmp
  [ -f "$COOKBOOK" ] || return 0
  tmp="$COOKBOOK.tmp.$$"
  awk -v h="## $stem" '
    /^## / {skip=($0==h)}
    !skip {print}
  ' "$COOKBOOK" > "$tmp"
  mv "$tmp" "$COOKBOOK"
  echo "wrote=${COOKBOOK#"$ROOT"/}"
}

suggestion() { printf '%s/suggestions/%s.md\n' "$SKILL" "$1"; }
is_builtin() { case "$1" in tasks|issues|feedback) return 0;; *) return 1;; esac; }

reconcile() {
  local stem="$1" strict="$2" src tracker_present=false module_present=false count
  valid_stem "$stem" || die invalid-stem "$stem"
  src="$(suggestion "$stem")"
  if [ ! -f "$src" ]; then
    if is_builtin "$stem"; then src="builtin:$stem"; elif [ "$strict" = custom ]; then src=""; else die unknown-stem "$stem"; fi
  fi
  [ -f "$TRACKERS/$stem.tsv" ] && tracker_present=true
  count="$(module_count "$stem")"; [ "$count" -le 1 ] || die duplicate-module "$stem"
  [ "$count" -eq 1 ] && module_present=true
  if [ "$tracker_present" = true ]; then validate_tracker "$stem" "$TRACKERS/$stem.tsv" >/dev/null; fi
  if [ "$tracker_present" = true ] && [ "$module_present" = true ]; then
    [ "$strict" = setup ] || die incumbent "$stem"
    echo "incumbent=$stem"; return
  fi
  if [ "$tracker_present" = false ]; then
    create_tracker "$stem"
    if [ "${BACKLOG_TEST_FAIL_AFTER_FIRST_COMPONENT:-0}" = 1 ]; then die injected-failure "$stem"; fi
  fi
  [ "$module_present" = true ] || append_module "$stem" "$src"
}

cmd_setup() {
  case "${1:-}" in
    --list)
      printf '%s\n' \
        $'stem=feedback\ttitle=Feedback\tuse-when="Developer-experience friction and observations."' \
        $'stem=issues\ttitle=Issues\tuse-when="Project problems, risks, and limitations."' \
        $'stem=tasks\ttitle=Tasks\tuse-when="Work someone should build or change."'
      ;;
    --apply)
      shift; [ $# -gt 0 ] || usage
      for stem in "$@"; do reconcile "$stem" setup; done
      ;;
    *) usage ;;
  esac
}

cmd_add() {
  local stem="" text="" link="" created file facts max hw next tmp
  created="$(date +%Y-%m-%d)"
  while [ $# -gt 0 ]; do case "$1" in
    --tracker) stem="${2:-}"; shift 2;; --text) text="${2:-}"; shift 2;;
    --link) link="${2:-}"; shift 2;; --created) created="${2:-}"; shift 2;; *) usage;; esac; done
  valid_stem "$stem" || die invalid-stem "$stem"
  [ -n "$text" ] && [[ "$text" != *$'\t'* ]] && [[ "$text" != *$'\n'* ]] || die invalid-text
  valid_link "$link" || die invalid-link "$link"; valid_date "$created" || die invalid-date "$created"
  file="$(tracker_path "$stem")"; facts="$(validate_tracker "$stem" "$file")"; read -r max hw <<< "$facts"
  (( hw > max )) && next=$((hw+1)) || next=$((max+1))
  tmp="$file.tmp.$$"
  awk -F '\t' -v OFS='\t' -v hw="$next" 'NR==1{print; print "# highwater=" hw; next} /^# highwater=/{next} {print}' "$file" > "$tmp"
  printf '%s-%s\topen\t%s\t\t%s\t%s\n' "$stem" "$next" "$created" "$text" "$link" >> "$tmp"
  mv "$tmp" "$file"; echo "id=$stem-$next"; echo "wrote=${file#"$ROOT"/}"
}

find_id() { printf '%s\n' "${1%-*}"; }

cmd_update() {
  local id="${1:-}" stem file text_set=false link_set=false text="" link="" tmp found
  [ -n "$id" ] || usage; shift; stem="$(find_id "$id")"; valid_stem "$stem" || die invalid-id "$id"
  while [ $# -gt 0 ]; do case "$1" in --text) text_set=true; text="${2:-}"; shift 2;; --link) link_set=true; link="${2:-}"; shift 2;; *) usage;; esac; done
  [ "$text_set" = true ] || [ "$link_set" = true ] || usage
  if [ "$text_set" = true ]; then [ -n "$text" ] && [[ "$text" != *$'\t'* ]] && [[ "$text" != *$'\n'* ]] || die invalid-text; fi
  valid_link "$link" || die invalid-link "$link"
  file="$(tracker_path "$stem")"; validate_tracker "$stem" "$file" >/dev/null; tmp="$file.tmp.$$"
  found="$(awk -F '\t' -v id="$id" '$1==id{n++} END{print n+0}' "$file")"; [ "$found" -eq 1 ] || die no-id "$id"
  awk -F '\t' -v OFS='\t' -v id="$id" -v ts="$text_set" -v ls="$link_set" -v text="$text" -v link="$link" '{if($1==id){if(ts=="true")$5=text;if(ls=="true")$6=link} print}' "$file" > "$tmp"
  mv "$tmp" "$file"; echo "wrote=${file#"$ROOT"/}"
}

complete_file() {
  local file="$1" stem="$2" id="$3" link="$4" today tmp matches
  validate_tracker "$stem" "$file" >/dev/null; today="$(date +%Y-%m-%d)"; tmp="$file.tmp.$$"
  matches="$(awk -F '\t' -v id="$id" -v link="$link" '$2=="open" && ((id!=""&&$1==id)||(link!=""&&$6==link)){n++} END{print n+0}' "$file")"
  [ "$matches" -gt 0 ] || return 1
  awk -F '\t' -v OFS='\t' -v id="$id" -v link="$link" -v d="$today" '{if($2=="open"&&((id!=""&&$1==id)||(link!=""&&$6==link))){$2="done";$4=d} print}' "$file" > "$tmp"
  mv "$tmp" "$file"; echo "wrote=${file#"$ROOT"/}"
}

cmd_complete() {
  local id="" link="" stem="" found=0 file
  if [ "${1:-}" != --link ]; then id="${1:-}"; [ -n "$id" ] || usage; stem="$(find_id "$id")"; file="$(tracker_path "$stem")"; complete_file "$file" "$stem" "$id" "" || die no-id "$id"; return; fi
  link="${2:-}"; shift 2; valid_link "$link" || die invalid-link "$link"
  if [ "${1:-}" = --tracker ]; then stem="${2:-}"; shift 2; fi; [ $# -eq 0 ] || usage
  if [ -n "$stem" ]; then file="$(tracker_path "$stem")"; complete_file "$file" "$stem" "" "$link" && found=1 || true
  else
    for file in "$TRACKERS"/*.tsv; do [ -f "$file" ] || continue; stem="$(basename "$file" .tsv)"; complete_file "$file" "$stem" "" "$link" && found=1 || true; done
  fi
  [ "$found" -eq 1 ] || die no-link "$link"
}

cmd_drop() {
  local id="${1:-}" stem file tmp found facts max hw
  [ -n "$id" ] && [ $# -eq 1 ] || usage; stem="$(find_id "$id")"; file="$(tracker_path "$stem")"
  facts="$(validate_tracker "$stem" "$file")"; read -r max hw <<< "$facts"
  found="$(awk -F '\t' -v id="$id" '$1==id{n++} END{print n+0}' "$file")"; [ "$found" -eq 1 ] || die no-id "$id"
  (( max > hw )) && hw="$max"; tmp="$file.tmp.$$"
  awk -F '\t' -v OFS='\t' -v id="$id" -v hw="$hw" 'NR==1{print; print "# highwater="hw; next} /^# highwater=/{next} $1!=id{print}' "$file" > "$tmp"
  mv "$tmp" "$file"; echo "wrote=${file#"$ROOT"/}"
}

cmd_reorder() {
  local stem="" csv="" file tmp
  while [ $# -gt 0 ]; do case "$1" in --tracker) stem="${2:-}"; shift 2;; --ids) csv="${2:-}"; shift 2;; *) usage;; esac; done
  file="$(tracker_path "$stem")"; validate_tracker "$stem" "$file" >/dev/null; [ -n "$csv" ] || usage; tmp="$file.tmp.$$"
  awk -F '\t' -v OFS='\t' -v csv="$csv" '
    BEGIN{n=split(csv,want,",")}
    /^#/ || NR==1 {head[++h]=$0; next}
    {row[$1]=$0; count++}
    END {if(n!=count)exit 3; for(i=1;i<=n;i++){if(!(want[i] in row)||used[want[i]]++)exit 4} for(i=1;i<=h;i++)print head[i]; for(i=1;i<=n;i++)print row[want[i]]}
  ' "$file" > "$tmp" || { rm -f "$tmp"; die invalid-order "$stem"; }
  mv "$tmp" "$file"; echo "wrote=${file#"$ROOT"/}"
}

cmd_list() {
  local stem="" status=open link="" file open module
  while [ $# -gt 0 ]; do case "$1" in --tracker) stem="${2:-}"; shift 2;; --status) status="${2:-}"; shift 2;; --link) link="${2:-}"; shift 2;; *) usage;; esac; done
  case "$status" in open|done|all) ;; *) usage;; esac
  if [ -n "$stem" ]; then
    file="$(tracker_path "$stem")"; validate_tracker "$stem" "$file" >/dev/null
    awk -F '\t' -v st="$status" -v link="$link" 'NR>1 && $0!~/^#/ && (st=="all"||$2==st) && (link==""||$6==link)' "$file"
    return
  fi
  [ -d "$TRACKERS" ] || return 0
  for file in "$TRACKERS"/*.tsv; do
    [ -f "$file" ] || continue; stem="$(basename "$file" .tsv)"; validate_tracker "$stem" "$file" >/dev/null
    open="$(awk -F '\t' '$2=="open"{n++} END{print n+0}' "$file")"; module=false; [ "$(module_count "$stem")" -eq 1 ] && module=true
    printf 'stem=%s\topen=%s\tmodule=%s\n' "$stem" "$open" "$module"
  done
}

cmd_compile() {
  local stems stem file
  [ -f "$COOKBOOK" ] || return 0
  [ ! -L "$COOKBOOK" ] || die symlink "$COOKBOOK"
  stems="$(awk '/^## /{s=substr($0,4); if(s !~ /^[a-z0-9][a-z0-9-]*$/) exit 3; if(seen[s]++) exit 4; print s}' "$COOKBOOK")" \
    || die malformed-cookbook
  [ -n "$stems" ] || return 0
  while IFS= read -r stem; do
    file="$(tracker_path "$stem")"; validate_tracker "$stem" "$file" >/dev/null
    echo "stem=$stem"
    awk -v h="## $stem" '$0==h{p=1;next} /^## /&&p{exit} p{print}' "$COOKBOOK"
  done < <(printf '%s\n' "$stems" | sort)
}

cmd_tracker_remove() {
  local stem="${1:-}" file count open block=false
  [ -n "$stem" ] && [ $# -eq 1 ] || usage; file="$(tracker_path "$stem")"; count="$(module_count "$stem")"; [ "$count" -le 1 ] || die duplicate-module "$stem"
  [ "$count" -eq 1 ] && block=true
  if [ -f "$file" ]; then validate_tracker "$stem" "$file" >/dev/null; open="$(awk -F '\t' '$2=="open"{n++} END{print n+0}' "$file")"; [ "$open" -eq 0 ] || die open-rows "$stem"; fi
  if [ ! -f "$file" ] && [ "$block" = false ]; then die no-tracker "$stem"; fi
  [ "$block" = false ] || remove_module "$stem"
  if [ "${BACKLOG_TEST_FAIL_AFTER_MODULE_REMOVE:-0}" = 1 ]; then die injected-failure "$stem"; fi
  if [ -f "$file" ]; then rm "$file"; echo "removed=${file#"$ROOT"/}"; fi
}

cmd="$1"; shift
safe_read_path "$WS_REL/backlog"
case "$cmd" in
  setup) cmd_setup "$@";; tracker-add) [ $# -eq 1 ] || usage; src="$(suggestion "$1")"; if [ -f "$src" ]; then reconcile "$1" add; else reconcile "$1" custom; fi;;
  tracker-remove) cmd_tracker_remove "$@";; list) cmd_list "$@";; add) cmd_add "$@";; update) cmd_update "$@";;
  complete) cmd_complete "$@";; drop) cmd_drop "$@";; reorder) cmd_reorder "$@";; compile) cmd_compile "$@";;
  migrate-import) cmd_migrate_import "$@";; *) usage;;
esac
