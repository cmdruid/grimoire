#!/usr/bin/env bash
# analyst-facts.sh <subcommand> <root> [options]
#
# Fact-gathering harness for the /analyst skill. Each subcommand does
# deterministic, READ-ONLY inspection of a project's records layer and git
# history, emitting compact `key=value` facts plus evidence blocks -- so the
# agent spends its turns curating and writing, not probing.
#
# DOCTRINE: facts, not verdicts. Nothing here scores, grades, or diagnoses. It
# reports what the project recorded and what git shows; every judgment about
# significance belongs to the agent reading these facts, and every judgment
# about QUALITY belongs to the project's audit tooling, not here.
#
# NEVER RUNS THE PROJECT'S GATE. No build, no test suite, no linter is invoked:
# they are slow, may mutate state, and are not this skill's business. Gate state
# is read from what the project already recorded, or reported unknown.
#
# Degrades by design: with no records layer, the git-derived facts still emit
# and the records facts report absent. No subcommand refuses for lack of a
# workshop.
#
# Portability: POSIX-ish bash, BSD/macOS safe. `grep -E` patterns use explicit
# character classes -- never `\b` (a GNU extension that matches nothing on BSD).
set -euo pipefail

# Front-door variable `records-root` (default `.records`).
resolve_records_root() {
  local root="$1" fd decl=""
  for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
    if [ -z "$decl" ] && [ -f "$fd" ]; then
      decl="$(sed -n 's/^records-root:[[:space:]]*//p' "$fd" | head -n 1 \
              | sed 's/[[:space:]]*$//')"
    fi
  done
  printf '%s\n' "${decl:-.records}"
}

usage() {
  cat >&2 <<'EOF'
usage: analyst-facts.sh <subcommand> <root> [options]

  span      <root> --since <date|ref>     briefing: closures, records, commits in span
  status    <root>                        status: open records, trackers, streams now
  health    <root>                        diagnostics: defects, staleness, recorded gate state
  subsystem <root> --path <p> [--path p]  subsystem/guide: records + history for paths
  catalog   <root>                        which templates are deployed vs bundled

Each prints `key=value` facts then evidence lists. Read-only; never runs the
project's gate; emits no recommendation.
EOF
  exit 1
}

err() { echo "analyst-facts.sh: $*" >&2; exit 2; }

# --- shared resolution -------------------------------------------------------

setup() {
  ROOT="${1:-}"
  [ -n "$ROOT" ] || usage
  [ -d "$ROOT" ] || err "no such directory: $ROOT"
  ROOT="$(cd "$ROOT" && pwd)"
  RR_REL="$(resolve_records_root "$ROOT")"
  RR="$ROOT/$RR_REL"
  LEDGER="$RR/history.tsv"
  RECORDS_SH="$RR/scripts/records.sh"
  if [ -d "$RR" ]; then RECORDS_LAYER=present; else RECORDS_LAYER=absent; fi
  if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then GIT=present; else GIT=absent; fi
  echo "root=$ROOT"
  echo "records_root=$RR_REL"
  echo "records_layer=$RECORDS_LAYER"
  echo "ledger=$([ -f "$LEDGER" ] && echo present || echo absent)"
  echo "git=$GIT"
}

# Records-root-relative store scan. `templates/`, `scripts/`, `history.tsv` are
# reserved (journal's contract) and never counted as records.
each_record() {
  [ "$RECORDS_LAYER" = present ] || return 0
  find "$RR" -type f -name '*.md' 2>/dev/null \
    | grep -v -e "^$RR/templates/" -e "^$RR/scripts/" || true
}

# front_matter_field <file> <field>
fm_field() {
  sed -n '/^---$/,/^---$/p' "$1" 2>/dev/null \
    | sed -n "s/^$2:[[:space:]]*//p" | head -n 1 | sed 's/[[:space:]]*$//'
}

rel_to_rr() { printf '%s\n' "${1#"$RR"/}"; }

# --- subcommands -------------------------------------------------------------

