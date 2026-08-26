#!/usr/bin/env bash
# note-mint.sh — mint or stamp a notes/ record. Facts only.
#   note-mint.sh mint  <root> <records-root> <workspace> <title>
#   note-mint.sh stamp <root> <records-root> <workspace> <abs-path> [--status <status>] [--note "<text>"]
#
# Uses <agent-workspace>/journal/scripts/records.sh when that file is executable
# (`new --schema notepad/note@1 --template <resolved>`); otherwise writes the contract shape itself.
# Resolves notes.md through the project-templates rule, using the bundled file
# read-only when no project incumbent exists. Never decides
# update-vs-mint or whether to commit. Never writes history.tsv by hand.
# Never writes the flat <agent-records>/templates/notes.md.
set -euo pipefail

usage() {
  echo "usage: note-mint.sh mint  <root> <records-root> <workspace> <title>" >&2
  echo "       note-mint.sh stamp <root> <records-root> <workspace> <abs-path> [--status <status>] [--note \"<text>\"]" >&2
  exit 2
}

err() { echo "note-mint.sh: $*" >&2; exit 2; }

is_disposition() { case "$1" in done|dropped|superseded|consumed) return 0 ;; *) return 1 ;; esac; }

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_NAME="notepad"
BUNDLED_TPL="$SKILL_DIR/templates/notes.md"

fill() {
  TITLE="$3" DATE="$4" awk '
    {
      line = $0
      out = ""
      while ((i = index(line, "<title>")) > 0) {
        out = out substr(line, 1, i - 1) ENVIRON["TITLE"]
        line = substr(line, i + 7)
      }
      line = out line
      out = ""
      while ((i = index(line, "<date>")) > 0) {
        out = out substr(line, 1, i - 1) ENVIRON["DATE"]
        line = substr(line, i + 6)
      }
      line = out line
      print line
    }
  ' "$1" > "$2"
}

abs_dir() { (cd "$1" && pwd); }

emit() {
  printf 'agent-records=%s\n' "$1"
  printf 'records-root=%s\n' "$1"
  printf 'path=%s\n' "$2"
  printf 'rel=%s\n' "$3"
  printf 'mode=%s\n' "$4"
}

file_stamp() {
  tmp="$1.tmp"
  awk -v st="${2:-}" '
    BEGIN { infm = 0; fmdone = 0 }
    NR == 1 && $0 == "---" { infm = 1; print; next }
    infm && !fmdone && $0 == "---" { fmdone = 1; infm = 0; print; next }
    infm && st != "" && /^status:/ { print "status: " st; next }
    { print }
  ' "$1" > "$tmp" && mv "$tmp" "$1"
}

slug_of() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-\{1,\}//' -e 's/-\{1,\}$//'
}

