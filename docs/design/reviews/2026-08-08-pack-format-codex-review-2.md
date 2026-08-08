# Independent implementer review -- pack-format spec draft 2 (convergence run)

**Reviewer:** Codex CLI (codex-cli 0.147.0), fresh context, spec file only. **Date:** 2026-08-08. **Disposition:** see 2026-08-08-pack-format-design.md; draft 3 responds to the contradictions + precision items; depth items recorded as implementation-owned.

Reviewed solely from [pack-format.md](pack-format.md (draft 2)), without relying on the referenced design record.

## 1. Ambiguities

**A1 — High — Pack discovery beneath a root skill.**  
“Pack enumeration … every discovered skill directory…” conflicts in interpretation with “If the repository root is itself a skill directory, it is the sole discovered skill — unless a full-depth scan is requested.” ([L30](pack-format.md (draft 2):30), [L288](pack-format.md (draft 2):288))

- Reading 1: pack enumeration uses ordinary discovery, so nested sibling packs are invisible.
- Reading 2: pack-aware tools implicitly request a full-depth scan.

Those implementations enumerate different packs.

**A2 — High — Collision predicate.**  
“No member name collides with an already-installed skill of different content from a different source.” ([L144](pack-format.md (draft 2):144))

- Reading 1: collision exists only when both content and source differ.
- Reading 2: any content mismatch is a collision; “different source” merely describes the usual case.

Same-source modified content and identical content from another source behave differently under the two readings.

**A3 — High — What a lock scope scopes.**  
“Every pack operation … targets exactly one scope,” while placement belongs to ecosystem locks. ([L82](pack-format.md (draft 2):82), [L118](pack-format.md (draft 2):118))

- Reading 1: scope selects only the `grimoire.lock`; skill files may be resolved across visible locations.
- Reading 2: scope selects both the lock and an isolated project/global skill installation set.

This changes collision, check, and removal behavior.

**A4 — Medium — Upgrade treatment of removed optional members.**  
Optional members are “default-installed, removable without trace,” while reinstall is a “transactional replace.” ([L49](pack-format.md (draft 2):49), [L161](pack-format.md (draft 2):161))

- Reading 1: every reinstall restores all default optional members.
- Reading 2: an upgrade preserves the user’s removed-optional selection.

**A5 — Medium — Authority for optional status.**  
Each lock member contains `"optional"`, but “the manifest, not the lock, is what identifies it as an optional member.” ([L97](pack-format.md (draft 2):97), [L116](pack-format.md (draft 2):116))

- Reading 1: the current installed manifest controls.
- Reading 2: the lock’s install-time classification controls.

A modified manifest can make removal unsafe under one reading.

**A6 — Medium — Unsupported manifest writes.**  
For an unknown `format`, a tool “MUST NOT install or write.” ([L65](pack-format.md (draft 2):65))

- Reading 1: it must not write that manifest.
- Reading 2: it must not perform any mutating pack operation, including remove or lock repair.

**A7 — Medium — Canonical source identity.**  
`source` is “the canonical origin” and may use multiple locator forms. ([L107](pack-format.md (draft 2):107))

- Reading 1: preserve the user-provided locator verbatim.
- Reading 2: normalize equivalent GitHub shorthand, HTTPS, SSH, redirects, and local paths.

This affects source-change warnings and collision detection.

**A8 — Low — Member-list whitespace.**  
Names are separated by “runs of spaces,” but the fields are arbitrary YAML string scalars. ([L54](pack-format.md (draft 2):54))

- Reading 1: only literal ASCII spaces are accepted.
- Reading 2: decoded YAML whitespace, including folded newlines or tabs, is accepted.

Leading and trailing spaces are also unspecified.

## 2. Contradictions

**C1 — High — Faceless root packs violate two identity rules.**  
A pack is defined as a skill directory, yet a faceless root pack has no `SKILL.md`, so it is not a skill directory. More seriously, “packs do not nest” forbids any descendant `SKILL.md`, while a faceless root pack can install only listed member skills located beneath that root. ([L21](pack-format.md (draft 2):21), [L25](pack-format.md (draft 2):25), [L32](pack-format.md (draft 2):32))

