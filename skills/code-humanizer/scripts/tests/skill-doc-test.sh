#!/usr/bin/env bash
# skill-doc-test.sh — grep gates on the live package. Red-proofs the stop.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
if [ -n "${CODE_HUMANIZER_SKILL_UNDER_TEST:-}" ]; then
  SKILL="$CODE_HUMANIZER_SKILL_UNDER_TEST"
fi
. "$DIR/lib.sh"

for v in mark map walk; do
  if [ -f "$SKILL/verbs/$v.md" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: missing verbs/$v.md" >&2
    fail=$((fail + 1))
  fi
  if grep -qF "\`verbs/$v.md\`" "$SKILL/SKILL.md"; then
    pass=$((pass + 1))
  else
    echo "FAIL: SKILL.md does not cite verbs/$v.md" >&2
    fail=$((fail + 1))
  fi
done

flatten() { tr '\n' ' ' < "$1" | tr -s ' '; }
router="$(flatten "$SKILL/SKILL.md")"
description="$(sed -n 's/^description: //p' "$SKILL/SKILL.md" | head -n 1)"
description_text="${description#\"}"
description_text="${description_text%\"}"
description_chars="$(printf '%s' "$description_text" | wc -c | tr -d ' ')"
mark="$(flatten "$SKILL/verbs/mark.md")"
map="$(flatten "$SKILL/verbs/map.md")"
walk="$(flatten "$SKILL/verbs/walk.md")"
landmarks="$(flatten "$SKILL/references/landmarks.md")"

if [ "$description_chars" -le 220 ]; then
  pass=$((pass + 1))
else
  echo "FAIL: description exceeds catalog-safe prefix — chars=$description_chars max=220" >&2
  fail=$((fail + 1))
fi
expect_match "description routes durable product source" 'durable app/service/library/CLI or maintained tests' "$description"
expect_match "description routes explicit requests" 'humanize/format/indent/mark/map/walk' "$description"
expect_match "description hard-excludes infrastructure" 'Never infrastructure/deployment/CI/build' "$description"
expect_match "description excludes repository scripts" 'No auto-use for repo scripts' "$description"
expect_match "description excludes disposable and generated code" 'throwaway/generated/vendor code' "$description"
expect_match "description excludes fixtures" 'fixtures/snapshots' "$description"
expect_match "applicability uses role and lifecycle" 'role and intended lifecycle' "$router"
expect_match "applicability distinguishes shipped CLIs" 'shipped CLI.*repository script' "$router"
expect_match "ambiguous implicit application skips" 'ambiguous.*skip the implicit write-time standard' "$router"
expect_match "explicit supported override" 'Explicit invocation bypasses the automatic exclusions for supported non-infrastructure code' "$router"
expect_match "infrastructure refuses before scope" 'before dispatch, file listing, or editing' "$router"
expect_match "quality starts with correctness" 'Correctness and task constraints come first' "$router"
expect_match "quality follows project fit" 'repository instructions, formatter configuration, established architecture' "$router"
expect_match "quality prefers cohesive design" 'simplest cohesive implementation' "$router"
expect_match "quality includes scanability" 'Visually scannable code' "$router"
expect_match "quality ends with verification" "host's applicable tests" "$router"
expect_match "write-time limits changed scope" 'introduces or materially reshapes' "$router"
expect_match "write-time limits formatting context" 'immediate formatting context' "$router"
expect_match "legacy touch is not cleanup" 'Merely touching a legacy file' "$router"
expect_match "function shape is responsibility-based" 'responsibility and control flow are understandable together' "$router"
expect_match "file shape is cohesion-based" 'contents change for the same reason' "$router"
expect_match "comments and docstrings are conditional" 'File-purpose comments and public docstrings are conditional' "$router"
expect_match "quality makes risks explicit" 'invariants, failure behavior, resource ownership, and edge cases' "$router"
expect_match "quality restrains public surface" 'no unnecessary public surface' "$router"
expect_match "write-time forbids extra sweep" 'Do not start a second sweep of the tree' "$router"
expect_match "formatter precedence starts with host" 'documented formatting command and checked-in configuration' "$router"
expect_match "formatter scope is narrow" 'narrowest supported touched scope' "$router"
expect_match "formatter config is protected" 'Do not install a formatter, add or alter formatter configuration, or silently run a repository-wide reformat' "$router"
expect_match "manual indentation follows local style" 'tabs-versus-spaces choice, indentation depth, continuation alignment' "$router"
expect_match "indentation-sensitive safe path" 'trusted formatter to parseable code or adjust continuation whitespace' "$router"
expect_match "ambiguous indentation stops" 'must not guess at ambiguous nesting' "$router"
expect_match "verification is reused" 'do not repeat it solely because code-humanizer loaded' "$router"
expect_match "no-floor records.sh" 'Missing `records.sh` is not an error' "$router"
expect_match "no-floor journal standup" 'Journal standup is never a precondition' "$router"
expect_match "schema is package-owned" 'code-humanizer/map@1' "$router"
expect_match "records home literal" '<agent-records>/maps/' "$router"
expect_match "default cap 20" 'Default cap is 20' "$router"
expect_match "scope script cited" 'scripts/scope.sh' "$router"
expect_match "not-v1 excludes broad quality work" 'Review, debugging, audit, and broad refactoring' "$router"
expect_match "edges produce record" 'produces: record' "$router"

expect_match "mark stops before edits" 'Wait for a short go-ahead' "$mark"
expect_match "mark same-breath ban" 'Do not print the summary and edit in the same breath' "$mark"
expect_match "mark previews formatting" 'landmarks, formatter application, or manual whitespace adjustment' "$mark"
expect_match "mark allows presentation edits" 'comments, docstrings, blank lines, semantics-neutral whitespace' "$mark"
expect_match "mark allows canonical formatter output" "project's formatter" "$mark"
expect_match "mark forbids semantic edits" 'identifiers, APIs, behavior, control flow, abstractions, dependencies, or file boundaries' "$mark"
expect_match "mark stops on formatter failure" 'parse error, ambiguous indentation, or a change that cannot be shown semantics-preserving' "$mark"
expect_match "mark does not commit" 'Do not commit; git is the review' "$mark"
expect_match "mark reads landmarks" 'references/landmarks.md' "$mark"
expect_match "dot is not whole-repo" 'A path of `.` is not that permission' "$mark"

expect_match "map is conversational default" 'lives in the conversation unless the human asks to save' "$map"
expect_match "map stamps revision" 'Built against:' "$map"
expect_match "map verify before trusting" 'Verify before trusting' "$map"
expect_match "map no paste" 'Do not paste function bodies' "$map"

expect_match "walk pauses" 'After the first two or three stops, ask whether to continue' "$walk"
expect_match "walk no mark side-effect" 'Do not mark source as a side effect of a walk' "$walk"

expect_match "landmarks why-not-what" 'Why, not what' "$landmarks"
expect_match "landmarks formatter precedence" 'Repository command and checked-in configuration' "$landmarks"
expect_match "landmarks safe indentation" 'Indentation-sensitive languages' "$landmarks"
expect_match "landmarks readability theater" 'Readability theater' "$landmarks"
expect_match "landmarks mark boundary" '`mark` may change presentation, not meaning' "$landmarks"

# --- red-proof: the stop needle is actually in the file (plant would hit) ---
tmp="$(mktemp -d "${TMPDIR:-/tmp}/code-humanizer-doc.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
planted="$(printf '%s\n' "$mark" | sed 's/Wait for a short go-ahead./Then edit immediately./')"
if [ "$planted" = "$mark" ]; then
  echo "FAIL: stop-phrase plant did not apply (needle missing or drifted)" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
printf '%s\n' "$planted" > "$tmp/mark.planted"
if grep -q 'Wait for a short go-ahead' "$tmp/mark.planted"; then
  echo "FAIL: planted copy still has the stop" >&2
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi
if grep -q 'Wait for a short go-ahead' "$SKILL/verbs/mark.md"; then
  pass=$((pass + 1))
else
  echo "FAIL: live mark.md lost the stop while planting a copy" >&2
  fail=$((fail + 1))
fi

finish
