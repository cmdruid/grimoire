---
doctype: design
status: current
created: 2026-08-17
updated: 2026-08-17
tags: [spec]
---

# auditor review — Spec

**Shipped 2026-08-17** on `stream/grok` — subject: `auditor: fold
skill-builder review findings`.

Accepted 2026-08-17 on stream `grok`. Same-session `/skill-builder review
auditor` against `skills/agent-council/briefs/skill-review.md`. Verdict:
**needs-rework**. The human asked to remediate the findings; this file
is the governing spec for that fold. It is the review report plus the
receiving locks — not a restatement of the skill.

Target (unchanged by the review verb):
`/Users/cscott/Repos/grimoire/.workstreams/grok/skills/auditor/`

Brief:
`/Users/cscott/Repos/grimoire/.workstreams/grok/skills/agent-council/briefs/skill-review.md`

## Facts (Pass 1)

lint fails=0 warns=1 (target-relevant):

- `WARN: auditor: ~/.claude/skills/auditor resolves to /Users/cscott/Repos/grimoire/skills/auditor, not this clone`

Expected worktree-vs-clone note. Not a finding.

## Findings (the requirements)

### 1. high — Setup playbook writes the 12 rules from an empty skeleton
Location: `skills/auditor/BOOTSTRAP.md:269-271` vs `skills/auditor/SKILL.md:88-98`
Class: must-fix

`SKILL.md` setup says follow `BOOTSTRAP.md`, then copy bundled `rules/`
and fill `<language>` slots. `BOOTSTRAP.md` §10 step 2 says write each
rule from the §6 skeleton. Following the named playbook discards the
authored decision logic, false-positives, and quantify recipes.

### 2. high — BOOTSTRAP still stands up a living findings tracker
Location: `skills/auditor/BOOTSTRAP.md:24-26` and `:257-258` vs `:86-87`
and `skills/auditor/SKILL.md:60-61`
Class: must-fix

“How to use” still sells “a tracker that drains into your existing
trackers.” Decision-walk step 5 says “the audit’s tracker can own the
work.” §3 and `SKILL.md` say there is no living findings tracker.

### 3. mid — Non-setup modes never say how to find the standalone home
Location: `skills/auditor/SKILL.md:31-33` and `:55-56`
Class: nice-to-have

Workshop home is a fixed path. Standalone home is “confirmed once”
(default `docs/audit/`). Later modes only say “no rubric yet → setup.”
No detect rule; a non-default confirmation lives only in chat.

### 4. mid — Workshop wiring paths are not rooted
Location: `skills/auditor/SKILL.md:103-104` and
`skills/auditor/BOOTSTRAP.md:277-278`
Class: nice-to-have

Routing hook is `core/ROUTING.md` and chore line is `test/POLICY.md`.
After a workshop probe those are `.handbook/core/ROUTING.md` and
`.handbook/test/POLICY.md`.

### 5. mid — `metrics` and `check` have no done-when; `check` has no failure action
Location: `skills/auditor/SKILL.md:50-52` and `:145-152`
Class: nice-to-have

Done-when covers only pass and setup. `check` “fails” without saying
whether to stop, drain, or continue.

### 6. mid — PERF scoring requires a bench this skill never locates
Location: `skills/auditor/rules/performance.md:22` and `:57-59`
Class: nice-to-have

“Never file a PERF finding without measuring” plus no harness path
means a host without a bench can never file PERF, or the agent invents
a bench.

### 7. mid — Description use-when fires on generic “audit / quality-check”
Location: `skills/auditor/SKILL.md:3`
Class: nice-to-have

`/auditor` and “stand up the audit framework” are precise. “asks to
audit/quality-check the codebase or a module” also matches a PR review,
a docs sweep, or “audit this skill.”

### 8. mid — Drain text still cites “journal’s capture kinds”
Location: `skills/auditor/SKILL.md:73`
Class: nice-to-have

Capture kinds are Backlog / Issues / Feedback. “journal” is a sibling
name after the journal/backlog split.

### 9. mid — GUIDE.md and `metrics.sh` are invented from section lists
Location: `skills/auditor/SKILL.md:99-102` and
`skills/auditor/BOOTSTRAP.md:145-188` vs `:223-242`
Class: nice-to-have

Rules have a verbatim skeleton. The hub and the only script do not.

### 10. low — Theme prefixes are still “finding IDs”
Location: `skills/auditor/BOOTSTRAP.md:116` vs `:197-199`
Class: nice-to-have

§5 says prefixes are used for finding IDs. §7 abolished sequential
IDs. Prefixes stay as the Dimension tag.

### 11. low — “One environment probe” is not true on a workshop host
Location: `skills/auditor/SKILL.md:20-22` vs `:29-30`
Class: nice-to-have

The stamp probe is supposed to be the only host fact. Workshop drain
then reads `AGENTS.md` for `records-root:`.

### 12. low — `<target>` “at its depth” is undefined
Location: `skills/auditor/SKILL.md:53`
Class: nice-to-have

Depth is Deep/Mid/Light from GUIDE’s table. A path not in the table
has no rule.

## Receiving locks (do not fold past these)

Applied 2026-08-17 before planning. Feedback is a claim; these are the
pushbacks.

1. **Host “tracker” words stay.** `<drains>`, “host’s own tracker
   files”, and Backlog/Issues/Feedback tracker *lines* are the host’s
   queues. Only the *audit’s own living findings store* is forbidden.
   Do not grep-replace every “tracker”.
2. **Templates live in `BOOTSTRAP.md`.** `SKILL.md` already says “The
   generic templates live inside it.” Finding 9 is new sections in
   `BOOTSTRAP.md`, not a `skills/auditor/templates/` directory.
3. **Do not add `verbs/`.** Modes stay in the router.
4. **Do not stand the rubric up in this library.** Patient-zero. No
   `docs/audit/` in grimoire. Verify with lint + grep, not `setup`.
5. **Finding 11 is honesty, not a new probe script.** Either mention
   `records-root` as the workshop follow-on of the stamp branch, or
   drop “nothing else about the host is probed.” Do not add a scanner.
6. **Finding 7 must keep** `/auditor`, `setup`, `metrics`, `check`, and
   the workshop/standalone sentence. Description is 721 chars today;
   stay under 1024, prefer ≤750.
7. **Rule-file `Issue theme:` lines stay.** Finding 10 only rewrites
   the “used for finding IDs” claim in `BOOTSTRAP.md` §5.
8. **Empty Calibrated examples / Exemplars stay.** Correct until
   Select-exemplars on a real host.
9. **Independence walk stays on `check`.** Do not run or paste
   `docs/BOUNDARY-AUDIT.md` into this fold.
10. **Sibling `feat` does not own auditor.** Do not drive it. Root
    checkout dirt (mailbox scripts + two untracked design docs) is
    disjoint — do not sweep it into stream commits.

## Out of scope

- Folding findings into a second skill.
- Convening a panel.
- Workshop registration against this library’s `AGENTS.md`.
- Pack version bump (member set unchanged).
- Host leftovers (`./install.sh notepad`, `./install.sh --remove bootstrap`).
