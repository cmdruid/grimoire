#!/bin/sh
# standup.sh setup|repair <target-root> [--write-only]
# Reconcile Journal's fixed public tool layer from current filesystem state.
set -eu
set -f

SKILL="$(CDPATH='' cd "$(dirname "$0")/.." && pwd -P)"

usage() {
  echo "usage: standup.sh setup|repair <target-root> [--write-only]" >&2
  exit 1
}

die() { echo "standup.sh: $*" >&2; exit 2; }
refuse() { echo "reason=$1${2:+ action=$2}" >&2; exit 2; }
refuse_detail() { echo "reason=$1${2:+ detail=$2}" >&2; exit 2; }

[ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage
mode="$1"; root="$2"; write_only=no
case "$mode" in setup|repair) ;; *) usage ;; esac
if [ "$#" -eq 3 ]; then [ "$3" = --write-only ] || usage; write_only=yes; fi
[ -d "$root" ] && [ ! -L "$root" ] || die "no safe target directory: $root"
root="$(CDPATH='' cd "$root" && pwd -P)"

git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
git_has_head=no
if [ -n "$git_root" ]; then
  git_root="$(CDPATH='' cd "$git_root" && pwd -P)"
  [ "$git_root" = "$root" ] || die "target root is not the Git top level: $root"
  if git -C "$root" rev-parse --verify HEAD >/dev/null 2>&1; then git_has_head=yes; fi
fi

records="$root/.records"
provider="$records/records.sh"; ledger="$records/history.tsv"; readme="$records/README.md"
provider_rel=.records/records.sh; ledger_rel=.records/history.tsv; readme_rel=.records/README.md
source_provider="$SKILL/scripts/records.sh"
status_helper="$SKILL/scripts/records-layer-status.sh"
readme_status_helper="$SKILL/scripts/records-readme-status.sh"
readme_template="$SKILL/templates/records-readme-block.md"
[ -f "$source_provider" ] && [ ! -L "$source_provider" ] || die "package provider missing"
[ -x "$status_helper" ] && [ -x "$readme_status_helper" ] || die "package status helper missing"
[ -f "$readme_template" ] && [ ! -L "$readme_template" ] || die "README template missing"

cleanup_files=""
remember_tmp() {
  if [ -z "$cleanup_files" ]; then cleanup_files="$1"; else cleanup_files="$cleanup_files
$1"; fi
}
cleanup() {
  old_ifs=$IFS; IFS='
'
  for path in $cleanup_files; do [ -z "$path" ] || rm -f "$path"; done
  IFS=$old_ifs
}
trap cleanup EXIT

safe_regular_or_absent() { [ ! -L "$1" ] && { [ ! -e "$1" ] || [ -f "$1" ]; }; }
safe_records_parent() { [ -d "$records" ] && [ ! -L "$records" ]; }

facts="$($status_helper "$mode" --root "$root")" || exit $?
fact_value() { printf '%s\n' "$facts" | sed -n "s/^$1=//p" | head -n 1; }
layer_status="$(fact_value layer_status)"
ledger_status="$(fact_value ledger_status)"
provider_status="$(fact_value provider_status)"
readme_status="$(fact_value readme_status)"
recovery_state="$(fact_value recovery_state)"

if [ "$mode" = repair ]; then
  [ "$ledger_status" = regular ] || refuse setup-required '/journal setup'
  [ "$layer_status" = current ] || die "unsafe records layer"
else
  case "$recovery_state" in
    git-restore) refuse ledger-recovery-required git-restore ;;
    human-review) refuse ledger-recovery-required human-review ;;
    unsafe) die "unsafe records layer" ;;
    initialized|uninitialized) ;;
    *) die "unknown records-layer state" ;;
  esac
fi
case "$provider_status" in unsafe) die "unsafe provider: $provider" ;; esac
case "$readme_status" in unsafe|malformed) die "unsafe or malformed README: $readme" ;; esac
safe_regular_or_absent "$provider" || die "unsafe provider incumbent: $provider"
safe_regular_or_absent "$ledger" || die "unsafe ledger incumbent: $ledger"
safe_regular_or_absent "$readme" || die "unsafe README incumbent: $readme"

