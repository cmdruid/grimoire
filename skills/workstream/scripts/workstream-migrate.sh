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

validate_legacy_checkout() { # checkout stream
  local checkout="$1" stream="$2" entry path porcelain
  porcelain="$(git -C "$checkout" status --porcelain --untracked-files=all | grep -vFx '?? WORKSTREAM.md' || true)"
  [ -z "$porcelain" ] || die "legacy stream has uncommitted work: $stream"
  for entry in MERGE_HEAD rebase-merge rebase-apply CHERRY_PICK_HEAD REVERT_HEAD sequencer BISECT_START; do
    path="$(legacy_git_path "$checkout" "$entry")"
    [ ! -e "$path" ] && [ ! -L "$path" ] || die "legacy stream has interrupted Git administration: $stream"
  done
}

registered_at() { # root path
  git -C "$1" worktree list --porcelain | awk -v p="$2" '$1=="worktree"&&$2==p{print $2; found++} END{if(found>1)exit 2}'
}

validate_legacy_shape() { # source stream destination
  local old="$1" stream="$2" destination="$3" handoff
  handoff="$old/WORKSTREAM.md"
  [ -d "$old" ] && [ ! -L "$old" ] || die "legacy child is not a safe directory: $stream"
  [ ! -e "$destination" ] && [ ! -L "$destination" ] || die "migration destination collides: $stream"
  [ ! -d "$old/.streams" ] && [ ! -d "$old/.workstreams" ] || die "legacy worktree contains nested stream state: $stream"
  [ -f "$handoff" ] && [ ! -L "$handoff" ] || die "legacy handoff is missing or unsafe: $stream"
}

build_migration_manifest() { # old-home candidate
  local old_home="$1" candidate="$2" unsupported old stream destination registered branch target instance tip handoff handoff_hash boundary commit_count checkout names
  [ -d "$old_home" ] && [ ! -L "$old_home" ] || die "legacy stream home is unsafe"
  if find "$old_home" -mindepth 1 -maxdepth 1 ! -type d -print -quit | grep -q .; then die "legacy stream home contains an unknown child"; fi
  unsupported="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-unsupported.XXXXXX")"
  printf 'stream\told\tnew\tkind\tbranch\ttarget\tstage\tinstance\ttip\thandoff-sha256\tboundary\tcommit-count\n' >"$candidate"
  while IFS= read -r old; do
    stream="$(basename "$old")"; validate_stream_name "$stream"; destination="$ROOT/.streams/$stream"
    [ -f "$old/WORKSTREAM.md" ] && [ ! -L "$old/WORKSTREAM.md" ] || die "legacy handoff is missing or unsafe: $stream"
    registered="$(registered_at "$ROOT" "$old")"
    if [ "$registered" != "$old" ]; then
      if grep -qE '^- isolation:[[:space:]]*in-place|^isolation[[:space:]]+in-place$' "$old/WORKSTREAM.md"; then
        printf '%s\n' "$stream" >>"$unsupported"
        continue
      fi
      die "legacy child is unregistered or ambiguous: $stream"
    fi
    validate_legacy_shape "$old" "$stream" "$destination"
    branch="$(git -C "$old" branch --show-current)"; checkout="$old"; validate_ref "$branch"
    target="$(legacy_target_field "$old/WORKSTREAM.md")" || die "legacy target is ambiguous: $stream"
    if [ -z "$target" ]; then git -C "$ROOT" show-ref --verify --quiet refs/heads/main || die "legacy target is missing: $stream"; target=main; fi
    validate_ref "$target"; validate_legacy_checkout "$checkout" "$stream"
    tip="$(git -C "$checkout" rev-parse "$branch^{commit}")"; boundary="$(git -C "$checkout" rev-parse "$target^{commit}")"
    git -C "$checkout" merge-base --is-ancestor "$boundary" "$tip" || die "legacy stream has divergent target state: $stream"
    commit_count="$(git -C "$checkout" rev-list --count "$boundary..$tip")"
    handoff="$old/WORKSTREAM.md"; handoff_hash="$(sha256_file "$handoff")"; instance="$(mint_instance_id)"
    printf '%s\t%s\t%s\tworktree\t%s\t%s\tpending\t%s\t%s\t%s\t%s\t%s\n' \
      "$stream" "$old" "$destination" "$branch" "$target" "$instance" "$tip" "$handoff_hash" "$boundary" "$commit_count" >>"$candidate"
  done < <(find "$old_home" -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort)
  if [ -s "$unsupported" ]; then
    names="$(LC_ALL=C sort -u "$unsupported" | paste -sd, -)"; rm -f "$unsupported"
    die "legacy in-place streams must be finished or closed under the legacy skill before migration: $names"
  fi
  rm -f "$unsupported"
}

