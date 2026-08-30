---
doctype: specs
status: published
schema: architect/spec@1
tags: [spec]
---

# Clankshop skill simplification and seam tightening — Spec

## Problem

Clankshop is mechanically healthy: the skill lint gate has no failures, the pack integration tests
pass, and every executable skill test harness is green. Its remaining debt is architectural rather
than broken behavior.

Several packages describe facts or protocols outside their ownership boundary. Delegate and Mailbox
encode stale claims about which Codex dispatch mechanisms exist. Workstream repeats parts of their
delegation and transport protocols instead of limiting itself to the operational seam it consumes.
The pack runbook bypasses Workspace's public procedure in one place. Notepad uses a typed handoff to
describe an inline return to its caller. These inconsistencies make otherwise-independent skills
more expensive to maintain and allow a correct change in one package to leave another package
plausibly wrong.

The library also carries substantial migration and rationale prose. Some of that is load-bearing
safety doctrine; some is compatibility behavior; some is authoring commentary that no runtime agent
needs. Treating all repetition as removable would damage package independence, while leaving every
historical explanation in the runtime surface would keep increasing the cost of using and revising
the skills.

## Goal

Make Clankshop's delegation, workstream, workspace-validation, and typed-edge boundaries precise
without redesigning their workflows. After this change, each leaf states only the procedure it owns,
`PACK.md` holds the cross-skill composition, dispatch behavior is capability-based rather than tied
to a stale harness assumption, and every residual lint warning has an explicit disposition.

Reduce clear runtime-surface debt in the touched packages, but preserve intentional package-local
tools and supported migration paths.

## Approach

Perform one bounded seam-remediation change across the pack runbook and the affected leaf packages.
Use three rules:

1. **Capabilities over harness folklore.** A dispatch path is selected from the mechanisms actually
   exposed to the current agent. Native same-harness delegation is preferred when available;
   headless CLI execution remains a fallback or an explicitly selected route.
2. **The pack composes; leaves operate.** `PACK.md` names the Workstream → Delegate → Mailbox seam.
   Delegate may name Mailbox because Delegate is the router that selects transport. Workstream keeps
   only the operational pointer required to invoke delegation safely and does not restate another
   package's spawn, return, or fallback protocol.
3. **Remove only proven debt.** Delete stale facts, duplicated sibling protocol, and authoring
   boilerplate in touched surfaces. Keep self-contained runtime scripts and supported migration
   behavior unless separate evidence proves they are obsolete.

This pass rejects four broader alternatives:

- **Merge Delegate and Mailbox.** Rejected because dispatch judgment and artifact transport have
  distinct triggers, and merging them would enlarge Delegate's already-heavy routing surface.
- **Split Workstream or extract resource coordination.** Rejected until a focused substance review
  shows that the behavior is independently useful and that the split shrinks the operating surface,
  not merely the payload.
- **Centralize identical runtime helpers.** Rejected because shared runtime files would make bare
  skill installation incomplete. Exact package-local copies may receive an author-time equality
  check later, but remain local at runtime.
- **Remove migration support during prose cleanup.** Rejected because no compatibility horizon has
  been ratified. Migration recognizers remain until a versioned retirement decision names which
  prior installations no longer need them.

## Mechanism

### Capability-based delegation

Delegate owns the dispatch decision. Its procedure must distinguish capabilities from policy:

- Inspect the current harness for native subagent dispatch, model override, working-directory
  control, and isolated execution. These are observable facts.
- Prefer a native same-harness subagent for ordinary delegated analysis or file work when it
  satisfies the task's isolation needs. A native route does not require a claim that Codex or any
  other named harness always has or lacks a feature.
- Use `codex exec` only when native dispatch is unavailable, when an explicitly chosen external
  process is the required provider route, or when its executor semantics are otherwise material to
  the task. Keep the package reference as the procedure for that branch.
- Keep provider/model choice under Delegate's existing confirmation policy. Capability detection
  does not authorize an unapproved cross-provider or different-model route.
- Preserve Delegate's return contract and byproducts hook. This work changes dispatch selection,
  not the semantic result contract.

Mailbox owns pass-by-reference transport. Its spawn section becomes mechanism-neutral: the caller
uses its selected dispatch capability and supplies Mailbox's absolute slot and single-writer
contract. Mailbox must not claim that a named harness requires a particular dispatch primitive.
Its slot creation, tree-drift check, apply/consume distinction, and reap behavior remain unchanged.

### Workstream composition boundary

`PACK.md` gains one explicit seam: Workstream may ask Delegate to route a bounded work unit; when
Delegate selects Mailbox, Mailbox transports the returned artifact while Workstream's main session
remains the sole writer of the held target. Workstream remains fully functional without either
optional skill by executing inline.

Workstream may retain the following owner-local facts:

- whether a work unit is manual or delegated;
- that a held target has one main-session writer;
- the route selected for the current stream when that route is stored in Workstream's handoff;
- when the loop must fall back to inline execution.