render_readme() { # <incumbent-or-empty-path> <status> <output>
  incumbent="$1"; incumbent_status="$2"; output="$3"
  if [ ! -e "$incumbent" ]; then
    cp "$readme_template" "$output"
  elif [ "$incumbent_status" = current ] || [ "$incumbent_status" = drifted ]; then
    awk -v block="$readme_template" '
      function emit( line) { while ((getline line < block) > 0) print line; close(block) }
      $0 == "<!-- journal:records-tool BEGIN -->" { emit(); inside = 1; next }
      inside && $0 == "<!-- journal:records-tool END -->" { inside = 0; next }
      !inside { print }
    ' "$incumbent" >"$output"
    if [ -s "$incumbent" ]; then
      incumbent_last="$(tail -c 1 "$incumbent" | od -An -tuC | tr -d '[:space:]')"
      output_last="$(tail -c 1 "$output" | od -An -tuC | tr -d '[:space:]')"
      output_line="$(tail -n 1 "$output")"
      if [ "$incumbent_last" != 10 ] && [ "$output_last" = 10 ] &&
        [ "$output_line" != '<!-- journal:records-tool END -->' ]; then
        bytes="$(wc -c <"$output" | tr -d '[:space:]')"
        trimmed="$(mktemp "${TMPDIR:-/tmp}/journal-readme-trimmed.XXXXXX")"
        remember_tmp "$trimmed"
        dd if="$output" of="$trimmed" bs=1 count="$((bytes - 1))" 2>/dev/null
        mv "$trimmed" "$output"
      fi
    fi
  elif [ "$incumbent_status" = absent ]; then
    cat "$incumbent" >"$output"
    if [ -s "$incumbent" ]; then
      last="$(tail -c 1 "$incumbent" | od -An -tuC | tr -d '[:space:]')"
      if [ "$last" = 10 ]; then printf '\n'; else printf '\n\n'; fi >>"$output"
    fi
    cat "$readme_template" >>"$output"
  else
    die "cannot render README from state: $incumbent_status"
  fi
}

readme_candidate="$(mktemp "${TMPDIR:-/tmp}/journal-readme.XXXXXX")"
remember_tmp "$readme_candidate"
render_readme "$readme" "$readme_status" "$readme_candidate"

if [ -n "${JOURNAL_SETUP_TEST_AFTER_PREFLIGHT:-}" ]; then
  [ -x "$JOURNAL_SETUP_TEST_AFTER_PREFLIGHT" ] || die "test preflight hook is not executable"
  "$JOURNAL_SETUP_TEST_AFTER_PREFLIGHT" "$root" .records
fi

if [ ! -e "$records" ]; then mkdir "$records"; fi
safe_records_parent || die "unsafe records parent during creation"

writes=""; write_count=0
was_written() {
  old_ifs=$IFS; IFS='
'
  for path in $writes; do
    if [ "$path" = "$1" ]; then IFS=$old_ifs; return 0; fi
  done
  IFS=$old_ifs; return 1
}
record_write() {
  if [ -z "$writes" ]; then writes="$1"; else writes="$writes
$1"; fi
  printf 'wrote: %s\n' "$1"
  write_count=$((write_count + 1))
  if [ -n "${JOURNAL_SETUP_TEST_AFTER_WRITE:-}" ]; then
    [ -x "$JOURNAL_SETUP_TEST_AFTER_WRITE" ] || die "test post-write hook is not executable"
    "$JOURNAL_SETUP_TEST_AFTER_WRITE" "$root" .records "$1" "$write_count"
  fi
  case "$1" in
    "$provider_rel") stop_name=provider ;;
    "$ledger_rel") stop_name=ledger ;;
    "$readme_rel") stop_name=readme ;;
    *) stop_name=unknown ;;
  esac
  if [ "${JOURNAL_SETUP_TEST_STOP_AFTER:-}" = "$stop_name" ]; then
    exit "${JOURNAL_SETUP_TEST_STOP_RC:-86}"
  fi
}

provider_valid() {
  [ -f "$provider" ] && [ ! -L "$provider" ] && [ -x "$provider" ] &&
    cmp -s "$source_provider" "$provider" || return 1
  usage_output="$("$provider" 2>&1)" && usage_rc=0 || usage_rc=$?
  [ "$usage_rc" -eq 1 ] || return 1
  [ "$(printf '%s\n' "$usage_output" | sed -n '1p')" = \
    'usage: .records/records.sh <command> [args]' ] || return 1
  for command in list grep show new touch "done" history prune-candidates check relocate; do
    printf '%s\n' "$usage_output" |
      awk -v command="$command" '$1 == command { found = 1 } END { exit !found }' || return 1
  done
}

