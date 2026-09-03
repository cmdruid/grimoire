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

  runtime-init <stream> <target> [brief] [--source-kind <brief|plan|roadmap>] [--cursor <value>]
    [--mode <delegate|manual>] [--isolation <worktree|in-place>]
    [--landing <local|push|pr>] [--ship-cadence <milestone|per-track|per-stage>]
  setup
  repair
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
  friction-add <stream> <reason>
  sync <stream>
  park <stream>
  unpark <stream>
  recycle <stream> [--source-kind <brief|plan|roadmap>] [--cursor <value>]
  close-check <stream>
  list
  ship-prepare <stream>
  gate-run <stream> --class <docs|full> --label <label> -- <argv...>
  gate-none <stream>
  land-advance <stream> --authority confirmed
  ship-finalize <stream> [--note <note>]
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
  local label="$1" value="$2" allow_dash="${3:-no}" bytes
  bytes="$(LC_ALL=C printf '%s' "$value" | wc -c | tr -d ' ')"
  [ -n "$value" ] && [ "$bytes" -le 4096 ] || die "$label must be 1..4096 bytes"
  [ "$allow_dash" = yes ] || [ "$value" != - ] || die "$label cannot be a sentinel"
  if LC_ALL=C printf '%s' "$value" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    die "$label contains a control character"
  fi
}

validate_queue_source() { # kind cursor ref
  local kind="$1" cursor="$2" ref="$3" source_file
  case "$kind" in
    brief)
      [ "$cursor" = - ] || die "brief source does not accept a cursor"
      ;;
    plan|roadmap)
      validate_text cursor "$cursor"
      source_file="${cursor%%#*}"
      case "$source_file" in ''|/*|.|..|../*|*/../*|*/..|*:*|*'//'*) die "queue cursor is not a safe root-relative path" ;; esac
      [ "$(git -C "$ROOT" cat-file -t "$ref:$source_file" 2>/dev/null)" = blob ] || die "queue source is not a tracked regular file at $ref"
      ;;
    *) die "invalid queue source kind" ;;
  esac
}

validate_tracked_control_surface() { # checkout
  local checkout="$1" path
  while IFS= read -r -d '' path; do
    case "$path" in
      .streams/.gitignore|.streams/CONFIG.md|.streams/README.md|.streams/history.tsv|.streams/workstream.sh) ;;
      *) die "tracked path is not part of the fixed .streams control surface: $path" ;;
    esac
  done < <(git -C "$checkout" ls-files -z -- .streams)
}

validate_marker_span() { # file opening closing
  local file="$1" opening="$2" closing="$3"
  awk -v opening="$opening" -v closing="$closing" '
    $0==opening {
      if (inside || opened || closed) bad=1
      inside=1; opened++
      next
    }
    $0==closing {
      if (!inside || closed) bad=1
      inside=0; closed++
      next
    }
    END { exit (bad || inside || opened!=closed || opened>1) ? 2 : 0 }
  ' "$file"
}

validate_no_nested_stream_state() { # runtime checkout/state directory
  local runtime="$1" candidate parent relative mode
  [ -d "$runtime" ] && [ ! -L "$runtime" ] || die "stream runtime is unsafe"
  while IFS= read -r candidate; do
    parent="$(dirname "$candidate")"
    [ "$parent" = "$runtime" ] || die "nested stream artifact found: $candidate"
  done < <(find "$runtime" -mindepth 1 \( -name WORKSTREAM.md -o -name workstream.tsv \) -print)
  if find "$runtime" -mindepth 1 -type d -name .workstreams -print -quit | grep -q .; then
    die "nested legacy stream home found in $runtime"
  fi
  if [ -d "$runtime/.streams" ]; then
    [ ! -L "$runtime/.streams" ] || die "nested control home is symlinked"
    if find "$runtime/.streams" -mindepth 1 -type d -print -quit | grep -q .; then
      die "nested stream runtime found below $runtime/.streams"
    fi
  fi
  if find "$runtime" -mindepth 2 -type d -name .streams -print -quit | grep -q .; then
    die "nested stream home found in $runtime"
  fi
  while IFS= read -r candidate; do
    parent="$(dirname "$candidate")"
    case "$parent" in
      "$WT"/*)
        relative="${parent#"$WT"/}"
        mode="$(git -C "$WT" ls-tree HEAD -- "$relative" | awk 'NR==1{print $1}')"
        [ "$mode" = 160000 ] && [ ! -L "$candidate" ] && { [ -f "$candidate" ] || [ -d "$candidate" ]; } && continue
        ;;
    esac
    die "nested Git marker found outside a tracked gitlink: $candidate"
  done < <(find "$runtime" -mindepth 2 -name .git -print)
}

ROOT=""
SELF=""
ADMIT_OPERATION="ordinary"
ALLOW_PARKED="no"
RUNTIME=""
TRACKER_FINGERPRINT=""
RUNBOOK_FINGERPRINT=""
LANDING_LOCK_BACKEND=""

select_landing_lock_backend() {
  local system
  system="$(uname -s 2>/dev/null)" || die "cannot identify a supported landing lock primitive"
  case "$system" in
    Darwin|FreeBSD|NetBSD|OpenBSD|DragonFly)
      command -v lockf >/dev/null 2>&1 || die "landing requires the lockf primitive on $system"
      printf '%s\n' lockf
      ;;
    *)
      command -v flock >/dev/null 2>&1 || die "landing requires the flock primitive on $system"
      printf '%s\n' flock
      ;;
  esac
}

admit_root() {
  local supplied="$1" canonical top primary installed readme initialized=no starts=0 ends=0
  canonical="$(canonical_dir "$supplied")" || die "root is not a real directory: $supplied"
  [ "$canonical" = "$supplied" ] || die "root is not canonical: $supplied"
  top="$(git -C "$canonical" rev-parse --show-toplevel 2>/dev/null)" || die "root is not a Git checkout"
  top="$(canonical_dir "$top")" || die "Git top level is unsafe"
  [ "$top" = "$canonical" ] || die "root is not the checkout top level: $supplied"
  primary="$(git -C "$canonical" worktree list --porcelain | sed -n 's/^worktree //p' | sed -n '1p')"
  primary="$(canonical_dir "$primary")" || die "cannot resolve primary worktree"
  [ "$primary" = "$canonical" ] || die "root is a linked worktree, not the primary checkout"

  ROOT="$canonical"
  validate_tracked_control_surface "$ROOT"
  SELF="$(canonical_dir "$(dirname "$0")")/$(basename "$0")"
  installed="$ROOT/.streams/workstream.sh"
  readme="$ROOT/.streams/README.md"
  if [ -e "$readme" ] || [ -L "$readme" ]; then
    [ -f "$readme" ] && [ ! -L "$readme" ] || {
      case "$ADMIT_OPERATION" in setup|repair|anchor|migrate) return ;; esac
      die "control README is unsafe; run /workstream repair"
    }
    starts="$(grep -cFx '<!-- workstream:control@1 -->' "$readme" || true)"
    ends="$(grep -cFx '<!-- /workstream:control@1 -->' "$readme" || true)"
    if [ "$starts" -ne "$ends" ] || [ "$starts" -gt 1 ] ||
       ! validate_marker_span "$readme" '<!-- workstream:control@1 -->' '<!-- /workstream:control@1 -->'; then
      case "$ADMIT_OPERATION" in setup|repair|anchor|migrate) return ;; esac
      die "control README markers conflict; run /workstream repair"
    fi
    [ "$starts" -eq 0 ] || initialized=yes
  fi
  if [ -e "$installed" ] || [ -L "$installed" ]; then
    if ! { [ -f "$installed" ] && [ ! -L "$installed" ]; }; then
      case "$ADMIT_OPERATION" in setup|repair|anchor|migrate) return ;; esac
      die "installed helper is unsafe; run /workstream repair"
    fi
    if [ "$initialized" = no ]; then
      case "$ADMIT_OPERATION" in setup|repair|anchor|migrate) return ;; esac
      die "installed helper without managed README is partial setup; run /workstream setup"
    fi
    if ! git -C "$ROOT" ls-files --error-unmatch .streams/workstream.sh >/dev/null 2>&1 ||
       ! git -C "$ROOT" diff --quiet -- .streams/workstream.sh ||
       ! git -C "$ROOT" diff --cached --quiet -- .streams/workstream.sh; then
      case "$ADMIT_OPERATION" in setup|repair|anchor|migrate) ;; *) die "installed helper differs from its tracked control artifact; run /workstream repair" ;; esac
    fi
    installed="$(canonical_dir "$(dirname "$installed")")/$(basename "$installed")"
    if [ "$SELF" != "$installed" ]; then
      case "$ADMIT_OPERATION" in setup|repair|anchor|migrate) ;; *) die "initialized control surface requires $installed; run /workstream repair" ;; esac
    fi
  elif [ "$initialized" = yes ]; then
    case "$ADMIT_OPERATION" in setup|repair|anchor|migrate) ;; *) die "initialized control surface is missing its helper; run /workstream repair" ;; esac
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

runbook_policy_part() { # file key column
  local file="$1" key="$2" column="$3"
  awk -F '\t' -v key="$key" -v column="$column" '
    /^<!-- workstream:policy@1 -->$/ { inside=1; next }
    /^<!-- \/workstream:policy@1 -->$/ { inside=0 }
    inside && $1==key { print $column; found++ }
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

compiled_hook_fingerprint() { # event execution concurrency body-file
  local event="$1" execution="$2" concurrency="$3" body="$4" combined fingerprint
  combined="$(mktemp "${TMPDIR:-/tmp}/workstream-hook-config.XXXXXX")"
  printf 'event=%s\nexecution=%s\nconcurrency=%s\n\n' "$event" "$execution" "$concurrency" >"$combined"
  cat "$body" >>"$combined"; fingerprint="$(sha256_file "$combined")"; rm -f "$combined"; printf '%s\n' "$fingerprint"
}

compile_config() {
  local config="$ROOT/.streams/CONFIG.md" event body_var exec_var concurrency_var source_var fingerprint_var
  MODE=delegate; ISOLATION=worktree; LANDING=local; SHIP_CADENCE=milestone; DEFAULTS_SOURCE=bundled
  MODE_SOURCE=bundled; ISOLATION_SOURCE=bundled; LANDING_SOURCE=bundled; SHIP_CADENCE_SOURCE=bundled
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
    MODE_SOURCE=project; ISOLATION_SOURCE=project; LANDING_SOURCE=project; SHIP_CADENCE_SOURCE=project
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
    printf -v "$fingerprint_var" '%s' "$(compiled_hook_fingerprint "$event" "${!exec_var}" "${!concurrency_var}" "${!body_var}")"
  done
}

stream_paths() {
  local stream="$1"
  validate_stream_name "$stream"
  if [ -e "$ROOT/.streams" ] || [ -L "$ROOT/.streams" ]; then
    [ -d "$ROOT/.streams" ] && [ ! -L "$ROOT/.streams" ] || die "control home is unsafe: $ROOT/.streams"
    [ "$(canonical_dir "$ROOT/.streams")" = "$ROOT/.streams" ] || die "control home is not canonical"
  fi
  RUNTIME="$ROOT/.streams/$stream"
  WT="$RUNTIME"
  RUNBOOK="$RUNTIME/WORKSTREAM.md"
  TRACKER="$RUNTIME/workstream.tsv"
}

admit_stream_coordinates() {
  local stream="$1" top branch target recorded_root recorded_wt recorded_stream isolation held current
  stream_paths "$stream"
  [ -d "$RUNTIME" ] && [ ! -L "$RUNTIME" ] || die "stream runtime is missing or unsafe: $stream"
  [ -f "$RUNBOOK" ] && [ ! -L "$RUNBOOK" ] || die "runbook is missing or unsafe: $RUNBOOK"
  [ -f "$TRACKER" ] && [ ! -L "$TRACKER" ] || die "tracker is missing or unsafe: $TRACKER"
  RUNBOOK_FINGERPRINT="$(file_fingerprint "$RUNBOOK")"
  recorded_root="$(runbook_field "$RUNBOOK" root)" || die "invalid runbook root"
  recorded_wt="$(runbook_field "$RUNBOOK" worktree)" || die "invalid runbook worktree"
  recorded_stream="$(runbook_field "$RUNBOOK" stream)" || die "invalid runbook stream"
  branch="$(runbook_field "$RUNBOOK" branch)" || die "invalid runbook branch"
  target="$(runbook_field "$RUNBOOK" target)" || die "invalid runbook target"
  isolation="$(runbook_field "$RUNBOOK" isolation)" || die "invalid runbook isolation"
  [ "$recorded_root" = "$ROOT" ] || die "runbook root mismatch"
  [ "$recorded_stream" = "$stream" ] || die "runbook stream mismatch"
  validate_ref "$branch"
  validate_ref "$target"
  case "$isolation" in
    worktree)
      WT="$RUNTIME"
      [ "$recorded_wt" = "$WT" ] || die "runbook worktree mismatch"
      top="$(git -C "$WT" rev-parse --show-toplevel 2>/dev/null)" || die "stream is not a Git worktree"
      top="$(canonical_dir "$top")" || die "stream top level is unsafe"
      [ "$top" = "$WT" ] || die "stream worktree coordinate disagrees with Git"
      [ "$(git -C "$WT" branch --show-current)" = "$branch" ] || die "stream branch is not held"
      git -C "$ROOT" worktree list --porcelain | grep -qxF "worktree $WT" || die "stream worktree is not registered"
      validate_no_nested_stream_state "$RUNTIME"
      ;;
    in-place)
      WT="$ROOT"
      [ "$recorded_wt" = "$ROOT" ] || die "in-place worktree mismatch"
      held="$(git -C "$ROOT" branch --show-current)"
      if [ "$held" != "$branch" ]; then
        [ "$ALLOW_PARKED" = yes ] && [ "$held" = "$target" ] || die "in-place stream branch is not held"
      fi
      if git -C "$ROOT" worktree list --porcelain | awk -v b="refs/heads/$branch" '$1=="branch"&&$2==b{found=1} END{exit found?0:1}'; then
        [ "$held" = "$branch" ] || die "in-place branch is held by another worktree"
      fi
      validate_no_nested_stream_state "$RUNTIME"
      ;;
    *) die "unsupported isolation: $isolation" ;;
  esac
  validate_tracked_control_surface "$WT"
  git -C "$WT" rev-parse --verify --quiet "$target^{commit}" >/dev/null || die "target does not resolve"
  TRACKER_FINGERPRINT="$(file_fingerprint "$TRACKER")"
  [ "$TRACKER_FINGERPRINT" != absent ] || die "tracker disappeared during admission"
  validate_tracker "$TRACKER"
  current="$(file_fingerprint "$TRACKER")"
  [ "$current" = "$TRACKER_FINGERPRINT" ] || die "tracker changed during admission"
  [ "$(file_fingerprint "$RUNBOOK")" = "$RUNBOOK_FINGERPRINT" ] || die "runbook changed during admission"
  [ "$(tracker_get meta - instance-id)" = "$(runbook_field "$RUNBOOK" instance-id)" ] || die "runbook and tracker instance IDs disagree"
  awk -F '\t' -v s="$stream" '$1=="hook"{split($2,p,"/"); if(p[1]!=s) exit 2}' "$TRACKER" || die "hook identity belongs to another stream"
}

admit_stream() {
  local stream="$1" pending
  admit_stream_coordinates "$stream"
  pending="$(awk -F '\t' '$1=="meta"&&$2=="-"&&$3=="pending-runbook-contract-sha256"{print $4}' "$TRACKER")"
  [ -z "$pending" ] || die "runbook contract transaction is pending; recover it before ordinary use"
  [ "$(runbook_contract_hash "$RUNBOOK")" = "$(tracker_get meta - runbook-contract-sha256)" ] || die "runbook and tracker are not bound"
  if [ -n "${WORKSTREAM_TEST_AFTER_TRACKER_SNAPSHOT:-}" ]; then
    "$WORKSTREAM_TEST_AFTER_TRACKER_SNAPSHOT" "$TRACKER"
  fi
  if [ -n "${WORKSTREAM_TEST_AFTER_RUNBOOK_SNAPSHOT:-}" ]; then
    "$WORKSTREAM_TEST_AFTER_RUNBOOK_SNAPSHOT" "$RUNBOOK"
  fi
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
  if ! LC_ALL=C awk -F '\t' "$record_rank_awk"'
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
  if ! LC_ALL=C awk -F '\t' '
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
      if(value["queue","-","source-kind"]~/^(plan|roadmap)$/ && value["queue","-","state"]!="exhausted" && value["queue","-","cursor"]=="-") bad=1
      if(value["queue","-","source-kind"]~/^(brief|template)$/ && value["queue","-","cursor"]!="-") bad=1
      if(value["queue","-","state"]=="exhausted" && value["queue","-","cursor"]!="-") bad=1
      need("phase","-","name"); need("phase","-","next-action"); fields("phase","-",2)
      if(value["phase","-","name"]!~/^(none|plan|build|ship)$/ || value["phase","-","next-action"]!~/^(define-unit|plan|build|feature-hook|accumulate|sync|unpark|prepare-ship|land|await-merge|postflight|recycle|close|blocked)$/) bad=1

      for(key in ids) {
        split(key,a,SUBSEP); r=a[1]; i=a[2]
        if(r=="unit") {
          unit_count++; if(i+0>max_unit) max_unit=i+0
          if(!pos(i)) bad=1
          need(r,i,"boundary"); need(r,i,"commit-count"); need(r,i,"slug"); need(r,i,"state"); need(r,i,"summary"); fields(r,i,5)
          if(!isobject(value[r,i,"boundary"]) || !nonneg(value[r,i,"commit-count"]) || value[r,i,"slug"]=="" || value[r,i,"summary"]=="" || value[r,i,"state"]!~/^(active|complete)$/) bad=1
          if(value[r,i,"state"]=="active") active_units++
          if(value[r,i,"state"]=="complete" && value[r,i,"commit-count"]+0<1) bad=1
        } else if(r=="unit-subject") {
          split(i,a2,"/"); if(length(a2)!=2 || !pos(a2[1]) || !pos(a2[2]) || !has("unit",a2[1],"state")) bad=1
          need(r,i,"subject"); fields(r,i,1); if(value[r,i,"subject"]=="") bad=1
          subjects[a2[1]]++; subject_index[a2[1],a2[2]]=1
        } else if(r=="hook") {
          hook_parts=split(i,h,"/")
          need(r,i,"name"); need(r,i,"fingerprint"); need(r,i,"state"); need(r,i,"inputs-sha256")
          if(value[r,i,"name"]!~/^(feature-completion|ship-friction)$/ || !ishex(value[r,i,"fingerprint"],64) || !ishex(value[r,i,"inputs-sha256"],64) || value[r,i,"state"]!~/^(ready|running|complete|not-applicable)$/) bad=1
          if(hook_parts!=5 || h[1]!~/^[a-z0-9]+(-[a-z0-9]+)*$/ || h[2]!=value["meta","-","instance-id"]) bad=1
          if(value[r,i,"name"]=="feature-completion") {
            if(h[3]!="unit" || !pos(h[4]) || h[5]!="feature-completion" || !has("unit",h[4],"state") || value["unit",h[4],"state"]!="complete") bad=1
          } else {
            if(h[3]!="shipment" || !pos(h[4]) || h[5]!="ship-friction" || !has("shipment",h[4],"phase")) bad=1
            ship_hooks[h[4]]++; ship_hook_state[h[4]]=value[r,i,"state"]
          }
          terminal=(value[r,i,"state"]=="complete"||value[r,i,"state"]=="not-applicable")
          if(terminal) { need(r,i,"evidence-sha256"); if(!ishex(value[r,i,"evidence-sha256"],64)) bad=1; fields(r,i,5) }
          else { if(has(r,i,"evidence-sha256")) bad=1; fields(r,i,4) }
        } else if(r=="shipment") {
          shipment_count++; shipment_id=i; if(i+0>max_shipment) max_shipment=i+0
          if(!pos(i)) bad=1
          need(r,i,"branch-tip"); need(r,i,"inputs-sha256"); need(r,i,"outcome"); need(r,i,"phase"); need(r,i,"target-tip"); fields(r,i,5)
          if(!isobject(value[r,i,"branch-tip"]) || !ishex(value[r,i,"inputs-sha256"],64) || !isobject(value[r,i,"target-tip"]) || value[r,i,"phase"]!~/^(prepare|sync|metadata|gitlinks|gate|friction|ready-to-land|advance|postflight|complete)$/ || value[r,i,"outcome"]!~/^(active|blocked|uncertain|awaiting-merge|landed)$/) bad=1
        } else if(r=="shipment-unit") {
          split(i,a2,"/"); if(length(a2)!=2 || !pos(a2[1]) || !pos(a2[2]) || !has("shipment",a2[1],"phase") || !pos(value[r,i,"unit"]) || !has("unit",value[r,i,"unit"],"state")) bad=1
          need(r,i,"unit"); fields(r,i,1); shipment_index[a2[1],a2[2]]=1; shipment_units[a2[1]]++
          if(value["unit",value[r,i,"unit"],"state"]!="complete") bad=1
        } else if(r=="friction") {
          split(i,a2,"/"); if(length(a2)!=2 || !pos(a2[1]) || !has("shipment",a2[1],"phase") || a2[2]!~/^(rebase-conflict|semantic-conflict|target-reject|remote-reject|repeat-sync|gate-recovery|gitlink-repair|agent-intervention)$/ || value[r,i,"present"]!="yes") bad=1
          need(r,i,"present"); fields(r,i,1)
        } else if(r=="gate") {
          gate_count++
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
        }
      }
      for(u in subjects) {
        if(value["unit",u,"commit-count"]+0 != subjects[u]) bad=1
        for(j=1;j<=subjects[u];j++) if(!subject_index[u,j]) bad=1
      }
      for(key in ids) { split(key,a,SUBSEP); if(a[1]=="unit"&&value["unit",a[2],"state"]=="complete"&&subjects[a[2]]+0!=value["unit",a[2],"commit-count"]+0) bad=1 }
      for(s in shipment_units) for(j=1;j<=shipment_units[s];j++) if(!shipment_index[s,j]) bad=1
      if(active_units>1 || shipment_count>1 || gate_count>1 || (active_units && shipment_count)) bad=1
      if(value["meta","-","next-unit"]+0<=max_unit || value["meta","-","next-shipment"]+0<=max_shipment) bad=1
      if(shipment_count) {
        if(shipment_units[shipment_id]+0<1 || value["phase","-","name"]!="ship") bad=1
        sp=value["shipment",shipment_id,"phase"]; so=value["shipment",shipment_id,"outcome"]; na=value["phase","-","next-action"]
        if(sp=="prepare" && (so!="active" || na!="prepare-ship")) bad=1
        if(sp=="sync" && !((so=="active"&&na=="prepare-ship")||(so=="blocked"&&na=="blocked"))) bad=1
        if(sp=="metadata" && (so!="active" || na!="prepare-ship")) bad=1
        if(sp=="ready-to-land" && (so!="active" || na!="land")) bad=1
        if(sp=="postflight" && (so!="landed" || na!="postflight")) bad=1
        if(sp=="advance" && !((so=="active"&&na=="land")||(so=="uncertain"&&na=="blocked")||(so=="awaiting-merge"&&na=="await-merge"))) bad=1
        if(sp=="gate" && !((so=="active"&&(na=="prepare-ship"||na=="blocked"))||(so=="blocked"&&na=="blocked"))) bad=1
        if(sp=="gitlinks" && (so!="blocked" || na!="blocked")) bad=1
        if(sp=="friction" && (so!~/^(active|blocked)$/ || na!="prepare-ship")) bad=1
        if(sp~/^(ready-to-land|advance|postflight)$/ && (value["gate",shipment_id,"outcome"]!="passed" || ship_hooks[shipment_id]!=1 || ship_hook_state[shipment_id]!~/^(complete|not-applicable)$/)) bad=1
        if(has("gate",shipment_id,"outcome") && value["gate",shipment_id,"inputs-sha256"]!=value["shipment",shipment_id,"inputs-sha256"]) bad=1
      } else {
        pn=value["phase","-","name"]; na=value["phase","-","next-action"]
        if(pn=="none" && na!~/^(define-unit|build|feature-hook|accumulate|sync|unpark|recycle|close|blocked)$/) bad=1
        if(pn=="plan" && na!="plan") bad=1
        if(pn=="build" && na!~/^(build|feature-hook|accumulate)$/) bad=1
        if(pn=="ship" && na!="prepare-ship") bad=1
      }
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

hook_identity() { # stream instance owner sequence event
  printf '%s/%s/%s/%s/%s\n' "$1" "$2" "$3" "$4" "$5"
}

emit_hook_receipt() { # identity event fingerprint inputs state [evidence]
  local identity="$1" event="$2" fingerprint="$3" inputs="$4" state="$5" evidence="${6:-}"
  case "$state" in
    ready|running) [ -z "$evidence" ] || die "nonterminal hook receipt cannot carry evidence" ;;
    complete|not-applicable) [ -n "$evidence" ] || die "terminal hook receipt requires evidence" ;;
    *) die "invalid hook receipt state: $state" ;;
  esac
  printf 'hook\t%s\tfingerprint\t%s\nhook\t%s\tinputs-sha256\t%s\nhook\t%s\tname\t%s\nhook\t%s\tstate\t%s\n' \
    "$identity" "$fingerprint" "$identity" "$inputs" "$identity" "$event" "$identity" "$state"
  [ -z "$evidence" ] || printf 'hook\t%s\tevidence-sha256\t%s\n' "$identity" "$evidence"
}

emit_tracker_base() { # instance next-shipment next-unit runbook-hash cursor source-kind queue-state next-action
  local instance="$1" next_shipment="$2" next_unit="$3" runbook_hash="$4" cursor="$5" source_kind="$6" queue_state="$7" next_action="$8"
  printf 'record\tid\tfield\tvalue\n'
  printf 'meta\t-\tschema\tworkstream@1\nmeta\t-\tinstance-id\t%s\n' "$instance"
  printf 'meta\t-\tnext-shipment\t%s\nmeta\t-\tnext-unit\t%s\nmeta\t-\trunbook-contract-sha256\t%s\n' \
    "$next_shipment" "$next_unit" "$runbook_hash"
  printf 'queue\t-\tcursor\t%s\nqueue\t-\tsource-kind\t%s\nqueue\t-\tstate\t%s\n' "$cursor" "$source_kind" "$queue_state"
  printf 'phase\t-\tname\tnone\nphase\t-\tnext-action\t%s\n' "$next_action"
}

rewrite_tracker() {
  local raw="$1" before temp rows ranked sorted current runtime_before runtime_current tracker_parent
  runtime_before="$(canonical_dir "$RUNTIME")" || die "tracker parent is unsafe"
  tracker_parent="$(canonical_dir "$(dirname "$TRACKER")")" || die "tracker parent is unsafe"
  [ "$runtime_before" = "$RUNTIME" ] && [ "$tracker_parent" = "$RUNTIME" ] || die "tracker parent coordinate is unsafe"
  before="$TRACKER_FINGERPRINT"
  [ -n "$before" ] && [ "$before" != absent ] || die "tracker mutation has no admitted snapshot"
  temp="$(mktemp "$RUNTIME/.workstream.tsv.XXXXXX")"
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
  runtime_current="$(canonical_dir "$RUNTIME")" || { rm -f "$temp" "$rows" "$ranked" "$sorted"; die "tracker parent became unsafe"; }
  [ "$runtime_current" = "$runtime_before" ] && [ ! -L "$RUNTIME" ] && [ ! -L "$WT" ] && [ ! -L "$TRACKER" ] || { rm -f "$temp" "$rows" "$ranked" "$sorted"; die "tracker destination became unsafe"; }
  chmod 600 "$temp"
  mv -f "$temp" "$TRACKER"
  TRACKER_FINGERPRINT="$(file_fingerprint "$TRACKER")"
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
  local exclude parent temp pattern before current parent_before parent_current
  exclude="$(git -C "$ROOT" rev-parse --git-path info/exclude)"
  case "$exclude" in /*) ;; *) exclude="$ROOT/$exclude" ;; esac
  [ -f "$exclude" ] && [ ! -L "$exclude" ] || die "shared Git exclusion is unsafe"
  parent="$(dirname "$exclude")"
  [ -d "$parent" ] && [ ! -L "$parent" ] || die "shared Git exclusion parent is unsafe"
  parent_before="$(canonical_dir "$parent")" || die "shared Git exclusion parent is unsafe"
  before="$(file_fingerprint "$exclude")"
  temp="$(mktemp "$parent/.workstream-exclude.XXXXXX")"
  awk '{ print }' "$exclude" >"$temp"
  for pattern in '/.streams/*/' '/.streams/.migration.tsv' '/WORKSTREAM.md' '/workstream.tsv'; do
    grep -qxF "$pattern" "$temp" || printf '%s\n' "$pattern" >>"$temp"
  done
  chmod "$(stat -f '%Lp' "$exclude" 2>/dev/null || printf 644)" "$temp" 2>/dev/null || chmod 644 "$temp"
  current="$(file_fingerprint "$exclude")"; parent_current="$(canonical_dir "$parent")" || { rm -f "$temp"; die "shared Git exclusion parent became unsafe"; }
  [ "$current" = "$before" ] && [ "$parent_current" = "$parent_before" ] && [ ! -L "$exclude" ] || { rm -f "$temp"; die "shared Git exclusion changed concurrently"; }
  mv -f "$temp" "$exclude"
}

