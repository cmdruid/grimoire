#!/usr/bin/env bash
# artifacts-test.sh — draft/spike writer contract in throwaway fixtures.
set -u
DIR="$(CDPATH='' cd "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd "$DIR/../.." && pwd)"
WRITER="$SKILL/scripts/architect-artifacts.sh"
# shellcheck disable=SC1091
. "$DIR/lib.sh"

T="$(mktemp -d "${TMPDIR:-/tmp}/architect-artifacts.XXXXXX")"
trap 'rm -rf "$T"' EXIT
ROOT="$T/root"; INPUT="$T/input"; mkdir -p "$ROOT" "$INPUT"
OUT="$T/out"; ERR="$T/err"; rc=0

draft_body() { sed "s/<title>/$2/" "$SKILL/templates/draft.md" >"$1"; }
spike_body() { # spike_body <path> <title> [positive|negative|inconclusive]
  awk -v title="$2" -v result="${3:-positive}" '
    NR == 1 { sub(/<title>/, title) }
    { print }
    $0 == "## Question and decision relevance" {
      print ""; print "Question: can the candidate mechanism meet the decision threshold?"
    }
    $0 == "## Executor, baseline, and environment" {
      print ""; print "Executor: fixture-agent; baseline: fixture-head; environment: temporary sandbox."
    }
    $0 == "## Hypothesis, success criterion, and budget" {
      print ""; print "Hypothesis: yes. Success: one bounded observation. Budget: one command."
    }
    $0 == "## Method, reproduction commands, and observations" {
      print ""; print "Method: run fixture command. Observation: bounded fixture result recorded."
    }
    $0 == "## Conclusion, limitations, and remaining uncertainty" {
      print ""; print "Result: " result ". Limitation: fixture evidence only."
    }
  ' "$SKILL/templates/spikes.md" >"$1"
}
run_writer() { "$WRITER" "$@" >"$OUT" 2>"$ERR"; rc=$?; }
count_spikes() { find "$ROOT/.records/spikes" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' '; }

writer_text="$(cat "$WRITER")"
expect_match "writer uses securely created temporary files" 'mktemp ' "$writer_text"
expect_absent_match "writer has no predictable PID temporary path" 'tmp\.\$\$' "$writer_text"

draft_body "$INPUT/draft.md" 'Cache design'
run_writer draft-save --root "$ROOT" --slug cache-design \
  --title 'Cache design' --body "$INPUT/draft.md"
expect_eq "draft save succeeds" 0 "$rc"
expect_eq "draft path is owner-first" 'path=.agents/skilldata/architect/drafts/cache-design.md' "$(cat "$OUT")"
expect_match "draft keeps title" '^# Cache design$' "$(cat "$ROOT/.agents/skilldata/architect/drafts/cache-design.md")"

printf '\nSaved detail.\n' >>"$INPUT/draft.md"
run_writer draft-save --root "$ROOT" --slug cache-design \
  --title 'Cache design' --body "$INPUT/draft.md"
expect_eq "same-title draft updates" 0 "$rc"
expect_match "draft update is visible" 'Saved detail\.' "$(cat "$ROOT/.agents/skilldata/architect/drafts/cache-design.md")"

sentinel="$T/temp-sentinel"; printf 'unchanged\n' >"$sentinel"
planted="$ROOT/.agents/skilldata/architect/drafts/.cache-design.md.tmp.planted"
ln -s "$sentinel" "$planted"
run_writer draft-save --root "$ROOT" --slug cache-design \
  --title 'Cache design' --body "$INPUT/draft.md"
expect_eq "planted temporary symlink does not block safe save" 0 "$rc"
expect_eq "planted temporary symlink target is untouched" 'unchanged' "$(cat "$sentinel")"
expect_eq "writer does not consume planted temporary symlink" "$sentinel" "$(readlink "$planted")"
rm -f "$planted"

draft_body "$INPUT/other.md" 'Other design'
run_writer draft-save --root "$ROOT" --slug cache-design \
  --title 'Other design' --body "$INPUT/other.md"
expect_eq "different title cannot claim slug" 2 "$rc"
expect_match "collision explains refusal" 'different title' "$(cat "$ERR")"

run_writer draft-save --root "$ROOT" --slug ../escape \
  --title 'Cache design' --body "$INPUT/draft.md"
expect_eq "unsafe draft slug refuses" 2 "$rc"

symlink_root="$T/symlink-root"; mkdir -p "$symlink_root/outside" "$symlink_root/.agents"; ln -s "$symlink_root/outside" "$symlink_root/.agents/skilldata"
run_writer draft-save --root "$symlink_root" --slug cache-design \
  --title 'Cache design' --body "$INPUT/draft.md"
expect_eq "symlinked workspace refuses" 2 "$rc"
expect_eq "interrupted draft has no spike" 0 "$(count_spikes)"

sed 's/<title>/Empty feasibility/' "$SKILL/templates/spikes.md" >"$INPUT/empty-spike.md"
run_writer spike-publish --root "$ROOT" \
  --title 'Empty feasibility' --body "$INPUT/empty-spike.md"
