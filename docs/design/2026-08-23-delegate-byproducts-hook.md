---
doctype: specs
status: published
created: 2026-08-23
updated: 2026-08-24
tags: [spec]
---

# Delegate byproducts — return-contract overlay + owned setup — Spec

This library's design home is `docs/design/` (patient-zero). This spec
lives here. It doubles as the implementation plan.

Dependencies (land first):

- `docs/design/2026-08-24-clankshop-faceless-pack.md` — no face-owned
  hook publisher.
- `docs/design/2026-08-23-workspace-kinds.md` — canonical hook path is
  `delegate/hooks/byproducts.md`.

This spec owns Delegate only. It does not amend Backlog, publish another
skill's hook, or edit a sibling spec during implementation.

## Problem

Delegated work returns the requested deliverable and status, but useful
observations outside that narrow deliverable are easily lost when the
delegate's context disappears. The current prose compensates with a
fixed byproduct taxonomy and a cross-skill drain instruction. That
taxonomy is neither portable nor project-specific.

The return contract needs a stable third part while letting a project
define what counts as a byproduct. The policy must be optional, read
directly by the agent, and owned by Delegate. A pack assembler or
runtime hooks engine would create a second owner and unnecessary
machinery.

## Goal

After this feature:

- Every delegated return has exactly three parts:
  `Deliverable`, `Status`, and `Byproducts`.
- `Byproducts` always exists. With no applicable item it is exactly
  `- None.`.
- A project may define byproduct policy at:

  ```text
  <agent-workspace>/delegate/hooks/byproducts.md
  ```

- `/delegate setup` deploys the exact empty package skeleton from
  `skills/delegate/templates/hooks/byproducts.md` absent-only. It owns
  and touches no sibling namespace.
- On every dispatch, Delegate reads the project file once before
  sending the prompt. Missing or empty means no additional policy. A
  non-empty snapshot is appended to the delegate prompt and governs
  handling of that return.
- The core three-part contract is portable and does not depend on the
  project file. The overlay may add project-specific detection and
  routing guidance but cannot replace the three headings.
- There is no runtime parser, staged Delegate script, generic hooks
  framework, pack fill, taxonomy, compatibility path, or fallback to an
  old workspace location.
- Lint `fails=0`; Delegate setup/skill-doc harnesses are green.

## Approach

**Chosen: invariant core contract plus one direct-read, dispatch-scoped
policy overlay.** The package defines the shape; the project defines
what extra observations matter locally.

The skeleton is intentionally zero bytes. Installing Delegate policy
should not silently add policy. Explicit setup merely creates the
project-owned override point.

**Rejected: optional third heading.** Callers and delegates would need
branching prose and useful “nothing found” evidence would disappear.

**Rejected: fixed kinds.** Categories such as bugs, feedback, cleanup,
or follow-ups are host policy, not transport law.

**Rejected: runtime reader or staged Delegate entrypoint.** One known
Markdown file is cheaper and clearer to read directly. No script is
needed to parse an optional whole-file overlay.

**Rejected: pack publication or fill.** Delegate owns its durable
project surface and exposes its own explicit setup.

**Rejected: general before/after hooks.** This feature has one semantic
need: define return byproducts. A generic lifecycle system would exceed
the feature.

## Mechanism

### Project surface

Package skeleton:

```text
skills/delegate/templates/hooks/byproducts.md
```

Project policy:

```text
<root>/<agent-workspace>/delegate/hooks/byproducts.md
```

Ownership:

| Surface | Owner | Policy |
|---|---|---|
| package skeleton | Delegate package | exact empty bytes |
| project hook | project through `/delegate setup` | incumbent wins |
| core return contract | Delegate package | package law |

### `/delegate setup`

Add:

```text
/delegate setup [<root>]
```

`<root>` defaults to the current repository root and must exist.
Canonicalize it, resolve `agent-workspace:` from the front door (default
`.dev`), and reject empty, `.`, absolute, or root-escaping declarations.

Explicit setup may create only:

```text
<agent-workspace>/delegate/hooks/
```

Refuse a symlink or non-directory in the workspace, owner, or hooks
parent chain; recheck immediately before each mkdir/copy. Resolve the
empty skeleton relative to the installed Delegate package.

Deployment:

1. Skeleton missing or not a regular file → refuse; write nothing.
2. Destination absent → copy exact bytes.
3. Destination is an existing regular file → preserve it as incumbent.
4. Destination is a symlink, directory, or other incompatible entry →
   refuse; never follow a symlink to read or write.
5. Rerun is idempotent. A later package skeleton change does not
   overwrite project policy; upgrade is a human diff.

If setup created the empty file, scoped-commit exactly that file when
standalone. If nothing changed, do not commit. No front-door
registration is added: Delegate is a transport mechanism and the empty
policy has no captured items to surface.

### Dispatch snapshot

For every `/delegate` dispatch, before constructing the delegate prompt:

1. Resolve root and `<agent-workspace>` read-only.
2. Read exactly `delegate/hooks/byproducts.md` once.
3. Missing or zero-byte file → no overlay.
4. Non-empty regular file → retain exact snapshot for this dispatch.
5. Directory, unreadable entry, or read error → surface the problem and
   do not dispatch under ambiguous policy.