emit_runbook() {
  local stream="$1" instance="$2" branch="$3" target="$4" brief="$5" source_kind="${6:-brief}" source_pointer="${7:--}"
  printf '# %s — workstream runbook\n\n' "$stream"
  printf '<!-- workstream:identity@1 -->\n'
  printf 'stream\t%s\ninstance-id\t%s\nroot\t%s\nworktree\t%s\n' "$stream" "$instance" "$ROOT" "$WT"
  printf 'branch\t%s\ntarget\t%s\nisolation\t%s\nlanding\t%s\n' "$branch" "$target" "$ISOLATION" "$LANDING"
  printf '<!-- /workstream:identity@1 -->\n\n'
  printf '<!-- workstream:brief@1 -->\n'
  printf 'purpose\t%s\n' "$brief"
  printf 'queue-source-kind\t%s\nqueue-source\t%s\n' "$source_kind" "$source_pointer"
  printf 'orientation\tVerify pointers against Git before trusting them.\n'
  printf 'operator-note\t-\n'
  printf '<!-- /workstream:brief@1 -->\n\n'
  printf '<!-- workstream:policy@1 -->\n'
  printf 'mode\t%s\t%s\nisolation\t%s\t%s\nlanding\t%s\t%s\nship-cadence\t%s\t%s\n' \
    "$MODE" "$MODE_SOURCE" "$ISOLATION" "$ISOLATION_SOURCE" "$LANDING" "$LANDING_SOURCE" "$SHIP_CADENCE" "$SHIP_CADENCE_SOURCE"
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
  [ "$#" -ge 2 ] || die "usage: runtime-init <stream> <target> [brief] [options]"
  local stream="$1" target="$2" brief="Ad hoc workstream" branch instance runbook_candidate tracker_candidate runbook_temp tracker_temp runbook_hash next history
  local source_kind=brief cursor=- queue_state=intake mode_opt="" isolation_opt="" landing_opt="" cadence_opt=""
  local source_seen=no cursor_seen=no mode_seen=no isolation_seen=no landing_seen=no cadence_seen=no
  shift 2
  if [ "$#" -gt 0 ] && [[ "$1" != --* ]]; then brief="$1"; shift; fi
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --source-kind)
        [ "$#" -ge 2 ] && [ "$source_seen" = no ] || die "--source-kind requires one value"
        source_kind="$2"; source_seen=yes; shift 2
        ;;
      --cursor)
        [ "$#" -ge 2 ] && [ "$cursor_seen" = no ] || die "--cursor requires one value"
        cursor="$2"; cursor_seen=yes; shift 2
        ;;
      --mode)
        [ "$#" -ge 2 ] && [ "$mode_seen" = no ] || die "--mode requires one value"
        mode_opt="$2"; mode_seen=yes; shift 2
        ;;
      --isolation)
        [ "$#" -ge 2 ] && [ "$isolation_seen" = no ] || die "--isolation requires one value"
        isolation_opt="$2"; isolation_seen=yes; shift 2
        ;;
      --landing)
        [ "$#" -ge 2 ] && [ "$landing_seen" = no ] || die "--landing requires one value"
        landing_opt="$2"; landing_seen=yes; shift 2
        ;;
      --ship-cadence)
        [ "$#" -ge 2 ] && [ "$cadence_seen" = no ] || die "--ship-cadence requires one value"
        cadence_opt="$2"; cadence_seen=yes; shift 2
        ;;
      *) die "unknown runtime-init option: $1" ;;
    esac
  done
  validate_stream_name "$stream"
  validate_ref "$target"
  validate_text brief "$brief" yes
  case "$source_kind" in brief|plan|roadmap) ;; *) die "invalid queue source kind" ;; esac
  case "$mode_opt" in ''|delegate|manual) ;; *) die "invalid mode override" ;; esac
  case "$isolation_opt" in ''|worktree|in-place) ;; *) die "invalid isolation override" ;; esac
  case "$landing_opt" in ''|local|push|pr) ;; *) die "invalid landing override" ;; esac
  case "$cadence_opt" in ''|milestone|per-track|per-stage) ;; *) die "invalid ship-cadence override" ;; esac
  if [ "$source_kind" = plan ] || [ "$source_kind" = roadmap ]; then
    [ "$cursor_seen" = yes ] && [ "$cursor" != - ] || die "$source_kind source requires --cursor"
    queue_state=ready
  else
    [ "$cursor_seen" = no ] || die "brief source does not accept --cursor"
  fi
  git -C "$ROOT" rev-parse --verify --quiet "$target^{commit}" >/dev/null || die "target does not resolve"
  validate_queue_source "$source_kind" "$cursor" "$target"
  if git -C "$ROOT" ls-tree -r --name-only "$target" | awk 'index($0,".streams/")==1 {rest=substr($0,10); if(index(rest,"/")>0)found=1} END{exit found?0:1}'; then
    die "target contains a nested stream-shaped tree"
  fi
  branch="stream/$stream"
  validate_ref "$branch"
  stream_paths "$stream"
  if [ -d "$RUNTIME" ] && [ ! -L "$RUNTIME" ]; then
    admit_stream "$stream"
    [ "$(runbook_field "$RUNBOOK" target)" = "$target" ] || die "existing stream target differs"
    printf 'status=existing\nstream=%s\ninstance_id=%s\nnext_action=%s\n' \
      "$stream" "$(tracker_get meta - instance-id)" "$(tracker_get phase - next-action)"
    return
  fi
  [ ! -e "$WT" ] && [ ! -L "$WT" ] || die "stream path already exists"
  ! git -C "$ROOT" show-ref --verify --quiet "refs/heads/$branch" || die "stream branch already exists"

  compile_config
  if [ -n "$mode_opt" ]; then MODE="$mode_opt"; MODE_SOURCE=explicit; DEFAULTS_SOURCE=explicit; fi
  if [ -n "$isolation_opt" ]; then ISOLATION="$isolation_opt"; ISOLATION_SOURCE=explicit; DEFAULTS_SOURCE=explicit; fi
  if [ -n "$landing_opt" ]; then LANDING="$landing_opt"; LANDING_SOURCE=explicit; DEFAULTS_SOURCE=explicit; fi
  if [ -n "$cadence_opt" ]; then SHIP_CADENCE="$cadence_opt"; SHIP_CADENCE_SOURCE=explicit; DEFAULTS_SOURCE=explicit; fi
  [ "$ISOLATION" != worktree ] || [ "$LANDING" = local ] || die "worktree isolation requires local landing"
  DEFAULTS_FINGERPRINT="$(sha256_text "mode=$MODE|isolation=$ISOLATION|landing=$LANDING|ship-cadence=$SHIP_CADENCE")"
  if [ "$ISOLATION" = in-place ]; then
    [ "$(git -C "$ROOT" branch --show-current)" = "$target" ] || die "in-place creation requires the target branch to be held"
    [ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ] || die "in-place creation requires clean tracked work"
    while IFS= read -r candidate; do
      grep -qE '^isolation[[:space:]]+in-place$' "$candidate" && die "another in-place stream already exists"
    done < <(find "$ROOT/.streams" -mindepth 2 -maxdepth 2 -type f -name WORKSTREAM.md -print 2>/dev/null)
    WT="$ROOT"
  else
    [ "$LANDING" = local ] || die "linked worktree isolation requires local landing"
    WT="$RUNTIME"
  fi
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
  emit_runbook "$stream" "$instance" "$branch" "$target" "$brief" "$source_kind" "$cursor" >"$runbook_candidate"
  runbook_hash="$(runbook_contract_hash "$runbook_candidate")"
  rm -f "$FEATURE_BODY" "$FRICTION_BODY"
  emit_tracker_base "$instance" "$next" "$next" "$runbook_hash" "$cursor" "$source_kind" "$queue_state" define-unit >"$tracker_candidate"
  validate_tracker "$tracker_candidate"

  ensure_exclusions
  mkdir -p "$ROOT/.streams"
  [ -d "$ROOT/.streams" ] && [ ! -L "$ROOT/.streams" ] || die "control home became unsafe"
  if [ "$ISOLATION" = worktree ]; then
    git -C "$ROOT" worktree add -q -b "$branch" "$WT" "$target"
  else
    git -C "$ROOT" branch "$branch" "$target"
    git -C "$ROOT" switch -q "$branch"
    mkdir -p "$RUNTIME"
  fi
  runbook_temp="$(mktemp "$RUNTIME/.WORKSTREAM.md.XXXXXX")"
  tracker_temp="$(mktemp "$RUNTIME/.workstream.tsv.XXXXXX")"
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
  if [ "$(runbook_field "$RUNBOOK" isolation)" = in-place ] &&
     [ "$(git -C "$ROOT" branch --show-current)" = "$target" ]; then next=unpark; fi
  queue="$(tracker_get queue - state)"
  unit="$(awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="active" {print $2}' "$TRACKER")"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase" {print $2; exit}' "$TRACKER")"
  printf 'schema=workstream-state@1\nstream=%s\ninstance_id=%s\nbranch=%s\ntarget=%s\nphase=%s\nnext_action=%s\nqueue_state=%s\nactive_unit=%s\nshipment=%s\n' \
    "$stream" "$instance" "$branch" "$target" "$phase" "$next" "$queue" "${unit:--}" "${shipment:--}"
}

cmd_read() {
  [ "$#" -eq 1 ] || die "usage: read <stream>"
  local stream="$1" purpose orientation note source_kind source_pointer instance phase next queue unit unit_slug unit_summary shipment hook_identity hook_state mode isolation landing cadence branch target
  admit_stream "$stream"
  purpose="$(runbook_block_field "$RUNBOOK" brief purpose)" || die "runbook purpose is malformed"
  orientation="$(runbook_block_field "$RUNBOOK" brief orientation)" || die "runbook orientation is malformed"
  note="$(runbook_block_field "$RUNBOOK" brief operator-note)" || die "runbook operator note is malformed"
  source_kind="$(runbook_block_field "$RUNBOOK" brief queue-source-kind)" || die "runbook queue source is malformed"
  source_pointer="$(runbook_block_field "$RUNBOOK" brief queue-source)" || die "runbook queue source is malformed"
  instance="$(tracker_get meta - instance-id)"; phase="$(tracker_get phase - name)"
  next="$(tracker_get phase - next-action)"; queue="$(tracker_get queue - state)"
  if [ "$(runbook_field "$RUNBOOK" isolation)" = in-place ] &&
     [ "$(git -C "$ROOT" branch --show-current)" = "$(runbook_field "$RUNBOOK" target)" ]; then next=unpark; fi
  unit="$(awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="active" {print $2}' "$TRACKER")"
  if [ -n "$unit" ]; then unit_slug="$(tracker_get unit "$unit" slug)"; unit_summary="$(tracker_get unit "$unit" summary)"; else unit_slug=-; unit_summary=-; fi
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase" {print $2; exit}' "$TRACKER")"
  hook_identity="$(awk -F '\t' '$1=="hook"&&$3=="state"&&($4=="ready"||$4=="running") {print $2; exit}' "$TRACKER")"
  if [ -n "$hook_identity" ]; then hook_state="$(tracker_get hook "$hook_identity" state)"; else hook_identity=-; hook_state=-; fi
  mode="$(runbook_policy_part "$RUNBOOK" mode 2)"; isolation="$(runbook_field "$RUNBOOK" isolation)"
  landing="$(runbook_field "$RUNBOOK" landing)"; cadence="$(runbook_policy_part "$RUNBOOK" ship-cadence 2)"
  branch="$(runbook_field "$RUNBOOK" branch)"; target="$(runbook_field "$RUNBOOK" target)"
  printf 'schema=workstream-read@1\nstream=%s,instance_id=%s\nworktree=%s\ncoordinates=branch:%s,target:%s,isolation:%s,landing:%s\npolicy=mode:%s,ship-cadence:%s\npurpose=%s\norientation=%s\noperator_note=%s\nqueue=source-kind:%s,source:%s,state:%s\nunit=id:%s,slug:%s,summary:%s\nshipment=%s,hook_identity=%s,hook_state=%s\nnext_action=%s\n' \
    "$stream" "$instance" "$WT" "$branch" "$target" "$isolation" "$landing" "$mode" "$cadence" "$purpose" "$orientation" "$note" "$source_kind" "$source_pointer" "$queue" "${unit:--}" "$unit_slug" "$unit_summary" "${shipment:--}" "$hook_identity" "$hook_state" "$next"
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
  local stream="$1" note="$2" before temp note_file current count
  admit_stream "$stream"
  validate_text 'operator note' "$note" yes
  if [ "$(runbook_block_field "$RUNBOOK" brief operator-note)" = "$note" ]; then
    printf 'status=unchanged\nnext_action=%s\n' "$(tracker_get phase - next-action)"
    return
  fi
  before="$RUNBOOK_FINGERPRINT"
  temp="$(mktemp "$RUNTIME/.WORKSTREAM.md.XXXXXX")"
  note_file="$(mktemp "${TMPDIR:-/tmp}/workstream-note.XXXXXX")"
  printf '%s\n' "$note" >"$note_file"
  awk -v note_file="$note_file" '
    BEGIN { if ((getline note < note_file) <= 0 || (getline extra < note_file) > 0) exit 2; close(note_file) }
    /^<!-- workstream:brief@1 -->$/ { inside=1 }
    /^<!-- \/workstream:brief@1 -->$/ { inside=0 }
    inside && index($0,"operator-note\t")==1 { print "operator-note\t" note; changed++; next }
    { print }
    END { if(changed!=1) exit 2 }
  ' "$RUNBOOK" >"$temp" || { rm -f "$temp" "$note_file"; die "operator note span is malformed"; }
  rm -f "$note_file"
  [ "$(runbook_contract_hash "$temp")" = "$(tracker_get meta - runbook-contract-sha256)" ] || { rm -f "$temp"; die "note edit changed managed contract"; }
  if [ -n "${WORKSTREAM_TEST_BEFORE_RUNBOOK_REPLACE:-}" ]; then "$WORKSTREAM_TEST_BEFORE_RUNBOOK_REPLACE" "$RUNBOOK"; fi
  current="$(file_fingerprint "$RUNBOOK")"
  [ "$current" = "$before" ] || { rm -f "$temp"; die "runbook changed concurrently"; }
  [ ! -L "$WT" ] && [ ! -L "$RUNBOOK" ] || { rm -f "$temp"; die "runbook destination became unsafe"; }
  chmod 600 "$temp"
  mv -f "$temp" "$RUNBOOK"
  RUNBOOK_FINGERPRINT="$(file_fingerprint "$RUNBOOK")"
  count="$(runbook_block_field "$RUNBOOK" brief operator-note | wc -c | tr -d ' ')"
  printf 'status=saved\nnote_bytes=%s\nnext_action=%s\n' "$((count - 1))" "$(tracker_get phase - next-action)"
}