cmd_span() {
  setup "$@"; shift
  local since=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --since) [ $# -ge 2 ] || usage; since="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$since" ] || err "span requires --since <date|ref>"
  echo "since=$since"

  # A git ref resolves to its commit date; a bare date passes through.
  local since_date="$since"
  if [ "$GIT" = present ] && git -C "$ROOT" rev-parse --verify --quiet "$since^{commit}" >/dev/null 2>&1; then
    since_date="$(git -C "$ROOT" log -1 --format=%cs "$since")"
    echo "since_kind=ref"
  else
    echo "since_kind=date"
  fi
  echo "since_date=$since_date"

  # Closures in span, straight from the ledger (its schema: date \t disposition
  # \t path \t type \t note).
  local closures=0
  if [ -f "$LEDGER" ]; then
    closures="$(awk -F'\t' -v a="$since_date" '$1 >= a' "$LEDGER" | wc -l | tr -d ' ')"
  fi
  echo "closures=$closures"
  if [ "$closures" -gt 0 ]; then
    echo "--- closures ---"
    awk -F'\t' -v a="$since_date" '$1 >= a' "$LEDGER"
  fi

  # Records whose front-matter says they moved in span.
  local touched=0 f u
  local touched_list=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    u="$(fm_field "$f" updated)"
    [ -n "$u" ] || continue
    if [ "$u" \> "$since_date" ] || [ "$u" = "$since_date" ]; then
      touched=$((touched + 1))
      touched_list="$touched_list$(rel_to_rr "$f")	$(fm_field "$f" status)
"
    fi
  done <<EOF
$(each_record)
EOF
  echo "records_touched=$touched"
  if [ -n "$touched_list" ]; then
    echo "--- records touched (path, status) ---"
    printf '%s' "$touched_list"
  fi

  # Commit shape.
  if [ "$GIT" = present ]; then
    local commits
    commits="$(git -C "$ROOT" log --since="$since_date" --oneline 2>/dev/null | wc -l | tr -d ' ')"
    echo "commits=$commits"
    if [ "$commits" -gt 0 ]; then
      echo "--- commits by top-level area ---"
      git -C "$ROOT" log --since="$since_date" --name-only --format= 2>/dev/null \
        | grep -v '^$' | awk -F/ '{print $1}' | sort | uniq -c | sort -rn | head -20
      echo "--- commit subjects ---"
      git -C "$ROOT" log --since="$since_date" --format='%cs %h %s' 2>/dev/null | head -60
    fi
  fi
}

cmd_status() {
  setup "$@"
  local open=0 current=0 f st
  local open_list=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    st="$(fm_field "$f" status)"
    case "$st" in
      open)    open=$((open + 1));    open_list="$open_list$(rel_to_rr "$f")	open	$(fm_field "$f" updated)
" ;;
      current) current=$((current + 1)) ;;
    esac
  done <<EOF
