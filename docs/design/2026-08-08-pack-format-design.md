# Pack format (sub-project ①) — design record

**Status:** approved in brainstorm (2026-08-08); the normative output is
`docs/spec/pack-format.md` (format 1). Parent: `docs/design/2026-08-07-grimoire-repurpose-design.md`
(umbrella — pack-as-skill, overlay hard requirement, setup-only lifecycle were decided there).

## Decisions (this cycle)

1. **Free redesign; clankshop migrates.** The spec is designed first-principles for the
   ecosystem. Where it diverges from the clankshop plan's ratified Appendix I machinery, the
   plan amends and re-ratifies — not the other way around.
2. **Semver packs, hash-pinned members.** The wild ecosystem is unversioned and hash-pinned;
   the spec follows. Pack releases carry semver; members pin by content hash in the lock.
   Member `version:` keys and `name>=N` ranges are **dead** — including clankshop Task 3.3's
   planned `version:`-in-SKILL.md keys (also rejected on principle: `SKILL.md` frontmatter is a
   foreign format's surface — same argument as the locks).
3. **Sidecar lock (`grimoire.lock`, project + global twin).** The "extend the Vercel locks"
   option was eliminated by verified mechanics: both qntx's and the TS reference's lock schemas
   are closed — unknown keys are dropped on every read→write cycle, so an embedded `packs`
   section would be silently deleted by the first foreign `skills add`. Lock overlays lock,
   mirroring pack-overlays-skills.
4. **Partition collapse: `skills:` + `optional:`.** Hash pinning dissolved the mechanical
   reason `helpers:` existed (separate versioning for shared members); repo-local member refs
   dissolve shared-helper drift (all members move in lockstep on pull). What survives from the
   old core/helpers/optional partition is the only distinction tools can act on:
   required vs. default-installed-but-removable-without-trace. Core-vs-helpers becomes runbook
   prose.
5. **Lifecycle is pack-scoped; `setup:` only, rest reserved.** No per-skill setup exists at
   the spec level; the pack's entrypoint orchestrates member wiring. Tools offer, never
   auto-run. *(Superseded in draft 4 — see Owner review below: format 1 declares no lifecycle
   keys at all; setup lives in the face.)*
6. **No bare-usefulness requirement for members.** Deliberately rejected: forcing pack-based
   skills to work standalone reintroduces the generic seams and boilerplate the clankshop
   redesign removed (members are framework-committed by design). The overlay guarantee is
   mechanical (discover/install), not semantic (useful solo). The pack is the unit of
   usefulness.
7. **Pack-based skill conduct requirements (spec §7):** guard clause (tripwire) MUST — fail
   gracefully when the pack system is absent, gating on the pack-defined setup-stamped marker,
   never on the lock; lock-**aware** SHOULD (read `grimoire.lock` for pack facts, tolerate
   absence, never write); no install-time self-setup MUST; face skill carries no tripwire (its
   welcome case is "not installed yet").
8. **Check reports facts, not verdicts** (generalized from Appendix I): missing-required =
   broken, hash-moved = re-pin offer, missing-optional = green, locked-without-source =
   orphaned.

## Consequences for clankshop (owned by ①'s plan)

- Absorb `packs/clankshop.md` into `skills/clankshop/PACK.md` (pack-as-skill; the skill dir
  does not move); retire the `packs/` shelf; `install.sh --pack` reads the new location and
  writes the sidecar lock.
- Frontmatter migrates: `name:` stays `name:`, `pack-version: 1`→`version: 1.0.0`, `layout:`
  dropped (`format:` is optional; absent = format 1), `core:`+`helpers:` fold into `required:`
  (minus `clankshop` itself — the face is
  implicit, spec §2), `optional:` stays (both lists comma-separated). No `setup:` key exists —
  setup lives in the face (spec §6), which clankshop's face already does.
- Task 3.3 (bare→ranged helpers + SKILL.md `version:` keys) is **cancelled by this design**;
  the Appendix I pinning-semantics paragraph re-ratifies against spec §4/§5. The lint gate's
  `core:`-as-exemption-rule input (plan Task 4.1) needs a replacement source — flagged for the
  clankshop stream, decided there.
- Members already carry the guard discipline ("read-only on an unstamped root"); §7 makes it a
  named requirement. The face (`skills/clankshop/SKILL.md`) must shed any tripwire behavior it
  has and own the welcome case.

## Follow-on work recorded

- **pack-builder skill** (requested 2026-08-08): the toolmaker at pack altitude, sibling of
  `skill-builder` — scaffold `PACK.md` + faces, scaffold pack-based skills with the §7 guard
  preamble, validate a repo against `docs/spec/pack-format.md`, related authoring verbs. Builds
  after the spec lands; natural first consumer of `grimoire-pack`'s validator (or its shell
  precursor).
