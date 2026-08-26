#!/usr/bin/env bash
set -euo pipefail
HERE="$(CDPATH='' cd -P "$(dirname "$0")" && pwd)"
SKILL="$(CDPATH='' cd -P "$HERE/../.." && pwd)"
REVIEW="$SKILL/verbs/review.md"
pass=0 fail=0
has() { if grep -qF -- "$2" "$1"; then pass=$((pass + 1)); else echo "FAIL $3" >&2; fail=$((fail + 1)); fi; }
eq() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else echo "FAIL $1 expected=$2 got=$3" >&2; fail=$((fail + 1)); fi; }

has "$REVIEW" 'If you want, I can fold these findings with `/inspector' "failing refine offer missing"
has "$REVIEW" 're-review the amended document' "failing refine offer does not disclose queued re-review"
has "$REVIEW" 'If you accept, this session will publish' "passing publish offer missing"
has "$REVIEW" 'Do not offer publish, refine, or' "implementation close guard missing"
has "$REVIEW" 'write nothing; stay draft' "passing reject guard missing"
has "$REVIEW" 'ask once whether they accept the verdict' "passing unclear guard missing"
has "$REVIEW" 'and re-review queued by default' "failing next-turn parse does not carry re-review"

transition() {
  local kind="$1" verdict="$2" answer="${3:-}"
  [ "$kind" = implementation ] && { echo verdict-only; return; }
  if [ "$verdict" = needs-rework ]; then
    case "$answer" in refine|revise|fold) echo refine-next-queued ;; stop|"not yet") echo no-write ;; *) echo ask ;; esac
  else
    case "$answer" in yes|approved|proceed) echo publish-reviewed ;; stop|"not yet"|refine) echo no-write ;; *) echo ask ;; esac
  fi
}
eq "failing review queues re-review on next-turn refine" refine-next-queued "$(transition document needs-rework refine)"
eq "passing review waits for accept" ask "$(transition document approve '')"
eq "passing acceptance publishes" publish-reviewed "$(transition document approve approved)"
eq "passing rejection writes nothing" no-write "$(transition document approve 'not yet')"
eq "implementation has no transition" verdict-only "$(transition implementation needs-rework refine)"

ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
printf '%s\n' '---' 'status: draft' 'updated: 2026-08-01' '---' > "$ROOT/reviewed.md"
cp "$ROOT/reviewed.md" "$ROOT/other.md"
sed -e 's/status: draft/status: published/' -e 's/updated: 2026-08-01/updated: 2026-08-24/' \
  "$ROOT/reviewed.md" > "$ROOT/next"; mv "$ROOT/next" "$ROOT/reviewed.md"
has "$ROOT/reviewed.md" 'status: published' "accepted artifact not published"
has "$ROOT/other.md" 'status: draft' "acceptance changed another artifact"

echo "review-close-test: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
