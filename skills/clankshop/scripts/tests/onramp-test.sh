#!/bin/sh
# onramp-test.sh -- the onramp fixtures (plan Tasks 1.8, 5.3): greenfield projection,
# brownfield migration, unstamped refusal, transactional pack install, registration
# stability. Fixture instances live in a temp dir and are destroyed on exit; the real
# doctrine and pack lock are the inputs under test.
set -eu
DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd -P)
CLANKSHOP_SCRIPTS=$(CDPATH='' cd "$DIR/.." && pwd -P)
DOCTRINE=$CLANKSHOP_SCRIPTS/../doctrine
LOCK=$CLANKSHOP_SCRIPTS/../PACK.md
TMP=$(mktemp -d "${TMPDIR:-/tmp}/clankshop-onramp.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0   # re-assigned by lib.sh's helpers (shellcheck cannot follow the source)
# shellcheck source=lib.sh
. "$DIR/lib.sh"

PV=$(sed -n 's/^version:[[:space:]]*//p' "$LOCK" | head -1)
DV=$(awk '/^doctrine-version: /{print $2; exit}' "$DOCTRINE/README.md")

# The installed set = the manifest's members (spec format 1: the pack: face is an
# implicit member; optional: members are default-installed). Stubs keep fixture and
# manifest in sync.
MEMBERS="$(sed -n 's/^pack:[[:space:]]*//p' "$LOCK" | head -1) \
$(sed -n 's/^skills:[[:space:]]*//p' "$LOCK" | head -1) \
$(sed -n 's/^optional:[[:space:]]*//p' "$LOCK" | head -1)"
SKILLS=$TMP/skills
mkdir -p "$SKILLS"
for m in $MEMBERS; do
  mkdir -p "$SKILLS/$m"
  printf -- '---\nname: %s\n---\n' "$m" > "$SKILLS/$m/SKILL.md"
done

# ============ fixture 1: greenfield ============
R=$TMP/green
mkdir -p "$R" && git -C "$R" init -qb main . 2>/dev/null
project_doctrine "$R" "$DOCTRINE" "$SKILLS" "make test" main "$PV"
git -C "$R" add -A && git -C "$R" -c user.email=t@t -c user.name=t commit -qm "greenfield setup"

bash "$CLANKSHOP_SCRIPTS/check-facts.sh" "$R" "$SKILLS" > "$TMP/facts" 2>&1
expect "green: stamped"                "stamped=1" "$TMP/facts"
expect "green: chapters complete"      "chapters_missing=" "$TMP/facts"
for key in handbook_unknown steward_stale unregistered orphaned_registrations \
           registration_stale routing_unresolved lane_missing routing_entry_unresolved \
           ticket_problems ticket_blocking_cycles done_log_inconsistent dup_ids \
           missing_base bump_uncovered lock_missing_installed; do
  expect "green: ${key} empty" "${key}_count=0" "$TMP/facts"
done
expect "green: stores complete"        "stores_missing=" "$TMP/facts"
expect "green: records projection current" "records_projection_version=$DV" "$TMP/facts"

# every seeded entry carries its provenance marker / origin keys
inv_doc=$(grep -cE '^INV-[0-9]+:' "$DOCTRINE/rules/INVARIANTS.md")
inv_marked=$(grep -cE '^INV-[0-9]+:.*⟨clankshop:INV-[0-9]+ @v'"$DV"'⟩' "$R/.handbook/rules/INVARIANTS.md")
expect_eq "green: every INV line marked" "$inv_doc" "$inv_marked"
for sub in workflows testing; do
  for f in "$DOCTRINE/$sub"/*.md; do
    b=$(basename "$f" .md)
    expect "green: $sub/$b origin key" "origin: clankshop:$sub/$b" "$R/.handbook/$sub/$b.md"
    expect "green: $sub/$b origin version" "origin-version: $DV" "$R/.handbook/$sub/$b.md"
  done
done

# every installed member has its door registration block
for m in $MEMBERS; do
  expect "green: $m registered" "<!-- skill:$m BEGIN built-against:" "$R/AGENTS.md"
done

# cold-clone readable: nothing in the handbook points at a skill path or harness home
grep -rEn 'skills/|\.claude|~/' "$R/.handbook" > "$TMP/coldclone" 2>/dev/null || true
expect_eq "green: cold-clone readable (no skill paths in .handbook)" "" "$(cat "$TMP/coldclone")"

# the seeded deployment classifies UNCHANGED across the board (projection == protocol)
bash "$CLANKSHOP_SCRIPTS/doctrine-diff.sh" "$R" gate="make test" trunk=main > "$TMP/diff" 2>&1
states=$(grep -c '^state:' "$TMP/diff" || true)
unchanged=$(grep -c '=unchanged$' "$TMP/diff" || true)
expect_eq "green: every seeded entry unchanged" "$states" "$unchanged"
expect_absent "green: no missing bases in diff" "missing-base=" "$TMP/diff"

# ============ fixture 2: migrate ============
R=$TMP/brown
mkdir -p "$R/docs/decisions"
git -C "$R" init -qb main . 2>/dev/null
printf '# TODO\n- TODO-7: refactor the widget loader\n- TODO-9: write install docs\n' > "$R/TODO.md"
printf '# Rules\nAlways run the linter before any commit.\n' > "$R/docs/RULES.md"
printf '# Use sqlite\nDecided 2020-01-01: sqlite over postgres for embedability.\n' > "$R/docs/decisions/2020-01-01-use-sqlite.md"
git -C "$R" add -A && git -C "$R" -c user.email=t@t -c user.name=t commit -qm "ad-hoc history"

# preconditions: unstamped + clean -> migrate may proceed
bash "$CLANKSHOP_SCRIPTS/migrate-preflight.sh" "$R" > "$TMP/pre" 2>&1
expect "migrate: preflight unstamped" "stamped=0" "$TMP/pre"
expect "migrate: preflight clean"     "tree_clean=1" "$TMP/pre"
expect "migrate: no active streams"   "inplace_streams_count=0" "$TMP/pre"

# execute the confirmed mapping table in a WORKTREE (the mechanical walk of the verb):
#   TODO.md items      -> tasks.md entries, IDs minted, (alias TODO-n) preserved
#   docs/RULES.md      -> a project INVARIANTS entry (no origin marker: not doctrine-seeded)
#   decisions doc      -> .records/adr/ (moved verbatim)
WT=$TMP/brown-wt
git -C "$R" worktree add -q "$WT" -b migrate/clankshop
project_doctrine "$WT" "$DOCTRINE" "$SKILLS" "make lint" main "$PV"
next=$((inv_doc + 1))
printf 'INV-%s: Always run the linter before any commit.\n' "$next" >> "$WT/.handbook/rules/INVARIANTS.md"
{
  printf -- '- T-001 — refactor the widget loader (alias TODO-7) · added 2026-08-07\n'
  printf -- '- T-002 — write install docs (alias TODO-9) · added 2026-08-07\n'
} >> "$WT/.records/trackers/tasks.md"
mkdir -p "$WT/.records/adr"
git -C "$WT" mv docs/decisions/2020-01-01-use-sqlite.md .records/adr/2020-01-01-use-sqlite.md
git -C "$WT" rm -q TODO.md docs/RULES.md
git -C "$WT" add -A && git -C "$WT" -c user.email=t@t -c user.name=t commit -qm "migrate: confirmed mapping table executed"
git -C "$R" merge -q --ff-only migrate/clankshop 2>/dev/null || git -C "$R" merge -q migrate/clankshop
git -C "$R" worktree remove "$WT"

# nothing dropped: every source row accounted for at its destination
expect_eq "migrate: TODO.md consumed"  "absent" "$([ -f "$R/TODO.md" ] && echo present || echo absent)"
expect_eq "migrate: RULES.md consumed" "absent" "$([ -f "$R/docs/RULES.md" ] && echo present || echo absent)"
expect "migrate: adr moved"        "sqlite over postgres" "$R/.records/adr/2020-01-01-use-sqlite.md"
expect "migrate: alias preserved"  "(alias TODO-7)" "$R/.records/trackers/tasks.md"
expect "migrate: second alias"     "(alias TODO-9)" "$R/.records/trackers/tasks.md"
expect "migrate: rule migrated"    "INV-$next: Always run the linter" "$R/.handbook/rules/INVARIANTS.md"

# check green on the migrated tree
bash "$CLANKSHOP_SCRIPTS/check-facts.sh" "$R" "$SKILLS" > "$TMP/facts2" 2>&1
expect "migrate: stamped"          "stamped=1" "$TMP/facts2"
for key in ticket_problems dup_ids missing_base routing_unresolved lane_missing; do
  expect "migrate: ${key} empty" "${key}_count=0" "$TMP/facts2"
done
expect "migrate: stores complete"  "stores_missing=" "$TMP/facts2"

# ============ fixture 3: unstamped refusal ============
R=$TMP/unstamped
mkdir -p "$R" && git -C "$R" init -qb main . 2>/dev/null
bash "$CLANKSHOP_SCRIPTS/check-facts.sh" "$R" "$SKILLS" > "$TMP/facts3" 2>&1
expect "refusal: check emits unstamped"   "stamped=0" "$TMP/facts3"
bash "$CLANKSHOP_SCRIPTS/install-block.sh" resolve "$R" > "$TMP/res" 2>&1
expect "refusal: resolver unmanaged"      "unmanaged=1" "$TMP/res"
bash "$CLANKSHOP_SCRIPTS/migrate-preflight.sh" "$R" > "$TMP/pre3" 2>&1
expect "refusal: preflight unstamped"     "stamped=0" "$TMP/pre3"

# ============ fixture 4: transactional pack install (spec format 1) ============
REPO_ROOT=$(CDPATH='' cd "$CLANKSHOP_SCRIPTS/../../.." && pwd -P)
IT=$TMP/inst-scope
mkdir -p "$IT"
"$REPO_ROOT/install.sh" --pack clankshop --target "$IT/skills" > "$TMP/inst" 2>&1
expect "install: face linked"        "installed clankshop" "$TMP/inst"
expect "install: lock committed"     "locked    clankshop@$PV" "$TMP/inst"
expect_eq "install: face symlink"    "link" "$([ -L "$IT/skills/clankshop" ] && echo link || echo missing)"
expect "install: lock entry"         "\"clankshop\": {" "$IT/grimoire.lock"
expect "install: optional flagged"   "\"optional\": true" "$IT/grimoire.lock"
expect "install: member hash"        "sha256:" "$IT/grimoire.lock"
expect "install: setup declared"     "\"declared\": \"/clankshop setup\"" "$IT/grimoire.lock"
"$REPO_ROOT/install.sh" --pack clankshop --target "$IT/skills" > "$TMP/inst2" 2>&1
expect "install: idempotent rerun"   "already installed" "$TMP/inst2"
expect "install: rerun re-locks"     "locked    clankshop@$PV" "$TMP/inst2"

# ============ fixture 5: registration stability (plan Task 5.3, pulled forward) ============
# setup writes each member's pack-style door block once; the four self-registering
# members (backlog init, architect init, auditor deploy, feature init) re-register
# lazily during normal use, through their own register-route.sh copies. The contract:
# an existing pack-style block is ADOPTED -- re-registration converges byte-identically,
# never rewrites the real front door -- and a hand-broken delimiter leaves the file
# untouched (malformed = report + exit; the human repairs, then re-runs).
SKILLS_SRC=$(CDPATH='' cd "$CLANKSHOP_SCRIPTS/../.." && pwd -P)
R=$TMP/regstab
mkdir -p "$R" && git -C "$R" init -qb main . 2>/dev/null
project_doctrine "$R" "$DOCTRINE" "$SKILLS" "make test" main "$PV"
cp "$R/AGENTS.md" "$TMP/door.before"
for m in backlog architect auditor feature; do
  extract_door_body "$DOCTRINE/README.md" "$m" > "$TMP/body.$m"
  bash "$SKILLS_SRC/$m/scripts/register-route.sh" "$R/AGENTS.md" "$m" "clankshop@$PV" \
    < "$TMP/body.$m" > "$TMP/reg.$m" 2>&1
  expect "regstab: $m re-registers over its block" "result=replaced" "$TMP/reg.$m"
  expect_eq "regstab: $m adopts byte-identically" "identical" \
    "$(cmp -s "$TMP/door.before" "$R/AGENTS.md" && echo identical || echo diverged)"
done

# hand-broken delimiter: drop one member's END line -> register must touch NOTHING
grep -vF '<!-- skill:feature END -->' "$R/AGENTS.md" > "$TMP/door.broken.tmp"
cat "$TMP/door.broken.tmp" > "$R/AGENTS.md"
cp "$R/AGENTS.md" "$TMP/door.broken"
bash "$SKILLS_SRC/feature/scripts/register-route.sh" "$R/AGENTS.md" feature "clankshop@$PV" \
  < "$TMP/body.feature" > "$TMP/reg.mal" 2>&1 || echo "exit=$?" >> "$TMP/reg.mal"
expect "regstab: malformed reported"      "malformed" "$TMP/reg.mal"
expect "regstab: malformed refuses (rc 3)" "exit=3" "$TMP/reg.mal"
expect_eq "regstab: broken door left untouched" "identical" \
  "$(cmp -s "$TMP/door.broken" "$R/AGENTS.md" && echo identical || echo diverged)"

echo "onramp: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
