"""Extraction eval harness (PRF-09): dataset, metrics, regression gate, entry points."""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EVAL = ROOT / "tools" / "bench" / "eval"
sys.path.insert(0, str(EVAL))
import scoring  # noqa: E402

PROFILES = ["meeting", "warranty", "engineering"]


def _schema_keys(profile):
    text = (ROOT / "app" / "assets" / "profiles" / f"{profile}.yaml").read_text()
    m = re.search(r"^schema:\n  type: object\n  required: \[([^\]]+)\]", text, re.M)
    return [k.strip() for k in m.group(1).split(",")]


def test_PRF_09_AC1_dataset_30_synthetic_cases_per_builtin_profile():
    """[PRF-09/AC1] >= 30 cases per built-in profile, each with script, meta,
    whisper transcript and expected JSON covering the schema."""
    for profile in PROFILES:
        cases = [d for d in (EVAL / profile).iterdir() if (d / "expected.json").exists()]
        assert len(cases) >= 30, profile
        keys = _schema_keys(profile)
        for d in cases:
            meta = json.loads((d / "meta.json").read_text())
            assert meta["synthetic"] is True and meta["profile"] == profile, d
            assert "asr" in meta, f"{d}: transcript not produced by synth.py"
            assert (d / "script.md").read_text().count(":") >= 2, d
            lines = (d / "transcript.txt").read_text().strip().splitlines()
            assert lines and all(re.match(r"^\[\d\d:\d\d:\d\d\] ", line) for line in lines), d
            expected = json.loads((d / "expected.json").read_text())
            assert sorted(expected) == sorted(keys), d


def test_PRF_09_AC1_metrics_score_perfect_missing_and_hallucinated_items():
    """[PRF-09/AC1] list P/R/F1 with fuzzy matching, sub-field accuracy,
    scalar exact/fuzzy, hallucination rate."""
    cfg = json.loads((EVAL / "meeting" / "scoring.json").read_text())
    expected = json.loads((EVAL / "meeting" / "meeting-003" / "expected.json").read_text())
    transcript = (EVAL / "meeting" / "meeting-003" / "transcript.txt").read_text()

    perfect = scoring.score_case(expected, expected, transcript, cfg)
    agg = scoring.aggregate([{"valid": True, "score": perfect}], cfg)
    assert agg["lists"]["action_items"]["f1"] == 1.0
    assert agg["lists"]["action_items"]["owner_accuracy"] == 1.0
    assert agg["hallucination_rate"] == 0.0

    pred = json.loads(json.dumps(expected))
    pred["action_items"] = pred["action_items"][:1] + [
        {"task": "Buy a sailing boat for the office", "owner": "Zed", "due": None, "t": None}]
    pred["action_items"][0]["task"] = pred["action_items"][0]["task"].lower() + "."  # fuzzy
    pred["action_items"][0]["owner"] = "Diego"  # wrong owner
    s = scoring.score_case(expected, pred, transcript, cfg)
    agg = scoring.aggregate([{"valid": True, "score": s}], cfg)
    ai = agg["lists"]["action_items"]
    assert (ai["tp"], ai["expected"], ai["predicted"]) == (1, 2, 2)
    assert ai["precision"] == 0.5 and ai["recall"] == 0.5
    assert ai["owner_accuracy"] == 0.0
    assert agg["hallucination_rate"] > 0

    invalid = scoring.score_case(expected, None, transcript, cfg)
    agg = scoring.aggregate([{"valid": False, "score": invalid}], cfg)
    assert agg["schema_valid"] == 0.0 and agg["lists"]["action_items"]["recall"] == 0.0

    wcfg = json.loads((EVAL / "warranty" / "scoring.json").read_text())
    wexp = json.loads((EVAL / "warranty" / "warranty-001" / "expected.json").read_text())
    wpred = dict(wexp, serial_number="sm 441 027", brand="fabrikam", price="649 EUR")
    ws = scoring.score_case(wexp, wpred, "", wcfg)["scalars"]
    assert ws["serial_number"] == {"exact": True, "fuzzy": True}
    assert ws["brand"]["exact"] and not ws["price"]["exact"]


def test_PRF_09_AC1_regression_gate_flags_f1_drop_and_low_validity():
    """[PRF-09/AC1] a prompt change may not drop F1 > 2 points or validity < 99 %."""
    base = {"schema_valid": 1.0, "scalars": {}, "lists": {"action_items": {"f1": 0.80}}}
    ok = {"schema_valid": 0.99, "scalars": {}, "lists": {"action_items": {"f1": 0.785}}}
    bad = {"schema_valid": 0.97, "scalars": {}, "lists": {"action_items": {"f1": 0.77}}}
    assert scoring.regressions(ok, base) == []
    problems = scoring.regressions(bad, base)
    assert any("schema_valid" in p for p in problems)
    assert any("action_items.f1" in p for p in problems)


def test_PRF_09_AC1_make_eval_wraps_run_py():
    """[PRF-09/AC1] `make eval PROFILE=… MODEL=…` runs tools/bench/eval/run.py."""
    r = subprocess.run(["make", "-n", "eval", "PROFILE=warranty", "MODEL=/m/x.gguf"],
                       cwd=ROOT, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert "python3 tools/bench/eval/run.py --profile warranty --model /m/x.gguf" in r.stdout


def test_PRF_09_AC1_ci_eval_runs_on_prompt_or_profile_changes_only():
    """[PRF-09/AC1] tools/ci/eval.sh runs on prompt/profile changes, skips otherwise."""
    def decide(files):
        env = dict(os.environ, EVAL_CHANGED_FILES="\n".join(files))
        r = subprocess.run(["bash", str(ROOT / "tools/ci/eval.sh"), "--check-only"],
                           env=env, capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
        return r.stdout.strip()

    assert decide(["app/assets/profiles/meeting.yaml"]) == "run"
    assert decide(["app/lib/features/profiles/domain/prompt_builder.dart"]) == "run"
    assert decide(["tools/bench/eval/meeting/meeting-001/expected.json"]) == "run"
    assert decide(["native/llama.cpp"]) == "run"
    assert decide(["app/lib/features/recording/domain/wav_header.dart", "README.md"]) == "skip"
    assert decide([]) == "skip"


def test_PRF_09_AC2_baseline_numbers_recorded_for_each_builtin_profile():
    """[PRF-09/AC2] a baseline per built-in profile (SmolLM2) from the full case
    set, produced in < 30 min, with a committed report."""
    for profile in PROFILES:
        path = EVAL / "baselines" / f"{profile}.SmolLM2-135M-Instruct-Q8-0.json"
        data = json.loads(path.read_text())
        assert data["aggregate"]["cases"] >= 30, profile
        assert data["perf"]["wall_s"] < 30 * 60, profile
        assert 0.0 <= data["aggregate"]["schema_valid"] <= 1.0
        reports = list((ROOT / "tools/bench/results").glob(f"*-eval-{profile}-SmolLM2-135M-Instruct-Q8-0.md"))
        assert reports, profile
