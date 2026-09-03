#!/usr/bin/env bash
# Bind one provisional Foreman operation and its exact goal record to one acceptance digest.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage:
  goal-start.sh render --root <dir> --identity foreman/<stem> --objective <text> --candidate <file> --goal-output <file> --manifest-output <file>
  goal-start.sh apply --root <dir> --candidate <file> --goal-input <file> --manifest-input <file> --expected-preview-digest sha256:<hex>
EOF
  exit 2
}
die() { echo "status=refused"; echo "reason=$1"; exit 1; }
sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else die sha256-tool-missing
  fi
}
valid_identity() { printf '%s\n' "$1" | grep -Eq '^foreman/[a-z0-9]+(-[a-z0-9]+)*$'; }
valid_record_path() {
  printf '%s\n' "$1" | grep -Eq '^goals/[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*\.md$'
}
slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' |
    sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-\{1,\}//' -e 's/-\{1,\}$//'
}
safe_parent_chain() {
  local rel="$1" cur="$root" part oldifs="$IFS" missing=no
  case "$rel" in ''|/*|*//*|*/./*|./*|*/.|*/../*|../*|*/..) return 1 ;; esac
  IFS=/
  for part in $rel; do
    [ -n "$part" ] || continue
    cur="$cur/$part"
    [ "$missing" = no ] || continue
    [ ! -L "$cur" ] || { IFS="$oldifs"; return 1; }
    if [ -e "$cur" ]; then [ -d "$cur" ] || { IFS="$oldifs"; return 1; }; else missing=yes; fi
  done
  IFS="$oldifs"
}

mode="${1:-}"; [ -n "$mode" ] || usage; shift
root=""; identity=""; objective=""; candidate=""; goal_output=""; manifest_output=""
goal_input=""; manifest_input=""; expected_preview_digest=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) [ "$#" -ge 2 ] || usage; root="$2"; shift 2 ;;
    --identity) [ "$#" -ge 2 ] || usage; identity="$2"; shift 2 ;;
    --objective) [ "$#" -ge 2 ] || usage; objective="$2"; shift 2 ;;
    --candidate) [ "$#" -ge 2 ] || usage; candidate="$2"; shift 2 ;;
    --goal-output) [ "$#" -ge 2 ] || usage; goal_output="$2"; shift 2 ;;
    --manifest-output) [ "$#" -ge 2 ] || usage; manifest_output="$2"; shift 2 ;;
    --goal-input) [ "$#" -ge 2 ] || usage; goal_input="$2"; shift 2 ;;
    --manifest-input) [ "$#" -ge 2 ] || usage; manifest_input="$2"; shift 2 ;;
    --expected-preview-digest) [ "$#" -ge 2 ] || usage; expected_preview_digest="$2"; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$root" ] && [ -d "$root" ] || usage
root="$(CDPATH='' cd -P "$root" && pwd)"
script_dir="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
compiler="$script_dir/goal-compile.sh"; writer="$script_dir/operation-write.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/foreman-start.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

write_manifest() {
  local file="$1" operation_value="$2" operation_hash="$3" goal_record_value="$4" goal_hash="$5"
  printf 'operation=%s\noperation_sha256=%s\ngoal_record=%s\ngoal_sha256=%s\n' \
    "$operation_value" "$operation_hash" "$goal_record_value" "$goal_hash" >"$file"
}

