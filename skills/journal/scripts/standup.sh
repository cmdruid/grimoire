#!/bin/sh
# standup.sh — reconcile Journal's records tool layer.
#
#   standup.sh setup|repair|finalize <target-root>
#
# Setup is resumable. Every non-clean run records its roots and completed path
# union at .spaces/journal/setup.intent before changing the tool
# layer. Finalize removes only a ready, revalidated intent after its caller has
# taken commit custody of that union.
set -eu
set -f

SKILL="$(CDPATH='' cd "$(dirname "$0")/.." && pwd -P)"
INTENT_SCHEMA="journal/setup-intent@1"

usage() {
  echo "usage: standup.sh setup|repair|finalize <target-root>" >&2
  exit 1
}

die() {
  echo "standup.sh: $*" >&2
  exit 2
}

valid_rel_dir() {
  [ -n "$1" ] || return 1
  case "$1" in .|/*|*'
'*) return 1 ;; esac
  case "/$1/" in */../*|*/./*|*//*) return 1 ;; esac
  return 0
}

safe_tree() { # verify existing parents from root to target
  tree_target="$1"
  case "$tree_target" in "$root"/*) tree_rel="${tree_target#"$root"/}" ;; *) return 1 ;; esac
  tree_current="$root"
  tree_old_ifs=$IFS
  # Split only on '/', with pathname expansion disabled globally.
  IFS='/'
  # shellcheck disable=SC2086
  set -- $tree_rel
  IFS=$tree_old_ifs
  for tree_part in "$@"; do
    tree_current="$tree_current/$tree_part"
    if [ -L "$tree_current" ]; then
      return 1
    elif [ -e "$tree_current" ] && [ ! -d "$tree_current" ]; then
      return 1
    fi
  done
}

make_tree() { # create after every existing parent has passed safe_tree
  tree_target="$1"
  tree_rel="${tree_target#"$root"/}"
  tree_current="$root"
  tree_old_ifs=$IFS
  # Split only on '/', with pathname expansion disabled globally.
  IFS='/'
  # shellcheck disable=SC2086
  set -- $tree_rel
  IFS=$tree_old_ifs
  for tree_part in "$@"; do
    tree_current="$tree_current/$tree_part"
    if [ ! -e "$tree_current" ]; then mkdir "$tree_current"; fi
    [ -d "$tree_current" ] && [ ! -L "$tree_current" ] || return 1
  done
}

safe_regular_or_absent() {
  [ ! -L "$1" ] && { [ ! -e "$1" ] || [ -f "$1" ]; }
}

cleanup_files=""
remember_tmp() {
  if [ -z "$cleanup_files" ]; then cleanup_files="$1"; else cleanup_files="$cleanup_files
$1"; fi
}
cleanup() {
  cleanup_old_ifs=$IFS
  IFS='
'
  for cleanup_file in $cleanup_files; do [ -z "$cleanup_file" ] || rm -f "$cleanup_file"; done
  IFS=$cleanup_old_ifs
}
trap cleanup EXIT

test_stop() {
  [ "${JOURNAL_SETUP_TEST_STOP_AFTER:-}" != "$1" ] || exit "${JOURNAL_SETUP_TEST_STOP_RC:-86}"
}

completed_list=""
pending_path=""
reported_list=""
is_completed() {
  completed_old_ifs=$IFS
  IFS='
'
  for completed_item in $completed_list; do
    if [ "$completed_item" = "$1" ]; then IFS=$completed_old_ifs; return 0; fi
  done
  IFS=$completed_old_ifs
  return 1
}

append_completed() {
  is_completed "$1" && die "duplicate completed path in setup intent: $1"
  if [ -z "$completed_list" ]; then completed_list="$1"; else completed_list="$completed_list
$1"; fi
}

is_reported() {
  reported_old_ifs=$IFS
  IFS='
'
  for reported_item in $reported_list; do
    if [ "$reported_item" = "$1" ]; then IFS=$reported_old_ifs; return 0; fi
  done
  IFS=$reported_old_ifs
  return 1
}

report_path() {
  is_reported "$1" && return 0
  if [ -z "$reported_list" ]; then reported_list="$1"; else reported_list="$reported_list
$1"; fi
  echo "wrote: $1"
}

emit_completed() {
  emit_old_ifs=$IFS
  IFS='
'
  for emit_path in $completed_list; do [ -z "$emit_path" ] || report_path "$emit_path"; done
  IFS=$emit_old_ifs
}

known_completed_path() {
  [ "$1" = "$provider_rel" ] || [ "$1" = "$ledger_rel" ] ||
    [ "$1" = "$readme_rel" ] || { [ "$legacy_is_deployed" -eq 0 ] && [ "$1" = "$legacy_rel" ]; }
}

write_intent() {
  intent_phase="$1"
  safe_tree "$intent_parent" || die "unsafe setup intent parent during write"
  safe_regular_or_absent "$intent" || die "unsafe setup intent during write: $intent"
  intent_tmp="$(mktemp "$intent_parent/.setup.intent.XXXXXX")"
  remember_tmp "$intent_tmp"
  {
    printf 'schema=%s\n' "$INTENT_SCHEMA"
    printf 'phase=%s\n' "$intent_phase"
    printf 'root=%s\n' "$root"
    printf 'records_root=%s\n' "$records"
    printf 'workspace_root=%s\n' "$workspace"
    printf 'prior_provider=%s\n' "$legacy"
    printf 'pending=%s\n' "$pending_path"
    intent_old_ifs=$IFS
    IFS='
'
    for intent_path in $completed_list; do
      [ -z "$intent_path" ] || printf 'completed=%s\n' "$intent_path"
    done
    IFS=$intent_old_ifs
  } > "$intent_tmp"
  chmod 600 "$intent_tmp"
  mv "$intent_tmp" "$intent"
  phase="$intent_phase"
}

load_intent() {
  safe_tree "$intent_parent" || die "unsafe setup intent parent"
  [ ! -L "$intent" ] && [ -f "$intent" ] || die "unsafe setup intent: $intent"
  intent_schema=""; phase=""; intent_root=""; intent_records=""
  intent_workspace=""; intent_prior=""; pending_path=""; completed_list=""
  schema_count=0; phase_count=0; root_count=0; records_count=0
  workspace_count=0; prior_count=0; pending_count=0
  while IFS= read -r intent_line || [ -n "$intent_line" ]; do
    case "$intent_line" in *=*) ;; *) die "malformed setup intent line" ;; esac
    intent_key=${intent_line%%=*}
    intent_value=${intent_line#*=}
    case "$intent_key" in
      schema) schema_count=$((schema_count + 1)); intent_schema="$intent_value" ;;
      phase) phase_count=$((phase_count + 1)); phase="$intent_value" ;;
      root) root_count=$((root_count + 1)); intent_root="$intent_value" ;;
      records_root) records_count=$((records_count + 1)); intent_records="$intent_value" ;;
      workspace_root) workspace_count=$((workspace_count + 1)); intent_workspace="$intent_value" ;;
      prior_provider) prior_count=$((prior_count + 1)); intent_prior="$intent_value" ;;
      pending) pending_count=$((pending_count + 1)); pending_path="$intent_value" ;;
      completed)
        if [ -z "$intent_value" ] || ! known_completed_path "$intent_value"; then
          die "unsupported completed path in setup intent: $intent_value"
        fi
        append_completed "$intent_value"
        ;;
      *) die "unsupported setup intent field: $intent_key" ;;
    esac
  done < "$intent"
  [ "$schema_count" -eq 1 ] && [ "$phase_count" -eq 1 ] && [ "$root_count" -eq 1 ] &&
    [ "$records_count" -eq 1 ] && [ "$workspace_count" -eq 1 ] && [ "$prior_count" -eq 1 ] &&
    [ "$pending_count" -eq 1 ] ||
    die "setup intent requires exactly one of each fixed field"
  [ "$intent_schema" = "$INTENT_SCHEMA" ] || die "unsupported setup intent schema: $intent_schema"
  case "$phase" in applying|ready) ;; *) die "unsupported setup intent phase: $phase" ;; esac
  if [ -n "$pending_path" ] && ! known_completed_path "$pending_path"; then
    die "unsupported pending path in setup intent: $pending_path"
  fi
  [ "$intent_root" = "$root" ] && [ "$intent_records" = "$records" ] &&
    [ "$intent_workspace" = "$workspace" ] && [ "$intent_prior" = "$legacy" ] ||
    die "setup intent conflicts with current roots"
}

claim_path() {
  [ "$mode" = setup ] || return 0
  [ -z "$pending_path" ] || [ "$pending_path" = "$1" ] ||
    die "setup intent has a different pending path: $pending_path"
  pending_path="$1"
  write_intent applying
}

record_completed() {
  if [ "$mode" = setup ]; then
    [ "$pending_path" = "$1" ] || die "setup path changed without pending custody: $1"
    is_completed "$1" || append_completed "$1"
    pending_path=""
    write_intent applying
  fi
  report_path "$1"
  write_count=$((write_count + 1))
  [ -z "${JOURNAL_SETUP_TEST_AFTER_WRITE:-}" ] || {
    [ -x "$JOURNAL_SETUP_TEST_AFTER_WRITE" ] || die "test post-write hook is not executable"
    "$JOURNAL_SETUP_TEST_AFTER_WRITE" "$root" "$records_rel" "$1" "$write_count"
  }
  case "$1" in
    "$provider_rel") test_stop provider ;;
    "$ledger_rel") test_stop ledger ;;
    "$readme_rel") test_stop readme ;;
    "$legacy_rel") test_stop legacy ;;
  esac
}

validate_markers() {
  readme_begins=0
  [ -f "$readme" ] || return 0
  readme_counts="$(awk '
    $0 == "<!-- journal:records-tool BEGIN -->" { begins++ }
    $0 == "<!-- journal:records-tool END -->" { ends++ }
    END { print begins + 0, ends + 0 }
  ' "$readme")"
  readme_begins=${readme_counts% *}
  readme_ends=${readme_counts#* }
  if [ "$readme_begins" -gt 1 ] || [ "$readme_ends" -gt 1 ] ||
    [ "$readme_begins" -ne "$readme_ends" ]; then
    die "malformed journal records-tool block: $readme"
  fi
  if [ "$readme_begins" -eq 1 ] && ! awk '
    $0 == "<!-- journal:records-tool BEGIN -->" { if (state != 0) exit 1; state = 1; next }
    $0 == "<!-- journal:records-tool END -->" { if (state != 1) exit 1; state = 2; next }
    END { if (state != 2) exit 1 }
  ' "$readme"; then
    die "malformed journal records-tool block: $readme"
  fi
}

render_readme() {
  block_tmp="$(mktemp "${TMPDIR:-/tmp}/journal-records-block.XXXXXX")"
  readme_candidate="$(mktemp "${TMPDIR:-/tmp}/journal-records-readme.XXXXXX")"
  remember_tmp "$block_tmp"; remember_tmp "$readme_candidate"
  cp "$readme_template" "$block_tmp"
  if [ ! -e "$readme" ]; then
    {
      printf '%s\n\n' '# Records' 'Records accumulated during development.'
      cat "$block_tmp"
      cat <<EOF

The directory layout under this root belongs to record writers. The engine
crawls records at any depth and knows no store roster. Project templates live
at \`.spaces/<skill>/templates/\` (for example,
\`.spaces/notepad/templates/\`); project doctrine lives at
\`.spaces/<skill>/doctrine/\`. Journal setup deploys the engine,
ledger, and this README only.

Stood up by journal on $(date +%Y-%m-%d).
EOF
    } > "$readme_candidate"
  elif [ "$readme_begins" -eq 1 ]; then
    awk -v block="$block_tmp" '
      function emit( line) { while ((getline line < block) > 0) print line; close(block) }
      $0 == "<!-- journal:records-tool BEGIN -->" { emit(); inside = 1; next }
      inside && $0 == "<!-- journal:records-tool END -->" { inside = 0; next }
      !inside { print }
    ' "$readme" > "$readme_candidate"
  elif [ "$mode" = setup ]; then
    awk -v block="$block_tmp" -v prior="$legacy_rel" '
      function emit( line) { while ((getline line < block) > 0) print line; close(block); emitted = 1 }
      $0 == "`" prior "` is the query and lifecycle engine;" {
        first = $0; got_second = (getline second) > 0; got_third = (getline third) > 0
        if (got_second && got_third &&
            second ~ /^every invocation passes .*\. It is the$/ &&
            third == "sole writer of `history.tsv`, the closure ledger.") { emit(); next }
        print first; if (got_second) print second; if (got_third) print third; next
      }
      { print }
      END { if (!emitted) { print ""; emit() } }
    ' "$readme" > "$readme_candidate"
  else
    cat "$readme" >"$readme_candidate"
    if [ -s "$readme" ]; then
      readme_last_byte="$(tail -c 1 "$readme" | od -An -tuC | tr -d '[:space:]')"
      if [ "$readme_last_byte" = 10 ]; then printf '\n'; else printf '\n\n'; fi \
        >>"$readme_candidate"
    fi
    cat "$block_tmp" >>"$readme_candidate"
  fi

  # awk preserves every record byte but necessarily emits a newline after its
  # final record. When project-owned prose follows the managed replacement and
  # the incumbent ended without a newline, remove only that synthesized byte.
  # A candidate ending at Journal's END marker owns its canonical final newline.
  if [ -s "$readme" ]; then
    incumbent_last_byte="$(tail -c 1 "$readme" | od -An -tuC | tr -d '[:space:]')"
    candidate_last_line="$(tail -n 1 "$readme_candidate")"
    candidate_last_byte="$(tail -c 1 "$readme_candidate" | od -An -tuC | tr -d '[:space:]')"
    if [ "$incumbent_last_byte" != 10 ] && [ "$candidate_last_byte" = 10 ] &&
      [ "$candidate_last_line" != '<!-- journal:records-tool END -->' ]; then
      candidate_bytes="$(wc -c <"$readme_candidate" | tr -d '[:space:]')"
      readme_trimmed="$(mktemp "${TMPDIR:-/tmp}/journal-records-readme-trimmed.XXXXXX")"
      remember_tmp "$readme_trimmed"
      dd if="$readme_candidate" of="$readme_trimmed" bs=1 count="$((candidate_bytes - 1))" 2>/dev/null
      mv "$readme_trimmed" "$readme_candidate"
    fi
  fi
}

provider_valid() {
  [ -f "$provider" ] && [ ! -L "$provider" ] && [ -x "$provider" ] &&
    cmp -s "$source_engine" "$provider" || return 1
  provider_usage="$("$provider" 2>&1)" &&
    provider_rc=0 || provider_rc=$?
  [ "$provider_rc" -eq 1 ] || return 1
  provider_first="$(printf '%s\n' "$provider_usage" | sed -n '1p')"
  [ "$provider_first" = "usage: .records/records.sh <command> [args]" ] || return 1
  for provider_command in list grep show new touch "done" history prune-candidates check relocate; do
    printf '%s\n' "$provider_usage" | awk -v command="$provider_command" '$1 == command { found = 1 } END { exit !found }' || return 1
  done
}

preflight_tool_layer() {
  safe_tree "$records" || die "unsafe records parent"
  for preflight_entry in "$provider" "$ledger" "$readme"; do
    safe_regular_or_absent "$preflight_entry" || die "unsafe incumbent: $preflight_entry"
  done
  if [ "$mode" != repair ] && [ "$legacy_is_deployed" -eq 0 ]; then
    safe_regular_or_absent "$legacy" || die "unsafe prior provider: $legacy"
    [ "$legacy_parent" = "$root" ] || safe_tree "$legacy_parent" || die "unsafe prior provider parent"
  fi
  validate_markers
  render_readme
}

validate_completed_results() {
  [ -z "$pending_path" ] || die "ready setup intent retains a pending path: $pending_path"
  if is_completed "$provider_rel"; then provider_valid || die "completed provider no longer validates"; fi
  if is_completed "$ledger_rel"; then [ -f "$ledger" ] && [ ! -L "$ledger" ] || die "completed ledger is missing or unsafe"; fi
  if is_completed "$readme_rel"; then cmp -s "$readme_candidate" "$readme" || die "completed README no longer validates"; fi
  if [ "$legacy_is_deployed" -eq 0 ] && is_completed "$legacy_rel"; then
    [ ! -e "$legacy" ] && [ ! -L "$legacy" ] || die "completed prior-provider removal no longer validates"
  fi
}

layer_is_current() {
  provider_valid && [ -f "$ledger" ] && [ ! -L "$ledger" ] &&
    [ -f "$readme" ] && cmp -s "$readme_candidate" "$readme" &&
    { [ "$legacy_is_deployed" -eq 1 ] || { [ ! -e "$legacy" ] && [ ! -L "$legacy" ]; }; }
}

run_content_check() {
  echo "records: $records ($label)"
  if ! "$provider" check; then
    echo "records check failed — tool layer is up; run the record owner's explicit migrate verb for legacy records, then /journal curate" >&2
  fi
}

atomic_install_provider() {
  safe_tree "$records" || die "unsafe records parent during provider write"
  safe_regular_or_absent "$provider" || die "unsafe provider incumbent during write: $provider"
  provider_tmp="$(mktemp "$records/.records.sh.XXXXXX")"
  remember_tmp "$provider_tmp"
  cp "$source_engine" "$provider_tmp"
  chmod 755 "$provider_tmp"
  safe_tree "$records" || die "unsafe records parent during provider replace"
  safe_regular_or_absent "$provider" || die "unsafe provider incumbent during replace: $provider"
  mv "$provider_tmp" "$provider"
}

atomic_create_ledger() {
  safe_tree "$records" || die "unsafe records parent during ledger write"
  [ ! -e "$ledger" ] && [ ! -L "$ledger" ] || die "unsafe ledger incumbent during write: $ledger"
  ledger_tmp="$(mktemp "$records/.history.tsv.XXXXXX")"
  remember_tmp "$ledger_tmp"
  chmod 644 "$ledger_tmp"
  safe_tree "$records" || die "unsafe records parent during ledger replace"
  [ ! -e "$ledger" ] && [ ! -L "$ledger" ] || die "unsafe ledger incumbent during replace: $ledger"
  mv "$ledger_tmp" "$ledger"
}

atomic_install_readme() {
  safe_tree "$records" || die "unsafe records parent during README write"
  safe_regular_or_absent "$readme" || die "unsafe README incumbent during write: $readme"
  readme_tmp="$(mktemp "$records/.README.XXXXXX")"
  remember_tmp "$readme_tmp"
  cp "$readme_candidate" "$readme_tmp"
  chmod 644 "$readme_tmp"
  safe_tree "$records" || die "unsafe records parent during README replace"
  safe_regular_or_absent "$readme" || die "unsafe README incumbent during replace: $readme"
  mv "$readme_tmp" "$readme"
}

[ $# -eq 2 ] || usage
mode="$1"; root="$2"; shift 2
case "$mode" in setup|repair|finalize) ;; *) usage ;; esac
records_rel=.records; workspace_rel=.spaces
[ -d "$root" ] && [ ! -L "$root" ] || die "no safe target directory: $root"
root="$(CDPATH='' cd "$root" && pwd -P)"
git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$git_root" ]; then
  git_root="$(CDPATH='' cd "$git_root" && pwd -P)"
  [ "$git_root" = "$root" ] || die "target root is not the Git top level: $root"
fi
source_engine="$SKILL/scripts/records.sh"
[ -f "$source_engine" ] || die "records.sh missing beside this script: $source_engine"
readme_template="$SKILL/templates/records-readme-block.md"
[ -f "$readme_template" ] && [ ! -L "$readme_template" ] ||
  die "records README template missing or unsafe: $readme_template"
readme_status="$SKILL/scripts/records-readme-status.sh"
if [ ! -x "$readme_status" ] ||
  ! "$readme_status" --validate-template "$readme_template" >/dev/null; then
  die "records README template is malformed: $readme_template"
fi

records="$root/$records_rel"; workspace="$root/$workspace_rel"
provider="$records/records.sh"; ledger="$records/history.tsv"; readme="$records/README.md"
provider_rel="$records_rel/records.sh"; ledger_rel="$records_rel/history.tsv"; readme_rel="$records_rel/README.md"
intent_parent="$workspace/journal"; intent="$intent_parent/setup.intent"
legacy=""; legacy_rel=""; legacy_parent=""; legacy_is_deployed=1
if [ "$mode" != repair ]; then
  legacy="$workspace/journal/scripts/records.sh"; legacy_rel="$workspace_rel/journal/scripts/records.sh"
  legacy_parent="$workspace/journal/scripts"
  legacy_is_deployed=0; [ "$legacy" != "$provider" ] || legacy_is_deployed=1
fi
write_count=0; phase=""

# Intent is authoritative and is checked before tool-layer destinations.
if [ "$mode" = repair ]; then
  safe_tree "$intent_parent" || die "unsafe setup intent parent; run /journal setup"
  [ ! -e "$intent" ] && [ ! -L "$intent" ] || die "active setup intent; run /journal setup"
  intent_exists=0
elif [ -e "$intent" ] || [ -L "$intent" ]; then
  load_intent
  intent_exists=1
  [ "$mode" != setup ] || emit_completed
else
  safe_tree "$intent_parent" || die "unsafe setup intent parent"
  intent_exists=0
fi

preflight_tool_layer

if [ "$mode" = repair ]; then
  [ -d "$records" ] && [ ! -L "$records" ] || die "records layer is not initialized; run /journal setup"
  [ -f "$ledger" ] && [ ! -L "$ledger" ] || die "records layer is not initialized; run /journal setup"
  label="journal, current"
  if ! provider_valid; then
    provider_was_present=0; [ -e "$provider" ] && provider_was_present=1
    atomic_install_provider
    provider_valid || die "installed provider failed validation"
    label="journal"; [ "$provider_was_present" -eq 0 ] || label="journal, refreshed"
    record_completed "$provider_rel"
  fi
  provider_valid || die "provider gate failed before README publication"
  if [ ! -f "$readme" ] || ! cmp -s "$readme_candidate" "$readme"; then
    atomic_install_readme
    record_completed "$readme_rel"
  fi
  run_content_check
  exit 0
fi

if [ "$mode" = finalize ]; then
  [ "$intent_exists" -eq 1 ] || die "no setup intent to finalize"
  [ "$phase" = ready ] || die "setup intent is not ready"
  validate_completed_results
  layer_is_current || die "ready setup results no longer validate"
  test_stop before-finalize
  safe_tree "$intent_parent" || die "unsafe setup intent parent during finalization"
  [ ! -L "$intent" ] && [ -f "$intent" ] || die "unsafe setup intent during finalization"
  rm "$intent"
  exit 0
fi

if [ "$intent_exists" -eq 1 ]; then
  if [ "$phase" = ready ]; then
    validate_completed_results
    layer_is_current || die "ready setup results no longer validate"
    label="journal, current"
    run_content_check
    exit 0
  fi
else
  if layer_is_current; then
    label="journal, current"
    run_content_check
    exit 0
  fi
  safe_tree "$intent_parent" || die "unsafe setup intent parent"
  [ -z "${JOURNAL_SETUP_TEST_AFTER_PREFLIGHT:-}" ] || {
    [ -x "$JOURNAL_SETUP_TEST_AFTER_PREFLIGHT" ] || die "test hook is not executable"
    "$JOURNAL_SETUP_TEST_AFTER_PREFLIGHT" "$root" "$records_rel" "$workspace_rel"
  }
  make_tree "$intent_parent" || die "unsafe setup intent parent during creation"
  write_intent applying
  intent_exists=1
  test_stop intent
fi

make_tree "$records" || die "unsafe records parent during creation"

label="journal, current"
if ! provider_valid; then
  claim_path "$provider_rel"
  provider_was_present=0; [ -e "$provider" ] && provider_was_present=1
  atomic_install_provider
  provider_valid || die "installed provider failed validation"
  label="journal"; [ "$provider_was_present" -eq 0 ] || label="journal, refreshed"
  record_completed "$provider_rel"
elif [ "$pending_path" = "$provider_rel" ]; then
  record_completed "$provider_rel"
fi

if [ ! -e "$ledger" ]; then
  claim_path "$ledger_rel"
  atomic_create_ledger
  record_completed "$ledger_rel"
else
  [ -f "$ledger" ] && [ ! -L "$ledger" ] || die "unsafe ledger incumbent: $ledger"
  if [ "$pending_path" = "$ledger_rel" ]; then record_completed "$ledger_rel"; fi
fi

provider_valid || die "provider gate failed before README publication"
if [ ! -f "$readme" ] || ! cmp -s "$readme_candidate" "$readme"; then
  claim_path "$readme_rel"
  atomic_install_readme
  record_completed "$readme_rel"
elif [ "$pending_path" = "$readme_rel" ]; then
  record_completed "$readme_rel"
fi

if [ "$legacy_is_deployed" -eq 0 ]; then
  if [ -e "$legacy" ] || [ -L "$legacy" ]; then
    [ ! -L "$legacy" ] && [ -f "$legacy" ] || die "unsafe prior provider during removal: $legacy"
    safe_tree "$legacy_parent" || die "unsafe prior provider parent during removal"
    claim_path "$legacy_rel"
    rm "$legacy"
    record_completed "$legacy_rel"
  elif [ "$pending_path" = "$legacy_rel" ]; then
    record_completed "$legacy_rel"
  fi
fi

[ -z "$pending_path" ] || die "setup intent retains an unhandled pending path: $pending_path"
provider_valid || die "provider failed final validation"
run_content_check
write_intent ready
test_stop ready
