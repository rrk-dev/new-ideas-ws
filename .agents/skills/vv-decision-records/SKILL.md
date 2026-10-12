---
name: vv-decision-records
description: "Technology decision spikes and ADRs in docs/adr/: framing options, weighted criteria, measured evidence, Proposed vs Accepted. Use whenever a task says decide/evaluate/spike or code picks one library/approach over another."
---

# Decision Spikes & Architecture Decision Records

## When an ADR is required
- The task Scope says "decision", "spike", "evaluate", "choose", or "Record decision".
- You add a new runtime dependency (pub package, native lib, model) not already covered by an ADR.
- You deviate from a recommendation in `tasks/README.md` → "Open Decisions".

## Procedure
1. **Frame**: write the question and the hard constraints from `AGENTS.md` (offline, privacy,
   iOS 16+/Android 26+ arm64, Flutter FFI, memory limits, license must allow commercial
   redistribution).
2. **Options**: at least 2 real options (plus "do nothing" if relevant). Include the default
   recommendation from `tasks/README.md`.
3. **Criteria** with weights, decided *before* measuring. Typical: performance on target devices,
   peak RAM, binary/model size, integration effort, license, maintenance health (last release,
   open issues, bus factor), privacy (network/telemetry), testability.
4. **Evidence**: build the smallest prototype that measures what matters. Put spike code in
   `tools/spikes/<adr-number>-<slug>/` (never in `app/lib`). Record device, OS, build flags,
   commit hashes, and raw numbers. Use `vv-benchmark-eval` methodology for numbers.
5. **Decide** and write `docs/adr/ADR-<TASK-ID>-<slug>.md` from `assets/adr-template.md`
   (e.g. `ADR-FND-04-database.md`, `ADR-LLM-01-runtime.md`). Naming by task ID means agents on
   parallel branches never collide. A second decision in the same task appends a letter
   (`ADR-SEC-01b-file-encryption.md`). Decisions without a task: `ADR-X-<yyyymmdd>-<slug>.md`.
6. **Propagate**: update `tasks/README.md` Open Decisions row ("Decided: ADR-<TASK-ID>"), and add
   a note to dependent tasks' `## Notes` if the decision changes their scope.

## Rules
- Measured beats assumed. If you could not measure on a device, say so in the ADR and set status
  `Proposed` (not `Accepted`); the task goes to `review`.
- Product decisions (pricing, Free vs Pro, naming) are not yours: write the ADR as `Proposed`
  with options and ask the user.
- Superseding: never edit an Accepted ADR's decision; write a new ADR with `Supersedes: ADR-<id>`.
- Check licenses of every option (see `vv-privacy-security` → license compliance).
