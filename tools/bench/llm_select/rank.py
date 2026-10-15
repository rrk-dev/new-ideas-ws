#!/usr/bin/env python3
"""Default LLM selection (LLM-08): ranks candidate models from PRF-09 eval results.

  tools/bench/llm_select/rank.py [--results tools/bench/results] [--out FILE] [--json FILE]

Inputs: candidates.json (license, size, tier budgets, weights fixed up front) and the
`*-eval-<profile>-<model>.json` files written by tools/bench/eval/run.py (latest per
model x profile). A model is *measured* only when all three built-in profiles have a result.

Hard gates per tier (a failing candidate is never selected): commercial licence, not CI-only,
Free-plan size cap, RAM budget (measured peak RSS, else 1.25 x file size), first-pass schema
validity >= 0.90. Eligible candidates are ranked by the weighted score; unmeasured eligible
candidates are listed as `needs-eval` and never selected, so no default is picked from guesses.
Stdlib only.
"""
from __future__ import annotations

import argparse
import json
import re
import statistics
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent / "eval"
PROFILES = ("meeting", "warranty", "engineering")
MIN_SCHEMA_VALID = 0.90
UNMEASURED_RAM_FACTOR = 1.25
HALLUCINATION_CEILING = 0.15


def lookup(agg: dict, dotted: str):
    cur = agg
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def load_results(results_dir: Path) -> dict[str, dict[str, dict]]:
    """model file -> profile -> result (latest date wins)."""
    out: dict[str, dict[str, dict]] = {}
    for f in sorted(results_dir.glob("*-eval-*.json")):
        m = re.match(r"^(\d{4}-\d\d-\d\d)-eval-([a-z]+)-", f.name)
        if not m:
            continue
        data = json.loads(f.read_text())
        model, profile = data["env"]["model"], m.group(2)
        prev = out.setdefault(model, {}).get(profile)
        if prev is None or data["env"]["date"] >= prev["env"]["date"]:
            out[model][profile] = data
    return out


def profile_quality(profile: str, agg: dict) -> float:
    """Mean target attainment (capped at 1) over the profile's non-schema targets."""
    targets = json.loads((EVAL / profile / "scoring.json").read_text())["targets"]
    parts = []
    for key, required in targets.items():
        if key == "schema_valid":
            continue
        actual = lookup(agg, key)
        parts.append(min((actual or 0.0) / required, 1.0))
    return statistics.mean(parts) if parts else 0.0


def measure(per_profile: dict[str, dict]) -> dict | None:
    if not all(p in per_profile for p in PROFILES):
        return None
    aggs = {p: per_profile[p]["aggregate"] for p in PROFILES}
    perf = [per_profile[p]["perf"] for p in PROFILES]
    return {
        "quality": statistics.mean(profile_quality(p, aggs[p]) for p in PROFILES),
        "quality_by_profile": {p: profile_quality(p, aggs[p]) for p in PROFILES},
        "schema_valid": statistics.mean(a["schema_valid"] for a in aggs.values()),
        "hallucination": statistics.mean(a["hallucination_rate"] for a in aggs.values()),
        "decode_tps": statistics.median(p["decode_tps"] for p in perf),
        "prefill_tps": statistics.median(p["prefill_tps"] for p in perf),
        "peak_rss_mib": max(p["peak_rss"] for p in perf) / 2**20,
        "backend": per_profile["meeting"]["env"].get("backend"),
        "host": per_profile["meeting"]["env"].get("host"),
    }


def gates(c: dict, m: dict | None, tier: str, cfg: dict) -> list[str]:
    fails = []
    if c["license_status"] != "ok":
        fails.append(f"licence: {c['license']}")
    if c.get("ci_only"):
        fails.append("CI-only model")
    spec = cfg["tiers"][tier]
    if "max_size_mib" in spec and c["size_mib"] > spec["max_size_mib"]:
        fails.append(f"size {c['size_mib']} MiB > Free cap {spec['max_size_mib']}")
    budget = spec.get("ram_budget_mib", cfg["tiers"]["low"]["ram_budget_mib"])
    ram = m["peak_rss_mib"] if m else c["size_mib"] * UNMEASURED_RAM_FACTOR
    if ram > budget:
        fails.append(f"RAM {ram:.0f} MiB > budget {budget}")
    if m and m["schema_valid"] < MIN_SCHEMA_VALID:
        fails.append(f"schema_valid {m['schema_valid']:.2f} < {MIN_SCHEMA_VALID}")
    return fails


