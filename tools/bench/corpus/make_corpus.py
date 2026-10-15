#!/usr/bin/env python3
"""Builds the QA-02 STT benchmark corpus audio outside the repository.

Two parts (nothing personal is ever committed; audio never lands in git):

* synthetic — our own scripted texts (`scripts/*.txt`, `<voice>|<text>` per
  turn) spoken by macOS `say` voices (US/UK/IE/IN/AU English, 1–3 speakers),
  converted with `afconvert` to 16 kHz mono PCM16, turns joined by 0.6 s of
  silence. Writes `<id>.wav` + `<id>.segments.json` (true speech spans, for
  the VAD-trimming comparison). Needs macOS.
* librispeech — LibriSpeech test-clean (OpenSLR SLR12, CC BY 4.0,
  https://www.openslr.org/12): downloads `test-clean.tar.gz` (verified by
  sha256), extracts the utterances listed in `librispeech-test-clean.jsonl`
  (2 per speaker, first 20 speakers by id) and converts FLAC → 16 kHz WAV
  (afconvert, ffmpeg or sox). `--select` regenerates that list + refs.

Usage:
  make_corpus.py [--dest DIR] [synthetic] [librispeech] [manifest] [--select]
  (`manifest` rewrites the committed corpus.jsonl; `--select` implies it)
  DIR default $VV_BENCH_CORPUS_DIR or ~/.cache/vaultvoice/bench/qa02-corpus
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "stt_wer"))
import audio  # noqa: E402

LIBRI_URL = "https://www.openslr.org/resources/12/test-clean.tar.gz"
LIBRI_SHA256 = "39fde525e59672dc6d1551919b1478f724438a95aa55f874b576be21967e6c23"
LIBRI_MANIFEST = HERE / "librispeech-test-clean.jsonl"
GAP_S = 0.6
RATE_WPM = "175"


def default_dest() -> Path:
    env = os.environ.get("VV_BENCH_CORPUS_DIR")
    return Path(env) if env else Path.home() / ".cache" / "vaultvoice" / "bench" / "qa02-corpus"


def parse_script(path: Path) -> list[tuple[str, str]]:
    turns = []
    for line in path.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        voice, text = line.split("|", 1)
        turns.append((voice.strip(), text.strip()))
    return turns


def script_ref(path: Path) -> str:
    return " ".join(t for _, t in parse_script(path))


def to_wav16k(src: Path, dst: Path) -> None:
    if shutil.which("afconvert"):
        cmd = ["afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", str(src), str(dst)]
    elif shutil.which("ffmpeg"):
        cmd = ["ffmpeg", "-loglevel", "error", "-y", "-i", str(src), "-ac", "1", "-ar", "16000",
               "-sample_fmt", "s16", str(dst)]
    elif shutil.which("sox"):
        cmd = ["sox", str(src), "-r", "16000", "-c", "1", "-b", "16", str(dst)]
    else:
        raise SystemExit("need afconvert (macOS), ffmpeg or sox to convert audio")
    subprocess.run(cmd, check=True)


def make_synthetic(dest: Path) -> None:
    if not shutil.which("say"):
        raise SystemExit("synthetic corpus needs macOS `say`")
    out = dest / "synthetic"
    out.mkdir(parents=True, exist_ok=True)
    import numpy as np
    for script in sorted((HERE / "scripts").glob("*.txt")):
        pieces, segs, pos = [], [], 0
        gap = np.zeros(int(GAP_S * audio.RATE), dtype=np.float32)
        with tempfile.TemporaryDirectory() as tmp:
            for i, (voice, text) in enumerate(parse_script(script)):
                aiff, wav = Path(tmp) / f"{i}.aiff", Path(tmp) / f"{i}.wav"
                subprocess.run(["say", "-v", voice, "-r", RATE_WPM, "-o", str(aiff), text],
                               check=True)
                to_wav16k(aiff, wav)
                x = audio.read_wav(wav)
                pieces += [gap, x]
                pos += len(gap)
                segs.append((pos * 1000 // audio.RATE, (pos + len(x)) * 1000 // audio.RATE))
                pos += len(x)
        pieces.append(gap)
        audio.write_wav(out / f"{script.stem}.wav", np.concatenate(pieces))
        (out / f"{script.stem}.segments.json").write_text(json.dumps(segs))
        print(f"synthetic/{script.stem}.wav")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def fetch_librispeech(dest: Path) -> Path:
    tgz = dest / "downloads" / "test-clean.tar.gz"
    if not tgz.exists() or sha256(tgz) != LIBRI_SHA256:
        tgz.parent.mkdir(parents=True, exist_ok=True)
        print(f"downloading {LIBRI_URL} (331 MB)")
        urllib.request.urlretrieve(LIBRI_URL, tgz)  # dev tooling, not the app
        if sha256(tgz) != LIBRI_SHA256:
            tgz.unlink()
            raise SystemExit("test-clean.tar.gz: sha256 mismatch")
    return tgz


def select_librispeech(tgz: Path) -> None:
    """Regenerates librispeech-test-clean.jsonl (ids + reference text)."""
    trans: dict[str, str] = {}
    with tarfile.open(tgz) as tf:
        for m in tf:
            if m.name.endswith(".trans.txt"):
                for line in tf.extractfile(m).read().decode().splitlines():
                    uid, text = line.split(" ", 1)
                    trans[uid] = text
    by_speaker: dict[str, list[str]] = {}
    for uid in sorted(trans):
        by_speaker.setdefault(uid.split("-")[0], []).append(uid)
    picked = [u for spk in sorted(by_speaker, key=int)[:20] for u in by_speaker[spk][:2]]
    with LIBRI_MANIFEST.open("w") as f:
        for uid in picked:
            f.write(json.dumps({"id": f"ls-{uid}", "utterance": uid, "ref": trans[uid]}) + "\n")
    print(f"selected {len(picked)} utterances → {LIBRI_MANIFEST.name}")


def make_librispeech(dest: Path, select: bool) -> None:
    tgz = fetch_librispeech(dest)
    if select or not LIBRI_MANIFEST.exists():
        select_librispeech(tgz)
    wanted = {json.loads(l)["utterance"] for l in LIBRI_MANIFEST.read_text().splitlines() if l}
    out = dest / "librispeech"
    out.mkdir(parents=True, exist_ok=True)
    with tarfile.open(tgz) as tf, tempfile.TemporaryDirectory() as tmp:
        for m in tf:
            uid = Path(m.name).stem
            if m.name.endswith(".flac") and uid in wanted and not (out / f"{uid}.wav").exists():
                flac = Path(tmp) / f"{uid}.flac"
                flac.write_bytes(tf.extractfile(m).read())
                to_wav16k(flac, out / f"{uid}.wav")
    print(f"librispeech: {len(list(out.glob('*.wav')))} wav files in {out}")


TAGS = {
    "notes": ["clean", "voice-memo"], "meeting": ["clean", "meeting"],
    "engineering": ["clean", "vocabulary"], "warranty": ["clean", "numbers"],
    "accent": ["clean", "accent"],
}


def write_manifest() -> None:
    """corpus.jsonl: one line per item — {id, audio (relative to the corpus
    dir), ref, speakers, tags, source, license}."""
    lines = []
    for script in sorted((HERE / "scripts").glob("*.txt")):
        turns = parse_script(script)
        lines.append({
            "id": script.stem, "audio": f"synthetic/{script.stem}.wav",
            "ref": " ".join(t for _, t in turns),
            "speakers": len({v for v, _ in turns}),
            "tags": TAGS[script.stem.split("-")[0]] + ["synthetic"],
            "source": "synthetic (own script, macOS say)", "license": "CC0 (our text)",
        })
    for l in LIBRI_MANIFEST.read_text().splitlines():
        e = json.loads(l)
        lines.append({
            "id": e["id"], "audio": f"librispeech/{e['utterance']}.wav", "ref": e["ref"],
            "speakers": 1, "tags": ["clean", "read-speech", "librispeech"],
            "source": "LibriSpeech test-clean (OpenSLR SLR12)", "license": "CC BY 4.0",
        })
    (HERE / "corpus.jsonl").write_text("".join(json.dumps(x) + "\n" for x in lines))
    print(f"corpus.jsonl: {len(lines)} items")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("parts", nargs="*", default=["synthetic", "librispeech"])
    ap.add_argument("--dest", type=Path, default=default_dest())
    ap.add_argument("--select", action="store_true")
    a = ap.parse_args()
    if "synthetic" in a.parts:
        make_synthetic(a.dest)
    if "librispeech" in a.parts:
        make_librispeech(a.dest, a.select)
    if "manifest" in a.parts or a.select:
        write_manifest()
    print(f"VV_BENCH_CORPUS_DIR={a.dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
