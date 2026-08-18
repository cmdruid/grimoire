---
doctype: design
status: open
created: 2026-08-18
updated: 2026-08-18
tags: [spec]
---

# `handbook` — extract the doctrine layer from `clankshop` — Draft

Brainstorm draft, `stream/feat` **feature 3**. Grounded against `1707ede` (post-`grok`
records-layer-init landing). Not yet argued into a spec — `grill` or `spec` resolves the
open questions at the foot.

> **Resequenced 2026-08-18 (human).** This was feature 2 until the `agent-doctrine`
> front-door variable was proposed; that variable now leads (see
> `2026-08-18-agent-doctrine-home.md`) because it rewrites the same six consumer skills
> this feature would otherwise rewrite twice. Two sections below are **superseded by that
> feature** and are kept only to record the reasoning: *The install stamp — split its two
> jobs* (the probe half is dissolved by home resolution, not converted).
>
> **Tier: `required:` (settled 2026-08-18, human — after a brief revision to `optional`).**
> Pack tier and framework dependency are distinct claims and both hold: installing the pack
> installs handbook and `/clankshop setup` hard-stops without it (a workshop cannot stand up
> doctrine-less), while the `agent-doctrine` rule still resolves with no handbook installed
> at all. `journal` is the exact precedent — `required:` in the manifest, yet `1707ede` made
> record-writers work without its floor. **This also answers this draft's deferred question:**
> `setup`'s Guard (a) extends to check handbook exactly as it checks journal.

## Problem

The doctrine layer has no owning authority. `.handbook/` is read by **six** skills
(`auditor`, `blueprint`, `contractor`, `debugger`, `workstream`, `clankshop`), but its
format, load rules, station model, and deployed loader (`context.sh`) are defined nowhere
citable — they are embedded in the pack face's `seed/`. The records layer got a format
authority (`journal`); the doctrine layer never did. That asymmetry has three visible
consequences.

1. **No lifecycle.** `clankshop/SKILL.md:23` and `verbs/setup.md:19` both promise that
   upgrades are "a judgment-assisted diff against the current seed, anchored by the README
   stamp line." **No verb performs it.** `journal` has `done` + `curate`; the doctrine
   layer has nothing — no drift detection, no stale-chapter pass, no upgrade path beyond
   the prose promise.

2. **The face carries layer mechanics.** `seed/` (16 files), `scripts/seed.sh`, and
   `seed/scripts/context.sh` sit in the pack face alongside genuine orchestration
   (`setup`, `migrate`, `check`, the door, the manifest). The face is the assembler; it
   should not also be the doctrine layer's implementation.

3. **Consumers probe a prose string to predict a tool.** All six grep
   `.handbook/README.md` for `Seeded from clankshop` in order to decide whether they can
   run `.handbook/scripts/context.sh <station>` or read a chapter file. That is
   indirection where a direct test would do — and the string is ID-bearing across ten
   sites.

## Goal

`handbook` becomes the **doctrine-layer format authority**, symmetric to `journal`'s
records-layer authority. `clankshop` narrows to the **assembler**: it composes the two
layers, writes the door, validates the assembly, and carries the manifest.

## Approach — full symmetry (settled 2026-08-18, human)

**Moves to `handbook`:** `seed/`, `scripts/seed.sh`, `seed/scripts/context.sh`, plus two
verbs — `setup` (the delegated doctrine seam) and `curate` (which finally *implements* the
promised seed-diff).

**Stays on the clankshop face:** `persona`, `check`, `migrate`, the `AGENTS.md` door,
`PACK.md`.

**Tier:** `required:`, alongside `journal` — a workshop without doctrine is not a workshop,
and `setup` should hard-stop without it exactly as it already does without `journal`.

**Name:** `handbook` — the word the library already uses in 40+ places. It collapses the
skill-name/artifact-name distinction that `journal`/`.records` and `notepad`/`notes` keep;
that cost was weighed and accepted against translating a settled term of art.

**The precedent is explicit and was reinforced this morning.** `setup.md` step 3 delegates
records standup to `/journal setup` and forbids inlining its walk; as of `1707ede` it
delegates the records **tool layer** specifically (`records.sh`, the ledger, the README —
not stores or templates). Extracting `handbook` is the same move for the other half.

### Why not the alternatives

- **Thin extraction** (assets move, no lifecycle verbs) — a file move dressed as an
  architecture change. The six consumers already cite `context.sh` fine today, so
  citability alone is thin payoff, and it leaves the seed-diff gap unowned. What makes
  `journal` worth being a skill is not that it holds `records.sh`; it is that the layer has
  a lifecycle.
