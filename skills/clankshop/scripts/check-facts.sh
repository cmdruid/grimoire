#!/bin/sh
# check-facts.sh <root> [<skills-root>] -- the assembly facts (pack section 3.3): exactly
# the clankshop side of the fact partition. Installation block, stamped projections vs
# their named inputs, chapter presence, cross-store foreign-key integrity (lifecycle-
# aware), done-log consistency (prefix-aware), ID rules, lane coverage, ticket ages,
# seats, pack lock vs installed set, duplicate IDs, design drafts, missing bases.
# Facts only, one key=value per line; the check verb judges. Document-shape facts
# (entry conformance, citation resolution, budgets) are the docs-quality role's, not here.
set -eu
ROOT=${1:-.}
ROOT=$(CDPATH='' cd "$ROOT" && pwd)
DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd -P)
SKILLS_ROOT=${2:-}
cd "$ROOT"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/clankshop-check.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# emit_capped <key> <cap>: stdin items -> <key>_count= + capped comma-joined <key>=.
emit_capped() {
  awk -v key="$1" -v cap="$2" '
    $0 != "" { n++; if (n <= cap) s = (s == "" ? $0 : s "," $0) }
    END {
      print key "_count=" n+0
      if (n > cap) s = s " ...(+" n-cap " more)"
      print key "=" s
    }'
}

# frontmatter <file> <key>: value of a top-level "key: value" line inside the leading
# --- fence, empty if absent.
frontmatter() {
  awk -v k="$2" '
    NR == 1 { if ($0 != "---") exit; next }
    /^---$/ { exit }
    index($0, k ": ") == 1 { print substr($0, length(k) + 3); exit }
  ' "$1"
}

# ---------- installation block ----------
IB_FACTS=$(sh "$DIR/install-block.sh" read "$ROOT")
printf '%s\n' "$IB_FACTS"
PACK_VERSION=$(printf '%s\n' "$IB_FACTS" | sed -n 's/^pack-version=//p')
DOOR=$(printf '%s\n' "$IB_FACTS" | sed -n 's/^door=//p')
[ "$DOOR" = none ] && DOOR=""

# ---------- chapter presence vs the registry ----------
missing=""
for ch in rules workflows design testing; do
  [ -d ".handbook/$ch" ] || missing="${missing:+$missing,}$ch"
done
echo "chapters_missing=$missing"

# Top-level handbook entries with no steward block in the handbook map.
for e in .handbook/*; do
  [ -e "$e" ] || continue
  b=$(basename "$e")
  [ "$b" = README.md ] && continue
  # known = the handbook map mentions it (a stewardship line or steward block names it)
  grep -qF "$b" .handbook/README.md 2>/dev/null || echo "$b"
done | emit_capped handbook_unknown 20

# ---------- stewardship maps ----------
hm=0; [ -f .handbook/README.md ] && hm=1; echo "handbook_map=$hm"
rm_=0; [ -f .records/README.md ] && rm_=1; echo "records_map=$rm_"
# Steward blocks across both maps; a clankshop@N stamp with N != pack-version is stale.
for m in .handbook/README.md .records/README.md; do
  [ -f "$m" ] || continue
  awk -v src="$m" '
    match($0, /<!-- steward:[A-Za-z0-9-]+ -->/) {
      name = substr($0, RSTART + 13, RLENGTH - 13 - 4); cur = name; next
    }
    cur != "" && index($0, "built-against: ") {
      s = $0; sub(/^.*built-against: */, "", s); sub(/ *-->.*$/, "", s); sub(/ *$/, "", s)
      print src ":" cur "@" s; cur = ""
    }
    /<!-- \/steward:/ { cur = "" }
  ' "$m"
done > "$TMP/stewards" || true
emit_capped steward_blocks 20 < "$TMP/stewards"
awk -F'@' -v pv="$PACK_VERSION" '
  index($0, "@clankshop@") { if ($NF != pv) print }
' "$TMP/stewards" | emit_capped steward_stale 20

