#!/usr/bin/env bash
# workstream.sh <root> <operation> [args...]
#
# Guarded state provider for the composed Workstream runtime. Both the bundled
# and installed copies require the canonical root explicitly. Agent-facing
# callers consume compact projections; workstream.tsv is never an input or
# output surface for an agent.
set -euo pipefail

die() {
  echo "workstream.sh: $*" >&2
  exit 2
}

usage() {
  cat >&2 <<'EOF'
usage: workstream.sh <canonical-root> <operation> [args...]

  runtime-init <stream> <target> [brief]
  read <stream>
  state <stream>
  diagnose <stream>
  operator-note <stream> <note>
  phase-set <stream> <phase> <next-action>
  contract-recover <stream>
  unit-begin <stream> <slug> <summary>
  unit-complete <stream>
  hook-start <stream> <identity> --isolation <available|unavailable>
  hook-complete <stream> <identity> --closure <path>
  ship-prepare <stream>
  gate-run <stream> --class <docs|full> --label <label> -- <argv...>
  land-advance <stream> --authority confirmed
  ship-finalize <stream>
  validate-tracker <path>
EOF
}

canonical_dir() {
  [ -d "$1" ] && [ ! -L "$1" ] || return 1
  (cd "$1" && pwd -P)
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

sha256_text() {
  local temp
  temp="$(mktemp "${TMPDIR:-/tmp}/workstream-hash.XXXXXX")"
  printf '%s' "$1" >"$temp"
  sha256_file "$temp"
  rm -f "$temp"
}

runbook_contract_hash() {
  local file="$1" temp
  temp="$(mktemp "${TMPDIR:-/tmp}/workstream-contract.XXXXXX")"
  awk '
    /^<!-- workstream:(identity|policy)@1 -->$/ || /^<!-- workstream:hook:(feature-completion|ship-friction)@1 -->$/ { inside=1 }
    inside { print }
    /^<!-- \/workstream:(identity|policy)@1 -->$/ || /^<!-- \/workstream:hook:(feature-completion|ship-friction)@1 -->$/ { inside=0 }
  ' "$file" >"$temp"
  sha256_file "$temp"
  rm -f "$temp"
}

file_fingerprint() {
  if [ -f "$1" ] && [ ! -L "$1" ]; then
    sha256_file "$1"
  else
    printf '%s\n' absent
  fi
}

validate_stream_name() {
  case "$1" in
    ''|*[!a-z0-9-]*|-*|*-|*--*) die "invalid stream name: $1" ;;
  esac
}

validate_ref() {
  git check-ref-format --branch "$1" >/dev/null 2>&1 || die "invalid ref: $1"
}

validate_text() {
  local label="$1" value="$2" allow_dash="${3:-no}"
  [ -n "$value" ] && [ "${#value}" -le 4096 ] || die "$label must be 1..4096 bytes"
  [ "$allow_dash" = yes ] || [ "$value" != - ] || die "$label cannot be a sentinel"
  if LC_ALL=C printf '%s' "$value" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    die "$label contains a control character"
  fi
}

ROOT=""
SELF=""

admit_root() {
  local supplied="$1" canonical top primary installed
  canonical="$(canonical_dir "$supplied")" || die "root is not a real directory: $supplied"
  [ "$canonical" = "$supplied" ] || die "root is not canonical: $supplied"
  top="$(git -C "$canonical" rev-parse --show-toplevel 2>/dev/null)" || die "root is not a Git checkout"
  top="$(canonical_dir "$top")" || die "Git top level is unsafe"
  [ "$top" = "$canonical" ] || die "root is not the checkout top level: $supplied"
  primary="$(git -C "$canonical" worktree list --porcelain | sed -n 's/^worktree //p' | sed -n '1p')"
  primary="$(canonical_dir "$primary")" || die "cannot resolve primary worktree"
  [ "$primary" = "$canonical" ] || die "root is a linked worktree, not the primary checkout"

  ROOT="$canonical"
  SELF="$(canonical_dir "$(dirname "$0")")/$(basename "$0")"
  installed="$ROOT/.streams/workstream.sh"
  if [ -e "$installed" ] || [ -L "$installed" ]; then
    [ -f "$installed" ] && [ ! -L "$installed" ] || die "installed helper is unsafe; run /workstream repair"
    installed="$(canonical_dir "$(dirname "$installed")")/$(basename "$installed")"
    [ "$SELF" = "$installed" ] || die "initialized control surface requires $installed; run /workstream repair"
  fi
}

runbook_field() {
  local file="$1" key="$2"
  awk -v key="$key" '
    /^<!-- workstream:identity@1 -->$/ { inside=1; next }
    /^<!-- \/workstream:identity@1 -->$/ { inside=0 }
    inside && index($0, key "\t") == 1 { print substr($0, length(key) + 2); found++ }
    END { if (found != 1) exit 2 }
  ' "$file"
}

runbook_block_field() {
  local file="$1" block="$2" key="$3"
  awk -v block="$block" -v key="$key" '
    $0=="<!-- workstream:" block "@1 -->" { inside=1; next }
    $0=="<!-- /workstream:" block "@1 -->" { inside=0 }
    inside && index($0, key "\t")==1 { split($0,part,"\t"); print part[2]; found++ }
    END { if(found!=1) exit 2 }
  ' "$file"
}

runbook_hook_body() {
  local file="$1" event="$2"
  awk -v event="$event" '
    $0=="<!-- workstream:hook:" event "@1 -->" { inside=1; metadata=1; next }
    $0=="<!-- /workstream:hook:" event "@1 -->" { inside=0 }
    inside && metadata && $0=="" { metadata=0; next }
    inside && !metadata { print }
  ' "$file"
}

validate_config() {
  local file="$1"
  [ -f "$file" ] && [ ! -L "$file" ] || die "configuration is not a regular file"
  awk '
    function fail() { bad=1 }
    /^<!-- workstream:defaults@1 -->$/ { if(state!=""||defaults++) fail(); state="defaults"; next }
    /^<!-- \/workstream:defaults@1 -->$/ { if(state!="defaults") fail(); state=""; next }
    /^<!-- workstream:hook:(feature-completion|ship-friction)@1 -->$/ {
      if(state!="") fail(); event=$0; sub(/^<!-- workstream:hook:/,"",event); sub(/@1 -->$/,"",event)
      if(hooks[event]++) fail(); state="hook"; hookline=0; next
    }
    /^<!-- \/workstream:hook:(feature-completion|ship-friction)@1 -->$/ { if(state!="hook") fail(); state=""; event=""; next }
    /<!-- \/?workstream:/ { fail(); next }
    state=="defaults" {
      if($0 !~ /^(mode|isolation|landing|ship-cadence): [^[:space:]]+$/) fail()
      split($0,p,": "); if(seen[p[1]]++) fail(); scalar[p[1]]=p[2]; next
    }
    state=="hook" {
      hookline++
      if(hookline==1) { if($0!~/^execution: (inline|isolated-preferred|isolated-required)$/) fail(); split($0,p,": "); execution[event]=p[2]; next }
      if(hookline==2) { if($0!~/^concurrency: (serial|parallel-preferred)$/) fail(); split($0,p,": "); concurrency[event]=p[2]; next }
      if(hookline==3) { if($0!="") fail(); next }
      next
    }
    END {
      if(state!="" || defaults!=1 || seen["mode"]!=1 || seen["isolation"]!=1 || seen["landing"]!=1 || seen["ship-cadence"]!=1) fail()
      if(scalar["mode"]!~/^(delegate|manual)$/ || scalar["isolation"]!~/^(worktree|in-place)$/ || scalar["landing"]!~/^(local|push|pr)$/ || scalar["ship-cadence"]!~/^(milestone|per-track|per-stage)$/) fail()
      if(scalar["isolation"]=="worktree" && scalar["landing"]!="local") fail()
      for(e in hooks) if(execution[e]=="inline" && concurrency[e]=="parallel-preferred") fail()
      exit bad ? 2 : 0
    }
  ' "$file" || die "configuration violates workstream config@1"
}

config_default() {
  local file="$1" key="$2"
  awk -v key="$key" '
    /^<!-- workstream:defaults@1 -->$/ { inside=1; next }
    /^<!-- \/workstream:defaults@1 -->$/ { inside=0 }
    inside && index($0,key ": ")==1 { print substr($0,length(key)+3) }
  ' "$file"
}

config_hook_meta() {
  local file="$1" event="$2" key="$3"
  awk -v event="$event" -v key="$key" '
    $0=="<!-- workstream:hook:" event "@1 -->" { inside=1; next }
    $0=="<!-- /workstream:hook:" event "@1 -->" { inside=0 }
    inside && index($0,key ": ")==1 { print substr($0,length(key)+3) }
  ' "$file"
}

config_hook_body() {
  local file="$1" event="$2"
  awk -v event="$event" '
    $0=="<!-- workstream:hook:" event "@1 -->" { inside=1; line=0; next }
    $0=="<!-- /workstream:hook:" event "@1 -->" { inside=0 }
    inside { line++; if(line>3) print }
  ' "$file"
}

