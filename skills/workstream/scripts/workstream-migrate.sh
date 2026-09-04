#!/usr/bin/env bash
# Package-only attended migration from the retired Workstream layout.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$DIR/workstream.sh"

die() { echo "workstream-migrate.sh: $*" >&2; exit 2; }

usage_migrate() {
  echo 'usage: workstream-migrate.sh <canonical-root> <inventory|apply>' >&2
  exit 2
}

inventory_error() {
  if [ -n "${FINDINGS_FILE:-}" ]; then
    printf 'error\t%s\n' "$*" >>"$FINDINGS_FILE"
  else
    die "$*"
  fi
}

inventory_warn() {
  [ -n "${FINDINGS_FILE:-}" ] || return 0
  printf 'warning\t%s\n' "$*" >>"$FINDINGS_FILE"
}

print_findings() { # findings-file
  local file="$1" kind message
  [ -s "$file" ] || return 0
  while IFS=$'\t' read -r kind message; do
    echo "workstream-migrate.sh: $message" >&2
  done <"$file"
}

normalize_legacy_scalar() { # raw
  local value="$1"
  case "$value" in
    *$'\n'*|*$'\r'*) return 1 ;;
  esac
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  if [ "${#value}" -ge 2 ] && [ "${value:0:1}" = '`' ] && [ "${value: -1}" = '`' ]; then
    value="${value:1:${#value}-2}"
    case "$value" in *'`'*) return 1 ;; esac
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
  fi
  case "$value" in
    '`'*) return 1 ;;
    *'`') return 1 ;;
  esac
  printf '%s' "$value"
}

normalized_legacy_field() { # file key stream label
  local raw norm
  raw="$(legacy_handoff_field "$1" "$2")" || {
    inventory_error "$3: legacy $4 is ambiguous"
    return 1
  }
  if [ -z "$raw" ]; then
    printf '\n'
    return 0
  fi
  if ! norm="$(normalize_legacy_scalar "$raw")"; then
    inventory_error "$3: legacy $4 is invalid: raw=$raw"
    return 1
  fi
  printf '%s\n' "$norm"
}

target_relationship() { # checkout stream-tip target-tip
  local checkout="$1" tip="$2" target_oid="$3" merge_base counts ahead behind relation
  merge_base="$(git -C "$checkout" merge-base "$tip" "$target_oid" 2>/dev/null)" || return 1
  counts="$(git -C "$checkout" rev-list --left-right --count "$target_oid...$tip")"
  behind="${counts%%	*}"
  ahead="${counts#*	}"
  if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
    relation=aligned
  elif [ "$behind" -eq 0 ]; then
    relation=ahead
  elif [ "$ahead" -eq 0 ]; then
    relation=behind
  else
    relation=diverged
  fi
  printf '%s %s %s %s\n' "$merge_base" "$ahead" "$behind" "$relation"
}

is_ignorable_untracked() { # path
  case "$1" in
    .DS_Store|*/.DS_Store) return 0 ;;
  esac
  return 1
}

migration_stage() { # manifest stream stage
  local manifest="$1" stream="$2" stage="$3" temp
  temp="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-stage.XXXXXX")"
  awk -F '\t' -v OFS='\t' -v s="$stream" -v stage="$stage" \
    'NR==1{print;next} $1==s{$7=stage;found++} {print} END{if(found!=1)exit 2}' \
    "$manifest" >"$temp" || { rm -f "$temp"; die "migration manifest is inconsistent"; }
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

legacy_target_field() { # file
  sed -n -E 's/^- integration-target:[[:space:]]*//p; s/^- target:[[:space:]]*//p; s/^target[[:space:]]+//p' "$1" |
    awk 'NF{value=$0; found++} END{if(found==1)print value; else if(found>1)exit 2}'
}

legacy_purpose() { # file stream
  local value
  value="$(sed -n -E 's/^purpose[[:space:]]+//p; s/^# (.*) — workstream.*/\1/p; s/^# (.*) hand-?off.*/\1/p' "$1" |
    awk 'NF{value=$0; found++} END{if(found==1)print value; else if(found>1)exit 2}')" || die "legacy purpose is ambiguous: $2"
  [ -n "$value" ] || value="Migrated workstream $2"
  printf '%s\n' "$value"
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

