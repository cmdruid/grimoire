---
doctype: specs
status: published
schema: architect/spec@1
tags: [skill-feedback, backlog, skill-design, global-state]
---

# Global skill feedback capture and guided tuning — Spec

## Problem

Grimoire's authoring doctrine treats concrete friction, gaps, and wins from real skill use as the
signal that improves a skill. The current default sends public feedback to GitHub issues, while an
installation may override that route with a local collection file. Neither route supplies a
self-contained operating mechanism for the common local-capture case: an agent uses globally installed
skills across many projects, notices something that would change a skill, and needs to preserve that
evidence where the skill author can later review it.

Project trackers are the wrong home because cross-project skill feedback strands with the consuming
project. A public issue is often too much friction for immediate capture and may disclose private
project context. A hand-edited global Markdown file lowers that barrier but still depends on the
agent remembering a format, safely editing shared mutable state, avoiding duplicate or vague entries,
and manually separating unresolved feedback from historical dispositions. In practice, useful
observations are lost or accumulated without a reliable drain.

The capture point has a second failure mode: asking the user to review a form, approve a local write,
or answer follow-up questions turns a small observation into an interruption. Conversely, silently
recording a rating after every skill use creates low-value telemetry. The missing mechanism is a
one-call, local-only capture path that teaches the agent to submit specific and actionable evidence,
skips when the evidence does not clear a strict bar, and later revalidates every claim before it can
change a skill.

## Goal

Add a globally useful `skill-feedback` skill that captures change-worthy observations about any
installed skill in one invocation, aggregates them in a local user-owned TSV across projects, and
guides a bounded, human-approved tuning pass for one named skill. Capture asks the user no questions,
writes to no project, makes no network request, and treats “nothing worth recording” as a successful
outcome.

The durable store lives at
`~/.agents/skilldata/skill-feedback/feedback.tsv`. Installation bytes remain under the harness's
skills directory; mutable feedback survives package replacement and never dirties a linked skill
source tree.

## Approach

Build `skill-feedback` as a standalone durable-home skill outside the `clankshop` pack. Its package
contains the judgment procedure and one guarded TSV provider. The provider owns initialization,
validation, locking, capture, querying, and lifecycle mutation; agents never edit the TSV directly.
The bare invocation is capture, so the ordinary path is simply `/skill-feedback` or
`/skill-feedback <skill>`.

`~/.agents/skilldata/` is a shared namespace for mutable state owned by globally installed skills.
This package creates and owns only its lowercase-slug child, `skill-feedback/`; it does not create a
root registry, enumerate sibling state, or read or mutate another child's bytes. This is preferable
to `~/.agents/data/`, whose generic name invites unrelated applications to assign incompatible
meaning to the root, and to `~/.agents/skills/skill-feedback/feedback.tsv`, which mixes mutable user
data with replaceable package content and can write through a source-tree symlink.
The cross-skill namespace decision is recorded separately in
→ `adr/2026-09-02-reserve-skilldata-for-project-and-global-skill-owned-data.md`.

Capture is explicit by default. An optional `/skill-feedback anchor` command can install a
reversible post-use instruction in `~/.agents/AGENTS.md` for harnesses that load that file. It tells
the custodial agent to invoke `skill-feedback` once after completing another skill only when a
concrete friction, gap, preservation win, or new-skill signal plausibly clears the change-worthiness
bar. Capture and setup remain fully usable without the anchor; anchoring improves recall rather than
becoming a runtime dependency.

Backlog retains its project tracker stem `feedback`, but its default title and classifier narrow to
**project-owned development experience**. The deciding test is where the remedy belongs: an installed
reusable skill routes to its home feedback channel; this repository's docs, scripts, CI, tooling, or
workflow routes to the project's feedback tracker. The two systems share an ordinary word without
sharing ownership, storage, lifecycle, or a forwarding dependency.

The design rejects five alternatives:

- **A mandatory survey after every skill.** Rejected because it interrupts the user and rewards
  generic ratings rather than evidence. No observation is the normal outcome for most uses.
- **A project tracker or callback as the canonical store.** Rejected because the evidence concerns
  the installed skill across projects, not any consuming project's work. Projects may explicitly
  call the global command from their own closure mechanism, but this skill assumes none.
