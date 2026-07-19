# Grimoire maintainer backlog

The "simple version" backlog for **this repo's own** loose ends — maintainer follow-ups on the skill
library itself (lint gaps, doctrine debt, deferred audit items). This is grimoire-as-a-project, distinct
from the `.records/` trackers a *consuming* project gets; grimoire authors those skills, it does not run
them on itself. Phase 7's `skill-builder` steward may eventually own this list; until then it is a flat
maintainer file.

**Format.** One entry per loose end, newest concerns first. Each: an `id`, a one-line title, a `source`
(where it came from), a `status`, and a short body. Close an entry by setting `status: done` with a
one-line resolution; delete only when the reason it existed is gone.

---

## Open

### BL-4 — check-8 single-use WARN misfires on intra-skill produce↔consume pairs
- **source:** Phase 3 disposition audit (2026-07-19); `docs/design/2026-07-19-phase3-skill-dispositions.md` §5.
- **status:** open
- **body:** `scripts/skills-lint.sh` **check 8** WARNs on a type used by exactly one skill (orphan/typo
  signal). But a legitimate **intra-skill chain** — `handoff` `produces: handoff-doc` **and** `consumes:
  handoff-doc` (save→resume), `feature` `design→plan→build` — is a *single skill* on both ends and will
  trip the single-use WARN even though it is correctly paired. This is distinct from the *rollout*
  orphan-WARNs (a type with no consumer yet), which resolve once Phase 5 wires consumers; the intra-skill
  WARN never resolves. **Follow-up (Phase 5):** refine check 8 to count producer-vs-consumer *skills*
  separately, so a same-skill produce↔consume pair does not read as single-use (it also cleanly covers
  feature's internal chain). Keep the genuine cross-skill orphan WARN. Alternative: accept the WARN as a
  documented known case. Recommend the refinement.

### BL-3 — block-splicing helpers must avoid multi-line `awk -v` (BSD/macOS portability)
- **source:** Phase 1 pilot A4 (2026-07-18); `docs/design/2026-07-18-phase1-pilot-acceptance.md`;
  commit `4b32a2b`.
- **status:** open
- **body:** `skills/backlog/scripts/register-route.sh` splices a skill's route block into a front-door
  doc. The first cut passed the multi-line block via `awk -v blk=…`; **BSD/macOS awk rejects a newline
  in a `-v` value** (`awk: newline in string`) and the script aborted before writing (fail-safe, but
  the write silently didn't happen). Fixed by passing the block through the environment
  (`ENVIRON["BLK"]`). **Follow-up (not a fix — a constraint to carry):** Phase 5 rolls this registration
  mechanism out to the remaining 8 skills, and Phase 4's composer will *rebuild* the projection
  wholesale — any new block-splicing/registration helper must use `ENVIRON[]` (or a temp file), never
  multi-line `-v`. Candidate for a `bash -n`-adjacent lint note or a shared helper both skills call, so
  the constraint isn't re-learned per skill. `register-route.sh` + `scaffold-records.sh` are the reusable
  reference implementations.

### BL-1 — check-7 (skills-lint) has no body-level backstop for re-documentation
- **source:** boundary body audit (2026-07-18); `docs/boundary-audit.md` §"Known limitation";
  `FEEDBACK.md` [foreman] entry; commit `4688039`.
- **status:** open
- **body:** `scripts/skills-lint.sh` **check 7** WARNs only on *description*-level backticked `/name`
  refs to a sibling. **Body-level re-documentation** (rubric V1 — a body section restating a sibling's
  verb roster / protocol / seam, the *bigger* class) has **no mechanical backstop**; it is caught only by
  the manual boundary-audit scan (step 2), and it *silently rots* (the `foreman` roster listed
  `architect`'s verbs as `init/brainstorm/plan/prep/distill/check` long after `architect` gained
  `extract`/`reconcile`). **Follow-up:** evaluate a `check 8` that flags a body section which enumerates
  another skill's verb set (e.g. a run of backticked `/sibling <verb>` tokens, or a "Companion
  skills / Scope boundary" heading). Keep it a **WARN, not FAIL** — some cross-mention is legitimate;
  the maintainer judges against the rubric. Natural home: Phase 2's lint work, or Phase 7's
  `skill-builder audit`.
- **Phase 2 evaluation (2026-07-19):** *deferred, not folded in.* Phase 2 added `skills-lint.sh`
  **check 8** (typed-edge blocks), but a body-roster backstop does **not** fit that pass — check 8
  parses the *delimited, bounded* `<!-- edges:<name> -->` block, whereas BL-1 must scan *all body
  prose* for runs of `/sibling <verb>` attributions, a different pass with real false-positive risk
  (routers legitimately name sibling verbs) that needs the boundary-audit rubric to tune. Rushing it
  under the milestone would ship a noisy check that erodes gate trust. Reaffirmed home: **Phase 7's
  `skill-builder audit`** (or a dedicated pass), not check 8.

### BL-2 — the body-roster sweep was targeted, not exhaustive
- **source:** boundary body audit (2026-07-18); commits `0380885`, `689309f`, `da76945`.
- **status:** open
- **body:** the body audit fixed the roster-rot pattern where it was *found* — `foreman`, `backlog`,
  and `workstream`'s templates — but did not confirm an **exhaustive** scan of all 10 skills' bodies for
  the same pattern (a body restating a sibling's verbs/protocol that can rot when the sibling changes).
  With no mechanical backstop (BL-1), an unswept body could carry a stale roster today. **Follow-up:** a
  one-pass sweep of every `skills/*/SKILL.md` + `verbs/*` body against boundary-audit rubric V1,
  recording per-skill "clean / fixed" — folded naturally into **Phase 3** (evaluate all skills) or run
  standalone. Closing BL-1 (a lint) would make future recurrences cheap to catch and largely retire
  this manual sweep.
- **Phase 3 note (2026-07-19):** *still open — Phase 3 was a different lens.* The Phase 3 disposition
  audit (`docs/design/2026-07-19-phase3-skill-dispositions.md`) read all 10 `SKILL.md` bodies, but
  scored them for **self-init / typed edges / registration**, not for rubric-V1 **sibling-verb-roster
  rot**. The exhaustive roster sweep was **not** performed here; it remains a distinct pass (best done
  once BL-1's lint exists to ground it).

---

## Done

_(none yet)_

---

> **Provenance note (2026-07-18).** The roadmap seeds this file with *"`#4`/`#5` from the body audit."*
> That numbering lived in the body-audit *session's* working notes and was never committed as an
> artifact, so **BL-1/BL-2 are reconstructed** from the committed record — `FEEDBACK.md`,
> `docs/boundary-audit.md`'s "Known limitation", and the body-thinning commits — which together capture
> the substantive deferred items (the check-7 body gap and the non-exhaustive sweep). If the original
> `#4`/`#5` were something else, amend here.
