#!/usr/bin/env bash
# done-entry.sh <root> <id> <outcome> <gist> [<commits>]
#
# The completion mutation, per the record schema's completion table (the
# installation's `.handbook/rules/RECORDS.md`): flat-tracker entries (T-/I-/F-)
# are REMOVED from the live file -- a bullet is its one line; a heading-led
# entry spans from its heading to the line before the next heading of EQUAL OR
# HIGHER rank (###/##/#) or EOF, so completing a category's last entry never
# consumes the following `##` category header. Store-dir items (B-/N-) are
# retained; completion advances frontmatter (`status: resolved` + `updated:`).
# Every completion appends one done-log line to `.records/done/log.md`
# (created with its header on first use):
#   - <YYYY-MM-DD> · <id> · <gist> · commits: <shas|-> · <outcome>
#
# Refusals (facts, no mutation, no log line): an absent ID (`refused=absent`),
# an already-completed ID (`refused=completed` -- present in the done log, or a
# store-dir file already resolved), a paused ID (`refused=paused` -- the entry
# carries the pause marker its store declares). An unstamped root emits
# `unstamped=1` and stops.
#
# DOCTRINE: a mutating mechanical helper (sibling of scoped-commit.sh). The
# verb prose owns the judgment -- which outcome, the gist, whether to complete
# at all; this script owns only the deterministic mutation + refusal facts.
set -euo pipefail

root="${1:?usage: done-entry.sh <root> <id> <outcome> <gist> [<commits>]}"
id="${2:?entry id required}"
outcome="${3:?outcome required (done|dropped|wontfix|drained)}"
gist="${4:?one-line gist required}"
commits="${5:--}"

case "$outcome" in
  done|dropped|wontfix|drained) ;;
  *) echo "FAIL: outcome must be done|dropped|wontfix|drained (got $outcome)" >&2; exit 2 ;;
esac

DIR="$(CDPATH='' cd "$(dirname "$0")" && pwd -P)"

# ---- stamped-root guard (framework scripts stop on an unstamped root) ----
IB="$DIR/../../clankshop/scripts/install-block.sh"
if [ -f "$IB" ]; then
  if ! sh "$IB" read "$root" | grep -q '^stamped=1$'; then
    echo "unstamped=1"; exit 0
  fi
else
  # degraded probe when the pack face's script is unavailable
  if ! grep -qs '^<!-- installation v' "$root/AGENTS.md" "$root/CLAUDE.md"; then
    echo "unstamped=1"; exit 0
  fi
fi

resolve_records_root() {
  local r="$1" fd decl=""
  for fd in "$r/AGENTS.md" "$r/CLAUDE.md"; do
    if [ -z "$decl" ] && [ -f "$fd" ]; then
      decl="$(sed -n 's/^records-root:[[:space:]]*//p' "$fd" | head -n 1 \
              | sed 's/[[:space:]]*$//')"
    fi
  done
  printf '%s\n' "${decl:-.records}"
}

rec_rel="$(resolve_records_root "$root")"
rec="$root/$rec_rel"
trk="$rec/trackers"
log="$rec/done/log.md"
today="$(date +%Y-%m-%d)"

# ---- already completed? (the done log is the completion record) ----
if [ -f "$log" ] && grep -qF "· $id ·" "$log"; then
  echo "refused=completed id=$id"; exit 0
fi

append_log() {
  mkdir -p "$rec/done"
  [ -f "$log" ] || printf '# Done log\n\n' > "$log"
  printf -- '- %s · %s · %s · commits: %s · %s\n' \
    "$today" "$id" "$gist" "$commits" "$outcome" >> "$log"
  echo "logged=1 log=$rec_rel/done/log.md"
}

# ---- flat trackers (T-/I-/F-): entry removed, the log line is the archive ----
flat_done() {  # <file> <entry-prefix-regex>  ("- " bullet or "### " heading)
  local f="$1" lead="$2" line tmp
  line="$(grep -E "^${lead}${id} " "$f" | head -1 || true)"
  if [ -z "$line" ]; then return 1; fi
  if printf '%s' "$line" | grep -qF '[⇧ TK-'; then
    echo "refused=paused id=$id"; exit 0
  fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/done-entry.XXXXXX")"
  if [ "$lead" = "- " ]; then
    awk -v id="$id" '
      !hit && $0 ~ ("^- " id " ") { hit = 1; next }
      { print }
    ' "$f" > "$tmp"
  else
    # heading-led: skip from the entry heading to the next heading of rank <= 3 or EOF
    awk -v id="$id" '
      skip {
        if (substr($0, 1, 1) == "#") {
          n = 0
          while (substr($0, n + 1, 1) == "#") n++
          if (n <= 3 && substr($0, n + 1, 1) == " ") skip = 0
        }
        if (skip) next
      }
      !hit && $0 ~ ("^### " id " ") { hit = 1; skip = 1; next }
      { print }
    ' "$f" > "$tmp"
  fi
  mv "$tmp" "$f"
  echo "mutation=removed entry=$id file=${f#"$root"/}"
  append_log
  exit 0
}

# ---- store dirs (B-/N-): file retained, frontmatter advanced ----
storedir_done() {  # <dir>
  local d="$1" f status paused tmp
  f="$(grep -lE "^id: ${id}$" "$d"/*.md 2>/dev/null | head -1 || true)"
  [ -n "$f" ] || return 1
  paused="$(awk 'NR==1 && $0!="---"{exit} /^---$/ && NR>1 {exit} index($0,"paused: ")==1 {print; exit}' "$f")"
  if [ -n "$paused" ]; then
    echo "refused=paused id=$id"; exit 0
  fi
  status="$(awk 'NR==1 && $0!="---"{exit} /^---$/ && NR>1 {exit} index($0,"status: ")==1 {print substr($0,9); exit}' "$f")"
  if [ "$status" = "resolved" ]; then
    echo "refused=completed id=$id"; exit 0
  fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/done-entry.XXXXXX")"
  awk -v today="$today" '
    NR == 1 { infm = ($0 == "---") }
    infm && NR > 1 && $0 == "---" { infm = 0 }
    infm && index($0, "status: ") == 1  { print "status: resolved"; next }
    infm && index($0, "updated: ") == 1 { print "updated: " today; next }
    { print }
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
  echo "mutation=advanced entry=$id file=${f#"$root"/}"
  append_log
  exit 0
}

case "$id" in
  T-*) [ -f "$trk/tasks.md" ]    && flat_done "$trk/tasks.md" "- "      || true ;;
  I-*) [ -f "$trk/issues.md" ]   && flat_done "$trk/issues.md" "### "   || true ;;
  F-*) [ -f "$trk/feedback.md" ] && flat_done "$trk/feedback.md" "### " || true ;;
  B-*) [ -d "$trk/bugs" ]        && storedir_done "$trk/bugs"           || true ;;
  N-*) [ -d "$trk/notes" ]       && storedir_done "$trk/notes"          || true ;;
  *) echo "FAIL: unrecognized id prefix: $id (T-/I-/F-/B-/N-)" >&2; exit 2 ;;
esac

echo "refused=absent id=$id"
