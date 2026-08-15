# agent-council Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land a standalone `skills/agent-council/` package that convenes Claude, Grok, and Codex for an independent two-round review of a skill package and emits a report ranked by agreement.

**Architecture:** Thin driver in `SKILL.md` (the orchestrator never reviews). What to look for lives in `briefs/skill-review.md`. CLI flags live in `references/spawn.md`. The only executable is `scripts/probe-seats.sh` (facts, not a verdict). Ballots are stdout captured into a temp scratch dir.

**Tech Stack:** Portable `SKILL.md` package; bash 3.2; the host's `claude` / `grok` / `codex` CLIs at convene time (not in CI).

**Spec:** `docs/design/2026-08-15-agent-council-skill-design.md`

## Global Constraints

- Standalone library skill at `skills/agent-council/`. Not a `clankshop` member. Absent from `PACK.md`. No workshop detection. Do not edit grimoire's own `AGENTS.md`.
- Scratch-only: no `init`, no front-door registration, no `.council/` in the project, no records-layer drain.
- V1 target is a directory containing `SKILL.md`. Refuse anything else. Do not ship `briefs/feature.md`.
- Agreement is the sort key. Severity is displayed, not sorted on. Review round shows clusters **without** ranks.
- Orchestrator is never a panelist. Same-family stand-ins are forbidden. Seats emit on stdout; orchestrator writes scratch.
- cwd for each seat is the **target skill directory**.
- Description is a trigger, not a protocol summary. `briefs/skill-review.md` names no sibling skill.
- No live convene in CI. Six authenticated headless runs are not a unit test.
- `description:` ≤ ~700 chars (hard cap 1024). Quote it if it contains `: `. Edges name types, not siblings.
- Every task's requirements implicitly include this section and the spec.

## File map

| Path | Responsibility |
|---|---|
| `skills/agent-council/scripts/probe-seats.sh` | Print `claude=` / `grok=` / `codex=` facts |
| `skills/agent-council/scripts/tests/probe-seats-test.sh` | PATH-isolated smoke for the probe |
| `skills/agent-council/scripts/tests/run.sh` | Test entrypoint |
| `skills/agent-council/templates/ballot.md` | Round-1 output contract |
| `skills/agent-council/templates/review.md` | Review-round output contract |
| `skills/agent-council/briefs/skill-review.md` | V1 panelist brief |
| `skills/agent-council/references/spawn.md` | CLI invocations (re-read `--help` per session) |
| `skills/agent-council/SKILL.md` | Trigger, loop, clustering, report, edges |
| `README.md` | Inventory row + pack minus-list |

---

### Task 1: probe-seats.sh

**Files:**
- Create: `skills/agent-council/scripts/tests/probe-seats-test.sh`
- Create: `skills/agent-council/scripts/tests/run.sh`
- Create: `skills/agent-council/scripts/probe-seats.sh`

**Interfaces:**
- Consumes: nothing (PATH only)
- Produces: `scripts/probe-seats.sh` prints exactly three `key=value` lines, keys in order `claude`, `grok`, `codex`, value is `command -v` or empty, exit 0 always, no verdict words

- [ ] **Step 1: Write the failing test**

Create `skills/agent-council/scripts/tests/probe-seats-test.sh`:

```bash
#!/usr/bin/env bash
# probe-seats-test.sh — PATH-isolated smoke for probe-seats.sh.
# Fixtures live in mktemp; nothing touches the real PATH or the library tree
# except reading the script under test.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$(cd "$DIR/../.." && pwd)"
PROBE="$SKILL/scripts/probe-seats.sh"

pass=0
fail=0

expect_eq() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL: $1 — expected: $2  got: $3" >&2
    fail=$((fail + 1))
  fi
}

expect_absent() {
  if printf '%s' "$3" | grep -qE "$2"; then
    echo "FAIL: $1 — expected NOT to match: $2" >&2
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/probe-seats-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
mkdir -p "$BIN"
# Two present, one missing — the degrade case the council actually hits.
: >"$BIN/claude"
: >"$BIN/grok"
chmod +x "$BIN/claude" "$BIN/grok"

OUT="$(PATH="$BIN" /bin/bash "$PROBE")"
expect_eq "three lines" "3" "$(printf '%s\n' "$OUT" | grep -c .)"
expect_eq "claude key" "claude=$BIN/claude" "$(printf '%s\n' "$OUT" | sed -n '1p')"
expect_eq "grok key" "grok=$BIN/grok" "$(printf '%s\n' "$OUT" | sed -n '2p')"
expect_eq "codex empty" "codex=" "$(printf '%s\n' "$OUT" | sed -n '3p')"
expect_absent "no verdict words" '(convene|recommend|should|missing|error|fail)' "$OUT"

EMPTY="$(PATH="/nonexistent-agent-council-$$" /bin/bash "$PROBE")"
expect_eq "empty claude" "claude=" "$(printf '%s\n' "$EMPTY" | sed -n '1p')"
expect_eq "empty grok" "grok=" "$(printf '%s\n' "$EMPTY" | sed -n '2p')"
expect_eq "empty codex" "codex=" "$(printf '%s\n' "$EMPTY" | sed -n '3p')"

echo "probe-seats-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

Create `skills/agent-council/scripts/tests/run.sh`:

```bash
#!/usr/bin/env bash
# run.sh — agent-council test entrypoint. Throwaway PATH fixtures only.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
rc=0
echo "== probe-seats-test.sh"
bash "$DIR/probe-seats-test.sh" || rc=1
if [ "$rc" -eq 0 ]; then
  echo "agent-council tests: ALL GREEN"
