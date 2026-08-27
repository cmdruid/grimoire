---
doctype: specs
status: draft
schema: architect/spec@1
tags: [spec, workstream, coordination, locks]
---

# Workstream shared-resource coordination — Spec

## Problem

Workstreams isolate source changes in Git worktrees, but they do not isolate external development
resources. A Docker-backed development environment may support several configurations while the host
can afford to run only one configuration at a time. Two agents can currently inspect the running
environment, notice a collision, negotiate ownership, and recover, but every collision spends time
and context rediscovering a fact that should be atomic and machine-readable.

Git landing is not part of this problem. Workstream already relies on Git's fast-forward ref update:
one concurrent ship wins and the other is rejected safely. The missing capability concerns external,
cooperatively managed resources whose tools do not know which workstream owns them.

The resource constraint is real rather than an avoidable code constraint: the host cannot afford two
DUCAT configurations simultaneously. The design therefore pays the cost of coordination rather than
pretending the singleton can be removed in this feature.

## Goal

Give workstreams a portable, low-token way to acquire, inspect, and release exclusive ownership of a
named repository-local resource. Exactly one claimant wins; a loser immediately receives enough facts
to identify the holder and halt at the blocker seam without probing Docker or negotiating from
scratch.

Done means the claim survives command exit and context resets, never expires, cannot be released by a
stale token, is automatically relinquished by a successful `/workstream close`, and requires explicit
human authorization to break when its owner cannot release it.

## Approach

Add a grouped `/workstream resource` verb backed by one bundled mutation helper. The registry is a
local custom Git-ref namespace, `refs/workstream-resources/<resource>`, shared by every linked
worktree in the repository and not pushed or fetched by ordinary branch operations. Each ref points
to an immutable metadata blob; the blob object ID is the ownership token.

Git is already Workstream's required coordination substrate. `git update-ref` supplies atomic
compare-and-swap for one claim and an all-or-nothing `--stdin` transaction for releasing several
claims. A disposable-repository probe on the host confirmed that concurrent create-from-zero rejects
the loser, a wrong expected object ID rejects deletion, and one wrong deletion rejects an entire
multi-ref batch without changing any ref.

Settled by the user on 2026-08-26:

- Claims are repository-local and persistent; age is diagnostic and never expiry.
- Acquisition is non-blocking fail-and-report; there is no waiter or fairness queue.
- Another stream's claim can be broken only after an explicit human confirmation.
- `/workstream close` automatically releases the closing stream's exact token-matched claim set before
  teardown.
- The public surface is one grouped verb invoking the atomic helper.

Rejected alternatives:

- Hand-off-only ownership has no atomic acquisition point; two agents can both observe "free."
- A filesystem `mkdir` makes acquisition atomic but needs a second crash-safe mutex to make release
  and break compare-and-swap operations. Git refs provide that transaction without a new lock layer.
- Expiry or automatic stale takeover is unsafe because Docker cannot fence an old holder. Time passing
  does not prove that holder stopped touching the environment.
- A broker daemon adds installation, heartbeat, recovery, and platform lifecycle for no v1 benefit.
- A FIFO queue cannot wake an agent without such a daemon and introduces abandoned-waiter cleanup.

## Mechanism

### Public contract

The new verb file defines four user operations:

- `/workstream resource acquire <resource> [--intent <text>]`
- `/workstream resource status [<resource>]`
- `/workstream resource release <resource>`
- `/workstream resource break <resource>`

`status` is read-only and may run from the root or any worktree. `acquire` and `release` require a
loaded workstream, its canonical hand-off, and a passing START HERE guard. `break` may run from a
coordinator or workstream session, but only with a human present and only after the verb shows the
current holder facts and receives explicit confirmation naming that resource. It is never available
to an unattended loop.

The resource name is the singleton, while `intent` describes the requested configuration. For
example, both `--intent config-a` and `--intent config-b` acquire `ducat-dev`; configurations must not
be encoded as distinct resource names or they would cease to exclude one another.

Resource names are one lowercase kebab segment: 1–63 bytes, ASCII lowercase letters and digits with
internal hyphens, no leading or trailing hyphen. The owner must satisfy `create`'s existing stream-name
grammar; this feature does not narrow it. Intent defaults to `(unspecified)`, is one non-empty argument
of at most 256 bytes, and rejects CR, LF, NUL, and other control characters. Intent is diagnostic and
must not contain secrets.

### Registry and claim format

The exact ref is `refs/workstream-resources/<resource>`. The helper is the only supported writer of
that namespace. It resolves the repository from the absolute root supplied by the verb, verifies that
`git -C <root> rev-parse --show-toplevel` resolves back to that root, and never derives correctness
from cwd.

An active ref points directly to a blob with this version-1, newline-terminated grammar in this exact
order:

