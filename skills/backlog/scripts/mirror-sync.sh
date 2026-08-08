#!/usr/bin/env bash
# mirror-sync.sh <root> [--provider <cmd>] [--label <label>] [--session <name>]
#
# The ticket-mirror sync, per the mirror protocol (the installation's
# `.handbook/rules/RECORDS.md` names the schema; the protocol is frozen in the
# pack doctrine): the in-repo ticket file is CANONICAL; the mirror is a stamped
# projection with drift facts -- never the reverse.
#
#   push  -- canonical projection (body minus `## Comments`, plus projected
#            header fields id/status/subject_kind/origin/title; `mirror:` block
#            and `updated:` excluded) hashed; pushed only when the hash differs
#            from the stamped `pushed_hash`. Title = ticket ID + subject; label
#            = status; body carries a `mirrored-from: <TK-id>` footer. Comments
#            never round-trip into the body.
#   pull  -- FULL comment inventory every sync, keyed by immutable remote
#            comment ID (the idempotency key), appended to `## Comments` in
#            remote-ID order and recorded in `mirror.comments` with `updated` +
#            content hash. A known ID whose content changed -> edited-comment
#            drift fact; a known ID absent -> deleted-comment drift fact. The
#            file wins -- imported copies are never rewritten.
#   create-- idempotent: scan the provider's issues by the framework label for
#            one whose footer names this ticket; adopt the LOWEST issue number
#            (extras flagged), else create -- then commit the `mirror:` block.
#            A crash between create and commit heals on the next sync (the
#            adoption scan finds the orphan issue).
#   lock  -- `.records/tickets/.sync-lock` via atomic mkdir; payload names the
#            owner (pid + session) + acquisition time; stale after 10 minutes
#            with the takeover logged; removed on completion; git-excluded
#            (this script writes the exclusion idempotently).
#   guard -- trunk-only: a linked worktree refuses. Verb-time only -- never a
#            daemon. No remote / no issue system -> `mirror=absent`, no
#            behavior change, no `mirror:` block.
#
# Provider contract (a command implementing these subcommands; immutable
# comment IDs with a total order, a comment list + updated timestamps -- or no
# mirror). The default is the GitHub adapter below (gh CLI); tests inject a
# mock via --provider:
#   present                       exit 0 iff an issue system is reachable
#   list <label>                  one line per issue: "<number> <ticket-id-or-->"
#   create <label> <title-file> <body-file>    prints the new issue number
#   update <number> <label> <title-file> <body-file>
#   comments <number>             one line per comment: "<id>\t<updated>\t<base64-body>"
#
# DOCTRINE: a mutating mechanical helper. Facts only on stdout; the sync verb
# owns the judgment (whether to sync, what a drift fact means).
set -euo pipefail

root="${1:?usage: mirror-sync.sh <root> [--provider <cmd>] [--label <label>] [--session <name>]}"
shift
provider=""; label="clankshop-ticket"; session="cli"
while [ $# -gt 0 ]; do
  case "$1" in
    --provider) provider="$2"; shift ;;
    --label)    label="$2"; shift ;;
    --session)  session="$2"; shift ;;
    *) echo "FAIL: unknown arg $1" >&2; exit 2 ;;
  esac
  shift
done

DIR="$(CDPATH='' cd "$(dirname "$0")" && pwd -P)"

# ---- stamped-root guard ----
IB="$DIR/../../clankshop/scripts/install-block.sh"
if [ -f "$IB" ] && ! sh "$IB" read "$root" | grep -q '^stamped=1$'; then
  echo "unstamped=1"; exit 0
fi

# ---- trunk-only: a linked worktree refuses ----
gd="$(git -C "$root" rev-parse --git-dir 2>/dev/null || true)"
gcd="$(git -C "$root" rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "$gd" ] && [ "$gd" != "$gcd" ]; then
  echo "refused=worktree"; exit 0
fi

# ---- degradation: no remote / no issue system -> no behavior change ----
gh_provider() {  # the default GitHub adapter (gh CLI); untested paths stay thin
  sub="$1"; shift
  case "$sub" in
    present) command -v gh >/dev/null && gh repo view >/dev/null 2>&1 ;;
    list)
      gh issue list --label "$1" --state all --json number,body --jq \
        '.[] | "\(.number) \((.body | capture("mirrored-from: (?<t>TK-[A-Za-z0-9-]+)").t) // "-")"' ;;
    create) gh issue create --label "$1" --title "$(cat "$2")" --body-file "$3" \
              | grep -oE '[0-9]+$' ;;
    update) gh issue edit "$1" --title "$(cat "$3")" --body-file "$4" >/dev/null ;;
    comments)
      gh api "repos/{owner}/{repo}/issues/$1/comments" --jq \
        '.[] | "\(.id)\t\(.updated_at)\t\(.body | @base64)"' ;;
  esac
}
prov() { if [ -n "$provider" ]; then "$provider" "$@"; else gh_provider "$@"; fi; }

if [ -z "$provider" ] && ! git -C "$root" remote 2>/dev/null | grep -q .; then
  echo "mirror=absent"; exit 0