- **Authority without extraction** (a doctrine-contract section in `clankshop/SKILL.md`,
  mirroring journal's record contract) — zero risk, zero stamp exposure, and it neither
  thins the face nor closes the lifecycle gap. Rejected, but preferred over thin extraction
  if the extraction were dropped entirely.

## The install stamp — split its two jobs (settled 2026-08-18, human)

`Seeded from clankshop vX.Y on DATE` does two unrelated jobs bolted into one line.

- **Job 1 — the boolean probe.** Delete it. Replace with an existence test of the deployed
  loader (`.handbook/scripts/context.sh`), symmetric with how the records layer is probed
  (*does `records.sh` exist* — `journal` has no stamp at all). This tests the thing that
  must actually work, cannot go stale through rewording, and stops the string being
  ID-bearing.
- **Job 2 — the version anchor.** Keep it, as pure provenance. It is what `curate` diffs
  against to distinguish a deliberate project accretion from an untaken seed change.
  Nothing branches on it.

**Grounding note (why this is now cheap).** `1707ede` added DOCTRINE.md rule 8 — *"Workshop
stamp is orthogonal … It does not pick the agent-records destination and does not decide
whether a record is minted."* The stamp's largest probe job was decoupled from records
behaviour before this feature started, so converting the probe **cannot regress record
minting**. What remains gated is exactly station/playbook context — precisely what the
loader test answers.

**Required fold:** DOCTRINE.md rule 8's wording names the stamp as "the one probe"; it must
change with the mechanism ("fix the doctrine, not just the tool", DOCTRINE.md:61).
`check.md` step 2 keeps asserting the stamp — as provenance, not as a probe.

## Persona (settled 2026-08-18, human)

`persona` stays on the clankshop face, untouched in the deployed case. Its **no-workshop
fallback is dropped**: `persona.md:14` currently falls back to clankshop's *bundled*
`seed/scripts/context.sh`, which after the extraction would be a reach into another skill's
bundle. `/clankshop <persona>` on an unseeded project instead reports that no workshop is
deployed and points at `setup`.

The cost is one degraded edge case, and `persona.md` already concedes what it is worth —
*"the voice is the generic seed persona — the project's own accrued judgments don't exist
yet."* The whole value of a station persona is accrued project judgment.

A **`personify` skill is queued as feature 3** (a general voice-adoption primitive carrying
its own bundled generic voices, of which the workshop's four stations are one source). If
built, it restores the fallback properly. Its go/no-go is a routing question — see open
question 7.

## Risks

- **Probe conversion touches six consumer skills.** Mechanical post-`1707ede`, but still
  six files. `grok` has landed, so the contention that existed this morning is gone.
- **Prove by breaking.** Whatever probe ships, break it deliberately and confirm a consumer
  notices. A verification grep is not evidence; no check is trusted until it FAILs on
  deliberately broken input.
- **Already-deployed handbooks** carry `Seeded from clankshop vX.Y` — the anchor `curate`
  needs is present in the field, so no migration is required for job 2.
- **`PACK.md`'s `version:` is ID-bearing.** A member-set change bumps it (2.4.0 → 2.5.0),
  and two streams have already claimed the same number with no textual conflict. Feature 3
  bumps it again.

## Open questions (for `grill` / `spec`)

1. **What exactly does `curate` do?** Candidate scope: seed-drift diff (anchored by the
   stamp version), unfilled `<gate>`/`<trunk>` slots, rotted intra-handbook links, stale
   chapters, broken load sets. Which of those are `curate` versus clankshop's `check`?
2. **Does `context.sh --check` grow to cover the whole doctrine layer** (stamp, slots,
   links), so clankshop's `check` delegates steps 1–4 the way step 5 already delegates to
   `records.sh check`? Or does `handbook` get a second deployed tool?
3. **Does `handbook` deploy a tool layer or the full chapters?** `journal` post-`1707ede`
   deploys only `records.sh` + ledger + README, no stores or templates. The doctrine seed
   *is* the chapters, so full projection is the likely answer — but it should be stated,
   not assumed.
4. **Who owns the resume/already-seeded classification?** `clankshop setup`'s Guard (c)
   currently decides absent / seeded-and-green / seeded-but-broken. After the split, does
   that stay on the face or move to `/handbook setup`?
5. **Does `migrate` delegate its doctrine-layer rows?** Settled direction is that the face
   keeps the single mapping table, but executing the doctrine rows may want handbook's
   mechanics.
6. **Does `install.sh` need any change?** It discovers skills by glob, so likely none —
   verify rather than assume.
7. **Routing.** `handbook`'s `description:` must route on its own without colliding with
   `clankshop`'s (DOCTRINE.md:77). Requires a routing probe per `docs/boundary-audit.md`.
   The same test is the go/no-go for feature 3's `personify`, whose natural description
   ("summon a persona, adopt a voice") over-fires on ordinary tone and roleplay requests.

## Grounding

Built against `1707ede`. Verified at draft time: no skill or directory named `handbook`
exists; `seed/`, `seed.sh`, and `persona.md` are untouched by the `grok` landing; ten live
`Seeded from clankshop` sites across six skills plus DOCTRINE.md; `PACK.md` at `2.4.0`.