**C2 — High — Transactional rollback does not restore the prior state.**  
Install “never half-installs” and restores both lock families to their pre-transaction observable state, but replaced content “is not resurrected.” A failed replace can therefore destroy the pre-install skill while reporting rollback. ([L142](pack-format.md (draft 2):142), [L156](pack-format.md (draft 2):156))

**C3 — High — `check` requires an undeclared marker.**  
`check` must detect an absent setup marker, but the marker is pack-defined, has no manifest field, and tools must ignore the Markdown body. A conforming tool has no machine-readable way to locate or test it. ([L37](pack-format.md (draft 2):37), [L190](pack-format.md (draft 2):190), [L222](pack-format.md (draft 2):222))

**C4 — High — Remote faceless packs become immediately orphaned.**  
A faceless pack installs no pack-directory entry. `check` can consult its manifest only when `source` is locally resolvable. Therefore a valid pack-as-repo installed from `github:…` has a lock but no locally resolvable manifest and meets the definition of *orphaned*. This also contradicts “nothing above” requiring a remote source. ([L112](pack-format.md (draft 2):112), [L180](pack-format.md (draft 2):180), [L189](pack-format.md (draft 2):189))

**C5 — High — Pack version does not identify one content state.**  
“One release = one content state,” but adoption may lock arbitrary pre-existing bytes under that version, and re-pin may bless arbitrary later bytes without changing the version. A clean lock can therefore represent multiple content states for the same pack release. ([L131](pack-format.md (draft 2):131), [L147](pack-format.md (draft 2):147), [L135](pack-format.md (draft 2):135))

**C6 — Medium — `setup.ran` records an event the protocol does not define.**  
The lock says the tool “dispatched” setup, while lifecycle says tools merely present harness-facing text and command dispatch is outside the specification. There is no defined event at which `ran` becomes true. ([L124](pack-format.md (draft 2):124), [L197](pack-format.md (draft 2):197))

## 3. Gaps

**G1 — High — Discovery is not deterministic enough to implement.**  
Appendix B leaves the per-agent directory set as “…”; does not define the recursive bound, traversal order, symlink handling, or when full-depth scanning is requested; and combines this with first-seen-wins duplicate resolution. Two conforming tools can select different members. ([L286](pack-format.md (draft 2):286))

**G2 — High — Pack identity uniqueness is absent.**  
Nothing prohibits two enumerated manifests from declaring the same `pack:`. The lock has only one entry per pack name. Selection, validation, and install behavior are undefined.

**G3 — Medium — Faceless pack/member namespace collision is absent.**  
A faceless pack may apparently list a skill whose name equals `pack:`. The resulting lock member key looks like the face entry used by normal packs, but has different semantics.

**G4 — High — The lock example is not a complete schema.**  
Required versus optional fields, types, timestamp syntax, hash validation, duplicate JSON keys, absent `packs`, malformed JSON, unsupported lower versions, and invalid `setup` objects have no normative handling.

**G5 — High — Installed-member location is not recoverable.**  
The pack lock stores only names and hashes while explicitly omitting agent placement. The spec never says how `check` finds the right directory when a skill is copied or linked into several agent homes, or how removal chooses which copies to delete.

**G6 — High — Source acquisition is unspecified.**  
There is no procedure for resolving a source, selecting one pack from a multi-pack repository, checking out `ref`, determining the repository root, or deriving the expected release bytes before collision decisions.

**G7 — High — Adoption lacks compatibility and provenance rules.**  
The spec does not say whether adopting the face is legal, whether an adopted face must contain the same valid `PACK.md`, how its old ecosystem-lock provenance is retained, or what update source subsequently owns it.

**G8 — High — Upgrade reconciliation is undefined.**  
No rules cover members added, removed, renamed, or changing required/optional status; locally moved members; preserved optional selections; shared members; or failures after obsolete members have been deleted.

**G9 — Medium — Optional-member operations are incomplete.**  
Removal is defined, but opting out during initial install and reinstalling one optional member are not. Nor is the behavior when an optional member has a collision.

**G10 — High — Removal ownership is incomplete.**  
Reference counting sees only pack entries in one scope. It cannot preserve a skill also installed deliberately through a plain CLI, referenced by a pack in the other scope, or used by another project through shared global placement.

**G11 — High — `check` lacks cases needed for real recovery.**  
Undefined cases include malformed or version-mismatched installed manifests, manifest membership changed since installation, members present but absent from the lock, multiple on-disk copies, missing face plus missing manifest, and marker present with `setup.ran: false`.