Workstream must remove or replace prose that defines another package's mechanism, including claims
about how Codex or Claude spawns agents, Mailbox's slot protocol, Delegate's model table, Delegate's
return headings, or Delegate's provider-failure ladder. An operational instruction should invoke
Delegate's public procedure and then resume the Workstream loop from the returned result.

The same rule applies to `SKILL.md`, `flow.md`, verb files, and package-only handoff templates. A
template may store Workstream-owned execution state, but it must point to the owning procedure for
the meaning of a foreign protocol.

### Pack runbook and public procedures

`PACK.md` remains the faceless pack's manifest and human-readable composition runbook. Keep its
member inventory, seam map, bounded configuration profile, aggregate custody, and validation
sequence.

Tighten two parts:

- Add the Workstream → Delegate → Mailbox seam described above.
- During validation, invoke Workspace's public `/workspace check` procedure. Do not direct the
  composer to call `skills/workspace/scripts/workspace-check.sh` itself. Optional composition calls
  public procedures and preserves their guards.

Condense setup prose only where it repeats a member's own safety mechanics. The pack may state the
cross-member invariant—member-owned setup, absent-only project surfaces, one aggregate commit—but
must not become a second copy of each setup protocol.

### Typed-edge dispositions

Typed edges describe artifacts and control flow, not ordinary returns to the invoking caller.

- Change Notepad's `handoff` to empty. Its write-only sweep returns paths inline to the caller; no
  successor consumes a `note` baton. Keep `produces: note` and `consumes: note`.
- Keep Workstream's `resource-claim` as an unmatched produced type. It is observable repository-local
  coordination state and unmatched producers are valid leaf outputs.
- Keep Foreman's `goal`, `goal-pursuit`, and `session-evidence` warnings as documented external-runtime
  edges. This pass does not invent fake skill consumers to silence the gate.

The expected lint result remains zero failures and four warnings unless the gate later gains a
first-class exception registry. Append one dated disposition entry to `docs/boundary-audit.md` that
names all four warnings: Workstream's `resource-claim` is a legal leaf output, while Foreman's
`goal`, `goal-pursuit`, and `session-evidence` are external-runtime edges.

### Adjacent documentation and surface cleanup

Update adjacent inventory prose when it contradicts the owned procedure. In particular, README's
Auditor summary must not imply that an audit writes findings directly to trackers: findings remain
in the report and promote through the host's capture lane.

Within files already touched by this work, remove authoring-only assertions that add no operating
constraint, such as claims that a skill is “uniquely named,” “collides with none,” or follows the
library-wide typed-edge rule. The portable doctrine owns those rules. Auditor and Inspector package
files are outside this cleanup; updating README's Auditor inventory summary does not authorize an
Auditor implementation change.

Migration procedures, recognized legacy paths, and the four identical package-local
`scoped-commit.sh` helpers are explicitly retained. A later compatibility-retirement spec may remove
them only after it defines the supported upgrade window and proves which paths no longer have live
consumers.

## Verification

The implementation is acceptable when all of the following hold:

1. `bash skills/skill-builder/scripts/skills-lint.sh .` reports `fails=0`. Its four residual edge
   warnings are documented as intentional in `docs/boundary-audit.md`.
2. `bash scripts/tests/run.sh` passes pack installation and Clankshop configuration fixtures.
3. Every `skills/*/scripts/tests/run.sh` harness passes. Any touched prose contract receives a
   focused assertion or fixture when a mechanical check can protect it.
4. No touched skill claims that Codex lacks native model-routed subagents or that a named harness
   always requires one dispatch primitive.
5. Workstream contains no restatement of Mailbox's slot protocol or Delegate's spawn, return, model,
   or fallback contracts. Required operational pointers remain sufficient for a standalone reader.
6. `PACK.md` invokes Workspace through its public procedure and carries the Workstream delegation
   seam.
7. Notepad's edge block no longer uses `handoff: note`; the resource and Foreman warning dispositions
   are recorded in `docs/boundary-audit.md`.
8. README's Auditor summary agrees with Auditor's current delivery contract.
9. The implementation diff is confined to `PACK.md`, `README.md`, `docs/boundary-audit.md`, owned
   files under `skills/delegate/`, `skills/mailbox/`, `skills/workstream/`, and `skills/notepad/`, plus
   focused tests that protect those changes. It includes no Auditor or Inspector package changes and
   no unrelated records.
10. If any frontmatter `description:` changes, run a fresh cold routing probe against only the
    changed descriptions and record the prompts and result. If descriptions do not change, the
    existing routing evidence remains applicable.

Every new absence or guard check protecting criteria 4–7 must be red-proved against a fixture copy or
synthetic input: plant one representative forbidden case, prove the focused check fails, restore the
fixture byte-for-byte, and then prove it passes. At minimum, cover a named-harness dispatch claim, a
Workstream restatement of each foreign contract class (spawn, return, model, and fallback), a direct
Workspace script invocation in the pack runbook, and Notepad's former `handoff: note` declaration.

The artifact remains `status: draft` until review passes and the caller accepts it. Implementation
planning begins only after that acceptance.