cmd_phase_set() {
  [ "$#" -eq 3 ] || die "usage: phase-set <stream> <phase> <next-action>"
  local stream="$1" phase="$2" next="$3" mode raw
  admit_stream "$stream"
  mode="$(runbook_block_field "$RUNBOOK" policy mode)" || die "runbook mode is malformed"
  local current_phase current_next
  current_phase="$(tracker_get phase - name)"; current_next="$(tracker_get phase - next-action)"
  if [ "$mode" = delegate ]; then
    [ "$phase" = none ] || die "delegate mode requires phase none"
    case "$next" in define-unit|accumulate|sync|unpark|recycle|close|blocked) ;; *) die "illegal delegate phase transition" ;; esac
  else
    case "$current_phase:$current_next:$phase:$next" in
      none:define-unit:plan:plan|plan:plan:build:build) ;;
      build:build:ship:prepare-ship|build:feature-hook:ship:prepare-ship|build:accumulate:ship:prepare-ship)
        ! awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="active"{bad=1} $1=="hook"&&$3=="state"&&($4=="ready"||$4=="running"){bad=1} END{exit bad?0:1}' "$TRACKER" || die "manual ship transition requires completed unit work"
        awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="complete"{found=1} END{exit found?0:1}' "$TRACKER" || die "manual ship transition requires a completed unit"
        ;;
      *) die "illegal manual phase transition" ;;
    esac
  fi
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
  local stream="$1" identity="$2" closure="$4" state status evidence raw event shipment next
  admit_stream "$stream"
  state="$(tracker_get hook "$identity" state)" || die "unknown hook identity"
  [ "$state" = running ] || die "hook is not running"
  status="$(validate_closure "$closure")"
  if [ "$status" != complete ]; then
    printf 'status=%s\nhook_state=running\nnext_action=blocked\n' "$status"
    return 1
  fi
  evidence="$(sha256_file "$closure")"
  event="$(tracker_get hook "$identity" name)"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-hook-close.XXXXXX")"
  awk -F '\t' -v i="$identity" 'NR>1 && !(($1=="hook"&&$2==i&&($3=="state"||$3=="evidence-sha256"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  if [ "$event" = ship-friction ]; then
    shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase"{print $2;exit}' "$TRACKER")"
    [ -n "$shipment" ] && [ "$(tracker_get shipment "$shipment" phase)" = friction ] || { rm -f "$raw"; die "ship friction receipt is outside its phase"; }
    awk -F '\t' -v s="$shipment" '!(($1=="shipment"&&$2==s&&($3=="phase"||$3=="outcome")))' "$raw" >"$raw.next"; mv "$raw.next" "$raw"
    printf 'shipment\t%s\tphase\tfriction\nshipment\t%s\toutcome\tactive\n' "$shipment" "$shipment" >>"$raw"
    next=prepare-ship
  else
    next=accumulate
  fi
  printf 'hook\t%s\tevidence-sha256\t%s\nhook\t%s\tstate\tcomplete\nphase\t-\tnext-action\t%s\n' "$identity" "$evidence" "$identity" "$next" >>"$raw"
  rewrite_tracker "$raw"; rm -f "$raw"
  printf 'status=complete\nevidence_sha256=%s\nnext_action=%s\n' "$evidence" "$next"
}

cmd_friction_add() {
  [ "$#" -eq 2 ] || die "usage: friction-add <stream> <reason>"
  local stream="$1" reason="$2" shipment phase raw
  case "$reason" in rebase-conflict|semantic-conflict|target-reject|remote-reject|repeat-sync|gate-recovery|gitlink-repair|agent-intervention) ;; *) die "invalid friction reason" ;; esac
  admit_stream "$stream"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase"{print $2;exit}' "$TRACKER")"; [ -n "$shipment" ] || die "no active shipment"
  phase="$(tracker_get shipment "$shipment" phase)"
  case "$phase" in prepare|sync|metadata|gitlinks|gate|friction|ready-to-land) ;; *) die "cannot add shipment friction during $phase" ;; esac
  if awk -F '\t' -v id="$shipment/$reason" '$1=="friction"&&$2==id{found=1}END{exit found?0:1}' "$TRACKER"; then
    printf 'status=existing\nreason=%s\n' "$reason"; return
  fi
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-friction.XXXXXX")"
  if [ "$phase" = ready-to-land ]; then
    awk -F '\t' -v s="$shipment" 'NR>1 && !(($1=="shipment"&&$2==s&&($3=="phase"||$3=="outcome"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  else
    tail -n +2 "$TRACKER" >"$raw"
  fi
  printf 'friction\t%s/%s\tpresent\tyes\n' "$shipment" "$reason" >>"$raw"
  if [ "$phase" = ready-to-land ]; then
    printf 'shipment\t%s\tphase\tfriction\nshipment\t%s\toutcome\tactive\nphase\t-\tnext-action\tprepare-ship\n' "$shipment" "$shipment" >>"$raw"
  fi
  rewrite_tracker "$raw"; rm -f "$raw"
  printf 'status=recorded\nreason=%s\nnext_action=%s\n' "$reason" "$(tracker_get phase - next-action)"
}

cmd_unit_begin() {
  [ "$#" -eq 3 ] || die "usage: unit-begin <stream> <slug> <summary>"
  local stream="$1" slug="$2" summary="$3" id boundary raw mode
  admit_stream "$stream"
  mode="$(runbook_block_field "$RUNBOOK" policy mode)"
  if [ "$mode" = manual ]; then
    case "$(tracker_get phase - name):$(tracker_get phase - next-action)" in
      build:build|build:accumulate) ;;
      *) die "manual unit work requires the build phase" ;;
    esac
  fi
  case "$slug" in ''|*[!a-z0-9-]*) die "invalid unit slug" ;; esac
  validate_text summary "$summary"
  id="$(awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="active" {print $2}' "$TRACKER")"
  if [ -n "$id" ]; then
    [ "$(tracker_get unit "$id" slug)" = "$slug" ] && [ "$(tracker_get unit "$id" summary)" = "$summary" ] || die "a different active unit already exists"
    printf 'status=resumed\nunit=%s\nnext_action=%s\n' "$id" "$(tracker_get phase - next-action)"
    return
  fi
  ! awk -F '\t' '$1=="shipment" {found=1} END{exit found?0:1}' "$TRACKER" || die "a shipment is active"
  ! awk -F '\t' '$1=="hook"&&$3=="state"&&($4=="ready"||$4=="running"){found=1} END{exit found?0:1}' "$TRACKER" || die "an unresolved hook blocks the next unit"
  id="$(tracker_get meta - next-unit)"
  boundary="$(git -C "$WT" rev-parse HEAD)"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-unit.XXXXXX")"
  awk -F '\t' 'NR>1 && !(($1=="meta"&&$2=="-"&&$3=="next-unit")||($1=="queue"&&$2=="-"&&$3=="state")||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  {
    printf 'meta\t-\tnext-unit\t%s\n' "$((id + 1))"
    printf 'queue\t-\tstate\tready\n'
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
    instance="$(tracker_get meta - instance-id)"
    identity="$(hook_identity "$stream" "$instance" unit "$id" feature-completion)"
    printf 'status=already-complete\nunit=%s\ncommits=%s\nhook_identity=%s\nhook_state=%s\nnext_action=%s\n' \
      "$id" "$(tracker_get unit "$id" commit-count)" "$identity" "$(tracker_get hook "$identity" state)" "$(tracker_get phase - next-action)"
    return
  fi
  boundary="$(tracker_get unit "$id" boundary)"
  [ -z "$(git -C "$WT" status --porcelain --untracked-files=no)" ] || die "unit completion requires clean tracked work"
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
  identity="$(hook_identity "$stream" "$instance" unit "$id" feature-completion)"
  fingerprint="$(runbook_block_field "$RUNBOOK" 'hook:feature-completion' fingerprint)" || die "compiled feature hook is malformed"
  inputs="$(sha256_text "$identity|$(git -C "$WT" rev-parse HEAD)")"
  hook_body="$(mktemp "${TMPDIR:-/tmp}/workstream-feature-body.XXXXXX")"
  runbook_hook_body "$RUNBOOK" feature-completion >"$hook_body"
  if grep -q '[^[:space:]]' "$hook_body"; then
    hook_state=ready; next=feature-hook
    emit_hook_receipt "$identity" feature-completion "$fingerprint" "$inputs" ready >>"$raw"
  else
    hook_state=not-applicable; next=accumulate
    evidence="$(sha256_text not-applicable)"
    emit_hook_receipt "$identity" feature-completion "$fingerprint" "$inputs" not-applicable "$evidence" >>"$raw"
  fi
  rm -f "$hook_body"
  printf 'phase\t-\tnext-action\t%s\n' "$next" >>"$raw"
  rewrite_tracker "$raw"
  rm -f "$raw"
  printf 'status=unit-complete\nunit=%s\ncommits=%s\nhook_identity=%s\nhook_state=%s\nnext_action=%s\n' "$id" "$count" "$identity" "$hook_state" "$next"
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

resolve_history_rebase_conflict() {
  local unmerged base ours theirs combined merged editor_status
  unmerged="$(git -C "$WT" diff --name-only --diff-filter=U)"
  [ "$unmerged" = .streams/history.tsv ] || return 1
  base="$(mktemp "${TMPDIR:-/tmp}/workstream-history-base.XXXXXX")"
  ours="$(mktemp "${TMPDIR:-/tmp}/workstream-history-ours.XXXXXX")"
  theirs="$(mktemp "${TMPDIR:-/tmp}/workstream-history-theirs.XXXXXX")"
  combined="$(mktemp "${TMPDIR:-/tmp}/workstream-history-combined.XXXXXX")"
  merged="$(mktemp "$WT/.streams/.history-union.XXXXXX")"
  git -C "$WT" show :1:.streams/history.tsv >"$base" 2>/dev/null || { rm -f "$base" "$ours" "$theirs" "$combined" "$merged"; return 1; }
  git -C "$WT" show :2:.streams/history.tsv >"$ours" 2>/dev/null || { rm -f "$base" "$ours" "$theirs" "$combined" "$merged"; return 1; }
  git -C "$WT" show :3:.streams/history.tsv >"$theirs" 2>/dev/null || { rm -f "$base" "$ours" "$theirs" "$combined" "$merged"; return 1; }
  if ! (validate_history "$base") || ! (validate_history "$ours") || ! (validate_history "$theirs"); then
    rm -f "$base" "$ours" "$theirs" "$combined" "$merged"
    return 1
  fi
  awk -F '\t' 'NR==FNR&&NR>1{base[$1 SUBSEP $2]=$0;next} NR>1{seen[$1 SUBSEP $2]=$0} END{for(k in base)if(!(k in seen)||seen[k]!=base[k])exit 2}' "$base" "$ours" || { rm -f "$base" "$ours" "$theirs" "$combined" "$merged"; return 1; }
  awk -F '\t' 'NR==FNR&&NR>1{base[$1 SUBSEP $2]=$0;next} NR>1{seen[$1 SUBSEP $2]=$0} END{for(k in base)if(!(k in seen)||seen[k]!=base[k])exit 2}' "$base" "$theirs" || { rm -f "$base" "$ours" "$theirs" "$combined" "$merged"; return 1; }
  { tail -n +2 "$ours"; tail -n +2 "$theirs"; } | LC_ALL=C sort -t $'\t' -k1,1 -k2,2n >"$combined"
  printf 'stream\tsequence\trecorded_at\ttarget\tunit\tcommits\tsummary\n' >"$merged"
  awk -F '\t' 'BEGIN{OFS="\t"} {key=$1 SUBSEP $2; if(key in row){if(row[key]!=$0)exit 2; next} row[key]=$0; print}' "$combined" >>"$merged" || { rm -f "$base" "$ours" "$theirs" "$combined" "$merged"; return 1; }
  if ! (validate_history "$merged"); then rm -f "$base" "$ours" "$theirs" "$combined" "$merged"; return 1; fi
  mv -f "$merged" "$WT/.streams/history.tsv"
  git -C "$WT" add -- .streams/history.tsv
  editor_status=0
  GIT_EDITOR=true git -C "$WT" rebase --continue >/dev/null 2>&1 || editor_status=$?
  rm -f "$base" "$ours" "$theirs" "$combined"
  [ "$editor_status" -eq 0 ]
}

prepare_history_metadata() { # stream shipment unit-ids target
  local stream="$1" shipment="$2" units="$3" target="$4" history history_temp history_before history_current now unit summary commits
  history="$WT/.streams/history.tsv"
  mkdir -p "$WT/.streams"
  history_temp="$(mktemp "$WT/.streams/.history.tsv.XXXXXX")"
  if [ -e "$history" ] || [ -L "$history" ]; then
    [ -f "$history" ] && [ ! -L "$history" ] || die "history is unsafe"
    validate_history "$history"
    history_before="$(file_fingerprint "$history")"
    cp "$history" "$history_temp"
  else
    history_before=absent
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
  history_current="$(file_fingerprint "$history")"
  [ "$history_current" = "$history_before" ] || { rm -f "$history_temp"; die "history changed concurrently"; }
  write_atomic_file "$history" "$history_temp" 644
  rm -f "$history_temp"
  git -C "$WT" add -- .streams/history.tsv
  if ! git -C "$WT" diff --cached --quiet -- .streams/history.tsv; then
    git -C "$WT" commit -qm "workstream: prepare shipment $shipment" -- .streams/history.tsv
  fi
}

prepare_gitlink_rows() { # shipment target-tip landing output
  local shipment="$1" target_tip="$2" landing="$3" output="$4" path object path_id availability published origin_url missing=no
  while IFS= read -r -d '' path; do
    object="$(git -C "$WT" ls-tree HEAD -- "$path" | awk '$1=="160000"{print $3}')"
    [ -n "$object" ] || continue
    validate_text 'gitlink path' "$path"
    path_id="$(sha256_text "$path")"
    availability=missing
    if [ -d "$WT/$path" ] && git -C "$WT/$path" cat-file -e "$object^{commit}" 2>/dev/null; then availability=ready; fi
    if [ "$landing" = local ]; then
      published=not-required
      if [ "$availability" = ready ]; then
        if ! git -C "$ROOT/$path" rev-parse --git-dir >/dev/null 2>&1; then
          mkdir -p "$(dirname "$ROOT/$path")"
          origin_url="$(git -C "$WT/$path" remote get-url origin 2>/dev/null || true)"
          if [ -n "$origin_url" ]; then git -c protocol.file.allow=always clone -q --no-checkout "$origin_url" "$ROOT/$path" 2>/dev/null || true; fi
        fi
        if git -C "$ROOT/$path" rev-parse --git-dir >/dev/null 2>&1; then
          if ! git -C "$ROOT/$path" cat-file -e "$object^{commit}" 2>/dev/null; then
            git -C "$ROOT/$path" fetch -q "$WT/$path" "$object" 2>/dev/null || true
          fi
          if git -C "$ROOT/$path" cat-file -e "$object^{commit}" 2>/dev/null; then availability=transferred; fi
        fi
      fi
    else
      published=no
      if [ "$availability" = ready ] && git -C "$WT/$path" fetch -q origin 2>/dev/null && \
         git -C "$WT/$path" for-each-ref --contains "$object" --format='%(refname)' refs/remotes/origin/ | grep -q .; then
        published=yes
      fi
    fi
    case "$landing:$availability:$published" in local:ready:not-required|local:transferred:not-required|push:ready:yes|pr:ready:yes) ;; *) missing=yes ;; esac
    printf 'gitlink\t%s/%s\tavailability\t%s\ngitlink\t%s/%s\tobject\t%s\ngitlink\t%s/%s\tpath\t%s\ngitlink\t%s/%s\tpublished\t%s\n' \
      "$shipment" "$path_id" "$availability" "$shipment" "$path_id" "$object" "$shipment" "$path_id" "$path" "$shipment" "$path_id" "$published" >>"$output"
  done < <(git -C "$WT" diff --name-only -z --diff-filter=AM "$target_tip..HEAD")
  printf '%s\n' "$missing"
}

