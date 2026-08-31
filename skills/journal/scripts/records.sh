#!/bin/sh
# records.sh — record query + lifecycle for the canonical .records layer.
# Journal's deployed asset: the source of truth lives in the journal skill;
# setup stages it at .records/records.sh beside the README and ledger. The
# canonical installed location selects the project and data roots. The script owns the facts —
# dates, paths, conformance — so agents never guess them.
#
#   .records/records.sh list [--type t] ...
#   .records/records.sh grep [--type t] [--status s] [--tag g] [--since d] [--until d] [--stage s] <pattern>
#   .records/records.sh show <path>
#   .records/records.sh new <doctype> --schema <writer/artifact@N> --title "..." [--template <body-path>] [--dir rel] [--tag t]...
#   .records/records.sh touch <path> [--status draft|published]
#   .records/records.sh done <path> [--as done|dropped|superseded|consumed] [--note "..."]
#   .records/records.sh history [--type t] [--disposition d] [--since d] [--until d] [--grep pat]
#   .records/records.sh prune-candidates [--until d]
#   .records/records.sh check
#   .records/records.sh relocate <source> --to <destination-relative> [--staged <path>]
#
# A file is a RECORD iff it is named YYYY-MM-DD-<slug>.md AND carries a
# front-matter block that declares a doctype. That is the whole discriminator:
# the tool crawls the root at any depth and knows no store names, so directory
# layout beneath fixed `.records` is the writers' business. Journal's README,
# provider, ledger, and any other non-record files simply fail the discriminator.
# The authoritative doctype is the front-matter key, never the parent
# directory. `list`/`history` emit TSV — grep/awk-friendly, no parser needed.
# Querying is a live scan (no stored index). Closure stamps the file `archived`
# and appends `--as` to history.tsv — the ledger's sole writer. `list` default
# is the live set (`draft` ∪ `published`). The path is the ID.
# Exit codes: 0 ok · 1 usage · 2 error / check failure.
set -eu

TAB="$(printf '\t')"
NL="$(printf '\n/')"
NL="${NL%/}"

usage() {
  cat >&2 <<'EOF'
usage: .records/records.sh <command> [args]
  list    [--type t] [--status s] [--tag g] [--since d] [--until d] [--stage s]
  grep    [--type t] [--status s] [--tag g] [--since d] [--until d] [--stage s] <pattern>
  show    <path>
  new     <doctype> --schema <writer/artifact@N> --title "..." [--template <body-path>] [--dir rel] [--tag t]...
  touch   <path> [--status draft|published]
  done    <path> [--as done|dropped|superseded|consumed] [--note "..."]
  history [--type t] [--disposition d] [--since d] [--until d] [--grep pat]
  prune-candidates [--until d]
  check
  relocate <source> --to <destination-relative> [--staged <path>]
EOF
  exit 1
}

err() { echo "records.sh: $*" >&2; exit 2; }

# valid_rel_dir <rel>: caller-named directory under $RR — relative, nonempty,
# no leading /, no `..` segment (including `foo/../bar` and a bare `..`).
valid_rel_dir() {
  [ -n "$1" ] || return 1
  case "$1" in /*) return 1 ;; esac
  case "/$1/" in */../*) return 1 ;; esac
  return 0
}

valid_rel_file() {
  valid_rel_dir "$1" || return 1
  case "$1" in */|.) return 1 ;; esac
  return 0
}

safe_components() { # <base> <relative>; reject every existing symlink component
  base="$1"; path_rel="$2"; current="$base"; old_ifs=$IFS
  IFS='/'; set -- $path_rel; IFS=$old_ifs
  for part in "$@"; do
    [ -n "$part" ] || continue
    current="$current/$part"
    [ ! -L "$current" ] || return 1
  done
}