compile_config() {
  local config="$ROOT/.streams/CONFIG.md" event body_var exec_var concurrency_var source_var fingerprint_var combined
  MODE=delegate; ISOLATION=worktree; LANDING=local; SHIP_CADENCE=milestone; DEFAULTS_SOURCE=bundled
  FEATURE_EXECUTION=inline; FEATURE_CONCURRENCY=serial; FEATURE_SOURCE=bundled
  FRICTION_EXECUTION=inline; FRICTION_CONCURRENCY=serial; FRICTION_SOURCE=bundled
  FEATURE_BODY="$(mktemp "${TMPDIR:-/tmp}/workstream-feature.XXXXXX")"
  FRICTION_BODY="$(mktemp "${TMPDIR:-/tmp}/workstream-friction.XXXXXX")"
  : >"$FEATURE_BODY"; : >"$FRICTION_BODY"
  if [ -e "$config" ] || [ -L "$config" ]; then
    validate_config "$config"
    MODE="$(config_default "$config" mode)"; ISOLATION="$(config_default "$config" isolation)"
    LANDING="$(config_default "$config" landing)"; SHIP_CADENCE="$(config_default "$config" ship-cadence)"
    DEFAULTS_SOURCE=project
    for event in feature-completion ship-friction; do
      case "$event" in
        feature-completion) body_var=FEATURE_BODY; exec_var=FEATURE_EXECUTION; concurrency_var=FEATURE_CONCURRENCY; source_var=FEATURE_SOURCE ;;
        ship-friction) body_var=FRICTION_BODY; exec_var=FRICTION_EXECUTION; concurrency_var=FRICTION_CONCURRENCY; source_var=FRICTION_SOURCE ;;
      esac
      if grep -qF "<!-- workstream:hook:$event@1 -->" "$config"; then
        printf -v "$exec_var" '%s' "$(config_hook_meta "$config" "$event" execution)"
        printf -v "$concurrency_var" '%s' "$(config_hook_meta "$config" "$event" concurrency)"
        printf -v "$source_var" '%s' project
        config_hook_body "$config" "$event" >"${!body_var}"
      fi
    done
  fi
  DEFAULTS_FINGERPRINT="$(sha256_text "mode=$MODE|isolation=$ISOLATION|landing=$LANDING|ship-cadence=$SHIP_CADENCE")"
  for event in feature-completion ship-friction; do
    case "$event" in
      feature-completion) body_var=FEATURE_BODY; exec_var=FEATURE_EXECUTION; concurrency_var=FEATURE_CONCURRENCY; fingerprint_var=FEATURE_FINGERPRINT ;;
      ship-friction) body_var=FRICTION_BODY; exec_var=FRICTION_EXECUTION; concurrency_var=FRICTION_CONCURRENCY; fingerprint_var=FRICTION_FINGERPRINT ;;
    esac
    combined="$(mktemp "${TMPDIR:-/tmp}/workstream-hook-config.XXXXXX")"
    printf 'event=%s\nexecution=%s\nconcurrency=%s\n\n' "$event" "${!exec_var}" "${!concurrency_var}" >"$combined"
    cat "${!body_var}" >>"$combined"
    printf -v "$fingerprint_var" '%s' "$(sha256_file "$combined")"
    rm -f "$combined"
  done
}

stream_paths() {
  local stream="$1"
  validate_stream_name "$stream"
  if [ -e "$ROOT/.streams" ] || [ -L "$ROOT/.streams" ]; then
    [ -d "$ROOT/.streams" ] && [ ! -L "$ROOT/.streams" ] || die "control home is unsafe: $ROOT/.streams"
    [ "$(canonical_dir "$ROOT/.streams")" = "$ROOT/.streams" ] || die "control home is not canonical"
  fi
  WT="$ROOT/.streams/$stream"
  RUNBOOK="$WT/WORKSTREAM.md"
  TRACKER="$WT/workstream.tsv"
}

admit_stream_coordinates() {
  local stream="$1" top branch target recorded_root recorded_wt recorded_stream
  stream_paths "$stream"
  [ -d "$WT" ] && [ ! -L "$WT" ] || die "stream runtime is missing or unsafe: $stream"
  [ -f "$RUNBOOK" ] && [ ! -L "$RUNBOOK" ] || die "runbook is missing or unsafe: $RUNBOOK"
  [ -f "$TRACKER" ] && [ ! -L "$TRACKER" ] || die "tracker is missing or unsafe: $TRACKER"
  top="$(git -C "$WT" rev-parse --show-toplevel 2>/dev/null)" || die "stream is not a Git worktree"
  top="$(canonical_dir "$top")" || die "stream top level is unsafe"
  [ "$top" = "$WT" ] || die "stream worktree coordinate disagrees with Git"
  recorded_root="$(runbook_field "$RUNBOOK" root)" || die "invalid runbook root"
  recorded_wt="$(runbook_field "$RUNBOOK" worktree)" || die "invalid runbook worktree"
  recorded_stream="$(runbook_field "$RUNBOOK" stream)" || die "invalid runbook stream"
  branch="$(runbook_field "$RUNBOOK" branch)" || die "invalid runbook branch"
  target="$(runbook_field "$RUNBOOK" target)" || die "invalid runbook target"
  [ "$recorded_root" = "$ROOT" ] || die "runbook root mismatch"
  [ "$recorded_wt" = "$WT" ] || die "runbook worktree mismatch"
  [ "$recorded_stream" = "$stream" ] || die "runbook stream mismatch"
  validate_ref "$branch"
  validate_ref "$target"
  [ "$(git -C "$WT" branch --show-current)" = "$branch" ] || die "stream branch is not held"
  git -C "$WT" rev-parse --verify --quiet "$target^{commit}" >/dev/null || die "target does not resolve"
  validate_tracker "$TRACKER"
}

admit_stream() {
  local stream="$1" pending
  admit_stream_coordinates "$stream"
  pending="$(awk -F '\t' '$1=="meta"&&$2=="-"&&$3=="pending-runbook-contract-sha256"{print $4}' "$TRACKER")"
  [ -z "$pending" ] || die "runbook contract transaction is pending; recover it before ordinary use"
  [ "$(runbook_contract_hash "$RUNBOOK")" = "$(tracker_get meta - runbook-contract-sha256)" ] || die "runbook and tracker are not bound"
}

record_rank_awk='function rank(r) {
  if (r=="meta") return 1; if (r=="queue") return 2; if (r=="phase") return 3;
  if (r=="unit") return 4; if (r=="unit-subject") return 5; if (r=="hook") return 6;
  if (r=="shipment") return 7; if (r=="shipment-unit") return 8;
  if (r=="friction") return 9; if (r=="gate") return 10;
  if (r=="gitlink") return 11; if (r=="delivery") return 12; return 99
}'

canonical_rows() {
  local source="$1" ranked="$2" sorted="$3" tab
  tab=$'\t'
  awk -F '\t' "$record_rank_awk"'{ first=($1=="meta"&&$3=="schema") ? 0 : 1; print rank($1) "\t" first "\t" $0 }' "$source" >"$ranked"
  LC_ALL=C sort -t "$tab" -k1,1n -k2,2n -k4,4 -k5,5 "$ranked" | cut -f3- >"$sorted"
}

