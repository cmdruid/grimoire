#!/usr/bin/env bash
# note-mint.sh — mint or stamp a notes/ record. Facts only.
#   note-mint.sh mint  <agent-records> <templates-home> <title>
#   note-mint.sh stamp <agent-records> <abs-path> [--status <status>] [--note "<text>"]
#
# Uses <agent-records>/scripts/records.sh when that file is executable
# (`new --template <resolved>`); otherwise writes the contract shape itself.
# Resolves notes.md through the project-templates rule. Never decides
# update-vs-mint or whether to commit. Never writes history.tsv by hand.
# Never writes the flat <agent-records>/templates/notes.md.
set -euo pipefail

usage() {
  echo "usage: note-mint.sh mint  <agent-records> <templates-home> <title>" >&2
  echo "       note-mint.sh stamp <agent-records> <abs-path> [--status <status>] [--note \"<text>\"]" >&2
  exit 2
}

err() { echo "note-mint.sh: $*" >&2; exit 2; }

is_disposition() { case "$1" in done|dropped|superseded|consumed) return 0 ;; *) return 1 ;; esac; }

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_NAME="notepad"
BUNDLED_TPL="$SKILL_DIR/templates/notes.md"

fill() {
  TITLE="$3" DATE="$4" TAGS="${5:-}" awk '
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
      out = ""
      while ((i = index(line, "<tags>")) > 0) {
        out = out substr(line, 1, i - 1) ENVIRON["TAGS"]
        line = substr(line, i + 6)
      }
      print out line
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
  awk -v today="$2" -v st="${3:-}" '
    BEGIN { infm = 0; fmdone = 0 }
    NR == 1 && $0 == "---" { infm = 1; print; next }
    infm && !fmdone && $0 == "---" { fmdone = 1; infm = 0; print; next }
    infm && /^updated:/ { print "updated: " today; next }
    infm && st != "" && /^status:/ { print "status: " st; next }
    { print }
  ' "$1" > "$tmp" && mv "$tmp" "$1"
}

slug_of() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-\{1,\}//' -e 's/-\{1,\}$//'
}

has_records() {
  [ -x "$1/scripts/records.sh" ]
}

# resolve_notes_template <agent-records> <templates-home>
resolve_notes_template() {
  local rr="$1" at="$2"
  local dest="$at/$SKILL_NAME/notes.md"
  local prev="$rr/templates/$SKILL_NAME/notes.md"
  local flat="$rr/templates/notes.md"
  [ -f "$BUNDLED_TPL" ] || err "bundled template missing: $BUNDLED_TPL"
  if [ -f "$dest" ]; then
    printf '%s\n' "$dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [ -f "$prev" ]; then
    cp "$prev" "$dest"
  elif [ -f "$flat" ]; then
    cp "$flat" "$dest"
  else
    cp "$BUNDLED_TPL" "$dest"
  fi
  printf '%s\n' "$dest"
}

cmd_mint() {
  [ $# -ge 3 ] || usage
  rr="$1"; at="$2"; title="$3"
  [ -n "$title" ] || err "empty title"
  [ -d "$rr" ] || mkdir -p "$rr"
  [ -d "$at" ] || mkdir -p "$at"
  rr="$(abs_dir "$rr")"
  at="$(abs_dir "$at")"

  tpl="$(resolve_notes_template "$rr" "$at")"

  if has_records "$rr"; then
    path="$("$rr/scripts/records.sh" new notes --template "$tpl" --title "$title")"
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
  fill "$tpl" "$path" "$title" "$today"
  rel="${path#"$rr"/}"
  emit "$rr" "$path" "$rel" "file"
}

cmd_stamp() {
  [ $# -ge 2 ] || usage
  rr="$1"; path="$2"; shift 2
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

  if has_records "$rr"; then
    case "$path" in
      "$rr"/*)
        if [ -n "$status" ] && is_disposition "$status"; then
          if [ -n "$note" ]; then
            "$rr/scripts/records.sh" "done" "$path" --as "$status" --note "$note" >/dev/null
          else
            "$rr/scripts/records.sh" "done" "$path" --as "$status" >/dev/null
          fi
          mode="records"
        else
          if [ -n "$status" ]; then
            "$rr/scripts/records.sh" touch "$path" --status "$status" >/dev/null
          else
            "$rr/scripts/records.sh" touch "$path" >/dev/null
          fi
          mode="records"
        fi
        ;;
      *)
        if is_disposition "$status"; then
          file_stamp "$path" "$(date +%Y-%m-%d)" "archived"
        else
          file_stamp "$path" "$(date +%Y-%m-%d)" "$status"
        fi
        mode="stamp"
        ;;
    esac
  else
    if is_disposition "$status"; then
      file_stamp "$path" "$(date +%Y-%m-%d)" "archived"
    else
      file_stamp "$path" "$(date +%Y-%m-%d)" "$status"
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
