# `setup` — reconcile the records tool layer

Stand up or refresh Journal's fixed `.records` tool layer in a generic brownfield project. Setup is
stateless: it derives work from the public layer and read-only Git evidence on every invocation. It
never resolves, inspects, migrates, or removes anything under `.spaces` and creates no writer
directory or project template.

1. **Resolve `<root>`.** Use the Git top level of the intended checkout; outside Git, use the project
   directory named by the conversation. A nested directory inside a Git checkout is not a second
   project root. Setup considers only `.records/records.sh`, `.records/history.tsv`, and
   `.records/README.md`.
2. **Run the reconciler.** Standalone or outside Git:
   `scripts/standup.sh setup <root>`. Inside an announced configuration sweep:
   `scripts/standup.sh setup <root> --write-only`.
   - A ledger tracked at the exact `HEAD` path but absent now refuses with
     `reason=ledger-recovery-required action=git-restore`.
   - A missing ledger witnessed by the current managed README markers or an archived record refuses
     with `reason=ledger-recovery-required action=human-review`.
   - Otherwise setup atomically reconciles provider → absent empty ledger → managed README. A fresh
     README contains exactly the managed block; an incumbent keeps every byte outside that block.
   - A content-check failure leaves the current tool layer in place and emits
     `records check failed — tool layer is current; action=/journal curate`.
3. **Take bounded custody.** `wrote: <path>` reports a current invocation write; `reconciled: <path>`
   reports an exact dirty result recovered from an earlier invocation. A nonzero custody refusal
   means commit nothing and leave the bounded diff for inspection. In a Git-backed standalone run,
   intersect the unique reported union with the paths still dirty after reconciliation; commit that
   exact nonempty set with
   `scripts/scoped-commit.sh <root> "Stand up the records layer" <paths...>`. A clean union makes no
   commit. Outside Git, the helper reports current `wrote:` paths only and the verb makes no commit.
   Inside an announced sweep, retain the reported writes in the sweep's approved diff custody and
   make no nested commit.

An interruption may leave a complete provider, ledger, or README prefix. Rerun the same command;
there is no private recovery artifact or finalization step.

## Done when

- The canonical executable provider, safe ledger, and current managed README block exist; no writer
  directories, private setup state, or noncanonical paths were read or changed.
- A Git-backed standalone run committed only the proven dirty reported union; a non-Git or announced
  run left commit custody with its caller.
- A content failure named `/journal curate` without undoing the current tool layer.