fi
if ! prov present; then
  echo "mirror=absent"; exit 0
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
rec_rel="$(resolve_records_root "$root")"
tdir="$root/$rec_rel/tickets"
[ -d "$tdir" ] || { echo "tickets=0"; exit 0; }

# ---- the sync lock (atomic mkdir; 10-minute staleness with logged takeover) ----
lock="$tdir/.sync-lock"
now="$(date +%s)"
excl="$root/.git/info/exclude"
if [ -d "$root/.git" ] || [ -f "$root/.git" ]; then
  mkdir -p "$(dirname "$excl")"
  grep -qsF "$rec_rel/tickets/.sync-lock/" "$excl" 2>/dev/null \
    || echo "$rec_rel/tickets/.sync-lock/" >> "$excl"
fi
if ! mkdir "$lock" 2>/dev/null; then
  held_owner="$(sed -n 's/^owner=//p' "$lock/owner" 2>/dev/null || true)"
  held_at="$(sed -n 's/^acquired=//p' "$lock/owner" 2>/dev/null || echo 0)"
  if [ $((now - held_at)) -gt 600 ]; then
    echo "lock-takeover=${held_owner:-unknown}"
  else
    echo "lock-held=${held_owner:-unknown}"; exit 0
  fi
fi
printf 'owner=%s@%s\nacquired=%s\n' "$$" "$session" "$now" > "$lock/owner"
trap 'rm -rf "$lock"' EXIT

TMP="$(mktemp -d "${TMPDIR:-/tmp}/mirror-sync.XXXXXX")"
trap 'rm -rf "$TMP" "$lock"' EXIT

hash12() { shasum -a 256 | cut -c1-12; }

fm() {  # fm <file> <key> -- top-level frontmatter value
  awk -v k="$2" '
    NR == 1 { if ($0 != "---") exit; next }
    /^---$/ { exit }
    index($0, k ": ") == 1 { print substr($0, length(k) + 3); exit }
  ' "$1"
}
mirror_kv() {  # mirror_kv <file> <key> -- indented key under mirror:
  awk -v k="$2" '
    NR == 1 { if ($0 != "---") exit; next }
    /^---$/ { exit }
    /^mirror:/ { inm = 1; next }
    inm && /^[^ ]/ { exit }
    inm && index($0, "  " k ": ") == 1 { print substr($0, length(k) + 5); exit }
  ' "$1"
}
known_comments() {  # known_comments <file> -> "id updated hash" per line
  awk '
    NR == 1 { if ($0 != "---") exit; next }
    /^---$/ { exit }
    /^mirror:/ { inm = 1; next }
    inm && /^[^ ]/ { exit }
    inm && match($0, /\{id: [^,]+, updated: [^,]+, hash: [^}]+\}/) {
      s = substr($0, RSTART + 1, RLENGTH - 2)
      gsub(/id: |updated: |hash: /, "", s); gsub(/,/, "", s)
      print s
    }
  ' "$1"
}

projection() {  # projection <file> <tid> -- the canonical hashed/pushed body
  {
    printf 'id: %s\nstatus: %s\nsubject_kind: %s\norigin: %s\ntitle: %s\n\n' \
      "$2" "$(fm "$1" status)" "$(fm "$1" subject_kind)" \
      "$(fm "$1" origin)" "$(sed -n 's/^# //p' "$1" | head -1)"
    awk '
      NR == 1 && $0 == "---" { infm = 1; next }
      infm { if ($0 == "---") infm = 0; next }
      /^## Comments/ { incom = 1; next }
      incom && /^## / { incom = 0 }
      incom { next }
      { print }
    ' "$1"
  }
}

write_mirror_block() {  # write_mirror_block <file> <issue> <hash> <comments-file>
  local f="$1" issue="$2" ph="$3" cf="$4" tmpf="$TMP/wm"
  awk -v issue="$issue" -v ph="$ph" -v cf="$cf" '
    function emit() {
      print "mirror:"
      print "  provider: mirror"
      print "  issue: " issue
      print "  pushed_hash: " ph
      print "  comments:"
      while ((getline cl < cf) > 0) {
        split(cl, a, " ")
        print "    - {id: " a[1] ", updated: " a[2] ", hash: " a[3] "}"
      }
      close(cf)
    }
    NR == 1 { print; infm = ($0 == "---"); next }
    infm && /^mirror:/ { inm = 1; next }
    inm && /^[ ]/ { next }
    inm { inm = 0 }
    infm && /^updated: / && !done { emit(); done = 1; print; next }
    infm && /^---$/ { if (!done) { emit(); done = 1 }; infm = 0; print; next }
    { print }
  ' "$f" > "$tmpf"
  mv "$tmpf" "$f"
}

commit_ticket() {  # commit_ticket <file> <msg> -- pathspec-scoped, trunk-side
  ( cd "$root" && git add -- "${1#"$root"/}" \
    && git commit -q -m "$2" -- "${1#"$root"/}" ) 2>/dev/null || true
}

