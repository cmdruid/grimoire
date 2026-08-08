#!/bin/sh
# mirror-test.sh -- the mirror failure matrix (plan Task 2.3): duplicate retry, crash
# between create and commit, worktree-sync refusal, mid-sync comment, edited + deleted
# comment drift, concurrent-sync lock contention, duplicate stamped-issue adoption.
# The provider is a local mock implementing the frozen provider contract -- no live
# GitHub in the gate. Fixture instances are temp-dir-local and destroyed.
set -eu
DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd -P)
. "$DIR/lib.sh"
pass=0; fail=0   # re-assigned by lib.sh's helpers (shellcheck cannot follow the source)
CLANKSHOP_SCRIPTS=$(CDPATH='' cd "$DIR/.." && pwd -P)
BACKLOG_SCRIPTS=$(CDPATH='' cd "$DIR/../../../backlog/scripts" && pwd -P)

TMP=$(mktemp -d "${TMPDIR:-/tmp}/clankshop-mirror.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
TODAY=$(date +%Y-%m-%d)

# ---- the mock provider (the frozen contract, state in a local dir) ----
STATE="$TMP/provider"
mkdir -p "$STATE/issues" "$STATE/comments"
echo 1 > "$STATE/next"
cat > "$TMP/mock-provider" <<'MOCK'
#!/bin/sh
set -eu
STATE="${MOCK_STATE:?}"
sub="$1"; shift
case "$sub" in
  present) exit 0 ;;
  list)
    for d in "$STATE/issues"/*/; do
      [ -d "$d" ] || continue
      n=$(basename "$d")
      t=$(sed -n 's/^mirrored-from: //p' "$d/body" 2>/dev/null | head -1)
      printf '%s %s\n' "$n" "${t:--}"
    done ;;
  create)
    n=$(cat "$STATE/next"); echo $((n + 1)) > "$STATE/next"
    mkdir -p "$STATE/issues/$n"
    cp "$2" "$STATE/issues/$n/title"; cp "$3" "$STATE/issues/$n/body"
    echo "$1" > "$STATE/issues/$n/label"
    echo "$n" >> "$STATE/create.log"
    echo "$n" ;;
  update)
    cp "$3" "$STATE/issues/$1/title"; cp "$4" "$STATE/issues/$1/body"
    echo "$2" > "$STATE/issues/$1/label" ;;
  comments)
    d="$STATE/comments/$1"
    [ -d "$d" ] || exit 0
    for c in "$d"/*.body; do
      [ -f "$c" ] || continue
      cid=$(basename "$c" .body)
      upd=$(cat "$d/$cid.updated")
      printf '%s\t%s\t%s\n' "$cid" "$upd" "$(base64 < "$c" | tr -d '\n')"
    done ;;
esac
MOCK
chmod +x "$TMP/mock-provider"
export MOCK_STATE="$STATE"
SYNC() { sh "$BACKLOG_SCRIPTS/mirror-sync.sh" "$1" --provider "$TMP/mock-provider" --session test > "$TMP/out" 2>&1 || true; }

# ---- project fixture ----
R="$TMP/proj"
mkdir -p "$R/.records/tickets"
( cd "$R" && git init -q . && git config user.email t@e.st && git config user.name t )
printf '# Front door\n' > "$R/AGENTS.md"
sh "$CLANKSHOP_SCRIPTS/install-block.sh" write "$R" 1 clankshop 1 > /dev/null
( cd "$R" && git add -A && git commit -qm seed )

mkticket() {  # mkticket <slug> <subject>
  cat > "$R/.records/tickets/$TODAY-$1.md" <<EOF
---
type: ticket
id: TK-$TODAY-$1
status: open
subject_kind: issue
updated: $TODAY
---

# TK-$TODAY-$1 — $2

## Context

body of $1.

## Decision needed

pick one.

## Comments

## Resolution
EOF
  ( cd "$R" && git add -- ".records/tickets/$TODAY-$1.md" \
    && git commit -qm "Ticket TK-$TODAY-$1" -- ".records/tickets/$TODAY-$1.md" )
}

# ---- create + stamped block committed; duplicate retry is a no-op ----
mkticket alpha "first ticket"
SYNC "$R"
expect "fresh ticket creates its issue" "created=TK-$TODAY-alpha:1" "$TMP/out"
expect "mirror block stamped" "issue: 1" "$R/.records/tickets/$TODAY-alpha.md"
expect "pushed_hash stamped" "pushed_hash: " "$R/.records/tickets/$TODAY-alpha.md"
SYNC "$R"
expect "second sync is unchanged" "unchanged=TK-$TODAY-alpha" "$TMP/out"
expect_eq "no duplicate create on retry" "1" "$(wc -l < "$STATE/create.log" | tr -d ' ')"

# ---- crash between create and commit: the adoption scan heals, no duplicate ----
mkticket beta "second ticket"
SYNC "$R"
expect "beta created" "created=TK-$TODAY-beta:2" "$TMP/out"
( cd "$R" && git checkout -q HEAD~1 -- ".records/tickets/$TODAY-beta.md" )   # lose the block write
SYNC "$R"
expect "orphan issue adopted, not re-created" "adopted=TK-$TODAY-beta:2" "$TMP/out"
expect "adoption re-pushes the canonical body" "pushed=TK-$TODAY-beta:2" "$TMP/out"
expect_eq "still exactly two creates" "2" "$(wc -l < "$STATE/create.log" | tr -d ' ')"

# ---- duplicate stamped-issue adoption: lowest wins, extras flagged ----
for n in 7 8; do
  mkdir -p "$STATE/issues/$n"
  printf 'TK-%s-gamma — dup\n' "$TODAY" > "$STATE/issues/$n/title"
  printf 'stale body\n\nmirrored-from: TK-%s-gamma\n' "$TODAY" > "$STATE/issues/$n/body"
  echo clankshop-ticket > "$STATE/issues/$n/label"
done
mkticket gamma "third ticket"
SYNC "$R"
expect "lowest duplicate adopted" "adopted=TK-$TODAY-gamma:7" "$TMP/out"
expect "extra duplicate flagged" "adoption-extras=TK-$TODAY-gamma:8" "$TMP/out"

# ---- push on hash change only ----
sed -i '' 's/pick one\./pick one, urgently./' "$R/.records/tickets/$TODAY-alpha.md"
SYNC "$R"
expect "content change pushes" "pushed=TK-$TODAY-alpha:1" "$TMP/out"
expect "remote body updated" "pick one, urgently." "$STATE/issues/1/body"
SYNC "$R"
expect "then quiescent again" "unchanged=TK-$TODAY-alpha" "$TMP/out"

# ---- pull: import, idempotency, mid-sync comment on the next pass ----
mkdir -p "$STATE/comments/1"
printf 'use the fast gate' > "$STATE/comments/1/101.body"
printf '2026-08-07T10:00Z' > "$STATE/comments/1/101.updated"
SYNC "$R"
expect "comment imported" "comments-imported=TK-$TODAY-alpha:1" "$TMP/out"
expect "comment body in the file" "use the fast gate" "$R/.records/tickets/$TODAY-alpha.md"
expect "comment recorded with its remote ID" "{id: 101, updated: 2026-08-07T10:00Z, hash: " "$R/.records/tickets/$TODAY-alpha.md"
printf 'second thought' > "$STATE/comments/1/102.body"     # arrives after that pass
printf '2026-08-07T11:00Z' > "$STATE/comments/1/102.updated"
SYNC "$R"
expect "mid-sync comment lands on the next pass" "comments-imported=TK-$TODAY-alpha:1" "$TMP/out"
expect_eq "first comment not re-imported" "1" "$(grep -c 'use the fast gate' "$R/.records/tickets/$TODAY-alpha.md")"

# ---- edited + deleted comment drift: facts, file wins, record persists ----
printf 'use the SLOW gate' > "$STATE/comments/1/101.body"
rm "$STATE/comments/1/102.body" "$STATE/comments/1/102.updated"
SYNC "$R"
expect "edited comment drift fact" "comment-edited=TK-$TODAY-alpha:101" "$TMP/out"
expect "deleted comment drift fact" "comment-deleted=TK-$TODAY-alpha:102" "$TMP/out"
expect "file's imported copy wins" "use the fast gate" "$R/.records/tickets/$TODAY-alpha.md"
SYNC "$R"
expect "deleted-drift record persists across syncs" "comment-deleted=TK-$TODAY-alpha:102" "$TMP/out"

# ---- concurrent-sync lock contention; stale takeover ----
mkdir -p "$R/.records/tickets/.sync-lock"
printf 'owner=999@other\nacquired=%s\n' "$(date +%s)" > "$R/.records/tickets/.sync-lock/owner"
SYNC "$R"
expect "live lock refuses" "lock-held=999@other" "$TMP/out"
printf 'owner=999@other\nacquired=1\n' > "$R/.records/tickets/.sync-lock/owner"
SYNC "$R"
expect "stale lock taken over, logged" "lock-takeover=999@other" "$TMP/out"
expect "lock exclusion written" ".records/tickets/.sync-lock/" "$R/.git/info/exclude"

# ---- worktree-sync refusal ----
( cd "$R" && git worktree add -q "$TMP/wt" -b wt-branch )
SYNC "$TMP/wt"
expect "linked worktree refuses" "refused=worktree" "$TMP/out"

# ---- degradation: no provider flag, no remote -> absent, no behavior change ----
sh "$BACKLOG_SCRIPTS/mirror-sync.sh" "$R" --session test > "$TMP/out" 2>&1 || true
expect "no remote degrades silently" "mirror=absent" "$TMP/out"

echo "mirror: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