legacy_git_path() { # checkout administration-path
  local checkout="$1" path
  path="$(git -C "$checkout" rev-parse --git-path "$2")" || die "cannot resolve legacy Git administration path"
  case "$path" in /*) ;; *) path="$checkout/$path" ;; esac
  printf '%s\n' "$path"
}

report_legacy_dirt() { # checkout stream; prints dirt summary; errors on tracked/staged
  local checkout="$1" stream="$2" line path tracked=0 untracked=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      '?? WORKSTREAM.md') continue ;;
      '?? '*)
        path="${line#?? }"
        if is_ignorable_untracked "$path"; then
          inventory_warn "$stream: ignored Finder metadata: $path"
          continue
        fi
        untracked=$((untracked + 1))
        if [ "$untracked" -le 20 ]; then
          inventory_warn "$stream: untracked path will move with the worktree: $path"
        fi
        ;;
      *)
        path="${line:3}"
        tracked=$((tracked + 1))
        if [ "$tracked" -le 20 ]; then
          inventory_error "$stream: tracked path blocks migration: $path"
        fi
        ;;
    esac
  done < <(git -C "$checkout" status --porcelain --untracked-files=all)
  if [ "$tracked" -gt 20 ]; then
    inventory_error "$stream: tracked path blocks migration: +$((tracked - 20)) more"
  fi
  if [ "$untracked" -gt 20 ]; then
    inventory_warn "$stream: untracked path will move with the worktree: +$((untracked - 20)) more"
  fi
  if [ "$tracked" -gt 0 ]; then
    printf 'tracked:%s\n' "$tracked"
    return 1
  fi
  if [ "$untracked" -gt 0 ]; then
    printf 'untracked:%s\n' "$untracked"
    return 0
  fi
  printf 'clean\n'
}

validate_legacy_admin() { # checkout stream
  local checkout="$1" stream="$2" entry path failed=0
  for entry in MERGE_HEAD rebase-merge rebase-apply CHERRY_PICK_HEAD REVERT_HEAD sequencer BISECT_START; do
    path="$(legacy_git_path "$checkout" "$entry")"
    if [ -e "$path" ] || [ -L "$path" ]; then
      inventory_error "$stream: interrupted Git administration: $path"
      failed=1
    fi
  done
  return "$failed"
}

validate_legacy_checkout() { # checkout stream
  validate_legacy_admin "$1" "$2" || return 1
  report_legacy_dirt "$1" "$2" >/dev/null
}

registered_at() { # root path
  local registry_root="$1" expected="$2" registry record path found=0
  registry="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-registry.XXXXXX")"
  git -C "$registry_root" worktree list --porcelain -z >"$registry" || {
    rm -f "$registry"
    return 2
  }
  while IFS= read -r -d '' record; do
    case "$record" in
      'worktree '*)
        path="${record#worktree }"
        if [ "$path" = "$expected" ]; then found=$((found + 1)); fi
        ;;
    esac
  done <"$registry"
  rm -f "$registry"
  [ "$found" -le 1 ] || return 2
  if [ "$found" -eq 1 ]; then printf '%s\n' "$expected"; fi
}

validate_legacy_shape() { # source stream destination
  local old="$1" stream="$2" destination="$3" handoff
  handoff="$old/WORKSTREAM.md"
  if [ ! -d "$old" ] || [ -L "$old" ]; then
    inventory_error "$stream: legacy child is not a safe directory: $old"
    return 1
  fi
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    inventory_error "$stream: destination already exists: $destination"
    return 1
  fi
  if [ -d "$old/.streams" ] || [ -d "$old/.workstreams" ]; then
    inventory_error "$stream: legacy worktree contains nested stream state"
    return 1
  fi
  if [ ! -f "$handoff" ] || [ -L "$handoff" ]; then
    inventory_error "$stream: legacy handoff is missing or unsafe: $handoff"
    return 1
  fi
}

validate_legacy_policy() { # handoff stream
  local handoff="$1" stream="$2" mode_value landing_value cadence_value source_kind_value cursor_value purpose_value failed=0
  mode_value="$(normalized_legacy_field "$handoff" mode "$stream" mode)" || failed=1
  landing_value="$(normalized_legacy_field "$handoff" landing "$stream" landing)" || failed=1
  cadence_value="$(normalized_legacy_field "$handoff" 'ship-cadence' "$stream" 'ship cadence')" || failed=1
  case "$mode_value" in ''|delegate|manual) ;; *) inventory_error "$stream: legacy mode is invalid: $mode_value"; failed=1 ;; esac
  case "$landing_value" in ''|local|push|pr) ;; *) inventory_error "$stream: legacy landing is invalid: $landing_value"; failed=1 ;; esac
  case "$cadence_value" in ''|milestone|per-track|per-stage) ;; *) inventory_error "$stream: legacy ship cadence is invalid: $cadence_value"; failed=1 ;; esac
  source_kind_value="$(normalized_legacy_field "$handoff" source-kind "$stream" 'queue source kind')" || failed=1
  cursor_value="$(normalized_legacy_field "$handoff" source "$stream" 'queue source')" || failed=1
  case "$source_kind_value" in
    plan|roadmap)
      if [ -z "$cursor_value" ] || [[ "$cursor_value" == \(* ]]; then
        inventory_error "$stream: legacy queue pointer is missing"
        failed=1
      else
        validate_text 'legacy queue pointer' "$cursor_value" || failed=1
      fi
      ;;
    brief|template|'') ;;
    *) inventory_error "$stream: legacy queue source kind is invalid: $source_kind_value"; failed=1 ;;
  esac
  purpose_value="$(legacy_purpose "$handoff" "$stream")" || return 1
  validate_text 'legacy purpose' "$purpose_value" || failed=1
  return "$failed"
}

scan_legacy_home() { # old-home
  local old_home="$1" child name
  [ -d "$old_home" ] && [ ! -L "$old_home" ] || {
    inventory_error "legacy stream home is unsafe"
    return 1
  }
  while IFS= read -r child; do
    [ -n "$child" ] || continue
    name="$(basename "$child")"
    if [ "$name" = .DS_Store ]; then
      inventory_warn "$child: ignored Finder metadata"
      continue
    fi
    inventory_error "$child: unknown child"
  done < <(find "$old_home" -mindepth 1 -maxdepth 1 ! -type d -print | LC_ALL=C sort)
}

build_migration_manifest() { # old-home candidate
  local old_home="$1" candidate="$2" old stream destination registered branch target instance tip handoff handoff_hash boundary commit_count checkout raw_target relation_info merge_base ahead behind relation recorded_branch dirt
  printf 'stream\told\tnew\tkind\tbranch\ttarget\tstage\tinstance\ttip\thandoff-sha256\tboundary\tcommit-count\n' >"$candidate"
  scan_legacy_home "$old_home" || return 1
  while IFS= read -r old; do
    stream="$(basename "$old")"
    destination="$ROOT/.streams/$stream"
    case "$stream" in
      ''|*[!a-z0-9-]*|-*|*-|*--*) inventory_error "$stream: invalid stream name"; continue ;;
    esac
    if [ -f "$old/WORKSTREAM.md" ] && grep -qE '^- isolation:[[:space:]]*in-place|^isolation[[:space:]]+in-place$' "$old/WORKSTREAM.md"; then
      inventory_error "$stream: in-place stream must be finished or closed under the legacy skill before migration"
      continue
    fi
    registered="$(registered_at "$ROOT" "$old" || true)"
    if [ "$registered" != "$old" ]; then
      inventory_error "$stream: unregistered or ambiguous worktree: $old"
      continue
    fi
    validate_legacy_shape "$old" "$stream" "$destination" || continue
    checkout="$old"
    branch="$(git -C "$old" branch --show-current || true)"
    if [ -z "$branch" ]; then
      inventory_error "$stream: worktree is not on a branch"
      continue
    fi
    if ! git check-ref-format --branch "$branch" >/dev/null 2>&1; then
      inventory_error "$stream: invalid branch: $branch"
      continue
    fi
    if ! recorded_branch="$(normalized_legacy_field "$old/WORKSTREAM.md" branch "$stream" branch)"; then
      continue
    fi
    if [ -n "$recorded_branch" ] && [ "$recorded_branch" != "$branch" ]; then
      inventory_error "$stream: branch-name mismatch: handoff=$recorded_branch git=$branch"
      continue
    fi
    if ! raw_target="$(legacy_target_field "$old/WORKSTREAM.md")"; then
      inventory_error "$stream: legacy target is ambiguous"
      continue
    fi
    target="$raw_target"
    if [ -n "$target" ]; then
      if ! target="$(normalize_legacy_scalar "$target")"; then
        inventory_error "$stream: normalized integration target is invalid: raw=$raw_target"
        continue
      fi
    fi
    if [ -z "$target" ]; then
      if git -C "$ROOT" show-ref --verify --quiet refs/heads/main; then
        target=main
      else
        inventory_error "$stream: legacy target is missing"
        continue
      fi
    fi
    if ! git check-ref-format --branch "$target" >/dev/null 2>&1; then
      inventory_error "$stream: normalized integration target is invalid: raw=${raw_target:-$target}"
      continue
    fi
    if ! git -C "$checkout" rev-parse --verify --quiet "$target^{commit}" >/dev/null; then
      inventory_error "$stream: integration target does not resolve: $target"
      continue
    fi
    validate_legacy_admin "$checkout" "$stream" || continue
    dirt="$(report_legacy_dirt "$checkout" "$stream")" || continue
    validate_legacy_policy "$old/WORKSTREAM.md" "$stream" || continue
    tip="$(git -C "$checkout" rev-parse "$branch^{commit}")"
    boundary="$(git -C "$checkout" rev-parse "$target^{commit}")"
    if ! relation_info="$(target_relationship "$checkout" "$tip" "$boundary")"; then
      inventory_error "$stream: no merge base with target $target"
      continue
    fi
    merge_base="${relation_info%% *}"
    relation_info="${relation_info#* }"
    ahead="${relation_info%% *}"
    relation_info="${relation_info#* }"
    behind="${relation_info%% *}"
    relation="${relation_info#* }"
    commit_count="$(git -C "$checkout" rev-list --count "$merge_base..$tip")"
    while IFS= read -r subject; do
      [ -n "$subject" ] || continue
      validate_text 'legacy commit subject' "$subject" || continue 2
      [[ "$subject" != *$'\t'* ]] || { inventory_error "$stream: legacy commit subject contains a tab"; continue 2; }
    done < <(git -C "$checkout" log --reverse --format='%s' "$merge_base..$tip")
    handoff="$old/WORKSTREAM.md"
    handoff_hash="$(sha256_file "$handoff")"
    instance="$(mint_instance_id)"
    printf '%s\t%s\t%s\tworktree\t%s\t%s\tpending\t%s\t%s\t%s\t%s\t%s\n' \
      "$stream" "$old" "$destination" "$branch" "$target" "$instance" "$tip" "$handoff_hash" "$boundary" "$commit_count" >>"$candidate"
    printf 'stream=%s\nold=%s\nnew=%s\nkind=worktree\nbranch=%s\ntarget=%s\nrelation=%s\nahead=%s\nbehind=%s\ndirt=%s\n' \
      "$stream" "$old" "$destination" "$branch" "$target" "$relation" "$ahead" "$behind" "$dirt"
  done < <(find "$old_home" -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort)
  if awk -F '\t' '$1=="error"{found=1} END{exit found?0:1}' "$FINDINGS_FILE"; then
    return 1
  fi
}

validate_pending_manifest_row() { # row fields are dynamically scoped from caller
  local registered merge_base
  validate_legacy_shape "$old" "$stream" "$destination" || die "legacy shape changed after inventory: $stream"
  registered="$(registered_at "$ROOT" "$old")"; [ "$registered" = "$old" ] || die "legacy worktree registry changed after inventory: $stream"
  [ "$(sha256_file "$old/WORKSTREAM.md")" = "$handoff_hash" ] || die "legacy handoff changed after inventory: $stream"
  [ "$(git -C "$old" branch --show-current)" = "$branch" ] || die "legacy branch checkout changed after inventory: $stream"
  [ "$(git -C "$old" rev-parse "$branch^{commit}")" = "$tip" ] || die "legacy branch moved after inventory: $stream"
  [ "$(git -C "$old" rev-parse "$target^{commit}")" = "$boundary" ] || die "legacy target boundary moved after inventory: $stream"
  validate_legacy_checkout "$old" "$stream" || die "legacy stream is not relocatable: $stream"
  validate_legacy_policy "$old/WORKSTREAM.md" "$stream" || die "legacy policy changed after inventory: $stream"
  merge_base="$(git -C "$old" merge-base "$tip" "$boundary")" || die "legacy stream has no merge base with target: $stream"
  while IFS= read -r subject; do
    validate_text 'legacy commit subject' "$subject"
    [[ "$subject" != *$'\t'* ]] || die "legacy commit subject contains a tab"
  done < <(git -C "$old" log --reverse --format='%s' "$merge_base..$tip")
}

relocate_legacy_worktree() { # old destination stream
  local old="$1" destination="$2" stream="$3" err
  err="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-move.XXXXXX")"
  if git -C "$ROOT" worktree move "$old" "$destination" 2>"$err"; then
    rm -f "$err"
    return 0
  fi
  if grep -q 'containing submodules cannot be moved' "$err"; then
    rm -f "$err"
    mv "$old" "$destination" || die "cannot relocate worktree: $stream"
    git -C "$ROOT" worktree repair "$destination" >/dev/null 2>&1 || die "cannot repair relocated worktree: $stream"
    return 0
  fi
  cat "$err" >&2
  rm -f "$err"
  die "cannot relocate worktree: $stream"
}

validate_moved_manifest_row() { # row fields are dynamically scoped from caller
  local registered
  [ ! -e "$old" ] && [ ! -L "$old" ] || die "moved migration source reappeared: $stream"
  [ -d "$destination" ] && [ ! -L "$destination" ] || die "moved migration destination is missing: $stream"
  registered="$(registered_at "$ROOT" "$destination")"; [ "$registered" = "$destination" ] || die "moved worktree registry changed: $stream"
  [ "$(git -C "$destination" branch --show-current)" = "$branch" ] || die "moved branch checkout changed: $stream"
  [ "$(git -C "$destination" rev-parse "$branch^{commit}")" = "$tip" ] || die "moved branch tip changed: $stream"
  [ "$(git -C "$destination" rev-parse "$target^{commit}")" = "$boundary" ] || die "moved target boundary changed: $stream"
  if ! grep -qFx '<!-- workstream:identity@1 -->' "$destination/WORKSTREAM.md" 2>/dev/null; then
    [ "$(sha256_file "$destination/WORKSTREAM.md")" = "$handoff_hash" ] || die "moved legacy handoff changed: $stream"
  fi
}

render_migrated_artifacts() { # manifest stream
  local manifest="$1" stream="$2" legacy purpose old_mode old_landing old_cadence source_kind cursor queue_state next runbook_temp tracker_temp runbook_hash index subject merge_base
  legacy="$destination/WORKSTREAM.md"; [ -f "$legacy" ] && [ ! -L "$legacy" ] || die "moved legacy handoff is missing or unsafe: $stream"
  purpose="$(legacy_purpose "$legacy" "$stream")"; compile_config
  old_mode="$(normalized_legacy_field "$legacy" mode "$stream" mode)" || die "legacy mode is invalid"
  old_landing="$(normalized_legacy_field "$legacy" landing "$stream" landing)" || die "legacy landing is invalid"
  old_cadence="$(normalized_legacy_field "$legacy" 'ship-cadence' "$stream" 'ship cadence')" || die "legacy ship cadence is invalid"
  case "$old_mode" in '') ;; delegate|manual) MODE="$old_mode"; MODE_SOURCE=explicit ;; *) die "legacy mode is invalid" ;; esac
  case "$old_landing" in '') ;; local|push|pr) LANDING="$old_landing"; LANDING_SOURCE=explicit ;; *) die "legacy landing is invalid" ;; esac
  case "$old_cadence" in '') ;; milestone|per-track|per-stage) SHIP_CADENCE="$old_cadence"; SHIP_CADENCE_SOURCE=explicit ;; *) die "legacy ship cadence is invalid" ;; esac
  WT="$destination"
  if [ "$MODE_SOURCE" = explicit ] || [ "$LANDING_SOURCE" = explicit ] || [ "$SHIP_CADENCE_SOURCE" = explicit ]; then
    # shellcheck disable=SC2034 # consumed by the sourced runbook emitter
    DEFAULTS_SOURCE=explicit
  fi
  # shellcheck disable=SC2034 # consumed by the sourced runbook emitter
  DEFAULTS_FINGERPRINT="$(sha256_text "mode=$MODE|landing=$LANDING|ship-cadence=$SHIP_CADENCE")"
  legacy_feature_hook "$legacy" "$FEATURE_BODY"
  if grep -q '[^[:space:]]' "$FEATURE_BODY"; then
    FEATURE_EXECUTION=inline; FEATURE_CONCURRENCY=serial
    # shellcheck disable=SC2034 # consumed by the sourced runbook emitter
    FEATURE_SOURCE=legacy
  fi
  # shellcheck disable=SC2034 # consumed by the sourced runbook emitter
  FEATURE_FINGERPRINT="$(compiled_hook_fingerprint feature-completion "$FEATURE_EXECUTION" "$FEATURE_CONCURRENCY" "$FEATURE_BODY")"
  source_kind="$(normalized_legacy_field "$legacy" source-kind "$stream" 'queue source kind')" || die "legacy queue source kind is invalid"
  cursor="$(normalized_legacy_field "$legacy" source "$stream" 'queue source')" || die "legacy queue source is invalid"
  case "$source_kind" in
    plan|roadmap) [ -n "$cursor" ] && [[ "$cursor" != \(* ]] || die "legacy queue pointer is missing"; validate_text 'legacy queue pointer' "$cursor"; queue_state=ready ;;
    brief|template|'') source_kind="${source_kind:-brief}"; cursor=-; queue_state=intake ;;
    *) die "legacy queue source kind is invalid" ;;
  esac
  merge_base="$(git -C "$WT" merge-base "$tip" "$boundary")" || die "moved stream has no merge base with target: $stream"
  commit_count="$(git -C "$WT" rev-list --count "$merge_base..$tip")"
  [ "$commit_count" -eq 0 ] || queue_state=ready
  RUNTIME="$destination"; RUNBOOK="$RUNTIME/WORKSTREAM.md"; TRACKER="$RUNTIME/workstream.tsv"
  next=1
  runbook_temp="$(mktemp "$RUNTIME/.WORKSTREAM.md.XXXXXX")"; emit_runbook "$stream" "$instance" "$branch" "$target" "$purpose" "$source_kind" "$cursor" >"$runbook_temp"
  runbook_hash="$(runbook_contract_hash "$runbook_temp")"; tracker_temp="$(mktemp "$RUNTIME/.workstream.tsv.XXXXXX")"
  {
    emit_tracker_base "$instance" "$next" "$((next + (commit_count > 0 ? 1 : 0)))" "$runbook_hash" "$cursor" "$source_kind" "$queue_state" "$([ "$commit_count" -gt 0 ] && printf accumulate || printf define-unit)"
    if [ "$commit_count" -gt 0 ]; then
      printf 'unit\t%s\tboundary\t%s\nunit\t%s\tcommit-count\t%s\nunit\t%s\tslug\tmigrated\nunit\t%s\tstate\tcomplete\nunit\t%s\tsummary\t%s\n' "$next" "$merge_base" "$next" "$commit_count" "$next" "$next" "$next" "$purpose"
      index=1
      while IFS= read -r subject; do printf 'unit-subject\t%s/%s\tsubject\t%s\n' "$next" "$index" "$subject"; index=$((index + 1)); done < <(git -C "$WT" log --reverse --format='%s' "$merge_base..$tip")
    fi
  } >"$tracker_temp"
  validate_tracker "$tracker_temp"; chmod 600 "$runbook_temp" "$tracker_temp"
  mv "$tracker_temp" "$TRACKER"
  if [ -n "${WORKSTREAM_TEST_AFTER_MIGRATION_TRACKER:-}" ]; then "$WORKSTREAM_TEST_AFTER_MIGRATION_TRACKER" "$manifest"; die "migration interrupted after tracker installation"; fi
  mv "$runbook_temp" "$RUNBOOK"; rm -f "$FEATURE_BODY" "$FRICTION_BODY"
}

cmd_migrate_isolated() {
  local action="$1" old_home="$ROOT/.workstreams" new_home="$ROOT/.streams" manifest="$ROOT/.streams/.migration.tsv" candidate
  local stream old destination kind branch target stage instance tip handoff_hash boundary commit_count count=0 current_set approved_set
  if [ ! -e "$old_home" ] && [ ! -f "$manifest" ]; then printf 'status=none\nstreams=0\n'; return; fi
  if [ "$action" = inventory ]; then
    if [ -f "$manifest" ]; then
      ! awk -F '\t' 'NR>1&&$7!="pending"{started=1}END{exit started?0:1}' "$manifest" || die "a migration is already in progress"
    fi
    candidate="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-candidate.XXXXXX")"
    FINDINGS_FILE="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-findings.XXXXXX")"
    if ! build_migration_manifest "$old_home" "$candidate"; then
      print_findings "$FINDINGS_FILE"
      rm -f "$candidate" "$FINDINGS_FILE"
      exit 2
    fi
    print_findings "$FINDINGS_FILE"
    mkdir -p "$new_home"; ensure_exclusions; write_atomic_file "$manifest" "$candidate" 600
    count="$(awk -F '\t' 'NR>1{n++} END{print n+0}' "$manifest")"
    rm -f "$candidate" "$FINDINGS_FILE"
    printf 'status=inventory\nmanifest=%s\nstreams=%s\n' "$manifest" "$count"; return
  fi
  [ -f "$manifest" ] && [ ! -L "$manifest" ] || die "migration apply requires a persisted inventory manifest"
  [ "$(sed -n '1p' "$manifest")" = $'stream\told\tnew\tkind\tbranch\ttarget\tstage\tinstance\ttip\thandoff-sha256\tboundary\tcommit-count' ] || die "migration manifest header is invalid"
  current_set="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-current.XXXXXX")"; approved_set="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-approved.XXXXXX")"
  find "$old_home" -mindepth 1 -maxdepth 1 ! -name .DS_Store -print 2>/dev/null | LC_ALL=C sort >"$current_set"
  awk -F '\t' 'NR>1&&$7=="pending"{print $2}' "$manifest" | LC_ALL=C sort >"$approved_set"
  cmp -s "$current_set" "$approved_set" || { rm -f "$current_set" "$approved_set"; die "legacy stream set changed after inventory; run inventory again after resolving it"; }
  rm -f "$current_set" "$approved_set"
  while IFS=$'\t' read -r stream old destination kind branch target stage instance tip handoff_hash boundary commit_count; do
    [ "$stream" != stream ] || continue
    validate_stream_name "$stream"; validate_ref "$branch"; validate_ref "$target"; [ "$kind" = worktree ] || die "migration manifest topology is unsupported"
    case "$stage" in pending) validate_pending_manifest_row ;; moved|complete) validate_moved_manifest_row ;; *) die "migration manifest has an invalid stage: $stage" ;; esac
  done < <(tail -n +2 "$manifest")
  while IFS=$'\t' read -r stream old destination kind branch target stage instance tip handoff_hash boundary commit_count; do
    [ "$stream" != stream ] || continue
    count=$((count + 1))
    if [ "$stage" = pending ]; then
      relocate_legacy_worktree "$old" "$destination" "$stream"; migration_stage "$manifest" "$stream" moved; stage=moved
      if [ -n "${WORKSTREAM_TEST_AFTER_MIGRATION_MOVE:-}" ]; then "$WORKSTREAM_TEST_AFTER_MIGRATION_MOVE" "$manifest"; die "migration interrupted after move"; fi
    fi
    if [ "$stage" = moved ]; then
      validate_moved_manifest_row
      RUNTIME="$destination"; WT="$destination"; RUNBOOK="$RUNTIME/WORKSTREAM.md"; TRACKER="$RUNTIME/workstream.tsv"
      if [ -f "$TRACKER" ] && [ ! -L "$TRACKER" ] && grep -qFx '<!-- workstream:identity@1 -->' "$RUNBOOK" 2>/dev/null; then
        cmd_read "$stream" >/dev/null
      else
        render_migrated_artifacts "$manifest" "$stream"; cmd_read "$stream" >/dev/null
      fi
      [ "$(git -C "$destination" rev-parse "$branch^{commit}")" = "$tip" ] || die "migration changed stream tip: $stream"
      [ "$(git -C "$destination" rev-parse "$target^{commit}")" = "$boundary" ] || die "migration changed target tip: $stream"
      migration_stage "$manifest" "$stream" complete
      printf 'migrated=%s\n' "$stream"
    fi
  done < <(tail -n +2 "$manifest")
  rm -f "$old_home/.DS_Store"
  rmdir "$old_home" 2>/dev/null || true; rm -f "$manifest"; printf 'status=migrated\nstreams=%s\n' "$count"
}

main_migrate() {
  [ "$#" -eq 2 ] || usage_migrate
  case "$2" in inventory|apply) ;; *) usage_migrate ;; esac
  # shellcheck disable=SC2034 # consumed by sourced root admission
  ADMIT_OPERATION=repair
  admit_root "$1"
  cmd_migrate_isolated "$2"
}

main_migrate "$@"