cmd_ship_prepare() {
  [ "$#" -eq 1 ] || die "usage: ship-prepare <stream>"
  local stream="$1" shipment target branch_tip target_tip recorded_branch recorded_target raw units unit inputs gitlinks missing phase outcome next_action landing sync_base prior_gate hook_state instance identity fingerprint hook_body friction_inputs current_phase existing_ship_state keep_ship_hook
  admit_stream "$stream"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase" {print $2; exit}' "$TRACKER")"
  [ -z "$(git -C "$WT" status --porcelain --untracked-files=no)" ] || die "shipment preparation requires clean tracked work"
  target="$(runbook_field "$RUNBOOK" target)"
  landing="$(runbook_field "$RUNBOOK" landing)"
  sync_base="$(git -C "$WT" rev-parse "$target")"
  if [ "$landing" = push ] || [ "$landing" = pr ]; then
    git -C "$WT" fetch -q origin "refs/heads/$target" || die "cannot fetch origin/$target"
    sync_base="$(git -C "$WT" rev-parse FETCH_HEAD)"
  fi

  if [ -z "$shipment" ]; then
    ! awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="active"{found=1} $1=="hook"&&$3=="state"&&($4=="ready"||$4=="running"){found=1} END{exit found?0:1}' "$TRACKER" || die "shipment preparation requires completed unit hooks"
    units="$(awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="complete" {print $2}' "$TRACKER")"
    [ -n "$units" ] || die "no completed unit to ship"
    shipment="$(tracker_get meta - next-shipment)"
    branch_tip="$(git -C "$WT" rev-parse HEAD)"
    inputs="$(sha256_text "$stream|$shipment|$units|$branch_tip|$sync_base|$landing|prepare")"
    raw="$(mktemp "${TMPDIR:-/tmp}/workstream-shipment-allocate.XXXXXX")"
    awk -F '\t' 'NR>1 && !(($1=="meta"&&$2=="-"&&$3=="next-shipment")||($1=="phase"&&$2=="-"&&($3=="name"||$3=="next-action")))' "$TRACKER" >"$raw"
    printf 'meta\t-\tnext-shipment\t%s\nphase\t-\tname\tship\nphase\t-\tnext-action\tprepare-ship\n' "$((shipment + 1))" >>"$raw"
    printf 'shipment\t%s\tphase\tprepare\nshipment\t%s\toutcome\tactive\nshipment\t%s\tbranch-tip\t%s\nshipment\t%s\ttarget-tip\t%s\nshipment\t%s\tinputs-sha256\t%s\n' \
      "$shipment" "$shipment" "$shipment" "$branch_tip" "$shipment" "$sync_base" "$shipment" "$inputs" >>"$raw"
    local idx=1
    for unit in $units; do printf 'shipment-unit\t%s/%s\tunit\t%s\n' "$shipment" "$idx" "$unit" >>"$raw"; idx=$((idx + 1)); done
    rewrite_tracker "$raw"; rm -f "$raw"
  else
    units="$(awk -F '\t' -v s="$shipment/" '$1=="shipment-unit"&&index($2,s)==1{print $4}' "$TRACKER")"
  fi

  current_phase="$(tracker_get shipment "$shipment" phase)"
  recorded_branch="$(tracker_get shipment "$shipment" branch-tip)"
  recorded_target="$(tracker_get shipment "$shipment" target-tip)"
  branch_tip="$(git -C "$WT" rev-parse HEAD)"
  prior_gate="$(awk -F '\t' -v s="$shipment" '$1=="gate"&&$2==s&&$3=="outcome"{print $4}' "$TRACKER")"

  # Any changed candidate or target invalidates downstream evidence but never the
  # shipment identity or immutable unit batch.
  if [ "$sync_base" != "$recorded_target" ] || ! git -C "$WT" merge-base --is-ancestor "$sync_base" HEAD; then
    raw="$(mktemp "${TMPDIR:-/tmp}/workstream-sync-receipt.XXXXXX")"
    awk -F '\t' -v s="$shipment" 'NR>1 && $1!="delivery" && !(($1=="gate"&&$2==s)||($1=="gitlink"&&index($2,s "/")==1)||($1=="hook"&&index($2,"/shipment/" s "/ship-friction")>0)||($1=="shipment"&&$2==s&&($3=="phase"||$3=="outcome"||$3=="target-tip"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
    [ "$current_phase" = prepare ] || grep -qF $'friction\t'"$shipment"$'/repeat-sync\tpresent\tyes' "$raw" || printf 'friction\t%s/repeat-sync\tpresent\tyes\n' "$shipment" >>"$raw"
    printf 'shipment\t%s\tphase\tsync\nshipment\t%s\toutcome\tactive\nshipment\t%s\ttarget-tip\t%s\nphase\t-\tnext-action\tprepare-ship\n' "$shipment" "$shipment" "$shipment" "$sync_base" >>"$raw"
    rewrite_tracker "$raw"; rm -f "$raw"
    if ! git -C "$WT" merge-base --is-ancestor "$sync_base" HEAD; then
      if ! git -C "$WT" rebase "$sync_base" >/dev/null 2>&1 && ! resolve_history_rebase_conflict; then
        raw="$(mktemp "${TMPDIR:-/tmp}/workstream-sync-conflict.XXXXXX")"
        tail -n +2 "$TRACKER" >"$raw"
        grep -qF $'friction\t'"$shipment"$'/rebase-conflict\tpresent\tyes' "$raw" || printf 'friction\t%s/rebase-conflict\tpresent\tyes\n' "$shipment" >>"$raw"
        awk -F '\t' -v s="$shipment" '!(($1=="shipment"&&$2==s&&$3=="outcome")||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$raw" >"$raw.next"; mv "$raw.next" "$raw"
        printf 'shipment\t%s\toutcome\tblocked\nphase\t-\tnext-action\tblocked\n' "$shipment" >>"$raw"
        rewrite_tracker "$raw"; rm -f "$raw"
        printf 'status=conflict\nshipment=%s\nphase=sync\nnext_action=blocked\n' "$shipment"
        return 1
      fi
    fi
    branch_tip="$(git -C "$WT" rev-parse HEAD)"
  fi

  if [ "$branch_tip" != "$recorded_branch" ] || [ "$sync_base" != "$recorded_target" ]; then
    instance="$(tracker_get meta - instance-id)"; identity="$(hook_identity "$stream" "$instance" shipment "$shipment" ship-friction)"
    existing_ship_state="$(awk -F '\t' -v i="$identity" '$1=="hook"&&$2==i&&$3=="state"{print $4}' "$TRACKER")"
    keep_ship_hook=no; case "$existing_ship_state" in complete|running) keep_ship_hook=yes ;; esac
    raw="$(mktemp "${TMPDIR:-/tmp}/workstream-candidate-refresh.XXXXXX")"
    awk -F '\t' -v s="$shipment" -v keep="$keep_ship_hook" 'NR>1 && $1!="delivery" && !(($1=="gate"&&$2==s)||($1=="gitlink"&&index($2,s "/")==1)||($1=="hook"&&index($2,"/shipment/" s "/ship-friction")>0&&keep!="yes")||($1=="shipment"&&$2==s&&($3=="branch-tip"||$3=="target-tip"||$3=="inputs-sha256"||$3=="phase"||$3=="outcome"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
    [ "$prior_gate" != failed ] || grep -qF $'friction\t'"$shipment"$'/gate-recovery\tpresent\tyes' "$raw" || printf 'friction\t%s/gate-recovery\tpresent\tyes\n' "$shipment" >>"$raw"
    inputs="$(sha256_text "$stream|$shipment|$units|$branch_tip|$sync_base|$landing|candidate")"
    printf 'shipment\t%s\tbranch-tip\t%s\nshipment\t%s\ttarget-tip\t%s\nshipment\t%s\tinputs-sha256\t%s\nshipment\t%s\tphase\tmetadata\nshipment\t%s\toutcome\tactive\nphase\t-\tnext-action\tprepare-ship\n' \
      "$shipment" "$branch_tip" "$shipment" "$sync_base" "$shipment" "$inputs" "$shipment" "$shipment" >>"$raw"
    rewrite_tracker "$raw"; rm -f "$raw"
  fi

  current_phase="$(tracker_get shipment "$shipment" phase)"
  if [ "$branch_tip" = "$(tracker_get shipment "$shipment" branch-tip)" ] &&
     [ "$sync_base" = "$(tracker_get shipment "$shipment" target-tip)" ]; then
    case "$current_phase" in
      ready-to-land)
        printf 'status=ready\nshipment=%s\nbranch_tip=%s\ntarget_tip=%s\nnext_action=land\n' "$shipment" "$branch_tip" "$sync_base"
        return
        ;;
      friction)
        instance="$(tracker_get meta - instance-id)"; identity="$(hook_identity "$stream" "$instance" shipment "$shipment" ship-friction)"
        hook_state="$(awk -F '\t' -v i="$identity" '$1=="hook"&&$2==i&&$3=="state"{print $4}' "$TRACKER")"
        friction_inputs="$(awk -F '\t' -v s="$shipment" '$1=="friction"&&index($2,s "/")==1{print $2}' "$TRACKER" | LC_ALL=C sort | shasum -a 256 | awk '{print $1}')"
        if [ "$hook_state" = not-applicable ] && [ "$(tracker_get hook "$identity" inputs-sha256)" != "$friction_inputs" ]; then
          hook_body="$(mktemp "${TMPDIR:-/tmp}/workstream-friction-refresh.XXXXXX")"; runbook_hook_body "$RUNBOOK" ship-friction >"$hook_body"
          raw="$(mktemp "${TMPDIR:-/tmp}/workstream-friction-refresh-rows.XXXXXX")"
          awk -F '\t' -v i="$identity" 'NR>1&&!($1=="hook"&&$2==i)' "$TRACKER" >"$raw"
          fingerprint="$(runbook_block_field "$RUNBOOK" 'hook:ship-friction' fingerprint)"
          if grep -q '[^[:space:]]' "$hook_body"; then
            hook_state=ready
            emit_hook_receipt "$identity" ship-friction "$fingerprint" "$friction_inputs" ready >>"$raw"
          else
            hook_state=not-applicable
            emit_hook_receipt "$identity" ship-friction "$fingerprint" "$friction_inputs" not-applicable "$(sha256_text "$friction_inputs|not-applicable")" >>"$raw"
          fi
          rewrite_tracker "$raw"; rm -f "$raw" "$hook_body"
        fi
        if [ "$hook_state" = complete ] || [ "$hook_state" = not-applicable ]; then
          raw="$(mktemp "${TMPDIR:-/tmp}/workstream-ready.XXXXXX")"
          awk -F '\t' -v s="$shipment" 'NR>1 && !(($1=="shipment"&&$2==s&&($3=="phase"||$3=="outcome"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
          printf 'shipment\t%s\tphase\tready-to-land\nshipment\t%s\toutcome\tactive\nphase\t-\tnext-action\tland\n' "$shipment" "$shipment" >>"$raw"
          rewrite_tracker "$raw"; rm -f "$raw"
          printf 'status=ready\nshipment=%s\nbranch_tip=%s\ntarget_tip=%s\nnext_action=land\n' "$shipment" "$branch_tip" "$sync_base"
        else
          printf 'status=resumed\nshipment=%s\nphase=friction\nhook_state=%s\nnext_action=prepare-ship\n' "$shipment" "${hook_state:-missing}"
        fi
        return
        ;;
      gate)
        if [ "$prior_gate" = running ]; then
          raw="$(mktemp "${TMPDIR:-/tmp}/workstream-gate-uncertain.XXXXXX")"
          awk -F '\t' -v s="$shipment" 'NR>1 && !(($1=="gate"&&$2==s&&($3=="outcome"||$3=="evidence-sha256"))||($1=="shipment"&&$2==s&&$3=="outcome")||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
          printf 'gate\t%s\toutcome\tuncertain\ngate\t%s\tevidence-sha256\t%s\nshipment\t%s\toutcome\tblocked\nphase\t-\tnext-action\tblocked\n' "$shipment" "$shipment" "$(sha256_text interrupted-gate)" "$shipment" >>"$raw"
          rewrite_tracker "$raw"; rm -f "$raw"; prior_gate=uncertain
        fi
        printf 'status=gate-required\nshipment=%s\nphase=gate\ngate_state=%s\nnext_action=%s\n' "$shipment" "${prior_gate:-required}" "$([ "$prior_gate" = uncertain ] && printf blocked || printf prepare-ship)"
        return
        ;;
    esac
  fi

  if ! git -C "$WT" merge-base --is-ancestor "$sync_base" HEAD; then
    die "synchronization did not make the recorded target an ancestor"
  fi
  prepare_history_metadata "$stream" "$shipment" "$units" "$target"
  branch_tip="$(git -C "$WT" rev-parse HEAD)"
  target_tip="$sync_base"
  gitlinks="$(mktemp "${TMPDIR:-/tmp}/workstream-gitlinks.XXXXXX")"
  missing="$(prepare_gitlink_rows "$shipment" "$target_tip" "$landing" "$gitlinks")"
  inputs="$(sha256_text "$stream|$shipment|$units|$branch_tip|$target_tip|$target|$landing|$(sha256_file "$gitlinks")")"
  if [ "$missing" = yes ]; then phase=gitlinks; outcome=blocked; next_action=blocked; else phase=gate; outcome=active; next_action=prepare-ship; fi
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-shipment.XXXXXX")"
  awk -F '\t' -v s="$shipment" 'NR>1 && !(($1=="gate"&&$2==s)||($1=="gitlink"&&index($2,s "/")==1)||($1=="shipment"&&$2==s&&($3=="phase"||$3=="outcome"||$3=="branch-tip"||$3=="target-tip"||$3=="inputs-sha256"))||($1=="phase"&&$2=="-"&&($3=="name"||$3=="next-action")))' "$TRACKER" >"$raw"
  {
    printf 'phase\t-\tname\tship\nphase\t-\tnext-action\t%s\n' "$next_action"
    printf 'shipment\t%s\tphase\t%s\nshipment\t%s\toutcome\t%s\nshipment\t%s\tbranch-tip\t%s\nshipment\t%s\ttarget-tip\t%s\nshipment\t%s\tinputs-sha256\t%s\n' \
      "$shipment" "$phase" "$shipment" "$outcome" "$shipment" "$branch_tip" "$shipment" "$target_tip" "$shipment" "$inputs"
    cat "$gitlinks"
  } >>"$raw"
  rm -f "$gitlinks"
  rewrite_tracker "$raw"
  rm -f "$raw"
  if [ "$missing" = yes ]; then
    printf 'status=blocked\nshipment=%s\nphase=gitlinks\nnext_action=blocked\n' "$shipment"
    return 1
  fi
  printf 'status=gate-required\nshipment=%s\nphase=gate\nbranch_tip=%s\ntarget_tip=%s\nnext_action=prepare-ship\n' "$shipment" "$branch_tip" "$target_tip"
}

build_gate_manifests() { # directory branch-tip transaction-base target-ref
  local private="$1" branch_tip="$2" transaction_base="$3" target="$4" local_target generated_path
  local_target="$(git -C "$WT" rev-parse "$target")"
  git -C "$WT" diff --name-only -z "$transaction_base..$branch_tip" | LC_ALL=C sort -zu >"$private/own"
  if [ "$local_target" = "$transaction_base" ]; then
    : >"$private/incoming"
  elif git -C "$WT" merge-base --is-ancestor "$local_target" "$transaction_base"; then
    git -C "$WT" diff --name-only -z "$local_target..$transaction_base" | LC_ALL=C sort -zu >"$private/incoming"
  else
    die "local and transaction targets do not form a safe incoming delta"
  fi
  git -C "$WT" diff --name-only -z "$local_target..$branch_tip" | LC_ALL=C sort -zu >"$private/final"
  : >"$private/generated"
  generated_path=.streams/history.tsv
  if tr '\0' '\n' <"$private/own" | grep -qxF "$generated_path"; then
    validate_history "$WT/$generated_path"
    printf '%s\0' "$generated_path" >"$private/generated"
  fi
  chmod 600 "$private/own" "$private/incoming" "$private/final" "$private/generated"
}

append_ship_friction_transition() { # stream shipment body-without-current-phase-rows
  local sf_stream="$1" sf_shipment="$2" sf_raw="$3" sf_instance sf_identity sf_fingerprint sf_inputs sf_body sf_existing sf_filtered
  sf_instance="$(tracker_get meta - instance-id)"
  sf_identity="$(hook_identity "$sf_stream" "$sf_instance" shipment "$sf_shipment" ship-friction)"
  sf_fingerprint="$(runbook_block_field "$RUNBOOK" 'hook:ship-friction' fingerprint)" || die "compiled ship hook is malformed"
  sf_inputs="$(awk -F '\t' -v s="$sf_shipment" '$1=="friction"&&index($2,s "/")==1{print $2}' "$sf_raw" | LC_ALL=C sort | shasum -a 256 | awk '{print $1}')"
  sf_body="$(mktemp "${TMPDIR:-/tmp}/workstream-friction-body.XXXXXX")"
  runbook_hook_body "$RUNBOOK" ship-friction >"$sf_body"
  sf_existing="$(awk -F '\t' -v i="$sf_identity" '$1=="hook"&&$2==i&&$3=="state"{print $4}' "$sf_raw")"
  [ "$sf_existing" != running ] || { rm -f "$sf_body"; die "running ship hook cannot be replayed"; }
  if [ -n "$sf_existing" ] && [ "$sf_existing" != complete ]; then
    sf_filtered="$(mktemp "${TMPDIR:-/tmp}/workstream-hook-refresh.XXXXXX")"
    awk -F '\t' -v i="$sf_identity" '!($1=="hook"&&$2==i)' "$sf_raw" >"$sf_filtered"
    mv "$sf_filtered" "$sf_raw"
  fi
  if [ "$sf_existing" = complete ]; then
    printf 'shipment\t%s\tphase\tready-to-land\nshipment\t%s\toutcome\tactive\nphase\t-\tnext-action\tland\n' "$sf_shipment" "$sf_shipment" >>"$sf_raw"
  elif awk -F '\t' -v s="$sf_shipment/" '$1=="friction"&&index($2,s)==1{found=1}END{exit found?0:1}' "$sf_raw" && grep -q '[^[:space:]]' "$sf_body"; then
    emit_hook_receipt "$sf_identity" ship-friction "$sf_fingerprint" "$sf_inputs" ready >>"$sf_raw"
    printf 'shipment\t%s\tphase\tfriction\nshipment\t%s\toutcome\tactive\nphase\t-\tnext-action\tprepare-ship\n' "$sf_shipment" "$sf_shipment" >>"$sf_raw"
  else
    emit_hook_receipt "$sf_identity" ship-friction "$sf_fingerprint" "$sf_inputs" not-applicable "$(sha256_text "$sf_inputs|not-applicable")" >>"$sf_raw"
    printf 'shipment\t%s\tphase\tready-to-land\nshipment\t%s\toutcome\tactive\nphase\t-\tnext-action\tland\n' "$sf_shipment" "$sf_shipment" >>"$sf_raw"
  fi
  rm -f "$sf_body"
}

cmd_gate_none() {
  [ "$#" -eq 1 ] || die "usage: gate-none <stream>"
  local stream="$1" shipment branch_tip target_tip target private raw inputs path next_action
  admit_stream "$stream"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase"{print $2;exit}' "$TRACKER")"; [ -n "$shipment" ] || die "no active shipment"
  [ "$(tracker_get shipment "$shipment" phase)" = gate ] || die "shipment is not at gate"
  branch_tip="$(tracker_get shipment "$shipment" branch-tip)"; target_tip="$(tracker_get shipment "$shipment" target-tip)"; target="$(runbook_field "$RUNBOOK" target)"
  private="$(mktemp -d "${TMPDIR:-/tmp}/workstream-none.XXXXXX")"; chmod 700 "$private"
  build_gate_manifests "$private" "$branch_tip" "$target_tip" "$target"
  while IFS= read -r -d '' path; do
    tr '\0' '\n' <"$private/generated" | grep -qxF "$path" || { rm -rf "$private"; die "none gate is illegal for build-relevant own changes"; }
  done <"$private/own"
  inputs="$(tracker_get shipment "$shipment" inputs-sha256)"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-none-gate.XXXXXX")"
  awk -F '\t' -v s="$shipment" 'NR>1 && !(($1=="gate"&&$2==s)||($1=="shipment"&&$2==s&&($3=="phase"||$3=="outcome"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  printf 'gate\t%s\tclass\tnone\ngate\t%s\tlabel\tno-build-relevant-own-changes\ngate\t%s\tinputs-sha256\t%s\ngate\t%s\toutcome\tpassed\n' "$shipment" "$shipment" "$shipment" "$inputs" "$shipment" >>"$raw"
  append_ship_friction_transition "$stream" "$shipment" "$raw"
  rewrite_tracker "$raw"; rm -f "$raw"; rm -rf "$private"
  next_action="$(tracker_get phase - next-action)"
  printf 'status=passed\nclass=none\nshipment=%s\nnext_action=%s\n' "$shipment" "$next_action"
}

