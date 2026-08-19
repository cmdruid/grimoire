#!/bin/sh
# records.sh — record query + lifecycle over the records root it is deployed into.
# Journal's deployed asset: the source of truth lives in the journal skill; standup
# copies it to <records-root>/scripts/records.sh, and it operates on THAT root
# (resolved from its own location — never from cwd). The script owns the facts —
# dates, paths, conformance — so agents never guess them.
#
#   records.sh list [--type t] [--status s] [--tag g] [--since d] [--until d]
#   records.sh show <path>
#   records.sh new <doctype> --title "..." [--template <path>]
#   records.sh touch <path> [--status open|current]
#   records.sh done <path> [--as done|dropped|superseded|consumed] [--note "..."]
#   records.sh history [--type t] [--disposition d] [--since d] [--until d] [--grep pat]
#   records.sh prune-candidates [--until d]
#   records.sh check
#
# Stores are the top-level directories at the records root; `templates/`, `scripts/`,
# and `history.tsv` are reserved and never scanned. `list`/`history` emit TSV —
# grep/awk-friendly, no parser needed. Querying is a live scan (no stored index).
# Closure is in place: `done` sets the closing status and appends the one ledger
# line to history.tsv — the ledger's sole writer. Filenames from `new` are
# YYYY-MM-DD-<slug>.md — the path is the ID.
# Exit codes: 0 ok · 1 usage · 2 error / check failure.
set -eu

RR="$(cd "$(dirname "$0")/.." && pwd)"
LEDGER="$RR/history.tsv"
TAB="$(printf '\t')"

usage() {
  cat >&2 <<'EOF'
usage: records.sh <command> [args]
  list    [--type t] [--status s] [--tag g] [--since d] [--until d]
  show    <path>
  new     <doctype> --title "..." [--template <path>]
  touch   <path> [--status open|current]
  done    <path> [--as done|dropped|superseded|consumed] [--note "..."]
  history [--type t] [--disposition d] [--since d] [--until d] [--grep pat]
  prune-candidates [--until d]
  check
EOF
  exit 1
}

err() { echo "records.sh: $*" >&2; exit 2; }

is_closing() { case "$1" in done|dropped|superseded|consumed) return 0 ;; *) return 1 ;; esac; }
is_status()  { case "$1" in open|current|done|dropped|superseded|consumed) return 0 ;; *) return 1 ;; esac; }

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
  case "$rel" in
    templates/*|scripts/*|doctrine/*|history.tsv) err "reserved path, not a record: $rel" ;;
  esac
}

# stores: the top-level directories minus the reserved ones.
#
# `doctrine` is reserved because a host whose agent-workspace and agent-records
# homes coincide keeps its doctrine at <agent-records>/doctrine -- living
# normative prose, not dated records. (It was also the doctrine home's own
# default before that home moved under <agent-workspace>.) It
# carries no record front-matter, so without this arm `check` FAILs on every
# doctrine file and `list` emits empty-field rows for them. The name is fixed
# rather than resolved: this script never scans the front door (front-door
# variables doctrine -- write scripts take resolved paths as arguments), and a
# fixed reserved name is the simplest portable rule. A host whose workspace
# sits elsewhere -- the default -- simply has no doctrine/ directory here.
stores() {
  for d in "$RR"/*/; do
    [ -d "$d" ] || continue
    b="$(basename "$d")"
    case "$b" in templates|scripts|doctrine) continue ;; esac
    printf '%s\n' "$b"
  done
}

# records: records-root-relative paths of every store record, one per line.
records() {
  stores | while IFS= read -r s; do
    find "$RR/$s" -name '*.md' -type f | sort | while IFS= read -r f; do
      printf '%s\n' "${f#"$RR"/}"
    done
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

cmd_list() {
  f_type=""; f_status=""; f_tag=""; f_since=""; f_until=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --type)   [ $# -ge 2 ] || usage; f_type="$2";   shift 2 ;;
      --status) [ $# -ge 2 ] || usage; f_status="$2"; shift 2 ;;
      --tag)    [ $# -ge 2 ] || usage; f_tag="$2";    shift 2 ;;
      --since)  [ $# -ge 2 ] || usage; f_since="$2";  shift 2 ;;
      --until)  [ $# -ge 2 ] || usage; f_until="$2";  shift 2 ;;
      *) usage ;;
    esac
  done
  records | while IFS= read -r r; do meta_row "$r"; done \
    | awk -F'\t' -v t="$f_type" -v s="$f_status" -v g="$f_tag" -v a="$f_since" -v z="$f_until" '
        t != "" && $2 != t { next }
        s != "" && $3 != s { next }
        g != "" && index("," $5 ",", "," g ",") == 0 { next }
        a != "" && $4 < a { next }
        z != "" && $4 > z { next }
        { print }
      ' \
    | sort -t "$TAB" -k4,4r -k1,1
}

cmd_show() {
  [ $# -eq 1 ] || usage
  resolve "$1"
  cat "$abs"
}

# fill <template> <dest> <title> <date>: literal slot substitution (no regex —
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
      print out line
    }
  ' "$1" > "$2"
}