validate_tracker() {
  local file="$1" rows ranked sorted
  [ -f "$file" ] && [ ! -L "$file" ] || die "tracker is not a regular file: $file"
  [ "$(sed -n '1p' "$file")" = $'record\tid\tfield\tvalue' ] || die "tracker header is invalid"
  rows="$(mktemp "${TMPDIR:-/tmp}/workstream-rows.XXXXXX")"
  ranked="$(mktemp "${TMPDIR:-/tmp}/workstream-rank.XXXXXX")"
  sorted="$(mktemp "${TMPDIR:-/tmp}/workstream-sort.XXXXXX")"
  tail -n +2 "$file" >"$rows"
  if ! awk -F '\t' "$record_rank_awk"'
    function allowed(r,f) {
      if (r=="meta") return f=="schema"||f=="instance-id"||f=="runbook-contract-sha256"||f=="pending-runbook-contract-sha256"||f=="next-unit"||f=="next-shipment"
      if (r=="queue") return f=="source-kind"||f=="cursor"||f=="state"
      if (r=="phase") return f=="name"||f=="next-action"
      if (r=="unit") return f=="slug"||f=="summary"||f=="state"||f=="boundary"||f=="commit-count"
      if (r=="unit-subject") return f=="subject"
      if (r=="hook") return f=="name"||f=="fingerprint"||f=="state"||f=="inputs-sha256"||f=="evidence-sha256"
      if (r=="shipment") return f=="phase"||f=="outcome"||f=="branch-tip"||f=="target-tip"||f=="inputs-sha256"
      if (r=="shipment-unit") return f=="unit"
      if (r=="friction") return f=="present"
      if (r=="gate") return f=="class"||f=="label"||f=="inputs-sha256"||f=="command-sha256"||f=="outcome"||f=="evidence-sha256"
      if (r=="gitlink") return f=="path"||f=="object"||f=="availability"||f=="published"
      if (r=="delivery") return f=="expected-tip"||f=="candidate-tip"||f=="observed-tip"||f=="state"
      return 0
    }
    NF!=4 { exit 2 }
    rank($1)==99 || !allowed($1,$3) { exit 2 }
    $1=="meta"||$1=="queue"||$1=="phase" { if ($2!="-") exit 2 }
    ($1=="unit"||$1=="shipment"||$1=="gate") && $2!~/^[1-9][0-9]*$/ { exit 2 }
    length($4)>4096 || $4~/\r/ { exit 2 }
    { key=$1 SUBSEP $2 SUBSEP $3; if (seen[key]++) exit 2 }
  ' "$rows"; then
    rm -f "$rows" "$ranked" "$sorted"
    die "tracker rows violate the closed schema"
  fi
  canonical_rows "$rows" "$ranked" "$sorted"
  cmp -s "$rows" "$sorted" || { rm -f "$rows" "$ranked" "$sorted"; die "tracker rows are not canonical"; }
  if ! awk -F '\t' '
    function has(r,i,f) { return ((r SUBSEP i SUBSEP f) in value) }
    function ishex(s,n) { return length(s)==n && s !~ /[^0-9a-f]/ }
    function isobject(s) { return (length(s)==40||length(s)==64) && s !~ /[^0-9a-f]/ }
    function pos(s) { return s ~ /^[1-9][0-9]*$/ }
    function nonneg(s) { return s ~ /^(0|[1-9][0-9]*)$/ }
    function need(r,i,f) { if (!has(r,i,f)) bad=1 }
    function fields(r,i,n,    k,count) { count=0; for(k in value) { split(k,p,SUBSEP); if(p[1]==r&&p[2]==i) count++ } if(count!=n) bad=1 }
    {
      value[$1,$2,$3]=$4
      ids[$1,$2]=1
      for (part=1; part<=4; part++) if ($part ~ /[[:cntrl:]]/) bad=1
    }
    END {
      need("meta","-","schema"); need("meta","-","instance-id"); need("meta","-","runbook-contract-sha256")
      need("meta","-","next-unit"); need("meta","-","next-shipment")
      if(value["meta","-","schema"]!="workstream@1" || !ishex(value["meta","-","instance-id"],32) ||
         !ishex(value["meta","-","runbook-contract-sha256"],64) || !pos(value["meta","-","next-unit"]) ||
         !pos(value["meta","-","next-shipment"])) bad=1
      if(has("meta","-","pending-runbook-contract-sha256") && !ishex(value["meta","-","pending-runbook-contract-sha256"],64)) bad=1
      fields("meta","-",has("meta","-","pending-runbook-contract-sha256")?6:5)

      need("queue","-","cursor"); need("queue","-","source-kind"); need("queue","-","state"); fields("queue","-",3)
      if(value["queue","-","source-kind"]!~/^(plan|roadmap|brief|template)$/ || value["queue","-","state"]!~/^(intake|ready|exhausted)$/) bad=1
      if((value["queue","-","state"]=="ready") != (value["queue","-","cursor"]!="-")) bad=1
      need("phase","-","name"); need("phase","-","next-action"); fields("phase","-",2)
      if(value["phase","-","name"]!~/^(none|plan|build|ship)$/ || value["phase","-","next-action"]!~/^(define-unit|plan|build|feature-hook|accumulate|sync|unpark|prepare-ship|land|await-merge|postflight|recycle|close|blocked)$/) bad=1

      for(key in ids) {
        split(key,a,SUBSEP); r=a[1]; i=a[2]
        if(r=="unit") {
          if(!pos(i)) bad=1
          need(r,i,"boundary"); need(r,i,"commit-count"); need(r,i,"slug"); need(r,i,"state"); need(r,i,"summary"); fields(r,i,5)
          if(!isobject(value[r,i,"boundary"]) || !nonneg(value[r,i,"commit-count"]) || value[r,i,"slug"]=="" || value[r,i,"summary"]=="" || value[r,i,"state"]!~/^(active|complete)$/) bad=1
          if(value[r,i,"state"]=="complete" && value[r,i,"commit-count"]+0<1) bad=1
        } else if(r=="unit-subject") {
          split(i,a2,"/"); if(length(a2)!=2 || !pos(a2[1]) || !pos(a2[2]) || !has("unit",a2[1],"state")) bad=1
          need(r,i,"subject"); fields(r,i,1); if(value[r,i,"subject"]=="") bad=1
          subjects[a2[1]]++; subject_index[a2[1],a2[2]]=1
        } else if(r=="hook") {
          need(r,i,"name"); need(r,i,"fingerprint"); need(r,i,"state"); need(r,i,"inputs-sha256")
          if(value[r,i,"name"]!~/^(feature-completion|ship-friction)$/ || !ishex(value[r,i,"fingerprint"],64) || !ishex(value[r,i,"inputs-sha256"],64) || value[r,i,"state"]!~/^(ready|running|complete|not-applicable)$/) bad=1
          terminal=(value[r,i,"state"]=="complete"||value[r,i,"state"]=="not-applicable")
          if(terminal) { need(r,i,"evidence-sha256"); if(!ishex(value[r,i,"evidence-sha256"],64)) bad=1; fields(r,i,5) }
          else { if(has(r,i,"evidence-sha256")) bad=1; fields(r,i,4) }
        } else if(r=="shipment") {
          if(!pos(i)) bad=1
          need(r,i,"branch-tip"); need(r,i,"inputs-sha256"); need(r,i,"outcome"); need(r,i,"phase"); need(r,i,"target-tip"); fields(r,i,5)
          if(!isobject(value[r,i,"branch-tip"]) || !ishex(value[r,i,"inputs-sha256"],64) || !isobject(value[r,i,"target-tip"]) || value[r,i,"phase"]!~/^(prepare|sync|metadata|gitlinks|gate|friction|ready-to-land|advance|postflight|complete)$/ || value[r,i,"outcome"]!~/^(active|blocked|uncertain|awaiting-merge|landed)$/) bad=1
        } else if(r=="shipment-unit") {
          split(i,a2,"/"); if(length(a2)!=2 || !pos(a2[1]) || !pos(a2[2]) || !has("shipment",a2[1],"phase") || !pos(value[r,i,"unit"]) || !has("unit",value[r,i,"unit"],"state")) bad=1
          need(r,i,"unit"); fields(r,i,1); shipment_index[a2[1],a2[2]]=1; shipment_units[a2[1]]++
        } else if(r=="friction") {
          split(i,a2,"/"); if(length(a2)!=2 || !pos(a2[1]) || !has("shipment",a2[1],"phase") || a2[2]!~/^(rebase-conflict|semantic-conflict|target-reject|remote-reject|repeat-sync|gate-recovery|gitlink-repair|agent-intervention)$/ || value[r,i,"present"]!="yes") bad=1
          need(r,i,"present"); fields(r,i,1)
        } else if(r=="gate") {
          if(!pos(i) || !has("shipment",i,"phase")) bad=1
          need(r,i,"class"); need(r,i,"label"); need(r,i,"inputs-sha256"); need(r,i,"outcome")
          if(value[r,i,"class"]!~/^(none|docs|full|semantic)$/ || value[r,i,"label"]=="" || !ishex(value[r,i,"inputs-sha256"],64) || value[r,i,"outcome"]!~/^(required|running|passed|failed|stale|uncertain)$/) bad=1
          if(value[r,i,"class"]=="none"&&value[r,i,"outcome"]=="passed") { fields(r,i,4); if(has(r,i,"command-sha256")||has(r,i,"evidence-sha256")) bad=1 }
          else if(value[r,i,"outcome"]=="required") { fields(r,i,4); if(has(r,i,"command-sha256")||has(r,i,"evidence-sha256")) bad=1 }
          else if(value[r,i,"outcome"]=="running") { need(r,i,"command-sha256"); if(!ishex(value[r,i,"command-sha256"],64)||has(r,i,"evidence-sha256")) bad=1; fields(r,i,5) }
          else { need(r,i,"command-sha256"); need(r,i,"evidence-sha256"); if(!ishex(value[r,i,"command-sha256"],64)||!ishex(value[r,i,"evidence-sha256"],64)) bad=1; fields(r,i,6) }
        } else if(r=="gitlink") {
          split(i,a2,"/"); if(length(a2)!=2 || !pos(a2[1]) || !ishex(a2[2],64) || !has("shipment",a2[1],"phase")) bad=1
          need(r,i,"availability"); need(r,i,"object"); need(r,i,"path"); need(r,i,"published"); fields(r,i,4)
          if(value[r,i,"availability"]!~/^(ready|transferred|missing)$/ || !isobject(value[r,i,"object"]) || value[r,i,"path"]=="" || value[r,i,"published"]!~/^(yes|no|not-required)$/) bad=1
        } else if(r=="delivery") {
          split(i,a2,"/"); if(length(a2)!=2 || !pos(a2[1]) || a2[2]!~/^(local-target|remote-target)$/ || !has("shipment",a2[1],"phase")) bad=1
          need(r,i,"candidate-tip"); need(r,i,"expected-tip"); need(r,i,"state")
          if(!isobject(value[r,i,"candidate-tip"]) || !isobject(value[r,i,"expected-tip"]) || value[r,i,"state"]!~/^(ready|running|advanced|rejected|uncertain)$/) bad=1
          ended=(value[r,i,"state"]=="advanced"||value[r,i,"state"]=="rejected")
          if(ended) { need(r,i,"observed-tip"); if(!isobject(value[r,i,"observed-tip"])) bad=1; fields(r,i,4) }
          else if(value[r,i,"state"]=="uncertain") { if(has(r,i,"observed-tip")&&!isobject(value[r,i,"observed-tip"])) bad=1; fields(r,i,has(r,i,"observed-tip")?4:3) }
          else { if(has(r,i,"observed-tip")) bad=1; fields(r,i,3) }
          if(value[r,i,"state"]=="advanced"&&value[r,i,"observed-tip"]!=value[r,i,"candidate-tip"]) bad=1
        }
      }
      for(u in subjects) {
        if(value["unit",u,"commit-count"]+0 != subjects[u]) bad=1
        for(j=1;j<=subjects[u];j++) if(!subject_index[u,j]) bad=1
      }
      for(key in ids) { split(key,a,SUBSEP); if(a[1]=="unit"&&value["unit",a[2],"state"]=="complete"&&subjects[a[2]]+0!=value["unit",a[2],"commit-count"]+0) bad=1 }
      for(s in shipment_units) for(j=1;j<=shipment_units[s];j++) if(!shipment_index[s,j]) bad=1
      exit bad ? 2 : 0
    }
  ' "$rows"; then
    rm -f "$rows" "$ranked" "$sorted"
    die "tracker state is contradictory"
  fi
  rm -f "$rows" "$ranked" "$sorted"
}

