# Workstream configuration

Text outside the versioned blocks is explanatory. Empty hook bodies disable their events.

<!-- workstream:defaults@1 -->
mode: delegate
landing: local
ship-cadence: milestone
<!-- /workstream:defaults@1 -->

<!-- workstream:hook:feature-completion@1 -->
execution: inline
concurrency: serial

<!-- /workstream:hook:feature-completion@1 -->

<!-- workstream:hook:ship-friction@1 -->
execution: inline
concurrency: serial

<!-- /workstream:hook:ship-friction@1 -->
