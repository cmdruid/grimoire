# Investigation body scaffold

_Fills the body of a `reports` record minted by `records.sh new reports --title "..."` — the tool
stamps the front-matter and filename; this template supplies only the sections below._

## Reproduction

<The reliable reproduction — commands, seed, scenario. A flaky reproduction is itself a finding.>

## Root cause

<The actual cause, not the symptom — where the bad value/behavior first originates.>

## Evidence

<What confirms the root cause independently of the fix: the trace, the boundary logs, the diff
against the working analog, the minimal probe and its result.>

## Fix + verification

<The one fix (or "none landed — see findings"), the failing-test-first artifact, and how it was
verified: new test green, nothing else broke, original symptom gone.>

## Findings

<One keyed heading per finding an outside consumer might act on — the key matches `[a-z0-9-]+`
and is unique in this report. The findings slice is what a debrief/curate pass reads.>

#### <finding-key> — <title>

<The finding: a durable trap proven here, a playbook gap, an architectural question the three-fix
threshold surfaced.>