# ---------- door registration blocks ----------
if [ -n "$DOOR" ] && [ -f "$DOOR" ]; then
  grep -oE '^<!-- skill:[a-z][a-z-]* BEGIN built-against:[^ ]* -->$' "$DOOR" 2>/dev/null \
    | sed -E 's/^<!-- skill:([a-z-]+) BEGIN built-against:([^ ]*) -->$/\1:\2/' \
    > "$TMP/reg" || true
else
  : > "$TMP/reg"
fi
emit_capped registered 30 < "$TMP/reg"
# Installed skills (skills-root resolved: given, or the standard Claude Code target).
if [ -z "$SKILLS_ROOT" ] && [ -d "$HOME/.claude/skills" ]; then SKILLS_ROOT="$HOME/.claude/skills"; fi
if [ -n "$SKILLS_ROOT" ] && [ -d "$SKILLS_ROOT" ]; then
  echo "skills_root=$SKILLS_ROOT"
  for d in "$SKILLS_ROOT"/*/; do
    [ -f "$d/SKILL.md" ] && basename "$d"
  done > "$TMP/inst" || true
else
  echo "skills_root="
  : > "$TMP/inst"
fi
# unregistered: installed skills with no door block (facts; the verb knows which members
# must register -- helpers and optional proxies have their own protocols).
if [ -s "$TMP/inst" ]; then
  while IFS= read -r s; do
    grep -q "^$s:" "$TMP/reg" || echo "$s"
  done < "$TMP/inst"
fi | emit_capped unregistered 30
# orphaned: door blocks naming no installed skill.
if [ -s "$TMP/reg" ]; then
  while IFS= read -r r; do
    n=${r%%:*}
    grep -qx "$n" "$TMP/inst" || echo "$n"
  done < "$TMP/reg"
fi | emit_capped orphaned_registrations 30
# stale core stamps: built-against clankshop@N with N != installed pack-version.
awk -F':' -v pv="$PACK_VERSION" '
  $2 ~ /^clankshop@/ { v = $2; sub(/^clankshop@/, "", v); if (v != pv) print $1 ":" $2 }
' "$TMP/reg" | emit_capped registration_stale 30

# ---------- routing targets (door table rows + ROUTING dispatch rows) ----------
if [ -n "$DOOR" ] && [ -f "$DOOR" ]; then
  grep -E '^\|' "$DOOR" 2>/dev/null | grep -oE '`/[a-z][a-z-]*' | tr -d '`' | sed 's|^/||' | sort -u
else
  :
fi > "$TMP/door-targets" || true
emit_capped routing_targets 30 < "$TMP/door-targets"
# unresolved: a door-table token naming no installed skill (by-hand rows carry no token).
if [ -s "$TMP/door-targets" ] && [ -s "$TMP/inst" ]; then
  while IFS= read -r t; do
    grep -qx "$t" "$TMP/inst" || echo "/$t"
  done < "$TMP/door-targets"
fi | emit_capped routing_unresolved 30
# lane coverage: each ROUTING dispatch row needs its lane file; its /skill entry point
# must be installed (by-hand entries resolve by definition).
RT=.handbook/rules/ROUTING.md
if [ -f "$RT" ]; then
  grep -E '^\| ' "$RT" | awk -F'|' 'NF >= 4 && $3 ~ /workflows\// {
    lane = $3; gsub(/[ `]/, "", lane)
    entry = $4; gsub(/^[ ]+|[ ]+$/, "", entry)
    print lane "\t" entry
  }' > "$TMP/lanes" || true
else
  : > "$TMP/lanes"
fi
while IFS="$(printf '\t')" read -r lane entry; do
  [ -n "$lane" ] || continue
  [ -f ".handbook/$lane" ] || echo "$lane"
done < "$TMP/lanes" | emit_capped lane_missing 10
while IFS="$(printf '\t')" read -r lane entry; do
  tok=$(printf '%s' "$entry" | grep -oE '`/[a-z][a-z-]*' | tr -d '`' | sed 's|^/||' | head -1 || true)
  [ -n "$tok" ] || continue   # by-hand rows resolve by definition
  if [ -s "$TMP/inst" ]; then
    grep -qx "$tok" "$TMP/inst" || echo "$lane:/$tok"
  fi
done < "$TMP/lanes" | emit_capped routing_entry_unresolved 10

# ---------- submodule index vs .gitmodules + gitlinks ----------
git ls-files --stage 2>/dev/null | awk '$1 == "160000" {print $4 "@" substr($2, 1, 7)}' \
  > "$TMP/gitlinks" || true
emit_capped gitlinks 20 < "$TMP/gitlinks"
if [ -n "$DOOR" ] && [ -f "$DOOR" ] && grep -q '<!-- submodules BEGIN' "$DOOR" 2>/dev/null; then
  awk '/<!-- submodules BEGIN/{f=1;next} /<!-- submodules END/{f=0} f && /^- /{print substr($0,3)}' \
    "$DOOR" > "$TMP/subidx" || true
  echo "submodule_index=1"
  # extra: indexed row with no matching gitlink path@sha (moved, removed, or SHA drift).
  while IFS= read -r row; do
    grep -qxF "$row" "$TMP/gitlinks" || echo "$row"
  done < "$TMP/subidx" | emit_capped submodule_index_stale 20
  # unindexed: a gitlink with no index row for its path (opted-out is legal; the verb judges).
  while IFS= read -r gl; do
    p=${gl%@*}
    grep -q "^$p@" "$TMP/subidx" || echo "$p"
  done < "$TMP/gitlinks" | emit_capped submodule_unindexed 20
  rm -f "$TMP/subidx"
else
  echo "submodule_index=0"
  echo "submodule_index_stale_count=0"; echo "submodule_index_stale="
  sed 's/@.*$//' "$TMP/gitlinks" | emit_capped submodule_unindexed 20
fi

# ---------- record stores ----------
missing=""
for s in .records/trackers/tasks.md .records/trackers/issues.md .records/trackers/feedback.md \
         .records/trackers/bugs .records/trackers/notes .records/tickets .records/done/log.md; do
  [ -e "$s" ] || missing="${missing:+$missing,}$s"
done
echo "stores_missing=$missing"

# ---------- tickets: schema + lifecycle-aware origin integrity ----------
LOG=.records/done/log.md
tcount=0
: > "$TMP/tprob"
: > "$TMP/tedges"
: > "$TMP/tages"
for tf in .records/tickets/*.md; do
  [ -f "$tf" ] || continue
  tcount=$((tcount + 1))
  base=$(basename "$tf" .md)
  tid=$(frontmatter "$tf" id)
  status=$(frontmatter "$tf" status)
  kind=$(frontmatter "$tf" subject_kind)
  origin=$(frontmatter "$tf" origin)
  blocking=$(frontmatter "$tf" blocking)
  [ "$tid" = "TK-$base" ] || echo "id-mismatch:$base" >> "$TMP/tprob"
  case "$kind" in note|task|issue|bug|feedback) : ;; *) echo "bad-subject-kind:$base" >> "$TMP/tprob" ;; esac
  case "$status" in open|answered|resolved) : ;; *) echo "bad-status:$base" >> "$TMP/tprob" ;; esac
  if [ -n "$blocking" ]; then
    printf '%s\n' "$blocking" | tr -d '[]' | tr ',' '\n' | while IFS= read -r b; do
      b=$(printf '%s' "$b" | tr -d ' ')
      [ -n "$b" ] && printf '%s %s\n' "$tid" "$b"
    done >> "$TMP/tedges"
  fi
  # unanswered-age (open/answered only): days since updated:.
  if [ "$status" = open ] || [ "$status" = answered ]; then
    upd=$(frontmatter "$tf" updated)
    echo "$tid:updated=$upd" >> "$TMP/tages"
  fi
  # Lifecycle-aware origin validation (a completed origin is REMOVED from its flat
  # tracker by design -- "origin -> live entry" would go red on every resolved
  # promoted ticket, so the required evidence depends on status):
  #   open/answered -> a live origin entry paused for THIS ticket
  #   resolved      -> a done-log line carrying the origin ID whose gist cites the
  #                    TK- (resolve/wontfix), OR a live UNPAUSED origin (demoted)
  #   resolved direct (no origin) -> a done-log line carrying the TK- ID (demoted
  #                    direct tickets aside, which the verb judges from the body)
  origin_live=""; origin_paused=""
  if [ -n "$origin" ]; then
    case "$origin" in
      T-*) store=.records/trackers/tasks.md ;;
      I-*) store=.records/trackers/issues.md ;;
      F-*) store=.records/trackers/feedback.md ;;
      B-*) store=.records/trackers/bugs ;;
      N-*) store=.records/trackers/notes ;;
      *)   store="" ;;
    esac
    if [ -d "$store" ]; then
      of=$(grep -rl "^id: $origin$" "$store" 2>/dev/null | head -1 || true)
      if [ -n "$of" ]; then
        origin_live=1
        [ "$(frontmatter "$of" paused)" = "$tid" ] && origin_paused=1
      fi
    elif [ -f "$store" ]; then
      oline=$(grep -F "$origin" "$store" | head -1 || true)
      if [ -n "$oline" ]; then
        origin_live=1
        case "$oline" in *"[⇧ $tid]"*) origin_paused=1 ;; esac
      fi
    fi
    case "$status" in
      open|answered)
        if [ -z "$origin_live" ]; then echo "origin-dangling:$base=$origin" >> "$TMP/tprob"
        elif [ -z "$origin_paused" ]; then echo "origin-unpaused:$base=$origin" >> "$TMP/tprob"
        fi ;;
      resolved)
        logline=""
        [ -f "$LOG" ] && logline=$(grep -F " $origin " "$LOG" | grep -F "$tid" | head -1 || true)
        if [ -z "$logline" ]; then
          if [ -z "$origin_live" ] || [ -n "$origin_paused" ]; then
            echo "resolution-unaccounted:$base=$origin" >> "$TMP/tprob"
          fi
        fi ;;
    esac
  else
    if [ "$status" = resolved ] && { [ ! -f "$LOG" ] || ! grep -qF " $tid " "$LOG"; }; then
      echo "direct-unlogged:$base" >> "$TMP/tprob"
    fi
  fi
done
echo "tickets=$tcount"
emit_capped ticket_problems 20 < "$TMP/tprob"
emit_capped ticket_open_age 20 < "$TMP/tages"
# blocking cycles: follow edges from each node; revisiting the start = a cycle.
awk '
  { adj[$1] = adj[$1] " " $2; nodes[$1] = 1 }
  END {
    for (s in nodes) {
      delete seen; n = 0; q[n++] = s; seen[s] = 1
      for (i = 0; i < n; i++) {
        split(adj[q[i]], a, " ")
        for (k in a) {
          t = a[k]; if (t == "") continue
          if (t == s) { print "cycle:" s; break }
          if (!(t in seen)) { seen[t] = 1; q[n++] = t }
        }
      }
    }
  }
' "$TMP/tedges" | sort -u | emit_capped ticket_blocking_cycles 10

# ---------- done-log consistency (prefix-aware per the completion-mutation contract) ----------
if [ -f "$LOG" ]; then
  grep -E '^- ' "$LOG" | awk -F' · ' 'NF >= 4 { print $2 }' > "$TMP/doneids" || true
  emit_capped done_log_ids 30 < "$TMP/doneids"
  while IFS= read -r id; do
    case "$id" in
      TK-*)
        # curation may age a resolved ticket into tickets/archive/ -- probe both homes
        tf=".records/tickets/${id#TK-}.md"
        [ -f "$tf" ] || tf=".records/tickets/archive/${id#TK-}.md"
        if [ ! -f "$tf" ]; then echo "$id:ticket-missing"
        elif [ "$(frontmatter "$tf" status)" != resolved ]; then echo "$id:ticket-unresolved"; fi ;;
      T-*|I-*|F-*)
        case "$id" in T-*) f=.records/trackers/tasks.md ;; I-*) f=.records/trackers/issues.md ;; *) f=.records/trackers/feedback.md ;; esac
        # completed flat entries are REMOVED; still present live = fact (pause marker or not)
        if [ -f "$f" ] && grep -qF "$id" "$f"; then echo "$id:still-live"; fi ;;
      B-*|N-*)
        case "$id" in B-*) d=.records/trackers/bugs ;; *) d=.records/trackers/notes ;; esac
        of=$(grep -rl "^id: $id$" "$d" 2>/dev/null | head -1 || true)
        if [ -n "$of" ] && [ "$(frontmatter "$of" status)" != resolved ]; then echo "$id:unresolved-status"; fi ;;
    esac
  done < "$TMP/doneids" | emit_capped done_log_inconsistent 20
  rm -f "$TMP/doneids"
else
  echo "done_log_ids_count=0"; echo "done_log_ids="
  echo "done_log_inconsistent_count=0"; echo "done_log_inconsistent="
fi

# ---------- duplicate-ID scan (whole installation, archives included) ----------
git ls-files --cached --others --exclude-standard -- '.records/*.md' '.handbook/*.md' 2>/dev/null \
  | while IFS= read -r mf; do [ -f "$mf" ] && printf '%s\n' "$mf"; done \
  | tr '\n' '\0' | { xargs -0 awk '
      function scan(s,   pre) {
        if (match(s, /(INV|POL|TK|G|T|I|B|N|F)-[0-9A-Za-z][0-9A-Za-z-]*/)) {
          pre = (RSTART > 1) ? substr(s, RSTART - 1, 1) : " "
          if (pre !~ /[0-9A-Za-z-]/) print substr(s, RSTART, RLENGTH) "\t" FILENAME
        }
      }
      /^#/            { scan($0) }
      /^- /           { scan($0) }
      /^(INV|POL|G)-[0-9]/ { scan($0) }
      /^(id|alias): / { scan($0) }
    ' 2>/dev/null || true; } | sort -u \
  | awk -F'\t' '$2 !~ /done\/log\.md/ {
      if (files[$1] != "") dup[$1] = 1
      files[$1] = files[$1] (files[$1] == "" ? "" : "+") $2
    }
    END { for (id in dup) print id ":" files[id] }' \
  | sort | emit_capped dup_ids 20