case "$0" in /*) SCRIPT_PATH="$0" ;; *) SCRIPT_PATH="$PWD/$0" ;; esac
SCRIPT_PARENT="${SCRIPT_PATH%/*}"
[ "${SCRIPT_PATH##*/}" = records.sh ] || err "provider must be installed at <project-root>/.records/records.sh"
[ ! -L "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ] || err "provider path is unsafe: $SCRIPT_PATH"
[ "${SCRIPT_PARENT##*/}" = .records ] && [ ! -L "$SCRIPT_PARENT" ] && [ -d "$SCRIPT_PARENT" ] ||
  err "provider must be installed at <project-root>/.records/records.sh"
RR="$(CDPATH='' cd -P "$SCRIPT_PARENT" && pwd)"
ROOT="$(CDPATH='' cd -P "$RR/.." && pwd)"
[ "$RR" = "$ROOT/.records" ] || err "provider must be installed at <project-root>/.records/records.sh"
GIT_ROOT="$(git -C "$RR" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$GIT_ROOT" ]; then
  GIT_ROOT="$(CDPATH='' cd -P "$GIT_ROOT" && pwd)"
  [ "$GIT_ROOT" = "$ROOT" ] || err "provider must be installed at the Git project root's .records/records.sh"
fi
LEDGER="$RR/history.tsv"

is_disposition() { case "$1" in done|dropped|superseded|consumed) return 0 ;; *) return 1 ;; esac; }
is_archived()    { [ "$1" = archived ]; }
is_status()      { case "$1" in draft|published|archived) return 0 ;; *) return 1 ;; esac; }
is_schema()      { printf '%s\n' "$1" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*/[a-z0-9]+(-[a-z0-9]+)*@[1-9][0-9]*$'; }

# resolve <path-arg>: sets abs + rel (rel is relative to .records, the ledger form).
resolve() {
  if [ -f "$1" ]; then
    abs="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  elif [ -f "$RR/$1" ]; then
    abs="$RR/$1"
  else
    err "no such record: $1"
  fi
  case "$abs" in
    "$RR"/*) rel="${abs#"$RR"/}" ;;
    *) err "not under the records root ($RR): $abs" ;;
  esac
  is_record "$abs" || err "not a record: $rel"
}

# is_record <abs>: THE discriminator, and the only one. Two conjuncts:
#
#   1. the record shape -- YYYY-MM-DD-<slug>.md, which is what `new` mints and
#      what makes the path an ID;
#   2. a front-matter block DECLARING a doctype.
#
# Neither alone is enough. Front matter alone would swallow any non-record
# Markdown file that happens to declare a doctype. The shape alone would swallow
# dated prose. Together they keep the open writer-owned directory layout beneath
# fixed `.records` independent of a reserved store-name roster.
is_record() {
  case "${1##*/}" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md) ;;
    *) return 1 ;;
  esac
  head -1 "$1" | grep -qx -- '---' || return 1
  [ -n "$(fm_field "$1" doctype)" ]
}

# records: paths relative to .records for every record, one per line. A crawl at
# any depth -- this tool knows no store names (a skill creates only the
# directories it needs, so the set is open-ended and unknown here).
records() {
  find "$RR" -type f -name '*.md' | sort | while IFS= read -r f; do
    is_record "$f" || continue
    printf '%s\n' "${f#"$RR"/}"
  done
}

# meta_row <rel>: one TSV row — path·doctype·status·filename-date·tags·title.
# Missing keys print empty fields (list is a lens; `check` is the enforcer).
meta_row() {
  name="${1##*/}"
  day="$(printf '%.10s' "$name")"
  awk -v rel="$1" -v day="$day" '
    BEGIN { infm = 0; fmdone = 0; doctype = ""; status = ""; tags = ""; title = "" }
    NR == 1 { if ($0 == "---") { infm = 1; next } else { exit } }
    infm && $0 == "---" { infm = 0; fmdone = 1; next }
    infm {
      if      ($0 ~ /^doctype:/) { v = $0; sub(/^doctype:[ \t]*/, "", v); doctype = v }
      else if ($0 ~ /^status:/)  { v = $0; sub(/^status:[ \t]*/,  "", v); status  = v }
      else if ($0 ~ /^tags:/)    { v = $0; sub(/^tags:[ \t]*/,    "", v); gsub(/[][ \t]/, "", v); tags = v }
      next
    }
    fmdone && title == "" && /^# / { title = substr($0, 3) }
    END { printf "%s\t%s\t%s\t%s\t%s\t%s\n", rel, doctype, status, day, tags, title }
  ' "$RR/$1"
}

