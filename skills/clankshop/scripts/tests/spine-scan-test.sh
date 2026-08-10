#!/bin/sh
set -eu
DIR=$(CDPATH='' cd "$(dirname "$0")" && pwd)
SCAN="$DIR/../spine-scan.sh"
out=$(sh "$SCAN" "$DIR/fixtures/basic")
fail=0
check() { echo "$out" | grep -qx "$1" || { echo "MISSING: $1"; fail=1; }; }
check "entry_door=CLAUDE.md"
check "import_chain=AGENTS.md"
# Task 3: link graph, reachability, orphans
echo "$out" | grep -q '^edges=AGENTS.md->dev/README.md$' || { echo "MISSING: edges=AGENTS.md->dev/README.md"; fail=1; }
check "orphan_docs=notes/orphan.md"
# Fix A: a doc referenced ONLY via a backtick inline-code path is now a reachability edge,
# so it is REACHED (not an orphan) -- assert both the edge and its absence from orphans.
echo "$out" | grep -q '^edges=AGENTS.md->sub/viabacktick.md$' || { echo "MISSING: backtick edge to sub/viabacktick.md"; fail=1; }
echo "$out" | grep -q 'sub/viabacktick.md' && echo "$out" | grep '^orphan_docs=' | grep -q 'sub/viabacktick.md' && { echo "REGRESSION: sub/viabacktick.md still an orphan"; fail=1; }
# Fenced-code-block ignore: a [x](./fenced-target.md) link and a backtick `fenced/code.md`
# ref live INSIDE a ```markdown fence in fenced.md (deliberate examples) -- neither path may
# become an edge, and the broken link inside the fence must NOT be reported as broken.
echo "$out" | grep -q 'fenced-target.md' && { echo "REGRESSION: fenced-target.md leaked from inside a code fence"; fail=1; }
echo "$out" | grep -q 'fenced/code.md' && { echo "REGRESSION: fenced/code.md ref leaked from inside a code fence"; fail=1; }
# Task 4: broken links + stale refs
echo "$out" | grep -q '^broken_links=' && echo "$out" | grep -q 'dev/missing.md' || { echo "no broken_links"; fail=1; }
echo "$out" | grep -q 'src/nope.rs' || { echo "no stale_refs"; fail=1; }
# Digestible-output contract: every list fact emits a true "<key>_count=<N>" line alongside
# its (capped) sample. The tiny fixture won't trigger truncation, so assert the counts directly.
check "edges_count=7"
check "orphan_docs_count=1"
check "unreachable_dirs_count=1"
check "broken_links_count=1"
check "stale_refs_count=1"
check "doc_sizes_count=7"
# (more checks appended in later tasks)
# Task 5: token economy + affordance flags
echo "$out" | grep -Eq '^always_loaded_bytes=[0-9]+$' || { echo "no always_loaded_bytes"; fail=1; }
check "has_glossary=0"
check "has_front_door=1"
check "has_stewardship_map=0"
# Absorbed foreman-health facts: line-overrun refs + door-uncovered top-level dirs.
check "fileline_overruns_count=1"
echo "$out" | grep -q '^fileline_overruns=AGENTS.md:src/real.rs:99' || { echo "no fileline_overruns"; fail=1; }
check "uncovered_dirs=notes/"
echo "$out" | grep -Eq '^frontmatter_coverage=[0-9]+/[0-9]+$' || { echo "no frontmatter_coverage"; fail=1; }
# --- stewardship fixture: a .handbook/README.md with spine-index + steward blocks is a map ---
outS=$(sh "$SCAN" "$DIR/fixtures/stewardship")
echo "$outS" | grep -qx "has_stewardship_map=1" || { echo "MISSING(stewardship): has_stewardship_map=1"; fail=1; }
# --- entry-door fixture (CLAUDE.md imports AGENTS.md -> claude->agents) ---
outE=$(sh "$SCAN" "$DIR/fixtures/entrydoor")
checkE() { echo "$outE" | grep -qx "$1" || { echo "MISSING(entrydoor): $1"; fail=1; }; }
checkE "agents_md=1"
checkE "claude_md=1"
checkE "front_door_link=claude->agents"
# --- no-link fixture (both exist, neither references the other -> none) ---
outN=$(sh "$SCAN" "$DIR/fixtures/entrydoor_nolink")
echo "$outN" | grep -qx "front_door_link=none" || { echo "MISSING(nolink): front_door_link=none"; fail=1; }
# content door = AGENTS.md (exists) -> outline carries its headings, hub links = guide.md + ref.md
echo "$outE" | grep -q '^entry_outline=' && echo "$outE" | grep -q '## Build' || { echo "MISSING(entrydoor): entry_outline w/ '## Build'"; fail=1; }
checkE "entry_hub_links=3"
# --- fenced-import fixture: a FENCED @AGENTS.md example in CLAUDE.md is a deliberate
# example, not a live import -- it must NOT flip the entry door to CLAUDE.md, and the
# import chain must stay empty.
outF=$(sh "$SCAN" "$DIR/fixtures/fenced_import")
echo "$outF" | grep -qx "entry_door=AGENTS.md" || { echo "MISSING(fenced_import): entry_door=AGENTS.md (fenced import flipped the door)"; fail=1; }
echo "$outF" | grep -qx "import_chain=" || { echo "MISSING(fenced_import): empty import_chain"; fail=1; }
# --- max_depth: basic fixture is CLAUDE.md -> AGENTS.md -> dev/README.md => depth 2
echo "$out" | grep -qx "max_depth=2" || { echo "MISSING: max_depth=2 (basic fixture)"; fail=1; }
# --- untracked-doc case: in a git repo, a new not-yet-committed doc is part of the spine.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp "$DIR/fixtures/fenced_import/AGENTS.md" "$DIR/fixtures/fenced_import/guide.md" "$tmp/"
git -C "$tmp" init -q && git -C "$tmp" add AGENTS.md guide.md
git -C "$tmp" -c user.email=t@t -c user.name=t commit -qm seed
printf '# New\n' > "$tmp/untracked.md"
outG=$(sh "$SCAN" "$tmp")
echo "$outG" | grep '^orphan_docs=' | grep -q 'untracked.md' || { echo "MISSING(git): untracked.md not scanned"; fail=1; }
# --- multi-root fixture: a superproject with a nested git repo (gitlink submodule).
# The outer scan must (a) report the nested repo as a sub_root annotated with its own
# front door, (b) classify backtick refs that resolve INSIDE a sub_root as xroot_refs
# (cross-root citations, not staleness), and (c) keep truly-unresolvable refs in
# stale_refs. Scanning the NESTED root directly must flag a ../-link that climbs above
# that root as an escaping_ref (breaks on standalone clone), not clamp it in-repo or
# count it as a broken link.
tmp2=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2"' EXIT
mkdir -p "$tmp2/repos/subA/docs" "$tmp2/repos/subA/src/util" "$tmp2/docs"
printf '# Outer\nSee [guide](docs/guide.md).\nCited: `src/util/helper.rs` and `subA/src/main.rs` and `src/nope.rs`.\n' > "$tmp2/AGENTS.md"
printf '# Guide\n' > "$tmp2/docs/guide.md"
printf '# Sub door\n[deep](docs/deep.md)\n' > "$tmp2/repos/subA/CLAUDE.md"
printf '# Deep\nUp and out: [outer guide](../../../docs/guide.md)\nAlso cites `../../../src/outside.ts` up and out of the repo.\n' > "$tmp2/repos/subA/docs/deep.md"
printf 'fn main() {}\n' > "$tmp2/repos/subA/src/main.rs"
printf 'pub fn h() {}\n' > "$tmp2/repos/subA/src/util/helper.rs"
git -C "$tmp2/repos/subA" init -q && git -C "$tmp2/repos/subA" add -A
git -C "$tmp2/repos/subA" -c user.email=t@t -c user.name=t commit -qm seed
subsha=$(git -C "$tmp2/repos/subA" rev-parse HEAD)
git -C "$tmp2" init -q && git -C "$tmp2" add AGENTS.md docs/guide.md
git -C "$tmp2" update-index --add --cacheinfo "160000,$subsha,repos/subA"
git -C "$tmp2" -c user.email=t@t -c user.name=t commit -qm seed
outM=$(sh "$SCAN" "$tmp2")
checkM() { echo "$outM" | grep -qx "$1" || { echo "MISSING(multiroot): $1"; fail=1; }; }
checkM "sub_roots_count=1"
checkM "sub_roots=repos/subA:CLAUDE.md"
# `src/util/helper.rs` resolves under the sub_root; `subA/src/main.rs` resolves under the
# sub_root's parent dir (repos/). Both are cross-root citations, not stale refs.
checkM "xroot_refs_count=2"
echo "$outM" | grep '^xroot_refs=' | grep -q 'AGENTS.md:src/util/helper.rs' || { echo "MISSING(multiroot): xroot_refs w/ src/util/helper.rs"; fail=1; }
checkM "stale_refs_count=1"
echo "$outM" | grep '^stale_refs=' | grep -q 'src/nope.rs' || { echo "MISSING(multiroot): stale_refs w/ src/nope.rs"; fail=1; }
# Nested-root docs are a separate spine: they must NOT appear in the outer scan's doc set.
echo "$outM" | grep -q 'repos/subA/docs/deep.md' && { echo "REGRESSION(multiroot): nested repo docs leaked into outer spine"; fail=1; }
# --- nested-root scan: an out-of-root ref escapes the scanned root whether it is a
# markdown LINK (../../../docs/guide.md) or a backtick CODE-SPAN ref
# (../../../src/outside.ts). BOTH are self-containment violations; both must land in
# escaping_refs and NEITHER may be mislabeled as ordinary stale_refs or broken_links.
outS=$(sh "$SCAN" "$tmp2/repos/subA")
checkS() { echo "$outS" | grep -qx "$1" || { echo "MISSING(subroot): $1"; fail=1; }; }
checkS "escaping_refs_count=2"
echo "$outS" | grep '^escaping_refs=' | grep -q 'docs/deep.md->../../../docs/guide.md' || { echo "MISSING(subroot): escaping link edge"; fail=1; }
echo "$outS" | grep '^escaping_refs=' | grep -q 'docs/deep.md->../../../src/outside.ts' || { echo "MISSING(subroot): escaping code-span ref"; fail=1; }
# The code-span escape must NOT be counted as an in-repo stale ref.
checkS "stale_refs_count=0"
echo "$outS" | grep '^stale_refs=' | grep -q 'outside.ts' && { echo "REGRESSION(subroot): code-span escape leaked into stale_refs"; fail=1; }
# The escape must not be clamped into a phantom in-repo edge or counted as broken.
checkS "broken_links_count=0"
# Outer scan has no escapes; escaping_refs must still be emitted (as an empty list fact).
checkM "escaping_refs_count=0"

