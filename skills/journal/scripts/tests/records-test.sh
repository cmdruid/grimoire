#!/usr/bin/env bash
# records-test.sh — the deployed records.sh end to end: the new→touch→done→history
# lifecycle round-trip (ledger line appended), list/history filters, and `check`
# proven by breaking — broken front-matter, closed-status-without-ledger-line,
# a malformed ledger, and every refusal the script advertises.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
. "$DIR/lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/journal-records-test.XXXXXX")"
TMP="$(cd "$TMP" && pwd)"   # canonical (a trailing-slash TMPDIR would break path equality)
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out"; ERR="$TMP/err"

proj="$TMP/proj"
mkdir -p "$proj"
"$SKILL/scripts/standup.sh" "$proj" >/dev/null
RS="$proj/.records/scripts/records.sh"
today="$(date +%Y-%m-%d)"

# Templates belong at <agent-workspace>/templates. This fixture plants them
# UNDER the records root on purpose: that is the coinciding-roots host the
# two-roots spec legalizes, and it is the case the discriminator must survive.
# They are contract-shaped -- a real doctype and unfilled <date> slots, because
# that block is exactly what `new` copies into the minted record -- so a
# front-matter-only discriminator would swallow all three as records and FAIL
# check on `created: <date>`. The dated-filename conjunct is what excludes them,
# with no reserved name anywhere. `<tags>` is the --tag slot (omit → []).
TPL="$proj/.records/templates"
mkdir -p "$TPL"
for t in plans notes trackers; do
  printf -- '---\ndoctype: %s\nstatus: open\ncreated: <date>\nupdated: <date>\ntags: [<tags>]\n---\n\n# <title>\n' "$t" \
    > "$TPL/$t.md"
done

# --- --template: path outside $RR is accepted -----------------------------------
outside="$TMP/outside-plans.md"
printf -- '---\ndoctype: plans\nstatus: open\ncreated: <date>\nupdated: <date>\ntags: []\n---\n\n# <title>\noutside\n' \
  > "$outside"
p_out="$("$RS" new plans --template "$outside" --title "From outside")"
expect_eq "new --template outside \$RR" "$proj/.records/plans/$today-from-outside.md" "$p_out"
expect "outside template body used" "outside" "$p_out"
expect "outside template title filled" "# From outside" "$p_out"

p="$("$RS" new plans --template "$TPL/plans.md" --title "Alpha: the first plan")"
expect_eq "new prints the path" "$proj/.records/plans/$today-alpha-the-first-plan.md" "$p"
expect "front-matter doctype" "doctype: plans" "$p"
expect "front-matter status open" "status: open" "$p"
expect "front-matter created stamped" "created: $today" "$p"
expect "title slot filled" "# Alpha: the first plan" "$p"
expect_absent "no unfilled date slot" "<date>" "$p"
expect_absent "no unfilled title slot" "<title>" "$p"
expect "no --tag leaves empty list" "tags: []" "$p"

p_tag="$("$RS" new notes --template "$TPL/notes.md" --title "Tagged fact" --tag alpha --tag hot)"
expect "repeatable --tag writes list" "tags: [alpha, hot]" "$p_tag"
"$RS" list --tag hot >"$OUT"
expect "list --tag matches minted tags" "tagged-fact" "$OUT"
rc=0; "$RS" new notes --template "$TPL/notes.md" --title "Empty tag" --tag "" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "empty --tag refuses" "2" "$rc"

p2="$("$RS" new plans --template "$TPL/plans.md" --title "Alpha: the first plan")"
expect_eq "colliding slug gets a suffix" "$proj/.records/plans/$today-alpha-the-first-plan-2.md" "$p2"

# --- list: TSV row + filters -----------------------------------------------------
"$RS" new notes --template "$TPL/notes.md" --title "A fact" >/dev/null
"$RS" list >"$OUT"
expect "list row is TSV" "plans/$today-alpha-the-first-plan.md	plans	open	$today" "$OUT"
"$RS" list --type notes >"$OUT"
expect "type filter keeps notes" "A fact" "$OUT"
expect_absent "type filter drops plans" "plans" "$OUT"
sed -i.bak "s/^tags: \[\]/tags: [alpha, hot]/" "$p" && rm -f "$p.bak"
"$RS" list --tag hot >"$OUT"
expect "tag filter matches" "alpha-the-first-plan" "$OUT"
"$RS" list --tag cold >"$OUT"
expect_absent "tag filter excludes" "alpha-the-first-plan" "$OUT"

