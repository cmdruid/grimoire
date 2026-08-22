#!/bin/sh
# records.sh — record query + lifecycle over the records root it is deployed into.
# Journal's deployed asset: the source of truth lives in the journal skill; standup
# copies it to <records-root>/scripts/records.sh, and it operates on THAT root
# (resolved from its own location — never from cwd). The script owns the facts —
# dates, paths, conformance — so agents never guess them.
#
#   records.sh list [--type t] [--status s] [--tag g] [--since d] [--until d] [--stage s]
#   records.sh grep [--type t] [--status s] [--tag g] [--since d] [--until d] [--stage s] <pattern>
#   records.sh show <path>
#   records.sh new <doctype> --title "..." --template <path> [--dir rel] [--tag t]...
#   records.sh touch <path> [--status draft|published]
#   records.sh done <path> [--as done|dropped|superseded|consumed] [--note "..."]
#   records.sh history [--type t] [--disposition d] [--since d] [--until d] [--grep pat]
#   records.sh prune-candidates [--until d]
#   records.sh check
#   records.sh migrate-status
#
# A file is a RECORD iff it is named YYYY-MM-DD-<slug>.md AND carries a
# front-matter block that declares a doctype. That is the whole discriminator:
# the tool crawls the root at any depth and knows no store names, so directory
# layout is the caller's business and a root shared with other homes (doctrine,
# templates, scripts) needs no reserved names — those files are simply not
# records. The authoritative doctype is the front-matter key, never the parent
# directory. `list`/`history` emit TSV — grep/awk-friendly, no parser needed.
# Querying is a live scan (no stored index). Closure stamps the file `archived`
# and appends `--as` to history.tsv — the ledger's sole writer. `list` default
# is the live set (`draft` ∪ `published`). The path is the ID.
# Exit codes: 0 ok · 1 usage · 2 error / check failure.
set -eu

RR="$(cd "$(dirname "$0")/.." && pwd)"
LEDGER="$RR/history.tsv"
TAB="$(printf '\t')"
NL="$(printf '\n/')"
NL="${NL%/}"

usage() {
  cat >&2 <<'EOF'
usage: records.sh <command> [args]
  list    [--type t] [--status s] [--tag g] [--since d] [--until d] [--stage s]
  grep    [--type t] [--status s] [--tag g] [--since d] [--until d] [--stage s] <pattern>
  show    <path>
  new     <doctype> --title "..." --template <path> [--dir rel] [--tag t]...
  touch   <path> [--status draft|published]
  done    <path> [--as done|dropped|superseded|consumed] [--note "..."]
  history [--type t] [--disposition d] [--since d] [--until d] [--grep pat]
  prune-candidates [--until d]
  check
  migrate-status
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

is_disposition() { case "$1" in done|dropped|superseded|consumed) return 0 ;; *) return 1 ;; esac; }
is_archived()    { [ "$1" = archived ]; }
is_status()      { case "$1" in draft|published|archived) return 0 ;; *) return 1 ;; esac; }

# resolve <path-arg>: sets abs + rel (rel is records-root-relative, the ledger form).
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
# Neither alone is enough. Front-matter alone would swallow the record
# TEMPLATES, which necessarily carry a doctype block (that block is what `new`
# copies into the minted record) -- and templates share this root whenever a
# host points its workspace and records homes at the same directory. The shape
# alone would swallow any dated prose file. Together they need no reserved
# names: doctrine pages, templates, and scripts fail one conjunct or the other,
# so a shared root is legal and the directory layout is the caller's business.
is_record() {
  case "${1##*/}" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md) ;;
    *) return 1 ;;
  esac
  head -1 "$1" | grep -qx -- '---' || return 1
  [ -n "$(fm_field "$1" doctype)" ]
}

# records: records-root-relative paths of every record, one per line. A crawl at
# any depth -- this tool knows no store names (a skill creates only the
# directories it needs, so the set is open-ended and unknown here).
records() {
  find "$RR" -type f -name '*.md' | sort | while IFS= read -r f; do
    is_record "$f" || continue
    printf '%s\n' "${f#"$RR"/}"
  done
}