tracker_get() {
  local record="$1" id="$2" field="$3"
  awk -F '\t' -v r="$record" -v i="$id" -v f="$field" '$1==r&&$2==i&&$3==f { print $4; n++ } END { if (n!=1) exit 2 }' "$TRACKER"
}

rewrite_tracker() {
  local raw="$1" before temp rows ranked sorted current
  before="$(file_fingerprint "$TRACKER")"
  [ "$before" != absent ] || die "tracker disappeared"
  temp="$(mktemp "$WT/.workstream.tsv.XXXXXX")"
  rows="$(mktemp "${TMPDIR:-/tmp}/workstream-newrows.XXXXXX")"
  ranked="$(mktemp "${TMPDIR:-/tmp}/workstream-newrank.XXXXXX")"
  sorted="$(mktemp "${TMPDIR:-/tmp}/workstream-newsort.XXXXXX")"
  cp "$raw" "$rows"
  canonical_rows "$rows" "$ranked" "$sorted"
  { printf 'record\tid\tfield\tvalue\n'; cat "$sorted"; } >"$temp"
  validate_tracker "$temp"
  if [ -n "${WORKSTREAM_TEST_BEFORE_REPLACE:-}" ]; then
    "$WORKSTREAM_TEST_BEFORE_REPLACE" "$TRACKER"
  fi
  current="$(file_fingerprint "$TRACKER")"
  [ "$current" = "$before" ] || { rm -f "$temp" "$rows" "$ranked" "$sorted"; die "tracker changed concurrently"; }
  [ ! -L "$WT" ] && [ ! -L "$TRACKER" ] || { rm -f "$temp" "$rows" "$ranked" "$sorted"; die "tracker destination became unsafe"; }
  chmod 600 "$temp"
  mv -f "$temp" "$TRACKER"
  rm -f "$rows" "$ranked" "$sorted"
}

copy_rows_except() {
  local out="$1" record="$2" id="$3" field="${4:-}"
  if [ -n "$field" ]; then
    awk -F '\t' -v r="$record" -v i="$id" -v f="$field" 'NR>1 && !($1==r&&$2==i&&$3==f)' "$TRACKER" >"$out"
  else
    awk -F '\t' -v r="$record" -v i="$id" 'NR>1 && !($1==r&&$2==i)' "$TRACKER" >"$out"
  fi
}

replace_value() {
  local record="$1" id="$2" field="$3" value="$4" raw
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-replace.XXXXXX")"
  copy_rows_except "$raw" "$record" "$id" "$field"
  printf '%s\t%s\t%s\t%s\n' "$record" "$id" "$field" "$value" >>"$raw"
  rewrite_tracker "$raw"
  rm -f "$raw"
}

mint_instance_id() {
  local source="${WORKSTREAM_TEST_ENTROPY_SOURCE:-/dev/urandom}" value
  [ -r "$source" ] || die "secure entropy is unavailable"
  value="$(od -An -N16 -tx1 "$source" 2>/dev/null | tr -d '[:space:]')" || die "secure entropy failed"
  [ "${#value}" -eq 32 ] && [[ "$value" =~ ^[0-9a-f]{32}$ ]] || die "secure entropy returned fewer than 128 bits"
  printf '%s\n' "$value"
}

ensure_exclusions() {
  local exclude
  exclude="$(git -C "$ROOT" rev-parse --git-path info/exclude)"
  case "$exclude" in /*) ;; *) exclude="$ROOT/$exclude" ;; esac
  [ -f "$exclude" ] && [ ! -L "$exclude" ] || die "shared Git exclusion is unsafe"
  for pattern in '/.streams/*/' '/WORKSTREAM.md' '/workstream.tsv'; do
    grep -qxF "$pattern" "$exclude" || printf '%s\n' "$pattern" >>"$exclude"
  done
}

emit_runbook() {
  local stream="$1" instance="$2" branch="$3" target="$4" brief="$5"
  printf '# %s — workstream runbook\n\n' "$stream"
  printf '<!-- workstream:identity@1 -->\n'
  printf 'stream\t%s\ninstance-id\t%s\nroot\t%s\nworktree\t%s\n' "$stream" "$instance" "$ROOT" "$WT"
  printf 'branch\t%s\ntarget\t%s\nisolation\t%s\nlanding\t%s\n' "$branch" "$target" "$ISOLATION" "$LANDING"
  printf '<!-- /workstream:identity@1 -->\n\n'
  printf '<!-- workstream:brief@1 -->\n'
  printf 'purpose\t%s\n' "$brief"
  printf 'orientation\tVerify pointers against Git before trusting them.\n'
  printf 'operator-note\t-\n'
  printf '<!-- /workstream:brief@1 -->\n\n'
  printf '<!-- workstream:policy@1 -->\n'
  printf 'mode\t%s\t%s\nisolation\t%s\t%s\nlanding\t%s\t%s\nship-cadence\t%s\t%s\n' \
    "$MODE" "$DEFAULTS_SOURCE" "$ISOLATION" "$DEFAULTS_SOURCE" "$LANDING" "$DEFAULTS_SOURCE" "$SHIP_CADENCE" "$DEFAULTS_SOURCE"
  printf 'defaults-fingerprint\t%s\t%s\n' "$DEFAULTS_FINGERPRINT" "$DEFAULTS_SOURCE"
  printf '<!-- /workstream:policy@1 -->\n\n'
  printf '<!-- workstream:hook:feature-completion@1 -->\n'
  printf 'execution\t%s\nconcurrency\t%s\nsource\t%s\nfingerprint\t%s\n\n' \
    "$FEATURE_EXECUTION" "$FEATURE_CONCURRENCY" "$FEATURE_SOURCE" "$FEATURE_FINGERPRINT"
  cat "$FEATURE_BODY"
  printf '<!-- /workstream:hook:feature-completion@1 -->\n\n'
  printf '<!-- workstream:hook:ship-friction@1 -->\n'
  printf 'execution\t%s\nconcurrency\t%s\nsource\t%s\nfingerprint\t%s\n\n' \
    "$FRICTION_EXECUTION" "$FRICTION_CONCURRENCY" "$FRICTION_SOURCE" "$FRICTION_FINGERPRINT"
  cat "$FRICTION_BODY"
  printf '<!-- /workstream:hook:ship-friction@1 -->\n'
}

