"""LLM-08: model selection harness and ADR."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SEL = ROOT / "tools" / "bench" / "llm_select"
sys.path.insert(0, str(SEL))
import rank as sel  # noqa: E402

CFG = json.loads((SEL / "candidates.json").read_text())


def _result(model, quality_scale, valid=1.0, rss_mib=1000, tps=90, halluc=0.05):
    """Synthetic results for the three profiles; quality_scale scales every target metric."""
    out = {}
    for p in sel.PROFILES:
        targets = json.loads((sel.EVAL / p / "scoring.json").read_text())["targets"]
        agg = {"schema_valid": valid, "hallucination_rate": halluc, "lists": {}, "scalars": {}}
        for key, req in targets.items():
            if key == "schema_valid":
                continue
            cur = agg
            parts = key.split(".")
            for part in parts[:-1]:
                cur = cur.setdefault(part, {})
            cur[parts[-1]] = req * quality_scale
        out[p] = {"env": {"model": model, "date": "2026-10-15", "backend": "cpu", "host": "t"},
                  "perf": {"decode_tps": tps, "prefill_tps": 500, "peak_rss": rss_mib * 2**20},
                  "aggregate": agg}
    return out


def _cand(cid):
    return next(c for c in CFG["candidates"] if c["id"] == cid)


def test_LLM_08_AC1_ranks_measured_models_and_selects_best_per_tier():
    """[LLM-08/AC1] decision backed by a results table: better measured model wins a tier."""
    f1, f3 = _cand("llama-3.2-1b-instruct-q4_k_m")["file"], _cand("llama-3.2-3b-instruct-q4_k_m")["file"]
    results = {f1: _result(f1, 0.6), f3: _result(f3, 0.95, rss_mib=2300, tps=40)}
    res = sel.evaluate(CFG, results)
    assert res["tiers"]["mid"]["selected"] == "llama-3.2-3b-instruct-q4_k_m"
    assert res["tiers"]["free"]["selected"] == "llama-3.2-1b-instruct-q4_k_m"
    assert "llama-3.2-3b-instruct-q4_k_m" in {r["id"] for r in res["tiers"]["free"]["rejected"]}
    text = sel.render(CFG, res)
    assert "| llama-3.2-3b-instruct-q4_k_m |" in text and "### mid:" in text


def test_LLM_08_AC1_license_gate_blocks_non_commercial_models():
    """[LLM-08/AC1] Qwen2.5-3B (research licence) is never selectable, even when it scores best."""
    f = _cand("qwen2.5-3b-instruct-q4_k_m")["file"]
    res = sel.evaluate(CFG, {f: _result(f, 1.0, rss_mib=2000)})
    for tier in ("mid", "high"):
        assert res["tiers"][tier]["selected"] is None
        assert any("licence" in x for r in res["tiers"][tier]["rejected"] if r["id"] == "qwen2.5-3b-instruct-q4_k_m"
                   for x in r["reasons"])


def test_LLM_08_AC1_ram_and_schema_gates_and_unmeasured_never_selected():
    """[LLM-08/AC1] RAM budget and schema-validity floor reject; unmeasured is `needs-eval`."""
    f = _cand("llama-3.2-1b-instruct-q4_k_m")["file"]
    bad = sel.evaluate(CFG, {f: _result(f, 1.0, valid=0.5)})
    assert bad["tiers"]["low"]["selected"] is None
    big = sel.evaluate(CFG, {f: _result(f, 1.0, rss_mib=1800)})
    assert big["tiers"]["low"]["selected"] is None and big["tiers"]["mid"]["selected"] == _cand("llama-3.2-1b-instruct-q4_k_m")["id"]
    none = sel.evaluate(CFG, {})
    assert all(t["selected"] is None for t in none["tiers"].values())
    assert "gemma-3-1b-it-q4_k_m" in none["tiers"]["free"]["needs_eval"]


def test_LLM_08_AC1_weights_sum_to_one_and_candidates_cover_required_models():
    """[LLM-08/AC1] criteria weights are fixed up front; required candidates + licences recorded."""
    assert abs(sum(CFG["weights"].values()) - 1.0) < 1e-9
    ids = {c["id"] for c in CFG["candidates"]}
    assert {"llama-3.2-3b-instruct-q4_k_m", "llama-3.2-1b-instruct-q4_k_m", "gemma-2-2b-it-q4_k_m"} <= ids
    assert all(c["license"] and c["license_status"] in ("ok", "blocked") for c in CFG["candidates"])


def test_LLM_08_AC1_committed_results_and_adr_exist():
    """[LLM-08/AC1] real host results table + ADR-LLM-08 are committed and agree."""
    adr = (ROOT / "docs" / "adr" / "ADR-LLM-08-default-llm.md").read_text()
    assert "**Status:** Proposed" in adr or "**Status:** Accepted" in adr
    report = (ROOT / "tools" / "bench" / "results" / "2026-10-15-llm08-selection.md").read_text()
    assert "llama-3.2-1b-instruct-q4_k_m" in report and "Llama-3.2-1B" in adr
    live = sel.evaluate(CFG, sel.load_results(ROOT / "tools" / "bench" / "results"))
    assert live["tiers"]["free"]["selected"]