expect_eq "empty spike refuses publication" 2 "$rc"
expect_match "empty spike names missing evidence" 'section must contain evidence' "$(cat "$ERR")"
expect_eq "empty spike creates no record" 0 "$(count_spikes)"

spike_body "$INPUT/spike.md" 'Cache feasibility' positive
run_writer spike-publish --root "$ROOT" \
  --title 'Cache feasibility' --body "$INPUT/spike.md"
expect_eq "file-mode spike publishes" 0 "$rc"
first="$(sed -n 's/^path=//p' "$OUT")"
expect_match "file-mode spike path" '^\.records/spikes/[0-9]{4}-[0-9]{2}-[0-9]{2}-cache-feasibility\.md$' "$first"
first_text="$(cat "$ROOT/$first")"
expect_match "spike is directly published" '^status: published$' "$first_text"
expect_match "spike owns schema" '^schema: architect/spike@1$' "$first_text"
expect_match "spike owns tags" '^tags: \[spike, feasibility\]$' "$first_text"
expect_match "spike records executor context" '^Executor: fixture-agent; baseline: fixture-head; environment: temporary sandbox\.$' "$first_text"
expect_match "spike records positive conclusion" '^Result: positive\.' "$first_text"
first_sum="$(cksum "$ROOT/$first")"

run_writer spike-publish --root "$ROOT" \
  --title 'Cache feasibility' --body "$INPUT/spike.md"
expect_eq "same-title spike creates successor" 0 "$rc"
second="$(sed -n 's/^path=//p' "$OUT")"
expect_absent_match "successor has a distinct path" "^${first}$" "$second"
expect_eq "predecessor bytes stay unchanged" "$first_sum" "$(cksum "$ROOT/$first")"

result_root="$T/result-root"; mkdir -p "$result_root"
for result in negative inconclusive; do
  case "$result" in negative) result_title='Negative feasibility' ;; *) result_title='Inconclusive feasibility' ;; esac
  spike_body "$INPUT/$result.md" "$result_title" "$result"
  run_writer spike-publish --root "$result_root" \
    --title "$result_title" --body "$INPUT/$result.md"
  expect_eq "$result spike publishes" 0 "$rc"
  result_path="$(sed -n 's/^path=//p' "$OUT")"
  expect_match "$result conclusion is retained" "^Result: $result\\." "$(cat "$result_root/$result_path")"
done

spike_body "$INPUT/successor.md" 'Cache feasibility follow-up'
printf '\nSupersedes evidence in → %s.\n' "${first#.records/}" >>"$INPUT/successor.md"
run_writer spike-publish --root "$ROOT" \
  --title 'Cache feasibility follow-up' --body "$INPUT/successor.md"
expect_eq "linked successor publishes" 0 "$rc"
successor="$(sed -n 's/^path=//p' "$OUT")"
expect_match "successor cites predecessor" "→ ${first#.records/}" "$(cat "$ROOT/$successor")"

printf '\n→ %s\n' "${successor#.records/}" >>"$INPUT/draft.md"
run_writer draft-save --root "$ROOT" --slug cache-design \
  --title 'Cache design' --body "$INPUT/draft.md"
expect_eq "draft accepts spike link" 0 "$rc"
expect_match "draft links completed spike" "→ ${successor#.records/}" "$(cat "$ROOT/.agents/skilldata/architect/drafts/cache-design.md")"

cp "$INPUT/spike.md" "$INPUT/bad-spike.md"
sed -i.bak '/^## Conclusion, limitations, and remaining uncertainty$/d' "$INPUT/bad-spike.md"
before="$(count_spikes)"
run_writer spike-publish --root "$ROOT" \
  --title 'Cache feasibility' --body "$INPUT/bad-spike.md"
expect_eq "malformed spike refuses" 2 "$rc"
expect_eq "malformed spike creates no record" "$before" "$(count_spikes)"

STUB="$T/records.sh"
# shellcheck disable=SC2016 # The quoted text below is the generated stub's source.
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -eu' 'root="${0%/.records/records.sh}"; records=.records'
  printf '%s\n' 'mode="$1"; shift' 'if [ "$mode" = new ]; then'
  printf '%s\n' '  mkdir -p "$root/$records/spikes"' '  path="$root/$records/spikes/2099-01-01-tool-spike.md"'
  printf '%s\n' "  printf '%s\\n' '---' 'doctype: spikes' 'status: draft' 'schema: architect/spike@1' 'tags: [spike, feasibility]' '---' '' '# placeholder' >\"\$path\""
  printf '%s\n' '  printf "%s\n" "$path"' 'else'
  printf '%s\n' '  rel="$1"; shift' '  tmp="$root/$records/$rel.tmp"'
  printf '%s\n' '  [ -z "${FAIL_TOUCH:-}" ] || exit 9'
  printf '%s\n' "  sed 's/^status: draft\$/status: published/' \"\$root/\$records/\$rel\" >\"\$tmp\""
  printf '%s\n' '  mv "$tmp" "$root/$records/$rel"' 'fi'
} >"$STUB"
chmod +x "$STUB"
tool_root="$T/tool-root"; mkdir -p "$tool_root/.records"; cp "$STUB" "$tool_root/.records/records.sh"; chmod +x "$tool_root/.records/records.sh"
run_writer spike-publish --root "$tool_root" \
  --title 'Cache feasibility' --body "$INPUT/spike.md"
