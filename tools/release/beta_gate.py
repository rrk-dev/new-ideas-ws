#!/usr/bin/env python3
"""Production-release gate for the beta program (REL-04).

Reads a counts-only JSON report and the thresholds in beta_thresholds.json.
Exits 0 when every exit criterion is met, 1 when production must wait, and
2 when the report is malformed. Prints blocker sentences only — never the
report body — so a report that accidentally contains user content is not
echoed into CI logs.

Verified against the numbers in docs/beta.md. The same thresholds are
evaluated in app/lib/features/beta/domain/beta_exit.dart.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
THRESHOLDS_PATH = Path(__file__).with_name("beta_thresholds.json")

REQUIRED = (
    "ios_testers",
    "android_testers",
    "crash_free_session_rate",
    "data_loss_reports",
    "extraction_satisfaction",
    "open_s1",
)


def load_thresholds(path: Path = THRESHOLDS_PATH) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    for key in (
        "min_testers",
        "min_crash_free_session_rate",
        "max_data_loss_reports",
        "min_extraction_satisfaction",
        "max_open_s1",
    ):
        if key not in data:
            raise ValueError(f"thresholds missing {key}")
    return data


def _count(report: dict, key: str) -> int:
    value = report[key]
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{key} must be an integer")
    if value < 0:
        raise ValueError(f"{key} must be >= 0")
    return value


def _rate(report: dict, key: str) -> float:
    value = report[key]
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{key} must be a number")
    rate = float(value)
    if rate < 0 or rate > 1:
        raise ValueError(f"{key} must be between 0 and 1")
    return rate


def evaluate(report: dict, thresholds: dict | None = None) -> list[str]:
    """Blocker messages. An empty list means production promotion may proceed."""
    if not isinstance(report, dict):
        raise ValueError("report must be a JSON object")
    missing = [k for k in REQUIRED if k not in report]
    if missing:
        raise ValueError("report missing " + ", ".join(missing))
    limits = thresholds if thresholds is not None else load_thresholds()
    ios = _count(report, "ios_testers")
    android = _count(report, "android_testers")
    crash_free = _rate(report, "crash_free_session_rate")
    data_loss = _count(report, "data_loss_reports")
    satisfaction = _rate(report, "extraction_satisfaction")
    open_s1 = _count(report, "open_s1")

    min_testers = int(limits["min_testers"])
    min_crash_free = float(limits["min_crash_free_session_rate"])
    max_data_loss = int(limits["max_data_loss_reports"])
    min_satisfaction = float(limits["min_extraction_satisfaction"])
    max_s1 = int(limits["max_open_s1"])

    blockers: list[str] = []
    # Both stores: a single-platform beta is not "across platforms".
    if ios < 1 or android < 1:
        blockers.append(
            f"need testers on both iOS and Android (ios={ios}, android={android})"
        )
    if ios + android < min_testers:
        blockers.append(
            f"need at least {min_testers} beta testers "
            f"(have {ios + android})"
        )
    if crash_free < min_crash_free:
        blockers.append(
            f"crash-free sessions {crash_free:.4f} is below {min_crash_free:.4f}"
        )
    if data_loss > max_data_loss:
        blockers.append(
            f"data-loss reports {data_loss} exceed {max_data_loss}"
        )
    if satisfaction < min_satisfaction:
        blockers.append(
            f"extraction satisfaction {satisfaction:.3f} is below {min_satisfaction:.3f}"
        )
    if open_s1 > max_s1:
        blockers.append(f"open S1 beta issues {open_s1} exceed {max_s1}")
    return blockers


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: beta_gate.py <report.json>", file=sys.stderr)
        return 2
    path = Path(argv[1])
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
        blockers = evaluate(report)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"beta gate: invalid report ({exc.__class__.__name__})", file=sys.stderr)
        return 2
    if blockers:
        print("beta gate: production release is blocked", file=sys.stderr)
        for item in blockers:
            print(f"- {item}", file=sys.stderr)
        return 1
    print("beta gate: exit criteria met")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