valid_rel() {
  [ -n "$1" ] || return 1
  case "$1" in /*) return 1 ;; esac
  case "/$1/" in */../*) return 1 ;; esac
}

safe_tree() {
  local rel="$2" current="$1" segment old_ifs
  valid_rel "$rel" || err "unsafe relative path: $rel"
  old_ifs="$IFS"; IFS=/
  for segment in $rel; do
    [ -n "$segment" ] || continue
    current="$current/$segment"
    [ ! -L "$current" ] || err "symlinked destination parent: $current"
    [ ! -e "$current" ] || [ -d "$current" ] || err "destination parent is not a directory: $current"
    [ -d "$current" ] || mkdir "$current"
  done
  IFS="$old_ifs"
}

check_existing_tree() {
  local rel="$2" current="$1" segment old_ifs
  valid_rel "$rel" || err "unsafe relative path: $rel"
  old_ifs="$IFS"; IFS=/
  for segment in $rel; do
    [ -n "$segment" ] || continue
    current="$current/$segment"
    [ ! -L "$current" ] || err "symlinked destination parent: $current"
    if [ -e "$current" ]; then
      [ -d "$current" ] || err "destination parent is not a directory: $current"
    else
      break
    fi
  done
  IFS="$old_ifs"
}

init_paths() {
  root="$1"; rr_rel="$2"; ws_rel="$3"; create="${4:-no}"
  case "$root" in /*) ;; *) err "root must be absolute: $root" ;; esac
  [ -d "$root" ] || err "root is not a directory: $root"
  root="$(abs_dir "$root")"
  valid_rel "$rr_rel" || err "unsafe records root: $rr_rel"
  valid_rel "$ws_rel" || err "unsafe workspace: $ws_rel"
  if [ "$create" = yes ]; then
    safe_tree "$root" "$rr_rel"
  fi
  check_existing_tree "$root" "$ws_rel/$SKILL_NAME/templates"
  rr="$root/$rr_rel"
  at="$root/$ws_rel/$SKILL_NAME/templates"
  engine="$root/$ws_rel/journal/scripts/records.sh"
}

has_records() {
  [ -x "$engine" ]
}

# resolve_notes_template <agent-records> <templates-home>
resolve_notes_template() {
  local rr="$1" at="$2"
  local dest="$at/notes.md"
  local prev="$rr/templates/$SKILL_NAME/notes.md"
  local flat="$rr/templates/notes.md"
  [ -f "$BUNDLED_TPL" ] || err "bundled template missing: $BUNDLED_TPL"
  [ ! -L "$dest" ] || err "project template is a symlink: $dest"
  if [ -f "$dest" ]; then
    if awk 'NR==1 && $0=="---"{fm=1;next} fm && $0=="---"{exit} fm && /^schema:/{found=1} END{exit !found}' "$dest"; then
      err "project template cannot select a schema: $dest"
    fi
    printf '%s\n' "$dest"
    return 0
  fi
  [ ! -e "$dest" ] || err "project template is not a regular file: $dest"
  [ ! -L "$prev" ] && [ ! -e "$prev" ] || err "legacy notes template found; run /notepad migrate $prev before minting"
  [ ! -L "$flat" ] && [ ! -e "$flat" ] || err "legacy notes template found; run /notepad migrate $flat before minting"
  printf '%s\n' "$BUNDLED_TPL"
}

cmd_mint() {
  [ $# -ge 4 ] || usage
  init_paths "$1" "$2" "$3" yes
  title="$4"
  [ -n "$title" ] || err "empty title"
  tpl="$(resolve_notes_template "$rr" "$at")"

  if has_records; then
    path="$("$engine" --root "$root" --records-root "$rr_rel" new notes --schema notepad/note@1 --template "$tpl" --title "$title")"
    rel="${path#"$rr"/}"
    emit "$rr" "$path" "$rel" "records"
    return 0
  fi

  slug="$(slug_of "$title")"
  [ -n "$slug" ] || err "title yields an empty slug: $title"
  today="$(date +%Y-%m-%d)"
  mkdir -p "$rr/notes"
  base="$rr/notes/$today-$slug"
  path="$base.md"
  n=2
  while [ -e "$path" ]; do path="$base-$n.md"; n=$((n + 1)); done
  body="$path.body"
  fill "$tpl" "$body" "$title" "$today"
  {
    printf '%s\n' '---' 'doctype: notes' 'status: draft' 'schema: notepad/note@1' 'tags: []' '---' ''
    cat "$body"
  } > "$path"
  rm -f "$body"
  rel="${path#"$rr"/}"
  emit "$rr" "$path" "$rel" "file"
}

cmd_stamp() {
  [ $# -ge 4 ] || usage
  init_paths "$1" "$2" "$3"
  path="$4"; shift 4
  status=""
  note=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --status) [ $# -ge 2 ] || usage; status="$2"; shift 2 ;;
      --note)   [ $# -ge 2 ] || usage; note="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -d "$rr" ] || err "agent-records home not a directory: $rr"
  rr="$(abs_dir "$rr")"
  [ -f "$path" ] || err "no such file: $path"

  if has_records; then
    case "$path" in
      "$rr"/*)
        if [ -n "$status" ] && is_disposition "$status"; then
          if [ -n "$note" ]; then
            "$engine" --root "$root" --records-root "$rr_rel" "done" "$path" --as "$status" --note "$note" >/dev/null
          else
            "$engine" --root "$root" --records-root "$rr_rel" "done" "$path" --as "$status" >/dev/null
          fi
          mode="records"
        else
          if [ -n "$status" ]; then
            "$engine" --root "$root" --records-root "$rr_rel" touch "$path" --status "$status" >/dev/null
          else
            "$engine" --root "$root" --records-root "$rr_rel" touch "$path" >/dev/null
          fi
          mode="records"
        fi
        ;;
      *)
        if is_disposition "$status"; then
          file_stamp "$path" "archived"
        else
          file_stamp "$path" "$status"
        fi
        mode="stamp"
        ;;
    esac
  else
    if is_disposition "$status"; then
      file_stamp "$path" "archived"
    else
      file_stamp "$path" "$status"
    fi
    mode="stamp"
  fi
  rel="${path#"$rr"/}"
  emit "$rr" "$path" "$rel" "$mode"
}

[ $# -ge 1 ] || usage
cmd="$1"; shift
case "$cmd" in
  mint)  cmd_mint "$@" ;;
  stamp) cmd_stamp "$@" ;;
  *) usage ;;
esac