```text
version=1
resource=<resource>
owner=<stream>
branch=stream/<stream>
handoff=<absolute canonical WORKSTREAM.md path>
intent=<single-line text>
acquired_epoch=<Unix seconds>
acquired_at=<UTC RFC 3339 seconds>
nonce=<opaque unique value>
```

The nonce is generated from a real `mktemp` allocation, not `mktemp -u`; it makes a rapid reacquire by
the same owner produce a different blob and therefore a different token. The token is the blob object
ID, with no SHA-1-length assumption: validation accepts the repository's object format. An active ref
keeps its blob reachable from garbage collection. Released blobs become ordinary unreachable Git
objects and require no bespoke cleanup.

Unknown versions, duplicate/missing/reordered keys, a non-blob target, a missing object, invalid
names, invalid time fields, a non-absolute hand-off path, or unsafe intent make the claim `malformed`.
Malformed claims remain held and block acquisition. They never become implicitly free.

### Atomic helper

Add `workstream-resource.sh` under `skills/workstream/scripts/`, resolved from Workstream's own package
directory. It is Bash-3.2 and BSD/macOS safe, accepts an absolute root on every subcommand, emits
compact `key=value` facts plus bounded evidence, and never sleeps or recommends an action.

Its public/internal subcommands are:

- `acquire <root> <stream> <branch> <handoff> <resource> <intent>`
- `status <root> [<resource>]`
- `validate <root> <stream> <handoff>`
- `release <root> <stream> <handoff> <resource>`
- `release-all <root> <stream> <handoff>`
- `break <root> <resource> <expected-oid>`
- `rollback <root> <resource> <expected-oid>`

The verb owns the human decision; the helper owns validation and mutation. Exit `0` means the
requested state was established, exit `1` is an expected negative outcome such as held, absent, or
compare-and-swap rejection, and exit `2` is invalid/unsafe/malformed input. Every outcome prints
`operation`, `resource` when singular, `state`, and the relevant booleans. Held-state evidence also
includes `owner`, `branch`, `handoff`, `intent`, `acquired_at`, `age_seconds`, and `oid` when readable.
`age_seconds` floors at zero if the wall clock moved backward. No output uses age to recommend
takeover.

Acquire creates the metadata blob, computes the all-zero object ID at the repository's actual hash
length, then runs:

```text
git update-ref refs/workstream-resources/<resource> <new-oid> <zero-oid>
```

Only that compare-and-swap decides the winner. A rejected acquire rereads the winning ref and emits
its bounded holder facts. If the holder is the current stream and the canonical hand-off already
contains the same resource/OID pair, the verb reports `already_owned=true` and succeeds idempotently.
The same owner with an absent or different hand-off token is an inconsistency and halts.

Release parses the expected OID from the current stream's hand-off and deletes only through
`git update-ref -d <ref> <expected-oid>`. A free resource with no hand-off entry is an idempotent
success. A declared-but-free resource, wrong owner, wrong token, or changed ref halts and leaves the
hand-off unchanged.

`break` first runs `status`. The verb displays the exact resource, owner, intent, age, hand-off, and
OID and asks for explicit confirmation. The helper then deletes only with that displayed OID as the
expected old value. If the ref changed between confirmation and deletion, compare-and-swap rejects the
break. Malformed claims may be broken the same way because the ref's OID is still an exact identity;
the verb must say that metadata validation failed. Break prints the displaced facts as evidence but
does not edit another stream's hand-off. That stream's next validation detects the loss and halts.

`rollback` is an internal compensation used only when acquire won but writing the new hand-off entry
failed. It performs the same exact-OID deletion without a human prompt. If rollback fails, the verb
reports the surviving ref and token as a hard blocker; it never claims acquisition failed cleanly.

### Hand-off custody

Add a `## Resource locks` section to the bundled hand-off template. Its machine-readable lines are:

```text
resource-lock: <resource> <oid>
```

No line means none; prose such as `(none)` is ignored. Resource and OID validation is strict, duplicate
resource lines are malformed, and intent is retrieved from the blob rather than duplicated into the
hand-off. The section is an ownership-token snapshot, so the template says to verify it before
trusting it.

On successful acquire, the verb adds the exact line only after the ref exists. If the hand-off write
fails, it invokes token-matched `rollback`. On successful release, the verb deletes the ref first and
then removes the line. If that hand-off write fails, the stale line is fail-closed: `load`/`validate`
reports a declared-but-free mismatch instead of silently treating ownership as live.

`save` preserves this section verbatim across template regeneration, just as it preserves immutable
Coordinates and compiled hooks. `create` instantiates it empty. `recycle` preserves it because resource
ownership is stream-scoped, not feature-unit-scoped.

