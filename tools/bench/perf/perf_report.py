#!/usr/bin/env python3
"""QA-03 performance, battery and thermal report.

Input: run files (JSON) from a device run:
  {"device": {"id": "VV-IOS-11", "model": "iPhone 11", "tier": "low", "os": "iOS 18.1"},
   "build": {"app": "<commit>", "whisper": "<commit>", "llama": "<commit>"},
   "date": "YYYY-MM-DD",
   "conditions": {"start_thermal": "nominal", "plugged": false, "airplane": true},
   "metrics": [<JobMetrics.toJson() lines from the diagnostics zip>]}

Commands:
  check   run.json...            exit 1 when a budget is missed (budgets.json)
  report  run.json... [--out f]  Markdown report per device class
  compare --history h.json run.json...   exit 1 on a regression above the limit
  record  --history h.json run.json...   append the runs to the history file
No network, no audio and no transcript text is read: metrics only.
"""
import argparse
import json
import statistics
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BUDGETS = HERE / "budgets.json"


def load_budgets(path=BUDGETS):
    return json.loads(Path(path).read_text())


def summarize(run):
    """Normalise one run to the budget metrics."""
    metrics = run["metrics"]
    if not metrics:
        raise ValueError("run has no metrics")
    audio_ms = max((m.get("audio_ms") or 0) for m in metrics)
    if audio_ms <= 0:
        raise ValueError("run has no audio duration")
    wall_ms = sum(m.get("wall_ms") or 0 for m in metrics)
    audio_min = audio_ms / 60000
    deltas = [m["battery_delta_pct"] for m in metrics
              if m.get("battery_delta_pct") is not None]
    battery = sum(deltas) if deltas else None
    thermal = []
    for m in metrics:
        thermal += [str(s).lower() for s in m.get("thermal") or []]
    rss = [m["peak_rss_bytes"] for m in metrics if m.get("peak_rss_bytes")]
    return {
        "device": run["device"]["id"],
        "tier": run["device"]["tier"],
        "os": run["device"].get("os", ""),
        "date": run.get("date", ""),
        "audio_min": round(audio_min, 2),
        "wall_min": round(wall_ms / 60000, 2),
        "process_min_per_60": round(wall_ms / 60000 / audio_min * 60, 2),
        "battery_pct_per_audio_hour": (
            None if battery is None else round(battery / audio_min * 60, 2)),
        "thermal_states": sorted(set(thermal)),
        "peak_rss_mb": round(max(rss) / 1048576) if rss else None,
    }


def verdict(summary, budgets):
    tier = budgets["tiers"][summary["tier"]]
    problems = []
    if summary["process_min_per_60"] > tier["max_process_minutes_per_60"]:
        problems.append(
            f"time {summary['process_min_per_60']} min per 60 min audio > "
            f"{tier['max_process_minutes_per_60']}")
    b = summary["battery_pct_per_audio_hour"]
    if b is not None and b > tier["max_battery_pct_per_audio_hour"]:
        problems.append(
            f"battery {b}%/audio-hour > {tier['max_battery_pct_per_audio_hour']}")
    bad = set(summary["thermal_states"]) & set(budgets["forbidden_thermal_states"])
    if bad:
        problems.append("thermal reached " + ", ".join(sorted(bad)))
    return problems


def median_by_device(summaries):
    """Median across repeated runs of the same device (>= 3 runs per rules)."""
    groups = {}
    for s in summaries:
        groups.setdefault(s["device"], []).append(s)
    out = []
    for dev, runs in sorted(groups.items()):
        merged = dict(runs[-1])
        for key in ("process_min_per_60", "battery_pct_per_audio_hour"):
            vals = [r[key] for r in runs if r[key] is not None]
            merged[key] = round(statistics.median(vals), 2) if vals else None
        merged["thermal_states"] = sorted({t for r in runs for t in r["thermal_states"]})
        merged["runs"] = len(runs)
        out.append(merged)
    return out


def regressions(summaries, history, limit_pct):
    """Compare against the last history entry for the same device."""
    found = []
    for s in median_by_device(summaries):
        prev = [h for h in history if h["device"] == s["device"]]
        if not prev:
            continue
        base = prev[-1]
        for key in ("process_min_per_60", "battery_pct_per_audio_hour"):
            if s[key] is None or not base.get(key):
                continue
            change = (s[key] - base[key]) / base[key] * 100
            if change > limit_pct:
                found.append(f"{s['device']} {key} +{change:.1f}% "
                             f"({base[key]} -> {s[key]})")
    return found


def render(summaries, budgets):
    rows = median_by_device(summaries)
    lines = [
        "# Performance report",
        "",
        "Time is processing minutes per 60 minutes of audio (transcribe through "
        "write). Battery is percent per hour of audio processed.",
        "",
        "| Device | Tier | OS | Runs | Time (min/60) | Budget | Battery %/h | "
        "Budget | Peak RSS MB | Thermal | Result |",
        "|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for s in rows:
        t = budgets["tiers"][s["tier"]]
        problems = verdict(s, budgets)
        lines.append(
            f"| {s['device']} | {s['tier']} | {s['os']} | {s['runs']} | "
            f"{s['process_min_per_60']} | {t['max_process_minutes_per_60']} | "
            f"{s['battery_pct_per_audio_hour']} | "
            f"{t['max_battery_pct_per_audio_hour']} | {s['peak_rss_mb']} | "
            f"{', '.join(s['thermal_states']) or 'n/a'} | "
            f"{'PASS' if not problems else 'FAIL: ' + '; '.join(problems)} |")
    return "\n".join(lines) + "\n"


def read_runs(paths):
    return [summarize(json.loads(Path(p).read_text())) for p in paths]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("command", choices=["check", "report", "compare", "record"])
    ap.add_argument("runs", nargs="+")
    ap.add_argument("--budgets", default=str(BUDGETS))
    ap.add_argument("--history")
    ap.add_argument("--out")
    args = ap.parse_args(argv)
    budgets = load_budgets(args.budgets)
    summaries = read_runs(args.runs)

    if args.command == "check":
        failed = False
        for s in median_by_device(summaries):
            for p in verdict(s, budgets):
                failed = True
                print(f"FAIL {s['device']}: {p}")
        print("budgets exceeded" if failed else "budgets met")
        return 1 if failed else 0
    if args.command == "report":
        text = render(summaries, budgets)
        if args.out:
            Path(args.out).write_text(text)
        else:
            sys.stdout.write(text)
        return 0
    if not args.history:
        ap.error("--history is required")
    hist_path = Path(args.history)
    history = json.loads(hist_path.read_text()) if hist_path.exists() else []
    if args.command == "compare":
        found = regressions(summaries, history, budgets["regression_limit_pct"])
        for f in found:
            print("REGRESSION", f)
        return 1 if found else 0
    history += median_by_device(summaries)
    hist_path.write_text(json.dumps(history, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