# meta_row <rel>: one TSV row — path·doctype·status·updated·tags·title.
# Missing keys print empty fields (list is a lens; `check` is the enforcer).
meta_row() {
  awk -v rel="$1" '
    BEGIN { infm = 0; fmdone = 0; doctype = ""; status = ""; updated = ""; tags = ""; title = "" }
    NR == 1 { if ($0 == "---") { infm = 1; next } else { exit } }
    infm && $0 == "---" { infm = 0; fmdone = 1; next }
    infm {
      if      ($0 ~ /^doctype:/) { v = $0; sub(/^doctype:[ \t]*/, "", v); doctype = v }
      else if ($0 ~ /^status:/)  { v = $0; sub(/^status:[ \t]*/,  "", v); status  = v }
      else if ($0 ~ /^updated:/) { v = $0; sub(/^updated:[ \t]*/, "", v); updated = v }
      else if ($0 ~ /^tags:/)    { v = $0; sub(/^tags:[ \t]*/,    "", v); gsub(/[][ \t]/, "", v); tags = v }
      next
    }
    fmdone && title == "" && /^# / { title = substr($0, 3) }
    END { printf "%s\t%s\t%s\t%s\t%s\t%s\n", rel, doctype, status, updated, tags, title }
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

# fill <template> <dest> <title> <date>: literal slot substitution (no regex —
# a title may carry any punctuation; same technique as the seed's subst).
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

cmd_new() {
  [ $# -ge 1 ] || usage
  doctype="$1"; shift
  title=""
  tpl=""
  tags=""
  dir=""
  dir_set=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --title)    [ $# -ge 2 ] || usage; title="$2"; shift 2 ;;
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
  # --template is required: a writer resolves its own template path and passes
  # it. There is no flat fallback to look up -- the tool knows no taxonomy, so
  # it cannot guess a template location from a doctype name.
  [ -n "$tpl" ] || err "--template is required (records.sh new <doctype> --title ... --template <path>)"
  [ -f "$tpl" ] || err "no template for doctype '$doctype': $tpl"
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
  fill "$tpl" "$path" "$title" "$today" "$tags"
  printf '%s\n' "$path"
}

# stamp <abs> <today> [<status>]: rewrite updated: (and optionally status:) in the
# front-matter block only.
stamp() {
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

# fm_field <abs> <key>: the key's front-matter value (empty when absent).
fm_field() {
  awk -v key="$2" '
    BEGIN { infm = 0 }
    NR == 1 { if ($0 == "---") { infm = 1; next } else { exit } }
    infm && $0 == "---" { exit }
    infm && index($0, key ":") == 1 { v = substr($0, length(key) + 2); sub(/^[ \t]*/, "", v); print v; exit }
  ' "$1"
}

require_record() { # a stampable record: front-matter with updated: and status: lines
  head -1 "$abs" | grep -qx -- '---' || err "no front-matter (not a record?): $rel"
  [ -n "$(fm_field "$abs" updated)" ] || err "front-matter lacks 'updated:': $rel"
  [ -n "$(fm_field "$abs" status)" ]  || err "front-matter lacks 'status:': $rel"
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
  stamp "$abs" "$(date +%Y-%m-%d)" "$new_status"
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
  stamp "$abs" "$today" "archived"
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
    | while IFS="$TAB" read -r d disp rel dt title note; do
        [ -f "$RR/$rel" ] || continue
        is_archived "$(fm_field "$RR/$rel" status)" || continue
        printf '%s\t%s\t%s\t%s\t%s\n' "$d" "$disp" "$rel" "$dt" "$title"
      done
}

cmd_check() {
  tmp="$(mktemp "${TMPDIR:-/tmp}/records-check.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  records > "$tmp"
  fails=0
  count=0
  while IFS= read -r rel; do
    count=$((count + 1))
    # per-record contract: front-matter present, five keys, enum status, ISO
    # dates. The doctype is NOT checked against the parent directory -- the
    # front-matter key is the authority and the directory is the caller's
    # business, so there is no second copy of the fact to disagree with.
    findings="$(awk '
      BEGIN { infm = 0; fmdone = 0 }
      NR == 1 { if ($0 == "---") { infm = 1; next } else { print "no front-matter block"; exit } }
      infm && $0 == "---" { infm = 0; fmdone = 1; next }
      infm {
        if      ($0 ~ /^doctype:/) { v = $0; sub(/^doctype:[ \t]*/, "", v); fm["doctype"] = v }
        else if ($0 ~ /^status:/)  { v = $0; sub(/^status:[ \t]*/,  "", v); fm["status"]  = v }
        else if ($0 ~ /^created:/) { v = $0; sub(/^created:[ \t]*/, "", v); fm["created"] = v }
        else if ($0 ~ /^updated:/) { v = $0; sub(/^updated:[ \t]*/, "", v); fm["updated"] = v }
        else if ($0 ~ /^tags:/)    { fm["tags"] = "present" }
        else if ($0 ~ /^stage:/) {
          v = $0; sub(/^stage:[ \t]*/, "", v); sub(/[ \t]+$/, "", v)
          if (v == "") print "stage is empty"
        }
        next
      }
      END {
        if (!fmdone) { print "unterminated front-matter block"; exit }
        split("doctype status created updated tags", keys, " ")
        for (i in keys) if (!(keys[i] in fm)) print "missing key: " keys[i]
        if (("status" in fm) && fm["status"] !~ /^(draft|published|archived)$/)
          print "status not in the contract: " fm["status"]
        if (("created" in fm) && fm["created"] !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/)
          print "created is not YYYY-MM-DD: " fm["created"]
        if (("updated" in fm) && fm["updated"] !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/)
          print "updated is not YYYY-MM-DD: " fm["updated"]
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

# Rewrite status: only. Do not bump updated:. Do not touch history.tsv.
migrate_status_line() {  # abs
  tmp="$1.tmp"
  awk '
    BEGIN { infm = 0; fmdone = 0 }
    NR == 1 && $0 == "---" { infm = 1; print; next }
    infm && !fmdone && $0 == "---" { fmdone = 1; infm = 0; print; next }
    infm && /^status:/ {
      v = $0; sub(/^status:[ \t]*/, "", v)
      if      (v == "open")                              v = "draft"
      else if (v == "current")                           v = "published"
      else if (v ~ /^(done|dropped|superseded|consumed)$/) v = "archived"
      print "status: " v; next
    }
    { print }
  ' "$1" > "$tmp" && mv "$tmp" "$1"
}

cmd_migrate_status() {
  migrated=0
  list="$(mktemp "${TMPDIR:-/tmp}/records-migrate.XXXXXX")"
  records > "$list"
  while IFS= read -r r; do
    before="$(fm_field "$RR/$r" status)"
    migrate_status_line "$RR/$r"
    after="$(fm_field "$RR/$r" status)"
    if [ "$before" != "$after" ]; then
      migrated=$((migrated + 1))
    fi
  done < "$list"
  rm -f "$list"
  echo "migrated=$migrated"
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
  check)   cmd_check "$@" ;;
  migrate-status) cmd_migrate_status "$@" ;;
  *) usage ;;
esac
