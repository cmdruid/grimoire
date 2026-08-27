# `resource acquire|status|release …` · repository-local shared-resource coordination

The bundled `scripts/workstream-resource.sh` is the only supported writer of
`refs/workstream-resources/`. Resolve it from this skill's own package directory and pass absolute
paths. The helper owns strict parsing, compact facts, and Git compare-and-swap; this verb owns user
judgment and the canonical hand-off edit. Claims persist until exact-token release and never expire.
Age is diagnostic only.

## `acquire <resource> [--intent <text>]`

Runs only in a loaded workstream. Resolve `<root>`, `<stream>`, `<branch>`, and `<this-hand-off>` from
Coordinates, run START HERE, default omitted intent to `(unspecified)`, and invoke:

```text
workstream-resource.sh acquire <root> <stream> <branch> <this-hand-off> <resource> <intent>
```

On `state=acquired`, atomically rewrite the one `## Resource locks` section to add exactly
`resource-lock: <resource> <oid>` only after the ref exists. If that write fails, immediately invoke
`rollback <root> <resource> <oid>`. A failed rollback is a hard blocker: report the surviving facts
and never claim the acquisition failed cleanly. `already_owned=true` is an idempotent success.
`held`, `malformed`, or `inconsistent` enters the Blocker seam with the helper's bounded holder facts;
do not wait, poll, or infer takeover from age.

## `status [<resource>]`

Read-only and valid from the root or any linked worktree. Invoke `status <absolute-toplevel>
[<resource>]` and report its facts without changing a hand-off or ref. A free singular resource is an
expected negative result, not an error to repair.

## `release <resource>`

Runs only in a loaded workstream after START HERE. Invoke
`release <root> <stream> <this-hand-off> <resource>`. The helper reads the expected OID from the
canonical hand-off and deletes only through exact-token compare-and-swap. On `state=released`,
atomically remove only that exact `resource-lock:` line from the hand-off. If the hand-off rewrite
fails, stop: the stale declared-but-free line is intentionally fail-closed and the next validation
will report it. `already_free=true` is idempotent success only when no hand-off line exists.

## `break <resource>`

Attended emergency recovery only; never run it in an unattended loop. First invoke `status <root>
<resource>` and display the exact resource, OID, owner, branch, hand-off, intent, acquired time, and
age—or explicitly say its metadata is malformed while still displaying the ref OID. Require a human
confirmation naming that exact resource. Only then invoke `break <root> <resource> <displayed-oid>`.
The exact OID is the compare-and-swap identity, so a ref changed after confirmation is preserved and
reported as a blocker. A malformed claim may be broken only through this same attended exact-OID
path. Never edit the displaced stream's hand-off; its next validation must detect the stale token and
halt.

## Result discipline

Exit 0 means the requested state was established, 1 is an expected negative (`held`, `free`, or a
compare-and-swap rejection), and 2 is invalid or malformed/inconsistent state. Helper output is
facts, never an action recommendation. Git landing, ordinary worktree files, and independently
addressable environments do not become resource claims merely because this verb exists. The resource
name identifies the singleton while intent identifies its requested configuration: for example,
`acquire ducat-dev --intent config-a` and `acquire ducat-dev --intent config-b` contend on the same
resource; encoding configurations as separate resource names would defeat exclusion.