cmd_runtime_init() {
  [ "$#" -ge 2 ] && [ "$#" -le 3 ] || die "usage: runtime-init <stream> <target> [brief]"
  local stream="$1" target="$2" brief="${3:-Ad hoc workstream}" branch instance runbook_candidate tracker_candidate runbook_temp tracker_temp runbook_hash next history
  validate_stream_name "$stream"
  validate_ref "$target"
  validate_text brief "$brief" yes
  git -C "$ROOT" rev-parse --verify --quiet "$target^{commit}" >/dev/null || die "target does not resolve"
  branch="stream/$stream"
  validate_ref "$branch"
  stream_paths "$stream"
  if [ -d "$WT" ] && [ ! -L "$WT" ]; then
    admit_stream "$stream"
    [ "$(runbook_field "$RUNBOOK" target)" = "$target" ] || die "existing stream target differs"
    printf 'status=existing\nstream=%s\ninstance_id=%s\nnext_action=%s\n' \
      "$stream" "$(tracker_get meta - instance-id)" "$(tracker_get phase - next-action)"
    return
  fi
  [ ! -e "$WT" ] && [ ! -L "$WT" ] || die "stream path already exists"
  ! git -C "$ROOT" show-ref --verify --quiet "refs/heads/$branch" || die "stream branch already exists"

  compile_config
  [ "$ISOLATION" = worktree ] && [ "$LANDING" = local ] || die "runtime-init supports local worktree isolation only"
  # The entropy read is deliberately before every repository mutation.
  instance="$(mint_instance_id)"
  next=1
  history="$ROOT/.streams/history.tsv"
  if [ -e "$history" ] || [ -L "$history" ]; then
    validate_history "$history"
    next="$(awk -F '\t' -v stream="$stream" 'NR>1&&$1==stream&&$2+0>=maximum {maximum=$2+1} END{print maximum+0}' "$history")"
    [ "$next" -gt 0 ] || next=1
  fi

  # Build and validate both runtime artifacts before changing Git topology.
  runbook_candidate="$(mktemp "${TMPDIR:-/tmp}/workstream-runbook.XXXXXX")"
  tracker_candidate="$(mktemp "${TMPDIR:-/tmp}/workstream-tracker.XXXXXX")"
  emit_runbook "$stream" "$instance" "$branch" "$target" "$brief" >"$runbook_candidate"
  runbook_hash="$(runbook_contract_hash "$runbook_candidate")"
  rm -f "$FEATURE_BODY" "$FRICTION_BODY"
  {
    printf 'record\tid\tfield\tvalue\n'
    printf 'meta\t-\tschema\tworkstream@1\n'
    printf 'meta\t-\tinstance-id\t%s\n' "$instance"
    printf 'meta\t-\tnext-shipment\t%s\n' "$next"
    printf 'meta\t-\tnext-unit\t%s\n' "$next"
    printf 'meta\t-\trunbook-contract-sha256\t%s\n' "$runbook_hash"
    printf 'queue\t-\tcursor\t-\nqueue\t-\tsource-kind\tbrief\nqueue\t-\tstate\tintake\n'
    printf 'phase\t-\tname\tnone\nphase\t-\tnext-action\tdefine-unit\n'
  } >"$tracker_candidate"
  validate_tracker "$tracker_candidate"

  ensure_exclusions
  mkdir -p "$ROOT/.streams"
  [ -d "$ROOT/.streams" ] && [ ! -L "$ROOT/.streams" ] || die "control home became unsafe"
  git -C "$ROOT" worktree add -q -b "$branch" "$WT" "$target"
  runbook_temp="$(mktemp "$WT/.WORKSTREAM.md.XXXXXX")"
  tracker_temp="$(mktemp "$WT/.workstream.tsv.XXXXXX")"
  cp "$runbook_candidate" "$runbook_temp"
  cp "$tracker_candidate" "$tracker_temp"
  rm -f "$runbook_candidate" "$tracker_candidate"
  [ "$(runbook_contract_hash "$runbook_temp")" = "$runbook_hash" ] || die "runbook candidate changed"
  validate_tracker "$tracker_temp"
  chmod 600 "$runbook_temp" "$tracker_temp"
  mv "$runbook_temp" "$RUNBOOK"
  mv "$tracker_temp" "$TRACKER"
  printf 'status=created\nstream=%s\ninstance_id=%s\nnext_action=define-unit\n' "$stream" "$instance"
}

cmd_state() {
  [ "$#" -eq 1 ] || die "usage: state <stream>"
  local stream="$1" instance branch target phase next queue unit shipment
  admit_stream "$stream"
  instance="$(tracker_get meta - instance-id)"
  branch="$(runbook_field "$RUNBOOK" branch)"
  target="$(runbook_field "$RUNBOOK" target)"
  phase="$(tracker_get phase - name)"
  next="$(tracker_get phase - next-action)"
  queue="$(tracker_get queue - state)"
  unit="$(awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="active" {print $2}' "$TRACKER")"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase" {print $2; exit}' "$TRACKER")"
  printf 'schema=workstream-state@1\nstream=%s\ninstance_id=%s\nbranch=%s\ntarget=%s\nphase=%s\nnext_action=%s\nqueue_state=%s\nactive_unit=%s\nshipment=%s\n' \
    "$stream" "$instance" "$branch" "$target" "$phase" "$next" "$queue" "${unit:--}" "${shipment:--}"
}

cmd_read() {
  [ "$#" -eq 1 ] || die "usage: read <stream>"
  local stream="$1" purpose orientation note instance phase next queue unit shipment
  admit_stream "$stream"
  purpose="$(runbook_block_field "$RUNBOOK" brief purpose)" || die "runbook purpose is malformed"
  orientation="$(runbook_block_field "$RUNBOOK" brief orientation)" || die "runbook orientation is malformed"
  note="$(runbook_block_field "$RUNBOOK" brief operator-note)" || die "runbook operator note is malformed"
  instance="$(tracker_get meta - instance-id)"; phase="$(tracker_get phase - name)"
  next="$(tracker_get phase - next-action)"; queue="$(tracker_get queue - state)"
  unit="$(awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="active" {print $2}' "$TRACKER")"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase" {print $2; exit}' "$TRACKER")"
  printf 'schema=workstream-read@1\nstream=%s\ninstance_id=%s\npurpose=%s\norientation=%s\noperator_note=%s\nstate=phase:%s,queue:%s,unit:%s,shipment:%s\nnext_action=%s\n' \
    "$stream" "$instance" "$purpose" "$orientation" "$note" "$phase" "$queue" "${unit:--}" "${shipment:--}" "$next"
}

cmd_diagnose() {
  [ "$#" -eq 1 ] || die "usage: diagnose <stream>"
  local stream="$1" running complete gates shipment
  admit_stream "$stream"
  running="$(awk -F '\t' '$1=="hook"&&$3=="state"&&$4=="running"{n++}END{print n+0}' "$TRACKER")"
  complete="$(awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="complete"{n++}END{print n+0}' "$TRACKER")"
  gates="$(awk -F '\t' '$1=="gate"&&$3=="outcome"{value=$4}END{print value==""?"none":value}' "$TRACKER")"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase"{print $2 ":" $4; exit}' "$TRACKER")"
  printf 'schema=workstream-diagnose@1\nstream=%s\ntracker=valid\nrunbook=bound\nrunning_hooks=%s\ncompleted_units=%s\ngate=%s\nshipment=%s\nnext_action=%s\n' \
    "$stream" "$running" "$complete" "$gates" "${shipment:-none}" "$(tracker_get phase - next-action)"
}

cmd_operator_note() {
  [ "$#" -eq 2 ] || die "usage: operator-note <stream> <note>"
  local stream="$1" note="$2" before temp current count
  admit_stream "$stream"
  validate_text 'operator note' "$note" yes
  if [ "$(runbook_block_field "$RUNBOOK" brief operator-note)" = "$note" ]; then
    printf 'status=unchanged\nnext_action=%s\n' "$(tracker_get phase - next-action)"
    return
  fi
  before="$(file_fingerprint "$RUNBOOK")"
  temp="$(mktemp "$WT/.WORKSTREAM.md.XXXXXX")"
  awk -v note="$note" '
    /^<!-- workstream:brief@1 -->$/ { inside=1 }
    /^<!-- \/workstream:brief@1 -->$/ { inside=0 }
    inside && index($0,"operator-note\t")==1 { print "operator-note\t" note; changed++; next }
    { print }
    END { if(changed!=1) exit 2 }
  ' "$RUNBOOK" >"$temp" || { rm -f "$temp"; die "operator note span is malformed"; }
  [ "$(runbook_contract_hash "$temp")" = "$(tracker_get meta - runbook-contract-sha256)" ] || { rm -f "$temp"; die "note edit changed managed contract"; }
  if [ -n "${WORKSTREAM_TEST_BEFORE_RUNBOOK_REPLACE:-}" ]; then "$WORKSTREAM_TEST_BEFORE_RUNBOOK_REPLACE" "$RUNBOOK"; fi
  current="$(file_fingerprint "$RUNBOOK")"
  [ "$current" = "$before" ] || { rm -f "$temp"; die "runbook changed concurrently"; }
  [ ! -L "$WT" ] && [ ! -L "$RUNBOOK" ] || { rm -f "$temp"; die "runbook destination became unsafe"; }
  chmod 600 "$temp"
  mv -f "$temp" "$RUNBOOK"
  count="$(runbook_block_field "$RUNBOOK" brief operator-note | wc -c | tr -d ' ')"
  printf 'status=saved\nnote_bytes=%s\nnext_action=%s\n' "$((count - 1))" "$(tracker_get phase - next-action)"
}

