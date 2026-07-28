# `/architect calibrate` — drain design-flavored signal into the seed

Fold captured dev-experience signal *about the seed* — a spec that repeatedly misleads builds, a
contract complaint, a "this tenet fights reality" observation — into targeted seed edits. The
signal source is the host's trackers (the dev-experience/issues stores the front door names),
consumed as entries by content; the slice that belongs here is the one whose fix would edit
**the seed** (a spec, a contract, PHILOSOPHY) rather than code or process doctrine.

**`calibrate` ≠ `distill`, kept sharp:** `distill` compacts the seed's *own accretion* (ADRs/plans
already in the record stores) into clean present-tense specs; `calibrate` absorbs *external
signal* (tracker entries about dev experience with the seed). One compresses inward, the other
absorbs inward. The editing discipline is shared: hand-edit, never bulk; the seed stays
regenerable; the durability gradient (`docs/DOCTRINE.md`) governs what may change.

## The pass

1. **Harvest the design slice.** Read the host's dev-experience/issues trackers (locations per
   the host's front door / ownership index) for entries whose fix would edit the seed. One
   complaint is a note; a pattern (the same spec misleading twice) is a calibration.
2. **Confirm against the seed.** Read the indicted spec/tenet. The entry may be stale (the seed
   already fixed), may indict the *code* (that is drift — `reconcile`'s finding, not a seed
   edit), or may indict process doctrine (not this skill's layer; hand it back to the caller).
3. **Edit, scoped by the gradient.** A confirmed miscalibration becomes a targeted edit: a
   `src/<system>.md` spec sharpened, a contract clarified, a `PHILOSOPHY.md` tenet amended
   (highest stakes — propose, never silently rewrite). Anything bigger than a targeted edit
   routes to `brainstorm`/`plan` as a design campaign.
4. **Record the outcome.** For each entry acted on, note the resolution so the caller can clear
   the source entry; log the pass alongside the seed's other change-records. Run the host's gate.

## Done when

The recurring design-flavored signal has become concrete seed edits (or a routed campaign), each
acted-on source entry has its resolution recorded, and the seed still passes `check`.
