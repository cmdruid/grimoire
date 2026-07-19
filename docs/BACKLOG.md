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