cmd_gate_run() {
  local stream="$1"; shift
  [ "${1:-}" = --class ] || die "gate-run requires --class"
  local class="${2:-}"; shift 2
  local selector=no
  if [ "${1:-}" = --selector ]; then selector=yes; shift; fi
  [ "${1:-}" = --label ] || die "gate-run requires --label"
  local label="${2:-}"; shift 2
  [ "${1:-}" = -- ] || die "gate-run requires -- before argv"
  shift
  [ "$#" -gt 0 ] || die "gate-run requires argv"
  case "$class:$selector" in docs:no|full:no|semantic:yes) ;; *) die "illegal gate class/selector combination" ;; esac
  validate_text 'gate label' "$label"
  [ "$(LC_ALL=C printf '%s' "$label" | wc -c | tr -d ' ')" -le 1024 ] || die "gate label exceeds 1024 bytes"
  admit_stream "$stream"
  local shipment inputs command_file output evidence command rc raw branch_tip target_tip shipment_phase private private_identity parent_safe receipt receipt_status test_state combined prior_failed target current_target path
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase" {print $2; exit}' "$TRACKER")"
  [ -n "$shipment" ] || die "no active shipment"
  shipment_phase="$(tracker_get shipment "$shipment" phase)"
  command_file="$(mktemp "${TMPDIR:-/tmp}/workstream-command.XXXXXX")"
  printf '%s\0' "$class" "$selector" "$label" "$@" >"$command_file"
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
  if awk -F '\t' -v s="$shipment" '$1=="gate"&&$2==s&&$3=="outcome"&&($4=="running"||$4=="uncertain"){bad=1}END{exit bad?0:1}' "$TRACKER"; then
    rm -f "$command_file"; die "gate result is uncertain; change the candidate or reconcile attendedly before retry"
  fi
  branch_tip="$(git -C "$WT" rev-parse HEAD)"
  target="$(runbook_field "$RUNBOOK" target)"; target_tip="$(tracker_get shipment "$shipment" target-tip)"
  if [ "$(runbook_field "$RUNBOOK" landing)" = local ]; then current_target="$(git -C "$WT" rev-parse "$target")"; else current_target="$(remote_target_tip "$target")" || die "cannot verify remote target"; fi
  [ "$branch_tip" = "$(tracker_get shipment "$shipment" branch-tip)" ] || die "branch changed after preparation"
  [ "$current_target" = "$target_tip" ] || die "target changed after preparation; resume ship preparation"
  inputs="$(tracker_get shipment "$shipment" inputs-sha256)"
  private="$(mktemp -d "${TMPDIR:-/tmp}/workstream-selector.XXXXXX")"; chmod 700 "$private"
  private_identity="$(stat -f '%d:%i' "$private")"
  build_gate_manifests "$private" "$branch_tip" "$target_tip" "$target"
  if [ "$class" = docs ]; then
    while IFS= read -r -d '' path; do
      if tr '\0' '\n' <"$private/generated" | grep -qxF "$path"; then continue; fi
      case "$path" in *.md) ;; *) rm -f "$command_file"; rm -rf "$private"; die "documentation gate is illegal for non-Markdown own path: $path" ;; esac
    done <"$private/own"
  fi
  prior_failed="$(awk -F '\t' -v s="$shipment" '$1=="gate"&&$2==s&&$3=="outcome"&&$4=="failed"{print "yes"}' "$TRACKER")"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-gate-running.XXXXXX")"
  awk -F '\t' -v s="$shipment" 'NR>1 && !(($1=="gate"&&$2==s)||($1=="shipment"&&$2==s&&$3=="outcome")||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  printf 'gate\t%s\tclass\t%s\ngate\t%s\tlabel\t%s\ngate\t%s\tinputs-sha256\t%s\ngate\t%s\tcommand-sha256\t%s\ngate\t%s\toutcome\trunning\nshipment\t%s\toutcome\tactive\nphase\t-\tnext-action\tblocked\n' \
    "$shipment" "$class" "$shipment" "$label" "$shipment" "$inputs" "$shipment" "$command" "$shipment" "$shipment" >>"$raw"
  rewrite_tracker "$raw"; rm -f "$raw"
  if [ -n "${WORKSTREAM_TEST_AFTER_GATE_RUNNING:-}" ]; then "$WORKSTREAM_TEST_AFTER_GATE_RUNNING" "$TRACKER"; die "gate interrupted after recording running"; fi
  output="$(mktemp "${TMPDIR:-/tmp}/workstream-gate.XXXXXX")"; rc=0
  receipt_status=""
  if [ "$selector" = yes ]; then
    receipt="$private/receipt.tsv"
    parent_safe=yes
    (
      while IFS='=' read -r name _; do case "$name" in WORKSTREAM_GATE_*) unset "$name" ;; esac; done < <(env)
      WORKSTREAM_GATE_SCHEMA=workstream-gate@1; WORKSTREAM_GATE_ROOT="$ROOT"; WORKSTREAM_GATE_WORKTREE="$WT"
      WORKSTREAM_GATE_BRANCH="$(runbook_field "$RUNBOOK" branch)"; WORKSTREAM_GATE_TARGET="$(runbook_field "$RUNBOOK" target)"
      WORKSTREAM_GATE_BASE="$target_tip"; WORKSTREAM_GATE_LANDING="$(runbook_field "$RUNBOOK" landing)"
      WORKSTREAM_GATE_OWN_MANIFEST="$private/own"; WORKSTREAM_GATE_INCOMING_MANIFEST="$private/incoming"
      WORKSTREAM_GATE_FINAL_MANIFEST="$private/final"; WORKSTREAM_GATE_GENERATED_MANIFEST="$private/generated"; WORKSTREAM_GATE_RECEIPT="$receipt"
      export WORKSTREAM_GATE_SCHEMA WORKSTREAM_GATE_ROOT WORKSTREAM_GATE_WORKTREE WORKSTREAM_GATE_BRANCH WORKSTREAM_GATE_TARGET
      export WORKSTREAM_GATE_BASE WORKSTREAM_GATE_LANDING WORKSTREAM_GATE_OWN_MANIFEST WORKSTREAM_GATE_INCOMING_MANIFEST
      export WORKSTREAM_GATE_FINAL_MANIFEST WORKSTREAM_GATE_GENERATED_MANIFEST WORKSTREAM_GATE_RECEIPT
      cd "$WT" && "$@"
    ) >"$output" 2>&1 || rc=$?
    if [ ! -d "$private" ] || [ -L "$private" ] || [ "$(stat -f '%d:%i' "$private" 2>/dev/null || true)" != "$private_identity" ]; then
      parent_safe=no; receipt_status=uncertain; rc=1
    fi
    if [ "$parent_safe" = yes ] && [ -f "$receipt" ] && [ ! -L "$receipt" ] && [ "$(wc -c <"$receipt" | tr -d ' ')" -le 4096 ] && \
      [ "$(sed -n '1p' "$receipt")" = $'key\tvalue' ] && [ "$(sed -n '2p' "$receipt")" = $'schema\tworkstream-gate@1' ] && \
      [ "$(wc -l <"$receipt" | tr -d ' ')" -eq 4 ]; then
      receipt_status="$(awk -F '\t' 'NR==3&&$1=="outcome"&&($2=="passed"||$2=="failed"){print $2}' "$receipt")"
      test_state="$(awk -F '\t' 'NR==4&&$1=="test-state"&&$2!=""{print $2}' "$receipt")"
    fi
    if [ -z "$receipt_status" ] || [ -z "$test_state" ] || { [ "$rc" -eq 0 ] && [ "$receipt_status" != passed ]; } || { [ "$rc" -ne 0 ] && [ "$receipt_status" != failed ]; }; then
      receipt_status=uncertain; rc=1
    fi
    combined="$(mktemp "${TMPDIR:-/tmp}/workstream-selector-evidence.XXXXXX")"; cat "$output" >"$combined"
    [ -f "$receipt" ] && [ ! -L "$receipt" ] && cat "$receipt" >>"$combined"
    evidence="$(sha256_file "$combined")"; rm -f "$combined"; rm -rf "$private"
  else
    (
      while IFS='=' read -r name _; do case "$name" in WORKSTREAM_GATE_*) unset "$name" ;; esac; done < <(env)
      cd "$WT" && "$@"
    ) >"$output" 2>&1 || rc=$?
    evidence="$(sha256_file "$output")"
    receipt_status="$([ "$rc" -eq 0 ] && printf passed || printf failed)"
    rm -rf "$private"
  fi
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-gaterows.XXXXXX")"
  awk -F '\t' -v s="$shipment" 'NR>1 && !(($1=="gate"&&$2==s)||($1=="shipment"&&$2==s&&($3=="phase"||$3=="outcome"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  printf 'gate\t%s\tclass\t%s\ngate\t%s\tlabel\t%s\ngate\t%s\tinputs-sha256\t%s\ngate\t%s\tcommand-sha256\t%s\ngate\t%s\toutcome\t%s\ngate\t%s\tevidence-sha256\t%s\n' \
    "$shipment" "$class" "$shipment" "$label" "$shipment" "$inputs" "$shipment" "$command" "$shipment" "$receipt_status" "$shipment" "$evidence" >>"$raw"
  if [ "$receipt_status" = passed ]; then
    if [ "$prior_failed" = yes ] && ! grep -qF $'friction\t'"$shipment"$'/gate-recovery\tpresent\tyes' "$raw"; then
      printf 'friction\t%s/gate-recovery\tpresent\tyes\n' "$shipment" >>"$raw"
    fi
    append_ship_friction_transition "$stream" "$shipment" "$raw"
  else
    printf 'shipment\t%s\tphase\tgate\nshipment\t%s\toutcome\tblocked\nphase\t-\tnext-action\tblocked\n' "$shipment" "$shipment" >>"$raw"
  fi
  rewrite_tracker "$raw"
  rm -f "$raw" "$command_file"
  printf 'status=%s\nclass=%s\nlabel=%s\nevidence_sha256=%s\noutput_tail:\n' "$receipt_status" "$class" "$label" "$evidence"
  tail -n 7 "$output" | LC_ALL=C awk '{ print substr($0,1,1024) }'
  rm -f "$output"
  [ "$receipt_status" = passed ]
}

record_delivery() { # shipment id candidate expected observed state phase outcome next-action [friction]
  local shipment="$1" delivery="$2" candidate="$3" expected="$4" observed="$5" state="$6" phase="$7" outcome="$8" next="$9" friction="${10:-}" raw
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-delivery.XXXXXX")"
  awk -F '\t' -v s="$shipment" -v d="$delivery" 'NR>1 && !(($1=="delivery"&&$2==d)||($1=="shipment"&&$2==s&&($3=="phase"||$3=="outcome"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  printf 'delivery\t%s\tcandidate-tip\t%s\ndelivery\t%s\texpected-tip\t%s\ndelivery\t%s\tstate\t%s\n' \
    "$delivery" "$candidate" "$delivery" "$expected" "$delivery" "$state" >>"$raw"
  case "$state" in advanced|rejected) printf 'delivery\t%s\tobserved-tip\t%s\n' "$delivery" "$observed" >>"$raw" ;; esac
  [ -z "$friction" ] || grep -qF $'friction\t'"$shipment/$friction"$'\tpresent\tyes' "$raw" || printf 'friction\t%s/%s\tpresent\tyes\n' "$shipment" "$friction" >>"$raw"
  printf 'shipment\t%s\tphase\t%s\nshipment\t%s\toutcome\t%s\nphase\t-\tnext-action\t%s\n' "$shipment" "$phase" "$shipment" "$outcome" "$next" >>"$raw"
  rewrite_tracker "$raw"; rm -f "$raw"
}

remote_target_tip() {
  local target="$1" output
  output="$(git -C "$ROOT" ls-remote --heads origin "refs/heads/$target")" || return 1
  printf '%s\n' "$output" | awk 'NF==2{print $1; found++} END{if(found!=1)exit 2}'
}

