# Workstream configuration

This file declares the package defaults used when a project has not installed a `.streams`
control surface. `/workstream setup` installs a byte-identical managed copy that a project may
extend through the versioned blocks below.

<!-- workstream:policy@1 -->
mode	delegate
isolation	worktree
landing	local
ship-cadence	milestone
<!-- /workstream:policy@1 -->

<!-- workstream:hook@1 feature-completion -->
execution	inline
concurrency	serial
fallback	disabled
instructions	-
<!-- /workstream:hook@1 feature-completion -->

<!-- workstream:hook@1 ship-friction -->
execution	inline
concurrency	serial
fallback	disabled
instructions	-
<!-- /workstream:hook@1 ship-friction -->
