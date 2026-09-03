---
doctype: specs
status: published
schema: architect/spec@1
tags: [agent-feedback, skill-builder, global-state, skill-design]
---

# Agent feedback capture and independent skill tuning — Spec

## Problem

The published skill-feedback design created a safe private queue for observations about installed
skills, but it coupled three different responsibilities: collecting feedback, deciding whether that
feedback was true, and editing a skill source package. Its identity, schema, automatic route, query
grammar, and guided `tune` workflow all assume that every observation concerns a skill. That excludes
equally useful feedback about agents, harnesses, tools, and reusable workflows, and it makes the
collector responsible for remediation it cannot generalize.

The source of feedback is also ambiguous. Agents need a low-friction way to preserve a concrete
observation they notice during ordinary work, while humans need an explicit slash-command interface
whose submitted wording remains recognizable. Applying the agent capture threshold to both sources
would either admit low-value automatic telemetry or let the collecting agent silently reject and
rewrite intentional human feedback.

Skill revision still needs the valuable half of the old `tune` workflow: source-custody checks,
claim revalidation, a bounded proposal, explicit acceptance, targeted edits, and verification. That
work belongs with the toolmaker steward, but tying it to the new feedback queue or its TSV schema
would merely move the coupling. Skill changes may be motivated by a conversation, review, issue,
report, or arbitrary prose file; the authoring workflow must work without any feedback skill or
global store installed.

This spec replaces the design in
→ `specs/2026-09-02-global-skill-feedback-capture-and-guided-tuning.md`. The earlier published record
remains authoritative until this draft passes review and the caller publishes it; at that point the
caller supersedes the earlier record and names this one as its successor.

## Goal

Replace `skill-feedback` with a standalone `agent-feedback` skill that privately aggregates feedback
authored by humans and agents about reusable agent-facing subjects across projects. It owns capture,
query, closure, setup, and optional global routing; it never interprets feedback as an accepted
requirement or edits the thing being discussed.

Add a producer-agnostic `skill-builder tune` verb that accepts current conversational evidence and,
optionally, one ordinary prose file. It revalidates claims against an explicitly selected editable
skill source, confirmation-gates the smallest coherent revision, and verifies the result without
reading, naming, or mutating `agent-feedback` state.

## Approach

Hard-cut the live package identity from `skill-feedback` to `agent-feedback` and generalize two
independent axes in its data model:

- `origin` says who authored the feedback: `agent` or `human`;
- `subject_type` says what the feedback concerns: `skill`, `agent`, `harness`, `tool`, or `workflow`.

The `subject` field names the concrete target within that type. Scope is decided by ownership of the
remedy, not by where the observation occurred: feedback about a reusable agent-facing capability
belongs in the global queue, while a remedy owned by the consuming repository remains project
feedback. A reusable workflow may therefore qualify; a project-local procedure does not.

Agent-originated capture keeps a high evidence bar and may silently skip. Human-originated capture is
an explicit request to preserve the submission: it may be safely redacted and summarized, but it is
not rejected merely because the human omitted a formal incident, consequence, or proposed fix. The
stored statement preserves the human's wording as closely as the privacy pass permits, and the row
records whether redaction occurred.

Move only the skill-authoring portion of the old guided tuning workflow into a new
`skill-builder tune` verb. `skill-builder review` remains read-only, `calibrate` remains limited to
portable authoring doctrine, and `tune` accepts prose by meaning rather than parsing a producer
schema. Neither package names the other, declares a typed edge to the other, or assumes the other is
installed. An orchestrating caller may carry information between them in conversation, but that is
not a package contract.

Rejected alternatives:

- **Rename without broadening.** Rejected because `agent-feedback` would misleadingly wrap a
  skill-only target schema and remediation workflow.
- **One untyped feedback bucket.** Rejected because provenance and subject ownership are needed to
  route and interpret evidence without turning the queue into an ownerless suggestion box.
- **Keep tuning in the collector through subject adapters.** Rejected because every new subject type
  would require source discovery, custody, and application semantics unrelated to capture.
- **Make `skill-builder tune` consume a feedback schema or global store.** Rejected because it would
  give an in-place toolmaker a global-data dependency and prevent ordinary conversational, issue,
  review, or report-driven tuning.
- **Expand `skill-builder review` to edit.** Rejected because its read-only report is a useful trust
  boundary; evidence-driven mutation deserves a separate, explicitly invoked verb.