cmd_phase_set() {
  [ "$#" -eq 3 ] || die "usage: phase-set <stream> <phase> <next-action>"
  local stream="$1" phase="$2" next="$3" mode raw
  admit_stream "$stream"
  mode="$(runbook_block_field "$RUNBOOK" policy mode)" || die "runbook mode is malformed"
  if [ "$mode" = delegate ]; then [ "$phase" = none ] || die "delegate mode requires phase none"; fi
  case "$phase" in none|plan|build|ship) ;; *) die "invalid phase" ;; esac
  case "$next" in define-unit|plan|build|feature-hook|accumulate|sync|unpark|prepare-ship|land|await-merge|postflight|recycle|close|blocked) ;; *) die "invalid next action" ;; esac
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-phase.XXXXXX")"
  awk -F '\t' 'NR>1 && !(($1=="phase"&&$2=="-"&&($3=="name"||$3=="next-action")))' "$TRACKER" >"$raw"
  printf 'phase\t-\tname\t%s\nphase\t-\tnext-action\t%s\n' "$phase" "$next" >>"$raw"
  rewrite_tracker "$raw"; rm -f "$raw"
  printf 'status=updated\nphase=%s\nnext_action=%s\n' "$phase" "$next"
}

cmd_contract_recover() {
  [ "$#" -eq 1 ] || die "usage: contract-recover <stream>"
  local stream="$1" pending incumbent actual raw outcome
  admit_stream_coordinates "$stream"
  pending="$(awk -F '\t' '$1=="meta"&&$2=="-"&&$3=="pending-runbook-contract-sha256"{print $4}' "$TRACKER")"
  [ -n "$pending" ] || { printf 'status=not-needed\n'; return; }
  incumbent="$(tracker_get meta - runbook-contract-sha256)"
  actual="$(runbook_contract_hash "$RUNBOOK")"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-contract-recover.XXXXXX")"
  if [ "$actual" = "$incumbent" ]; then
    awk -F '\t' 'NR>1 && !(($1=="meta"&&$2=="-"&&$3=="pending-runbook-contract-sha256"))' "$TRACKER" >"$raw"
    outcome=rolled-back
  elif [ "$actual" = "$pending" ]; then
    awk -F '\t' 'NR>1 && !(($1=="meta"&&$2=="-"&&($3=="pending-runbook-contract-sha256"||$3=="runbook-contract-sha256")))' "$TRACKER" >"$raw"
    printf 'meta\t-\trunbook-contract-sha256\t%s\n' "$pending" >>"$raw"
    outcome=promoted
  else
    rm -f "$raw"
    die "runbook matches neither side of the pending contract transaction"
  fi
  rewrite_tracker "$raw"; rm -f "$raw"
  printf 'status=recovered\noutcome=%s\n' "$outcome"
}

closure_field() {
  local file="$1" key="$2"
  awk -v key="$key" 'index($0,key ": ")==1 {print substr($0,length(key)+3); n++} END{if(n!=1)exit 2}' "$file"
}

validate_closure() {
  local file="$1" status summary effects actions
  [ -f "$file" ] && [ ! -L "$file" ] || die "closure is not a regular file"
  [ "$(wc -l <"$file" | tr -d ' ')" -eq 4 ] || die "closure must have exactly four lines"
  [ "$(sed -n '1p' "$file")" != "" ] || die "closure status is missing"
  status="$(closure_field "$file" status)" || die "closure status is malformed"
  summary="$(closure_field "$file" summary)" || die "closure summary is malformed"
  effects="$(closure_field "$file" effects)" || die "closure effects are malformed"
  actions="$(closure_field "$file" parent-actions)" || die "closure parent actions are malformed"
  case "$status" in complete|blocked|uncertain) ;; *) die "closure status is invalid" ;; esac
  validate_text 'closure summary' "$summary"; validate_text 'closure effects' "$effects" yes; validate_text 'closure parent actions' "$actions" yes
  [ "$(sed -n '1p' "$file")" = "status: $status" ] && [ "$(sed -n '2p' "$file")" = "summary: $summary" ] && \
    [ "$(sed -n '3p' "$file")" = "effects: $effects" ] && [ "$(sed -n '4p' "$file")" = "parent-actions: $actions" ] || die "closure rows are not canonical"
  printf '%s\n' "$status"
}

cmd_hook_start() {
  [ "$#" -eq 4 ] && [ "$3" = --isolation ] || die "usage: hook-start <stream> <identity> --isolation <available|unavailable>"
  local stream="$1" identity="$2" availability="$4" event state execution concurrency selected fallback
  admit_stream "$stream"
  case "$availability" in available|unavailable) ;; *) die "invalid isolation capability" ;; esac
  event="$(tracker_get hook "$identity" name)" || die "unknown hook identity"
  state="$(tracker_get hook "$identity" state)" || die "hook state is missing"
  [ "$state" = ready ] || die "hook is $state; explicit reconciliation is required"
  execution="$(runbook_block_field "$RUNBOOK" "hook:$event" execution)" || die "compiled hook policy is malformed"
  concurrency="$(runbook_block_field "$RUNBOOK" "hook:$event" concurrency)" || die "compiled hook policy is malformed"
  selected=inline; fallback=none
  if [ "$concurrency" = parallel-preferred ] || [ "$execution" != inline ]; then
    if [ "$availability" = available ]; then
      selected=isolated
      fallback="$([ "$execution" = isolated-required ] && printf stop || printf inline)"
    elif [ "$execution" = isolated-required ]; then
      die "serial isolation is required but unavailable"
    else
      selected=inline; fallback=inline
    fi
  fi
  replace_value hook "$identity" state running
  printf 'schema=workstream-hook@1\nidentity=%s\nexecution=%s\nfallback=%s\ninstructions:\n' "$identity" "$selected" "$fallback"
  runbook_hook_body "$RUNBOOK" "$event"
}

cmd_hook_complete() {
  [ "$#" -eq 4 ] && [ "$3" = --closure ] || die "usage: hook-complete <stream> <identity> --closure <path>"
  local stream="$1" identity="$2" closure="$4" state status evidence raw
  admit_stream "$stream"
  state="$(tracker_get hook "$identity" state)" || die "unknown hook identity"
  [ "$state" = running ] || die "hook is not running"
  status="$(validate_closure "$closure")"
  if [ "$status" != complete ]; then
    printf 'status=%s\nhook_state=running\nnext_action=blocked\n' "$status"
    return 1
  fi
  evidence="$(sha256_file "$closure")"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-hook-close.XXXXXX")"
  awk -F '\t' -v i="$identity" 'NR>1 && !(($1=="hook"&&$2==i&&($3=="state"||$3=="evidence-sha256"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  printf 'hook\t%s\tevidence-sha256\t%s\nhook\t%s\tstate\tcomplete\nphase\t-\tnext-action\taccumulate\n' "$identity" "$evidence" "$identity" >>"$raw"
  rewrite_tracker "$raw"; rm -f "$raw"
  printf 'status=complete\nevidence_sha256=%s\nnext_action=accumulate\n' "$evidence"
}

cmd_unit_begin() {
  [ "$#" -eq 3 ] || die "usage: unit-begin <stream> <slug> <summary>"
  local stream="$1" slug="$2" summary="$3" id boundary raw
  admit_stream "$stream"
  case "$slug" in ''|*[!a-z0-9-]*) die "invalid unit slug" ;; esac
  validate_text summary "$summary"
  id="$(awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="active" {print $2}' "$TRACKER")"
  if [ -n "$id" ]; then
    [ "$(tracker_get unit "$id" slug)" = "$slug" ] && [ "$(tracker_get unit "$id" summary)" = "$summary" ] || die "a different active unit already exists"
    printf 'status=resumed\nunit=%s\nnext_action=%s\n' "$id" "$(tracker_get phase - next-action)"
    return
  fi
  ! awk -F '\t' '$1=="shipment" {found=1} END{exit found?0:1}' "$TRACKER" || die "a shipment is active"
  id="$(tracker_get meta - next-unit)"
  boundary="$(git -C "$WT" rev-parse HEAD)"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-unit.XXXXXX")"
  awk -F '\t' 'NR>1 && !(($1=="meta"&&$2=="-"&&$3=="next-unit")||($1=="queue"&&$2=="-"&&($3=="cursor"||$3=="state"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  {
    printf 'meta\t-\tnext-unit\t%s\n' "$((id + 1))"
    printf 'queue\t-\tcursor\t%s\nqueue\t-\tstate\tready\n' "$slug"
    printf 'phase\t-\tnext-action\tbuild\n'
    printf 'unit\t%s\tslug\t%s\nunit\t%s\tsummary\t%s\nunit\t%s\tstate\tactive\nunit\t%s\tboundary\t%s\nunit\t%s\tcommit-count\t0\n' \
      "$id" "$slug" "$id" "$summary" "$id" "$id" "$boundary" "$id"
  } >>"$raw"
  rewrite_tracker "$raw"
  rm -f "$raw"
  printf 'status=unit-started\nunit=%s\nnext_action=build\n' "$id"
}