# live=1 → default hide archived; live=0 → no default status filter.
filter_rows() {
  live="$1"
  awk -F'\t' -v t="$f_type" -v s="$f_status" -v g="$f_tag" \
      -v a="$f_since" -v z="$f_until" -v live="$live" '
    function in_set(val, set,   n, arr, i) {
      if (set == "") return 0
      n = split(set, arr, " ")
      for (i = 1; i <= n; i++) if (arr[i] == val) return 1
      return 0
    }
    t != "" && $2 != t { next }
    live && s == "" && $3 != "draft" && $3 != "published" { next }
    s != "" && !in_set($3, s) { next }
    g != "" && index("," $5 ",", "," g ",") == 0 { next }
    a != "" && $4 < a { next }
    z != "" && $4 > z { next }
    { print }
  '
}

stage_ok() {  # rel; f_stage is newline-separated wanted values
  [ "$f_stage_given" -eq 0 ] && return 0
  val="$(fm_field "$RR/$1" stage)"
  val="$(printf '%s' "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ -n "$val" ] || return 1
  printf '%s\n' "$f_stage" | grep -qxF -- "$val"
}

cmd_list() {
  f_type=""; f_status=""; f_tag=""; f_since=""; f_until=""; f_stage=""; f_stage_given=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --type)   [ $# -ge 2 ] || usage; f_type="$2";   shift 2 ;;
      --status)
        [ $# -ge 2 ] || usage
        is_status "$2" || err "unknown status: $2"
        f_status="${f_status:+$f_status }$2"
        shift 2 ;;
      --stage)
        [ $# -ge 2 ] || usage
        f_stage_given=1
        f_stage="${f_stage:+$f_stage$NL}$2"
        shift 2 ;;
      --tag)    [ $# -ge 2 ] || usage; f_tag="$2";    shift 2 ;;
      --since)  [ $# -ge 2 ] || usage; f_since="$2";  shift 2 ;;
      --until)  [ $# -ge 2 ] || usage; f_until="$2";  shift 2 ;;
      *) usage ;;
    esac
  done
  records | while IFS= read -r r; do
    stage_ok "$r" || continue
    meta_row "$r"
  done | filter_rows 1 | sort -t "$TAB" -k4,4r -k1,1
}

cmd_grep() {
  f_type=""; f_status=""; f_tag=""; f_since=""; f_until=""; f_stage=""; f_stage_given=0; pattern=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --type)   [ $# -ge 2 ] || usage; f_type="$2";   shift 2 ;;
      --status)
        [ $# -ge 2 ] || usage
        is_status "$2" || err "unknown status: $2"
        f_status="${f_status:+$f_status }$2"
        shift 2 ;;
      --stage)
        [ $# -ge 2 ] || usage
        f_stage_given=1
        f_stage="${f_stage:+$f_stage$NL}$2"
        shift 2 ;;
      --tag)    [ $# -ge 2 ] || usage; f_tag="$2";    shift 2 ;;
      --since)  [ $# -ge 2 ] || usage; f_since="$2";  shift 2 ;;
      --until)  [ $# -ge 2 ] || usage; f_until="$2";  shift 2 ;;
      --*)      usage ;;
      *)
        [ -z "$pattern" ] || usage
        pattern="$1"
        shift
        ;;
    esac
  done
  [ -n "$pattern" ] || usage
  records | while IFS= read -r r; do
    if awk '
      BEGIN { infm = 0 }
      NR == 1 { if ($0 == "---") { infm = 1; next } }
      infm && $0 == "---" { infm = 0; next }
      infm { next }  # GREP_SKIP_FM
      { print }
    ' "$RR/$r" | grep -q -- "$pattern"; then
      stage_ok "$r" || continue
      meta_row "$r"
    fi
  done | filter_rows 0 | sort -t "$TAB" -k4,4r -k1,1
}

