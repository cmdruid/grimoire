#!/usr/bin/env bash
# intake-scan.sh <root>
#
# The improvement loop's fact scanner: eligible items per intake source, with
# paused entries, claimed entries, and processed finding keys ALREADY EXCLUDED.
# Facts only -- the eligibility bars (process-flavored, system-flavored, the
# system-improvement bar) are judgment and stay with the verb prose.
#
#   eligible=<id-or-key> source=<path>       an unclaimed, unpaused, unprocessed item
#   skipped_paused=<id>                      pause marker present (the ticket owns it)
#   skipped_claimed=<id-or-key>              claim marker / dispatched: / live source: claim
#   claim_age=<id>:<date>                    an open claim and when it was made (staleness
#                                            is judged by the verb / released by curation)
#
# Claim encodings (frozen): a flat entry's trailing `[⇢ dispatched <date>]`; a
# store-dir `dispatched: <date>` key; a materialized improvement item's
# `source: <identifier>#<key>` line (scanning it as a live claim on that key).
# An unstamped root emits `unstamped=1` and stops.
set -euo pipefail

root="${1:?usage: intake-scan.sh <root>}"
DIR="$(CDPATH='' cd "$(dirname "$0")" && pwd -P)"

IB="$DIR/../../clankshop/scripts/install-block.sh"
if [ -f "$IB" ] && ! sh "$IB" read "$root" | grep -q '^stamped=1$'; then
  echo "unstamped=1"; exit 0
fi

resolve_records_root() {
  local r="$1" fd decl=""
  for fd in "$r/AGENTS.md" "$r/CLAUDE.md"; do
    if [ -z "$decl" ] && [ -f "$fd" ]; then
      decl="$(sed -n 's/^records-root:[[:space:]]*//p' "$fd" | head -n 1 | sed 's/[[:space:]]*$//')"
    fi
  done
  printf '%s\n' "${decl:-.records}"
}
rec="$root/$(resolve_records_root "$root")"
trk="$rec/trackers"

# live source: claims from materialized improvement items (tasks.md improve: lines)
CLAIMED_KEYS="$(grep -oE 'source: [A-Za-z0-9./_-]+#[a-z0-9-]+' "$trk/tasks.md" 2>/dev/null \
  | sed 's/^source: //' || true)"

# ---- flat tracker sources: feedback (F-), issues (I-) ----
flat_source() {  # <file> <entry-lead-regex>
  local f="$1" lead="$2" line id
  [ -f "$f" ] || return 0
  grep -E "$lead" "$f" | while IFS= read -r line; do
    id="$(printf '%s' "$line" | grep -oE '(F|I)-[0-9A-Za-z-]+' | head -1)"
    [ -n "$id" ] || continue
    if printf '%s' "$line" | grep -qF '[⇧ TK-'; then
      echo "skipped_paused=$id"
    elif printf '%s' "$line" | grep -qF '[⇢ dispatched'; then
      echo "skipped_claimed=$id"
      echo "claim_age=$id:$(printf '%s' "$line" | sed -n 's/.*\[⇢ dispatched \([0-9-]*\)\].*/\1/p')"
    else
      echo "eligible=$id source=${f#"$root"/}"
    fi
  done
}
flat_source "$trk/feedback.md" '^### F-[0-9]'
flat_source "$trk/issues.md"   '^### I-[0-9]'

# ---- store-dir source: notes (N-) ----
if [ -d "$trk/notes" ]; then
  for nf in "$trk"/notes/*.md; do
    [ -f "$nf" ] || continue
    case "$nf" in */README.md) continue ;; esac
    id="$(awk 'NR==1 && $0!="---"{exit} /^---$/ && NR>1 {exit} index($0,"id: ")==1 {print substr($0,5); exit}' "$nf")"
    [ -n "$id" ] || continue
    if awk 'NR==1 && $0!="---"{exit 1} /^---$/ && NR>1 {f2=1; exit} index($0,"paused: ")==1 {f=1; exit} END{exit !f}' "$nf"; then
      echo "skipped_paused=$id"
    elif d="$(awk 'NR==1 && $0!="---"{exit} /^---$/ && NR>1 {exit} index($0,"dispatched: ")==1 {print substr($0,13); exit}' "$nf")" && [ -n "$d" ]; then
      echo "skipped_claimed=$id"
      echo "claim_age=$id:$d"
    else
      echo "eligible=$id source=${nf#"$root"/}"
    fi
  done
fi

# ---- finding sources: reports + the audit FINDINGS store ----
# Keys per report = its `#### <key> — <title>` headings; excluded when the file's
# frontmatter `processed:` list names them, or a live improvement item claims them.
finding_source() {  # <file> <source-identifier>
  local f="$1" sid="$2" processed keys k
  [ -f "$f" ] || return 0
  processed=" $(awk 'NR==1 && $0!="---"{exit} /^---$/ && NR>1 {exit} index($0,"processed: ")==1 {print substr($0,12); exit}' "$f" | tr -d '[]' | tr ',' ' ' | tr -s ' ') "
  keys="$(grep -E '^#### [A-Za-z0-9][A-Za-z0-9-]* ' "$f" | awk '{print $2}' || true)"
  for k in $keys; do
    case "$processed" in *" $k "*) echo "skipped_claimed=$sid#$k"; continue ;; esac
    if printf '%s\n' "$CLAIMED_KEYS" | grep -qxF "$sid#$k"; then
      echo "skipped_claimed=$sid#$k"
    else
      echo "eligible=$sid#$k source=${f#"$root"/}"
    fi
  done
}
for rf in "$rec"/reports/doc-drift-*.md "$rec"/reports/investigation-*.md; do
  [ -f "$rf" ] || continue
  sid="$(basename "$rf" .md)"
  finding_source "$rf" "$sid"
done
[ -f "$rec/audit/FINDINGS.md" ] && finding_source "$rec/audit/FINDINGS.md" "${rec#"$root"/}/audit/FINDINGS.md"

exit 0
