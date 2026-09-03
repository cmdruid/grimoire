# `setup [<root>]` · deploy Inspector's project kind doctrine

1. Resolve `<root>` from the argument, else the current repository root. Require an existing
   directory and canonicalize it. Inspector uses fixed `.agents/skilldata`.
2. Run this package's `scripts/kinds-deploy.sh --root <root>`.
   The script resolves bundled `kinds/` relative to its own package; it never scans a front door.
3. Report each copied and incumbent kind. A collision may leave earlier safe copies in place;
   correct the collision and rerun. Never refresh an incumbent automatically.
4. Standalone and nonempty: collect each `deployed=<path>` line and make one pathspec-scoped commit
   over exactly those paths. No deployed paths means no commit. Inside an announced configuration
   sweep, remain write-only and return the paths to the caller.

Setup may create only `.agents/skilldata/inspector/doctrine/` and absent bundled kind files below
it. It does not create hooks, scripts, templates, records, a door route, or another owner's
namespace. Host-added extra kind files remain untouched. Normal `review`, `revise`, and `refine`
never invoke setup or create this namespace.

Done when all bundled kinds are present as project incumbents and every file first copied by this
run is byte-identical to its bundled source.