validate_pending_manifest_row() { # row fields are dynamically scoped from caller
  local registered mode_value landing_value cadence_value source_kind_value cursor_value purpose_value subject
  validate_legacy_shape "$old" "$stream" "$destination"
  registered="$(registered_at "$ROOT" "$old")"; [ "$registered" = "$old" ] || die "legacy worktree registry changed after inventory: $stream"
  [ "$(sha256_file "$old/WORKSTREAM.md")" = "$handoff_hash" ] || die "legacy handoff changed after inventory: $stream"
  [ "$(git -C "$old" branch --show-current)" = "$branch" ] || die "legacy branch checkout changed after inventory: $stream"
  [ "$(git -C "$old" rev-parse "$branch^{commit}")" = "$tip" ] || die "legacy branch moved after inventory: $stream"
  [ "$(git -C "$old" rev-parse "$target^{commit}")" = "$boundary" ] || die "legacy target boundary moved after inventory: $stream"
  git -C "$old" merge-base --is-ancestor "$boundary" "$tip" || die "legacy stream diverged after inventory: $stream"
  validate_legacy_checkout "$old" "$stream"
  mode_value="$(legacy_handoff_field "$old/WORKSTREAM.md" mode)" || die "legacy mode is ambiguous"
  landing_value="$(legacy_handoff_field "$old/WORKSTREAM.md" landing)" || die "legacy landing is ambiguous"
  cadence_value="$(legacy_handoff_field "$old/WORKSTREAM.md" ship-cadence)" || die "legacy ship cadence is ambiguous"
  case "$mode_value" in ''|delegate|manual) ;; *) die "legacy mode is invalid" ;; esac
  case "$landing_value" in ''|local|push|pr) ;; *) die "legacy landing is invalid" ;; esac
  case "$cadence_value" in ''|milestone|per-track|per-stage) ;; *) die "legacy ship cadence is invalid" ;; esac
  source_kind_value="$(legacy_handoff_field "$old/WORKSTREAM.md" source-kind)" || die "legacy queue source kind is ambiguous"
  cursor_value="$(legacy_handoff_field "$old/WORKSTREAM.md" source)" || die "legacy queue source is ambiguous"
  case "$source_kind_value" in
    plan|roadmap) [ -n "$cursor_value" ] && [[ "$cursor_value" != \(* ]] || die "legacy queue pointer is missing"; validate_text 'legacy queue pointer' "$cursor_value" ;;
    brief|template|'') ;;
    *) die "legacy queue source kind is invalid" ;;
  esac
  purpose_value="$(legacy_purpose "$old/WORKSTREAM.md" "$stream")"; validate_text 'legacy purpose' "$purpose_value"
  while IFS= read -r subject; do validate_text 'legacy commit subject' "$subject"; [[ "$subject" != *$'\t'* ]] || die "legacy commit subject contains a tab"; done < <(git -C "$old" log --reverse --format='%s' "$boundary..$tip")
}

