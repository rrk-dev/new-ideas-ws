# Device verification — <TASK-ID> <title>

Copy to `docs/test-plans/device/<TASK-ID>.md`. One row per device-only acceptance criterion
(and per device/OS where the criterion names several). The implementer writes the rows
(steps + expected); whoever runs them fills Device/OS/Result/Date/Tester. `tasks.py` accepts a
row only when Result is `PASS` and Date is `YYYY-MM-DD`.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [<TASK-ID>/AC1] | 1. … 2. … | … | iPhone 11 | iOS 18.x | PASS / FAIL | YYYY-MM-DD | name |

## Notes / evidence
Screenshots, screen recordings, measurements (paths under `docs/test-plans/device/evidence/<TASK-ID>/`).
