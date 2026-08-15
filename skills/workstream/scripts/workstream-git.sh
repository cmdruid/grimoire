#!/usr/bin/env bash
# workstream-git.sh <subcommand> [args...]
#
# State-analysis harness for the /workstream skill. Each subcommand does
# deterministic, READ-ONLY inspection of a worktree/repo and emits compact
# `key=value` facts (plus evidence blocks) for the agent to reason over --
# token-free, so the agent spends turns deciding, not probing.
#
# DOCTRINE: facts, not verdicts. No subcommand recommends a gate or a landing
# action; it reports the variables the SKILL.md truth tables consume. The agent
# layers on session state the script cannot see (e.g. "I already gated this tip
# this turn"). A stale or wrong recommendation would be worse than none, so we
# emit none.
#
# All subcommands use `git -C <path>` and never mutate. One stable entrypoint so
# a prefix-matching approval policy can permit the whole harness with a single
# rule -- the worktree path that would otherwise vary per stream lives in an
# argument, not the program name.
set -euo pipefail

# Front-door variable `records-root` (default `.records`) -- see the
# front-door-variables doctrine. Prints the resolved repo-relative path.
resolve_records_root() {
  local root="$1" fd decl=""
  for fd in "$root/AGENTS.md" "$root/CLAUDE.md"; do
    if [ -z "$decl" ] && [ -f "$fd" ]; then
      decl="$(sed -n 's/^records-root:[[:space:]]*//p' "$fd" | head -n 1 \
              | sed 's/[[:space:]]*$//')"
    fi
  done
  printf '%s\n' "${decl:-.records}"
}

usage() {
  cat >&2 <<'EOF'
usage: workstream-git.sh <subcommand> [args...]

  stream-state     <worktree> <branch> <target>          launch/load snapshot
  gate-facts       <worktree> <branch> <target> [<pre-rebase-base>]
                                                          markdown gate truth table
  land-readiness   <root> <worktree> <branch> <target>   ship/land snapshot
  cheatsheet-check <worktree> [<handoff>]                 cheat-sheet pointer drift
  inplace-scan     <root>                                 in-place streams present?
  inplace-state    <root> <stream> <branch> <target>     custody facts (in-place)

Each prints `key=value` facts then (where useful) evidence lists. Read-only;
emits no recommendation -- the agent maps facts to action via SKILL.md.
EOF
}

# bool <non-empty-string-test>: echo true/false from a command's success.
emit_bool() { if "$@" >/dev/null 2>&1; then echo true; else echo false; fi; }

# Refuse malformed/option-shaped ref names up front: a ref starting with `-`
# would parse as a git option, and `..` inside a name breaks range syntax.
validate_ref() {
  git check-ref-format --branch "$1" >/dev/null 2>&1 \
    || { echo "workstream-git.sh: invalid ref name: $1" >&2; exit 2; }
}

# classify_paths: read a newline list of paths on stdin, echo one of
# empty | docs | build.  docs == every path ends in `.md` (the markdown-only
# rule -- anything else, including *.ron data, is build-relevant by design).
classify_paths() {
  local f any=0 nonmd=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    any=1
    case "$f" in
      *.md) ;;
      *) nonmd=1 ;;
    esac
  done
  if [ "$any" -eq 0 ]; then echo empty
  elif [ "$nonmd" -eq 1 ]; then echo build
  else echo docs; fi
}