# ---- the adoption inventory (one list scan per run) ----
prov list "$label" > "$TMP/issues" || : > "$TMP/issues"

tcount=0
for tf in "$tdir"/*.md; do
  [ -f "$tf" ] || continue
  tcount=$((tcount + 1))
  base="$(basename "$tf" .md)"
  tid="$(fm "$tf" id)"
  [ -n "$tid" ] || { echo "skipped=$base:no-id"; continue; }

  issue="$(mirror_kv "$tf" issue)"
  if [ -z "$issue" ]; then
    # -- idempotent creation: adopt by footer scan (lowest number), else create --
    matches="$(awk -v t="$tid" '$2 == t { print $1 }' "$TMP/issues" | sort -n)"
    if [ -n "$matches" ]; then
      issue="$(printf '%s\n' "$matches" | head -1)"
      extras="$(printf '%s\n' "$matches" | tail -n +2 | paste -sd, -)"
      echo "adopted=$tid:$issue"
      [ -n "$extras" ] && echo "adoption-extras=$tid:$extras"
      # adopted body may predate local edits -- leave the stamp pending so the
      # push-on-hash-change below re-pushes the canonical projection
      ph="adopt-pending"
    else
      printf '%s — %s\n' "$tid" "$(sed -n 's/^# TK-[A-Za-z0-9-]* — //p' "$tf" | head -1)" > "$TMP/title"
      { projection "$tf" "$tid"; printf '\nmirrored-from: %s\n' "$tid"; } > "$TMP/body"
      issue="$(prov create "$label" "$TMP/title" "$TMP/body")"
      echo "created=$tid:$issue"
      ph="$(projection "$tf" "$tid" | hash12)"
    fi
    : > "$TMP/kc"
    write_mirror_block "$tf" "$issue" "$ph" "$TMP/kc"
    commit_ticket "$tf" "Mirror $tid to issue $issue"
  fi

  # -- push on hash change only --
  ph_old="$(mirror_kv "$tf" pushed_hash)"
  ph_new="$(projection "$tf" "$tid" | hash12)"
  known_comments "$tf" > "$TMP/kc"
  if [ "$ph_new" != "$ph_old" ]; then
    printf '%s — %s\n' "$tid" "$(sed -n 's/^# TK-[A-Za-z0-9-]* — //p' "$tf" | head -1)" > "$TMP/title"
    { projection "$tf" "$tid"; printf '\nmirrored-from: %s\n' "$tid"; } > "$TMP/body"
    prov update "$issue" "$label" "$TMP/title" "$TMP/body"
    echo "pushed=$tid:$issue"
    write_mirror_block "$tf" "$issue" "$ph_new" "$TMP/kc"
    commit_ticket "$tf" "Mirror push $tid"
  else
    echo "unchanged=$tid"
  fi

  # -- pull: full inventory, keyed by immutable remote comment ID --
  prov comments "$issue" | sort -n > "$TMP/inv" || : > "$TMP/inv"
  : > "$TMP/kc2"; imported=0
  while IFS="$(printf '\t')" read -r cid cupd cb64; do
    [ -n "$cid" ] || continue
    chash="$(printf '%s' "$cb64" | base64 -d | hash12)"
    krow="$(awk -v c="$cid" '$1 == c { print }' "$TMP/kc")"
    if [ -z "$krow" ]; then
      { printf '\n- [%s @ %s] ' "$cid" "$cupd"; printf '%s' "$cb64" | base64 -d; printf '\n'; } \
        >> "$TMP/newc"
      printf '%s %s %s\n' "$cid" "$cupd" "$chash" >> "$TMP/kc2"
      imported=$((imported + 1))
    else
      khash="$(printf '%s\n' "$krow" | awk '{ print $3 }')"
      [ "$khash" != "$chash" ] && echo "comment-edited=$tid:$cid"
      printf '%s\n' "$krow" >> "$TMP/kc2"
    fi
  done < "$TMP/inv"
  # deleted: known IDs absent from the inventory (the file wins; the record is
  # KEPT in mirror.comments so the drift stays visible on every sync)
  while IFS=' ' read -r kid kupd khash; do
    [ -n "$kid" ] || continue
    if ! awk -v c="$kid" '$1 == c { found = 1 } END { exit !found }' "$TMP/inv"; then
      echo "comment-deleted=$tid:$kid"
      printf '%s %s %s\n' "$kid" "$kupd" "$khash" >> "$TMP/kc2"
    fi
  done < "$TMP/kc"
  if [ "$imported" -gt 0 ]; then
    awk '/^## Comments/ { print; while ((getline l < "'"$TMP/newc"'") > 0) print l; next } { print }' \
      "$tf" > "$TMP/tf" && mv "$TMP/tf" "$tf"
    write_mirror_block "$tf" "$issue" "$ph_new" "$TMP/kc2"
    commit_ticket "$tf" "Mirror pull $tid: $imported comment(s)"
    echo "comments-imported=$tid:$imported"
    rm -f "$TMP/newc"
  fi
done
echo "tickets=$tcount"
