#!/usr/bin/env bash
# Repository guard for Grimoire's live package-managed canonical providers.
set -euo pipefail

REPO="$(CDPATH='' cd -P "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/canonical-provider-parity.XXXXXX")"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL: $*" >&2; return 1; }

validate() {
  local root="$1" probe expected tracker_file
  [ -x "$root/.records/records.sh" ] || { fail 'deployed records provider missing'; return 1; }
  [ -x "$root/.trackers/trackers.sh" ] || { fail 'deployed tracker provider missing'; return 1; }
  cmp -s "$root/skills/journal/scripts/records.sh" "$root/.records/records.sh" || {
    fail 'deployed records provider differs from its package source'; return 1;
  }
  cmp -s "$root/skills/backlog/scripts/trackers.sh" "$root/.trackers/trackers.sh" || {
    fail 'deployed tracker provider differs from its package source'; return 1;
  }
  [ -d "$root/.trackers/tables" ] && [ ! -L "$root/.trackers/tables" ] || {
    fail 'deployed tracker tables directory missing'; return 1;
  }
  [ -f "$root/.trackers/tables/.gitkeep" ] && [ ! -L "$root/.trackers/tables/.gitkeep" ] || {
    fail 'deployed tracker table marker missing'; return 1;
  }
  [ "$(head -n 1 "$root/.trackers/history.tsv")" = $'id\tcreated\tconsumer\ttracker\titem\taction\tresolution\tresult' ] || {
    fail 'deployed tracker history is malformed'; return 1;
  }
  for tracker_file in "$root/.trackers"/*.tsv; do
    [ "$tracker_file" = "$root/.trackers/history.tsv" ] || {
      fail 'deployed tracker root contains a queue TSV'; return 1;
    }
  done
  for tracker_file in feedback issues routines tasks;do
    [ "$(head -n 1 "$root/.trackers/tables/$tracker_file.tsv")" = $'id\tcreated\ttext\tevidence' ] || {
      fail "deployed tracker table is malformed: $tracker_file"; return 1;
    }
  done
  [ "$("$root/.trackers/trackers.sh" describe|sed -n 's/^schema=//p')" = tracker@2 ] || {
    fail 'deployed tracker provider schema is not tracker@2'; return 1;
  }
  expected="$(mktemp "$T/tracker-readme.XXXXXX")"
  printf '%s\n\n' '# Project trackers' 'Public tracker@2 tables and their shared lifecycle history.' >"$expected"
  cat "$root/skills/backlog/templates/trackers-readme-block.md" >>"$expected"
  cmp -s "$expected" "$root/.trackers/README.md" || {
    fail 'deployed tracker guide differs from Backlog managed output'; return 1;
  }
  [ -f "$root/.records/README.md" ] || { fail 'records guide missing'; return 1; }
  grep -qF '.records/records.sh list' "$root/.records/README.md" || {
    fail 'records guide omits the fixed adjacent invocation'; return 1;
  }
  if rg -n \
    -e '<agent-(records|workspace|trackers)>' \
    -e 'agent-(records|workspace|trackers):' \
    -e 'records-root:' \
    -e '--(records-root|workspace-root|trackers-root)([[:space:]=)]|$)' \
    "$root/.records/README.md" >/dev/null; then
    fail 'records guide retains a retired project-home surface'; return 1
  fi
  probe="$(mktemp -d "$T/reconcile.XXXXXX")"
  mkdir -p "$probe/.records"
  cp "$root/.records/README.md" "$root/.records/records.sh" \
    "$root/.records/history.tsv" "$probe/.records/"
  "$root/skills/journal/scripts/standup.sh" repair "$probe" >/dev/null 2>&1 || {
    fail 'Journal reconciler rejected the deployed records guide'; return 1;
  }
  cmp -s "$root/.records/README.md" "$probe/.records/README.md" || {
    fail 'deployed records guide differs from Journal managed output'; return 1;
  }
}

# The repository itself is a consuming project for these two package-managed
# provider copies. Historical records remain outside this exact live surface.
validate "$REPO"

# Red-prove each parity/absence arm in a throwaway fixture, restoring bytes.
FIX="$T/repo"
mkdir -p "$FIX/skills/journal/scripts" "$FIX/skills/journal/templates" \
  "$FIX/skills/backlog/scripts" "$FIX/skills/backlog/templates" \
  "$FIX/.records" "$FIX/.trackers"
cp "$REPO/skills/journal/scripts/records.sh" "$FIX/skills/journal/scripts/records.sh"
cp "$REPO/skills/journal/scripts/standup.sh" "$FIX/skills/journal/scripts/standup.sh"
cp "$REPO/skills/journal/scripts/records-readme-status.sh" \
  "$FIX/skills/journal/scripts/records-readme-status.sh"
cp "$REPO/skills/journal/templates/records-readme-block.md" \
  "$FIX/skills/journal/templates/records-readme-block.md"
cp "$REPO/skills/backlog/scripts/trackers.sh" "$FIX/skills/backlog/scripts/trackers.sh"
cp "$REPO/skills/backlog/templates/trackers-readme-block.md" "$FIX/skills/backlog/templates/trackers-readme-block.md"
cp "$REPO/.records/records.sh" "$FIX/.records/records.sh"
cp "$REPO/.records/history.tsv" "$FIX/.records/history.tsv"
cp -R "$REPO/.trackers/." "$FIX/.trackers/"
cp "$REPO/.records/README.md" "$FIX/.records/README.md"

mutations=0
red_proof_append() {
  local file="$1" before="$T/before"
  cp "$file" "$before"
  printf '\n# parity canary\n' >>"$file"
  if validate "$FIX" >/dev/null 2>&1; then fail "provider drift survived: $file"; exit 1; fi
  cp "$before" "$file"
  cmp -s "$before" "$file" || { fail 'fixture restoration drifted'; exit 1; }
  mutations=$((mutations + 1))
}

red_proof_append "$FIX/.records/records.sh"
red_proof_append "$FIX/.trackers/trackers.sh"
red_proof_append "$FIX/.trackers/README.md"

printf 'id\tcreated\ttext\tevidence\n' >"$FIX/.trackers/legacy.tsv"
if validate "$FIX" >/dev/null 2>&1;then fail 'root queue layout survived';exit 1;fi
rm "$FIX/.trackers/legacy.tsv";mutations=$((mutations + 1))

mv "$FIX/.trackers/tables/.gitkeep" "$T/table-marker"
if validate "$FIX" >/dev/null 2>&1;then fail 'missing table marker survived';exit 1;fi
mv "$T/table-marker" "$FIX/.trackers/tables/.gitkeep";mutations=$((mutations + 1))

before="$T/readme.before"
cp "$FIX/.records/README.md" "$before"
[ "$(grep -cF '.records/records.sh list' "$before")" -eq 1 ] || {
  fail 'README mutation target count drifted'; exit 1;
}
sed 's|.records/records.sh list|records.sh --root <root> --records-root custom list|' \
  "$before" >"$FIX/.records/README.md"
if validate "$FIX" >/dev/null 2>&1; then fail 'retired README invocation survived'; exit 1; fi
cp "$before" "$FIX/.records/README.md"
cmp -s "$before" "$FIX/.records/README.md" || { fail 'README restoration drifted'; exit 1; }
mutations=$((mutations + 1))

validate "$FIX"
[ "$mutations" -eq 6 ] || { fail 'mutation count drifted'; exit 1; }
echo "canonical-provider-parity-test: $mutations red proofs passed"