case "$mode" in
  render)
    [ -n "$identity" ] && [ -n "$objective" ] && [ -n "$candidate" ] &&
      [ -n "$goal_output" ] && [ -n "$manifest_output" ] || usage
    [ -z "$goal_input$manifest_input$expected_preview_digest" ] || usage
    valid_identity "$identity" || die bad-identity
    case "$objective" in *$'\n'*|*$'\r'*) die multiline-objective ;; esac
    objective_slug="$(slugify "$objective")"; [ -n "$objective_slug" ] || die empty-objective-slug
    [ -f "$candidate" ] && [ ! -L "$candidate" ] || die bad-candidate
    [ ! -e "$goal_output" ] && [ ! -L "$goal_output" ] || die goal-output-exists
    [ ! -e "$manifest_output" ] && [ ! -L "$manifest_output" ] || die manifest-output-exists
    [ -d "${goal_output%/*}" ] && [ -d "${manifest_output%/*}" ] || die output-parent-missing
    record_path="goals/$(date +%Y-%m-%d)-$objective_slug.md"
    "$compiler" render-provisional --root "$root" --operation "$identity" --candidate "$candidate" \
      --objective "$objective" --record-path "$record_path" --output "$goal_output" >"$tmp/compiler.out"
    operation_hash="$(sha256_file "$candidate")"; goal_hash="$(sha256_file "$goal_output")"
    write_manifest "$manifest_output" "$identity" "$operation_hash" "$record_path" "$goal_hash"
    preview_digest="sha256:$(sha256_file "$manifest_output")"
    echo "status=rendered"; echo "operation=$identity"; echo "goal_record=$record_path"
    echo "preview_digest=$preview_digest"; echo "writes=0"
    ;;
  apply)
    [ -n "$candidate" ] && [ -n "$goal_input" ] && [ -n "$manifest_input" ] &&
      [ -n "$expected_preview_digest" ] || usage
    [ -z "$identity$objective$goal_output$manifest_output" ] || usage
    printf '%s\n' "$expected_preview_digest" | grep -Eq '^sha256:[0-9a-f]{64}$' || die bad-preview-digest
    [ -f "$candidate" ] && [ ! -L "$candidate" ] || die bad-candidate
    [ -f "$goal_input" ] && [ ! -L "$goal_input" ] || die bad-goal-input
    [ -f "$manifest_input" ] && [ ! -L "$manifest_input" ] || die bad-manifest-input
    [ "$(wc -l <"$manifest_input" | tr -d ' ')" -eq 4 ] || die malformed-manifest
    manifest_operation="$(sed -n '1s/^operation=//p' "$manifest_input")"
    manifest_operation_hash="$(sed -n '2s/^operation_sha256=//p' "$manifest_input")"
    manifest_goal_record="$(sed -n '3s/^goal_record=//p' "$manifest_input")"
    manifest_goal_hash="$(sed -n '4s/^goal_sha256=//p' "$manifest_input")"
    valid_identity "$manifest_operation" || die malformed-manifest
    printf '%s\n%s\n' "$manifest_operation_hash" "$manifest_goal_hash" |
      grep -Eqv '^[0-9a-f]{64}$' && die malformed-manifest
    valid_record_path "$manifest_goal_record" || die malformed-manifest
    objective="$(awk '/^# Goal: /{print substr($0,9);exit}' "$goal_input")"
    [ -n "$objective" ] || die missing-goal-title

    verify_bundle() {
      local regenerated_goal="$tmp/regenerated-goal.md" regenerated_manifest="$tmp/regenerated-manifest"
      [ "$(sha256_file "$candidate")" = "$manifest_operation_hash" ] || die candidate-drift
      [ "$(sha256_file "$goal_input")" = "$manifest_goal_hash" ] || die goal-drift
      rm -f "$regenerated_goal"
      "$compiler" render-provisional --root "$root" --operation "$manifest_operation" --candidate "$candidate" \
        --objective "$objective" --record-path "$manifest_goal_record" --output "$regenerated_goal" >"$tmp/compiler.out"
      cmp -s "$regenerated_goal" "$goal_input" || die goal-regeneration-mismatch
      write_manifest "$regenerated_manifest" "$manifest_operation" "$manifest_operation_hash" \
        "$manifest_goal_record" "$manifest_goal_hash"
      cmp -s "$regenerated_manifest" "$manifest_input" || die manifest-drift
      computed_preview_digest="sha256:$(sha256_file "$regenerated_manifest")"
      [ "$computed_preview_digest" = "$expected_preview_digest" ] || die preview-digest-mismatch

      operation_dest_rel=".agents/skilldata/${manifest_operation%%/*}/operations/${manifest_operation#*/}.md"
      goal_dest_rel=".records/$manifest_goal_record"
      safe_parent_chain "${operation_dest_rel%/*}" || die unsafe-operation-destination
      safe_parent_chain "${goal_dest_rel%/*}" || die unsafe-goal-destination
      operation_dest="$root/$operation_dest_rel"; goal_dest="$root/$goal_dest_rel"
      if [ -e "$operation_dest" ] || [ -L "$operation_dest" ]; then
        if [ ! -f "$operation_dest" ] || [ -L "$operation_dest" ] || ! cmp -s "$candidate" "$operation_dest"; then
          die operation-incumbent-conflict
        fi
      fi
      published_goal="$tmp/published-goal.md"
      awk 'NR==1&&$0=="---"{fm=1} fm&&/^status:/{print "status: published";next}{print}' "$goal_input" >"$published_goal"
      if [ -e "$goal_dest" ] || [ -L "$goal_dest" ]; then
        if [ ! -f "$goal_dest" ] || [ -L "$goal_dest" ] || ! cmp -s "$published_goal" "$goal_dest"; then
          die goal-incumbent-conflict
        fi
      fi
      records_provider="$root/.records/records.sh"
      if [ -x "$records_provider" ]; then
        provider_record="goals/$(date +%Y-%m-%d)-$(slugify "$objective").md"
        [ "$manifest_goal_record" = "$provider_record" ] || die records-path-mismatch
      fi
    }

    verify_bundle
    if [ -n "${FOREMAN_GOAL_START_TEST_AFTER_PREFLIGHT:-}" ]; then
      [ -x "$FOREMAN_GOAL_START_TEST_AFTER_PREFLIGHT" ] || die bad-test-hook
      "$FOREMAN_GOAL_START_TEST_AFTER_PREFLIGHT" "$candidate" "$goal_input" "$manifest_input"
    fi
    verify_bundle
    "$writer" put --root "$root" --identity "$manifest_operation" --candidate "$candidate" >"$tmp/write.out"
    if [ -n "${FOREMAN_GOAL_START_TEST_AFTER_OPERATION_WRITE:-}" ]; then
      [ -x "$FOREMAN_GOAL_START_TEST_AFTER_OPERATION_WRITE" ] || die bad-test-hook
      "$FOREMAN_GOAL_START_TEST_AFTER_OPERATION_WRITE" "$root" "$manifest_operation" "$manifest_goal_record"
    fi
    "$compiler" publish --root "$root" --input "$goal_input" --record-path "$manifest_goal_record" >"$tmp/publish.out"
    cmp -s "$candidate" "$operation_dest" || die operation-postcondition
    cmp -s "$published_goal" "$goal_dest" || die goal-postcondition
    echo "status=applied"; echo "operation=$manifest_operation"; echo "goal_record=$manifest_goal_record"
    echo "operation_result=$(sed -n 's/^status=//p' "$tmp/write.out" | head -n 1)"
    echo "goal_result=$(sed -n 's/^status=//p' "$tmp/publish.out" | head -n 1)"
    echo "goal_mode=$(sed -n 's/^mode=//p' "$tmp/publish.out" | head -n 1)"
    ;;
  *) usage ;;
esac