cmd_stream_state() {
  [ "$#" -eq 3 ] || { echo "usage: workstream-git.sh stream-state <worktree> <branch> <target>" >&2; exit 2; }
  local wt="$1" branch="$2" target="$3"
  validate_ref "$branch"; validate_ref "$target"

  local head_branch toplevel porcelain ahead behind drafts last_subj last_age rec_rel rec_re
  local staged rebase_ip gp
  rec_rel="$(resolve_records_root "$wt")"
  rec_re="${rec_rel//./\\.}"
  head_branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  toplevel="$(git -C "$wt" rev-parse --show-toplevel)"
  porcelain="$(git -C "$wt" status --porcelain)"
  staged="$(git -C "$wt" diff --cached --name-only)"
  # A rebase-in-progress leaves rebase-merge/ or rebase-apply/ under the git dir
  # (linked worktrees: rev-parse resolves into the common dir's worktrees/ area).
  rebase_ip=false
  for gp in rebase-merge rebase-apply; do
    gp="$(git -C "$wt" rev-parse --git-path "$gp")"
    case "$gp" in /*) ;; *) gp="$wt/$gp" ;; esac
    [ -d "$gp" ] && rebase_ip=true
  done
  behind="$(git -C "$wt" rev-list --count "$branch..$target")"
  ahead="$(git -C "$wt" rev-list --count "$target..$branch")"
  last_subj="$(git -C "$wt" log -1 --format='%s')"
  last_age="$(git -C "$wt" log -1 --format='%cr')"

  # Untracked plan drafts (e.g. ship's next-plan draft) are EXPECTED dirt, not
  # WIP -- separate them so the agent doesn't read a drafted plan as unsaved work.
  drafts="$(printf '%s\n' "$porcelain" | sed -n "s#^?? \($rec_re/plans/.*\.md\)\$#\1#p" | grep -v '/archive/' | paste -sd, - || true)"
  [ -z "$drafts" ] && drafts="none"
  # Real WIP = any porcelain line that is NOT an untracked TOP-LEVEL .records/plans
  # draft (the same set `drafts` reports). An untracked file under
  # .records/plans/archive/ (or deeper) is real WIP, not a draft -- it must surface in
  # wip_tracked rather than as dirt no fact explains.
  local wip
  wip="$(printf '%s\n' "$porcelain" | grep -v '^$' | grep -vE "^\?\? $rec_re/plans/[^/]+\.md\$" || true)"

  echo "records-root=$rec_rel"
  echo "branch_matches=$([ "$head_branch" = "$branch" ] && echo true || echo false)"
  echo "toplevel_matches=$([ "$toplevel" = "$wt" ] && echo true || echo false)"
  echo "behind=$behind"            # commits on <target> the branch lacks -> sync due if >0
  echo "ahead=$ahead"              # unshipped commits on the branch
  echo "dirty=$([ -n "$porcelain" ] && echo true || echo false)"
  echo "wip_tracked=$([ -n "$wip" ] && echo true || echo false)"  # real uncommitted edits
  # Staged-but-uncommitted entries are the strand signature of a `git mv` whose
  # pathspec-scoped commit named only one half -- the gate reads the working
  # tree, so only this fact surfaces it before a ship carries it wrong.
  echo "staged_uncommitted=$([ -n "$staged" ] && echo true || echo false)"
  if [ -n "$staged" ]; then
    echo "staged_paths:"
    printf '%s\n' "$staged" | sed 's/^/  /'
  fi
  echo "rebase_in_progress=$rebase_ip"  # true => an interrupted rebase holds the tree
  # A tree carrying its own top-level hand-off must not ALSO contain a nested
  # .workstreams/ -- that is the corruption signature of a save that resolved the
  # hand-off's root-relative address against the worktree (stray stale copy).
  echo "nested_stray_handoff=$([ -f "$wt/WORKSTREAM.md" ] && [ -e "$wt/.workstreams" ] && echo true || echo false)"
  echo "drafted_next_plan=$drafts"
  echo "last_commit=$last_subj"
  echo "last_commit_age=$last_age"
}

cmd_gate_facts() {
  [ "$#" -eq 3 ] || [ "$#" -eq 4 ] || { echo "usage: workstream-git.sh gate-facts <worktree> <branch> <target> [<pre-rebase-base>]" >&2; exit 2; }
  local wt="$1" branch="$2" target="$3" prebase="${4:-}"
  validate_ref "$branch"; validate_ref "$target"

  local base own_files inc_files own_class inc_class inc_base
  base="$(git -C "$wt" merge-base "$branch" "$target")"
  # The incoming axis answers "what did <target> gain since the branch's base?"
  # -- but a completed rebase MOVES the merge-base onto <target>'s tip, so
  # computed post-rebase from the current base the axis is vacuously empty:
  # exactly when the gate matrix needs it most (4 recurrences across 4 streams).
  # The caller threads the PRE-rebase base it captured before rebasing
  # (verbs/sync.md step 2's BASE) as the optional 4th arg; the fact is then true
  # across the rebase it gates. `incoming_base=` reports which mode computed it.
  if [ -n "$prebase" ]; then
    git -C "$wt" rev-parse --verify --quiet "$prebase^{commit}" >/dev/null \
      || { echo "workstream-git.sh: pre-rebase-base does not resolve to a commit: $prebase" >&2; exit 2; }
    inc_base="$prebase"
    echo "incoming_base=given"
  else
    inc_base="$base"
    echo "incoming_base=merge-base"
  fi
  # own diff: triple-dot == changes on <branch> since the merge-base (your work).
  own_files="$(git -C "$wt" diff --name-only "$target...$branch")"
  # incoming diff: what <target> gained since the (pre-rebase, when given) base.
  inc_files="$(git -C "$wt" diff --name-only "$inc_base..$target")"

  own_class="$(printf '%s\n' "$own_files" | classify_paths)"
  inc_class="$(printf '%s\n' "$inc_files" | classify_paths)"

  echo "own_empty=$([ "$own_class" = empty ] && echo true || echo false)"
  echo "own_docs_only=$([ "$own_class" = docs ] && echo true || echo false)"
  echo "incoming_empty=$([ "$inc_class" = empty ] && echo true || echo false)"
  echo "incoming_docs_only=$([ "$inc_class" = docs ] && echo true || echo false)"
  echo "own_files:"
  if [ -n "$own_files" ]; then printf '%s\n' "$own_files" | sed 's/^/  /'; else echo "  (none)"; fi
  echo "incoming_files:"
  if [ -n "$inc_files" ]; then printf '%s\n' "$inc_files" | sed 's/^/  /'; else echo "  (none)"; fi
}

cmd_land_readiness() {
  [ "$#" -eq 4 ] || { echo "usage: workstream-git.sh land-readiness <root> <worktree> <branch> <target>" >&2; exit 2; }
  local root="$1" wt="$2" branch="$3" target="$4"
  validate_ref "$branch"; validate_ref "$target"

  local root_branch root_porcelain behind ahead wt_staged root_dirty_list own_sorted overlap
  root_branch="$(git -C "$root" rev-parse --abbrev-ref HEAD)"
  root_porcelain="$(git -C "$root" status --porcelain)"
  behind="$(git -C "$wt" rev-list --count "$branch..$target")"
  ahead="$(git -C "$wt" rev-list --count "$target..$branch")"
  wt_staged="$(git -C "$wt" diff --cached --name-only)"

  # Dirty-overlap split: `merge --ff-only` (the root_on_target landing path)
  # aborts only when a dirty root path OVERLAPS the merge's changed set -- a
  # sibling's DISJOINT WIP does not block the land (and the by-ref advance never
  # touches the tree at all). One boolean forced a round-trip on provably safe
  # lands; the split lets the doctrine key on overlap only.
  root_dirty_list="$( { git -C "$root" diff --name-only; \
                        git -C "$root" diff --cached --name-only; \
                        git -C "$root" ls-files --others --exclude-standard; } | sort -u )"
  own_sorted="$(git -C "$wt" diff --name-only "$target...$branch" | sort -u)"
  overlap="$(comm -12 <(printf '%s\n' "$root_dirty_list") <(printf '%s\n' "$own_sorted") | grep -v '^$' || true)"

  echo "root_on_target=$([ "$root_branch" = "$target" ] && echo true || echo false)"
  echo "root_dirty=$([ -n "$root_porcelain" ] && echo true || echo false)"
  echo "root_dirty_overlapping=$([ -n "$overlap" ] && echo true || echo false)"
  if [ -n "$overlap" ]; then
    echo "root_dirty_overlap_paths:"
    printf '%s\n' "$overlap" | sed 's/^/  /'
  fi
  # Staged-but-uncommitted entries in the WORKTREE index (the git-mv strand
  # signature) -- resolve before landing; the gate reads the tree, not the index.
  echo "staged_uncommitted=$([ -n "$wt_staged" ] && echo true || echo false)"
  if [ -n "$wt_staged" ]; then
    echo "staged_paths:"
    printf '%s\n' "$wt_staged" | sed 's/^/  /'
  fi
  echo "behind=$behind"   # >0 => <target> moved; must sync before the ff-advance
  echo "ahead=$ahead"
  echo "ff_safe=$([ "$behind" -eq 0 ] && echo true || echo false)"  # branch can ff-advance <target>

  # Conflict forecast: will integrating <target> collide, and where? Read-only --
  # `merge-tree --write-tree` writes only loose objects, never the working tree,
  # index, or refs. A FORECAST, not a verdict: merge-tree models a MERGE while sync
  # does a REBASE, so the set can differ slightly; the real rebase is truth. Keyed
  # off `behind` so a no-op sync skips the probe.
  if [ "$behind" -eq 0 ]; then
    echo "will_conflict=false"   # <target> is an ancestor -- nothing to integrate
  else
    # Capture rc without tripping `set -e` (a conflict is exit 1, not a script error).
    local mt_out mt_rc
    mt_out="$(git -C "$wt" merge-tree --write-tree --name-only "$branch" "$target" 2>/dev/null)" && mt_rc=0 || mt_rc=$?
    case "$mt_rc" in
      0) echo "will_conflict=false" ;;
      1) echo "will_conflict=true"
         echo "conflict_files:"
         # output is <merged-tree-oid>, then conflicted paths, then a blank line + info
         # messages. Print lines 2..(first blank), reading all input (no early exit ->
         # no SIGPIPE under pipefail).
         printf '%s\n' "$mt_out" | awk 'NR==1{next} /^$/{d=1} !d{print}' | sed 's/^/  /' ;;
      *) echo "will_conflict=unknown" ;;  # merge-tree --write-tree unsupported (git <2.38) -- fail open
    esac
  fi

  if [ -n "$root_porcelain" ]; then
    echo "root_dirty_paths:"
    printf '%s\n' "$root_porcelain" | sed 's/^/  /'
  fi
}

# cheatsheet-check parses the hand-off's cheat-sheet pointers and flags any path
# that no longer resolves at the worktree HEAD -- token-free drift detection so a
# stale orientation map can't quietly mislead a resuming agent.
cmd_cheatsheet_check() {
  [ "$#" -eq 1 ] || [ "$#" -eq 2 ] || { echo "usage: workstream-git.sh cheatsheet-check <worktree> [<handoff>]" >&2; exit 2; }
  local wt="$1" handoff="${2:-$1/WORKSTREAM.md}"
  [ -f "$handoff" ] || { echo "no_handoff=true"; exit 0; }

  # Extract the `## Cheat sheet` section, pull every backticked `path/like/this`
  # token that looks like a repo path, and test existence relative to the worktree.
  # A checkable ref must be a SINGLE bare path (optionally `:line`/`#anchor`): the
  # shape gate rejects tokens with spaces, commas, flags, or `...` elisions --
  # cheat sheets legitimately mix command lines with paths, and a command string
  # is not a checkable ref (it false-positives as "stale").
  local section refs total=0 stale=0 r
  section="$(awk '/^## Cheat sheet/{f=1;next} /^## /{f=0} f' "$handoff")"
  # shellcheck disable=SC2016  # literal backticks are intentional (markdown code spans)
  refs="$(printf '%s\n' "$section" \
    | grep -oE '`[^`]+`' \
    | tr -d '`' \
    | grep -E '^[A-Za-z0-9._/-]+(:[0-9]+)?(#[A-Za-z0-9_-]+)?$' \
    | grep -vE '\.\.\.' \
    | grep -E '/|\.[a-z0-9]{1,5}$' \
    | sed -E 's/[:#].*$//' \
    | sort -u || true)"

  echo "stale_refs:"
  while IFS= read -r r; do
    [ -z "$r" ] && continue
    total=$((total + 1))
    # An absolute pointer (the discipline's absolute-worktree-path form) is
    # tested directly; only relative refs resolve against the worktree.
    local p
    case "$r" in /*) p="$r" ;; *) p="$wt/$r" ;; esac
    if [ ! -e "$p" ]; then
      stale=$((stale + 1))
      echo "  $r"
    fi
  done <<< "$refs"
  [ "$stale" -eq 0 ] && echo "  (none)"
  echo "checked=$total"
  echo "stale=$stale"
}

# inplace-scan: which streams (if any) record in-place isolation? The tree is
# singular, so create --in-place refuses when this is non-empty.
cmd_inplace_scan() {
  [ "$#" -eq 1 ] || { echo "usage: workstream-git.sh inplace-scan <root>" >&2; exit 2; }
  local root="$1" f name found=""
  for f in "$root"/.workstreams/*/WORKSTREAM.md; do
    [ -f "$f" ] || continue
    if grep -qE '^- isolation: *in-place' "$f"; then
      name="$(basename "$(dirname "$f")")"
      found="${found:+$found,}$name"
    fi
  done
  echo "inplace_streams=${found:-none}"
}

