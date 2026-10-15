"""QA-02: STT benchmark corpus + WER harness (tools/bench/)."""
import json
import re
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "bench" / "stt_wer"))
import wer  # noqa: E402

CORPUS = ROOT / "tools" / "bench" / "corpus"
RESULTS = ROOT / "tools" / "bench" / "results"


def test_QA_02_AC1_wer_normalizer_and_alignment():
    """[QA-02/AC1] WER counts S/D/I after a fixed normalization."""
    assert wer.normalize("It cost $649, OK?") == \
        "it cost six hundred forty nine dollars okay".split()
    assert wer.normalize("six hundred and forty nine dollars") == \
        "six hundred forty nine dollars".split()
    assert wer.normalize("the 15th at 7:15") == "the fifteenth at seven fifteen".split()
    assert wer.normalize("leaves at 7.15") == "leaves at seven fifteen".split()
    assert wer.normalize("Write-through cache, isn't it") == \
        "write through cache isn't it".split()
    s = wer.score("the cat sat on the mat", "the cat sat on mat today")
    assert (s["n"], s["sub"], s["del"], s["ins"]) == (6, 0, 1, 1)
    assert wer.wer([s]) == pytest.approx(2 / 6)
    assert wer.wer([]) == 0.0


def test_QA_02_AC1_corpus_manifest_is_consented_or_synthetic_only():
    """[QA-02/AC1] every corpus item is synthetic (our text) or public CC BY data;
    no audio is committed."""
    items = [json.loads(l) for l in (CORPUS / "corpus.jsonl").read_text().splitlines() if l]
    assert len(items) >= 40
    ids = [i["id"] for i in items]
    assert len(ids) == len(set(ids))
    for i in items:
        assert i["ref"].strip() and i["audio"].endswith(".wav")
        assert i["license"] in {"CC0 (our text)", "CC BY 4.0"}, i["id"]
        assert ("synthetic" in i["tags"]) ^ ("librispeech" in i["tags"]), i["id"]
    scripts = sorted(p.stem for p in (CORPUS / "scripts").glob("*.txt"))
    assert scripts == sorted(i["id"] for i in items if "synthetic" in i["tags"])
    assert sum(i["speakers"] > 1 for i in items) >= 2  # meetings
    assert not list(ROOT.joinpath("tools", "bench").rglob("*.wav"))
    assert not list(ROOT.joinpath("tools", "bench").rglob("*.flac"))


def test_QA_02_AC1_baseline_report_compares_at_least_two_models():
    """[QA-02/AC1] the committed baseline compares ≥ 2 models with WER + RTF."""
    reports = sorted(RESULTS.glob("*-qa02-stt-wer.jsonl"))
    assert reports, "no QA-02 baseline in tools/bench/results/"
    head = json.loads(reports[-1].read_text().splitlines()[0])
    models = head["models"]
    assert len(models) >= 2
    for m in models:
        assert 0 <= m["wer"] < 100 and m["rtf"] > 0 and m["load_ms"] > 0
        assert re.fullmatch(r"[0-9a-f]{16}", m["sha"])
        assert len(m["rtf_runs"]) >= 3
    assert head["agc"] and head["vad"]
    md = reports[-1].with_suffix(".md").read_text()
    assert "## Models" in md and "Software AGC" in md and "VAD trimming" in md


def test_QA_02_agc_port_matches_the_app_algorithm():
    """Software AGC port: boosts quiet speech toward −20 dBFS, never clips."""
    np = pytest.importorskip("numpy")
    import audio
    t = np.arange(audio.RATE * 2) / audio.RATE
    quiet = (0.01 * np.sin(2 * np.pi * 220 * t)).astype(np.float32)  # ≈ −43 dBFS
    out = audio.software_agc(quiet)
    assert audio.rms_db(out[audio.RATE:]) > audio.rms_db(quiet) + 15
    loud = (0.99 * np.sign(np.sin(2 * np.pi * 50 * t))).astype(np.float32)
    assert np.max(np.abs(audio.software_agc(loud))) <= 10 ** (-1 / 20) + 1e-4
    n = audio.add_noise(quiet, 10, "white", seed=1)
    assert abs((audio.rms_db(n - quiet) - audio.rms_db(quiet)) + 10) < 0.5
