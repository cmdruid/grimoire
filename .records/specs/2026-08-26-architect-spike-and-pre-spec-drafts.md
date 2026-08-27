---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec, architect, spike, drafts]
---

# Architect spike and pre-spec design drafts — Spec

Related:

- `→ specs/2026-08-25-agent-workspace-naming.md`
- `→ specs/2026-08-25-skill-owned-artifact-migration.md`
- `→ adr/2026-08-25-record-metadata-schema.md`

## Problem

Architect currently turns every feature brainstorm directly into a dated `specs` record. That
makes an unresolved idea look like an official design artifact. Most brainstorms should remain
conversation, while an idea the user chooses to keep needs a lighter home that another session can
resume.

Architect also lacks a bounded way to answer an implementation-feasibility question before
specification. A useful spike may need disposable code and measurements. Its working notes are too
provisional for records, but the executing agent's completed account may become important evidence
for a later design.

The feature must preserve Architect's boundary: experimental code may be measurement apparatus, but
Architect does not implement production features. The agent workspace also has a closed kind
vocabulary that does not currently admit `architect/drafts/`.

## Goal

Keep brainstorming conversational and write-free by default. Let the user explicitly save one
living Markdown draft per idea under `<agent-workspace>/architect/drafts/`. Add a guarded `spike`
verb only for a material feasibility uncertainty that cheap investigation cannot settle. A
confirmed spike may run disposable code in isolation and keep working notes in the idea draft; a
completed experiment becomes a direct, self-contained `architect/spike@1` account under
`<agent-records>/spikes/`. Neither path produces production code or an implementation plan.

## Approach

Use two storage layers:

~~~text
idea
  -> conversation (default; no project write)
     -> specification record
     -> explicit save -> one living workspace draft
     -> necessary spike -> charter -> user confirms -> isolated experiment
        -> update workspace draft -> completed spike record
     -> discard with no artifact
~~~

The workspace draft is opt-in incubation state: one current synthesis, not an event log or a job.
The spike record is a stable account of what the executing agent tried and observed. It is citable
evidence, not an independently approved conclusion, and must stand alone if the draft disappears.

Architect receives a narrow exception to its no-build rule. `spike` may create and execute
disposable code solely to measure a design uncertainty. Experimental writes stay in disposable
isolation and never become project changes or an implementation deliverable.

Alternatives rejected:

- **Automatically save brainstorms.** Most brainstorms need no artifact; explicit user intent is
  the persistence boundary.
- **Keep brainstorms as draft spec records.** That continues to make every saved idea look like an
  incipient specification.
- **Add sessions, locks, or probe recovery state.** User-supervised agents can coordinate through
  one living file; an interrupted spike can simply be reconsidered.
- **Require independent approval of spike records.** A spike is an attributed experimental report.
  A later design review judges how the specification uses it.
- **Have Architect charter a spike but execute nothing.** That cannot test feasibility. Disposable
  measurement code is compatible with design work when it never becomes a deliverable.

## Mechanism

### Saved drafts

Add `drafts` as the seventh closed `<agent-workspace>/<owner>/<kind>/` kind. Its generic Workspace
shape is a nested Markdown tree: safe-named directories and `.md` regular files only, with no
symlinks or non-Markdown payloads. `drafts` becomes a reserved top-level kind stem and cannot be an
owner name. The canonical workspace contract, checker, lint, documentation, and live generic
consumers must agree on the new kind. Historical published records remain unchanged.

Architect stores one living file per saved idea:

~~~text
<agent-workspace>/architect/drafts/<idea-slug>.md
~~~

`<idea-slug>` is one lowercase kebab segment. A package-owned outline supplies:

- title and `Disposition: active | parked | promoted`;
- problem or design question;
- constraints and candidate approaches;
- decisions and evidence;
- open questions and next step;
- current or previous spike notes; and
- related spike/spec record links.

Disposition is Architect-owned body syntax, not record status. Parking or promotion preserves the
file. Deletion requires explicit user authorization.

The outline is package-only, not a project-customizable template. An authorized save or confirmed
spike may safely create Architect's narrow draft home on first write. Merely brainstorming or
running setup does not create an empty draft store.

### `brainstorm`

Bare `/architect` remains `brainstorm`. `/architect brainstorm [topic]` explores conversationally
and writes nothing by default. The user may proceed directly to `spec`.

- `/architect brainstorm save [name]`, or an unambiguous natural-language equivalent, creates or
  updates `<idea-slug>.md` with the current synthesis.
- An explicit valid draft path beneath Architect's resolved draft home authorizes resuming it.
- If the normalized slug already names the same titled idea, update it. A different title at that
  slug refuses and asks for another name or explicit path.
- No heuristic implies save permission: not duration, importance, unresolved questions, multiple
  agents, or the agent's judgment that the idea may matter.
- Brainstorm never creates a record.

