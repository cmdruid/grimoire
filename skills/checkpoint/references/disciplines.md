# The four save-state disciplines

This is the generic normative home of Save, Resume, Lifecycle, Recovery, the authority order, and
two techniques. Another save-state owner may borrow a discipline by name while supplying its own
file, structure, custody, admission, and anchor rules. A borrowing site carries a one-line local
gloss so it remains usable without this package. The discipline names and three numbered checkpoint
moments are stable API.

## Save discipline

Scan and elide secrets; synthesize rather than transcribe; resolve relative dates to absolute. In a
Git repository, reconcile shipped claims against `git log`. Author one load-executable next action:
prefer intent named this turn, otherwise a KNOWN continuation, otherwise the safest useful
best-guess. Disk vetoes an action that claims landed work remains undone.

Named intent is a concrete next step in the invocation or same-turn message, not politeness or
chatter. KNOWN means one clear continuation: the in-flight unit, the sole pending item, an already
determined queue step, or unsuperseded standing direction.

## Resume discipline

Read the save-state in full, load it as context, echo its single next action, and rewrite nothing.
Report stale or already-landed work. A refresh happens only through a later Save. Any ownership or
custody claim is owner-specific; the owner decides whether explicit Resume invocation itself
authorizes that claim. This read-only primitive mandates no separate confirmation.

## Lifecycle discipline

The owner defines its explicit enrollment or creation event. The discipline creates no owner state
before that event. Afterward, refresh at checkpoint moments: (1) before a deliberate reset, (2) at
a human-visible work-unit completion, and (3) on a context-pressure warning, when the agent also
recommends a reset. A work-unit is an expensive-to-reconstruct milestone, not a file edit, review
pass, or status reply.

Resume never consumes the file. Landed work is a durable fact, not a completion heuristic; the
save-state remains active until its explicit close procedure runs. A polluted context resets without
saving, deliberately rolling back to the last trusted state.

## Recovery discipline

Recovery handles involuntary compaction and fires only when still-loaded context points to the
owner's save-state. The owner supplies its own discovery and admission rules.

1. **Stop.** Do not continue the task from the summary alone.
2. **Read the save-state in full.** If the owner permits a no-file fallback, reorient from the
   summary and bounded facts, then Save immediately; an owner may disable this fallback.
3. **Gather facts once, then stop.** Inspect the durable repo/state baseline and existence of paths
   cited as in flight, not general orientation material. Do not open a search.
4. **Reconcile.** Durable state wins for landed work; the file wins for last-saved intent; the
   summary contributes only later in-flight work that does not contradict durable state. Ask only
   if two live intents remain plausible. Report landed work neutrally without inferring or
   suggesting closure.
5. **Working set.** Use the file's TL;DR, reconciled pending work, and suggested first action.
6. **Reply.** Report the save-state path and next action, then work. Honor a still-visible context-
   pressure warning.
7. **Continue without a round trip** when the next action is KNOWN. A fresh session instead uses
   Resume under the owner's claim rule. A failed compaction is a hard session boundary: Save if
   possible, reset, then Resume.

Recovery itself never writes the save-state. Reconciled changes persist only at the owner's next
ordinary Lifecycle refresh; summary-only deltas and an untrusted merge never become trusted state.

**Done when (Recovery):** the compacted session is reconciled and continuing, or the owner's
explicit no-file fallback completed.

## Authority order

Committed or external systems of record > current files on disk > save-state > compaction summary.
The save-state and summary carry intent, never authority over landed facts.

## Two techniques

- **Anchor-line repetition:** carry the save-state's absolute path in its first heading or an
  equally early unique line so a compaction summary can retain it. Speak the path only at Save,
  Resume, Recovery, or when asked.
- **Context-pressure cue:** treat a harness context-low warning as Lifecycle moment (3): Save now
  and recommend a reset.