expect_eq "tool-mode spike publishes" 0 "$rc"
tool_path="$(sed -n 's/^path=//p' "$OUT")"
tool_text="$(cat "$tool_root/$tool_path")"
expect_eq "tool-mode stays in spike store" '.records/spikes/2099-01-01-tool-spike.md' "$tool_path"
expect_match "tool-mode body replaces placeholder" '^# Cache feasibility$' "$tool_text"
expect_match "tool-mode status matches file mode" '^status: published$' "$tool_text"

fail_root="$T/fail-root"; mkdir -p "$fail_root/.records"; cp "$STUB" "$fail_root/.records/records.sh"; chmod +x "$fail_root/.records/records.sh"
FAIL_TOUCH=1 "$WRITER" spike-publish --root "$fail_root" \
  --title 'Cache feasibility' --body "$INPUT/spike.md" \
  >"$OUT" 2>"$ERR"; rc=$?
expect_eq "tool failure is returned" 9 "$rc"
failed_record="$fail_root/.records/spikes/2099-01-01-tool-spike.md"
expect_match "tool failure leaves a draft" '^status: draft$' "$(cat "$failed_record")"
expect_match "failed draft still has complete body" '^# Cache feasibility$' "$(cat "$failed_record")"

# Retired home selectors refuse, while noncanonical canaries remain untouched.
for selector in --workspace --records-root --workspace-root --records-tool; do
  rejected="$T/rejected-${selector#--}"; mkdir -p "$rejected/custom"; printf 'CANARY\n'>"$rejected/custom/keep"
  run_writer draft-save --root "$rejected" "$selector" custom --slug rejected --title Rejected --body "$INPUT/draft.md"
  expect_eq "$selector refuses" 2 "$rc"
  expect_eq "$selector preserves canary" CANARY "$(cat "$rejected/custom/keep")"
  expect_eq "$selector creates no fixed roots" no "$([ -e "$rejected/.agents/skilldata" ] || [ -e "$rejected/.records" ] && printf yes || printf no)"
done

PROMO_ROOT="$T/promo-root"; mkdir -p "$PROMO_ROOT"
draft_body "$INPUT/promo.md" 'Promotable idea'
run_writer draft-save --root "$PROMO_ROOT" --slug promotable-idea \
  --title 'Promotable idea' --body "$INPUT/promo.md"
expect_eq "promotion source begins active" 0 "$rc"
expect_match "source is active before spec exists" '^Disposition: active$' \
  "$(cat "$PROMO_ROOT/.agents/skilldata/architect/drafts/promotable-idea.md")"
mkdir -p "$PROMO_ROOT/.records/specs"
printf '%s\n' '---' 'doctype: specs' 'status: draft' 'schema: architect/spec@1' \
  'tags: [spec]' '---' '' '# Promotable idea — Spec' \
  >"$PROMO_ROOT/.records/specs/2099-01-01-promotable-idea.md"
sed 's/^Disposition: active$/Disposition: promoted/' "$INPUT/promo.md" >"$INPUT/promoted.md"
printf '\n→ specs/2099-01-01-promotable-idea.md\n' >>"$INPUT/promoted.md"
run_writer draft-save --root "$PROMO_ROOT" --slug promotable-idea \
  --title 'Promotable idea' --body "$INPUT/promoted.md"
expect_eq "draft promotes after spec creation" 0 "$rc"
promo_text="$(cat "$PROMO_ROOT/.agents/skilldata/architect/drafts/promotable-idea.md")"
expect_match "promoted disposition persists" '^Disposition: promoted$' "$promo_text"
expect_match "promoted draft cites existing spec" '→ specs/2099-01-01-promotable-idea\.md' "$promo_text"

leaks() {
  find "$ROOT" -type f \
    ! -path "$ROOT/.agents/skilldata/architect/drafts/*.md" \
    ! -path "$ROOT/.records/spikes/*.md" | wc -l | tr -d ' '
}
experiment="$T/disposable-experiment"
mkdir -p "$experiment/code" "$experiment/fixtures" "$experiment/generated" "$experiment/build"
printf 'probe\n' >"$experiment/code/probe.sh"
printf 'input\n' >"$experiment/fixtures/input.txt"
printf 'measurement\n' >"$experiment/generated/result.txt"
printf 'object\n' >"$experiment/build/probe.o"
expect_eq "disposable experiment stays outside project" 0 "$(leaks)"
expect_eq "writer leaves only authorized durable payload" 0 "$(leaks)"
printf 'canary\n' >"$ROOT/leak.bin"
expect_eq "isolation canary detects contamination" 1 "$(leaks)"

finish