- **Rename Backlog's tracker to `project-feedback`.** Rejected because `/backlog` and `.trackers/`
  already establish project scope. Renaming the stored stem would force a tracker migration and
  ripple through provider, setup, and fixture contracts while leaving the real subject classifier
  implicit. Keep `feedback`; make “where does the remedy belong?” explicit instead.
- **Automatic publication to the skill's upstream issue tracker.** Rejected because local capture
  does not authorize a network write or disclosure of project-derived context. Export or publication
  requires a separate future contract and explicit authority.
- **Treating collected feedback as accepted requirements.** Rejected because observations are
  versioned claims. `tune` must compare them with the current package, dismiss stale or mistaken
  claims, and obtain human approval before editing.

## Mechanism

### Package and commands

The implementation adds a self-contained package directory named `skill-feedback` beneath the
library's existing `skills/` root. It has a thin `SKILL.md`, verb procedures, a package-local TSV
provider, a package-local anchor helper, an owned global-instruction template, and deterministic
tests. Its public grammar is:

| Invocation | Effect |
|---|---|
| `/skill-feedback` | Capture actionable feedback about the most recently completed non-feedback skill |
| `/skill-feedback <skill>` | Capture from context for the named skill |
| `/skill-feedback capture [<skill>] [<observation>]` | Explicit form; also disambiguates a skill whose name matches a verb |
| `/skill-feedback setup` | Reconcile only the owned data store |
| `/skill-feedback anchor [--remove]` | Preview and confirmation-gate installation, update, or removal of the optional global post-use instruction |
| `/skill-feedback query [<skill>] [--status open\|resolved] [--limit N]` | Page feedback without mutation |
| `/skill-feedback tune <skill> [--limit N] [--source <path>]` | Revalidate and guide disposition of one bounded batch |

Bare invocation never asks which verb: capture is the default. `capture` accepts zero or one skill
slug and optional caller-supplied observation text; the agent still structures and privacy-checks
that text rather than storing it verbatim. `query` defaults to the 20 newest open rows and caps
`--limit` at 100. `tune` defaults to the 20 oldest open rows so a channel cannot starve its older
evidence, and also caps the batch at 100.

There is no data teardown, automatic publisher, score/rating verb, project setup, or project tracker
adapter. `setup` performs explicit initialization and validation only; it never reads or writes
global instructions. Capture invokes the same absent-only initializer internally, so setup is never
a prerequisite for the one-call path. `anchor` is the only verb that may write
`~/.agents/AGENTS.md`.

The skill declares `produces: skill-observation` for captured rows and
`consumes: skill-observation` for `tune`. These are global user-state artifacts, not project records or
tracker entries, and they never create a seam inside `clankshop`.

### Global home and provider boundary

The provider resolves the current user's home once to a physical absolute directory at its process
boundary and constructs the exact path `.agents/skilldata/skill-feedback/feedback.tsv` beneath it.
Every existing descendant component must be a real, non-symlink directory until the final regular
file. Before each creation it rechecks the complete existing prefix. A missing, non-absolute, or
unresolvable home, a symlinked descendant, a non-directory intermediate component, or a non-regular
TSV refuses before writing. Tests supply an isolated temporary home; production has no path
selector, alternate root, project-relative fallback, or legacy-path probe.

Initialization uses a restrictive umask. It may create absent shared `.agents/` and `skilldata/`
parents with mode `0700` but never changes the mode or contents of an existing shared parent. It
creates the owned `skill-feedback/` directory with mode `0700` and the TSV with mode `0600` and the
exact header below. It preserves a valid incumbent byte-for-byte. A wrong header, malformed row,
unsafe descendant, or unexpected non-regular target refuses with a recovery diagnostic; capture
never overwrites, adopts, or silently repairs it. Setup may tighten overly broad permissions on the
valid owned directory and TSV but does not modify their data.

The package-local provider is the only supported TSV writer. Every mutating operation waits for the
atomic `feedback.tsv.lock` directory for at most five seconds, using bounded short retries without
asking the user. Once locked, it records its decimal PID, snapshots and validates the complete
current file, writes a mode-`0600` same-directory replacement, validates that replacement, closes
it, atomically renames it over the TSV, and releases only the lock it owns. Any failure before rename
leaves the incumbent TSV unchanged and removes only the operation's own temporary file.