$(each_record)
EOF
  echo "open_records=$open"
  echo "current_records=$current"
  [ -n "$open_list" ] && { echo "--- open records (path, status, updated) ---"; printf '%s' "$open_list"; }

  # Trackers are records too, but their LINES are the state.
  if [ -d "$RR/trackers" ]; then
    echo "--- tracker line counts ---"
    for f in "$RR"/trackers/*.md; do
      [ -f "$f" ] || continue
      printf '%s\t%s\n' "$(rel_to_rr "$f")" \
        "$(grep -c -E '^[-*] ' "$f" 2>/dev/null || echo 0)"
    done
  fi

  if [ "$GIT" = present ]; then
    echo "branch=$(git -C "$ROOT" branch --show-current 2>/dev/null || echo detached)"
    echo "dirty=$([ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ] && echo true || echo false)"
    local streams
    streams="$(git -C "$ROOT" worktree list 2>/dev/null | grep -c 'workstreams' || true)"
    echo "active_streams=${streams:-0}"
  fi
}

cmd_health() {
  setup "$@"
  local today cutoff
  today="$(date +%Y-%m-%d)"
  # 90 days back, portable across BSD/GNU date.
  cutoff="$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d '90 days ago' +%Y-%m-%d)"
  echo "today=$today"
  echo "stale_cutoff=$cutoff"

  local bugs=0 stale=0 f st u
  local bug_list="" stale_list=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    st="$(fm_field "$f" status)"
    u="$(fm_field "$f" updated)"
    case "$f" in
      "$RR"/bugs/*)
        if [ "$st" = open ]; then
          bugs=$((bugs + 1)); bug_list="$bug_list$(rel_to_rr "$f")	$u
"
        fi ;;
    esac
    if [ "$st" = open ] && [ -n "$u" ] && [ "$u" \< "$cutoff" ]; then
      stale=$((stale + 1)); stale_list="$stale_list$(rel_to_rr "$f")	$u
"
    fi
  done <<EOF
$(each_record)
EOF
  echo "open_bugs=$bugs"
  echo "stale_open_records=$stale"
  [ -n "$bug_list" ]   && { echo "--- open bugs (path, updated) ---"; printf '%s' "$bug_list"; }
  [ -n "$stale_list" ] && { echo "--- stale open records (path, updated) ---"; printf '%s' "$stale_list"; }

  # Recorded audit reports: the project's OWN instrument is the authority on
  # scored health. We report their existence and dates; we never re-derive a
  # score, and we never run the gate.
  local audits=0
  if [ -d "$RR/reports" ]; then
    audits="$(grep -l -E '^tags:.*audit' "$RR"/reports/*.md 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$audits" -gt 0 ]; then
      echo "--- audit reports (path, updated) ---"
      for f in $(grep -l -E '^tags:.*audit' "$RR"/reports/*.md 2>/dev/null); do
        printf '%s\t%s\n' "$(rel_to_rr "$f")" "$(fm_field "$f" updated)"
      done
    fi
  fi
  echo "audit_reports=$audits"
  echo "gate_state=unknown-not-run"   # never run here; read from records above

  if [ -f "$LEDGER" ]; then
    echo "ledger_lines=$(wc -l < "$LEDGER" | tr -d ' ')"
    echo "ledger_last=$(tail -n 1 "$LEDGER" | cut -f1)"
  fi
}

cmd_subsystem() {
  setup "$@"; shift
  local paths=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --path) [ $# -ge 2 ] || usage; paths+=("$2"); shift 2 ;;
      *) usage ;;
    esac
  done
  [ ${#paths[@]} -gt 0 ] || err "subsystem requires at least one --path"
  echo "paths=${paths[*]}"

  local p
  for p in "${paths[@]}"; do
    echo "path_exists[$p]=$([ -e "$ROOT/$p" ] && echo true || echo false)"
  done

  # Records naming any of these paths.
  echo "--- records referencing these paths ---"
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    for p in "${paths[@]}"; do
      if grep -q -F -- "$p" "$f" 2>/dev/null; then
        printf '%s\t%s\n' "$(rel_to_rr "$f")" "$(fm_field "$f" status)"
        break
      fi
    done
  done <<EOF
$(each_record)
EOF

  if [ "$GIT" = present ]; then
    echo "--- commit history for these paths (recent 40) ---"
    git -C "$ROOT" log --format='%cs %h %s' -40 -- "${paths[@]}" 2>/dev/null || true
    echo "--- churn (commits touching each path) ---"
    for p in "${paths[@]}"; do
      printf '%s\t%s\n' "$p" \
        "$(git -C "$ROOT" log --oneline -- "$p" 2>/dev/null | wc -l | tr -d ' ')"
    done
  fi
}

cmd_catalog() {
  setup "$@"
  local deployed="$RR/templates/analyst"
  local bundled
  bundled="$(cd "$(dirname "$0")/../templates" && pwd)"
  echo "bundled_dir=$bundled"
  echo "deployed_dir=$deployed"
  echo "deployed=$([ -d "$deployed" ] && echo true || echo false)"
  echo "--- templates (token, source) ---"
  local f tok
  for f in "$bundled"/*.md; do
    [ -f "$f" ] || continue
    tok="$(fm_field "$f" template)"
    if [ -f "$deployed/$(basename "$f")" ]; then
      printf '%s\tdeployed\n' "$tok"
    else
      printf '%s\tbundled\n' "$tok"
    fi
  done
  # Host-added templates the bundle does not carry.
  if [ -d "$deployed" ]; then
    for f in "$deployed"/*.md; do
      [ -f "$f" ] || continue
      [ -f "$bundled/$(basename "$f")" ] && continue
      printf '%s\thost-added\n' "$(fm_field "$f" template)"
    done
  fi
}

[ $# -ge 1 ] || usage
sub="$1"; shift
case "$sub" in
  span)      cmd_span "$@" ;;
  status)    cmd_status "$@" ;;
  health)    cmd_health "$@" ;;
  subsystem) cmd_subsystem "$@" ;;
  topic)     cmd_subsystem "$@" ;;   # guide uses the same path-scoped facts
  catalog)   cmd_catalog "$@" ;;
  *) usage ;;
esac