landing_lock_path() {
  local common canonical lock
  common="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || die "cannot resolve the shared Git directory"
  case "$common" in /*) ;; *) die "shared Git directory is not absolute" ;; esac
  canonical="$(canonical_dir "$common")" || die "shared Git directory is unsafe"
  [ "$canonical" = "$common" ] || die "shared Git directory is not canonical"
  lock="$common/workstream-landing.lock"
  if [ -e "$lock" ] || [ -L "$lock" ]; then
    [ -f "$lock" ] && [ ! -L "$lock" ] || die "landing lock path is unsafe"
  fi
  printf '%s\n' "$lock"
}

validate_landing_marker() { # marker
  local marker="$1" parent
  [ -f "$marker" ] && [ ! -L "$marker" ] || die "landing acquisition marker is unsafe"
  parent="$(canonical_dir "$(dirname "$marker")")" || die "landing acquisition marker parent is unsafe"
  case "$parent/" in "$ROOT/"|"$ROOT/"*) die "landing acquisition marker must be outside the repository" ;; esac
  [ "$parent/$(basename "$marker")" = "$marker" ] || die "landing acquisition marker is not canonical"
}

cmd_land_advance() {
  [ "$#" -eq 3 ] && [ "$2" = --authority ] && [ "$3" = confirmed ] || die "landing requires --authority confirmed"
  local stream="$1" lock marker marker_dir rc=0
  [ -n "$LANDING_LOCK_BACKEND" ] || die "landing lock primitive was not selected"
  lock="$(landing_lock_path)"
  marker_dir="$(canonical_dir "${TMPDIR:-/tmp}")" || die "temporary directory is unsafe"
  case "$marker_dir/" in "$ROOT/"|"$ROOT/"*) die "temporary directory for landing must be outside the repository" ;; esac
  marker="$(mktemp "$marker_dir/workstream-landing-acquired.XXXXXX")"
  chmod 600 "$marker"
  case "$LANDING_LOCK_BACKEND" in
    lockf)
      WORKSTREAM_LANDING_CHILD=yes lockf -s -t 0 -k "$lock" "$SELF" "$ROOT" _land-advance-transaction "$marker" "$stream" --authority confirmed || rc=$?
      ;;
    flock)
      WORKSTREAM_LANDING_CHILD=yes flock -n "$lock" "$SELF" "$ROOT" _land-advance-transaction "$marker" "$stream" --authority confirmed || rc=$?
      ;;
    *) rm -f "$marker"; die "unsupported landing lock backend" ;;
  esac
  if [ ! -s "$marker" ]; then
    rm -f "$marker"
    case "$LANDING_LOCK_BACKEND:$rc" in lockf:75|flock:1)
      printf 'status=landing-busy\nnext_action=land\n'
      return 1
      ;;
    esac
    die "landing lock wrapper failed before acquisition"
  fi
  rm -f "$marker"
  return "$rc"
}

cmd_land_advance_transaction() {
  [ "${WORKSTREAM_LANDING_CHILD:-}" = yes ] || die "private landing transaction cannot be invoked directly"
  [ "$#" -eq 4 ] && [ "$3" = --authority ] && [ "$4" = confirmed ] || die "invalid private landing transaction"
  local marker="$1" stream="$2" shipment shipment_phase candidate expected target observed delivery state rc isolation landing remote_expected local_expected raw
  validate_landing_marker "$marker"
  printf 'acquired\n' >"$marker"
  if [ -n "${WORKSTREAM_TEST_AFTER_LANDING_ACQUIRED:-}" ]; then
    "$WORKSTREAM_TEST_AFTER_LANDING_ACQUIRED" "$marker"
  fi
  admit_stream "$stream"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase" {print $2; exit}' "$TRACKER")"
  [ -n "$shipment" ] || die "no active shipment"
  shipment_phase="$(tracker_get shipment "$shipment" phase)"
  case "$shipment_phase" in ready-to-land|advance|postflight) ;; *) die "shipment is not ready to land" ;; esac
  [ "$(tracker_get gate "$shipment" outcome)" = passed ] || die "shipment gate has not passed"
  if [ "$shipment_phase" = postflight ] && \
    [ "$(tracker_get shipment "$shipment" outcome)" = landed ]; then
    candidate="$(tracker_get shipment "$shipment" branch-tip)"
    target="$(runbook_field "$RUNBOOK" target)"
    git -C "$ROOT" merge-base --is-ancestor "$candidate" "$target" || die "recorded landing is not on target"
    if [ "$(runbook_field "$RUNBOOK" landing)" = push ]; then
      [ "$(remote_target_tip "$target")" = "$candidate" ] || die "recorded landing is not on remote target"
    fi
    printf 'status=already-landed\nshipment=%s\ncandidate=%s\nnext_action=postflight\n' "$shipment" "$candidate"
    return
  fi
  candidate="$(tracker_get shipment "$shipment" branch-tip)"
  expected="$(tracker_get shipment "$shipment" target-tip)"
  target="$(runbook_field "$RUNBOOK" target)"
  landing="$(runbook_field "$RUNBOOK" landing)"
  case "$landing" in local|push) ;; pr) die "PR landing requires pr-await" ;; *) die "unsupported landing mode" ;; esac
  isolation="$(runbook_field "$RUNBOOK" isolation)"
  [ "$(git -C "$WT" rev-parse HEAD)" = "$candidate" ] || die "candidate changed"
  delivery="$shipment/local-target"
  state="$(awk -F '\t' -v i="$delivery" '$1=="delivery"&&$2==i&&$3=="state"{print $4}' "$TRACKER")"
  if [ "$landing" = push ] && [ -z "$state" ]; then
    remote_expected="$(remote_target_tip "$target")" || die "cannot verify remote target before delivery"
    local_expected="$(git -C "$ROOT" rev-parse "$target")"
    raw="$(mktemp "${TMPDIR:-/tmp}/workstream-delivery-ready.XXXXXX")"
    awk -F '\t' -v s="$shipment" 'NR>1 && !($1=="delivery"&&index($2,s "/")==1)' "$TRACKER" >"$raw"
    printf 'delivery\t%s/local-target\tcandidate-tip\t%s\ndelivery\t%s/local-target\texpected-tip\t%s\ndelivery\t%s/local-target\tstate\tready\n' \
      "$shipment" "$candidate" "$shipment" "$local_expected" "$shipment" >>"$raw"
    printf 'delivery\t%s/remote-target\tcandidate-tip\t%s\ndelivery\t%s/remote-target\texpected-tip\t%s\ndelivery\t%s/remote-target\tstate\tready\n' \
      "$shipment" "$candidate" "$shipment" "$remote_expected" "$shipment" >>"$raw"
    rewrite_tracker "$raw"; rm -f "$raw"; state=ready
  fi
  if [ -z "$state" ] || [ "$state" = ready ] || [ "$state" = rejected ]; then
    if [ -n "$state" ]; then expected="$(tracker_get delivery "$delivery" expected-tip)"; fi
    record_delivery "$shipment" "$delivery" "$candidate" "$expected" '' running advance active land
    state=running
    if [ -n "${WORKSTREAM_TEST_AFTER_DELIVERY_RUNNING:-}" ]; then
      "$WORKSTREAM_TEST_AFTER_DELIVERY_RUNNING" "$TRACKER"
      die "delivery interrupted after recording running"
    fi
  fi
  [ "$state" = running ] || [ "$state" = advanced ] || die "delivery receipt requires recovery"
  observed="$(git -C "$ROOT" rev-parse "$target")"
  if [ "$state" != advanced ] && [ "$observed" != "$candidate" ]; then
    if [ "$observed" = "$expected" ]; then
      [ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ] || die "primary checkout has tracked dirt"
      rc=0
      if [ "$isolation" = in-place ]; then
        [ "$(git -C "$ROOT" branch --show-current)" = "$(runbook_field "$RUNBOOK" branch)" ] || die "in-place stream is not held"
        git -C "$ROOT" merge-base --is-ancestor "$expected" "$candidate" || die "candidate is not a fast-forward"
        git -C "$ROOT" update-ref "refs/heads/$target" "$candidate" "$expected" || rc=$?
      else
        [ "$(git -C "$ROOT" branch --show-current)" = "$target" ] || die "primary checkout is not on the target"
        git -C "$ROOT" merge --ff-only -q "$(runbook_field "$RUNBOOK" branch)" || rc=$?
      fi
      observed="$(git -C "$ROOT" rev-parse "$target")"
      [ "$rc" -eq 0 ] || state=rejected
    else
      state=rejected
    fi
  fi
  if [ "$observed" = "$candidate" ] || git -C "$ROOT" merge-base --is-ancestor "$candidate" "$observed" 2>/dev/null; then
    state=advanced
    if [ "$landing" = local ]; then
      record_delivery "$shipment" "$delivery" "$candidate" "$expected" "$observed" advanced postflight landed postflight
      printf 'status=landed\nshipment=%s\ncandidate=%s\nnext_action=postflight\n' "$shipment" "$candidate"
      return
    fi
    record_delivery "$shipment" "$delivery" "$candidate" "$expected" "$observed" advanced advance active land
  else
    state=rejected
    record_delivery "$shipment" "$delivery" "$candidate" "$expected" "$observed" rejected friction blocked prepare-ship target-reject
    printf 'status=rejected\nshipment=%s\nobserved=%s\nnext_action=prepare-ship\n' "$shipment" "$observed"
    return 1
  fi

  delivery="$shipment/remote-target"
  state="$(awk -F '\t' -v i="$delivery" '$1=="delivery"&&$2==i&&$3=="state"{print $4}' "$TRACKER")"
  [ -n "$state" ] || die "remote delivery receipt is missing"
  remote_expected="$(tracker_get delivery "$delivery" expected-tip)"
  if [ "$state" = ready ] || [ "$state" = rejected ]; then
    record_delivery "$shipment" "$delivery" "$candidate" "$remote_expected" '' running advance active land
    state=running
    if [ -n "${WORKSTREAM_TEST_AFTER_REMOTE_RUNNING:-}" ]; then "$WORKSTREAM_TEST_AFTER_REMOTE_RUNNING" "$TRACKER"; die "remote delivery interrupted after recording running"; fi
  fi
  [ "$state" = running ] || [ "$state" = advanced ] || die "remote delivery receipt requires recovery"
  observed="$(remote_target_tip "$target")" || {
    record_delivery "$shipment" "$delivery" "$candidate" "$remote_expected" '' uncertain advance uncertain blocked
    printf 'status=uncertain\nshipment=%s\nnext_action=blocked\n' "$shipment"
    return 1
  }
  if [ "$state" != advanced ] && [ "$observed" != "$candidate" ]; then
    if [ "$observed" = "$remote_expected" ]; then
      rc=0; git -C "$ROOT" push -q origin "$candidate:refs/heads/$target" || rc=$?
      observed="$(remote_target_tip "$target")" || {
        record_delivery "$shipment" "$delivery" "$candidate" "$remote_expected" '' uncertain advance uncertain blocked
        printf 'status=uncertain\nshipment=%s\nnext_action=blocked\n' "$shipment"
        return 1
      }
      [ "$rc" -eq 0 ] || state=rejected
    else
      state=rejected
    fi
  fi
  git -C "$ROOT" fetch -q origin "refs/heads/$target" >/dev/null 2>&1 || true
  if [ "$observed" = "$candidate" ] || git -C "$ROOT" merge-base --is-ancestor "$candidate" "${observed}^{commit}" 2>/dev/null; then
    record_delivery "$shipment" "$delivery" "$candidate" "$remote_expected" "$observed" advanced postflight landed postflight
    printf 'status=landed\nshipment=%s\ncandidate=%s\nnext_action=postflight\n' "$shipment" "$candidate"
  else
    record_delivery "$shipment" "$delivery" "$candidate" "$remote_expected" "$observed" rejected friction blocked prepare-ship remote-reject
    printf 'status=rejected\nshipment=%s\nobserved=%s\nnext_action=prepare-ship\n' "$shipment" "$observed"
    return 1
  fi
}

cmd_sync() {
  [ "$#" -eq 1 ] || die "usage: sync <stream>"
  local stream="$1" target before after
  admit_stream "$stream"; target="$(runbook_field "$RUNBOOK" target)"
  [ -z "$(git -C "$WT" status --porcelain --untracked-files=no)" ] || die "sync requires clean tracked work"
  before="$(git -C "$WT" rev-parse HEAD)"
  if git -C "$WT" merge-base --is-ancestor "$target" HEAD; then printf 'status=current\nhead=%s\nnext_action=%s\n' "$before" "$(tracker_get phase - next-action)"; return; fi
  if ! git -C "$WT" rebase "$target"; then printf 'status=conflict\nnext_action=blocked\n'; return 1; fi
  after="$(git -C "$WT" rev-parse HEAD)"
  printf 'status=synced\nbefore=%s\nafter=%s\nnext_action=%s\n' "$before" "$after" "$(tracker_get phase - next-action)"
}

cmd_park() {
  [ "$#" -eq 1 ] || die "usage: park <stream>"
  local stream="$1" branch target
  admit_stream "$stream"
  [ "$(runbook_field "$RUNBOOK" isolation)" = in-place ] || die "park applies only to an in-place stream"
  branch="$(runbook_field "$RUNBOOK" branch)"; target="$(runbook_field "$RUNBOOK" target)"
  [ "$(git -C "$ROOT" branch --show-current)" = "$branch" ] || die "in-place stream is not held"
  [ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ] || die "park requires clean tracked work"
  ! awk -F '\t' '$1=="hook"&&$3=="state"&&($4=="ready"||$4=="running"){found=1}END{exit found?0:1}' "$TRACKER" || die "park refuses an unresolved hook"
  git -C "$ROOT" switch -q "$target"
  printf 'status=parked\nstream=%s\nbranch=%s\nnext_action=unpark\n' "$stream" "$target"
}

cmd_unpark() {
  [ "$#" -eq 1 ] || die "usage: unpark <stream>"
  local stream="$1" branch target
  admit_stream "$stream"
  [ "$(runbook_field "$RUNBOOK" isolation)" = in-place ] || die "unpark applies only to an in-place stream"
  branch="$(runbook_field "$RUNBOOK" branch)"; target="$(runbook_field "$RUNBOOK" target)"
  [ "$(git -C "$ROOT" branch --show-current)" = "$target" ] || die "root is not holding the recorded target"
  [ -z "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ] || die "unpark requires clean tracked work"
  git -C "$ROOT" switch -q "$branch"
  printf 'status=unparked\nstream=%s\nbranch=%s\nnext_action=%s\n' "$stream" "$branch" "$(tracker_get phase - next-action)"
}

cmd_recycle() {
  [ "$#" -ge 1 ] || die "usage: recycle <stream> [--source-kind <brief|plan|roadmap>] [--cursor <value>]"
  local stream="$1" raw source_kind=brief cursor=- queue_state=intake source_seen=no cursor_seen=no branch target
  shift
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --source-kind)
        [ "$#" -ge 2 ] && [ "$source_seen" = no ] || die "--source-kind requires one value"
        source_kind="$2"; source_seen=yes; shift 2
        ;;
      --cursor)
        [ "$#" -ge 2 ] && [ "$cursor_seen" = no ] || die "--cursor requires one value"
        cursor="$2"; cursor_seen=yes; shift 2
        ;;
      *) die "unknown recycle option: $1" ;;
    esac
  done
  case "$source_kind" in brief|plan|roadmap) ;; *) die "invalid queue source kind" ;; esac
  if [ "$source_kind" = plan ] || [ "$source_kind" = roadmap ]; then
    [ "$cursor_seen" = yes ] && [ "$cursor" != - ] || die "$source_kind source requires --cursor"
    queue_state=ready
  else
    [ "$cursor_seen" = no ] || die "brief source does not accept --cursor"
  fi
  admit_stream "$stream"
  validate_queue_source "$source_kind" "$cursor" "$(git -C "$WT" rev-parse HEAD)"
  [ "$(tracker_get queue - state)" = exhausted ] || die "recycle requires a finalized queue"
  [ -z "$(git -C "$WT" status --porcelain --untracked-files=no)" ] || die "recycle requires clean tracked work"
  branch="$(runbook_field "$RUNBOOK" branch)"; target="$(runbook_field "$RUNBOOK" target)"
  git -C "$WT" merge-base --is-ancestor "$branch" "$target" || die "recycle refuses unlanded stream commits"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-recycle.XXXXXX")"
  awk -F '\t' 'NR>1 && !(($1=="queue"&&$2=="-"&&($3=="cursor"||$3=="state"))||($1=="phase"&&$2=="-"&&($3=="name"||$3=="next-action")))' "$TRACKER" >"$raw"
  awk -F '\t' '!(($1=="queue"&&$2=="-"&&$3=="source-kind"))' "$raw" >"$raw.source"
  mv "$raw.source" "$raw"
  printf 'queue\t-\tcursor\t%s\nqueue\t-\tsource-kind\t%s\nqueue\t-\tstate\t%s\nphase\t-\tname\tnone\nphase\t-\tnext-action\tdefine-unit\n' \
    "$cursor" "$source_kind" "$queue_state" >>"$raw"
  rewrite_tracker "$raw"; rm -f "$raw"
  printf 'status=recycled\nnext_action=define-unit\n'
}

cmd_close_check() {
  [ "$#" -eq 1 ] || die "usage: close-check <stream>"
  local stream="$1" branch target ahead dirty blocked landing
  admit_stream "$stream"; branch="$(runbook_field "$RUNBOOK" branch)"; target="$(runbook_field "$RUNBOOK" target)"
  landing="$(runbook_field "$RUNBOOK" landing)"
  if [ "$landing" = pr ]; then
    git -C "$WT" fetch -q origin "refs/heads/$target" || die "cannot fetch merged PR target"
    ahead="$(git -C "$WT" rev-list --count "FETCH_HEAD..$branch")"
  else
    ahead="$(git -C "$WT" rev-list --count "$target..$branch")"
  fi
  dirty="$([ -n "$(git -C "$WT" status --porcelain --untracked-files=no)" ] && printf yes || printf no)"
  blocked="$([ -n "$(awk -F '\t' '$1=="shipment" || ($1=="hook"&&$3=="state"&&($4=="ready"||$4=="running")){print "yes";exit}' "$TRACKER")" ] && printf yes || printf no)"
  printf 'schema=workstream-close@1\nstream=%s\nbranch=%s\ntarget=%s\nahead=%s\ndirty=%s\nlifecycle_blocked=%s\nworktree=%s\n' "$stream" "$branch" "$target" "$ahead" "$dirty" "$blocked" "$WT"
}

cmd_list() {
  [ "$#" -eq 0 ] || die "usage: list"
  local directory stream count=0
  printf 'schema=workstream-list@1\n'
  [ -d "$ROOT/.streams" ] || { printf 'count=0\n'; return; }
  while IFS= read -r directory; do
    [ -f "$directory/WORKSTREAM.md" ] && [ -f "$directory/workstream.tsv" ] || continue
    stream="$(basename "$directory")"; admit_stream "$stream"
    printf 'stream=%s,branch=%s,phase=%s,next=%s\n' "$stream" "$(runbook_field "$RUNBOOK" branch)" "$(tracker_get phase - name)" "$(tracker_get phase - next-action)"
    count=$((count + 1))
  done < <(find "$ROOT/.streams" -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort)
  printf 'count=%s\n' "$count"
}

cmd_ship_finalize() {
  [ "$#" -eq 1 ] || { [ "$#" -eq 3 ] && [ "$2" = --note ]; } || die "usage: ship-finalize <stream> [--note <note>]"
  local stream="$1" shipment candidate target raw note="" landing remote
  admit_stream "$stream"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase" {print $2; exit}' "$TRACKER")"
  if [ -z "$shipment" ]; then
    [ "$(tracker_get queue - state)" = exhausted ] || die "no shipment to finalize"
    if [ "$#" -eq 3 ]; then note="$3"; cmd_operator_note "$stream" "$note" >/dev/null; fi
    printf 'status=already-finalized\nnext_action=close\n'
    return
  fi
  [ "$(tracker_get shipment "$shipment" phase)" = postflight ] || die "shipment is not in postflight"
  [ "$(tracker_get shipment "$shipment" outcome)" = landed ] || die "shipment has not landed"
  candidate="$(tracker_get shipment "$shipment" branch-tip)"
  target="$(runbook_field "$RUNBOOK" target)"
  landing="$(runbook_field "$RUNBOOK" landing)"
  if [ "$landing" = pr ]; then
    remote="$(remote_target_tip "$target")" || die "cannot verify merged PR target"
    git -C "$ROOT" fetch -q origin "refs/heads/$target" || die "cannot fetch merged PR target"
    [ "$(git -C "$ROOT" rev-parse FETCH_HEAD)" = "$remote" ] || die "fetched PR target differs"
    git -C "$ROOT" merge-base --is-ancestor "$candidate" FETCH_HEAD || die "landed candidate is not on remote target"
  else
    git -C "$ROOT" merge-base --is-ancestor "$candidate" "$target" || die "landed candidate is not on target"
    if [ "$landing" = push ]; then
      remote="$(remote_target_tip "$target")" || die "cannot verify pushed target"
      git -C "$ROOT" fetch -q origin "refs/heads/$target" || die "cannot fetch pushed target"
      [ "$(git -C "$ROOT" rev-parse FETCH_HEAD)" = "$remote" ] || die "fetched pushed target differs"
      git -C "$ROOT" merge-base --is-ancestor "$candidate" FETCH_HEAD || die "remote target no longer contains the landed candidate"
    fi
  fi
  if [ "$#" -eq 3 ]; then note="$3"; cmd_operator_note "$stream" "$note" >/dev/null; fi
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-final.XXXXXX")"
  awk -F '\t' 'NR>1 && $1!="unit" && $1!="unit-subject" && $1!="hook" && $1!="shipment" && $1!="shipment-unit" && $1!="friction" && $1!="gate" && $1!="gitlink" && $1!="delivery" && !(($1=="queue"&&$2=="-"&&($3=="cursor"||$3=="state"))||($1=="phase"&&$2=="-"&&($3=="name"||$3=="next-action")))' "$TRACKER" >"$raw"
  printf 'queue\t-\tcursor\t-\nqueue\t-\tstate\texhausted\nphase\t-\tname\tnone\nphase\t-\tnext-action\tclose\n' >>"$raw"
  rewrite_tracker "$raw"
  rm -f "$raw"
  printf 'status=finalized\nshipment=%s\nnext_action=close\n' "$shipment"
}

cmd_delivery_classify() {
  [ "$#" -eq 1 ] || die "usage: delivery-classify <stream>"
  local stream="$1" shipment uncertain advanced rejected total classifier
  admit_stream "$stream"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase"{print $2;exit}' "$TRACKER")"; [ -n "$shipment" ] || die "no active shipment"
  uncertain="$(awk -F '\t' -v p="$shipment/" '$1=="delivery"&&index($2,p)==1&&$3=="state"&&$4=="uncertain"{n++}END{print n+0}' "$TRACKER")"
  advanced="$(awk -F '\t' -v p="$shipment/" '$1=="delivery"&&index($2,p)==1&&$3=="state"&&$4=="advanced"{n++}END{print n+0}' "$TRACKER")"
  rejected="$(awk -F '\t' -v p="$shipment/" '$1=="delivery"&&index($2,p)==1&&$3=="state"&&$4=="rejected"{n++}END{print n+0}' "$TRACKER")"
  total="$(awk -F '\t' -v p="$shipment/" '$1=="delivery"&&index($2,p)==1&&$3=="state"{n++}END{print n+0}' "$TRACKER")"
  if [ "$uncertain" -gt 0 ]; then classifier=uncertain
  elif [ "$advanced" -gt 0 ] && [ "$advanced" -lt "$total" ]; then classifier=partial-delivery
  elif [ "$total" -gt 0 ] && [ "$advanced" -eq "$total" ]; then classifier=complete
  elif [ "$rejected" -gt 0 ]; then classifier=push-friction
  else classifier=clean
  fi
  printf 'schema=workstream-delivery@1\nshipment=%s\nclassifier=%s\nadvanced=%s\ntotal=%s\n' "$shipment" "$classifier" "$advanced" "$total"
}

cmd_reconcile_partial() {
  [ "$#" -eq 3 ] && [ "$2" = --authority ] && [ "$3" = confirmed ] || die "usage: reconcile-partial <stream> --authority confirmed"
  local stream="$1" shipment classifier candidate divergent raw new inputs first second local_observed remote_observed target remote_actual
  admit_stream "$stream"
  [ "$(runbook_field "$RUNBOOK" landing)" = push ] || die "partial reconciliation applies only to push delivery"
  classifier="$(cmd_delivery_classify "$stream" | sed -n 's/^classifier=//p')"
  [ "$classifier" = partial-delivery ] || die "delivery is not partial"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase"{print $2;exit}' "$TRACKER")"
  case "$(tracker_get shipment "$shipment" phase)" in advance|friction) ;; *) die "partial shipment is not in delivery recovery" ;; esac
  candidate="$(tracker_get delivery "$shipment/local-target" candidate-tip)"
  divergent="$(tracker_get delivery "$shipment/remote-target" observed-tip)"
  [ "$(tracker_get delivery "$shipment/remote-target" candidate-tip)" = "$candidate" ] || die "destination candidates disagree"
  local_observed="$(tracker_get delivery "$shipment/local-target" observed-tip)"
  remote_observed="$(tracker_get delivery "$shipment/remote-target" observed-tip)"
  target="$(runbook_field "$RUNBOOK" target)"
  [ "$(git -C "$ROOT" rev-parse "$target")" = "$local_observed" ] || die "local destination moved since its receipt"
  remote_actual="$(remote_target_tip "$target")" || die "remote destination cannot be verified"
  [ "$remote_actual" = "$remote_observed" ] || die "remote destination moved since its receipt"
  git -C "$WT" fetch -q origin "refs/heads/$target" || die "cannot fetch divergent remote destination"
  [ "$(git -C "$WT" rev-parse FETCH_HEAD)" = "$remote_actual" ] || die "fetched divergent destination differs"
  if [ "$local_observed" != "$candidate" ]; then divergent="$local_observed"; fi
  [ "$(git -C "$WT" rev-parse HEAD)" = "$candidate" ] || die "candidate no longer matches the stream"
  git -C "$WT" cat-file -e "$divergent^{commit}" 2>/dev/null || die "divergent destination object is unavailable"
  if git -C "$WT" merge-base --is-ancestor "$candidate" "$divergent" || \
    git -C "$WT" merge-base --is-ancestor "$divergent" "$candidate"; then
    die "partial tips do not require reconciliation"
  fi
  if ! git -C "$WT" merge --no-ff --no-edit "$divergent" >/dev/null 2>&1; then
    die "reconciliation conflicted; semantic resolution requires new authority"
  fi
  new="$(git -C "$WT" rev-parse HEAD)"; first="$(git -C "$WT" rev-parse HEAD^1)"; second="$(git -C "$WT" rev-parse HEAD^2)"
  [ "$first" = "$candidate" ] && [ "$second" = "$divergent" ] || die "reconciliation parent order is invalid"
  inputs="$(sha256_text "$stream|$shipment|$new|$candidate|$divergent|reconciliation")"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-reconcile.XXXXXX")"
  awk -F '\t' -v s="$shipment" 'NR>1 && $1!="delivery" && !(($1=="gate"&&$2==s)||($1=="shipment"&&$2==s&&($3=="branch-tip"||$3=="inputs-sha256"||$3=="phase"||$3=="outcome"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  printf 'shipment\t%s\tbranch-tip\t%s\nshipment\t%s\tinputs-sha256\t%s\nshipment\t%s\tphase\tgate\nshipment\t%s\toutcome\tactive\nphase\t-\tnext-action\tprepare-ship\n' \
    "$shipment" "$new" "$shipment" "$inputs" "$shipment" "$shipment" >>"$raw"
  rewrite_tracker "$raw"; rm -f "$raw"
  printf 'status=reconciled\nshipment=%s\ncandidate=%s\nauthority=invalidated\nnext_action=prepare-ship\n' "$shipment" "$new"
}

cmd_pr_await() {
  [ "$#" -eq 5 ] && [ "$2" = --authority ] && [ "$3" = confirmed ] && [ "$4" = --reference ] || die "usage: pr-await <stream> --authority confirmed --reference <value>"
  local stream="$1" reference="$5" shipment raw branch candidate published
  validate_text 'PR reference' "$reference"
  admit_stream "$stream"
  [ "$(runbook_field "$RUNBOOK" landing)" = pr ] || die "stream is not configured for PR landing"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase"{print $2;exit}' "$TRACKER")"; [ -n "$shipment" ] || die "no active shipment"
  [ "$(tracker_get shipment "$shipment" phase)" = ready-to-land ] || die "shipment is not ready for PR delivery"
  branch="$(runbook_field "$RUNBOOK" branch)"; candidate="$(tracker_get shipment "$shipment" branch-tip)"
  published="$(git -C "$ROOT" ls-remote --heads origin "refs/heads/$branch" | awk 'NF==2{print $1;found++}END{if(found!=1)exit 2}')" || die "cannot verify published PR branch"
  [ "$published" = "$candidate" ] || die "published PR branch does not match the shipment"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-pr.XXXXXX")"
  awk -F '\t' -v s="$shipment" 'NR>1 && !(($1=="shipment"&&$2==s&&($3=="phase"||$3=="outcome"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  printf 'shipment\t%s\tphase\tadvance\nshipment\t%s\toutcome\tawaiting-merge\nphase\t-\tnext-action\tawait-merge\n' "$shipment" "$shipment" >>"$raw"
  rewrite_tracker "$raw"; rm -f "$raw"
  printf 'status=awaiting-merge\nshipment=%s\nreference=%s\nnext_action=await-merge\n' "$shipment" "$reference"
}

cmd_pr_verify() {
  [ "$#" -eq 1 ] || die "usage: pr-verify <stream>"
  local stream="$1" shipment candidate target raw remote
  admit_stream "$stream"
  [ "$(runbook_field "$RUNBOOK" landing)" = pr ] || die "stream is not configured for PR landing"
  shipment="$(awk -F '\t' '$1=="shipment"&&$3=="phase"{print $2;exit}' "$TRACKER")"; [ -n "$shipment" ] || die "no active shipment"
  [ "$(tracker_get shipment "$shipment" outcome)" = awaiting-merge ] || die "shipment is not awaiting merge"
  candidate="$(tracker_get shipment "$shipment" branch-tip)"; target="$(runbook_field "$RUNBOOK" target)"
  remote="$(remote_target_tip "$target")" || die "cannot verify PR target"
  git -C "$ROOT" fetch -q origin "refs/heads/$target" || die "cannot fetch PR target"
  [ "$(git -C "$ROOT" rev-parse FETCH_HEAD)" = "$remote" ] || die "fetched PR target differs"
  git -C "$ROOT" merge-base --is-ancestor "$candidate" FETCH_HEAD || { printf 'status=awaiting-merge\nnext_action=await-merge\n'; return 1; }
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-pr-merged.XXXXXX")"
  awk -F '\t' -v s="$shipment" 'NR>1 && !(($1=="shipment"&&$2==s&&($3=="phase"||$3=="outcome"))||($1=="phase"&&$2=="-"&&$3=="next-action"))' "$TRACKER" >"$raw"
  printf 'shipment\t%s\tphase\tpostflight\nshipment\t%s\toutcome\tlanded\nphase\t-\tnext-action\tpostflight\n' "$shipment" "$shipment" >>"$raw"
  rewrite_tracker "$raw"; rm -f "$raw"
  printf 'status=merged\nshipment=%s\nnext_action=postflight\n' "$shipment"
}

emit_default_config() {
  cat <<'EOF'
# Workstream configuration

Text outside the versioned blocks is explanatory. Empty hook bodies disable their events.

<!-- workstream:defaults@1 -->
mode: delegate
isolation: worktree
landing: local
ship-cadence: milestone
<!-- /workstream:defaults@1 -->

<!-- workstream:hook:feature-completion@1 -->
execution: inline
concurrency: serial

<!-- /workstream:hook:feature-completion@1 -->

<!-- workstream:hook:ship-friction@1 -->
execution: inline
concurrency: serial

<!-- /workstream:hook:ship-friction@1 -->
EOF
}

emit_control_readme() {
  cat <<'EOF'
<!-- workstream:control@1 -->
# Workstream control surface

`CONFIG.md` defines defaults and lifecycle hooks for streams created after configuration. The
executable `workstream.sh` exclusively validates and mutates ignored per-stream runtime state.
`history.tsv` is the concise landed-unit ledger. Immediate child directories are ignored stream
runtimes; do not copy or nest them.
<!-- /workstream:control@1 -->
EOF
}

write_atomic_file() {
  local destination="$1" candidate="$2" mode="${3:-600}" before current temp parent
  parent="$(dirname "$destination")"; [ -d "$parent" ] && [ ! -L "$parent" ] || die "unsafe destination parent"
  [ ! -L "$destination" ] || die "destination is a symlink: $destination"
  before="$(file_fingerprint "$destination")"; temp="$(mktemp "$parent/.workstream-control.XXXXXX")"
  cp "$candidate" "$temp"; chmod "$mode" "$temp"
  current="$(file_fingerprint "$destination")"; [ "$current" = "$before" ] || { rm -f "$temp"; die "control file changed concurrently"; }
  [ ! -L "$parent" ] && [ ! -L "$destination" ] || { rm -f "$temp"; die "control destination became unsafe"; }
  mv -f "$temp" "$destination"
}

render_control_readme() {
  local incumbent="$1" output="$2" block="$3" starts ends
  if [ ! -e "$incumbent" ]; then cp "$block" "$output"; return; fi
  [ -f "$incumbent" ] && [ ! -L "$incumbent" ] || die "README is unsafe"
  starts="$(grep -cFx '<!-- workstream:control@1 -->' "$incumbent" || true)"; ends="$(grep -cFx '<!-- /workstream:control@1 -->' "$incumbent" || true)"
  if ! { [ "$starts" -le 1 ] && [ "$ends" -le 1 ] && [ "$starts" -eq "$ends" ] &&
    validate_marker_span "$incumbent" '<!-- workstream:control@1 -->' '<!-- /workstream:control@1 -->'; }; then
    die "README control markers conflict"
  fi
  if [ "$starts" -eq 0 ]; then
    cat "$incumbent" >"$output"; [ ! -s "$output" ] || printf '\n' >>"$output"; cat "$block" >>"$output"
  else
    awk -v block="$block" '
      $0=="<!-- workstream:control@1 -->" { while((getline line < block)>0) print line; close(block); inside=1; next }
      $0=="<!-- /workstream:control@1 -->" { inside=0; next }
      !inside { print }
    ' "$incumbent" >"$output"
  fi
}

cmd_control_surface() {
  local mode="$1" home="$ROOT/.streams" initialized=no candidate_config candidate_ignore candidate_readme_block candidate_readme candidate_history changed=0 path
  local -a changed_paths=()
  if [ -e "$home" ] || [ -L "$home" ]; then [ -d "$home" ] && [ ! -L "$home" ] || die "control home is unsafe"; else mkdir "$home"; fi
  if [ -f "$home/README.md" ] && grep -qFx '<!-- workstream:control@1 -->' "$home/README.md"; then initialized=yes; fi
  if [ "$mode" = repair ] && [ "$initialized" = no ] && [ ! -e "$home/workstream.sh" ]; then die "repair requires recognized initialized control state"; fi
  if [ "$mode" = repair ] && { [ ! -e "$home/history.tsv" ] || [ -L "$home/history.tsv" ]; }; then die "initialized history is missing or unsafe; recover it from Git"; fi
  for path in .gitignore CONFIG.md README.md history.tsv workstream.sh; do [ ! -L "$home/$path" ] || die "control target is symlinked: $path"; done

  candidate_config="$(mktemp "${TMPDIR:-/tmp}/workstream-config.XXXXXX")"; emit_default_config >"$candidate_config"
  candidate_ignore="$(mktemp "${TMPDIR:-/tmp}/workstream-ignore.XXXXXX")"; printf '/*/\n/.migration.tsv\n' >"$candidate_ignore"
  candidate_readme_block="$(mktemp "${TMPDIR:-/tmp}/workstream-readme-block.XXXXXX")"; emit_control_readme >"$candidate_readme_block"
  candidate_readme="$(mktemp "${TMPDIR:-/tmp}/workstream-readme.XXXXXX")"; render_control_readme "$home/README.md" "$candidate_readme" "$candidate_readme_block"
  candidate_history="$(mktemp "${TMPDIR:-/tmp}/workstream-history.XXXXXX")"; printf 'stream\tsequence\trecorded_at\ttarget\tunit\tcommits\tsummary\n' >"$candidate_history"

  if [ -e "$home/CONFIG.md" ]; then validate_config "$home/CONFIG.md"; else write_atomic_file "$home/CONFIG.md" "$candidate_config" 644; changed_paths+=(.streams/CONFIG.md); changed=$((changed + 1)); fi
  if [ -e "$home/history.tsv" ]; then validate_history "$home/history.tsv"; else write_atomic_file "$home/history.tsv" "$candidate_history" 644; changed_paths+=(.streams/history.tsv); changed=$((changed + 1)); fi
  if [ ! -f "$home/.gitignore" ] || ! cmp -s "$candidate_ignore" "$home/.gitignore"; then write_atomic_file "$home/.gitignore" "$candidate_ignore" 644; changed_paths+=(.streams/.gitignore); changed=$((changed + 1)); fi
  if [ ! -f "$home/README.md" ] || ! cmp -s "$candidate_readme" "$home/README.md"; then write_atomic_file "$home/README.md" "$candidate_readme" 644; changed_paths+=(.streams/README.md); changed=$((changed + 1)); fi
  if [ "$SELF" != "$home/workstream.sh" ] && { [ ! -f "$home/workstream.sh" ] || ! cmp -s "$SELF" "$home/workstream.sh"; }; then write_atomic_file "$home/workstream.sh" "$SELF" 755; changed_paths+=(.streams/workstream.sh); changed=$((changed + 1)); fi
  if [ "$SELF" = "$home/workstream.sh" ]; then chmod 755 "$home/workstream.sh"; fi
  ensure_exclusions
  rm -f "$candidate_config" "$candidate_ignore" "$candidate_readme_block" "$candidate_readme" "$candidate_history"
  if [ "${#changed_paths[@]}" -gt 0 ]; then git -C "$ROOT" add -- "${changed_paths[@]}"; fi
  if [ "${#changed_paths[@]}" -gt 0 ] && ! git -C "$ROOT" diff --cached --quiet -- "${changed_paths[@]}"; then
    git -C "$ROOT" commit -qm "Workstream: $mode control surface" -- "${changed_paths[@]}"
    printf 'status=committed\noperation=%s\nchanged=%s\n' "$mode" "$changed"
  else
    printf 'status=current\noperation=%s\nchanged=0\n' "$mode"
  fi
}

