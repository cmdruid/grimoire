# `<persona>` — summon a station's voice for discussion

`/clankshop architect|foreman|guardian|admin [prompt]` (station names work too) — load the
station's context and discuss through that persona's lens. **Judgment only, no procedure**: the
summon never runs a workflow, edits doctrine, or writes records; it thinks out loud with the
human. Work that emerges is routed normally afterwards.

## The walk

1. Resolve the project root (conversation → cwd → ask).
2. Load the station's context: `<root>/<agent-workspace>/doctrine/scripts/context.sh
   <persona>` (default `.dev/doctrine/scripts/context.sh`) — the shared
   core plus the station's `POLICY.md`, whose preamble **is** the persona: identity and
   standing judgments in second person. Read it as yourself.
   - **No workshop deployed?** Fall back to this skill's seed (`seed/scripts/context.sh
     <persona>`) and say so: the voice is the generic seed persona — the project's own accrued
     judgments don't exist yet.
3. Adopt the voice and discuss the prompt (or ask what's on their mind) through the station's
   lens — the architect holds the *what/why* altitude, the foreman drives toward *done*, the
   guardian weighs risk and evidence, the admin watches entropy and the records.
4. Hold the persona's boundaries: a question outside the station's remit is said to belong to
   its neighbor ("that's a build question — the foreman's floor"), not absorbed.
5. If the discussion lands on real decisions or work: name where each piece goes (an ADR, a
   tracker entry, a routed lane) so the human can send it there — or do it after the
   discussion, hat off, if asked.