if ! provider_valid; then
  safe_records_parent || die "unsafe records parent during provider write"
  safe_regular_or_absent "$provider" || die "unsafe provider during write: $provider"
  provider_tmp="$(mktemp "$records/.records.sh.XXXXXX")"; remember_tmp "$provider_tmp"
  cp "$source_provider" "$provider_tmp"; chmod 755 "$provider_tmp"
  safe_records_parent && safe_regular_or_absent "$provider" ||
    die "unsafe provider during replace: $provider"
  mv "$provider_tmp" "$provider"
  provider_valid || die "installed provider failed validation"
  record_write "$provider_rel"
fi

provider_valid || die "provider gate failed before ledger publication"
if [ "$mode" = setup ] && [ ! -e "$ledger" ]; then
  safe_records_parent || die "unsafe records parent during ledger write"
  [ ! -e "$ledger" ] && [ ! -L "$ledger" ] || die "unsafe ledger during write: $ledger"
  ledger_tmp="$(mktemp "$records/.history.tsv.XXXXXX")"; remember_tmp "$ledger_tmp"
  chmod 644 "$ledger_tmp"
  safe_records_parent && [ ! -e "$ledger" ] && [ ! -L "$ledger" ] ||
    die "unsafe ledger during replace: $ledger"
  mv "$ledger_tmp" "$ledger"
  record_write "$ledger_rel"
fi
[ -f "$ledger" ] && [ ! -L "$ledger" ] || refuse setup-required '/journal setup'

provider_valid || die "provider gate failed before README publication"
if [ ! -f "$readme" ] || ! cmp -s "$readme_candidate" "$readme"; then
  safe_records_parent || die "unsafe records parent during README write"
  safe_regular_or_absent "$readme" || die "unsafe README during write: $readme"
  readme_tmp="$(mktemp "$records/.README.XXXXXX")"; remember_tmp "$readme_tmp"
  cp "$readme_candidate" "$readme_tmp"; chmod 644 "$readme_tmp"
  safe_records_parent && safe_regular_or_absent "$readme" ||
    die "unsafe README during replace: $readme"
  mv "$readme_tmp" "$readme"
  record_write "$readme_rel"
fi

echo "records: $records (journal, current)"
if ! "$provider" check; then
  echo "records check failed — tool layer is current; action=/journal curate" >&2
fi

[ "$write_only" = no ] || exit 0
[ "$git_has_head" = yes ] || exit 0

is_dirty() { [ -n "$(git -C "$root" status --porcelain=v1 --untracked-files=all -- "$1")" ]; }
head_has() { git -C "$root" cat-file -e "HEAD:$1" 2>/dev/null; }

readme_change_owned() {
  head_readme="$(mktemp "${TMPDIR:-/tmp}/journal-head-readme.XXXXXX")"
  expected_readme="$(mktemp "${TMPDIR:-/tmp}/journal-expected-readme.XXXXXX")"
  remember_tmp "$head_readme"; remember_tmp "$expected_readme"
  if head_has "$readme_rel"; then
    git -C "$root" show "HEAD:$readme_rel" >"$head_readme"
    if head_facts="$("$readme_status_helper" "$readme_template" "$head_readme" 2>/dev/null)"; then
      head_status="$(printf '%s\n' "$head_facts" | sed -n 's/^readme_status=//p' | head -n 1)"
    else
      return 1
    fi
    case "$head_status" in current|drifted|absent) ;; *) return 1 ;; esac
    render_readme "$head_readme" "$head_status" "$expected_readme"
  else
    rm -f "$head_readme"
    render_readme "$head_readme" absent "$expected_readme"
  fi
  cmp -s "$expected_readme" "$readme"
}

candidates="$provider_rel
$readme_rel"
if [ "$mode" = setup ]; then candidates="$provider_rel
$ledger_rel
$readme_rel"; fi
old_ifs=$IFS; IFS='
'
for candidate in $candidates; do
  is_dirty "$candidate" || continue
  case "$candidate" in
    "$provider_rel") provider_valid || { IFS=$old_ifs; refuse_detail commit-custody-required "$candidate"; } ;;
    "$ledger_rel")
      if head_has "$ledger_rel" || [ ! -f "$ledger" ] || [ -L "$ledger" ] || [ -s "$ledger" ]; then
        IFS=$old_ifs; refuse_detail commit-custody-required "$candidate"
      fi
      ;;
    "$readme_rel") readme_change_owned || { IFS=$old_ifs; refuse_detail commit-custody-required "$candidate"; } ;;
  esac
done
for candidate in $candidates; do
  is_dirty "$candidate" || continue
  was_written "$candidate" || printf 'reconciled: %s\n' "$candidate"
done
IFS=$old_ifs