cmd_setup() { [ "$#" -eq 0 ] || die "usage: setup"; cmd_control_surface setup; }
reconstruct_idle_tracker() { # stream
  local stream="$1" recorded_stream recorded_root recorded_worktree branch target isolation held top before current instance next history candidate temp runbook_hash
  [ -f "$RUNBOOK" ] && [ ! -L "$RUNBOOK" ] || die "stream repair requires a safe runbook"
  [ ! -e "$TRACKER" ] && [ ! -L "$TRACKER" ] || die "stream tracker is unsafe"
  recorded_stream="$(runbook_field "$RUNBOOK" stream)"; recorded_root="$(runbook_field "$RUNBOOK" root)"
  recorded_worktree="$(runbook_field "$RUNBOOK" worktree)"; branch="$(runbook_field "$RUNBOOK" branch)"
  target="$(runbook_field "$RUNBOOK" target)"; isolation="$(runbook_field "$RUNBOOK" isolation)"
  [ "$recorded_stream" = "$stream" ] && [ "$recorded_root" = "$ROOT" ] || die "runbook identity disagrees with the requested stream"
  [ "$branch" = "stream/$stream" ] || die "runbook branch is not canonical"
  validate_ref "$branch"; validate_ref "$target"; git -C "$ROOT" rev-parse --verify --quiet "$target^{commit}" >/dev/null || die "target does not resolve"
  case "$isolation" in
    worktree)
      [ "$recorded_worktree" = "$RUNTIME" ] || die "runbook worktree mismatch"
      top="$(git -C "$RUNTIME" rev-parse --show-toplevel 2>/dev/null)" || die "stream is not a Git worktree"
      [ "$(canonical_dir "$top")" = "$RUNTIME" ] || die "stream worktree coordinate disagrees with Git"
      [ "$(git -C "$RUNTIME" branch --show-current)" = "$branch" ] || die "stream branch is not held"
      git -C "$ROOT" worktree list --porcelain | grep -qxF "worktree $RUNTIME" || die "stream worktree is not registered"
      WT="$RUNTIME"
      ;;
    in-place)
      [ "$recorded_worktree" = "$ROOT" ] || die "in-place worktree mismatch"
      held="$(git -C "$ROOT" branch --show-current)"
      [ "$held" = "$branch" ] || [ "$held" = "$target" ] || die "in-place stream branch is not held or parked"
      WT="$ROOT"
      ;;
    *) die "unsupported isolation: $isolation" ;;
  esac
  validate_tracked_control_surface "$WT"
  [ -z "$(git -C "$WT" status --porcelain --untracked-files=no)" ] || die "tracker reconstruction requires clean tracked work"
  git -C "$WT" merge-base --is-ancestor "$branch" "$target" || die "tracker reconstruction refuses unlanded commits"
  instance="$(runbook_field "$RUNBOOK" instance-id)"; runbook_hash="$(runbook_contract_hash "$RUNBOOK")"
  next=1; history="$ROOT/.streams/history.tsv"
  if [ -e "$history" ] || [ -L "$history" ]; then
    validate_history "$history"
    next="$(awk -F '\t' -v s="$stream" 'NR>1&&$1==s&&$2+0>=m{m=$2+1}END{print m+0}' "$history")"; [ "$next" -gt 0 ] || next=1
  fi
  before="$(file_fingerprint "$RUNBOOK")"; candidate="$(mktemp "${TMPDIR:-/tmp}/workstream-repair-tracker.XXXXXX")"
  emit_tracker_base "$instance" "$next" "$next" "$runbook_hash" - brief intake define-unit >"$candidate"
  validate_tracker "$candidate"; current="$(file_fingerprint "$RUNBOOK")"; [ "$current" = "$before" ] || { rm -f "$candidate"; die "runbook changed during tracker reconstruction"; }
  temp="$(mktemp "$RUNTIME/.workstream.tsv.XXXXXX")"; cp "$candidate" "$temp"; rm -f "$candidate"; chmod 600 "$temp"
  [ ! -e "$TRACKER" ] && [ ! -L "$TRACKER" ] || { rm -f "$temp"; die "tracker appeared during reconstruction"; }
  mv "$temp" "$TRACKER"
}

cmd_repair() {
  if [ "$#" -eq 0 ]; then cmd_control_surface repair; return; fi
  [ "$#" -eq 1 ] || die "usage: repair [stream]"
  stream_paths "$1"
  [ -f "$RUNBOOK" ] && [ ! -L "$RUNBOOK" ] || die "stream repair requires a safe runbook"
  local outcome=repaired
  if [ ! -e "$TRACKER" ] && [ ! -L "$TRACKER" ]; then reconstruct_idle_tracker "$1"; outcome=reconstructed; fi
  [ -f "$TRACKER" ] && [ ! -L "$TRACKER" ] || die "stream tracker is unsafe"
  ensure_exclusions; chmod 600 "$RUNBOOK" "$TRACKER"; admit_stream "$1"
  printf 'status=%s\noperation=repair-stream\nstream=%s\nnext_action=%s\n' "$outcome" "$1" "$(tracker_get phase - next-action)"
}

emit_recovery_anchor() {
  cat <<'EOF'
<!-- workstream:recovery-anchor@1 -->
## Workstream compaction recovery

Only after context compaction, resolve the current Git top level. If its top-level
`WORKSTREAM.md` has matching root/worktree/branch coordinates, read its bounded brief through the
effective `.streams/workstream.sh`, reconcile it with Git, and resume its one reported action. For
an in-place stream, admit only `.streams/<stream>/WORKSTREAM.md` whose recorded branch is currently
checked out. Handoffs visible from the root otherwise belong to other sessions: do not read them.
<!-- /workstream:recovery-anchor@1 -->
EOF
}

anchor_classify() {
  local file="$1" block="$2" starts ends extracted
  if [ ! -e "$file" ]; then printf absent; return; fi
  [ -f "$file" ] && [ ! -L "$file" ] || { printf error; return; }
  starts="$(grep -cFx '<!-- workstream:recovery-anchor@1 -->' "$file" || true)"; ends="$(grep -cFx '<!-- /workstream:recovery-anchor@1 -->' "$file" || true)"
  if ! { [ "$starts" -eq 1 ] && [ "$ends" -eq 1 ] &&
    validate_marker_span "$file" '<!-- workstream:recovery-anchor@1 -->' '<!-- /workstream:recovery-anchor@1 -->'; }; then
      [ "$starts" -eq 0 ] && [ "$ends" -eq 0 ] && printf absent || printf conflict
      return
  fi
  extracted="$(mktemp "${TMPDIR:-/tmp}/workstream-anchor-current.XXXXXX")"
  awk '$0=="<!-- workstream:recovery-anchor@1 -->"{inside=1} inside{print} $0=="<!-- /workstream:recovery-anchor@1 -->"{inside=0}' "$file" >"$extracted"
  if cmp -s "$extracted" "$block"; then printf current; else printf drifted; fi
  rm -f "$extracted"
}

cmd_anchor() {
  local action="${1:-status}" front="${2:-$ROOT/AGENTS.md}" parent block classification output before current
  [ "$#" -le 2 ] || die "usage: anchor [status|install|refresh|remove] [front-door]"
  case "$action" in status|install|refresh|remove) ;; *) die "invalid anchor action" ;; esac
  case "$front" in /*) ;; *) front="$ROOT/$front" ;; esac
  parent="$(dirname "$front")"; [ -d "$parent" ] && [ ! -L "$parent" ] || die "anchor parent is unsafe"
  parent="$(canonical_dir "$parent")" || die "anchor parent is unsafe"
  case "$parent/" in "$ROOT/"*) ;; *) die "anchor front door escapes root" ;; esac
  front="$parent/$(basename "$front")"
  block="$(mktemp "${TMPDIR:-/tmp}/workstream-anchor.XXXXXX")"; emit_recovery_anchor >"$block"
  before="$(file_fingerprint "$front")"
  classification="$(anchor_classify "$front" "$block")"
  if [ "$action" = status ]; then rm -f "$block"; printf 'status=%s\nfront_door=%s\n' "$classification" "$front"; return; fi
  [ "$classification" != conflict ] && [ "$classification" != error ] || { rm -f "$block"; die "anchor state is $classification"; }
  case "$action:$classification" in
    install:absent|refresh:absent|refresh:drifted|refresh:current|install:current) ;;
    install:drifted) rm -f "$block"; die "drifted anchor requires refresh" ;;
    remove:absent) rm -f "$block"; printf 'status=absent\n'; return ;;
    remove:current|remove:drifted) ;;
    *) rm -f "$block"; die "unsupported anchor transition" ;;
  esac
  output="$(mktemp "${TMPDIR:-/tmp}/workstream-anchor-output.XXXXXX")"
  if [ "$action" = remove ]; then
    awk '$0=="<!-- workstream:recovery-anchor@1 -->"{inside=1;next} $0=="<!-- /workstream:recovery-anchor@1 -->"{inside=0;next} !inside{print}' "$front" >"$output"
  elif [ "$classification" = absent ]; then
    [ -e "$front" ] && cat "$front" >"$output"; [ ! -s "$output" ] || printf '\n' >>"$output"; cat "$block" >>"$output"
  else
    awk -v block="$block" '$0=="<!-- workstream:recovery-anchor@1 -->"{while((getline line < block)>0)print line;close(block);inside=1;next} $0=="<!-- /workstream:recovery-anchor@1 -->"{inside=0;next} !inside{print}' "$front" >"$output"
  fi
  [ "$(anchor_classify "$front" "$block")" = "$classification" ] || { rm -f "$block" "$output"; die "anchor changed concurrently"; }
  current="$(file_fingerprint "$front")"; [ "$current" = "$before" ] || { rm -f "$block" "$output"; die "anchor front door changed concurrently"; }
  write_atomic_file "$front" "$output" 644
  rm -f "$block" "$output"
  printf 'status=%s\nfront_door=%s\nprevious=%s\n' "$([ "$action" = remove ] && printf removed || printf installed)" "$front" "$classification"
}

cmd_reconfig() {
  [ "$#" -ge 1 ] || die "usage: reconfig <stream> [--mode <mode>] [--landing <landing>] [--ship-cadence <cadence>] [--inherit <field>]..."
  local stream="$1"; shift
  local purpose branch target source_kind source_pointer generated managed candidate old_hash new_hash raw before current temp config_before config_current
  local mode_opt="" landing_opt="" cadence_opt="" inherit_mode=no inherit_landing=no inherit_cadence=no field
  local old_mode old_mode_source old_landing old_landing_source old_cadence old_cadence_source old_isolation old_isolation_source
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --mode) [ "$#" -ge 2 ] || die "--mode requires a value"; mode_opt="$2"; shift 2 ;;
      --landing) [ "$#" -ge 2 ] || die "--landing requires a value"; landing_opt="$2"; shift 2 ;;
      --ship-cadence) [ "$#" -ge 2 ] || die "--ship-cadence requires a value"; cadence_opt="$2"; shift 2 ;;
      --inherit)
        [ "$#" -ge 2 ] || die "--inherit requires a field"; field="$2"; shift 2
        case "$field" in mode) inherit_mode=yes ;; landing) inherit_landing=yes ;; ship-cadence) inherit_cadence=yes ;; *) die "invalid inherited field: $field" ;; esac
        ;;
      *) die "unknown reconfig option: $1" ;;
    esac
  done
  case "$mode_opt" in ''|delegate|manual) ;; *) die "invalid mode override" ;; esac
  case "$landing_opt" in ''|local|push|pr) ;; *) die "invalid landing override" ;; esac
  case "$cadence_opt" in ''|milestone|per-track|per-stage) ;; *) die "invalid ship-cadence override" ;; esac
  [ -z "$mode_opt" ] || [ "$inherit_mode" = no ] || die "mode cannot be explicit and inherited"
  [ -z "$landing_opt" ] || [ "$inherit_landing" = no ] || die "landing cannot be explicit and inherited"
  [ -z "$cadence_opt" ] || [ "$inherit_cadence" = no ] || die "ship-cadence cannot be explicit and inherited"
  admit_stream_coordinates "$stream"
  if awk -F '\t' '$1=="meta"&&$3=="pending-runbook-contract-sha256"{found=1}END{exit found?0:1}' "$TRACKER"; then cmd_contract_recover "$stream" >/dev/null; fi
  admit_stream "$stream"
  [ -z "$(git -C "$WT" status --porcelain --untracked-files=no)" ] || die "reconfig requires a clean tracked worktree"
  ! awk -F '\t' '$1=="unit"&&$3=="state"&&$4=="active"{found=1} $1=="shipment"{found=1} END{exit found?0:1}' "$TRACKER" || die "reconfig requires a quiescent lifecycle boundary"
  ! awk -F '\t' '$1=="hook"&&$3=="state"&&($4=="ready"||$4=="running"){found=1}END{exit found?0:1}' "$TRACKER" || die "reconfig requires completed hook receipts"
  old_mode="$(runbook_policy_part "$RUNBOOK" mode 2)"; old_mode_source="$(runbook_policy_part "$RUNBOOK" mode 3)"
  old_landing="$(runbook_policy_part "$RUNBOOK" landing 2)"; old_landing_source="$(runbook_policy_part "$RUNBOOK" landing 3)"
  old_cadence="$(runbook_policy_part "$RUNBOOK" ship-cadence 2)"; old_cadence_source="$(runbook_policy_part "$RUNBOOK" ship-cadence 3)"
  old_isolation="$(runbook_field "$RUNBOOK" isolation)"; old_isolation_source="$(runbook_policy_part "$RUNBOOK" isolation 3)"
  config_before="$(file_fingerprint "$ROOT/.streams/CONFIG.md")"
  compile_config
  if [ "$old_isolation_source" = explicit ]; then
    ISOLATION="$old_isolation"; ISOLATION_SOURCE=explicit
  else
    [ "$ISOLATION" = "$old_isolation" ] || die "reconfig cannot change isolation"
  fi
  if [ -n "$mode_opt" ]; then MODE="$mode_opt"; MODE_SOURCE=explicit; elif [ "$inherit_mode" = no ] && [ "$old_mode_source" = explicit ]; then MODE="$old_mode"; MODE_SOURCE=explicit; fi
  if [ -n "$landing_opt" ]; then LANDING="$landing_opt"; LANDING_SOURCE=explicit; elif [ "$inherit_landing" = no ] && [ "$old_landing_source" = explicit ]; then LANDING="$old_landing"; LANDING_SOURCE=explicit; fi
  if [ -n "$cadence_opt" ]; then SHIP_CADENCE="$cadence_opt"; SHIP_CADENCE_SOURCE=explicit; elif [ "$inherit_cadence" = no ] && [ "$old_cadence_source" = explicit ]; then SHIP_CADENCE="$old_cadence"; SHIP_CADENCE_SOURCE=explicit; fi
  if [ "$MODE_SOURCE" = explicit ] || [ "$ISOLATION_SOURCE" = explicit ] || [ "$LANDING_SOURCE" = explicit ] || [ "$SHIP_CADENCE_SOURCE" = explicit ]; then DEFAULTS_SOURCE=explicit; fi
  [ "$ISOLATION" != worktree ] || [ "$LANDING" = local ] || die "worktree isolation requires local landing"
  DEFAULTS_FINGERPRINT="$(sha256_text "mode=$MODE|isolation=$ISOLATION|landing=$LANDING|ship-cadence=$SHIP_CADENCE")"
  purpose="$(runbook_block_field "$RUNBOOK" brief purpose)"; branch="$(runbook_field "$RUNBOOK" branch)"; target="$(runbook_field "$RUNBOOK" target)"
  source_kind="$(runbook_block_field "$RUNBOOK" brief queue-source-kind)"; source_pointer="$(runbook_block_field "$RUNBOOK" brief queue-source)"
  generated="$(mktemp "${TMPDIR:-/tmp}/workstream-reconfig-generated.XXXXXX")"; emit_runbook "$stream" "$(tracker_get meta - instance-id)" "$branch" "$target" "$purpose" "$source_kind" "$source_pointer" >"$generated"
  rm -f "$FEATURE_BODY" "$FRICTION_BODY"
  managed="$(mktemp "${TMPDIR:-/tmp}/workstream-reconfig-managed.XXXXXX")"
  awk '/^<!-- workstream:policy@1 -->$/{inside=1} inside{print} /^<!-- \/workstream:hook:ship-friction@1 -->$/{inside=0;exit}' "$generated" >"$managed"
  candidate="$(mktemp "${TMPDIR:-/tmp}/workstream-reconfig-candidate.XXXXXX")"
  awk -v managed="$managed" '
    /^<!-- workstream:policy@1 -->$/ { while((getline line < managed)>0) print line; close(managed); skip=1; next }
    /^<!-- \/workstream:hook:ship-friction@1 -->$/ { skip=0; next }
    !skip { print }
  ' "$RUNBOOK" >"$candidate"
  old_hash="$(tracker_get meta - runbook-contract-sha256)"; new_hash="$(runbook_contract_hash "$candidate")"
  if [ "$old_hash" = "$new_hash" ]; then rm -f "$generated" "$managed" "$candidate"; printf 'status=unchanged\n'; return; fi
  if [ -n "${WORKSTREAM_TEST_BEFORE_RECONFIG_CONFIG_RECHECK:-}" ]; then "$WORKSTREAM_TEST_BEFORE_RECONFIG_CONFIG_RECHECK" "$ROOT/.streams/CONFIG.md"; fi
  config_current="$(file_fingerprint "$ROOT/.streams/CONFIG.md")"
  [ "$config_current" = "$config_before" ] || { rm -f "$generated" "$managed" "$candidate"; die "configuration changed during reconfig"; }
  current="$(file_fingerprint "$RUNBOOK")"
  [ "$current" = "$RUNBOOK_FINGERPRINT" ] || { rm -f "$generated" "$managed" "$candidate"; die "runbook changed during reconfig"; }
  printf 'status=preview\nold_contract=%s\nnew_contract=%s\n' "$old_hash" "$new_hash"
  raw="$(mktemp "${TMPDIR:-/tmp}/workstream-reconfig-pending.XXXXXX")"; tail -n +2 "$TRACKER" >"$raw"
  printf 'meta\t-\tpending-runbook-contract-sha256\t%s\n' "$new_hash" >>"$raw"; rewrite_tracker "$raw"; rm -f "$raw"
  if [ -n "${WORKSTREAM_TEST_AFTER_RECONFIG_PENDING:-}" ]; then "$WORKSTREAM_TEST_AFTER_RECONFIG_PENDING" "$TRACKER"; die "reconfig interrupted after pending receipt"; fi
  before="$RUNBOOK_FINGERPRINT"; temp="$(mktemp "$RUNTIME/.WORKSTREAM.md.XXXXXX")"; cp "$candidate" "$temp"; chmod 600 "$temp"
  current="$(file_fingerprint "$RUNBOOK")"; [ "$current" = "$before" ] || { rm -f "$temp"; die "runbook changed during reconfig"; }
  mv -f "$temp" "$RUNBOOK"
  rm -f "$generated" "$managed" "$candidate"
  cmd_contract_recover "$stream" >/dev/null
  printf 'status=applied\nold_contract=%s\nnew_contract=%s\n' "$old_hash" "$new_hash"
}

migration_stage() { # manifest stream stage
  local manifest="$1" stream="$2" stage="$3" temp
  temp="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-inventory.XXXXXX")"
  awk -F '\t' -v OFS='\t' -v s="$stream" -v stage="$stage" 'NR==1{print;next} $1==s{$7=stage;found++} {print} END{if(found!=1)exit 2}' "$manifest" >"$temp" || { rm -f "$temp"; die "migration manifest is inconsistent"; }
  write_atomic_file "$manifest" "$temp" 600
  rm -f "$temp"
}

legacy_handoff_field() { # file key
  local file="$1" key="$2"
  awk -v prefix="- $key:" '
    index($0,prefix)==1 {
      value=substr($0,length(prefix)+1); sub(/^[[:space:]]+/,"",value); sub(/[[:space:]]+$/,"",value)
      print value; found++
    }
    END { if(found>1) exit 2 }
  ' "$file"
}

legacy_feature_hook() { # file output
  local file="$1" output="$2"
  awk '
    $0=="feature-completion:" { inside=1; next }
    inside && ($0~/^[a-z][a-z-]*:$/ || /^##[[:space:]]/) { inside=0 }
    inside { print }
  ' "$file" >"$output"
  if [ "$(awk 'NF{print;exit}' "$output")" = '(empty)' ]; then : >"$output"; fi
}

build_migration_manifest() { # old-home manifest
  local old_home="$1" manifest="$2" temp old stream destination registered kind branch target instance tip handoff handoff_hash checkout boundary commit_count
  [ -d "$old_home" ] && [ ! -L "$old_home" ] || die "legacy stream home is unsafe"
  if find "$old_home" -mindepth 1 -maxdepth 1 ! -type d -print -quit | grep -q .; then die "legacy stream home contains an unknown child"; fi
  temp="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-inventory.XXXXXX")"
  printf 'stream\told\tnew\tkind\tbranch\ttarget\tstage\tinstance\ttip\thandoff-sha256\tboundary\tcommit-count\n' >"$temp"
  while IFS= read -r old; do
    [ -d "$old" ] && [ ! -L "$old" ] || die "legacy child is not a directory"
    stream="$(basename "$old")"; validate_stream_name "$stream"; destination="$ROOT/.streams/$stream"
    [ ! -e "$destination" ] && [ ! -L "$destination" ] || die "migration destination collides: $stream"
    [ ! -d "$old/.streams" ] && [ ! -d "$old/.workstreams" ] || die "legacy worktree contains nested stream state: $stream"
    handoff="$old/WORKSTREAM.md"; [ -f "$handoff" ] && [ ! -L "$handoff" ] || die "legacy handoff is missing or unsafe: $stream"
    registered="$(git -C "$ROOT" worktree list --porcelain | awk -v p="$old" '$1=="worktree"&&$2==p{print $2}')"
    if [ "$registered" = "$old" ]; then
      kind=worktree; branch="$(git -C "$old" branch --show-current)"; checkout="$old"
    elif [ -f "$old/WORKSTREAM.md" ] && grep -qE '^- isolation:[[:space:]]*in-place|^isolation[[:space:]]+in-place$' "$old/WORKSTREAM.md"; then
      kind=in-place; branch="$(sed -n -E 's/^- branch:[[:space:]]*//p; s/^branch[[:space:]]+//p' "$old/WORKSTREAM.md" | head -n 1)"; checkout="$ROOT"
      [ -n "$branch" ] || branch="stream/$stream"
    else
      die "legacy child has ambiguous topology: $stream"
    fi
    validate_ref "$branch"
    target="$(sed -n -E 's/^- integration-target:[[:space:]]*//p; s/^- target:[[:space:]]*//p; s/^target[[:space:]]+//p' "$old/WORKSTREAM.md" 2>/dev/null | head -n 1)"
    if [ -z "$target" ]; then git -C "$ROOT" show-ref --verify --quiet refs/heads/main || die "legacy target is missing: $stream"; target=main; fi
    validate_ref "$target"
    [ -z "$(git -C "$checkout" status --porcelain --untracked-files=no)" ] || die "legacy stream has uncommitted tracked state: $stream"
    ! git -C "$checkout" rev-parse -q --verify REBASE_HEAD >/dev/null 2>&1 || die "legacy stream has an interrupted rebase: $stream"
    tip="$(git -C "$checkout" rev-parse "$branch^{commit}")"; boundary="$(git -C "$checkout" rev-parse "$target^{commit}")"
    git -C "$checkout" merge-base --is-ancestor "$boundary" "$tip" || die "legacy stream has divergent target state: $stream"
    commit_count="$(git -C "$checkout" rev-list --count "$boundary..$tip")"
    handoff_hash="$(sha256_file "$handoff")"; instance="$(mint_instance_id)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\tpending\t%s\t%s\t%s\t%s\t%s\n' "$stream" "$old" "$destination" "$kind" "$branch" "$target" "$instance" "$tip" "$handoff_hash" "$boundary" "$commit_count" >>"$temp"
  done < <(find "$old_home" -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort)
  write_atomic_file "$manifest" "$temp" 600
  rm -f "$temp"
}