**G12 — Medium — Re-pin with shared members is undefined.**  
It is unclear whether re-pin updates one pack entry, every same-scope pack expecting that member, or refuses when doing so would make another pack inconsistent.

**G13 — High — Transaction isolation and crash recovery are unspecified.**  
There is no file-locking, atomic-replacement, journal, or concurrent-operation rule. “Transactional” cannot be implemented interoperably when ordinary skill machinery and two lock families are mutated independently.

**G14 — High — The hash encoding has trivial structural collisions.**  
No delimiter or length separates path from content. A tree containing file `a` with bytes `bc` and a tree containing file `ab` with bytes `c` both feed `abc` into SHA-256. Invalid-UTF-8 filenames and Unicode normalization are also undefined. ([L275](pack-format.md (draft 2):275))

**G15 — Medium — Teardown guidance may disappear during removal.**  
The tool must point users at the face for manual teardown, but removal deletes that face. The required ordering or preservation of those instructions is not defined.

**G16 — Medium — Shared-member guard semantics are incomplete.**  
A member shipped in multiple packs may choose whichever marker it requires. Nothing requires it to accept every pack that declares it, so one pack can install a required member that always refuses to run.

## 4. Interop risks

**I1 — High — Whole-directory copying is not graceful degradation for pack function.**  
If a plain CLI filters `PACK.md`, the face may still “speak,” but pack-aware tools can no longer enumerate or check that installed pack. That is broken pack functionality, not merely reduced metadata. The spec acknowledges the premise but understates the consequence. ([L254](pack-format.md (draft 2):254))

**I2 — High — Installing the face does not install the system.**  
A plain CLI installs only the face directory. Its declared setup may name a required member command that was not installed. “Document its dependencies” gives a useful error message, but not a runnable degradation path.

**I3 — High — Root-skill discovery can hide every member.**  
A repository whose root is a face skill may be treated by plain tooling as containing only that skill. Pack members elsewhere in the repo then cannot be individually discovered without a non-default full-depth mode.

**I4 — High — Duplicate-name resolution may differ across tools.**  
“First-seen wins” relies on an unspecified traversal order, and plain CLIs are not bound to Appendix B. Pack-aware and pack-unaware installs may select different same-named skills.

**I5 — High — Pack removal can delete plain-CLI-owned content.**  
Pack refcounting cannot see independent ownership. Adoption makes this worse by expressly transferring ownership of pre-existing content to the pack without recording its prior owner.

**I6 — High — Project/global shadowing may not match agent loading.**  
The spec shadows locks by pack name, but an agent harness usually resolves actual skill names and search paths. A project lock can therefore describe one pack while the invoked member comes from the global installation, or vice versa.

**I7 — Medium — Guard clauses do not reliably protect solo installs.**  
They are prose-level author conduct, not a machine declaration. A stale marker left by plain-CLI removal permits execution against a partial pack; the spec acknowledges this, which materially limits the table’s “fails gracefully” claim.

**I8 — Medium — Symlink handling may produce permanent drift.**  
The normative hash skips symlinks entirely. A plain installer that dereferences, preserves, or replaces symlinks differently can install behaviorally equivalent content whose pack hash never agrees.

**I9 — Medium — Ecosystem-lock restoration is not portable.**  
The transactional guarantee assumes ordinary skill machinery can snapshot and restore every supported CLI’s locks and placements. Those APIs and schemas are outside this specification, so a generic conforming tool cannot guarantee it.

## 5. Verdict

**Needs rework. No, I could not implement an interoperable conforming tool from this document alone.**

I would be forced to guess:

- whether faceless root packs are exempt from the no-nesting rule;
- the deterministic discovery set and traversal order;
- how scope maps names to physical installed copies;
- the exact collision predicate and adoption provenance;
- upgrade and optional-member reconciliation;
- ownership-safe removal across plain installs and scopes;
- where a setup marker is and when `setup.ran` changes;
- how remote faceless manifests remain available;
- the normative lock schema and crash-recovery protocol.

A pack author would likewise have to invent marker conventions, multi-pack guard behavior, plain-CLI bootstrap instructions, and upgrade expectations. The high-severity findings permit data loss or divergent implementations, so they are format-v1 blockers.