Capture generates and collision-checks its ID while holding the lock and rerolls a collision. It
rewrites the complete validated file rather than appending in place, so interruption cannot leave a
torn final row. Contention that outlives the retry budget returns
`reason=feedback-busy action=retry`; capture does not interrupt the user with a question or guess
that a lock is stale. Setup may remove a lock only when its owner is well-formed and a platform
process probe conclusively proves that PID absent; malformed, live, permission-denied, or otherwise
ambiguous locks remain for human inspection.

### Provider executable contract

`scripts/feedback.sh` is the sole data API. It accepts exactly these commands:

| Command | Contract |
|---|---|
| `describe` | Print the schema, canonical relative store path, and supported command names without touching the store |
| `init` | Perform the absent-only initialization and validate or permission-tighten a valid incumbent |
| `capture --skill S --skill-ref R --invocation I --kind K --summary T --incident T --consequence T --suggestion T [--project-ref R]` | Validate and atomically add exactly one open row |
| `query [--skill S] [--status open\|resolved] [--limit N] [--order newest\|oldest] [--format human\|tsv] [--include-project-ref]` | Validate the whole store and emit a stable filtered page; `--include-project-ref` is valid only with `--format tsv` |
| `resolve --entry ID D T R [--entry ID D T R ...]` | Atomically resolve a heterogeneous batch; each group is ID, disposition, resolution, and a result reference or an empty fourth argument |

Unknown commands, missing or repeated singleton flags, positional data, and incompatible flags
return `reason=usage` without initializing the store. Successful mutations print one
`captured=<id>`, `resolved=<id>`, or `unchanged=<id>` line per requested row followed by
`count=<N>`. `init` prints `status=ready`; `describe` and `query` have their declared payloads.
Diagnostics use one `reason=<code> action=<next-step>` line on stderr and a nonzero exit.
Human query output is labeled prose; TSV output repeats the canonical header followed by physical
stored rows in the selected order, but emits an empty `project_ref` field unless
`--include-project-ref` was supplied.

`resolve` requires each `--entry` to consume exactly four arguments and is all-or-nothing across the
heterogeneous batch. Every requested ID must exist and be open, or already have exactly its requested
disposition, resolution, and result reference. An exact repeat is an idempotent `unchanged=` result.
A duplicate ID in one request, missing ID, malformed group, or conflicting attempt to re-resolve an
already resolved row refuses the complete operation without mutation.

### TSV contract

`feedback.tsv` is UTF-8, ends in one newline, and has this exact `skill-feedback@1` header:

```text
id\tcreated_at\tupdated_at\tskill\tskill_ref\tinvocation\tkind\tsummary\tincident\tconsequence\tsuggestion\tproject_ref\tstatus\tdisposition\tresolution\tresult_ref
```

Normative field rules:

- `id` is an immutable, locally unique `SF-<UTC basic timestamp>-<eight lowercase hex>` identifier.
- `created_at` and `updated_at` are UTC RFC 3339 seconds. Capture gives them the same value; a
  lifecycle mutation changes only `updated_at`, `status`, `disposition`, `resolution`, and
  `result_ref`.
- `skill` is a lowercase kebab-case installed-skill slug. Anchored capture never targets
  `skill-feedback` itself; explicit `capture skill-feedback` may do so without triggering recursion.
- `skill_ref` is `content-sha256:<digest>` using the exact `grimoire/skill-content@1` grammar defined
  by → `specs/2026-08-31-grimoire-symlink-package-manager.md`. It is `unknown` only when that
  canonical identity cannot be obtained; no repository-wide commit or alternate content grammar
  substitutes for it. A changed reference prompts revalidation rather than dismissal.
- `invocation` is the used command or verb, such as `architect/spec`; use `unknown` only when the
  conversation supplies no defensible value.
- `kind` is exactly `friction`, `gap`, `win`, or `new-skill`.
- `summary` is one nonempty sentence of at most 240 UTF-8 bytes. `incident`, `consequence`, and
  `suggestion` are each nonempty and at most 2,000 UTF-8 bytes before escaping. For a win, the
  suggestion states what behavior or invariant to preserve. A complete encoded physical row is at
  most 8,192 bytes including its newline.
