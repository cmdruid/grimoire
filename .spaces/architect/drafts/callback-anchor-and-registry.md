# Callback anchor and registry

Disposition: promoted

## Problem or question

Extract Backlog's debrief anchor into a dedicated callback skill that recognizes a fixed catalog of
agent-observable events, dispatches explicitly registered agent instructions or skill commands, and
lets Backlog participate as a subscriber. The material uncertainty was whether current Grok and
Codex harnesses reliably follow the added anchor → dispatcher → ordered-action indirection.

## Constraints and candidate approaches

The callback runner never executes arbitrary shell handlers. Registrations are explicit project
configuration and use either a validated skill command or a subscriber-owned Markdown instruction.
The event catalog is closed; version one contains only `work-unit-boundary@1`. The callback skill
owns the exact front-door anchor, registry, provider, ordering, and boundary protocol. Subscriber
setups do not mutate callback state.

The chosen design uses provider-owned relative ordering (`first`, `last`, `before`, `after`) rather
than user-managed numeric priority. Every registration declares `on-failure=block` or
`on-failure=advise`. Advisory failure is reported and dispatch continues. Blocking failure reports
the callback, keeps the boundary pending, and halts immediately before later callbacks or the next
work unit. Registry or dispatcher failure blocks globally.

The approved specification places shared durable configuration in a fixed public `.callbacks/`
layer rather than the owner-local workspace. `/callback setup` creates an empty initialized layer;
`/callback repair` restores only package-managed surfaces and never reconstructs registry data.
Backlog makes a hard cut to a lean route, and automatic debrief is activated only by an explicit
registration owned by the operator or an attended composition sweep.

## Decisions and evidence

- Callback payloads are agent instructions or skill commands, never executable shell handlers.
- Registration is explicit through the callback provider; it is not performed by subscriber setup.
- The catalog is fixed and initially exposes only `work-unit-boundary@1`.
- Both advisory and blocking policies are part of `callback-registry@1`; blocking is fail-fast.
- Reordering uses stable subscriber IDs and relative move operations; omitted placement appends.
- `.callbacks/registry.tsv` is ordered public project configuration and `.callbacks/callbacks.sh`
  is its sole guarded writer and read-only dispatcher.
- `/callback repair` may refresh the provider, README block, and anchor or clear a provably stale
  mutation lock; registry loss requires Git recovery.
- Backlog remains the tracker and debrief owner but no longer owns the event trigger. Its setup does
  not inspect or mutate Callback state.
- The direct Backlog anchor spike supports boundary detection in Grok and Codex for completion,
  autonomous transition, and pure-Q&A exclusion.
- The callback indirection spike passed all eight hosted Grok/Codex cells. It adds evidence for
  dispatcher indirection, ordered instruction and skill-command callbacks, advisory continuation,
  blocking fail-fast, and pure-Q&A silence. Deterministic provider/order tests and ShellCheck also
  passed.

## Open questions and next step

No design branch remains open. The argued specification now defines the public layer, schemas,
provider interface, exact anchor, setup and repair boundaries, mutation locking, action-time target
validation, Backlog hard cut, explicit pack composition, and deterministic plus hosted acceptance
gates.

The specification remains `status: draft` for human review. Nothing should be sequenced or
implemented from it until that review passes and the caller accepts publication.

## Spike notes

The attended experiment used eight fresh temporary Git fixtures under
`/private/tmp/grimoire-callback-anchor-spike.zy2Pj6`. All eight cells passed. Grok's transition cell
filed the fixture's visible deferred canary while Codex's did not; callback-before-Unit-Two ordering
remained unambiguous in both. Raw fixtures and hosted logs remain disposable and no production
callback implementation was written during the spike.

## Related records

- → specs/2026-08-29-callback-registry-and-explicit-backlog-debrief-subscription.md
- → spikes/2026-08-29-callback-anchor-dispatcher-harness-acceptance.md
- → spikes/2026-08-29-backlog-debrief-anchor-harness-acceptance.md
- → specs/2026-08-28-backlog-debrief-anchor-reliability.md
- → specs/2026-08-28-backlog-tracker-provider-discoverability.md
