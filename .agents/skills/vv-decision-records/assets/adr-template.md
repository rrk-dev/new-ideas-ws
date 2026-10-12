# ADR-<TASK-ID> — <Decision title>

- **Status:** Proposed | Accepted | Superseded by ADR-XXX
- **Date:** YYYY-MM-DD
- **Task:** <TASK-ID>
- **Deciders:** <agent + human reviewer>
- **Supersedes:** — 

## Context
What problem, which constraints (offline, privacy, devices, memory, license), why now.

## Options
1. **Option A** — one-line description
2. **Option B** — …

## Criteria (weights fixed before measuring)
| Criterion | Weight |
|---|---|
| Performance on target devices | 30% |
| Peak RAM / size | 20% |
| Integration effort | 15% |
| License & maintenance health | 15% |
| Privacy / network behaviour | 10% |
| Testability | 10% |

## Evidence
Environment: device(s), OS, build flags, library commit/version.

| Metric | Option A | Option B |
|---|---|---|
| … | … | … |

Raw data / scripts: `tools/spikes/NNN-<slug>/`

## Decision
We choose **<option>** because …

## Consequences
- Positive: …
- Negative / risks: … (with mitigation)
- Follow-up tasks: …