def score(c: dict, m: dict, tier: str, cfg: dict) -> dict:
    w = cfg["weights"]
    spec = cfg["tiers"][tier]
    budget = spec.get("ram_budget_mib", cfg["tiers"]["low"]["ram_budget_mib"])
    parts = {
        "quality": m["quality"],
        "schema_validity": m["schema_valid"],
        "hallucination": 1 - min(m["hallucination"] / HALLUCINATION_CEILING, 1),
        "speed": min(m["decode_tps"] / cfg["speed_target_decode_tps"], 1),
        "ram": max(0.0, 1 - m["peak_rss_mib"] / budget),
        "license": c["maintenance"] if c["license_status"] == "ok" else 0.0,
    }
    return {"parts": parts, "total": sum(w[k] * v for k, v in parts.items())}


def evaluate(cfg: dict, results: dict) -> dict:
    tiers = {}
    rows = {}
    for c in cfg["candidates"]:
        m = measure(results.get(c["file"], {}))
        rows[c["id"]] = {"candidate": c, "measured": m}
    for tier in cfg["tiers"]:
        ranked, needs_eval, rejected = [], [], []
        for cid, r in rows.items():
            c, m = r["candidate"], r["measured"]
            fails = gates(c, m, tier, cfg)
            if fails:
                rejected.append({"id": cid, "reasons": fails})
            elif m is None:
                needs_eval.append(cid)
            else:
                ranked.append({"id": cid, **score(c, m, tier, cfg)})
        ranked.sort(key=lambda x: -x["total"])
        tiers[tier] = {"selected": ranked[0]["id"] if ranked else None, "ranked": ranked,
                       "needs_eval": needs_eval, "rejected": rejected,
                       "complete": not needs_eval}
    return {"models": rows, "tiers": tiers}


def render(cfg: dict, res: dict) -> str:
    L = ["# LLM default model selection (LLM-08)", "",
         "Weights: " + ", ".join(f"{k} {v:.0%}" for k, v in cfg["weights"].items()), "",
         "## Measured candidates", "",
         "| Model | Quality | Schema-valid | Halluc. | Decode tok/s | Peak RSS MiB | Backend |",
         "|---|---|---|---|---|---|---|"]
    for cid, r in res["models"].items():
        m = r["measured"]
        if m:
            L.append(f"| {cid} | {m['quality']:.0%} | {m['schema_valid']:.1%} | {m['hallucination']:.1%} | "
                     f"{m['decode_tps']:.0f} | {m['peak_rss_mib']:.0f} | {m['backend']} |")
    L += ["", "## Per tier", ""]
    for tier, t in res["tiers"].items():
        L.append(f"### {tier}: " + (f"**{t['selected']}**" + ("" if t["complete"] else " (provisional: eligible candidates still unmeasured)")
                                  if t["selected"] else "no measured eligible model"))
        for i, r in enumerate(t["ranked"], 1):
            L.append(f"{i}. {r['id']} — {r['total']:.3f}")
        if t["needs_eval"]:
            L.append("- needs-eval: " + ", ".join(t["needs_eval"]))
        for r in t["rejected"]:
            L.append(f"- rejected {r['id']}: {'; '.join(r['reasons'])}")
        L.append("")
    return "\n".join(L)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--candidates", default=str(HERE / "candidates.json"))
    ap.add_argument("--results", default=str(HERE.parents[1] / "bench" / "results"))
    ap.add_argument("--out")
    ap.add_argument("--json")
    a = ap.parse_args(argv)
    cfg = json.loads(Path(a.candidates).read_text())
    res = evaluate(cfg, load_results(Path(a.results)))
    text = render(cfg, res)
    print(text)
    if a.out:
        Path(a.out).write_text(text + "\n")
    if a.json:
        Path(a.json).write_text(json.dumps(res, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