- `project_ref` is empty outside a project. Inside a project it is `local-sha256:<first 16 hex>` of
  the canonical project root, allowing local cross-project counting without storing its name or
  path. It is never included in a public change or issue draft.
- `status` is `open` or `resolved`. New rows are `open` with empty `disposition`, `resolution`, and
  `result_ref`.
- A resolved row has one of `applied`, `preserved`, `already-addressed`, `rejected`, `stale`, or
  `duplicate` in `disposition`. `resolution` is a nonempty rationale of at most 2,000 UTF-8 bytes.
  `result_ref` is a privacy-safe commit, repository-relative path, or another feedback ID; it is
  required for `applied`, `preserved`, `already-addressed`, and `duplicate`, and optional for
  `rejected` or `stale`.

Text fields encode backslash, tab, carriage return, and newline as `\\`, `\t`, `\r`, and `\n` in
that order. Readers reverse the encoding. NUL and other control characters refuse. No field contains
a literal tab or line break, so every physical line is exactly one row. Row order is append order;
queries derive their requested chronology from timestamps and IDs rather than rewriting order.

### One-call capture judgment

Capture is an agent-authored observation, not a user questionnaire. It applies this five-part rubric
inside the invocation:

1. **Change test:** would this plausibly change the target skill or preserve behavior that a future
   revision might accidentally remove?
2. **Concrete incident:** what happened during this particular invocation?
3. **Consequence:** what failure, ambiguity, workaround, excess work, avoided error, or useful
   protection resulted?
4. **Candidate response:** what instruction, mechanism, trigger, test, or skill boundary should
   change—or remain intact?
5. **Privacy pass:** remove project and person names, absolute paths, proprietary identifiers,
   secrets, raw prompts, environment values, and source excerpts that are unnecessary to understand
   the claim.

An entry that cannot supply all five does not get padded with guesses. Capture returns
`skipped=no-change-worthy-feedback` when the change test fails and `skipped=skill-ambiguous` when the
target cannot be inferred; it never asks a follow-up question in either case. The explicit skill or
observation form lets a caller eliminate that ambiguity in the original call.

Good feedback has the shape “during `<invocation>`, this happened; this was the consequence; make or
preserve this concrete change.” Generic praise, numeric ratings, preferences without an incident,
project-product feedback, speculative redesigns, and defects in the consuming project are excluded.
One capture call submits exactly one coherent observation and invokes the provider once. If a use
exposes several unrelated observations, the agent records the highest-signal one in that call rather
than combining unrelated incidents; another explicit invocation may record another observation.

On success the provider returns one `captured=<id>` line and `count=1`. A valid no-op
returns its single `skipped=` reason. It emits no stored feedback text by default, keeping automatic
capture out of the user's primary result.

### Optional global anchor

`/skill-feedback anchor` is the only post-use automation surface. It explains that the route is
effective only for harnesses that always load `~/.agents/AGENTS.md`, reads the incumbent global
instructions, and runs package-local `scripts/feedback-anchor.sh preview`. The helper physically
resolves the current user's home, applies the provider's non-symlink descendant rule, may create only
an absent `.agents/` parent with mode `0700`, and constructs the exact global front-door path. The
skill shows the complete proposed diff and obtains explicit confirmation before applying it with the
preview's base identity.

The helper accepts only `preview [--remove]` and
`apply [--remove] --confirmed --base-sha256 <digest-or-absent>`. Preview prints
`status=change|noop`, `base-sha256=<digest-or-absent>`, and the complete proposed diff when a change
exists. Apply repeats all path and delimiter checks, requires the current file to match that base
identity, and prints exactly one of `wrote=AGENTS.md`, `removed=AGENTS.md`, or `status=noop`.
Unsupported arguments refuse without mutation.

Absent means append one owned block beneath `## Skill routes (self-registered)`, creating the safe
regular file and heading when absent. Present and well-formed means replace only owned bytes. The
`built-against` value is path-scoped: `git -C <skill-dir> log -1 --format=%h -- .`, otherwise the
package version, otherwise `v0-2026-09-02`; it is never repository-wide `HEAD`. For installation or
update only, the agent treats an active instruction outside the owned block that routes
reusable-skill feedback to another command or store as a conflict, quotes it, and asks the human to
choose the cutover. Removal ignores outside routes and considers only ownership and path safety. A
malformed owned block, unsafe path, unresolved installation conflict, or front-door change between
preview and apply refuses without touching the file. The owned block is:

