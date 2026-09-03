#!/usr/bin/env bash
# Common helper responses stay compact and do not expose internal state.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
. "$DIR/lib.sh"
HELPER="$(cd "$DIR/.." && pwd)/workstream.sh"
SKILL="$(cd "$DIR/../.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/workstream-envelope.XXXXXX")"
TMP="$(cd "$TMP" && pwd -P)"
ROOT="$TMP/project"
OUT="$TMP/out"
trap 'rm -rf "$TMP"' EXIT

init_repo "$ROOT"
printf 'fixture\n' >"$ROOT/file.txt"
git -C "$ROOT" add file.txt
git -C "$ROOT" commit -qm initial

assert_envelope() {
  local label="$1" file="$2" lines longest
  lines="$(awk 'NF{count++} END{print count+0}' "$file")"
  longest="$(awk '{if(length($0)>max)max=length($0)} END{print max+0}' "$file")"
  if [ "$lines" -le 12 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label has $lines nonempty lines" >&2; fi
  if [ "$longest" -le 1024 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label has a $longest-byte line" >&2; fi
  expect_absent "$label hides tracker header" $'record\tid\tfield\tvalue' "$file"
  expect_absent "$label hides hook body" 'feature-completion' "$file"
  expect_absent "$label hides tabular rows" $'meta\t-\t' "$file"
}

check_read_budgets() { # skill-root; prints the declared mandatory populations
  local base="$1" router load ship
  router="$(wc -c <"$base/SKILL.md" | tr -d ' ')"
  load=$((router + $(wc -c <"$base/verbs/load.md" | tr -d ' ') + $(wc -c <"$base/templates/workstream-runbook.md" | tr -d ' ')))
  ship=$((router + $(wc -c <"$base/verbs/ship.md" | tr -d ' ') + $(wc -c <"$base/templates/workstream-runbook.md" | tr -d ' ')))
  printf 'read-population router SKILL.md %s\n' "$router"
  printf 'read-population load SKILL.md+verbs/load.md+templates/workstream-runbook.md %s\n' "$load"
  printf 'read-population ship SKILL.md+verbs/ship.md+templates/workstream-runbook.md %s\n' "$ship"
  [ "$router" -le 10000 ] && [ "$load" -le 20000 ] && [ "$ship" -le 20000 ]
}

"$HELPER" "$ROOT" runtime-init concise main 'Keep runtime reads concise' >"$OUT"
assert_envelope 'runtime-init' "$OUT"
"$HELPER" "$ROOT" state concise >"$OUT"
assert_envelope 'state' "$OUT"
expect 'state identifies schema' 'schema=workstream-state@1' "$OUT"
expect 'state emits one action' 'next_action=define-unit' "$OUT"
expect_eq 'state has one next-action row' 1 "$(grep -c '^next_action=' "$OUT")"
"$HELPER" "$ROOT" read concise >"$OUT"
assert_envelope 'read' "$OUT"
expect 'read exposes admitted worktree' "worktree=$ROOT/.streams/concise" "$OUT"
expect 'read exposes effective coordinates' 'coordinates=branch:stream/concise,target:main,landing:local' "$OUT"
expect 'read exposes effective policy' 'policy=mode:delegate,ship-cadence:milestone' "$OUT"
expect 'read exposes durable queue source' 'queue=source-kind:brief,source:-,state:intake' "$OUT"
cp "$OUT" "$TMP/named-read"
"$HELPER" "$ROOT" read-current "$ROOT/.streams/concise" >"$OUT"
if cmp -s "$TMP/named-read" "$OUT"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: named and current reads differ' >&2; fi
"$HELPER" "$ROOT" unit-begin concise bounded 'Bounded active summary' >"$OUT"
"$HELPER" "$ROOT" read concise >"$OUT"
expect 'read exposes active unit identity' 'unit=id:1,slug:bounded,summary:Bounded active summary' "$OUT"

scaffold_bytes="$(wc -c <"$ROOT/.streams/concise/WORKSTREAM.md" | tr -d ' ')"
if [ "$scaffold_bytes" -le 4000 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: generated runbook is $scaffold_bytes bytes" >&2; fi

if check_read_budgets "$SKILL"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo 'FAIL: mandatory read population exceeds budget' >&2; fi

# Each ceiling is mutation-proven in a disposable package copy.
for budget_case in router load ship; do
  COPY="$TMP/$budget_case-skill"
  mkdir -p "$COPY/verbs" "$COPY/templates"
  cp "$SKILL/SKILL.md" "$COPY/SKILL.md"
  cp "$SKILL/verbs/load.md" "$COPY/verbs/load.md"
  cp "$SKILL/verbs/ship.md" "$COPY/verbs/ship.md"
  runbook_name="workstream-runbook.md"
  cp "$SKILL/templates/$runbook_name" "$COPY/templates/$runbook_name"
  case "$budget_case" in
    router) awk 'BEGIN{for(i=0;i<11000;i++)printf "x"}' >>"$COPY/SKILL.md" ;;
    load) awk 'BEGIN{for(i=0;i<20000;i++)printf "x"}' >>"$COPY/verbs/load.md" ;;
    ship) awk 'BEGIN{for(i=0;i<20000;i++)printf "x"}' >>"$COPY/verbs/ship.md" ;;
  esac
  if check_read_budgets "$COPY" >/dev/null; then
    fail=$((fail + 1)); echo "FAIL: $budget_case budget mutation stayed green" >&2
  else
    pass=$((pass + 1))
  fi
done

report 'workstream read envelope'
