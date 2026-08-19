# `promote` — drain Issues / Feedback onto Backlog

Judgment, not a mechanical copy. Curate stays hygiene; this verb is the drain. There is
**no write-only arm** — `debrief` does not invoke `promote`.

1. Resolve both homes (SKILL.md).
2. **Load candidates.** Open the live Issues and Feedback trackers **if they already
   exist** (title match among live `trackers/` records; `records.sh list --type trackers`
   when the tool exists). Do not find-or-create a tracker in order to walk it. Default:
   every live `- [ ]` line on both existing trackers. A human-named subset is allowed
   ("promote that feedback line"). If both trackers are absent, or every candidate is
   Leave → **no-op**: do not create empty trackers, do not stamp, do not commit.
3. **Judge each candidate** — not mechanical promotion:
   - **Promote** iff the line is now one cold-actionable thing to **build**. Find-or-create
     the Backlog tracker, append one newest-last line, stamp Backlog. The new line is one
     concrete sentence. If the source carried `→ <dir>/<file>.md`, copy that link onto the
     new line; otherwise the sentence names origin (`promoted from Issues: …` / `promoted
     from Feedback: …`). Rewrite the source line to the contract's **completed** form with
     today's date. No new dated record is minted.
   - **Drop** iff it is no longer a live concern (done elsewhere, wontfix, noise). Rewrite
     the source line to the completed form (same contract rewrite). Do not mint a task. The
     sentence keeps enough of the original to say what was dropped.
   - **Leave** iff it remains a valid issue or feedback that is not yet a task, **or** the
     line is a leftover remainder (`needs human:`, `file repro:`, `write down:`). Those
     prefixes are prose convention. No edit.
4. `scripts/record-mint.sh stamp` every tracker that was actually edited.
5. If anything was edited: one scoped commit on the tree the SKILL.md commit-tree
   probe selects (`scripts/scoped-commit.sh <root> "Backlog: promote" <paths…>`).
   Silent no-op otherwise.

A Backlog task is a tracker line, not a file, so there is no `→ trackers/…` link back from
the completed issue. Origin is the completed source line plus the copied record link or the
`promoted from …` clause. Do not invent a second link form.

Promote-drop always uses the journal completed form (`- [x] … — <today>`). Curate may still
strike or delete a line that no longer applies — that is hygiene, not this drain.

## Done when

- Existing Issues/Feedback walked (or no-op: nothing to walk / every candidate Leave);
  each candidate judged promote / drop / leave; edited trackers stamped; one scoped
  commit if anything was edited, otherwise no files created, stamped, or committed.