cmd_show() {
  [ $# -eq 1 ] || usage
  resolve "$1"
  cat "$abs"
}

# fill <template> <dest> <title> <date>: literal body-slot substitution (no regex —
# a title may carry any punctuation; same technique as the seed's subst).
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

cmd_new() {
  [ $# -ge 1 ] || usage
  doctype="$1"; shift
  title=""
  schema=""
  tpl=""
  tags=""
  dir=""
  dir_set=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --title)    [ $# -ge 2 ] || usage; title="$2"; shift 2 ;;
      --schema)   [ $# -ge 2 ] || usage; schema="$2"; shift 2 ;;
      --template) [ $# -ge 2 ] || usage; tpl="$2"; shift 2 ;;
      --dir)
        [ $# -ge 2 ] || usage
        dir="$2"
        dir_set=1
        shift 2 ;;
      --tag)
        [ $# -ge 2 ] || usage
        [ -n "$2" ] || err "empty --tag"
        if [ -n "$tags" ]; then tags="$tags, $2"; else tags="$2"; fi
        shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$title" ] || usage
  [ -n "$schema" ] || err "--schema is required"
  is_schema "$schema" || err "invalid schema (want writer/artifact@positive-integer): $schema"
  if [ -n "$tpl" ]; then
    [ -f "$tpl" ] || err "no body template for doctype '$doctype': $tpl"
    grep -qF '<schema>' "$tpl" && err "body template contains forbidden <schema> slot: $tpl"
    grep -qF '<tags>' "$tpl" && err "body template contains forbidden <tags> slot: $tpl"
    [ "$(head -1 "$tpl")" != "---" ] || err "body template must not contain record front matter: $tpl"
  fi
  # Directory is --dir, defaulting to the doctype positional. mkdir is the
  # caller creating that directory through the tool.
  if [ "$dir_set" -eq 0 ]; then
    dir="$doctype"
  fi
  valid_rel_dir "$dir" || err "directory must be a relative path with no .. segment: $dir"
  today="$(date +%Y-%m-%d)"
  slug="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' \
          | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-\{1,\}//' -e 's/-\{1,\}$//')"
  [ -n "$slug" ] || err "title yields an empty slug: $title"
  mkdir -p "$RR/$dir"
  base="$RR/$dir/$today-$slug"
  path="$base.md"
  n=2
  while [ -e "$path" ]; do path="$base-$n.md"; n=$((n + 1)); done
  tmp="$path.tmp"
  {
    printf '%s\n' '---'
    printf 'doctype: %s\n' "$doctype"
    printf 'status: draft\n'
    printf 'schema: %s\n' "$schema"
    printf 'tags: [%s]\n' "$tags"
    printf '%s\n\n' '---'
  } > "$tmp"
  if [ -n "$tpl" ]; then
    body="$path.body"
    fill "$tpl" "$body" "$title" "$today"
    cat "$body" >> "$tmp"
    rm -f "$body"
  else
    printf '# %s\n' "$title" >> "$tmp"
  fi
  mv "$tmp" "$path"
  printf '%s\n' "$path"
}

# stamp <abs> <status>: rewrite status in the front-matter block only.
stamp() {
  tmp="$1.tmp"
  awk -v st="${2:-}" '
    BEGIN { infm = 0; fmdone = 0 }
    NR == 1 && $0 == "---" { infm = 1; print; next }
    infm && !fmdone && $0 == "---" { fmdone = 1; infm = 0; print; next }
    infm && st != "" && /^status:/ { print "status: " st; next }
    { print }
  ' "$1" > "$tmp" && mv "$tmp" "$1"
}

# fm_field <abs> <key>: the key's front-matter value (empty when absent).
fm_field() {
  awk -v key="$2" '
    BEGIN { infm = 0 }
    NR == 1 { if ($0 == "---") { infm = 1; next } else { exit } }
    infm && $0 == "---" { exit }
    infm && index($0, key ":") == 1 { v = substr($0, length(key) + 2); sub(/^[ \t]*/, "", v); print v; exit }
  ' "$1"
}

require_record() { # a mutable current record
  head -1 "$abs" | grep -qx -- '---' || err "no front-matter (not a record?): $rel"
  [ -n "$(fm_field "$abs" status)" ]  || err "front-matter lacks 'status:': $rel"
  schema="$(fm_field "$abs" schema)"
  [ -n "$schema" ] || err "front-matter lacks 'schema:' (run the owning skill's migrate verb): $rel"
  is_schema "$schema" || err "front-matter has invalid schema: $rel"
}

cmd_touch() {
  [ $# -ge 1 ] || usage
  resolve "$1"; shift
  new_status=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --status) [ $# -ge 2 ] || usage; new_status="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  if [ -n "$new_status" ]; then
    is_status "$new_status" || err "unknown status: $new_status"
    is_archived "$new_status" && err "closing status goes through 'done', not 'touch': $new_status"
  fi
  require_record
  stamp "$abs" "$new_status"
  printf '%s\n' "$rel"
}

cmd_done() {
  [ $# -ge 1 ] || usage
  resolve "$1"; shift
  disposition="done"; note="-"
  while [ $# -gt 0 ]; do
    case "$1" in
      --as)   [ $# -ge 2 ] || usage; disposition="$2"; shift 2 ;;
      --note) [ $# -ge 2 ] || usage; note="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  is_disposition "$disposition" || err "unknown disposition: $disposition (done|dropped|superseded|consumed)"
  require_record
  status="$(fm_field "$abs" status)"
  is_archived "$status" && err "already closed ($status): $rel"
  doctype="$(fm_field "$abs" doctype)"
  title="$(awk '/^# /{ print substr($0, 3); exit }' "$abs" | tr '\t' ' ')"
  note="$(printf '%s' "$note" | tr '\t\n' '  ')"
  today="$(date +%Y-%m-%d)"
  : >> "$LEDGER" || err "cannot write ledger: $LEDGER"
  bak="$abs.done-bak"
  cp "$abs" "$bak"
  stamp "$abs" "archived"
  line="$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$today" "$disposition" "$rel" "$doctype" "$title" "$note" | tr '\n' ' ')"
  if ! printf '%s\n' "$line" >> "$LEDGER"; then
    mv "$bak" "$abs"
    err "ledger append failed; record restored: $rel"
  fi
  rm -f "$bak"
  printf '%s\n' "$line"
}

cmd_history() {
  f_type=""; f_disp=""; f_since=""; f_until=""; f_grep=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --type)        [ $# -ge 2 ] || usage; f_type="$2";  shift 2 ;;
      --disposition) [ $# -ge 2 ] || usage; f_disp="$2";  shift 2 ;;
      --since)       [ $# -ge 2 ] || usage; f_since="$2"; shift 2 ;;
      --until)       [ $# -ge 2 ] || usage; f_until="$2"; shift 2 ;;
      --grep)        [ $# -ge 2 ] || usage; f_grep="$2";  shift 2 ;;
      *) usage ;;
    esac
  done
  [ -f "$LEDGER" ] || return 0
  filtered() {
    awk -F'\t' -v t="$f_type" -v d="$f_disp" -v a="$f_since" -v z="$f_until" '
      t != "" && $4 != t { next }
      d != "" && $2 != d { next }
      a != "" && $1 < a { next }
      z != "" && $1 > z { next }
      { print }
    ' "$LEDGER"
  }
  if [ -n "$f_grep" ]; then
    filtered | { grep -- "$f_grep" || true; }
  else
    filtered
  fi
}

# prune-candidates: ledger entries whose record file still exists and is still
# closed — the review station's prune shortlist (curate proposes; the human
# confirms; deletion keeps the ledger line + git history as the trace).
cmd_prune_candidates() {
  f_until=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --until) [ $# -ge 2 ] || usage; f_until="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -f "$LEDGER" ] || return 0
  awk -F'\t' -v z="$f_until" 'z != "" && $1 > z { next } { print }' "$LEDGER" \
    | while IFS="$TAB" read -r d disp record_path dt title note; do
        [ -f "$RR/$record_path" ] || continue
        is_archived "$(fm_field "$RR/$record_path" status)" || continue
        printf '%s\t%s\t%s\t%s\t%s\n' "$d" "$disp" "$record_path" "$dt" "$title"
      done
}

checksum() { cksum "$1" | awk '{ print $1 ":" $2 }'; }

# relocate is Journal's narrow record-identity primitive. The caller may provide
# already-transformed bytes with --staged; Journal owns only the move, ledger,
# and exact inbound record links. Its adjacent manifest makes every phase
# idempotent and forward-resumable.
cmd_relocate() {
  [ $# -ge 1 ] || usage
  source_arg="$1"; shift
  to=""; staged=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --to)     [ $# -ge 2 ] || usage; to="$2"; shift 2 ;;
      --staged) [ $# -ge 2 ] || usage; staged="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$to" ] || err "relocate requires --to <record-relative-path>"
  valid_rel_file "$to" || err "relocation destination must be relative to .records with no .. segment: $to"
  case "${to##*/}" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md) ;;
    *) err "relocation destination is not a dated record path: $to" ;;
  esac

  # Resolve the manifest location without requiring the source to remain. This
  # is what lets a rerun finish after the source-removal phase.
  case "$source_arg" in
    /*)
      case "$source_arg" in "$RR"/*) hinted_rel="${source_arg#"$RR"/}" ;; *) err "relocation source is outside records root: $source_arg" ;; esac
      ;;
    *) hinted_rel="$source_arg" ;;
  esac
  valid_rel_file "$hinted_rel" || err "unsafe relocation source path: $source_arg"
  safe_components "$RR" "$hinted_rel" || err "symlinked relocation source component: $source_arg"
  safe_components "$RR" "$to" || err "symlinked relocation destination component: $to"
  source_hint="$RR/$hinted_rel"
  source_dir="$(dirname "$source_hint")"
  manifest="$source_dir/.journal-relocate-manifest"
  dest="$RR/$to"

  if [ -f "$manifest" ]; then
    old_rel="$(sed -n 's/^source=//p' "$manifest")"
    recorded_to="$(sed -n 's/^destination=//p' "$manifest")"
    before_sum="$(sed -n 's/^before=//p' "$manifest")"
    staged_sum="$(sed -n 's/^staged=//p' "$manifest")"
    phase="$(sed -n 's/^phase=//p' "$manifest")"
    [ "$recorded_to" = "$to" ] || err "relocation manifest targets $recorded_to, not $to"
    source="$RR/$old_rel"
  else
    resolve "$source_arg"
    source="$abs"; old_rel="$rel"
    [ "$old_rel" != "$to" ] || err "relocation source and destination are identical: $to"
    [ ! -e "$dest" ] || err "relocation destination already exists: $to"
    if [ -n "$staged" ]; then
      [ -f "$staged" ] || err "no staged record: $staged"
      staged_input="$staged"
    else
      staged_input="$source"
    fi

    # Preflight external references. Journal rewrites only records it owns.
    refs="$(mktemp "${TMPDIR:-/tmp}/records-relocate-refs.XXXXXX")"
    find "$ROOT" -type f | sort | while IFS= read -r f; do
      case "$f" in
        "$RR"/*|"$ROOT/.git"/*|*.tmp|*migrate-manifest*) continue ;;
      esac
      grep -Iq . "$f" 2>/dev/null || continue
      grep -nHF -- "→ $old_rel" "$f" 2>/dev/null || true
    done > "$refs"
    if [ -s "$refs" ]; then
      cat "$refs" >&2
      rm -f "$refs"
      err "external references block relocation of $old_rel"
    fi
    rm -f "$refs"

    mkdir -p "$(dirname "$dest")"
    staged_file="$dest.relocate-staged"
    # Retarget a self-reference before calculating the staged checksum so the
    # destination remains byte-stable through later link phases.
    awk -v old="→ $old_rel" -v new="→ $to" '
      { line=$0; while ((i=index(line, old)) > 0) { printf "%s%s", substr(line,1,i-1),new; line=substr(line,i+length(old)) } print line }
    ' "$staged_input" > "$staged_file"
    # Validate the staged current profile under its eventual dated name.
    status="$(fm_field "$staged_file" status)"
    schema="$(fm_field "$staged_file" schema)"
    [ -n "$(fm_field "$staged_file" doctype)" ] || err "staged destination lacks doctype: $to"
    is_status "$status" || err "staged destination has invalid status: $to"
    is_schema "$schema" || err "staged destination has invalid schema: $to"
    for retired in created updated created_at updated_at revision; do
      [ -z "$(fm_field "$staged_file" "$retired")" ] || err "staged destination retains reserved key '$retired': $to"
    done
    grep -q '^tags:' "$staged_file" || err "staged destination lacks tags: $to"
    before_sum="$(checksum "$source")"
    staged_sum="$(checksum "$staged_file")"
    phase=0
    {
      printf 'source=%s\n' "$old_rel"
      printf 'destination=%s\n' "$to"
      printf 'before=%s\n' "$before_sum"
      printf 'staged=%s\n' "$staged_sum"
      printf 'phase=0\n'
    } > "$manifest"
  fi

  staged_file="$dest.relocate-staged"
  if [ "$phase" -lt 1 ]; then
    [ -f "$source" ] && [ "$(checksum "$source")" = "$before_sum" ] || err "relocation source no longer matches recorded before checksum: $old_rel"
    [ -f "$staged_file" ] && [ "$(checksum "$staged_file")" = "$staged_sum" ] || err "relocation staged bytes no longer match recorded checksum: $to"
    mv "$staged_file" "$dest"
    sed 's/^phase=.*/phase=1/' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
    phase=1
    [ "${RECORDS_TEST_FAIL_AFTER_PHASE:-}" != 1 ] || err "injected relocation failure after phase 1"
  fi
  if [ "$phase" -lt 2 ]; then
    [ -f "$dest" ] && [ "$(checksum "$dest")" = "$staged_sum" ] || err "relocation destination no longer matches staged checksum: $to"
    if [ -f "$LEDGER" ]; then
      awk -F'\t' -v OFS='\t' -v old="$old_rel" -v new="$to" '{ if ($3 == old) $3 = new; print }' "$LEDGER" > "$LEDGER.tmp" && mv "$LEDGER.tmp" "$LEDGER"
    fi
    sed 's/^phase=.*/phase=2/' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
    phase=2
    [ "${RECORDS_TEST_FAIL_AFTER_PHASE:-}" != 2 ] || err "injected relocation failure after phase 2"
  fi
  if [ "$phase" -lt 3 ]; then
    records | while IFS= read -r r; do
      [ "$r" = "$old_rel" ] && continue
      [ "$r" = "$to" ] && continue
      f="$RR/$r"
      grep -qF -- "→ $old_rel" "$f" || continue
      awk -v old="→ $old_rel" -v new="→ $to" '
        { line=$0; while ((i=index(line, old)) > 0) { printf "%s%s", substr(line,1,i-1),new; line=substr(line,i+length(old)) } print line }
      ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    done
    sed 's/^phase=.*/phase=3/' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
    phase=3
    [ "${RECORDS_TEST_FAIL_AFTER_PHASE:-}" != 3 ] || err "injected relocation failure after phase 3"
  fi
  if [ "$phase" -lt 4 ]; then
    if [ -f "$source" ]; then
      [ "$(checksum "$source")" = "$before_sum" ] || err "relocation source changed before removal: $old_rel"
      rm -f "$source"
    fi
    sed 's/^phase=.*/phase=4/' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
  fi
  rm -f "$manifest" "$staged_file"
  printf 'relocated=%s\t%s\n' "$old_rel" "$to"
}

cmd_check() {
  tmp="$(mktemp "${TMPDIR:-/tmp}/records-check.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  records > "$tmp"
  fails=0
  count=0
  while IFS= read -r rel; do
    count=$((count + 1))
    # Per-record contract: front-matter, the four shared keys, status enum,
    # schema grammar, and no retired generic history keys. The doctype is NOT checked against the parent directory -- the
    # front-matter key is the authority and the directory is the caller's
    # business, so there is no second copy of the fact to disagree with.
    findings="$(awk '
      BEGIN { infm = 0; fmdone = 0 }
      NR == 1 { if ($0 == "---") { infm = 1; next } else { print "no front-matter block"; exit } }
      infm && $0 == "---" { infm = 0; fmdone = 1; next }
      infm {
        if      ($0 ~ /^doctype:/) { v = $0; sub(/^doctype:[ \t]*/, "", v); fm["doctype"] = v; seen["doctype"]++ }
        else if ($0 ~ /^status:/)  { v = $0; sub(/^status:[ \t]*/,  "", v); fm["status"]  = v; seen["status"]++ }
        else if ($0 ~ /^schema:/)  { v = $0; sub(/^schema:[ \t]*/,  "", v); fm["schema"]  = v; seen["schema"]++ }
        else if ($0 ~ /^tags:/)    { fm["tags"] = "present"; seen["tags"]++ }
        else if ($0 ~ /^(created|updated|created_at|updated_at|revision):/) {
          key = $0; sub(/:.*/, "", key); retired[key] = 1
        }
        else if ($0 ~ /^stage:/) {
          v = $0; sub(/^stage:[ \t]*/, "", v); sub(/[ \t]+$/, "", v)
          if (v == "") print "stage is empty"
        }
        next
      }
      END {
        if (!fmdone) { print "unterminated front-matter block"; exit }
        split("doctype status schema tags", keys, " ")
        for (i in keys) {
          if (!(keys[i] in fm)) print "missing key: " keys[i]
          if (seen[keys[i]] > 1) print "duplicate key: " keys[i]
        }
        for (key in retired) print "retired reserved key: " key
        if (("status" in fm) && fm["status"] !~ /^(draft|published|archived)$/)
          print "status not in the contract: " fm["status"]
        if (("schema" in fm) && fm["schema"] !~ /^[a-z0-9]+(-[a-z0-9]+)*\/[a-z0-9]+(-[a-z0-9]+)*@[1-9][0-9]*$/)
          print "schema not in writer/artifact@positive-integer grammar: " fm["schema"]
      }
    ' "$RR/$rel")"
    if [ -n "$findings" ]; then
      printf '%s\n' "$findings" | while IFS= read -r f; do
        echo "FAIL: $rel — $f" >&2
      done
      fails=$((fails + 1))
    fi
    # record links: a body reference `→ <dir>/<file>.md` must resolve at the
    # root (link-rot detection). CODE BLOCKS are skipped -- fenced and
    # four-space-indented alike -- because an example line showing the
    # tracker-line FORM is teaching syntax, not referencing a record. A live
    # link whose first-segment directory is gone is still rot.
    links="$(awk '
      /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
      fence                    { next }
      /^(    |\t)/             { next }
      { print }
    ' "$RR/$rel" 2>/dev/null | grep -o '→ *[A-Za-z0-9._/-]*\.md' | sed 's/^→ *//' | sort -u || true)"
    if [ -n "$links" ]; then
      while IFS= read -r lnk; do
        case "$lnk" in
          */*)
            if ! [ -f "$RR/$lnk" ]; then
              echo "FAIL: $rel — broken link → $lnk" >&2
              fails=$((fails + 1))
            fi ;;
        esac
      done <<LINKS
$links
LINKS
    fi
    status="$(fm_field "$RR/$rel" status)"
    if is_archived "$status"; then
      disp=""
      if [ -f "$LEDGER" ]; then
        disp="$(awk -F'\t' -v p="$rel" '$3 == p { print $2; exit }' "$LEDGER")"
      fi
      if [ -z "$disp" ]; then
        echo "FAIL: $rel — archived but no history.tsv ledger line" >&2
        fails=$((fails + 1))
      fi
      # deliberately no: elif [ "$disp" != "$status" ]
    fi
  done < "$tmp"
  # ledger well-formedness: six tab-separated fields, a known disposition.
  if [ -f "$LEDGER" ]; then
    bad="$(awk -F'\t' '
      NF != 6 { print "history.tsv:" NR " — " NF " fields (want 6)"; next }
      $2 !~ /^(done|dropped|superseded|consumed)$/ { print "history.tsv:" NR " — unknown disposition: " $2 }
    ' "$LEDGER")"
    if [ -n "$bad" ]; then
      printf '%s\n' "$bad" | while IFS= read -r f; do echo "FAIL: $f" >&2; done
      fails=$((fails + 1))
    fi
  fi
  # WARN tier: a file wearing the record SHAPE that the discriminator rejects.
  # This is the one thing a crawl loses that a path-based scan had -- inside a
  # known store, a file with broken front-matter was a FAIL; under the crawl it
  # simply is not seen. So look for the shape and say so. A warning does not
  # fail the check: the file may legitimately not be a record.
  shaped="$(mktemp "${TMPDIR:-/tmp}/records-shaped.XXXXXX")"
  trap 'rm -f "$tmp" "$shaped"' EXIT
  find "$RR" -type f -name '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md' | sort > "$shaped"
  warns=0
  while IFS= read -r f; do
    is_record "$f" && continue
    echo "WARN: ${f#"$RR"/} — record-shaped filename, but no front-matter declaring a doctype" >&2
    warns=$((warns + 1))
  done < "$shaped"
  if [ "$warns" -gt 0 ]; then
    echo "records check: $warns record-shaped file(s) not recognized as records" >&2
  fi
  if [ "$fails" -gt 0 ]; then
    echo "records check: FAIL ($fails of $count records/ledger)" >&2
    exit 2
  fi
  echo "records check: OK ($count records)"
}

[ $# -ge 1 ] || usage
cmd="$1"; shift
case "$cmd" in
  list)    cmd_list "$@" ;;
  grep)    cmd_grep "$@" ;;
  show)    cmd_show "$@" ;;
  new)     cmd_new "$@" ;;
  touch)   cmd_touch "$@" ;;
  done)    cmd_done "$@" ;;
  history) cmd_history "$@" ;;
  prune-candidates) cmd_prune_candidates "$@" ;;
  relocate) cmd_relocate "$@" ;;
  check)   cmd_check "$@" ;;
  *) usage ;;
esac
