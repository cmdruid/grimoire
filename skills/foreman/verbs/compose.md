# `compose` — extract and order reusable operations

Composition simplifies large project procedures without introducing a graph runtime.

1. Select the operations or native source in scope. Resolve complete bodies only after inventory
   selection.
2. Identify duplicated instruction that forms one stable, intention-revealing procedure. Preview
   the proposed shared operation and each reference replacement separately.
3. After explicit acceptance, write the shared Foreman-owned draft through `operation-write.sh put`.
   Return foreign publisher edits as bounded patches; never rewrite another owner's operation.
4. Build or revise a workflow as a written ordered list. Every top-level item begins with exactly one
   identity reference. Conditions and recovery notes may follow that reference in ordinary Markdown.
5. Validate the complete candidate set through `operation-check.sh --candidate`. Missing references,
   excluded candidates, and cycles write nothing.

Nested workflows are allowed and written order is execution order. Do not copy a referenced body
into another operation or add parallel nodes, dependency metadata, retries, or mutable step state.