else
  echo "agent-council tests: FAILURES" >&2
fi
exit "$rc"
```

`chmod +x` both test scripts.

- [ ] **Step 2: Run the test and confirm it fails**

Run:

```bash
bash skills/agent-council/scripts/tests/run.sh
```

Expected: FAIL because `scripts/probe-seats.sh` does not exist (`/bin/bash: .../probe-seats.sh: No such file or directory`) or the script is empty.

- [ ] **Step 3: Write the probe**

Create `skills/agent-council/scripts/probe-seats.sh`:

```bash
#!/usr/bin/env bash
# probe-seats.sh — print which council CLIs exist. Facts only; never a verdict.
# Usage: scripts/probe-seats.sh
# Prints three lines, always, in this order:
#   claude=<path-or-empty>
#   grok=<path-or-empty>
#   codex=<path-or-empty>
set -u
for name in claude grok codex; do
  path="$(command -v "$name" || true)"
  printf '%s=%s\n' "$name" "$path"
done
```

`chmod +x skills/agent-council/scripts/probe-seats.sh`

- [ ] **Step 4: Run the test and confirm it passes**

Run:

```bash
bash skills/agent-council/scripts/tests/run.sh
```

Expected: `probe-seats-test: 8 passed, 0 failed` and `agent-council tests: ALL GREEN`.

- [ ] **Step 5: Commit**

```bash
git add skills/agent-council/scripts/probe-seats.sh \
        skills/agent-council/scripts/tests/probe-seats-test.sh \
        skills/agent-council/scripts/tests/run.sh
git commit -m "$(cat <<'EOF'
agent-council: probe-seats.sh prints claude/grok/codex facts

PATH-isolated smoke covers the two-present / one-missing case and
the all-empty PATH. No verdict words.
EOF
)"
```

---

### Task 2: the skill package

**Files:**
- Create: `skills/agent-council/templates/ballot.md`
- Create: `skills/agent-council/templates/review.md`
- Create: `skills/agent-council/briefs/skill-review.md`
- Create: `skills/agent-council/references/spawn.md`
- Create: `skills/agent-council/SKILL.md`

**Interfaces:**
- Consumes: `scripts/probe-seats.sh` from Task 1 (backticked from `SKILL.md`)
- Produces: a complete skill directory whose bundled refs resolve; `/agent-council [path]` is followable from `SKILL.md` alone

- [ ] **Step 1: Write `templates/ballot.md`**

```markdown
# Round-1 ballot

Emit one block per opinion, in this shape, on stdout. No preamble that
is itself a claim. No seat tags.

## Opinion

- claim: <one sentence>
- evidence: <path + quote, or file:line>
- action: <what to change>
- severity: high | mid | low
```

- [ ] **Step 2: Write `templates/review.md`**

```markdown
# Review-round reply

For every cluster id you were shown, emit one Reply block. Verdict is
exactly `confirm`, `refine`, or `rescind`. A refine MUST include
replacement claim / evidence / action / severity; omit them and the
orchestrator treats the reply as a confirm.

After the replies, you MAY emit new Opinion blocks in the round-1
ballot shape for claims that are not a refine of an existing cluster.

## Reply

- id: C1
- verdict: confirm
- claim:
- evidence:
- action:
- severity:

## Opinion

- claim: <one sentence>
- evidence: <path + quote, or file:line>
- action: <what to change>
- severity: high | mid | low
```

- [ ] **Step 3: Write `briefs/skill-review.md`**

Do **not** name another skill. Do **not** mention agreement-as-strength or sibling seats.

```markdown
# Skill-package brief