Existing `status: draft`, `schema: architect/spec@1` spec records remain valid inputs to `grill`
and `spec`; they are not migrated into workspace drafts.

### `spike [draft-or-question]`

Add a routed `spike` verb accepting a valid Architect draft path or a free-text feasibility
question. Invocation requests consideration, not execution permission. No other Architect verb
invokes it automatically. One invocation addresses one feasibility question in four phases:

1. **Qualify.** Use read-only investigation first. A spike is warranted only when material
   uncertainty blocks a design choice, cheaper evidence cannot resolve it, the result could change
   that choice, and a bounded experiment is possible. Otherwise explain the cheaper path and stop.
2. **Charter and confirm.** Present the question, decision relevance, hypothesis, success criterion,
   expected cost, and stopping condition. Explicit user confirmation is required even after a
   direct `/architect spike`. Before confirmation, write no draft and run no experiment.
3. **Experiment.** After confirmation, create or resume the idea draft and record the charter.
   Inspect the project read-only. Experiment code, fixtures, generated data, and build output stay in
   disposable isolation; the only durable writes authorized by the spike are its Architect draft
   notes and completed record. Retain normal approval boundaries for external effects. Save the
   method, observations, failures, and limitations to the draft.
4. **Conclude.** Stop at the charter's condition or budget. When the bounded attempt is complete and
   its account is coherent, publish the spike record below and link it from the draft. Positive,
   negative, and inconclusive results are all valid accounts. Incomplete or interrupted work remains
   draft notes; resumption rechecks the charter and asks again if its assumptions or cost changed.

### Spike records

A completed spike publishes:

~~~yaml
doctype: spikes
status: published
schema: architect/spike@1
tags: [spike, feasibility]
~~~

Its path is `<agent-records>/spikes/YYYY-MM-DD-<slug>.md`; links use
`→ spikes/YYYY-MM-DD-<slug>.md`. Architect uses a package-owned body outline. It uses the executable
records tool opportunistically with explicit roots; without that tool it creates its own store and
writes the same record in file mode. Both modes stage the record as `draft`, complete and validate
its body, and only then change it to `published`. A failed write remains `draft` rather than posing
as a completed account.

`architect/spike@1` contains:

1. question and decision relevance;
2. executor, baseline, and environment;
3. hypothesis, success criterion, and budget;
4. method, reproduction commands, and observations; and
5. conclusion, limitations, and remaining uncertainty.

One record answers one question. Every fact needed to understand the method and conclusion is in
the record or a durable source it cites; the workspace draft is provenance, not a dependency.
`published` means stable and citable, not independently endorsed. Corrections or materially changed
evidence create a linked successor rather than silently rewriting the original account.

Architect owns the `architect/spike@1` contract and validator. The body outline is package-only;
setup deploys no new template, and there is no legacy spike or draft migration.

### Promotion into specification

`/architect spec <draft>` recognizes the canonical workspace draft, incorporates settled
decisions into a new or existing `architect/spec@1` record, cites completed spike records on which
the design relies, then marks the draft `promoted` and adds the spec link after that record exists.
Raw working notes and transient code are not copied. Ordinary specification review judges whether
the cited evidence supports the design; no separate spike-review workflow exists.

### Skill boundary and composition

Architect's description and router add draft-incubation and feasibility-spike triggers while
replacing “does not build” with the more exact boundary: it does not implement production
features; `spike` may run disposable code solely as measurement. Architect produces draft and
spike artifacts, but only an accepted specification is a feature handoff.

The package remains complete without another skill's setup. Missing records tooling takes the
file-mode path, and authorized capture creates only Architect's own workspace path and record
store.

## Verification

- Brainstorm transcript tests prove conversation writes nothing unless the user explicitly saves;
  save and resume cover safe names, collisions, and path containment.
- Spike transcript tests prove cheap investigation can refuse a spike, confirmation is mandatory,
  and neither a draft write nor an experimental command occurs before confirmation.
- Isolation tests prove experiment code, fixtures, generated data, and build output cannot escape
  disposable isolation; the only durable project writes are the authorized Architect draft and
  completed spike record.
- Record tests cover positive, negative, and inconclusive completed accounts; executor and context;
  tool and file modes; direct publication only after complete content; and independence from the
  workspace draft.
- Promotion tests prove `spec <draft>` preserves existing draft-spec inputs, cites completed spike
  records it relies on, and marks the workspace draft only after the specification exists.
- Workspace tests accept safe Markdown under the seventh `drafts` kind and reject unsafe payloads,
  symlinks, reserved-owner collisions, and unknown kinds.
- Architect, Workspace, portable-doctrine, skill-builder, and repository lint gates pass with one
  consistent seven-kind vocabulary and no deployed patient-zero assets.
- Every new absence or rejection assertion is mutation-red-proved by disabling its guard and
  observing the corresponding test fail.