# --- touch: stamps without hand-editing ------------------------------------------
"$RS" touch "$p" --status current >/dev/null
expect "touch sets status" "status: current" "$p"
expect "touch keeps updated stamped" "updated: $today" "$p"

# --- done: closure in place + the one ledger line --------------------------------
"$RS" 'done' "$p" --as consumed --note "folded into the spec" >"$OUT"
expect "done reports the ledger line" "consumed	plans/$today-alpha-the-first-plan.md" "$OUT"
expect "record closed in place" "status: consumed" "$p"
expect "ledger line appended" "$today	consumed	plans/$today-alpha-the-first-plan.md	plans	Alpha: the first plan	folded into the spec" "$proj/.records/history.tsv"

"$RS" history >"$OUT"
expect "history round-trips" "folded into the spec" "$OUT"
"$RS" history --disposition dropped >"$OUT"
expect_absent "disposition filter excludes" "consumed" "$OUT"
"$RS" history --grep "folded" >"$OUT"
expect "history grep matches" "consumed" "$OUT"

"$RS" check >"$OUT"
expect "check green after lifecycle" "records check: OK (5 records)" "$OUT"

# --- proven by breaking -----------------------------------------------------------
rc=0; "$RS" 'done' "$p" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "double-done refused rc" "2" "$rc"
expect "double-done names the status" "already closed (consumed)" "$ERR"

rc=0; "$RS" touch "$p2" --status 'done' >"$OUT" 2>"$ERR" || rc=$?
expect_eq "closing via touch refused rc" "2" "$rc"
expect "closing via touch routed to done" "closing status goes through 'done'" "$ERR"

rc=0; "$RS" 'done' "$p2" --as wontfix >"$OUT" 2>"$ERR" || rc=$?
expect_eq "unknown disposition rc" "2" "$rc"

rc=0; "$RS" new gizmos --template "$TPL/gizmos.md" --title "No such store" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "missing template file rc" "2" "$rc"
expect "missing template names the doctype" "no template for doctype 'gizmos'" "$ERR"

# --template is mandatory: the tool knows no taxonomy, so it cannot guess a
# template location from a doctype name. There is no flat fallback to lean on.
rc=0; "$RS" new plans --title "No template given" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "bare mint rc" "2" "$rc"
expect "bare mint names the missing flag" "--template is required" "$ERR"
expect_absent "bare mint minted nothing" "no-template-given" "$OUT"

# A template sharing the records root is not a record: it declares a doctype but
# wears no date, so it fails the shape conjunct.
rc=0; "$RS" touch "$TPL/notes.md" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "template refused as a record rc" "2" "$rc"
expect "template named not-a-record" "not a record: templates/notes.md" "$ERR"

rc=0; "$RS" show "plans/nope.md" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "missing record rc" "2" "$rc"

# broken front-matter: check FAILs and names each violation
bad="$proj/.records/notes/$today-broken.md"
printf -- '---\ndoctype: bugs\nstatus: bogus\ncreated: 2026-8-1\n---\n# Broken\n' > "$bad"
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "broken front-matter check rc" "2" "$rc"
expect "check flags missing key" "missing key: updated" "$ERR"
# The doctype is NOT cross-checked against the parent directory any more: the
# front-matter key is the authority and the directory is the caller's business,
# so `doctype: bugs` living under notes/ is not a finding.
expect_absent "no doctype-vs-directory finding" "does not match store" "$ERR"
expect "check flags bad status" "status not in the contract: bogus" "$ERR"
expect "check flags bad date" "created is not YYYY-MM-DD: 2026-8-1" "$ERR"
rm "$bad"

# closed status with no ledger line: the coherence half of check
sneaky="$proj/.records/notes/$today-sneaky.md"
printf -- '---\ndoctype: notes\nstatus: done\ncreated: %s\nupdated: %s\ntags: []\n---\n# Sneaky\n' "$today" "$today" > "$sneaky"
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "closed-without-ledger check rc" "2" "$rc"
expect "check names the coherence break" "closing status 'done' but no history.tsv ledger line" "$ERR"
rm "$sneaky"