cmd_unit_complete() {
  [ "$#" -eq 1 ] || die "usage: unit-complete <stream>"
  local stream="$1" id boundary count raw index instance identity fingerprint inputs evidence subject hook_body hook_state next
  admit_stream "$stream"
  id="$(awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="active" {print $2}' "$TRACKER")"
  if [ -z "$id" ]; then
    id="$(awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="complete" {last=$2} END{print last}' "$TRACKER")"
    [ -n "$id" ] || die "no active unit"
    printf 'status=already-complete\nunit=%s\ncommits=%s\nnext_action=%s\n' \
      "$id" "$(tracker_get unit "$id" commit-count)" "$(tracker_get phase - next-action)"
    return
  fi
  boundary="$(tracker_get unit "$id" boundary)"
  count="$(git -C "$WT" rev-list --count "$boundary..HEAD")"
  [ "$count" -gt 0 ] || die "unit has no implementation commit"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-complete.XXXXXX")"
  awk -F '\t' -v id="$id" 'NR>1 && !(($1=="unit"&&$2==id&&($3=="state"||$3=="commit-count"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  printf 'unit\t%s\tstate\tcomplete\nunit\t%s\tcommit-count\t%s\n' "$id" "$id" "$count" >>"$raw"
  index=1
  while IFS= read -r subject; do
    [ -n "$subject" ] || die "empty commit subject"
    [[ "$subject" != *$'\t'* ]] || die "commit subject contains a tab"
    printf 'unit-subject\t%s/%s\tsubject\t%s\n' "$id" "$index" "$subject" >>"$raw"
    index=$((index + 1))
  done < <(git -C "$WT" log --reverse --format='%s' "$boundary..HEAD")
  instance="$(tracker_get meta - instance-id)"
  identity="$stream/$instance/unit/$id/feature-completion"
  fingerprint="$(runbook_block_field "$RUNBOOK" 'hook:feature-completion' fingerprint)" || die "compiled feature hook is malformed"
  inputs="$(sha256_text "$identity|$(git -C "$WT" rev-parse HEAD)")"
  hook_body="$(mktemp "${TMPDIR:-/tmp}/workstream-feature-body.XXXXXX")"
  runbook_hook_body "$RUNBOOK" feature-completion >"$hook_body"
  if grep -q '[^[:space:]]' "$hook_body"; then
    hook_state=ready; next=feature-hook
    printf 'hook\t%s\tname\tfeature-completion\nhook\t%s\tfingerprint\t%s\nhook\t%s\tstate\tready\nhook\t%s\tinputs-sha256\t%s\n' \
      "$identity" "$identity" "$fingerprint" "$identity" "$identity" "$inputs" >>"$raw"
  else
    hook_state=not-applicable; next=accumulate
    evidence="$(sha256_text not-applicable)"
    printf 'hook\t%s\tname\tfeature-completion\nhook\t%s\tfingerprint\t%s\nhook\t%s\tstate\tnot-applicable\nhook\t%s\tinputs-sha256\t%s\nhook\t%s\tevidence-sha256\t%s\n' \
      "$identity" "$identity" "$fingerprint" "$identity" "$identity" "$inputs" "$identity" "$evidence" >>"$raw"
  fi
  rm -f "$hook_body"
  printf 'phase\t-\tnext-action\t%s\n' "$next" >>"$raw"
  rewrite_tracker "$raw"
  rm -f "$raw"
  printf 'status=unit-complete\nunit=%s\ncommits=%s\nhook_state=%s\nnext_action=%s\n' "$id" "$count" "$hook_state" "$next"
}

validate_history() {
  local file="$1"
  [ -f "$file" ] && [ ! -L "$file" ] || die "history is not a regular file"
  [ "$(sed -n '1p' "$file")" = $'stream\tsequence\trecorded_at\ttarget\tunit\tcommits\tsummary' ] || die "history header is invalid"
  LC_ALL=C awk -F '\t' '
    NR==1 { next }
    NF!=7 || $1=="" || $2!~/^[1-9][0-9]*$/ || $3!~/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/ ||
      $4=="" || $5=="" || $6!~/^[1-9][0-9]*$/ || $7=="" { exit 2 }
    {
      for (part=1; part<=7; part++) if (length($part)>4096 || $part~/[[:cntrl:]]/) exit 2
      key=$1 SUBSEP $2
      if (seen[key]++ || ($1 in last && $2+0<=last[$1])) exit 2
      last[$1]=$2+0
    }
  ' "$file" || die "history rows are invalid"
}

cmd_ship_prepare() {
  [ "$#" -eq 1 ] || die "usage: ship-prepare <stream>"
  local stream="$1" shipment next target branch_tip target_tip raw history history_temp now units unit summary commits inputs
  admit_stream "$stream"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase" {print $2; exit}' "$TRACKER")"
  if [ -n "$shipment" ]; then
    printf 'status=resumed\nshipment=%s\nnext_action=%s\n' "$shipment" "$(tracker_get phase - next-action)"
    return
  fi
  units="$(awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="complete" {print $2}' "$TRACKER")"
  [ -n "$units" ] || die "no completed unit to ship"
  next="$(tracker_get meta - next-shipment)"
  target="$(runbook_field "$RUNBOOK" target)"
  history="$WT/.streams/history.tsv"
  mkdir -p "$WT/.streams"
  history_temp="$(mktemp "$WT/.streams/.history.tsv.XXXXXX")"
  if [ -e "$history" ] || [ -L "$history" ]; then
    [ -f "$history" ] && [ ! -L "$history" ] || die "history is unsafe"
    validate_history "$history"
    cp "$history" "$history_temp"
  else
    printf 'stream\tsequence\trecorded_at\ttarget\tunit\tcommits\tsummary\n' >"$history_temp"
  fi
  now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  for unit in $units; do
    if awk -F '\t' -v s="$stream" -v u="$unit" 'NR>1&&$1==s&&$2==u{found=1}END{exit found?0:1}' "$history_temp"; then
      continue
    fi
    summary="$(tracker_get unit "$unit" summary)"
    commits="$(tracker_get unit "$unit" commit-count)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$stream" "$unit" "$now" "$target" "$(tracker_get unit "$unit" slug)" "$commits" "$summary" >>"$history_temp"
  done
  validate_history "$history_temp"
  mv "$history_temp" "$history"
  git -C "$WT" add -- .streams/history.tsv
  if ! git -C "$WT" diff --cached --quiet -- .streams/history.tsv; then
    git -C "$WT" commit -qm "workstream: prepare shipment $next" -- .streams/history.tsv
  fi
  branch_tip="$(git -C "$WT" rev-parse HEAD)"
  target_tip="$(git -C "$WT" rev-parse "$target")"
  inputs="$(sha256_text "$stream|$next|$units|$branch_tip|$target_tip|$target")"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-shipment.XXXXXX")"
  awk -F '\t' 'NR>1 && !(($1=="meta"&&$2=="-"&&$3=="next-shipment")||($1=="phase"&&$2=="-"&&($3=="name"||$3=="next-action")))' "$TRACKER" >"$raw"
  printf 'meta\t-\tnext-shipment\t%s\nphase\t-\tname\tship\nphase\t-\tnext-action\tprepare-ship\n' "$((next + 1))" >>"$raw"
  printf 'shipment\t%s\tphase\tgate\nshipment\t%s\toutcome\tactive\nshipment\t%s\tbranch-tip\t%s\nshipment\t%s\ttarget-tip\t%s\nshipment\t%s\tinputs-sha256\t%s\n' \
    "$next" "$next" "$next" "$branch_tip" "$next" "$target_tip" "$next" "$inputs" >>"$raw"
  local idx=1
  for unit in $units; do
    printf 'shipment-unit\t%s/%s\tunit\t%s\n' "$next" "$idx" "$unit" >>"$raw"
    idx=$((idx + 1))
  done
  rewrite_tracker "$raw"
  rm -f "$raw"
  printf 'status=prepared\nshipment=%s\nbranch_tip=%s\ntarget_tip=%s\nnext_action=prepare-ship\n' "$next" "$branch_tip" "$target_tip"
}

