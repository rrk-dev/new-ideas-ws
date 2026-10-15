"""STT-05: DER scorer used by the diarization benchmark (synthetic RTTM; the
real-model AMI numbers live in docs/adr/ADR-STT-05-diarization.md)."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "bench" / "diarization"))
import der  # noqa: E402

T = der.Turn


def test_stt05_ac1_perfect_hypothesis_scores_zero_even_with_relabelled_speakers():
    ref = [T(0, 10, "a"), T(10, 20, "b"), T(20, 30, "a")]
    hyp = [T(0, 10, "x"), T(10, 20, "y"), T(20, 30, "x")]
    r = der.score(ref, hyp, collar=0.0)
    assert r["der"] == 0.0 and r["hyp_speakers"] == 2


def test_stt05_ac1_confusion_miss_and_false_alarm_are_counted():
    ref = [T(0, 10, "a"), T(10, 20, "b")]
    hyp = [T(0, 10, "x"), T(10, 15, "x"), T(15, 18, "y")]
    r = der.score(ref, hyp, uem=[(0, 20)], collar=0.0)
    assert abs(r["miss_s"] - 2.0) < 0.05
    assert abs(r["confusion_s"] - 5.0) < 0.1
    assert abs(r["der"] - 0.35) < 0.01


def test_stt05_ac1_collar_forgives_boundary_errors():
    ref = [T(0, 10, "a"), T(10, 20, "b")]
    hyp = [T(0, 10.2, "a"), T(10.2, 20, "b")]
    assert der.score(ref, hyp, collar=0.0)["der"] > 0
    assert der.score(ref, hyp, collar=0.25)["der"] == 0.0


def test_stt05_ac1_rttm_round_trip(tmp_path):
    turns = [T(0.5, 3.25, "spk1"), T(4.0, 6.0, "spk2")]
    p = tmp_path / "x.rttm"
    der.write_rttm(p, "f", turns)
    assert der.read_rttm(p) == turns