# --- record links: `→ <store>/<file>.md` must resolve (link-rot detection) --------
tr_rec="$("$RS" new trackers --template "$TPL/trackers.md" --title "Backlog")"
note_rel="$("$RS" list --type notes | head -1 | cut -f1)"
printf -- '- [ ] %s — wire the alpha [→ %s]\n' "$today" "$note_rel" >> "$tr_rec"
printf -- '- [ ] %s — prose example, unchecked [→ path/to/linked-record.md]\n' "$today" >> "$tr_rec"
"$RS" check >"$OUT"
expect "resolving link passes check" "records check: OK" "$OUT"
printf -- '- [ ] %s — rotted [→ notes/never-existed.md]\n' "$today" >> "$tr_rec"
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "broken link check rc" "2" "$rc"
expect "check names the broken link" "broken link → notes/never-existed.md" "$ERR"
sed -i.bak '/rotted/d' "$tr_rec" && rm -f "$tr_rec.bak"

# A template teaching the tracker-line FORM must name a real store to be useful,
# which defeats the first-segment filter -- so code blocks are skipped outright.
# Both fence styles and the four-space indent, since templates use all three.
printf -- '\n    - [ ] %s — indented example [→ notes/%s-nope.md]\n' "$today" "$today" >> "$tr_rec"
printf -- '\n```\n- [ ] %s — fenced example [→ notes/%s-also-nope.md]\n```\n' "$today" "$today" >> "$tr_rec"
lrc=0; "$RS" check >"$OUT" 2>"$ERR" || lrc=$?   # rc captured so a regression here
expect_eq "example links in code blocks do not fail the check" "0" "$lrc"  # reports, not aborts
expect "example links inside code blocks are not followed" "records check: OK" "$OUT"
# Red-proof: the skip must not be a blanket amnesty -- a real link OUTSIDE a code
# block, added while those examples remain, still has to fail.
printf -- '- [ ] %s — rotted-again [→ notes/never-existed-either.md]\n' "$today" >> "$tr_rec"
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "real rot still caught alongside examples" "2" "$rc"
expect "check still names the real broken link" "broken link → notes/never-existed-either.md" "$ERR"
sed -i.bak '/rotted-again/d' "$tr_rec" && rm -f "$tr_rec.bak"

# --- WARN tier: record-shaped files the discriminator rejects ---------------------
# The one thing crawling loses. A path-based scan FAILed a malformed record it
# found inside a known store; the crawl does not see such a file at all. So
# `check` hunts the record SHAPE and reports what it cannot accept -- reported,
# never silent, and never a failure, because the file may legitimately not be a
# record.
"$RS" check >"$OUT" 2>"$ERR"
expect_absent "a clean root warns about nothing" "WARN:" "$ERR"

orphan="$proj/.records/notes/$today-orphan.md"
printf '# Orphan\n\nHand-written, never minted.\n' > "$orphan"
[ -f "$orphan" ] || { echo "FAIL: orphan fixture was not applied" >&2; exit 1; }
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "a shaped non-record does not fail the check" "0" "$rc"
expect "shaped non-record warns" "WARN: notes/$today-orphan.md" "$ERR"
expect "the warning explains the miss" "no front-matter declaring a doctype" "$ERR"

# front-matter present but declaring no type: the (b) half of the discriminator
typeless="$proj/.records/notes/$today-typeless.md"
printf -- '---\nstatus: open\ncreated: %s\n---\n# Typeless\n' "$today" > "$typeless"
[ -f "$typeless" ] || { echo "FAIL: typeless fixture was not applied" >&2; exit 1; }
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "a typeless shaped file does not fail the check" "0" "$rc"
expect "typeless file warns too" "WARN: notes/$today-typeless.md" "$ERR"
expect "both shaped misses are counted" "2 record-shaped file(s) not recognized" "$ERR"
expect_absent "a warned file is not counted as a record" "typeless" "$OUT"

rm "$orphan" "$typeless"
"$RS" check >"$OUT" 2>"$ERR"
expect_absent "warnings clear once the files go" "WARN:" "$ERR"

# a closed-then-reopened record, for the prune shortlist below
tk="$("$RS" new notes --template "$TPL/notes.md" --title "Need the API key")"
"$RS" 'done' "$tk" --note "key provided" >/dev/null