```markdown
<!-- skill:skill-feedback BEGIN built-against:<path-scoped-stamp> -->
### /skill-feedback — capture reusable-skill feedback
Route: after completing a named skill other than `skill-feedback`, if its concrete use exposed
friction, a gap, a preservation win, or a plausible new-skill signal, invoke
`/skill-feedback capture <skill>` once before the final response. The skill applies its full quality
and privacy rubric and may skip without asking questions. Do not invoke it for ordinary success,
generic praise, project-owned product defects, or feedback about `skill-feedback` itself. Capture is
advisory: failure never changes the completed skill's outcome.
Edges: produces `skill-observation`.
<!-- skill:skill-feedback END -->
```

`/skill-feedback anchor --remove` previews removal and requires confirmation before deleting only
the one well-formed owned block. An absent block is an idempotent no-op. It preserves the shared
heading and every surrounding byte even when the heading becomes empty; a malformed delimiter or
concurrent edit refuses without mutation. Removal does not delete captured data.

The instruction is a global user preference, not a block in any consuming project's front door.
Setup, capture, query, and tune never inspect, require, update, or remove it. The package must not
edit the Grimoire library's own `AGENTS.md`; anchor tests use a temporary global front door. A
missing, rejected, or harness-inapplicable anchor does not impair manual capture.

### Query and guided tuning

Query validates the whole TSV before filtering, de-escapes fields for human display, and never
reveals `project_ref` unless the caller explicitly combines `--format tsv` with
`--include-project-ref`. It supports exact skill/status filtering only; fuzzy clustering belongs to
judgment in `tune`.

`/skill-feedback tune <skill>` is a guided review-and-apply workflow:

1. Select one bounded, stable page of the oldest open rows for the exact skill and keep those IDs
   fixed for the pass.
2. Resolve the installed package for preliminary read-only analysis. Never infer source custody from
   its writability, symlink target, Git ancestry, or directory shape. A source candidate exists only
   when the caller supplied `--source <path>` or the human names an exact directory during this guided
   pass. Resolve that candidate physically, require a matching `SKILL.md` tracked in a Git worktree,
   and reject a path classified by available package-manager metadata as an immutable store entry.
   The installed directory itself is never an apply target. Its real symlink target may qualify only
   when it independently passes this source gate and was explicitly selected.
3. Re-check every claim against the gated source candidate when one exists; otherwise use the
   installation for analysis only. Compare its canonical content identity with `skill_ref`, inspect
   relevant history, grep before generalizing, cluster repeated evidence, and distinguish current
   defects, already-addressed behavior, stale version-specific claims, project-specific concerns,
   false claims, preservation wins, and evidence that points to a new skill rather than an expansion
   of the named one.
4. Present a proposed disposition for each ID and the smallest coherent package changes supported by
   the analyzed target. Feedback is evidence, not authority; push back when the package contradicts
   it. Rows lacking enough evidence stay open and do not block unrelated supported rows. When no
   source candidate exists, label the proposal analysis-only and do not offer apply.
5. Obtain explicit human acceptance of the proposed dispositions and exact writable source target.
   The preview identifies whether that target came from `--source` or the human's explicit selection;
   mere discovery of a likely checkout does not authorize it. If the human selects or changes the
   source after a proposal, invalidate that proposal, run the source gate and step 3 against the new
   target, and present a replacement before seeking acceptance. Before acceptance, do not edit the
   package or resolve a row.
6. Apply only the accepted change to the named package, use its authoring doctrine and package-local
   checks, then run the host library's skill lint. `tune` does not broaden into unrelated skill or
   doctrine changes; a cross-skill or new-skill finding remains open with a concise proposed next
   action.
7. Resolve rows only after the accepted result is verified. Update their lifecycle columns in one
   locked transaction with the accepted disposition, durable resolution rationale, and any required
   privacy-safe result reference. A failed edit or gate leaves all affected rows open. Never record
   an absolute path or copied project evidence.