- **Automatically launch tuning after capture.** Rejected because feedback is evidence, not
  authority, and ordinary capture must not broaden into source modification.
- **Let the successor import or remove predecessor-owned global state.** Rejected because global
  ownership begins below each skill's child and inside each skill's own anchor delimiters. The hard
  cut leaves predecessor data and routes outside successor ownership rather than granting the
  successor a sibling migration privilege.

## Mechanism

### Package identity and public grammar

Rename the package directory to `skills/agent-feedback/` with frontmatter `name: agent-feedback`.
The live package exposes:

| Invocation | Effect |
|---|---|
| agent-selected qualifying use | Capture at most one agent-authored observation from current context |
| `/agent-feedback capture <subject-type> <subject> [<message>]` | Preserve one explicit human submission |
| `/agent-feedback query [filters]` | Read one bounded validated page without mutation |
| `/agent-feedback close <id> --as <disposition> --reason <text> [--result-ref <ref>]` | Close one open row with a durable rationale |
| `/agent-feedback setup` | Initialize or validate only the owned global data home |
| `/agent-feedback anchor [--remove]` | Preview and confirmation-gate its optional global route |

Human capture requires the slash command and `capture` verb. Bare or natural skill selection is the
agent path, not an alternate human form. If `[<message>]` is omitted, the procedure uses feedback
prose elsewhere in that same human utterance; if none exists, it asks one concise question and does
not call the provider. `capture`, `query`, `close`, `setup`, and `anchor` are reserved first tokens;
unknown option-shaped input refuses. The collector has no `tune` or other remediation, migration, or
project-setup verb.

Agent selection is permitted when current work exposes one concrete observation about a reusable
agent-facing subject. The skill description must route that use on its own without naming a sibling.
Most successful work produces no capture. The optional anchor remains a recall aid only for harnesses
that always load `~/.agents/AGENTS.md`; it is never an installation or runtime floor.

The package is global-only and outside every pack. Its edge block declares
`produces: feedback-observation`, no handoff, and
`consumes: feedback-observation` only for its own query and closure lifecycle. It does not declare a
skill-change or remediation edge.

### Capture provenance and quality

The skill procedure determines `origin` from custody of the observation and passes it as a required
provider flag; the provider validates but does not infer provenance:

- `agent` means the agent noticed and authored the observation during ordinary work;
- `human` means the human explicitly invoked `/agent-feedback capture` and supplied or adopted the
  feedback statement.

Agent-originated capture applies five checks before invoking the provider:

1. **Reuse boundary:** the remedy belongs to a reusable skill, agent, harness, tool, or workflow, not
   the consuming project's product or local process.
2. **Change:** the observation could plausibly change the subject or preserve valuable behavior a
   future revision might remove.
3. **Incident and consequence:** current context supports what happened and why it mattered.
4. **Response:** current context supports a plausible change, boundary, test, or invariant to
   preserve.
5. **Privacy:** the proposed row omits secrets, raw prompts, environment values, absolute project
   paths, proprietary identifiers, person/project names, and unnecessary source excerpts.

Failure of the reuse or change checks returns `skipped=no-change-worthy-feedback`; inability to name
one subject returns `skipped=subject-ambiguous`. Capture asks no follow-up, invokes the provider at
most once, and stores at most one coherent highest-signal observation. Generic praise, ratings,
speculative redesign, and ordinary success do not qualify automatically.

Human-originated capture treats the explicit command as authority to store one submission. The
procedure validates or normalizes the subject type and lowercase kebab subject, preserves the
submitted statement nearly verbatim, produces a short faithful summary, and fills incident,
consequence, and suggestion only where the human's words or current context support them. Those three
fields may be empty for a human row. Generic praise and incomplete suggestions are allowed from a
human. If the subject is ambiguous the command asks one concise question; if privacy-safe redaction
would destroy the meaning, it asks for a safe restatement rather than inventing one. Otherwise it
stores immediately and reports `captured=<id>`, `count=1`, and `redacted=yes|no` without echoing the
stored statement.

Both paths classify `kind` as `friction`, `gap`, `win`, or `request`. An agent-originated
preservation win has a nonempty suggestion stating what must remain intact; a human win may preserve
praise in its statement while leaving suggestion empty.

### Global home and provider boundary

The package owns only:

```text
~/.agents/skilldata/agent-feedback/feedback.tsv
```