cmd_new() {
  [ $# -ge 1 ] || usage
  doctype="$1"; shift
  title=""
  tpl=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --title)    [ $# -ge 2 ] || usage; title="$2"; shift 2 ;;
      --template) [ $# -ge 2 ] || usage; tpl="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$title" ] || usage
  [ -n "$tpl" ] || tpl="$RR/templates/$doctype.md"
  [ -f "$tpl" ] || err "no template for doctype '$doctype' (expected $tpl)"
  today="$(date +%Y-%m-%d)"
  slug="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' \
          | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-\{1,\}//' -e 's/-\{1,\}$//')"
  [ -n "$slug" ] || err "title yields an empty slug: $title"
  mkdir -p "$RR/$doctype"
  base="$RR/$doctype/$today-$slug"
  path="$base.md"
  n=2
  while [ -e "$path" ]; do path="$base-$n.md"; n=$((n + 1)); done
  fill "$tpl" "$path" "$title" "$today"
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
    is_closing "$new_status" && err "closing status goes through 'done', not 'touch': $new_status"
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
  is_closing "$disposition" || err "unknown disposition: $disposition (done|dropped|superseded|consumed)"
  require_record
  status="$(fm_field "$abs" status)"
  is_closing "$status" && err "already closed ($status): $rel"
  doctype="$(fm_field "$abs" doctype)"
  title="$(awk '/^# /{ print substr($0, 3); exit }' "$abs" | tr '\t' ' ')"
  note="$(printf '%s' "$note" | tr '\t\n' '  ')"
  today="$(date +%Y-%m-%d)"
  stamp "$abs" "$today" "$disposition"
  line="$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$today" "$disposition" "$rel" "$doctype" "$title" "$note" | tr '\n' ' ')"
  printf '%s\n' "$line" >> "$LEDGER"
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
        is_closing "$(fm_field "$RR/$rel" status)" || continue
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
    store="${rel%%/*}"
    # per-record contract: front-matter present, five keys, enum status,
    # ISO dates, doctype matching the store directory.
    findings="$(awk -v store="$store" '
      BEGIN { infm = 0; fmdone = 0 }
      NR == 1 { if ($0 == "---") { infm = 1; next } else { print "no front-matter block"; exit } }
      infm && $0 == "---" { infm = 0; fmdone = 1; next }
      infm {
        if      ($0 ~ /^doctype:/) { v = $0; sub(/^doctype:[ \t]*/, "", v); fm["doctype"] = v }
        else if ($0 ~ /^status:/)  { v = $0; sub(/^status:[ \t]*/,  "", v); fm["status"]  = v }
        else if ($0 ~ /^created:/) { v = $0; sub(/^created:[ \t]*/, "", v); fm["created"] = v }
        else if ($0 ~ /^updated:/) { v = $0; sub(/^updated:[ \t]*/, "", v); fm["updated"] = v }
        else if ($0 ~ /^tags:/)    { fm["tags"] = "present" }
        next
      }
      END {
        if (!fmdone) { print "unterminated front-matter block"; exit }
        split("doctype status created updated tags", keys, " ")
        for (i in keys) if (!(keys[i] in fm)) print "missing key: " keys[i]
        if (("doctype" in fm) && fm["doctype"] != store)
          print "doctype '\''" fm["doctype"] "'\'' does not match store '\''" store "'\''"
        if (("status" in fm) && fm["status"] !~ /^(open|current|done|dropped|superseded|consumed)$/)
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
    # record links: a body reference `→ <store>/<file>.md` must resolve at the
    # root (link-rot detection). Two filters keep illustrations from manufacturing
    # false rot. (1) Only tokens whose first segment is a real top-level directory
    # are checked, so prose naming no store can't trip it. (2) CODE BLOCKS are
    # skipped -- fenced and four-space-indented alike -- because an example line
    # showing the tracker-line FORM necessarily names a real store, which defeats
    # filter (1) on its own: a template demonstrating `→ notes/<file>.md` is
    # teaching syntax, not referencing a record.
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
            if [ -d "$RR/${lnk%%/*}" ] && ! [ -f "$RR/$lnk" ]; then
              echo "FAIL: $rel — broken link → $lnk" >&2
              fails=$((fails + 1))
            fi ;;
        esac
      done <<LINKS
$links
LINKS
    fi
    # status <-> ledger coherence: a closing status with no ledger line is a fact.
    status="$(fm_field "$RR/$rel" status)"
    if is_closing "$status"; then
      if ! [ -f "$LEDGER" ] || ! awk -F'\t' -v p="$rel" '$3 == p { found = 1 } END { exit !found }' "$LEDGER"; then
        echo "FAIL: $rel — closing status '$status' but no history.tsv ledger line" >&2
        fails=$((fails + 1))
      fi
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
  # open-ticket visibility: tickets await a human, so the check surfaces them.
  open_tickets=0
  while IFS= read -r rel; do
    case "$rel" in tickets/*) ;; *) continue ;; esac
    is_closing "$(fm_field "$RR/$rel" status)" || open_tickets=$((open_tickets + 1))
  done < "$tmp"
  echo "open tickets: $open_tickets"
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
  show)    cmd_show "$@" ;;
  new)     cmd_new "$@" ;;
  touch)   cmd_touch "$@" ;;
  done)    cmd_done "$@" ;;
  history) cmd_history "$@" ;;
  prune-candidates) cmd_prune_candidates "$@" ;;
  check)   cmd_check "$@" ;;
  *) usage ;;
esac