If no explicit source target is accepted, `tune` stops after analysis and leaves every row open. It
never patches a replaceable installation merely because it is writable. It does not commit,
publish, open issues, or push; those remain under the caller's normal source-control and
external-action policies.

### Project-feedback boundary

Backlog's default `feedback` queue remains `.trackers/tables/feedback.tsv`; existing queue names,
IDs, history, provider commands, and migrations do not change. Its package suggestion becomes:

```yaml
title: Project Feedback
use-when: "Development-experience observations whose remedy belongs in this project."
```

The corresponding editable prompt body tells the agent to file concrete friction or a useful
observation from doing project work only when the remedy belongs in the repository. It explicitly
excludes feedback about a reusable installed skill and directs that observation generically to the
skill's home feedback channel, without naming or requiring `skill-feedback`.

Backlog's debrief procedure applies the same non-overridable subject cut before consulting the
editable project prompt:

- project-owned development-experience friction may route to `feedback`;
- feedback whose remedy belongs in an installed reusable skill is not written to `.trackers` and is
  returned to the custodial caller as a skill-tagged byproduct;
- project defects, risks, work, and repeated responses continue through `issue`, `task`, and
  `routine` according to their existing classifiers.

An incumbent `.trackers/DEBRIEF.md` remains project-owned and is not overwritten merely to adopt the
new wording. Its editable sections may narrow or specialize project routing, but cannot widen
Backlog into a store for globally owned skill feedback. New setups receive `Project Feedback` in the
packaged suggestion and default catalog. The package catalog output, suggestion, runtime classifier,
and focused tests must agree on the exact use-when sentence above.

`PACK.md` keeps `feedback` as the project tracker class in its delegated-byproduct example, but
qualifies it as project-owned. A reusable-skill observation is returned separately with the affected
skill tag for the caller's home feedback channel. The pack does not require the new global skill,
write its TSV, or create a direct Delegate-to-global-feedback seam.

### Existing feedback channels and hard cut

The data runtime reads and writes only the canonical TSV. It does not probe, dual-read, rename,
parse, or delete an incumbent `~/.agents/FEEDBACK.md` or project feedback tracker. Those remain
historical input until a separately requested, explicitly specified migration is performed. Setup
does not inspect global instructions; only an explicit anchor reports a conflicting route rather
than silently rewriting it. This keeps the package portable and prevents a local installation
format from becoming a universal legacy contract.

## Verification

The implementation is acceptable when all of the following hold:

1. `bash skills/skill-builder/scripts/skills-lint.sh .` reports `fails=0`, and the new package passes
   its substance and boundary checks as a standalone globally useful skill outside `clankshop`.
   `README.md` lists it in the skill table and changes the outside-pack inventory from four skills to
   five; `PACK.md` does not add it.
2. The package test harness runs with a temporary home and never writes the developer's real
   `~/.agents`, the repository's `AGENTS.md`, a consuming project, or the installed package tree.
3. `feedback.sh describe`, `init`, `capture`, `query`, and `resolve` accept only their
   declared grammar and produce the declared stdout/stderr shapes. Unknown commands, duplicate
   singleton flags, incompatible flags, and positional data refuse without initialization.
4. Capture against an empty temporary home creates only
   `.agents/skilldata/skill-feedback/feedback.tsv` plus its transient lock, with the specified modes,
   exact header, one valid row, and terse success output. A second valid capture preserves the first
   row byte-for-byte and adds one row through atomic replacement.
5. Parallel capture tests start at least 20 writers and prove bounded internal retry lets all ordinary
   contenders succeed with unique IDs, the exact expected row count, no torn bytes, no surviving
   lock or temporary file, and a fully valid TSV. A deliberately prolonged live lock exhausts the
   five-second budget with `reason=feedback-busy`. A planted ID collision rerolls under lock, and a
   writer delayed before acquisition re-reads and preserves rows committed by earlier lock holders.
   A malformed header, malformed row, symlinked descendant, and non-regular target each refuse without
   changing the incumbent file. Fixtures also prove absent shared parents are created safely and
   existing shared-parent modes and contents are preserved.
6. Encoding round-trips backslash, tab, CR, LF, and non-ASCII text exactly. Planted NUL/control input,
   invalid slugs, invalid enums, overlong fields, inconsistent resolved rows, and extra/missing
   columns fail validation before mutation.