It writes no project data and never stores mutable state in installed package bytes. The provider
physically resolves the current user's absolute home once, rejects symlinked descendants and
incompatible entries, uses `0700` for its owned directory and `0600` for the TSV, and never claims
that local permissions make the queue a secret store. Setup may tighten permissions on the owned
directory and file but never changes shared-parent modes or valid incumbent data.

The package-local provider remains the only TSV API. It supports `describe`, `init`, `capture`,
`query`, and `close`; agents never edit the TSV directly. Mutations retain the existing
bounded lock-directory protocol, complete-file validation, mode-`0600` same-directory temporary,
atomic rename, collision check under lock, cleanup discipline, and terse `key=value` results.
Contention after the bounded retry returns `reason=feedback-busy action=retry`. Setup alone may remove
a conclusively stale well-formed lock. Malformed, unsafe, or ambiguous state refuses without repair or
partial mutation.

### Provider executable contract

`scripts/feedback.sh` accepts exactly these commands and flags:

| Command | Contract |
|---|---|
| `describe` | Print the schema, canonical home-relative store path, and command names without touching the store |
| `init` | Perform absent-only initialization, then validate or permission-tighten a valid incumbent |
| `capture --origin O --subject-type T --subject S --subject-ref R --invocation I --kind K --summary T --statement T --incident T --consequence T --suggestion T --redacted yes\|no [--project-ref R]` | Validate and atomically add exactly one open row |
| `query [--origin O] [--subject-type T] [--subject S] [--status open\|closed] [--limit N] [--order newest\|oldest] [--format human\|tsv] [--include-project-ref]` | Validate the whole store and emit one stable filtered page; `--include-project-ref` is valid only with `--format tsv` |
| `close --id ID --as D --reason T [--result-ref R]` | Atomically close one row or recognize one exact idempotent repetition |

All capture flags shown before `[--project-ref R]` are required exactly once, including flags whose
human-originated text value is empty. Query singleton flags may appear at most once. It defaults to
`--status open --limit 20 --order newest --format human`; other absent filters are unconstrained.
Close flags shown before `[--result-ref R]` are required exactly once, and the optional flag is
permitted or required according to the disposition rule below. Unknown commands, missing or repeated
singleton flags, positional data, and incompatible flags return exactly
`reason=usage action=check-command` without initializing the store.

`describe` prints exactly these three newline-terminated lines:

```text
schema=agent-feedback@1
store=.agents/skilldata/agent-feedback/feedback.tsv
commands=describe,init,capture,query,close
```

Successful `init` prints `status=ready`. Successful capture prints `captured=<id>`, `count=1`, and
`redacted=yes|no`, in that order. Successful close prints `closed=<id>` or `unchanged=<id>`, followed
by `count=1`. Diagnostics print one `reason=<code> action=<next-step>` line on stderr and exit nonzero.
TSV query output repeats the canonical header followed by selected physical rows.

Human query output prints every selected row with exactly these labels in this order, followed by the
literal `--` separator:

```text
id=<value>
created_at=<value>
updated_at=<value>
origin=<value>
subject_type=<value>
subject=<value>
subject_ref=<value>
invocation=<value>
kind=<value>
summary=<value>
statement=<value>
incident=<value>
consequence=<value>
suggestion=<value>
redacted=<value>
status=<value>
disposition=<value>
resolution=<value>
result_ref=<value>
--
```

Text and reference values are de-escaped. Empty optional and open-row lifecycle values retain their
labels with an empty value; `project_ref` is never printed in human output. Neither query format
prints a count trailer. An empty result is header-only TSV or empty human output.

### TSV contract

The canonical `agent-feedback@1` header is:

```text
id\tcreated_at\tupdated_at\torigin\tsubject_type\tsubject\tsubject_ref\tinvocation\tkind\tsummary\tstatement\tincident\tconsequence\tsuggestion\tredacted\tproject_ref\tstatus\tdisposition\tresolution\tresult_ref
```

Normative fields:

- New `id` values are `AF-<UTC basic timestamp>-<eight lowercase hex>`. IDs are immutable and
  locally unique.
- `created_at` and `updated_at` are UTC RFC 3339 seconds. Capture sets both equally; close changes
  only `updated_at`, `status`, `disposition`, `resolution`, and `result_ref`.
- `origin` is `agent` or `human`.
- `subject_type` is `skill`, `agent`, `harness`, `tool`, or `workflow`.
- `subject` is a lowercase kebab slug of at most 120 UTF-8 bytes naming one target. It is never
  inferred from a generic tool call when several targets are plausible.
