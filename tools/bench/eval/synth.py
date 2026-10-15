#!/usr/bin/env python3
"""Synthetic-audio recipe for extraction eval cases (PRF-09, vv-benchmark-eval).

script.md (scripted dialogue, synthetic people only) -> one TTS clip per turn
(macOS `say`, 16 kHz mono) -> concatenated WAV with pauses -> host whisper.cpp
(`whisper-cli` built from the pinned native/whisper.cpp) -> transcript.txt with
realistic ASR errors kept. Speakers are attributed from the script's turn
timings (a stand-in for diarization); profiles with `diarization: false` get
unlabelled lines.

Audio is written to a cache outside the repository and never committed:
${VV_EVAL_AUDIO_DIR:-~/.cache/vaultvoice/eval-audio}/<profile>/<case>.wav

Usage:
  tools/bench/eval/synth.py [--profile meeting] [--case meeting-001] [--force]
      [--whisper-cli native/build/whisper-cli/bin/whisper-cli]
      [--model ~/.cache/vaultvoice/bench/ggml-base.en-q8_0.bin]

Build whisper-cli once (dev machine only):
  cmake -S native/whisper.cpp -B native/build/whisper-cli -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DWHISPER_BUILD_EXAMPLES=ON -DWHISPER_BUILD_TESTS=OFF
  cmake --build native/build/whisper-cli --target whisper-cli
Piper TTS (MIT code; check each voice's license) may replace `say` on Linux:
pass --tts piper --piper-model <voice.onnx>.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EVAL = Path(__file__).resolve().parent
RATE = 16000
PAUSE_S = 0.45
LEAD_S = 0.6
TURN = re.compile(r"^([A-Za-z][\w .'-]{0,40}):\s+(.+)$")


def parse_script(path: Path) -> list[tuple[str, str]]:
    turns = []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = TURN.match(line.strip())
        if m and not line.startswith("#"):
            turns.append((m.group(1).strip(), m.group(2).strip()))
    return turns


def tts(text: str, voice: str, out: Path, args) -> None:
    if args.tts == "piper":
        subprocess.run(["piper", "--model", args.piper_model, "--output_file", str(out)],
                       input=text.encode(), check=True, capture_output=True)
        resample = out.with_suffix(".16k.wav")
        subprocess.run(["sox", str(out), "-r", str(RATE), "-c", "1", "-b", "16", str(resample)], check=True)
        resample.replace(out)
        return
    subprocess.run(["say", "-v", voice, "-o", str(out), "--file-format=WAVE",
                    f"--data-format=LEI16@{RATE}", text], check=True)


def read_pcm(path: Path) -> bytes:
    with wave.open(str(path), "rb") as w:
        if w.getframerate() != RATE or w.getnchannels() != 1 or w.getsampwidth() != 2:
            raise SystemExit(f"{path}: expected 16 kHz mono s16 (got {w.getframerate()} Hz)")
        return w.readframes(w.getnframes())


def synth_case(case_dir: Path, args, audio_root: Path) -> Path:
    meta = json.loads((case_dir / "meta.json").read_text())
    voices = {s["name"]: s.get("voice", "Samantha") for s in meta["speakers"]}
    turns = parse_script(case_dir / "script.md")
    if not turns:
        raise SystemExit(f"{case_dir}: script.md has no `Name: text` turns")
    out = audio_root / meta["profile"] / f"{meta['id']}.wav"
    out.parent.mkdir(parents=True, exist_ok=True)
    pcm = bytearray(b"\0\0" * int(LEAD_S * RATE))
    spans = []
    with tempfile.TemporaryDirectory() as tmp:
        for i, (who, text) in enumerate(turns):
            clip = Path(tmp) / f"{i}.wav"
            tts(text, voices.get(who, "Samantha"), clip, args)
            data = read_pcm(clip)
            start = len(pcm) // 2
            pcm += data
            spans.append((start / RATE, len(pcm) // 2 / RATE, who))
            pcm += b"\0\0" * int(PAUSE_S * RATE)
    with wave.open(str(out), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(pcm))
    (out.with_suffix(".turns.json")).write_text(json.dumps(spans))
    return out


def transcribe(wav: Path, args) -> list[dict]:
    with tempfile.TemporaryDirectory() as tmp:
        base = Path(tmp) / "out"
        subprocess.run([args.whisper_cli, "-m", args.model, "-f", str(wav), "-l", "en", "-oj",
                        "-of", str(base), "-np", "-t", str(os.cpu_count() or 4)],
                       check=True, capture_output=True)
        return json.loads((base.with_suffix(".json")).read_text())["transcription"]


def fmt(seconds: float) -> str:
    s = max(0, int(seconds))
    return f"{s // 3600:02d}:{s // 60 % 60:02d}:{s % 60:02d}"


def attribute(segments: list[dict], spans: list) -> list[tuple[float, str | None, str]]:
    out = []
    for seg in segments:
        a = seg["offsets"]["from"] / 1000
        b = seg["offsets"]["to"] / 1000
        text = " ".join(seg["text"].split())
        if not text:
            continue
        best, who = 0.0, None
        for (s, e, name) in spans:
            ov = min(b, e) - max(a, s)
            if ov > best:
                best, who = ov, name
        if who is None:  # pause-only segment: nearest turn
            who = min(spans, key=lambda t: abs(t[0] - a))[2]
        out.append((a, who, text))
    return out


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def main() -> int:
    home = Path.home()
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--profile", action="append")
    p.add_argument("--case", action="append")
    p.add_argument("--force", action="store_true")
    p.add_argument("--tts", choices=["say", "piper"], default="say")
    p.add_argument("--piper-model")
    p.add_argument("--whisper-cli", default=str(ROOT / "native/build/whisper-cli/bin/whisper-cli"))
    p.add_argument("--model", default=os.environ.get(
        "VV_EVAL_WHISPER_MODEL", str(home / ".cache/vaultvoice/bench/ggml-base.en-q8_0.bin")))
    args = p.parse_args()
    if args.tts == "say" and not shutil.which("say"):
        print("synth: macOS `say` not found (use --tts piper on Linux)", file=sys.stderr)
        return 2
    for tool in (args.whisper_cli, args.model):
        if not Path(tool).exists():
            print(f"synth: missing {tool} (see --help)", file=sys.stderr)
            return 2
    audio_root = Path(os.environ.get("VV_EVAL_AUDIO_DIR", home / ".cache/vaultvoice/eval-audio"))
    if str(audio_root.resolve()).startswith(str(ROOT)):
        print("synth: refusing to write audio inside the repository", file=sys.stderr)
        return 2
    model_sha = sha256(args.model)
    commit = subprocess.run(["git", "-C", str(ROOT / "native/whisper.cpp"), "rev-parse", "--short", "HEAD"],
                            capture_output=True, text=True).stdout.strip() or "?"
    profiles = args.profile or sorted(d.name for d in EVAL.iterdir() if (d / "scoring.json").exists())
    done = 0
    for prof in profiles:
        for case_dir in sorted((EVAL / prof).iterdir()):
            if not (case_dir / "script.md").exists():
                continue
            if args.case and case_dir.name not in args.case:
                continue
            transcript = case_dir / "transcript.txt"
            if transcript.exists() and not args.force:
                continue
            wav = synth_case(case_dir, args, audio_root)
            spans = json.loads(wav.with_suffix(".turns.json").read_text())
            meta = json.loads((case_dir / "meta.json").read_text())
            lines = attribute(transcribe(wav, args), spans)
            with transcript.open("w", encoding="utf-8") as f:
                for (t, who, text) in lines:
                    label = f"{who}: " if meta.get("diarization", True) else ""
                    f.write(f"[{fmt(t)}] {label}{text}\n")
            with wave.open(str(wav), "rb") as w:
                meta["duration_s"] = round(w.getnframes() / RATE, 2)
            meta["asr"] = {"engine": "whisper.cpp " + commit, "model": Path(args.model).name,
                           "model_sha256": model_sha[:16], "tts": args.tts}
            (case_dir / "meta.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n")
            done += 1
            print(f"synth: {case_dir.name}: {len(lines)} segments")
    print(f"synth: {done} case(s) transcribed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
