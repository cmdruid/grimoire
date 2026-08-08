# Independent implementer review — pack-format spec draft 1

**Reviewer:** Codex CLI (codex-cli 0.147.0), fresh context, spec file only — no design discussion access. **Date:** 2026-08-08. **Disposition:** see 2026-08-08-pack-format-design.md §Independent review; draft 2 of the spec responds.


High/medium findings are v1 blockers; low findings are clarifications.

## 1. Ambiguities

**A1 — High. Root pack contents.** “A `PACK.md` at a repository root makes the whole repository one pack” and “The pack directory itself … is recorded as a member entry” ([lines 23, 86](pack-format.md (draft 1):23)). Reading A: hash/install the literal repository, including nested member directories. Reading B: create a logical pack member containing only face, manifest, and support files. These produce different hashes and layouts.

**A2 — High. Optional “no trace.”** “Removing individual optional members leaves no trace” ([line 117](pack-format.md (draft 1):117)). Reading A: remove the skill and ecosystem-lock entry but retain its pack-lock record. Reading B: remove its pack-lock record too. Under B, `check` cannot identify a missing optional member without reopening a manifest.

**A3 — High. Collision policy.** Preflight prohibits collisions, but “collision handling MAY be interactive — adopt/replace” ([line 106](pack-format.md (draft 1):106)). Reading A: every collision initially fails; adopt/replace is an extension. Reading B: an acknowledged collision passes preflight. “Adopt” could mean accepting arbitrary installed bytes or only a hash-identical member.

**A4 — High. Re-pin meaning.** A mismatch is “moved since install” and tools “offer re-pin” ([lines 99–100, 120–122](pack-format.md (draft 1):99)). Reading A: accept current local bytes and update the hash. Reading B: recover the declared release and pin its bytes. Only B preserves the stated version/content relationship.

**A5 — High. Lock precedence.** Skills read “project scope, then global” ([lines 149–151](pack-format.md (draft 1):149)). Reading A: an existing project lock shadows the global lock completely. Reading B: look up the requested pack in the project lock, then fall through to global. It is also unclear whether removal reference-counts one scope or both.

**A6 — Medium. “Corresponding manifest source.”** `check` calls a lock entry without one “orphaned” ([line 122](pack-format.md (draft 1):122)). This could mean no installed `PACK.md`, no reachable upstream repository, or no manifest at the stored source revision. Offline behavior differs under each reading.

**A7 — Medium. Face versus pack-directory member.** The face is “implicitly a member,” while the pack directory is recorded under the pack name ([lines 49–50, 86–87](pack-format.md (draft 1):49)). Reading A: these are the same member. Reading B: they are distinct conceptual members, although the JSON map cannot represent both under one name.

**A8 — Medium. `setup.ran`.** It records whether the tool “observed setup being run” ([line 90](pack-format.md (draft 1):90)). “Ran” could mean launched, returned successfully, or produced the pack marker.

**A9 — Low. Preservation.** Unknown keys must be “preserved,” while the Markdown body is ignored ([lines 31–32, 51–52, 89](pack-format.md (draft 1):31)). It is unclear whether semantic preservation after reserialization suffices or unknown YAML/body content must remain byte-for-byte intact.

## 2. Contradictions

**C1 — High. Non-root faceless packs are legal but undiscoverable.** A siblingless `PACK.md` is legal ([line 21](pack-format.md (draft 1):21)), but enumeration finds only discovered skill directories plus a root `PACK.md` ([lines 26–27](pack-format.md (draft 1):26)). A non-root directory without `SKILL.md` is not a discovered skill directory.

**C2 — Medium. Lock example violates the subsequent rule.** The example’s `clankshop` pack has only `architect` and `task` members ([lines 68–80](pack-format.md (draft 1):68)); the next clause requires a member entry named `clankshop` ([lines 86–87](pack-format.md (draft 1):86)).

**C3 — High. Setup is optional, but pack-based skills require it.** `setup:` is optional ([line 42](pack-format.md (draft 1):42)), yet every pack-based skill must point at “the declared setup entrypoint” and check an artifact that setup creates ([lines 141–147](pack-format.md (draft 1):141)). A pack-based member in a setup-less pack cannot comply.

**C4 — Medium. Mandatory failure conflicts with self-healing.** On marker absence, a skill MUST fail without partial execution ([lines 141–144](pack-format.md (draft 1):141)); use-time lazy self-healing is then declared legitimate ([lines 152–153](pack-format.md (draft 1):152)). The permitted boundary is not stated.

## 3. Gaps

**G1 — High. Unsupported formats.** No required behavior exists for `format: 2`, a missing/typed-wrong format, or a lock `"version"` newer than the tool understands.

**G2 — High. Manifest grammar.** The spec does not define duplicate YAML keys, accepted semver grammar, whitespace/tokenization of member scalars, duplicate names, empty `skills:`, or whether YAML sequences are invalid.