`load` runs `validate` after START HERE and before Confident launch. Validation is bidirectional: every
handoff line must name a live ref with the same OID and owner, and every valid registry claim whose
metadata owner is this stream must appear in the hand-off. Any missing, extra, malformed, or mismatched
claim is a hard stop. A passing validation reports the held resources and their current intents.

Before a protected external-resource operation, the agent runs the same validation. Workstream cannot
infer which host commands use which resources; the host procedure that starts, stops, tests, or
reconfigures the singleton must name the resource acquisition as its prerequisite. This feature is a
cooperative correctness protocol, not an OS security boundary.

### Close and teardown

`close` automatically relinquishes ownership. After its ordinary ship-or-discard decision is settled
but before worktree/branch teardown, it invokes `release-all <root> <stream> <handoff>`.

`release-all` parses the hand-off resource/OID set, scans the entire ref namespace for valid claims
whose metadata owner is the stream, and requires the sets to match exactly. An absent claim, extra
claim, duplicate, malformed hand-off-named claim, or token mismatch exits nonzero without changing
any ref. An exact set is passed as expected-OID deletes to one `git update-ref --stdin` transaction.
One rejected delete rejects the whole batch. Only exit `0` with `released=<count>` permits teardown;
zero is valid.

`--force` in close continues to mean discard Git WIP and never bypasses the resource gate. The bundled
worktree teardown helper also calls the resource validation guard and refuses direct teardown while
the stream owns or declares a claim, preventing callers from bypassing close accidentally. In-place
teardown applies the same guard in prose before switching branches or removing the hand-off.

If resource release succeeds and later Git teardown fails, close reports that locks were released and
does not resume protected-resource work implicitly; the surviving stream must reacquire before any
such operation. Close does not stop or reconfigure the external resource. It states only that the
terminated workstream will no longer touch it.

`park`, `save`, `sync`, `ship`, and ordinary feature boundaries neither release nor reacquire claims.
A context reset therefore retains ownership. A stream may release early with the public verb when it
no longer needs the resource. A stream may hold several distinct resources, acquired one at a time;
only close uses a multi-resource transaction.

### Scope and non-goals

The registry is repository-local by construction. Custom refs are not pushed, fetched, merged, or
landed by ordinary Workstream operations. No front-door variable, project setup, daemon, Docker
integration, remote registry, expiry, renewal, heartbeat, automatic reclaim, waiter queue,
multi-resource atomic acquisition, or fairness policy is added.

Git shipping remains unchanged and does not acquire a resource lock. The existing fast-forward reject
continues to serialize trunk advancement. Resource locks coordinate only external singleton use.

## Verification

Add `resource-test.sh` beneath the existing Workstream script-test directory and register it in that
directory's runner. All fixtures use disposable repositories and linked worktrees; no test touches the
library's real refs or `.workstreams/` state.

The fixture suite proves:

1. Two simultaneous acquire processes for one free resource produce exactly one winner and one held
   result; the loser reports the winner's bounded holder facts.
2. Different intents for the same resource conflict, while distinct resource names can be held
   concurrently.
3. Same-stream acquire is idempotent only when the hand-off carries the current OID.
4. Wrong-owner, wrong-token, stale-token, and ref-changed release/break attempts preserve the winner.
5. A lock with an arbitrarily old acquisition time remains held and is never classified free.
6. A malformed blob/ref fails closed; status reports malformed, acquire refuses, and only an
   explicitly confirmed exact-OID break can clear it.
7. SHA-length handling derives from the repository rather than assuming 40 characters.
8. Acquire hand-off-write failure rolls the exact claim back; a failed rollback reports the surviving
   claim. Release hand-off-write failure leaves a detectable declared-but-free mismatch.
9. Bidirectional load validation catches every missing, extra, duplicate, wrong-owner, and wrong-OID
   case and accepts a matching multi-resource set.
10. `release-all` deletes a matching multi-resource set atomically; one wrong expected OID preserves
    every ref in the batch.
11. Close refuses before teardown on validation/release failure, releases before a successful teardown,
    and does not let `--force` bypass the gate. Direct worktree teardown refuses held claims.
12. Create starts with no resource lines; save and recycle preserve exact lines; break leaves the old
    holder's hand-off stale so its next load halts.
13. Ordinary `sync`/`ship` operations neither enumerate nor mutate `refs/workstream-resources/`, and
    active refs do not dirty either checkout.
14. Status works from root and linked worktrees and resolves the same repository-local registry.

The new concurrency assertion must be red-proven by deliberately replacing create-from-zero with an
unguarded ref update, confirming that both contenders can report success, then restoring the
compare-and-swap implementation and confirming byte-identical fixture restoration plus a green test.

The implementation gate is the Workstream script-test runner, ShellCheck over the new/changed shell
helpers, the library's skills lint, and the host's full gate because executable files change. The
specification remains `status: draft` until a passing review the user accepts; implementation must not
be sequenced before that publication decision.