You are reviewing the skill package that is your current working
directory. Read `SKILL.md`, then only the verbs, scripts, docs, and
templates it actually names. Do not tour the rest of any repo.

## Judge

- **Trigger** — will the description fire on the right jobs and skip
  the wrong ones?
- **Followability** — can you execute the procedure without inventing
  steps?
- **Holes** — missing failure states, missing done-when, ambiguous
  branches.
- **Independence** — does it assume a sibling, a pack, or a host layout
  that is not guaranteed?
- **Judgment vs mechanism** — does it ask an agent to compute what a
  script should, or a script to decide what an agent should?
- **Scope** — does it know when to stop?
- **Output shape** — if it produces something, is that shape specified?

## Do not

- Restate the skill.
- Rank anything.
- Propose a rewrite. Emit discrete claims.
- Run a lint or mechanical gate.
- Tag claims with seat letters.
- Read files the skill does not name.
```

- [ ] **Step 4: Write `references/spawn.md`**

```markdown
# Spawn — the harness edge

Re-read each binary's `--help` once per session. Flags drift; this file
is intent plus a last-known surface, not a pin.

The orchestrator writes a prompt file in scratch and captures **stdout**
into `round1/<seat>.md` or `review/<seat>.md`. Codex `-o` is the parent
CLI writing the final message — same idea. Seats do not write scratch.

cwd for every seat is the **target skill directory**. No model pin unless
the user named one for this convene. Read-only: prefer an allow-list of
read tools; otherwise disallow write/edit tools. If a CLI would hang on
a permission prompt, pass its non-interactive approve flag **after**
write tools are already gone.

| Seat | Letter | Binary | Intent |
|---|---|---|---|
| Claude | `c` | `claude` | `claude -p --bare` with write tools disallowed. If the process does not start in the target, `--add-dir <target>`. Allow `Read,Glob,Grep` (or the current equivalents). |
| Grok | `g` | `grok` | `grok -p --cwd <target> --prompt-file <scratch-prompt>`. Disallow write/edit tools (`--disallowed-tools` / `--tools` allow-list — re-read help). `--always-approve` only after writes are gone. |
| Codex | `x` | `codex` | `codex exec --sandbox read-only -c approval_policy="never" -C <target> -o <ballot-or-review-file>` with the prompt as the argument or on stdin. |

Do not retry an identical failed dispatch. Do not substitute a
same-family subagent. The orchestrator's own context is not a seat.
```

- [ ] **Step 5: Write `SKILL.md`**

Create `skills/agent-council/SKILL.md` with exactly this content (do not summarize the two-round protocol in `description:`):

````markdown
---
name: agent-council
description: "Use when the user runs `/agent-council`, asks for a multi-model or cross-vendor review panel, or wants independent Claude, Grok, and Codex opinions on a skill package. Keywords: council, panel, convene, multi-model review, cross-vendor review."
---

# agent-council — a three-family review panel

Convene isolated Claude, Grok, and Codex reviewers against a skill
package, cluster their claims, let them update or rescind, and show one
list ranked by how many seats support each claim. You are the
orchestrator. You never sit on the panel.

Scratch-only: ballots live under `$TMPDIR`. No durable home, no `init`.

## When to use

- Explicit `/agent-council [path]`
- A request for a multi-model / cross-vendor / council / panel review
  of a skill package

**Do not use** for a one-line tweak, a mechanical lint pass, a scored
rubric audit, or when fewer than two seats exist.

## Target

`/agent-council [path]`:

1. A directory that contains `SKILL.md` → that package.
2. A relative path → resolve from cwd, then apply (1).
3. A bare slug → `<git-toplevel>/skills/<slug>/` if that directory
   contains `SKILL.md`.
4. Missing or unresolvable → ask. Do not guess a different brief.

V1 refuses a target that is not a skill package. The brief is always
`briefs/skill-review.md`.

## Loop

1. Resolve the target. No `SKILL.md` → stop.
2. Brief is `briefs/skill-review.md`.
3. Run `scripts/probe-seats.sh`. A missing CLI drops that seat. Fewer
   than two paths → stop (one reviewer is not a council).
4. Confirm cost. Name the seats and that this is up to six headless
   runs (round 1 + review). Wait for a yes. A previous session's yes
   does not count. A no leaves no scratch and no dispatches.
5. Open `$TMPDIR/agent-council-<YYYYMMDDTHHMMSS>-<pid>/`. Print the
   path once. You write every file in it. Layout: `round1/<seat>.md`,
   `review/<seat>.md`, `clusters.md`, `RESULT.md`, plus prompt files.
6. **Round 1.** One isolated, read-only, headless process per present
   seat, **in parallel**, per `references/spawn.md`. cwd is the target
   skill directory. Each prompt (a file in scratch) tells the seat:
   - You are one isolated reviewer. You do not see other reviewers.
   - Read the brief at `<absolute briefs/skill-review.md>`.
   - Emit opinions on stdout in the shape of `<absolute templates/ballot.md>`.
   - Do not edit files. Do not rank. Do not self-tag seats.
   Capture stdout into `round1/<seat>.md`.
7. **Cluster** (rules below). Write `clusters.md` with ids `C1`, `C2`,
   … and support tags. No ranks, no “strongest / weakest” frame.
   Fewer than two successful ballots (missing file, or zero extracted
   `## Opinion` blocks) → stop, say why, do not invent a ranked list.