- `subject_ref` is a privacy-safe version or content identity when current context or a
  package-local resolver can establish one, otherwise `unknown`. Skill subjects may retain the
  existing canonical `content-sha256:<digest>` computation; no repository-wide commit substitutes
  for a subject identity. It is at most 512 UTF-8 bytes.
- `invocation` names the relevant command, verb, or interaction when known, otherwise `unknown`, and
  is at most 240 UTF-8 bytes.
- `kind` is `friction`, `gap`, `win`, or `request`.
- `summary` is one nonempty sentence of at most 240 UTF-8 bytes.
- `statement` is the nonempty privacy-safe source statement, at most 4,000 UTF-8 bytes. For `human`, it
  preserves submitted wording except necessary redaction and whitespace normalization. For `agent`,
  it is the agent-authored coherent observation.
- `incident`, `consequence`, and `suggestion` are each at most 2,000 UTF-8 bytes. They are nonempty
  for agent rows and optional for human rows.
- `redacted` is `yes` when privacy filtering changed the source statement, otherwise `no`.
- `project_ref` is empty outside a project. Inside a project it is exactly
  `local-sha256:<first-16-lowercase-hex>` of the physically resolved project root; ordinary human
  query output never exposes it.
- `status` is `open` or `closed`. New rows are open with empty lifecycle fields.
- A closed row has disposition `addressed`, `preserved`, `declined`, `stale`, or `duplicate`, plus a
  nonempty resolution of at most 2,000 UTF-8 bytes. `result_ref` is required for `addressed`,
  `preserved`, and `duplicate`, and optional for `declined` or `stale`. It is a privacy-safe commit,
  repository-relative path, URL, or another feedback ID; never an absolute local path and never more
  than 2,000 UTF-8 bytes.

Text-field encoding maps backslash to `\\`, tab to `\t`, carriage return to `\r`, and newline to
`\n`, in that order. Decoding recognizes only those four escapes in one left-to-right pass; an unknown
or dangling escape refuses. NUL and other control characters refuse. Every physical row has the exact
field count and is at most 32,768 bytes including its terminating newline. The file ends in one
newline, and whole-store validation precedes every read or mutation.

### Query and closure

`/agent-feedback query` is a read-only wrapper over the provider's exact query grammar and output
contract above; it adds no filters, defaults, or exposure rules.

`/agent-feedback close` is human-directed lifecycle management, not remediation. It requires one
open ID, an exact disposition, and a nonempty reason; it validates the result-reference rule and
updates the row atomically. Exact repetition is idempotent. A missing ID, conflicting re-close,
invalid disposition, or malformed result reference refuses without mutation. Closing a row makes no
claim about what tool, person, or workflow produced the result and invokes no downstream capability.

### Optional global anchor

The new owned block uses only `agent-feedback` delimiters and advertises the generalized automatic
capture boundary. It tells an agent to invoke the skill at most once after qualifying work, remain
silent for ordinary success, apply the strict agent quality and privacy checks, avoid project-owned
feedback, and suppress automatic feedback about `agent-feedback` itself. Explicit human capture may
still target the skill.

Anchor preview and apply retain exact-diff confirmation, base-digest concurrency protection,
well-formed delimiter checks, preservation of surrounding bytes, and reversible removal. The anchor
owns and changes only bytes inside `agent-feedback` delimiters.

For installation or update, preview scans unfenced bytes in the self-registered route section outside
the owned block. A competing feedback route is an H3 slash-command heading whose command slug
contains `feedback` as a hyphen-delimited token. Preview and apply refuse such a conflict with the
single diagnostic
`reason=competing-feedback-route action=resolve-route conflict=<exact-heading>` and propose no write;
no confirmation token bypasses it. Removal ignores competing routes and may remove only the owned
block. The anchor may read surrounding bytes to protect their arrangement but never modifies another
owner's bytes or markers. Tests use a temporary global front door; Grimoire's authored `AGENTS.md` is
never a deployment target. Setup, capture, query, and close never inspect global instructions.

### Predecessor disposition

The rename is a hard cut, not a transfer of global ownership. Existing predecessor installations and
global data children remain outside the successor's control; `agent-feedback` never probes,
validates, imports, repairs, renames, warns about, or deletes them. A predecessor anchor may be
observed only when it matches the generic competing-route grammar above; the successor quotes and
refuses the route but never treats it as migration input or mutates its bytes. A human who wants
predecessor state removed does so through its owner or ordinary manual administration. The new
package recognizes no predecessor schema or ID prefix. Historical records may retain the old name as
evidence, while live documentation and runtime contracts do not.