- Upstream courtesy issue to qntx: `@filter`-after-URL-subpath parsing quirk (unrelated to
  packs; noted during backend evaluation).

## Independent review (2026-08-08)

Draft 1 was reviewed by a fresh-context Codex agent cast as a third-party implementer (spec
file only; verbatim findings: `docs/design/reviews/2026-08-08-pack-format-codex-review.md`).
Verdict on draft 1: not implementable standalone — 37 findings. Dispositions in draft 2:

- **Fixed:** all four contradictions (faceless packs now root-only; lock example carries the
  pack's own entry; guard pointer falls back to the face when `setup:` absent; guard vs.
  self-healing boundary stated) and all nine ambiguities (re-pin defined as accept-disk-bytes;
  scope targeting + per-pack shadowing; adopt/replace defined non-silent; `setup.ran` =
  best-effort dispatch record reconciled by check; optional removal drops the lock entry;
  orphaned = manifest no longer locally resolvable; face = pack-dir entry, one artifact).
  Gap closures: normative hash algorithm (Appendix A, byte-verified against the reference
  implementations), normative discovery summary (Appendix B), manifest grammar, unsupported
  format/lock-version behavior, source canonicalization + `ref`, reinstall/upgrade, shared
  members, check's input model + fact table, content-vs-placement split with ecosystem locks.
- **Acknowledged as stated limits (§8), not solved in format 1:** plain-CLI mutations
  producing partial systems; stale markers after removals (no teardown key yet); flat skill
  namespace. The guard is spec'd as a bootstrap gate; `check` is the integrity instrument.
  Post-review limits discussion (2026-08-08) ranked stale-marker-after-removal the one live
  risk (fires on every removal of a set-up pack; undetectable post-hoc since markers are
  pack-defined) → §5 gained a MUST: removal of a `setup:`-declaring pack surfaces persisting
  setup artifacts and points at the face for manual teardown. Mutation drift is neutralized
  ergonomically instead — carried to ③'s design: the TUI runs `check` ambiently (launch/project
  open). Flat namespace: inherited ecosystem property, accepted.
- **Left to implementations:** deep transaction mechanics (journaling, crash recovery,
  concurrency) — spec requires stage-then-commit + never-silently-plausible outcomes;
  `grimoire-pack` decides the how.