# ---------- seats ----------
for s in .agents/roles/*/; do
  [ -d "$s" ] && basename "$s"
done 2>/dev/null | emit_capped seats 20

# ---------- pack lock vs installed set ----------
LOCK=$DIR/../../../packs/clankshop.md
if [ -f "$LOCK" ]; then
  echo "lock_found=1"
  lock_members=$(sed -n 's/^skills:[[:space:]]*//p' "$LOCK" | head -1)
  echo "lock_members=$(printf '%s' "$lock_members" | tr ' ' ',')"
  printf '%s\n' "$lock_members" | tr ' ' '\n' | while IFS= read -r m; do
    [ -n "$m" ] || continue
    if [ -s "$TMP/inst" ]; then
      grep -qx "$m" "$TMP/inst" || echo "$m"
    fi
  done | emit_capped lock_missing_installed 20
else
  echo "lock_found=0"
  echo "lock_members="
  echo "lock_missing_installed_count=0"; echo "lock_missing_installed="
fi

# ---------- stale design drafts ----------
for f in .records/design-draft/*.md .records/design/draft/*.md; do
  [ -f "$f" ] || continue
  echo "$f:updated=$(frontmatter "$f" updated)"
done | emit_capped design_draft 10

# ---------- provenance stamps + missing bases ----------
DOCTRINE=$DIR/../doctrine
BASES=$DOCTRINE/BASES.md
# Fence-stripped view of the base archive: its header carries fenced EXAMPLE base/bump
# blocks (grammar documentation), which must never read as real archive entries.
if [ -f "$BASES" ]; then
  awk '/^[ ]*(```|~~~)/{f=!f;next} f{next} {print}' "$BASES" > "$TMP/bases"
else
  : > "$TMP/bases"
fi
BASES=$TMP/bases
DV=$(awk '/^doctrine-version: /{print $2; exit}' "$DOCTRINE/README.md" 2>/dev/null || true)
echo "doctrine_version=$DV"
RPV=""
[ -f .handbook/rules/RECORDS.md ] && RPV=$(awk '/^built-against: /{v=$2; sub(/^.*@/,"",v); print v; exit}' .handbook/rules/RECORDS.md)
echo "records_projection_version=$RPV"
# Collect deployed (origin, version) pairs: line markers, heading keys, declaration keys.
{
  grep -rhoE "⟨clankshop:[^ ⟩]+ @v[0-9]+" .handbook 2>/dev/null \
    | sed -E 's/^⟨(clankshop:[^ ]+) @v([0-9]+)$/\1@v\2/' || true
  git ls-files --cached --others --exclude-standard -- '.handbook/*.md' 2>/dev/null \
    | while IFS= read -r hf; do [ -f "$hf" ] && printf '%s\n' "$hf"; done \
    | tr '\n' '\0' | { xargs -0 awk '
        /^origin: /         { o = $2 }
        /^origin-version: / { if (o != "") { print o "@v" $2; o = "" } }
      ' 2>/dev/null || true; }
} | sort -u > "$TMP/prov" || true
emit_capped provenance_stamps 30 < "$TMP/prov"
# missing base: no BASES block for origin at version >= N AND no live doctrine entry.
while IFS= read -r pv; do
  [ -n "$pv" ] || continue
  o=${pv%@v*}; v=${pv##*@v}
  if [ -f "$BASES" ] && awk -v o="$o" -v v="$v" '
       index($0, "<!-- base " o " @v") == 1 {
         s = $0; sub(/^.*@v/, "", s); sub(/ -->.*$/, "", s)
         if (s + 0 >= v + 0) found = 1
       }
       END { exit found ? 0 : 1 }' "$BASES"; then
    continue
  fi
  short=${o#clankshop:}
  case "$short" in
    INV-*) grep -q "^$short:" "$DOCTRINE/rules/INVARIANTS.md" 2>/dev/null && continue ;;
    G-*)   grep -qE "^##+ $short:" "$DOCTRINE/rules/GOTCHAS.md" 2>/dev/null && continue ;;
    POL-*) grep -qE "^##+ $short:" "$DOCTRINE/rules/POLICY.md" 2>/dev/null && continue ;;
    workflows/*|testing/*) [ -f "$DOCTRINE/$short.md" ] && continue ;;
  esac
  echo "$pv"
done < "$TMP/prov" | emit_capped missing_base 20
# bump-record coverage: a bump vK origin needs its base block keyed @v(K-1).
if [ -f "$BASES" ]; then
  awk '
    match($0, /^<!-- bump v[0-9]+:/) {
      v = $0; sub(/^<!-- bump v/, "", v); sub(/:.*$/, "", v)
      s = $0; sub(/^<!-- bump v[0-9]+: */, "", s); sub(/ *-->.*$/, "", s)
      n = split(s, os, " ")
      for (i = 1; i <= n; i++) print os[i] "@v" (v - 1)
    }
  ' "$BASES" | sort -u | while IFS= read -r need; do
    o=${need%@v*}; v=${need##*@v}
    grep -qF "<!-- base $o @v$v -->" "$BASES" || echo "$need"
  done | emit_capped bump_uncovered 20
else
  echo "bump_uncovered_count=0"; echo "bump_uncovered="
fi