validate_moved_manifest_row() { # row fields are dynamically scoped from caller
  local registered
  [ ! -e "$old" ] && [ ! -L "$old" ] || die "moved migration source reappeared: $stream"
  [ -d "$destination" ] && [ ! -L "$destination" ] || die "moved migration destination is missing: $stream"
  registered="$(registered_at "$ROOT" "$destination")"; [ "$registered" = "$destination" ] || die "moved worktree registry changed: $stream"
  [ "$(git -C "$destination" branch --show-current)" = "$branch" ] || die "moved branch checkout changed: $stream"
  [ "$(git -C "$destination" rev-parse "$branch^{commit}")" = "$tip" ] || die "moved branch tip changed: $stream"
  [ "$(git -C "$destination" rev-parse "$target^{commit}")" = "$boundary" ] || die "moved target boundary changed: $stream"
  git -C "$destination" merge-base --is-ancestor "$boundary" "$tip" || die "moved stream diverged after inventory: $stream"
  if ! grep -qFx '<!-- workstream:identity@1 -->' "$destination/WORKSTREAM.md" 2>/dev/null; then
    [ "$(sha256_file "$destination/WORKSTREAM.md")" = "$handoff_hash" ] || die "moved legacy handoff changed: $stream"
  fi
}

render_migrated_artifacts() { # manifest stream
  local manifest="$1" stream="$2" legacy purpose old_mode old_landing old_cadence source_kind cursor queue_state next history runbook_temp tracker_temp runbook_hash index subject
  legacy="$destination/WORKSTREAM.md"; [ -f "$legacy" ] && [ ! -L "$legacy" ] || die "moved legacy handoff is missing or unsafe: $stream"
  purpose="$(legacy_purpose "$legacy" "$stream")"; compile_config
  old_mode="$(legacy_handoff_field "$legacy" mode)" || die "legacy mode is ambiguous"
  old_landing="$(legacy_handoff_field "$legacy" landing)" || die "legacy landing is ambiguous"
  old_cadence="$(legacy_handoff_field "$legacy" ship-cadence)" || die "legacy ship cadence is ambiguous"
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
  source_kind="$(legacy_handoff_field "$legacy" source-kind)" || die "legacy queue source kind is ambiguous"
  cursor="$(legacy_handoff_field "$legacy" source)" || die "legacy queue source is ambiguous"
  case "$source_kind" in
    plan|roadmap) [ -n "$cursor" ] && [[ "$cursor" != \(* ]] || die "legacy queue pointer is missing"; validate_text 'legacy queue pointer' "$cursor"; queue_state=ready ;;
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
    build_migration_manifest "$old_home" "$candidate"
    mkdir -p "$new_home"; ensure_exclusions; write_atomic_file "$manifest" "$candidate" 600; rm -f "$candidate"
    while IFS=$'\t' read -r stream old destination kind branch target stage instance tip handoff_hash boundary commit_count; do
      [ "$stream" != stream ] || continue
      count=$((count + 1)); printf 'stream=%s\nold=%s\nnew=%s\nkind=%s\n' "$stream" "$old" "$destination" "$kind"
    done <"$manifest"
    printf 'status=inventory\nmanifest=%s\nstreams=%s\n' "$manifest" "$count"; return
  fi
  [ -f "$manifest" ] && [ ! -L "$manifest" ] || die "migration apply requires a persisted inventory manifest"
  [ "$(sed -n '1p' "$manifest")" = $'stream\told\tnew\tkind\tbranch\ttarget\tstage\tinstance\ttip\thandoff-sha256\tboundary\tcommit-count' ] || die "migration manifest header is invalid"
  current_set="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-current.XXXXXX")"; approved_set="$(mktemp "${TMPDIR:-/tmp}/workstream-migration-approved.XXXXXX")"
  find "$old_home" -mindepth 1 -maxdepth 1 -print 2>/dev/null | LC_ALL=C sort >"$current_set"
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
      git -C "$ROOT" worktree move "$old" "$destination"; migration_stage "$manifest" "$stream" moved; stage=moved
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
      migration_stage "$manifest" "$stream" complete
    fi
  done < <(tail -n +2 "$manifest")
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