**Convergence run (draft 2 → draft 3, same brief, fresh context; verbatim:
`reviews/2026-08-08-pack-format-codex-review-2.md`).** Verdict still "needs rework" (~39
findings) — but the finding *character* shifted from foundational to precision/depth. Five
genuine contradictions draft 2 had introduced were fixed in draft 3: faceless-root packs are
now an explicit manifest-only shape (no skill-dir/no-nesting conflict); replace stages content
so rollback truly restores it (the data-loss permit is gone); check's unimplementable
marker-drift row became *setup pending* (`setup.ran` false), with system-level validation
explicitly the pack's own business; faceless installs cache the manifest into the lock (no
born-orphaned remote packs); §4 now states hashes are authoritative over version for installed
content (adopt/re-pin honesty). Precision fixes: collision predicate = hash inequality
(source-irrelevant), source normalization (`github:<owner>/<repo>`), upgrades preserve
optional selections, lock `optional` flag authoritative at install time, `setup.ran` =
user-attested, removal warning ordered before deletion + relays face teardown guidance, adopt
never applies to the face, re-pin touches only the target pack's entry, pack enumeration
declared full-depth, duplicate `pack:` names invalid, whitespace grammar post-YAML-decode,
unknown-format inaction scoped (removal stays lock-governed), Appendix A documents the
inherited non-collision-resistance + symlink caveats, Appendix B defers to reference
implementations where the summary diverges. **Review loop closed by decision:** a maximal-rigor
reviewer keeps producing ~40 findings per pass at increasing depth (npm-grade schema/protocol
detail); remaining highs are implementation-owned (acquisition procedure, crash protocol, lock
JSON-schema, check's exhaustive case list) or accepted §8 limits (cross-ownership visibility,
placement-vs-lock shadowing). `grimoire-pack`'s implementation + conformance fixtures are the
next truth-finder; prose iterates only when implementation contradicts it.

## Owner review (2026-08-08, draft 3 → draft 4)

The spec owner's read of draft 3 produced five directives, all applied in draft 4:

1. **Appendix B slimmed:** `skills/.curated`, `skills/.experimental`, `skills/.system` dropped
   from the priority-directory list (the reference-implementations-govern clause absorbs any
   divergence; the summary keeps only the paths that matter here).
2. **`pack:` → `name:`** as the manifest identity key — parallel to `SKILL.md` frontmatter.
3. **Member lists are comma-separated** (trimmed tokens), not whitespace-split.
4. **`setup:` deleted; `skills:` → `required:`.** Format 1 now declares **no lifecycle keys**:
   setup is the face `SKILL.md`'s job — pack-scoped, atomic (complete system or clean refusal),
   delivered by every install path including plain-CLI. This supersedes the umbrella's
   "setup-only lifecycle" decision and decision 5 above. Tools point at the face after install
   instead of offering an entrypoint; the removal warning (9ce24cf) survives but is now
   unconditional, since setup is no longer machine-declared.
5. **Lock `setup` object deleted; member `optional` flag flipped to `required`.** With it go
   `setup.ran` (user-attested tracking) and check's *setup pending* fact — draft 3's
   convergence fix on that row is moot, the tracked state no longer exists. Lock state is
   explicitly one bit per pack: entry present = fully installed (transaction-guaranteed), no
   entry = not installed; no pending sub-states. System-setup state stays where §7 always put
   the real gate: the pack-defined marker.

A second owner pass the same day (draft 5) added two more:

6. **Lock `members` → `skills`** as the JSON key (prose keeps "member" as the concept term).
7. **`format:` demoted to optional-with-default:** absent means format 1, and format-1
   manifests SHOULD omit it. The *mechanism* survives without the mandatory key — the
   refuse-on-unimplemented-value rule stays, so a future breaking revision declares `format: 2`
   and format-1 tools refuse to act instead of misparsing. Dropping the rule entirely was
   rejected: without it, old tools would ignore an unknown `format:` key and misread a
   breaking-revision manifest.

**Implementation (2026-08-08):** shell surfaces conformed to draft 5 and the `grimoire-pack`
crate built per `docs/design/2026-08-08-pack-format-impl-plan.md` (with review-ratified
deviations recorded there: per-manifest `Enumeration{packs, issues}`, symlink-safe walks,
strict unsupported-format stance, schema-level lock failures read-only). The crate's
`tests/fixtures/` conformance trees are the format's executable examples and the spec's next
truth-finder; `tests/clankshop.rs` pins the live flagship pack against the library.

## Open questions deliberately deferred (format 2 candidates)

- Cross-repo member references.
- Additional lifecycle keys (**teardown** — promoted to first candidate by review findings
  I4/I5, stale-marker states; check, …) — reserved, unspecified.
- Registry/distribution semantics beyond git repos (skills.sh has no pack concept yet).