**G3 — High. Hash interoperability.** “SHA-256 over sorted relative paths + contents” lacks byte framing, encoding, path normalization, symlink, executable-bit, ignored-file, and directory handling. Two conforming implementations can compute different hashes.

**G4 — High. Discovery resolution.** “Ecosystem discovery rules” is not pinned to a normative version. The spec does not resolve duplicate skill names, `name:` versus directory name, nested packs, symlinks, or repository-boundary detection.

**G5 — High. Faceless/root installation.** For a root faceless pack, no destination path or ordinary skill atom exists for the required pack-directory member. It is unspecified whether installing it copies the entire repository or synthesizes an artifact.

**G6 — High. Reproducible source identity.** `source` has no defined canonical form and the lock stores no URL, commit/tag, subdirectory, or manifest hash. Version plus member hashes is insufficient to fetch the recorded release.

**G7 — High. Pack identity conflicts and updates.** There are no semantics for reinstall, no-op install, upgrade, downgrade, source change, same-name pack from another repository, or pack rename.

**G8 — High. Adopt/replace.** The spec does not say which bytes are hashed after adoption, whether provenance changes, whether replacement may overwrite local edits, or how replaced content and ecosystem-lock state are restored on rollback.

**G9 — High. Transactions.** “Full rollback” lacks atomic-write, crash-recovery, locking, journaling, and concurrent-installer requirements. Pre-existing files and locks that must survive rollback are not identified.

**G10 — High. Shared ownership/removal.** Reference counting ignores independent non-pack installs, local modifications, and cross-scope references. A tool cannot know whether removing the last pack reference authorizes deleting the skill.

**G11 — High. Shared-member compatibility.** Two installed packs may lock different hashes for the same member. The spec neither rejects that state nor defines which pack wins. Optional in one pack and required in another is also unresolved.

**G12 — Medium. Individual member operations.** Behavior is absent for removing a required member, reinstalling a removed optional member, or removing an optional member that another pack references.

**G13 — High. `check` algorithm.** It does not specify where installed members or manifests are located, whether the current manifest is compared with the locked snapshot, how version drift is reported, or what happens when the source is temporarily unavailable.

**G14 — High. Scope and target model.** “Project” root resolution is undefined. A lock entry also records no agent/install target, despite skill tooling potentially installing the same name into multiple target locations.

**G15 — Medium. Lifecycle state.** There is no protocol for executing/observing setup, recording failure, retrying setup, or reconciling `setup.ran` with a missing marker.

**G16 — Medium. Pack-based membership.** Nothing declares which members are “pack-based,” so tools cannot validate their MUST clauses. A member may also appear in multiple packs, while §7 speaks of singular “its pack,” marker, and setup.

## 4. Interop risks

**I1 — High. Face-only install can dead-end.** A plain CLI installs only the face, while the example setup command (`/foreman setup`) may belong to an uninstalled sibling member. The face can explain setup but cannot invoke it.

**I2 — High. Payload/discovery assumptions are outside the format.** Graceful degradation assumes every compatible CLI discovers root/nested faces and copies arbitrary files such as `PACK.md`. The spec provides no compatibility requirement or fallback if it copies only recognized skill files.

**I3 — High. Plain updates create unsafe mixed releases.** A plain CLI may update one member independently. The marker can remain valid, and lock reading is only SHOULD, so another member may execute against a composition that no longer matches any pack release.

**I4 — High. Plain removal bypasses the tripwire.** Removing a required member does not remove the setup marker. Remaining members can pass the marker check and execute against a partial system.

**I5 — High. Pack removal leaves stale setup state.** Format 1 has no teardown. Removing a pack can leave its marker behind, causing later solo-installed members to believe the system is present.

**I6 — High. Flat names lose source/version identity.** Plain tools treat skills as atoms keyed by name. Two packs or sources sharing a member name can overwrite each other, while the guard checks only a pack-defined marker.

**I7 — Medium. Slash-command lifecycle is not portable.** An “agent command string” such as `/foreman setup` assumes command-dispatch behavior not defined by the SKILL.md ecosystem or this specification.

**I8 — Medium. Sidecar survival is not semantic compatibility.** A plain tool may leave `grimoire.lock` syntactically untouched while changing or deleting every installed member. “Unaffected” therefore means only “not rewritten,” not “still authoritative.”

## 5. Verdict

No: I could not build a reliably conforming, interoperable tool from this document alone.

I would have to invent:

- Pack/root discovery and the exact bytes installed.
- Manifest and lock schemas, hashing, and source canonicalization.
- Scope precedence and target selection.
- Collision, adoption, replacement, rollback, and crash recovery.
- Ownership and removal rules for shared or independently installed members.
- Upgrade/re-pin behavior and shared-member compatibility.
- Setup observation, marker lifecycle, and pack-based membership rules.

Those guesses affect lock compatibility and destructive behavior, not merely UX. No files were changed.