# --- prune-candidates: still-existing × still-closed × ledger-dated ---------------
"$RS" prune-candidates >"$OUT"
expect "consumed plan is a prune candidate" "consumed	plans/$today-alpha-the-first-plan.md" "$OUT"
"$RS" prune-candidates --until 2000-01-01 >"$OUT"
expect_absent "until-filter excludes newer closures" "alpha-the-first-plan" "$OUT"
"$RS" touch "$tk" --status open >/dev/null   # reopened after closure: no longer prunable
"$RS" prune-candidates >"$OUT"
expect_absent "reopened record is not a candidate" "need-the-api-key" "$OUT"
rm "$proj/.records/plans/$today-alpha-the-first-plan.md"   # pruned: ledger line stays,
"$RS" prune-candidates >"$OUT"                             # candidate disappears
expect_absent "pruned record drops off the shortlist" "alpha-the-first-plan" "$OUT"
"$RS" check >"$OUT"
expect "check green after prune (ledger line survives)" "records check: OK" "$OUT"

# --- the coinciding-roots host: doctrine sharing the records root ---------------
# A host that points <agent-workspace> and <agent-records> at the same directory
# keeps its doctrine under this root: living normative prose, not dated records.
# There is no reserved name for it any more -- doctrine simply fails the
# discriminator. Both arms are proven INDEPENDENTLY on purpose: a check-only
# proof would pass a partial fix (fix the crawl, leave resolve() open, and
# `check` returns OK while `show` happily cats the file). So the crawl is proven
# via check/list, resolve() via show/touch.
mkdir -p "$proj/.records/doctrine/test/workflows"
printf '# Diagnostics\n\nLiving normative prose. No front-matter, by design.\n' \
  > "$proj/.records/doctrine/test/workflows/diagnostics.md"

# arm 1 -- the crawl: doctrine is not a record, so check stays green and list ignores it
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "doctrine dir keeps check green rc" "0" "$rc"
expect "doctrine dir does not break check" "records check: OK" "$OUT"
"$RS" list >"$OUT"
expect_absent "doctrine file is not listed as a record" "doctrine/" "$OUT"
expect_absent "undated doctrine prose does not even warn" "diagnostics.md" "$ERR"

# arm 2 -- resolve(): a doctrine path is refused as a record
rc=0; "$RS" show doctrine/test/workflows/diagnostics.md >"$OUT" 2>"$ERR" || rc=$?
expect_eq "show refuses a doctrine path rc" "2" "$rc"
expect "show names it not-a-record" "not a record: doctrine/test/workflows/diagnostics.md" "$ERR"
rc=0; "$RS" touch doctrine/test/workflows/diagnostics.md >"$OUT" 2>"$ERR" || rc=$?
expect_eq "touch refuses a doctrine path rc" "2" "$rc"
expect "touch names it not-a-record" "not a record: doctrine/test/workflows/diagnostics.md" "$ERR"

# A doctrine page may legitimately carry front-matter of its own -- a title, an
# owner -- which is why mere front-matter cannot be the discriminator. It
# declares no doctype, so it is still not a record. The MESSAGE assertion is the
# real proof here: the rc alone would also be produced by the five-key contract
# check, so it can pass for the wrong reason.
printf -- '---\ntitle: Diagnostics\nowner: test station\n---\n\n# Diagnostics\n\nProse.\n' \
  > "$proj/.records/doctrine/test/workflows/stamped.md"
rc=0; "$RS" touch doctrine/test/workflows/stamped.md >"$OUT" 2>"$ERR" || rc=$?
expect_eq "touch refuses front-mattered doctrine rc" "2" "$rc"
expect "front-mattered doctrine named not-a-record" "not a record: doctrine/test/workflows/stamped.md" "$ERR"

# --- grep: body search, not front-matter (red-proofs 1–2) -----------------------
# Plant tags: [ZXSECRET] with no ZXSECRET in title or body → grep is empty
# (exit 0). Title lives after the closing ---, so it must not contain the token.
secret_tags="$proj/.records/notes/$today-tagged-zx.md"
printf -- '---\ndoctype: notes\nstatus: open\ncreated: %s\nupdated: %s\ntags: [ZXSECRET]\n---\n\n# Tagged zx\n\nNo match word in the body.\n' \
  "$today" "$today" > "$secret_tags"