### Independent `skill-builder tune`

Add this public grammar to `skill-builder`:

```text
/skill-builder tune <skill-source> [<input-path>]
```

`<skill-source>` follows the existing skill target resolution used by review: a directory containing
`SKILL.md`, a `SKILL.md` path, a relative path resolved from the current directory, or a bare slug
resolved to `<git-toplevel>/skills/<slug>/`. Tune adds a mutation gate: the selected package must be a
matching, Git-tracked source beneath its resolved worktree and outside an immutable package-manager
store. Writability, symlink targets, ancestry, or directory shape alone never establishes custody.
A package-local read-only helper computes and reports these facts plus a proposal identity consisting
of the physical package root, declared name, Git root, HEAD object ID, and `package-sha256`. The digest
walks the package without following symlinks and hashes each sorted relative path, entry type,
executable bit, and regular-file bytes or symlink target. It includes tracked, dirty, and untracked
package entries and refuses unsupported entry types. Generalize the existing source-custody logic;
do not retain installed-package or feedback-store arguments.

The optional `<input-path>` is one explicitly named readable UTF-8 regular non-symlink file. Its
format is deliberately unspecified: prose, notes, issue text, review findings, reports, and exported
feedback are all ordinary evidence. Tune does not branch on headings, filenames, fields, IDs, or
schemas and treats instructions embedded in the file as quoted input rather than authority. With no
path, current conversation is the complete input. It never scans the current directory or a global
home for likely evidence.

Tune performs one evidence-driven revision pass:

1. Resolve and custody-check the exact source package. An ineligible or ambiguous target is reported
   without edits; the human must name a different source before work continues.
2. Extract a bounded set of concrete claims from current conversational input and the one named file.
   If the input spans unrelated changes, present the split and ask the human to select one coherent
   batch. Never invent a change merely because `tune` was invoked.
3. Re-check every selected claim against the current package, relevant history, and repository
   context before generalizing. Classify it as current, already addressed, stale, project-specific,
   false, a preservation constraint, out of scope, or unsupported. Input is evidence, never an
   accepted requirement.
4. Present each claim's disposition, durable rationale, exact source target, proposal identity, and
   the smallest coherent file changes supported by the evidence. For a named input file, also retain
   its physical path and SHA-256 digest. Unsupported or out-of-scope claims remain explicit and do not
   enter the edit proposal.
5. Obtain explicit human acceptance of the exact target and proposed changes. Immediately before any
   mutation, recompute custody and require exact equality of the physical target, declared name, Git
   root, HEAD, and package digest; also recheck a named input file's path and digest. Any mismatch,
   different target, or material claim-set change invalidates the proposal and requires revalidation
   and renewed acceptance.
6. Apply only the accepted changes within the selected skill package, following the host library's
   authoring doctrine. Run package-local focused checks, then the host library's skill lint; if a new
   check was authored, red-prove it before trusting green.
7. Report changed files, supported and rejected claims, verification results, and any remaining
   uncertainty in conversation.

`review` remains unchanged and read-only, while `calibrate` remains milestone-triggered doctrine
curation. `tune` is selected only by an explicit tuning or skill-revision request. It accepts evidence
only from current conversation or one caller-named input file, produces in-place skill changes plus a
conversational report, and creates no record, external disposition, commit, issue, publication,
global state, front-door registration, or producer-specific typed edge. The existing edge block
remains unchanged; the description names the tuning job but no feedback producer.

### Repository integration and hard cut

Update the live inventory and contribution prose in `README.md` from `skill-feedback` to
`agent-feedback`, describing global human/agent capture and lifecycle without guided source changes.
Keep the package standalone and outside `clankshop`. `PACK.md` continues to name only the generic home
feedback channel for reusable agent-facing observations; it does not name, install, invoke, or write
the global collector. Project-owned feedback retains the current Backlog boundary.

Rename or rewrite every package-local path, delimiter, schema, ID, temporary-file prefix, test hook,
fixture, and focused test that forms the live predecessor contract. Remove the old tune verb and its
contract test from the collector. Move only generalized source-custody facts into `skill-builder` and
add focused tune contract/custody tests there. Retain skill content identity computation in the
collector only for versioning a `subject_type=skill` observation; it grants no remediation behavior.

Live source contains no `skill-feedback`, `skill-observation`, old global path, or old command
references except same-line annotated negative fixtures that prove rejection. Historical records are
evidence and are not rewritten.

## Verification