8. **Review.** Only seats that produced a successful round-1 ballot, in
   parallel, read-only. Each prompt points at `clusters.md`, that
   seat's `round1/<seat>.md`, and `templates/review.md`. A no-show,
   crash, or unparseable reply **holds** that seat's round-1 support
   and is noted. Silence is not a rescind.
9. Re-cluster. Sort by support count. Write `RESULT.md`. Show it.

## Extracting opinions

From a ballot, take every `## Opinion` block that has `claim`,
`evidence`, and `action`. Ignore wrapping prose. Omitted `severity`
→ `mid`. Do not upgrade an omitted severity to `high`. Zero blocks
→ empty.

From a review reply, take every `## Reply` with `id` and `verdict` in
`confirm` / `refine` / `rescind`. A `refine` without replacement
`claim` / `evidence` / `action` / `severity` is a **confirm**. Then
take any extra `## Opinion` blocks as `new`.

## Clustering

Two claims join only when **both** hold:

1. Same artifact (same path or the same named surface).
2. Same assertion (the same change would fix both).

Unsure → split. Never inflate agreement.

Support tags list present seats in order `c`, `g`, `x` — never
`[x,c]`. Cluster severity is the highest among current supporters.
Keep every distinct evidence line. If actions conflict, list both;
if they agree, keep the more specific wording.

| Seat says | Effect |
|---|---|
| confirm | Support stays |
| refine | Same assertion → update cluster text, support stays. Different assertion → new id, that seat **moves** |
| rescind | That seat drops off |
| new | New id, that seat only (merge if another seat filed the same claim this round) |

Conflicting refines that still share an assertion: one wording, prefer
the more specific evidence. Divergent refines: split. A confirm stays
on the original. A cluster with no remaining support leaves the ranked
list and goes under **Rescinded**.

## Report

Show this, and write it to `RESULT.md`. No essay that re-argues claims.

```
# Council: <target>
Brief: skill
Seats: c=claude  g=grok  x=codex
Round 1: c,g,x ok
Review:  c,g ok; x no-show (held)

## Ranked opinions

### 1. [c,g,x] high — <claim>
Evidence: …
Action: …
Status: held

## Rescinded
- [was c,g] — <claim> (c rescinded, g rescinded)

## Seat notes
- x review no-show; round-1 support held

Scratch: <absolute path>
```

Sort by support count only (`[c,g,x]` before `[c,x]` before `[x]`).
Ties keep cluster-id order. Status is `held` / `refined` / `new`.
Rescinded clusters are not numbered.

## Anti-patterns

- Reviewing the target yourself
- Playing the seat that matches your family
- Substituting same-family subagents for a missing CLI
- Showing ranks (or “strongest”) in `clusters.md`
- Retrying an identical failed dispatch
- Inventing a short skill-level timeout
- Editing the project tree or a `.gitignore`

## Done when

Seats probed and cost confirmed; at least two round-1 ballots (or a
stop with the reason); cluster → review (or attempted) → re-cluster;
ranked report shown and written to `RESULT.md`; every dropped or silent
seat is in Seat notes.

## Edges

Scratch-only. The report ends the pass.

