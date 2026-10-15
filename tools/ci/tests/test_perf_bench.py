"""QA-03: performance, battery and thermal harness (tools/bench/perf/)."""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PERF = ROOT / "tools" / "bench" / "perf"
sys.path.insert(0, str(PERF))
import perf_report  # noqa: E402

PASS = PERF / "fixtures" / "synthetic_high_pass.json"
FAIL = PERF / "fixtures" / "synthetic_low_fail.json"


def summary(path):
    return perf_report.summarize(json.loads(path.read_text()))


def test_QA_03_AC1_budgets_match_the_task_and_cover_every_tier():
    """[QA-03/AC1] High 15 min / Low 30 min per 60 min audio, 10%/h battery."""
    b = perf_report.load_budgets()
    assert b["tiers"]["high"]["max_process_minutes_per_60"] == 15
    assert b["tiers"]["low"]["max_process_minutes_per_60"] == 30
    assert b["tiers"]["high"]["max_battery_pct_per_audio_hour"] == 10
    assert {"low", "mid", "high"} <= set(b["tiers"])
    assert "critical" in b["forbidden_thermal_states"]


def test_QA_03_AC1_summary_normalises_to_60_minutes_of_audio():
    """[QA-03/AC1] Wall time and battery scale to per-60-min and per-hour."""
    s = summary(PASS)
    assert s["audio_min"] == 60.0
    assert s["process_min_per_60"] == 11.0
    assert s["battery_pct_per_audio_hour"] == 4.0
    assert s["peak_rss_mb"] == 900


def test_QA_03_AC1_verdict_passes_within_budget_and_flags_misses():
    """[QA-03/AC1] Over-time and critical thermal state are reported."""
    b = perf_report.load_budgets()
    assert perf_report.verdict(summary(PASS), b) == []
    problems = perf_report.verdict(summary(FAIL), b)
    assert any("time" in p for p in problems)
    assert any("thermal" in p for p in problems)


def test_QA_03_AC1_report_has_one_row_per_device_class():
    """[QA-03/AC1] The Markdown report lists each device with its verdict."""
    text = perf_report.render([summary(PASS), summary(FAIL)],
                              perf_report.load_budgets())
    assert "| VV-SYN-HIGH | high |" in text and "PASS" in text
    assert "| VV-SYN-LOW | low |" in text and "FAIL" in text


def test_QA_03_AC1_median_of_repeated_runs():
    """[QA-03/AC1] Three runs are reduced to the median per device."""
    base = summary(PASS)
    runs = [dict(base, process_min_per_60=v) for v in (10.0, 14.0, 12.0)]
    merged = perf_report.median_by_device(runs)
    assert merged[0]["process_min_per_60"] == 12.0 and merged[0]["runs"] == 3


def test_QA_03_AC1_regression_over_ten_percent_is_flagged(tmp_path):
    """[QA-03/AC1] More than 10% slower than the last release fails compare."""
    hist = tmp_path / "h.json"
    run = [sys.executable, str(PERF / "perf_report.py")]
    assert subprocess.run(run + ["record", "--history", str(hist), str(PASS)]
                          ).returncode == 0
    assert subprocess.run(run + ["compare", "--history", str(hist), str(PASS)]
                          ).returncode == 0
    slower = json.loads(PASS.read_text())
    slower["metrics"][0]["wall_ms"] *= 1.3
    slow = tmp_path / "slow.json"
    slow.write_text(json.dumps(slower))
    assert subprocess.run(run + ["compare", "--history", str(hist), str(slow)]
                          ).returncode == 1


def test_QA_03_AC1_check_exit_codes():
    """[QA-03/AC1] check exits 0 within budget and 1 outside."""
    run = [sys.executable, str(PERF / "perf_report.py"), "check"]
    assert subprocess.run(run + [str(PASS)]).returncode == 0
    assert subprocess.run(run + [str(FAIL)]).returncode == 1


def test_QA_03_AC1_report_and_protocol_docs_exist():
    """[QA-03/AC1] Report per device class and the measurement protocol."""
    report = (ROOT / "docs" / "perf-report.md").read_text()
    for dev in ("VV-IOS-11", "VV-IOS-16", "VV-AND-7", "VV-AND-4G"):
        assert dev in report
    assert (ROOT / "docs" / "perf.md").exists()
    assert (ROOT / "docs" / "test-plans" / "device" / "QA-03.md").exists()