cmd_migrate() {
  local action="${1:-inventory}" old_home="$ROOT/.workstreams" new_home="$ROOT/.streams" manifest="$ROOT/.streams/.migration.tsv"
  local stream old destination kind branch target stage instance tip handoff_hash boundary commit_count count=0 purpose runbook_temp tracker_temp runbook_hash next history legacy checkout current_set approved_set old_mode_check old_landing_check old_cadence_check source_kind_check cursor_check subject index
  local old_mode old_landing old_cadence source_kind cursor queue_state
  [ "$#" -eq 1 ] || die "usage: migrate <inventory|apply>"
  case "$action" in inventory|apply) ;; *) die "invalid migration action" ;; esac
  if [ ! -e "$old_home" ] && [ ! -f "$manifest" ]; then printf 'status=none\nstreams=0\n'; return; fi
  ensure_exclusions; mkdir -p "$new_home"
  if [ "$action" = inventory ]; then
    if [ -f "$manifest" ]; then
      ! awk -F '\t' 'NR>1&&$7!="pending"{started=1}END{exit started?0:1}' "$manifest" || die "a migration is already in progress"
      rm -f "$manifest"
    fi
    build_migration_manifest "$old_home" "$manifest"
    while IFS=$'\t' read -r stream old destination kind branch target stage instance tip handoff_hash boundary commit_count; do
      [ "$stream" != stream ] || continue
      count=$((count + 1)); printf 'stream=%s\nold=%s\nnew=%s\nkind=%s\n' "$stream" "$old" "$destination" "$kind"
    done <"$manifest"
    printf 'status=inventory\nmanifest=%s\nstreams=%s\n' "$manifest" "$count"; return
  fi
  [ -f "$manifest" ] && [ ! -L "$manifest" ] || die "migration apply requires a persisted inventory manifest"
  [ "$(sed -n '1p' "$manifest")" = $'stream\told\tnew\tkind\tbranch\ttarget\tstage\tinstance\ttip\thandoff-sha256\tboundary\tcommit-count' ] || die "migration manifest header is invalid"
  current_set="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-current.XXXXXX")"; approved_set="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-approved.XXXXXX")"
  find "$old_home" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | LC_ALL=C sort >"$current_set"
  awk -F '\t' 'NR>1&&$7=="pending"{print $2}' "$manifest" | LC_ALL=C sort >"$approved_set"
  cmp -s "$current_set" "$approved_set" || { rm -f "$current_set" "$approved_set"; die "legacy stream set changed after inventory; run inventory again after resolving it"; }
  rm -f "$current_set" "$approved_set"
  # Validate every approved source and all parseable policy/state before the first move.
  while IFS=$'\t' read -r stream old destination kind branch target stage instance tip handoff_hash boundary commit_count; do
    [ "$stream" != stream ] || continue
    case "$stage" in pending)
      [ -d "$old" ] && [ ! -L "$old" ] || die "pending migration source is missing: $stream"
      [ "$(sha256_file "$old/WORKSTREAM.md")" = "$handoff_hash" ] || die "legacy handoff changed after inventory: $stream"
      checkout="$old"; [ "$kind" = in-place ] && checkout="$ROOT"
      [ "$(git -C "$checkout" rev-parse "$branch^{commit}")" = "$tip" ] || die "legacy branch moved after inventory: $stream"
      old_mode_check="$(legacy_handoff_field "$old/WORKSTREAM.md" mode)" || die "legacy mode is ambiguous"
      old_landing_check="$(legacy_handoff_field "$old/WORKSTREAM.md" landing)" || die "legacy landing is ambiguous"
      old_cadence_check="$(legacy_handoff_field "$old/WORKSTREAM.md" ship-cadence)" || die "legacy ship cadence is ambiguous"
      case "$old_mode_check" in ''|delegate|manual) ;; *) die "legacy mode is invalid" ;; esac
      case "$old_landing_check" in ''|local|push|pr) ;; *) die "legacy landing is invalid" ;; esac
      case "$old_cadence_check" in ''|milestone|per-track|per-stage) ;; *) die "legacy ship cadence is invalid" ;; esac
      source_kind_check="$(legacy_handoff_field "$old/WORKSTREAM.md" source-kind)" || die "legacy queue source kind is ambiguous"
      cursor_check="$(legacy_handoff_field "$old/WORKSTREAM.md" source)" || die "legacy queue source is ambiguous"
      case "$source_kind_check" in
        plan|roadmap) [ -n "$cursor_check" ] && [[ "$cursor_check" != \(* ]] || die "legacy queue pointer is missing"; validate_text 'legacy queue pointer' "$cursor_check" ;;
        brief|template|'') ;;
        *) die "legacy queue source kind is invalid" ;;
      esac
      purpose="$(sed -n -E 's/^purpose[[:space:]]+//p; s/^# (.*) — workstream.*/\1/p; s/^# (.*) hand-?off.*/\1/p' "$old/WORKSTREAM.md" 2>/dev/null | head -n 1)"; [ -n "$purpose" ] || purpose="Migrated workstream $stream"
      validate_text 'legacy purpose' "$purpose"
      while IFS= read -r subject; do validate_text 'legacy commit subject' "$subject"; [[ "$subject" != *$'\t'* ]] || die "legacy commit subject contains a tab"; done < <(git -C "$checkout" log --reverse --format='%s' "$boundary..$tip")
      ;;
    moved|complete) ;;
    *) die "migration manifest has an invalid stage: $stage" ;;
    esac
  done < <(tail -n +2 "$manifest")
  while IFS=$'\t' read -r stream old destination kind branch target stage instance tip handoff_hash boundary commit_count; do
    [ "$stream" != stream ] || continue
    count=$((count + 1)); validate_stream_name "$stream"; validate_ref "$branch"; validate_ref "$target"
    if [ "$stage" = pending ]; then
      [ -d "$old" ] && [ ! -L "$old" ] || die "pending migration source is missing: $stream"
      if [ "$kind" = worktree ]; then git -C "$ROOT" worktree move "$old" "$destination"; else mv "$old" "$destination"; fi
      migration_stage "$manifest" "$stream" moved; stage=moved
      if [ -n "${WORKSTREAM_TEST_AFTER_MIGRATION_MOVE:-}" ]; then "$WORKSTREAM_TEST_AFTER_MIGRATION_MOVE" "$manifest"; die "migration interrupted after move"; fi
    fi
    if [ "$stage" = moved ]; then
      [ -d "$destination" ] && [ ! -L "$destination" ] || die "moved migration destination is missing: $stream"
      RUNTIME="$destination"; RUNBOOK="$RUNTIME/WORKSTREAM.md"; TRACKER="$RUNTIME/workstream.tsv"
      if [ -f "$TRACKER" ] && [ ! -L "$TRACKER" ] && grep -qFx '<!-- workstream:identity@1 -->' "$RUNBOOK" 2>/dev/null; then
        validate_tracker "$TRACKER"
        [ "$(runbook_contract_hash "$RUNBOOK")" = "$(tracker_get meta - runbook-contract-sha256)" ] || die "interrupted migration artifacts do not bind: $stream"
        [ "$(runbook_field "$RUNBOOK" instance-id)" = "$instance" ] || die "interrupted migration instance changed: $stream"
        migration_stage "$manifest" "$stream" complete
        continue
      fi
      legacy="$destination/WORKSTREAM.md"; [ -f "$legacy" ] && [ ! -L "$legacy" ] || die "moved legacy handoff is missing or unsafe: $stream"
      purpose="$(sed -n -E 's/^purpose[[:space:]]+//p; s/^# (.*) — workstream.*/\1/p; s/^# (.*) hand-?off.*/\1/p' "$legacy" 2>/dev/null | head -n 1)"
      [ -n "$purpose" ] || purpose="Migrated workstream $stream"
      compile_config
      old_mode="$(legacy_handoff_field "$legacy" mode)" || die "legacy mode is ambiguous"
      old_landing="$(legacy_handoff_field "$legacy" landing)" || die "legacy landing is ambiguous"
      old_cadence="$(legacy_handoff_field "$legacy" ship-cadence)" || die "legacy ship cadence is ambiguous"
      case "$old_mode" in '') ;; delegate|manual) MODE="$old_mode"; MODE_SOURCE=explicit ;; *) die "legacy mode is invalid" ;; esac
      case "$old_landing" in '') ;; local|push|pr) LANDING="$old_landing"; LANDING_SOURCE=explicit ;; *) die "legacy landing is invalid" ;; esac
      case "$old_cadence" in '') ;; milestone|per-track|per-stage) SHIP_CADENCE="$old_cadence"; SHIP_CADENCE_SOURCE=explicit ;; *) die "legacy ship cadence is invalid" ;; esac
      if [ "$kind" = in-place ]; then ISOLATION=in-place; ISOLATION_SOURCE=explicit; WT="$ROOT"; else ISOLATION=worktree; ISOLATION_SOURCE=explicit; LANDING=local; WT="$destination"; fi
      [ "$ISOLATION" != worktree ] || [ "$LANDING" = local ] || die "legacy linked stream has non-local landing"
      if [ "$MODE_SOURCE" = explicit ] || [ "$ISOLATION_SOURCE" = explicit ] || [ "$LANDING_SOURCE" = explicit ] || [ "$SHIP_CADENCE_SOURCE" = explicit ]; then DEFAULTS_SOURCE=explicit; fi
      DEFAULTS_FINGERPRINT="$(sha256_text "mode=$MODE|isolation=$ISOLATION|landing=$LANDING|ship-cadence=$SHIP_CADENCE")"
      legacy_feature_hook "$legacy" "$FEATURE_BODY"
      if grep -q '[^[:space:]]' "$FEATURE_BODY"; then FEATURE_EXECUTION=inline; FEATURE_CONCURRENCY=serial; FEATURE_SOURCE=legacy; fi
      FEATURE_FINGERPRINT="$(compiled_hook_fingerprint feature-completion "$FEATURE_EXECUTION" "$FEATURE_CONCURRENCY" "$FEATURE_BODY")"
      source_kind="$(legacy_handoff_field "$legacy" source-kind)" || die "legacy queue source kind is ambiguous"
      cursor="$(legacy_handoff_field "$legacy" source)" || die "legacy queue source is ambiguous"
      case "$source_kind" in plan|roadmap)
          [ -n "$cursor" ] && [[ "$cursor" != \(* ]] || die "legacy queue pointer is missing"
          validate_text 'legacy queue pointer' "$cursor"; queue_state=ready
          ;;
        brief|template|'') source_kind="${source_kind:-brief}"; cursor=-; queue_state=intake ;;
        *) die "legacy queue source kind is invalid" ;;
      esac
      [ "$commit_count" -eq 0 ] || queue_state=ready
      RUNTIME="$destination"; RUNBOOK="$RUNTIME/WORKSTREAM.md"; TRACKER="$RUNTIME/workstream.tsv"
      next=1; history="$ROOT/.streams/history.tsv"
      if [ -e "$history" ]; then validate_history "$history"; next="$(awk -F '\t' -v s="$stream" 'NR>1&&$1==s&&$2+0>=m{m=$2+1}END{print m+0}' "$history")"; [ "$next" -gt 0 ] || next=1; fi
      runbook_temp="$(mktemp "$RUNTIME/.WORKSTREAM.md.XXXXXX")"; emit_runbook "$stream" "$instance" "$branch" "$target" "$purpose" "$source_kind" "$cursor" >"$runbook_temp"
      runbook_hash="$(runbook_contract_hash "$runbook_temp")"; tracker_temp="$(mktemp "$RUNTIME/.workstream.tsv.XXXXXX")"
      {
        emit_tracker_base "$instance" "$next" "$((next + (commit_count > 0 ? 1 : 0)))" "$runbook_hash" "$cursor" "$source_kind" "$queue_state" "$([ "$commit_count" -gt 0 ] && printf accumulate || printf define-unit)"
        if [ "$commit_count" -gt 0 ]; then
          printf 'unit\t%s\tboundary\t%s\nunit\t%s\tcommit-count\t%s\nunit\t%s\tslug\tmigrated\nunit\t%s\tstate\tcomplete\nunit\t%s\tsummary\t%s\n' "$next" "$boundary" "$next" "$commit_count" "$next" "$next" "$next" "$purpose"
          index=1
          while IFS= read -r subject; do printf 'unit-subject\t%s/%s\tsubject\t%s\n' "$next" "$index" "$subject"; index=$((index + 1)); done < <(git -C "$WT" log --reverse --format='%s' "$boundary..$tip")
        fi
      } >"$tracker_temp"
      validate_tracker "$tracker_temp"; chmod 600 "$runbook_temp" "$tracker_temp"
      mv "$tracker_temp" "$TRACKER"
      if [ -n "${WORKSTREAM_TEST_AFTER_MIGRATION_TRACKER:-}" ]; then "$WORKSTREAM_TEST_AFTER_MIGRATION_TRACKER" "$manifest"; die "migration interrupted after tracker installation"; fi
      mv "$runbook_temp" "$RUNBOOK"
      rm -f "$FEATURE_BODY" "$FRICTION_BODY"; migration_stage "$manifest" "$stream" complete
    fi
  done < <(tail -n +2 "$manifest")
  rmdir "$old_home" 2>/dev/null || true; rm -f "$manifest"; printf 'status=migrated\nstreams=%s\n' "$count"
}

main() {
  [ "$#" -ge 2 ] || { usage; exit 2; }
  if [ "$2" = land-advance ]; then
    LANDING_LOCK_BACKEND="$(select_landing_lock_backend)"
  fi
  case "$2" in setup|repair|anchor|migrate) ADMIT_OPERATION="$2" ;; *) ADMIT_OPERATION=ordinary ;; esac
  case "$2" in read|state|diagnose|list|unpark|close-check|repair) ALLOW_PARKED=yes ;; esac
  admit_root "$1"
  shift
  local operation="$1"; shift
  case "$operation" in
    runtime-init) cmd_runtime_init "$@" ;;
    setup) cmd_setup "$@" ;;
    repair) cmd_repair "$@" ;;
    anchor) cmd_anchor "$@" ;;
    reconfig) cmd_reconfig "$@" ;;
    migrate) cmd_migrate "$@" ;;
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
    friction-add) cmd_friction_add "$@" ;;
    sync) cmd_sync "$@" ;;
    park) cmd_park "$@" ;;
    unpark) cmd_unpark "$@" ;;
    recycle) cmd_recycle "$@" ;;
    close-check) cmd_close_check "$@" ;;
    list) cmd_list "$@" ;;
    ship-prepare) cmd_ship_prepare "$@" ;;
    gate-run) [ "$#" -ge 1 ] || die "gate-run requires a stream"; cmd_gate_run "$@" ;;
    gate-none) cmd_gate_none "$@" ;;
    land-advance) cmd_land_advance "$@" ;;
    _land-advance-transaction) cmd_land_advance_transaction "$@" ;;
    ship-finalize) cmd_ship_finalize "$@" ;;
    delivery-classify) cmd_delivery_classify "$@" ;;
    reconcile-partial) cmd_reconcile_partial "$@" ;;
    pr-await) cmd_pr_await "$@" ;;
    pr-verify) cmd_pr_verify "$@" ;;
    validate-tracker) [ "$#" -eq 1 ] || die "validate-tracker requires one path"; validate_tracker "$1"; printf 'status=valid\n' ;;
    -h|--help|help) usage ;;
    *) die "unknown operation: $operation" ;;
  esac
}

main "$@"