Do not trim a non-empty file into emptiness, glob hooks, merge multiple
files, or reread on return. A host overwrite takes effect on the next
dispatch, not the in-flight one.

When non-empty, append a delimited prompt block:

```text
Project byproducts policy (applies to this dispatch):
---
<exact snapshot>
---
```

The block cannot redefine the requested deliverable, transport mode,
status vocabulary, or mandatory return headings.

### Core return contract

Every delegate prompt requires this exact semantic structure:

```markdown
## Deliverable
<the requested artifact or conclusion>

## Status
<DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED>

## Byproducts
- <compact observation outside the deliverable>
```

If none:

```markdown
## Byproducts
- None.
```

Byproducts are not permission to expand the assignment. The delegate
reports them compactly because its context will be discarded. It does
not implement them, mutate unrelated files, contact external systems,
or turn them into records unless the original task explicitly required
that work.

The caller consumes the three parts independently:

- validate/apply the Deliverable;
- use Status for control flow:
  - `DONE` → verify the returned evidence, then proceed;
  - `DONE_WITH_CONCERNS` → investigate the named doubt before accepting;
  - `NEEDS_CONTEXT` → supply the missing fact and redispatch rather than
    guessing or repeating the unchanged prompt;
  - `BLOCKED` → escalate the model or narrow the task; repeated blocks on
    the same underlying work challenge the task or plan;
- interpret Byproducts through the same dispatch snapshot, if any, and
  otherwise present them as observations for the calling context.

These are the existing task-status states. They remain distinct from
provider failure and its retry/fallback policy; this feature changes the
return shape and byproducts policy, not Delegate's control-flow vocabulary.

An overlay may say how the host wants certain byproducts routed, but the
core contract names no destination skill or taxonomy.

### Live prose population

Update every instruction capable of constructing a delegate prompt or
return expectation, including the main router and provider references.
Keep one canonical return-contract block in `SKILL.md`; provider files
point to that contract and carry only provider-specific transport.

The Delegate description remains self-scoping. It may name dispatch,
routing, model choice, setup, and byproducts policy; it names no sibling.

### Spec ownership

This spec exclusively owns:

- Delegate's return contract and dispatch snapshot;
- `delegate/hooks/byproducts.md` and `/delegate setup`;
- removal of old Delegate taxonomy/cross-skill return prose;
- Delegate tests and package documentation;
- Delegate's exact seam span in the root faceless runbook.

It does not own workspace grammar, Backlog, pack setup, another skill's
hooks, or sibling spec amendments.

## Verification

**Setup**

- fresh default and declared workspace setups create only
  `delegate/hooks/byproducts.md` with exact zero-byte package contents;
- present empty and non-empty regular destinations are preserved;
- destination symlinks refuse without being followed;
- workspace/owner/hooks parent symlinks refuse without escape writes;
- incompatible parents/destinations refuse;
- second setup is a no-op and creates no commit;
- first standalone setup commits only the new hook and leaves a clean
  worktree;
- mutation red-proof permits a parent symlink once and makes the escape
  fixture fail.

**Contract and dispatch**

- exact canonical prompt population requires all three headings and the
  exact empty sentinel;
- missing/empty policy yields no prompt overlay;
- non-empty policy is inserted once and exact bytes are retained for
  return handling after an in-flight file change;
- unreadable/incompatible policy refuses before dispatch;
- injected policy cannot remove or rename core headings;
- weak-model examples still return the three-part shape.

**Absence**

- zero old fixed taxonomy or cross-skill drain instruction throughout
  `skills/delegate/`;
- zero kind-first `hooks/delegate` paths;
- zero runtime `*.sh` directly under `skills/delegate/scripts/` (test
  harness files under `scripts/tests/` are allowed);
- zero pack publisher/glue dependency;
- zero sibling spec path in implementation slices.

Red-proof the canonical-span, old-path, and runtime-script absence
assertions. Delegate and library lint green.

## Slices

| id | does | verify | paths |
|---|---|---|---|
| D1 | Hard-cut the always-three-part return contract and dispatch-scoped optional overlay through all Delegate prose | canonical-span and prompt fixtures | `skills/delegate/SKILL.md`, `skills/delegate/references/**`, `skills/delegate/scripts/tests/run.sh` |
| D2 | Add exact empty skeleton and Delegate-owned setup with symlink-safe absent-only deployment/scoped commit; update Delegate's faceless-pack seam span | setup harness + mutation red-proof | `skills/delegate/templates/hooks/byproducts.md`, `skills/delegate/verbs/setup.md`, `skills/delegate/scripts/tests/**`, `PACK.md` (Delegate seam span only) |

Land order D1 → D2. Workspace-kinds and Backlog have already landed.
There is no semantic Backlog dependency; the portfolio order only
serializes their disjoint root-runbook spans. Inspector follows.

## Out of scope

- Backlog schema, debrief, or setup.
- Pack glue, pack setup, or project-wide hook publication.
- Workstream dispatch or hook behavior.
- Generic lifecycle hooks or a shared parser.
- Runtime Delegate scripts beyond its test harness.
- Compatibility reads, aliases, adoption, or migration.