The implementation is accepted when:

1. `bash skills/skill-builder/scripts/skills-lint.sh .` reports `fails=0`. The full boundary audit
   confirms both descriptions route independently, neither package names the other, the collector is
   global-only, and the toolmaker has no global-data dependency.
2. The package exists only at `skills/agent-feedback/` with `name: agent-feedback`; the predecessor
   live directory is absent. `README.md` lists the new standalone package, while `PACK.md` and the
   repository's real `AGENTS.md` contain no installed route or direct writer dependency.
3. Provider `describe`, `init`, `capture`, `query`, and `close` accept only their declared grammar and
   produce the specified output, diagnostics, schema, and canonical home-relative path. Unknown commands,
   repeated singleton flags, incompatible flags, and positional data refuse without unintended
   initialization.
4. Empty-home setup and first capture create only the owned global directory, TSV, and transient
   lock/temporary state with the declared modes and exact header. Repeated setup preserves a valid
   incumbent byte-for-byte and tightens only owned permissions.
5. Provider fixtures round-trip escaping and non-ASCII text, enforce every enum, field bound,
   conditional rule, and the 32,768-byte encoded-row ceiling, reject control characters and unsafe
   references, validate the whole store before filtering, and preserve non-lifecycle fields during
   close.
6. Parallel capture tests exercise at least 20 writers and prove unique IDs, exact row count, bounded
   contention, no torn bytes, and no surviving operation-owned temporary or lock. A live prolonged
   lock, malformed store, symlinked descendant, non-regular target, and planted ID collision each
   produce the documented safe result.
7. Agent capture fixtures cover every subject type and kind, one-call/one-row behavior, automatic
   self-feedback suppression, project-owned exclusion, subject ambiguity, ordinary-success skip,
   privacy redaction, and preservation of a safe subject reference when available. Behavioral prompt
   tests show concrete incidents capture and generic praise or speculative redesign skip without a
   follow-up.
8. Human capture fixtures prove explicit slash-command provenance, near-verbatim statement
   preservation, faithful summary, optional structured fields, allowed praise and incomplete
   suggestions—including a human `win` with an empty suggestion—transparent redaction, one-question
   ambiguity handling, and refusal to invent a privacy-destroyed restatement.
9. Query tests cover every exact filter, both orders, bounds 1 and 100, newest-open defaults,
   exact human labels and order, de-escaping, retained empty fields, both empty-result forms, the TSV
   project-reference gate, and absence of count trailers. Close tests cover every disposition,
   result-reference requirements, exact idempotence, and all-or-nothing refusal on conflict.
10. Anchor fixtures prove confirmation-gated installation, update, and removal; exact detection and
    diagnostics for the generic competing-route grammar, including an annotated predecessor-route
    negative fixture; install/update refusal without mutation; successful owned-block removal while
    a competitor remains; malformed-marker refusal; base-digest concurrency protection; and
    preservation of every surrounding byte. A cold harness using the installed block captures each
    qualifying subject class, stays silent for ordinary success, excludes project-owned feedback,
    and does not recurse.
11. `skill-builder tune` accepts a current-conversation claim and representative schema-free UTF-8
    prose files with different shapes, while rejecting unreadable, non-regular, symlinked, or binary
    input without edits. Tests prove that headings and feedback-like IDs receive no special parsing.
12. Tune custody fixtures prove bare-slug and explicit source resolution, declared-name matching,
    tracked-source requirement, immutable-store exclusion, symlink/writability non-authority, and
    invalidation on target, declared name, Git root, HEAD, package-content, or named-input drift.
    Digest fixtures include clean tracked, dirty tracked, untracked, executable, and symlink entries.
    The helper prints facts only and has no global-home or feedback-store argument.
13. Tune behavior fixtures prove claim revalidation, history inspection, clustering, every
    disposition, coherent-batch selection, explicit target/change acceptance, target-contained edits,
    focused checks, and host lint. False, stale, unsupported, project-specific, and out-of-scope
    claims cause no corresponding edit.
14. Failure at proposal acceptance, source-identity recheck, edit application, package checks, or
    host lint produces no external lifecycle mutation, commit, issue, publication, or global write.
    `review` remains
    byte-for-byte read-only and `calibrate` retains its doctrine-only contract.
15. A live-reference sweep reports no predecessor names or contracts outside same-line annotated
    negative fixtures. Every new safety or reference-sweep check is
    red-proved by planting the forbidden condition, observing failure, restoring byte identity, and
    observing green.