cmd_gate_run() {
  local stream="$1"; shift
  [ "${1:-}" = --class ] || die "gate-run requires --class"
  local class="${2:-}"; shift 2
  [ "${1:-}" = --label ] || die "gate-run requires --label"
  local label="${2:-}"; shift 2
  [ "${1:-}" = -- ] || die "gate-run requires -- before argv"
  shift
  [ "$#" -gt 0 ] || die "gate-run requires argv"
  case "$class" in docs|full) ;; *) die "unsupported direct gate class: $class" ;; esac
  validate_text 'gate label' "$label"
  [ "${#label}" -le 1024 ] || die "gate label exceeds 1024 bytes"
  admit_stream "$stream"
  local shipment inputs command_file output evidence command rc raw branch_tip target_tip shipment_phase
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase" {print $2; exit}' "$TRACKER")"
  [ -n "$shipment" ] || die "no active shipment"
  shipment_phase="$(tracker_get shipment "$shipment" phase)"
  command_file="$(mktemp "${TMPDIR:-/tmp}/workstream-command.XXXXXX")"
  printf '%s\0' "$@" >"$command_file"
  command="$(sha256_file "$command_file")"
  if [ "$shipment_phase" = ready-to-land ]; then
    [ "$(tracker_get gate "$shipment" outcome)" = passed ] && \
      [ "$(tracker_get gate "$shipment" class)" = "$class" ] && \
      [ "$(tracker_get gate "$shipment" label)" = "$label" ] && \
      [ "$(tracker_get gate "$shipment" command-sha256)" = "$command" ] || {
        rm -f "$command_file"
        die "completed gate invocation differs"
      }
    rm -f "$command_file"
    printf 'status=reused\nclass=%s\nlabel=%s\nevidence_sha256=%s\n' \
      "$class" "$label" "$(tracker_get gate "$shipment" evidence-sha256)"
    return
  fi
  [ "$shipment_phase" = gate ] || { rm -f "$command_file"; die "shipment is not at gate"; }
  branch_tip="$(git -C "$WT" rev-parse HEAD)"
  target_tip="$(git -C "$WT" rev-parse "$(runbook_field "$RUNBOOK" target)")"
  [ "$branch_tip" = "$(tracker_get shipment "$shipment" branch-tip)" ] || die "branch changed after preparation"
  [ "$target_tip" = "$(tracker_get shipment "$shipment" target-tip)" ] || die "target changed after preparation"
  inputs="$(tracker_get shipment "$shipment" inputs-sha256)"
  output="$(mktemp "${TMPDIR:-/tmp}/workstream-gate.XXXXXX")"
  rc=0
  (cd "$WT" && "$@") >"$output" 2>&1 || rc=$?
  evidence="$(sha256_file "$output")"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-gaterows.XXXXXX")"
  awk -F '\t' -v s="$shipment" 'NR>1 && !(($1=="gate"&&$2==s)||($1=="shipment"&&$2==s&&($3=="phase"||$3=="outcome"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  printf 'gate\t%s\tclass\t%s\ngate\t%s\tlabel\t%s\ngate\t%s\tinputs-sha256\t%s\ngate\t%s\tcommand-sha256\t%s\ngate\t%s\toutcome\t%s\ngate\t%s\tevidence-sha256\t%s\n' \
    "$shipment" "$class" "$shipment" "$label" "$shipment" "$inputs" "$shipment" "$command" "$shipment" "$([ "$rc" -eq 0 ] && echo passed || echo failed)" "$shipment" "$evidence" >>"$raw"
  if [ "$rc" -eq 0 ]; then
    printf 'shipment\t%s\tphase\tready-to-land\nshipment\t%s\toutcome\tactive\nphase\t-\tnext-action\tland\n' "$shipment" "$shipment" >>"$raw"
  else
    printf 'shipment\t%s\tphase\tgate\nshipment\t%s\toutcome\tblocked\nphase\t-\tnext-action\tblocked\n' "$shipment" "$shipment" >>"$raw"
  fi
  rewrite_tracker "$raw"
  rm -f "$raw" "$command_file"
  printf 'status=%s\nclass=%s\nlabel=%s\nevidence_sha256=%s\noutput_tail:\n' "$([ "$rc" -eq 0 ] && echo passed || echo failed)" "$class" "$label" "$evidence"
  tail -n 7 "$output" | awk '{ print substr($0,1,1024) }'
  rm -f "$output"
  return "$rc"
}

cmd_land_advance() {
  [ "$#" -eq 3 ] && [ "$2" = --authority ] && [ "$3" = confirmed ] || die "landing requires --authority confirmed"
  local stream="$1" shipment candidate expected target raw observed
  admit_stream "$stream"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase" {print $2; exit}' "$TRACKER")"
  [ -n "$shipment" ] || die "no active shipment"
  if [ "$(tracker_get shipment "$shipment" phase)" = postflight ] && \
    [ "$(tracker_get shipment "$shipment" outcome)" = landed ]; then
    candidate="$(tracker_get shipment "$shipment" branch-tip)"
    target="$(runbook_field "$RUNBOOK" target)"
    git -C "$ROOT" merge-base --is-ancestor "$candidate" "$target" || die "recorded landing is not on target"
    printf 'status=already-landed\nshipment=%s\ncandidate=%s\nnext_action=postflight\n' "$shipment" "$candidate"
    return
  fi
  [ "$(tracker_get shipment "$shipment" phase)" = ready-to-land ] || die "shipment is not ready to land"
  candidate="$(tracker_get shipment "$shipment" branch-tip)"
  expected="$(tracker_get shipment "$shipment" target-tip)"
  target="$(runbook_field "$RUNBOOK" target)"
  [ "$(git -C "$WT" rev-parse HEAD)" = "$candidate" ] || die "candidate changed"
  observed="$(git -C "$ROOT" rev-parse "$target")"
  if [ "$observed" != "$candidate" ]; then
    [ "$observed" = "$expected" ] || die "target changed before landing"
    [ "$(git -C "$ROOT" branch --show-current)" = "$target" ] || die "primary checkout is not on the target"
    [ -z "$(git -C "$ROOT" status --porcelain)" ] || die "primary checkout is dirty"
    git -C "$ROOT" merge --ff-only -q "$(runbook_field "$RUNBOOK" branch)"
  fi
  [ "$(git -C "$ROOT" rev-parse "$target")" = "$candidate" ] || die "target advance is uncertain"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-land.XXXXXX")"
  awk -F '\t' -v s="$shipment" 'NR>1 && !(($1=="shipment"&&$2==s&&($3=="phase"||$3=="outcome"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  printf 'shipment\t%s\tphase\tpostflight\nshipment\t%s\toutcome\tlanded\nphase\t-\tnext-action\tpostflight\n' "$shipment" "$shipment" >>"$raw"
  rewrite_tracker "$raw"
  rm -f "$raw"
  printf 'status=landed\nshipment=%s\ncandidate=%s\nnext_action=postflight\n' "$shipment" "$candidate"
}

cmd_ship_finalize() {
  [ "$#" -eq 1 ] || die "usage: ship-finalize <stream>"
  local stream="$1" shipment candidate target raw
  admit_stream "$stream"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase" {print $2; exit}' "$TRACKER")"
  if [ -z "$shipment" ]; then
    [ "$(tracker_get queue - state)" = exhausted ] || die "no shipment to finalize"
    printf 'status=already-finalized\nnext_action=close\n'
    return
  fi
  [ "$(tracker_get shipment "$shipment" phase)" = postflight ] || die "shipment is not in postflight"
  [ "$(tracker_get shipment "$shipment" outcome)" = landed ] || die "shipment has not landed"
  candidate="$(tracker_get shipment "$shipment" branch-tip)"
  target="$(runbook_field "$RUNBOOK" target)"
  git -C "$ROOT" merge-base --is-ancestor "$candidate" "$target" || die "landed candidate is not on target"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-final.XXXXXX")"
  awk -F '\t' 'NR>1 && $1!="unit" && $1!="unit-subject" && $1!="hook" && $1!="shipment" && $1!="shipment-unit" && $1!="friction" && $1!="gate" && $1!="gitlink" && $1!="delivery" && !(($1=="queue"&&$2=="-"&&($3=="cursor"||$3=="state"))||($1=="phase"&&$2=="-"&&($3=="name"||$3=="next-action")))' "$TRACKER" >"$raw"
  printf 'queue\t-\tcursor\t-\nqueue\t-\tstate\texhausted\nphase\t-\tname\tnone\nphase\t-\tnext-action\tclose\n' >>"$raw"
  rewrite_tracker "$raw"
  rm -f "$raw"
  printf 'status=finalized\nshipment=%s\nnext_action=close\n' "$shipment"
}

main() {
  [ "$#" -ge 2 ] || { usage; exit 2; }
  admit_root "$1"
  shift
  local operation="$1"; shift
  case "$operation" in
    runtime-init) cmd_runtime_init "$@" ;;
    read) cmd_read "$@" ;;
    state) cmd_state "$@" ;;
    diagnose) cmd_diagnose "$@" ;;
    operator-note) cmd_operator_note "$@" ;;
    phase-set) cmd_phase_set "$@" ;;
    contract-recover) cmd_contract_recover "$@" ;;
    unit-begin) cmd_unit_begin "$@" ;;
    unit-complete) cmd_unit_complete "$@" ;;
    hook-start) cmd_hook_start "$@" ;;
    hook-complete) cmd_hook_complete "$@" ;;
    ship-prepare) cmd_ship_prepare "$@" ;;
    gate-run) [ "$#" -ge 1 ] || die "gate-run requires a stream"; cmd_gate_run "$@" ;;
    land-advance) cmd_land_advance "$@" ;;
    ship-finalize) cmd_ship_finalize "$@" ;;
    validate-tracker) [ "$#" -eq 1 ] || die "validate-tracker requires one path"; validate_tracker "$1"; printf 'status=valid\n' ;;
    -h|--help|help) usage ;;
    *) die "unknown operation: $operation" ;;
  esac
}

main "$@"
