---
doctype: reports
status: archived
schema: debugger/investigation@1
tags: [skill-feedback, implementation-review]
---

# Skill feedback implementation review fixes

## Reproduction

Disposable homes reproduced four failures against the initial implementation: an impossible
calendar timestamp and a non-UTF-8 summary were accepted; ownership markers after an inner
three-backtick line in a four-backtick fence were treated as live; a symlinked but physically
resolvable `HOME` was rejected by the anchor; and a planted ID collision did not have deterministic
coverage. The approved plan also named boundary, path, permission, and ambiguous-lock cases absent
from the initial suite.

## Root cause

The provider validated byte shape rather than UTF-8 and calendar semantics. The anchor represented
Markdown fencing with one Boolean instead of retaining the opening delimiter and length, and it
rejected `HOME` before physical resolution. The test suite covered happy paths and representative
guards but did not implement the plan's full adversarial matrix.

## Evidence

Each failure was first made red in a package-local test. The invalid-byte and impossible-time
fixtures were accepted before provider changes; nested fence fixtures lost their example body;
symlink-home preview returned `unsafe-home`; and the deterministic collision fixture consumed only
one random value instead of rerolling.

## Fix + verification

The provider now validates UTF-8, control bytes, calendar dates, time ranges, and timestamp-bearing
IDs, while deriving capture IDs from the same validated timestamp. The anchor now physically
resolves `HOME` before descendant checks and uses delimiter-aware fence state. The suite adds exact
field and row limits, encoding round-trips, malformed incumbents, every path component, permission
tightening, ambiguous locks, deterministic collision reroll, nested fences, and home-resolution
parity. The package finished with 305 passing assertions; Backlog finished with 841; repository
integration, quick validation, warning-level shellcheck, skill lint, and `git diff --check` passed.

## Findings

#### validate-semantics — Validate semantics at persistence boundaries

Shape checks alone do not establish a UTF-8 or RFC 3339 contract. Persisted formats need invalid
byte sequences and impossible calendar values in their whole-file validation fixtures.

#### parse-fence-state — Track Markdown fence identity

A Markdown fence scanner must retain delimiter character and opening length; a Boolean toggle makes
valid nested example bytes look like live document structure.

#### resolve-home-first — Distinguish the home root from descendants

When the contract says to resolve home physically and reject symlinked descendants, rejecting a
symlinked home before resolution changes the contract and creates parity failures between helpers.

#### implement-test-matrix — Treat approved adversarial cases as implementation scope

A green subset is not completion when the plan names collision, lock, permission, path, encoding,
and length cases. Each named guard needs a fixture that reaches its refusing or boundary arm.
