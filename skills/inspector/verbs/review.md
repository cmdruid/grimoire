# `review` · critique a spec, plan, or named kind

Independent second-set-of-eyes on a **document** — distinct from the
author's self-check. Findings + a verdict in **conversation**. It
reviews **documents, not diffs** — a code change is the host's
code-review tooling.

Kind-detect is the only artifact gate (SKILL.md *Kind-detect*). The
six bundled kinds are in-scope. Unknown kind → ask or refuse; do
not invent a rubric. Do not amend. Do not mint a record.

## Procedure

1. **Read the whole doc; detect its kind** per SKILL.md
   *Kind-detect*. Load the kind file (workspace copy if present,
   else bundled `kinds/<kind>.md`). Summon station context per
   SKILL.md after the kind is known. Unknown kind → ask or refuse
   here; stop.
2. **Axis 1 — soundness** (internally consistent, feasible): use
   the kind file's soundness axes. Shared floor, unless the kind
   file replaces it: no section contradicts another; the approach
   is justified with alternatives honestly weighed; the mechanism
   is implementable as written; scope is one artifact's worth;
   every requirement is unambiguous; a **numeric acceptance
   target** must attribute its population to the mechanism's
   target class; every **guard/absence-style test** ("asserts X
   never happens") needs a **red-proof** — disable the guarded
   mechanism once and show the test fails, or argue concretely
   why the fixture can exercise the failing arm.
3. **Axis 2 — groundedness** (conforms to the codebase — and to
   core doctrine when a workshop is present): run this package's
   `scripts/ground-check.sh` `<root> <doc>`, then **re-read the
   load-bearing signatures/code the claims rest on** (a clean
   ground-check finds moved files; the trap is a confident doc
   citing a function that never existed — or a `file:line` that
   resolves but points at different code than the prose claims).
   On a workshop host, check the doc against `core/` (invariants,
   gotchas) and the `status: published` spec + live ADRs. Apply
   the kind file's groundedness extras (or "none beyond
   ground-check + re-read").
4. **Report the verdict, in context**: open with one sentence the
   human can act on (what is wrong with the document, or that it
   is ready), then the code `approve` / `approve-with-changes` /
   `needs-rework`. Findings ranked by severity, each as location
   → what's wrong → why it matters → a concrete fix, must-fix
   separated from nice-to-have; a confidence note on anything
   unsure — never a guess presented as fact.

   Verdict words stay **conversation-only**. Do not create or
   append `## Review history`. Do not write `status:` or
   `stage:` **in this turn**.

   - **Failing** (`needs-rework`): stop. Leave `draft`. Do not
     write front-matter.
   - **Passing** (`approve` or `approve-with-changes`): dump the
     verdict. Wait (step 5). Do not write front-matter in this
     turn.

5. **After a passing verdict — wait for accept.** One sentence
   the human can act on: the document is ready; if they accept,
   this session writes `published` on `<path>`. Then **stop**.
   Confirm-parse the next utterance (compositional):

   1. **Reject** (closed set): `stop` / `don't` / `not yet` /
      `refine` / `needs work` → do not write. Stay `draft`.
   2. **Accept** (open set): any clear acceptance of the
      verdict. Examples: `yes`, `looks good`, `approved`,
      `proceed`, `do it`, `lgtm`, `ok`, `go ahead`. A request
      to sequence or walk the accepted document is accept.
      **Do:** write the gate on the artifact just reviewed
      (below), **then** honor the rest of that utterance.
      Founding-shaped: do **not** write `published`; stay
      `draft`.
   3. **Unclear** → ask once whether they accept the verdict.
      Do not write. Do not start a walk or a sequence.

   **Write (accept only).** Opportunistic
   `records.sh touch --status published` when the tool exists;
   else file-mode `status: published` and `updated:`. Job
   artifacts (`plan` / `roadmap` / `runbook`): also
   `stage: approved` in front-matter (`records.sh` has no
   `--stage` writer). Specs and ADRs: `published` only. Then
   stop, unless the same utterance asked for further work.

Depth dial (default off): for a high-stakes artifact, dispatch a
few **read-only** subagents in parallel — each a distinct lens,
one a skeptic trying to *refute* the doc's central claim — and
synthesize. Never an editing subagent.

This verb does not amend the body. Fold is `refine`.
