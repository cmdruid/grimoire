#!/usr/bin/env bash
# note-mint.sh — mint or stamp a notes/ record. Facts only.
#   note-mint.sh mint  <records-root> <title>
#   note-mint.sh stamp <records-root> <abs-path> [--status <status>]
#
# Uses <records-root>/scripts/records.sh when that file is executable;
# otherwise writes the contract shape itself. Never decides update-vs-mint
# or whether to commit. Never writes history.tsv by hand.
set -euo pipefail

usage() {
  echo "usage: note-mint.sh mint  <records-root> <title>" >&2
  echo "       note-mint.sh stamp <records-root> <abs-path> [--status <status>]" >&2
  exit 2
}

err() { echo "note-mint.sh: $*" >&2; exit 2; }

is_closing() { case "$1" in done|dropped|superseded|consumed) return 0 ;; *) return 1 ;; esac; }

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLED_TPL="$SKILL_DIR/templates/notes.md"

# fill <template> <dest> <title> <date> — same literal substitution as records.sh
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
      print out line
    }
  ' "$1" > "$2"
}

abs_dir() { (cd "$1" && pwd); }

emit() {
  printf 'records-root=%s\n' "$1"
  printf 'path=%s\n' "$2"
  printf 'rel=%s\n' "$3"
  printf 'mode=%s\n' "$4"
}

file_stamp() {
  # file_stamp <abs> <today> [<status>]
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

cmd_mint() {
  [ $# -ge 2 ] || usage
  rr="$1"; title="$2"
  [ -n "$title" ] || err "empty title"
  [ -d "$rr" ] || mkdir -p "$rr"
  rr="$(abs_dir "$rr")"

  if has_records "$rr"; then
    if [ ! -f "$rr/templates/notes.md" ]; then
      mkdir -p "$rr/templates"
      cp "$BUNDLED_TPL" "$rr/templates/notes.md"
    fi
    path="$("$rr/scripts/records.sh" new notes --title "$title")"
    rel="${path#"$rr"/}"
    emit "$rr" "$path" "$rel" "records"
    return 0
  fi

  [ -f "$BUNDLED_TPL" ] || err "bundled template missing: $BUNDLED_TPL"
  slug="$(slug_of "$title")"
  [ -n "$slug" ] || err "title yields an empty slug: $title"
  today="$(date +%Y-%m-%d)"
  mkdir -p "$rr/notes"
  base="$rr/notes/$today-$slug"
  path="$base.md"
  n=2
  while [ -e "$path" ]; do path="$base-$n.md"; n=$((n + 1)); done
  fill "$BUNDLED_TPL" "$path" "$title" "$today"
  rel="${path#"$rr"/}"
  emit "$rr" "$path" "$rel" "file"
}

cmd_stamp() {
  [ $# -ge 2 ] || usage
  rr="$1"; path="$2"; shift 2
  status=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --status) [ $# -ge 2 ] || usage; status="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -d "$rr" ] || err "records-root not a directory: $rr"
  rr="$(abs_dir "$rr")"
  [ -f "$path" ] || err "no such file: $path"

  if has_records "$rr"; then
    case "$path" in
      "$rr"/*)
        if [ -n "$status" ] && is_closing "$status"; then
          "$rr/scripts/records.sh" done "$path" --as "$status" >/dev/null
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
        file_stamp "$path" "$(date +%Y-%m-%d)" "$status"
        mode="stamp"
        ;;
    esac
  else
    file_stamp "$path" "$(date +%Y-%m-%d)" "$status"
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
