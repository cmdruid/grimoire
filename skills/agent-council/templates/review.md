# Review-round reply

For every cluster id you were shown, emit one Reply block. Verdict is
exactly `confirm`, `refine`, or `rescind`. A refine MUST include
replacement claim / evidence / action / severity; omit them and the
orchestrator treats the reply as a confirm.

After the replies, you MAY emit new Opinion blocks in the round-1
ballot shape for claims that are not a refine of an existing cluster.

## Reply

- id: C1
- verdict: confirm
- claim:
- evidence:
- action:
- severity:

## Opinion

- claim: <one sentence>
- evidence: <path + quote, or file:line>
- action: <what to change>
- severity: high | mid | low