# inplace-state: custody facts for an in-place stream. The agent classifies
# held/parked/foreign from these (verbs/park.md, load.md) -- the script only
# reports what git and the hand-off say.
cmd_inplace_state() {
  [ "$#" -eq 4 ] || { echo "usage: workstream-git.sh inplace-state <root> <stream> <branch> <target>" >&2; exit 2; }
  local root="$1" stream="$2" branch="$3" target="$4"
  validate_ref "$branch"; validate_ref "$target"
  local handoff="$root/.workstreams/$stream/WORKSTREAM.md"

  local head_branch porcelain behind ahead top_subj
  head_branch="$(git -C "$root" rev-parse --abbrev-ref HEAD)"
  porcelain="$(git -C "$root" status --porcelain)"
  behind="$(git -C "$root" rev-list --count "$branch..$target")"
  ahead="$(git -C "$root" rev-list --count "$target..$branch")"
  top_subj="$(git -C "$root" log -1 --format='%s' "$branch")"

  echo "head_branch=$head_branch"
  echo "on_stream_branch=$([ "$head_branch" = "$branch" ] && echo true || echo false)"
  echo "on_target=$([ "$head_branch" = "$target" ] && echo true || echo false)"
  if [ -f "$handoff" ]; then
    echo "handoff_parked=$(grep -qE '^Parked: *true' "$handoff" && echo true || echo false)"
  else
    echo "handoff_parked=unknown"
  fi
  # printf + bare case, NOT case-inside-$(...): bash 3.2's parser (macOS /bin/bash)
  # breaks on the unescaped ')' in a case-pattern nested in a quoted $(...).
  printf "top_wip="
  case "$top_subj" in wip:*) echo true ;; *) echo false ;; esac
  echo "dirty=$([ -n "$porcelain" ] && echo true || echo false)"
  echo "behind=$behind"
  echo "ahead=$ahead"
}

main() {
  [ "$#" -ge 1 ] || { usage; exit 2; }
  local sub="$1"; shift
  case "$sub" in
    -h|--help|help) usage ;;
    stream-state)     cmd_stream_state "$@" ;;
    gate-facts)       cmd_gate_facts "$@" ;;
    land-readiness)   cmd_land_readiness "$@" ;;
    cheatsheet-check) cmd_cheatsheet_check "$@" ;;
    inplace-scan)     cmd_inplace_scan "$@" ;;
    inplace-state)    cmd_inplace_state "$@" ;;
    *) echo "unknown subcommand: $sub" >&2; usage; exit 2 ;;
  esac
}

main "$@"