7. Capture fixtures cover all four kinds, exactly one row and one provider call per invocation,
   explicit target and observation, context inference, `skill-feedback` recursion suppression,
   ambiguous-skill skip, and no-change-worthy skip. Both skip cases make no file mutation after
   initialization.
8. Behavioral prompt tests give an agent the rubric and representative recent skill-use context.
   Concrete friction, gap, and preservation-win cases produce incident/consequence/suggestion rows;
   a grounded new-skill signal is classified separately, and generic praise, a consuming-project
   bug, a speculative preference, and context containing a secret or absolute project path are
   skipped or de-identified. No test requires a user follow-up.
9. Canonical identity byte goldens match `grimoire/skill-content@1` for executable and non-executable
   regular files and symlinks. A repository commit that changes another package does not alter the
   target skill's reference; inability to compute the canonical digest yields `unknown` rather than
   an alternate hash.
10. Anchor fixtures prove preview and confirmation-gated absent append, path-scoped stamp update,
    exact owned-block replacement, idempotent absence, confirmed `--remove`, preservation of the
    shared heading and unrelated bytes, malformed/conflicting refusal, unsafe-path refusal, and
    concurrent-edit refusal. Removal succeeds despite an unrelated competing route when its owned
    block is well-formed. A cold harness that loads the installed block calls capture for each
    qualifying kind, stays silent for ordinary success, and does not recurse after `skill-feedback`.
    Setup and every non-anchor verb leave global instructions byte-for-byte unchanged.
11. Query tests prove stable filters and limits, whole-file validation, newest-open default ordering,
    correct de-escaping, valid human and TSV formats, default suppression of `project_ref`, and its
    inclusion only for the explicit compatible flag pair.
12. Resolve tests prove atomic heterogeneous multi-ID updates, required rationales and result
    references, exact idempotent repeats, and refusal of duplicate IDs, malformed groups, conflicting
    re-resolution, or missing IDs without partial mutation. Every non-lifecycle field is preserved.
13. Tune fixtures cover matching and changed canonical `skill_ref`, repeated evidence clustering,
    every disposition, unsupported rows remaining open, explicit and session-selected source paths,
    tracked and untracked candidates, immutable-store exclusion, installed targets that are writable,
    symlinked, read-only, or immutable, and a source changed after the first proposal. A late source
    selection forces re-grounding and a replacement proposal. Rejected proposals, edit failure, and
    gate failure leave rows open; no installation is patched, and no row resolves before approval and
    successful verification.
14. Network and filesystem probes prove capture and query make no network calls and write only inside
    the owned global data directory. Anchor changes only the explicitly confirmed global instruction
    file. Tune makes no external write, commit, or publication and changes only the human-approved
    source package plus accepted TSV lifecycle fields.
15. A fixture containing `~/.agents/FEEDBACK.md` and a conflicting global override proves the legacy
    file is unchanged, no row is silently imported, setup remains independent, and explicit anchor
    stops with an actionable conflict. Grimoire's real `AGENTS.md` remains untouched under every test.
16. Backlog's default catalog and suggestion use the exact `Project Feedback` title and project-remedy
    classifier while retaining the `feedback` stem and table path. A planted installed-skill
    observation is not filed by debrief and returns as a skill-tagged byproduct; an otherwise
    equivalent project-owned workflow observation files once to `feedback`.
17. A fixture with an incumbent customized `.trackers/DEBRIEF.md` proves setup does not overwrite it,
    while Backlog's runtime subject boundary still prevents installed-skill feedback from being
    stranded in the project. Existing `feedback.tsv` rows, IDs, and history remain byte-for-byte
    unchanged; no tracker migration occurs.
18. The pack's byproduct guidance distinguishes project feedback from reusable-skill feedback without
    requiring `skill-feedback`, naming its global data path, or adding a direct writer. Focused tests
    cover the packaged suggestion, setup catalog output, debrief prose, and pack wording so the
    classifier cannot drift independently.

Every safety check in criteria 3–10 and 12–18 is red-proved by planting the forbidden
condition, showing the focused test fail, restoring the fixture byte-for-byte, and showing it pass.
The spec remains `status: draft` until review passes and the caller accepts it.