rc=0; "$RS" grep ZXSECRET >"$OUT" 2>"$ERR" || rc=$?
expect_eq "grep tags-only plant rc" "0" "$rc"
expect_absent "grep does not match tags in front-matter" "tagged-zx" "$OUT"

# Plant ZXSECRET in the body → one row. Tags-only plant still excluded.
secret_body="$proj/.records/notes/$today-body-zx.md"
printf -- '---\ndoctype: notes\nstatus: open\ncreated: %s\nupdated: %s\ntags: []\n---\n\n# Body zx\n\nThe token ZXSECRET lives here.\n' \
  "$today" "$today" > "$secret_body"
"$RS" grep ZXSECRET >"$OUT"
expect "grep matches body" "body-zx" "$OUT"
expect_absent "grep still excludes tags-only plant" "tagged-zx" "$OUT"

"$RS" grep ZXSECRET --type notes >"$OUT"
expect "grep --type notes keeps the body hit" "body-zx" "$OUT"
"$RS" grep ZXSECRET --type plans >"$OUT"
expect_absent "grep --type plans drops the notes hit" "body-zx" "$OUT"

rc=0; "$RS" grep >"$OUT" 2>"$ERR" || rc=$?
expect_eq "grep without pattern is usage rc" "1" "$rc"

rc=0; "$RS" >"$OUT" 2>"$ERR" || rc=$?
expect_eq "no-args usage rc" "1" "$rc"
expect "usage lists grep next to list" "  grep    " "$ERR"

# Red-proof 2: coinciding-roots template with a unique token is not a record.
printf '\nZXTEMPLTOKEN in the template\n' >> "$TPL/plans.md"
"$RS" grep ZXTEMPLTOKEN >"$OUT"
expect_absent "grep does not swallow templates" "templates/" "$OUT"
p_tok="$("$RS" new plans --template "$TPL/plans.md" --title "Has token")"
"$RS" grep ZXTEMPLTOKEN >"$OUT"
expect "grep hits minted record with the template token" "has-token" "$OUT"
expect_absent "template path still not listed after mint" "templates/" "$OUT"
expect_eq "minted record path" "$proj/.records/plans/$today-has-token.md" "$p_tok"

# Red-proof 1 (mutation): disable the front-matter skip on a COPY; the tags-only
# plant starts matching. A silent no-op cut would leave this green on unbroken
# input, so assert the skip is present, then gone.
proj_grep="$TMP/proj-grep-skip"
mkdir -p "$proj_grep"
"$SKILL/scripts/standup.sh" "$proj_grep" >/dev/null
RSG="$proj_grep/.records/scripts/records.sh"
mkdir -p "$proj_grep/.records/notes"
printf -- '---\ndoctype: notes\nstatus: open\ncreated: %s\nupdated: %s\ntags: [ZXSECRET]\n---\n\n# Tagged zx\n\nNo match word in the body.\n' \
  "$today" "$today" > "$proj_grep/.records/notes/$today-tagged-zx.md"
"$RSG" grep ZXSECRET >"$OUT"
expect_absent "unbroken grep skips tags on the copy" "tagged-zx" "$OUT"

skip='infm { next }  # GREP_SKIP_FM'
before="$(grep -cF -- "$skip" "$RSG" || true)"
expect_eq "front-matter skip present before the cut" "1" "$before"
awk -v s="$skip" '{ if (index($0, s)) next; else print }' "$RSG" > "$RSG.cut"
mv "$RSG.cut" "$RSG"
chmod +x "$RSG"
after="$(grep -cF -- "$skip" "$RSG" || true)"
expect_eq "front-matter skip gone after the cut" "0" "$after"
"$RSG" grep ZXSECRET >"$OUT"
expect "tags-only plant matches once the skip is gone" "tagged-zx" "$OUT"

# --- --dir: caller-named mint directory (red-proof 4) --------------------------
abs_dir="$TMP/records-abs-should-not-exist"
rc=0; "$RS" new notes --dir "$abs_dir" --template "$TPL/notes.md" --title "Abs dir" \
  >"$OUT" 2>"$ERR" || rc=$?
expect_eq "--dir absolute rc" "2" "$rc"
[ ! -e "$abs_dir" ] && pass=$((pass + 1)) || {
  echo "FAIL: --dir absolute created $abs_dir" >&2; fail=$((fail + 1)); }
[ ! -d "$proj/.records/abs" ] && pass=$((pass + 1)) || {
  echo "FAIL: --dir absolute mkdir under the records root" >&2; fail=$((fail + 1)); }

