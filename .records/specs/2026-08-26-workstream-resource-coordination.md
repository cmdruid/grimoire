---
doctype: specs
status: draft
schema: architect/spec@1
tags: [spec, workstream, coordination, locks]
---

# Workstream shared-resource coordination — Spec

## Problem

Workstreams can operate concurrently in isolated Git worktrees, but some development resources are
singleton outside Git. A Docker-backed development environment may support several configurations
while the host can afford to run only one configuration at a time. Two agents can currently notice
the conflict, inspect the running environment, negotiate ownership, and recover, but every collision
spends time and context on a fact that should be machine-readable.

Git landing is not part of this problem. Workstream already relies on Git's atomic fast-forward
ref update and rejects a second concurrent ship safely. The missing capability concerns external,
cooperatively managed resources whose tools do not know which workstream owns them.

## Goal

Give workstreams a portable, low-token way to acquire, inspect, and release an exclusive claim
on a named shared resource. A failed acquisition should immediately identify the holder and intent so
the caller can do other work or coordinate without rediscovering the conflict.

## Approach

Recommended: add a repository-local resource-lock registry owned by Workstream beneath the ignored
`.workstreams/` control area, plus one stable helper entrypoint and a grouped `resource` verb. A resource
name identifies the singleton (`ducat-dev`); the requested configuration is lock metadata, not part
of the resource name, so configurations still exclude one another.

The helper performs atomic state transitions and prints compact facts. The agent decides whether to
wait, do independent work, or ask the holder to release. Each lock has an opaque ownership token so an
old session cannot release a successor's claim. The live
hand-off records claims held by that stream, allowing `load` and recovery to revalidate them before
touching the resource.

Two alternatives remain useful boundaries:

- A hand-off-only convention is smaller, but has no atomic acquisition point; two agents can both
  observe "free" and claim the resource.
- An expiring lease clears abandoned ownership automatically, but the protected Docker environment
  cannot enforce fencing tokens. An old holder could continue after expiry while a successor takes
  over, producing the split-brain conflict the feature is meant to prevent.
- A broker daemon can provide heartbeats, fairness, and stronger enforcement, but adds a service,
  installation lifecycle, and platform dependency to a skill that currently works from ordinary
  files and Git. It is disproportionate for the first version.

## Mechanism

Public surface:

- `/workstream resource acquire <resource> [intent/configuration]` attempts one non-blocking atomic
  claim.
- `/workstream resource status [resource]` reports holder, intent, token generation, age, and whether the owning
  workstream still has a discoverable hand-off.
- `/workstream resource release <resource>` succeeds only for the recorded token and is idempotent for an already-free
  resource.
- `/workstream resource break <resource>` is the only way to clear another stream's lock. It requires explicit human
  authorization, records the displaced owner/token as evidence, and is never an autonomous recovery.

The verb invokes a bundled `scripts/workstream-resource.sh` entrypoint. The script does not remain
running and does not rely on a process-held `flock`: it atomically establishes or changes a persistent
ownership record, prints the resulting facts, and exits. The ownership record remains authoritative
until a token-matched release or an explicitly authorized break.

State lives under `<root>/.workstreams/.resources/` so all linked worktrees in one repository see the
same registry and no project setup is required. Repository-local scope is intentional: resources are
coordinated only among workstreams sharing that root. The state is local coordination data, ignored
by Git, and is not a durable project record. Resource names use a conservative slug grammar. Every
mutating operation returns facts such as `acquired`, `resource`, `holder`, `intent`, `acquired_at`,
and `token_matches`; it never blocks or sleeps.

The protocol is cooperative rather than a security boundary. Before changing a protected resource,
an agent revalidates its token. Lock age is diagnostic only: it never expires and never authorizes
takeover. A conflicting agent halts and reports the holder. `close` refuses while claims remain so
resource cleanup and release stay deliberate; recovery and `load` validate recorded claims rather
than assuming the hand-off snapshot is authoritative.

The first version should acquire one resource at a time and omit fairness queues, multi-resource
transactions, remote coordination, and a background heartbeat daemon.

Acquisition is fail-and-report. A held resource immediately returns compact ownership facts and a
non-success result; it does not block, poll, register a waiter, or infer when the caller should retry.
That keeps the coordination primitive deterministic while allowing the workstream to choose unrelated
work or halt at its normal blocker seam.

## Verification

Fixture tests should prove atomic exclusion under concurrent acquisition; compact fail-and-report
facts for the loser; wrong-token release
refusal; age classification without expiry; explicit human-gated break behavior; idempotent release;
malformed-state refusal; worktree-wide visibility; hand-off revalidation; and no interaction with
the existing Git landing path. Any newly added concurrency check must be red-proven before acceptance.

## Open questions

None at brainstorm weight. The specification pass must make the atomic state transitions and
workstream lifecycle integration fully falsifiable before implementation.