<!-- edges:agent-council -->
- produces: review — ranked council report (shown to the user + scratch RESULT.md)
- handoff: — (the report ends the pass)
- consumes: — (a path the user names, not another skill's typed artifact)
<!-- /edges:agent-council -->
````

- [ ] **Step 6: Bundled-ref check**

From the repo root, confirm every backticked bundle path in the new skill resolves:

```bash
python3 - <<'PY'
from pathlib import Path
import re
root = Path("skills/agent-council")
needles = re.compile(r'`((?:scripts|templates|verbs|references|briefs|rules)/[^`]+)`')
missing = []
for md in root.rglob("*.md"):
    text = md.read_text()
    for m in needles.finditer(text):
        p = root / m.group(1)
        if not p.exists():
            missing.append(f"{md}: {m.group(1)}")
print("ok" if not missing else "\n".join(missing))
raise SystemExit(1 if missing else 0)
PY
```

Expected: `ok`.

- [ ] **Step 7: Commit**

```bash
git add skills/agent-council/SKILL.md \
        skills/agent-council/briefs/skill-review.md \
        skills/agent-council/templates/ballot.md \
        skills/agent-council/templates/review.md \
        skills/agent-council/references/spawn.md
git commit -m "$(cat <<'EOF'
agent-council: SKILL.md loop, skill brief, ballot/review contracts, spawn

Orchestrator-only driver. V1 brief is skill packages. Seats emit on
stdout; flags live in references/spawn.md so they can drift.
EOF
)"
```

---

### Task 3: inventory, install, lint

**Files:**
- Modify: `README.md` (skills table + pack minus-list)
- Install: `./install.sh agent-council` (symlink only; not a committed file)
- Test: `skills/skill-builder/scripts/skills-lint.sh` and `skills/agent-council/scripts/tests/run.sh`

**Interfaces:**
- Consumes: the skill directory from Tasks 1–2
- Produces: README mention of `` `agent-council` ``; lint `fails=0`; probe tests still green

- [ ] **Step 1: Add the inventory row**

In `README.md`, insert this as the **first** data row of the skills table (alphabetically before `auditor`):

```markdown
| `agent-council` | three-family review panel: independent Claude, Grok, and Codex opinions on a skill package, clustered and ranked by agreement; standalone, outside every pack |
```

- [ ] **Step 2: Keep it out of the pack**

In `README.md` *The packs* section, change the minus-list so `agent-council` is excluded with the other standalone skills. The line today is:

```markdown
- **`clankshop`** (`skills/clankshop/PACK.md`) — the skills above (minus `bootstrap` and
  `skill-builder`) as one agentic workshop:
```

Replace with:

```markdown
- **`clankshop`** (`skills/clankshop/PACK.md`) — the skills above (minus `agent-council`,
  `bootstrap`, and `skill-builder`) as one agentic workshop:
```

Do **not** edit `skills/clankshop/PACK.md`. Do **not** edit `AGENTS.md`.

- [ ] **Step 3: Install the symlink**

```bash
./install.sh agent-council
```

Expected: `installed agent-council -> ...` or `ok agent-council (already installed)`.

- [ ] **Step 4: Run the skill tests and the lint gate**

```bash
bash skills/agent-council/scripts/tests/run.sh
bash skills/skill-builder/scripts/skills-lint.sh
```

Expected:

- probe tests: ALL GREEN
- lint: `fails=0`
- `agent-council` must not appear in any `FAIL:` line
- A `WARN:` that `review` is a single-use edge type is acceptable (same class as `checkpoint-doc`)
- A wiring WARN must not appear after Step 3
- A README-mention WARN must not appear after Step 1

If lint FAILs on a bundled-ref, frontmatter, edge block, or `bash -n`, fix that file and re-run. Do not suppress the gate.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
agent-council: list it in the README inventory, keep it out of clankshop

Standalone like bootstrap and skill-builder. Lint fails=0.
EOF
)"
```

---

## Spec coverage (self-review)

| Spec section | Task |
|---|---|
| §1 Shape, description, edges, when-not, README, not in PACK.md | Tasks 2, 3 |
| §2 Package layout | Tasks 1, 2 |
| §3 Loop (resolve, brief, probe, confirm, scratch, round 1, cluster, review, rank) | Task 2 `SKILL.md` |
| §4 Opinion contract + malformed / omitted severity | Task 2 templates + `SKILL.md` extract rules |
| §5 Clustering, tags order, refine-without-fields = confirm, no-show holds | Task 2 `SKILL.md` |
| §6 Spawn, stdout capture, cwd = target, no same-family fallback | Task 2 `references/spawn.md` + `SKILL.md` |
| §7 Skill brief, no sibling names, no ranking rule | Task 2 `briefs/skill-review.md` |
| §8 Report shape and sort | Task 2 `SKILL.md` |
| §9 Done when | Task 2 `SKILL.md` |
| §10 Non-goals (no feature brief, no journal drain, no verb table) | Global constraints + Task 2 does not add those files |
| §12 Gate + probe smoke, no live convene in CI | Tasks 1, 3 |

No live-convene task on purpose (spec §12).