rc=0; "$RS" new notes --dir foo/../bar --template "$TPL/notes.md" --title "Dotdot dir" \
  >"$OUT" 2>"$ERR" || rc=$?
expect_eq "--dir foo/../bar rc" "2" "$rc"
[ ! -d "$proj/.records/foo" ] && pass=$((pass + 1)) || {
  echo "FAIL: --dir foo/../bar created foo/" >&2; fail=$((fail + 1)); }
[ ! -d "$proj/.records/bar" ] && pass=$((pass + 1)) || {
  echo "FAIL: --dir foo/../bar created bar/" >&2; fail=$((fail + 1)); }

rc=0; "$RS" new notes --dir "" --template "$TPL/notes.md" --title "Empty dir" \
  >"$OUT" 2>"$ERR" || rc=$?
expect_eq "empty --dir rc" "2" "$rc"

p_dir="$("$RS" new notes --dir nested/facts --template "$TPL/notes.md" --title "Nested fact")"
expect_eq "new --dir path" "$proj/.records/nested/facts/$today-nested-fact.md" "$p_dir"
expect "doctype is still the positional" "doctype: notes" "$p_dir"
"$RS" list --type notes >"$OUT"
expect "list sees the --dir record" "nested-fact" "$OUT"
"$RS" list --type notes >"$OUT"
expect "list path is the --dir location" "nested/facts/$today-nested-fact.md" "$OUT"

# malformed ledger: hand-written lines are a fact check reports
echo "garbage line" >> "$proj/.records/history.tsv"
rc=0; "$RS" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "malformed ledger check rc" "2" "$rc"
expect "check counts ledger fields" "1 fields (want 6)" "$ERR"

# --- the dated-shape conjunct is load-bearing, proven by removing it ------------
# The discriminator is "named YYYY-MM-DD-<slug>.md AND carrying front-matter
# that declares a doctype". Front-matter alone is NOT enough, and the reason is
# not hypothetical: a record template necessarily carries a doctype block (that
# block is what `new` copies into the minted record), and templates share this
# root on any host whose workspace and records homes coincide.
#
# So run the decisive experiment: mutate a COPY of the script (in a second
# fixture project, so its self-derived $RR still resolves) to drop the shape
# conjunct, degrading the rule to front-matter-declaring-a-doctype, and watch
# the template get swallowed.
#
# The `assert applied` step is not ceremony: a "break" that silently fails to
# apply leaves the suite green on unbroken input, which is indistinguishable
# from a passing proof.
proj2="$TMP/proj-noshape"
mkdir -p "$proj2"
"$SKILL/scripts/standup.sh" "$proj2" >/dev/null
RS2="$proj2/.records/scripts/records.sh"
mkdir -p "$proj2/.records/templates"
printf -- '---\ndoctype: plans\nstatus: open\ncreated: <date>\nupdated: <date>\ntags: []\n---\n\n# <title>\n' \
  > "$proj2/.records/templates/plans.md"

# baseline: the UNBROKEN script is green on this exact fixture, so any change
# below is the conjunct's doing and not the fixture's.
rc=0; "$RS2" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "unbroken script is green with a template under the root" "0" "$rc"
expect_absent "the template is not a record" "templates/plans.md" "$OUT"

shape='[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md) ;;'
before="$(grep -cF -- "$shape" "$RS2" || true)"
expect_eq "shape conjunct present before the cut" "1" "$before"
awk -v s="$shape" '{ if (index($0, s)) print "    *) ;;"; else print }' "$RS2" > "$RS2.cut"
mv "$RS2.cut" "$RS2"
chmod +x "$RS2"
after="$(grep -cF -- "$shape" "$RS2" || true)"
expect_eq "shape conjunct gone after the cut" "0" "$after"

# With the shape gone, the rule is "declares a doctype" -- and the template
# declares one, so it is swallowed as a record and fails on its unfilled slot.
rc=0; "$RS2" check >"$OUT" 2>"$ERR" || rc=$?
expect_eq "template swallowed once the shape conjunct goes" "2" "$rc"
expect "swallowed template fails on the unfilled date slot" "created is not YYYY-MM-DD: <date>" "$ERR"
expect "and it is named as the offender" "templates/plans.md" "$ERR"

report "records-test"
