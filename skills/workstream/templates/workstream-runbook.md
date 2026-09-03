# <stream> — workstream runbook

<!-- workstream:identity@1 -->
stream	<stream>
instance-id	<instance-id>
root	<root>
worktree	<worktree>
branch	<branch>
target	<target>
isolation	worktree
landing	local
<!-- /workstream:identity@1 -->

<!-- workstream:brief@1 -->
purpose	<purpose>
orientation	Verify pointers against Git before trusting them.
operator-note	-
<!-- /workstream:brief@1 -->

<!-- workstream:policy@1 -->
mode	delegate	bundled
isolation	worktree	bundled
landing	local	bundled
ship-cadence	milestone	bundled
defaults-fingerprint	<sha256>	bundled
<!-- /workstream:policy@1 -->

<!-- workstream:hook:feature-completion@1 -->
execution	inline
concurrency	serial
source	bundled
fingerprint	<sha256>

<!-- /workstream:hook:feature-completion@1 -->

<!-- workstream:hook:ship-friction@1 -->
execution	inline
concurrency	serial
source	bundled
fingerprint	<sha256>

<!-- /workstream:hook:ship-friction@1 -->