# --- historical fixture: broken/stale refs inside historical-record docs (CHANGELOG,
# archive/ dir, dated filename) are cited past states, not live rot. They must land in
# the *_archived list facts; only refs in LIVE docs stay in broken_links / stale_refs.
outH=$(sh "$SCAN" "$DIR/fixtures/historical")
checkH() { echo "$outH" | grep -qx "$1" || { echo "MISSING(historical): $1"; fail=1; }; }
# AGENTS.md is the only live doc: one broken link + one stale ref stay live.
checkH "broken_links_count=1"
echo "$outH" | grep '^broken_links=' | grep -q 'AGENTS.md->nope-live.md' || { echo "MISSING(historical): live broken link"; fail=1; }
checkH "stale_refs_count=1"
echo "$outH" | grep '^stale_refs=' | grep -q 'src/live-missing.rs' || { echo "MISSING(historical): live stale ref"; fail=1; }
# Three historical docs (basename/archive-dir/dated) each contribute one broken + one stale.
checkH "broken_links_archived_count=3"
checkH "stale_refs_archived_count=3"
echo "$outH" | grep '^broken_links_archived=' | grep -q 'CHANGELOG.md->gone-basename.md' || { echo "MISSING(historical): basename broken link archived"; fail=1; }
echo "$outH" | grep '^stale_refs_archived=' | grep -q 'src/hist-dated.rs' || { echo "MISSING(historical): dated stale ref archived"; fail=1; }
# A live doc's rot must NOT leak into the archived buckets, and vice-versa.
echo "$outH" | grep '^broken_links_archived=' | grep -q 'nope-live.md' && { echo "REGRESSION(historical): live rot leaked into archived"; fail=1; }
echo "$outH" | grep '^stale_refs=' | grep -q 'hist-' && { echo "REGRESSION(historical): archived rot leaked into live stale_refs"; fail=1; }
# Basic fixture's live counts are unchanged AND its archived buckets are emitted-but-empty.
check "broken_links_archived_count=0"
check "stale_refs_archived_count=0"
# --- declaration fixture: the three declaration-driven checks (shared parser) ---
outD=$(sh "$SCAN" "$DIR/fixtures/decl")
checkD() { echo "$outD" | grep -qx "$1" || { echo "MISSING(decl): $1"; fail=1; }; }
checkD "decl_docs=.handbook/rules/GOTCHAS.md:gotchas"
checkD "decl_budget_over=.handbook/rules/GOTCHAS.md (2/1 entries)"
checkD "decl_unresolved_citations=.handbook/rules/GOTCHAS.md:G-9"
[ "$fail" = 0 ] && echo "PASS" || { echo "FAIL"; exit 1; }
