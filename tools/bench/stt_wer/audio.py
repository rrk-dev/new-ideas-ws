"""16 kHz mono PCM16 WAV helpers + test conditions for the QA-02 harness.

Dev tooling only (numpy on the host); nothing here ships in the app.
"""
from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np

RATE = 16000


def read_wav(path: Path) -> np.ndarray:
    """Float32 samples in [-1, 1] of a 16 kHz mono PCM16 WAV."""
    with wave.open(str(path), "rb") as w:
        if w.getframerate() != RATE or w.getnchannels() != 1 or w.getsampwidth() != 2:
            raise ValueError(f"{path}: need 16 kHz mono PCM16")
        data = w.readframes(w.getnframes())
    return np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768.0


def write_wav(path: Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(np.round(x * 32768.0), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def rms_db(x: np.ndarray) -> float:
    r = float(np.sqrt(np.mean(np.square(x, dtype=np.float64)))) if len(x) else 0.0
    return -math.inf if r == 0 else 20 * math.log10(r)


def gain(x: np.ndarray, db: float) -> np.ndarray:
    return x * (10 ** (db / 20))


def noise(n: int, kind: str, seed: int) -> np.ndarray:
    """Unit-RMS noise: 'white', 'pink' (1/f, Voss-McCartney-free FFT shaping)
    or 'babble' (8 summed, shifted, low-passed speech-like noise bursts)."""
    rng = np.random.default_rng(seed)
    if kind == "white":
        y = rng.standard_normal(n)
    elif kind == "pink":
        spec = np.fft.rfft(rng.standard_normal(n))
        f = np.fft.rfftfreq(n, 1 / RATE)
        f[0] = f[1]
        y = np.fft.irfft(spec / np.sqrt(f), n)
    elif kind == "babble":
        # Modulated pink noise with syllable-rate (4 Hz) envelopes: a
        # content-free stand-in for cafeteria babble (no real voices).
        y = np.zeros(n)
        t = np.arange(n) / RATE
        for k in range(8):
            env = 0.5 * (1 + np.sin(2 * math.pi * (3 + k * 0.4) * t + rng.uniform(0, 6.28)))
            y += noise(n, "pink", seed * 31 + k) * env
    else:
        raise ValueError(kind)
    y = y.astype(np.float64)
    return (y / (np.sqrt(np.mean(y * y)) + 1e-12)).astype(np.float32)


def add_noise(x: np.ndarray, snr_db: float, kind: str, seed: int = 1) -> np.ndarray:
    """Mixes noise at [snr_db] relative to the speech RMS (active samples)."""
    active = x[np.abs(x) > 1e-4]
    speech_rms = float(np.sqrt(np.mean(np.square(active)))) if len(active) else 1e-3
    nrms = speech_rms / (10 ** (snr_db / 20))
    return (x + noise(len(x), kind, seed) * nrms).astype(np.float32)


def software_agc(x: np.ndarray, target_dbfs=-20.0, max_gain_db=20.0, min_gain_db=-12.0,
                 ceiling_dbfs=-1.0, gate_dbfs=-60.0, attack_ms=10.0, release_ms=500.0,
                 rms_ms=50.0) -> np.ndarray:
    """Port of AUD-02 `SoftwareAgc` (app/lib/features/recording/domain/
    software_agc.dart on task/AUD-02-agc-level-metering @ 493d1b5): RMS
    envelope, attack/release-smoothed gain toward target, noise gate, peak
    limiter at the ceiling. Same defaults, sample by sample."""
    def coef(ms):
        n = ms * RATE / 1000
        return 1.0 if n <= 0 else 1 - math.exp(-1 / n)

    a, r, rc = coef(attack_ms), coef(release_ms), coef(rms_ms)
    ceiling = 10 ** (ceiling_dbfs / 20) * 32767
    gmax, gmin = 10 ** (max_gain_db / 20), 10 ** (min_gain_db / 20)
    target, gate = 10 ** (target_dbfs / 20), 10 ** (gate_dbfs / 20)
    pcm = np.clip(np.round(x * 32768.0), -32768, 32767)
    out = np.empty_like(pcm)
    env, g = 0.0, 1.0
    c = math.floor(ceiling)
    for i, s in enumerate(pcm.tolist()):
        norm = s / 32768
        env += rc * (norm * norm - env)
        rms = math.sqrt(env)
        if rms >= gate:
            wanted = min(max(target / rms, gmin), gmax)
            g += (a if wanted < g else r) * (wanted - g)
        gi = g
        mag = abs(s)
        if mag * gi > ceiling:
            gi = ceiling / mag
            g = gi
        y = round(s * gi)
        out[i] = c if y > c else (-c if y < -c else y)
    return (out / 32768.0).astype(np.float32)


def pad_silence(segments_ms: list[tuple[int, int]], x: np.ndarray, gap_s: float,
                noise_db: float = -70.0, seed: int = 3) -> tuple[np.ndarray, list[tuple[int, int]]]:
    """Re-assembles the speech [segments_ms] with [gap_s] of near-silence
    (room tone at [noise_db] dBFS) between them — a long recording with
    pauses, for the VAD-trimming comparison. Returns audio + new segments."""
    pieces, segs, pos = [], [], 0
    lead = int(gap_s * RATE)
    tone = lambda n: noise(n, "pink", seed + n) * (10 ** (noise_db / 20))  # noqa: E731
    pieces.append(tone(lead))
    pos = lead
    for (s, e) in segments_ms:
        chunk = x[s * RATE // 1000:e * RATE // 1000]
        pieces.append(chunk)
        segs.append((pos * 1000 // RATE, (pos + len(chunk)) * 1000 // RATE))
        pos += len(chunk)
        pieces.append(tone(lead))
        pos += lead
    return np.concatenate(pieces).astype(np.float32), segs
