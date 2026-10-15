#!/usr/bin/env python3
"""Writes the small WAV and GGUF seed corpora (synthetic silence, no audio of people)."""
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parent / "corpus" / "wav"


def wav(channels=1, rate=16000, bits=16, frames=160, tag=1, data_len=None, extra=b""):
    data = b"\x00" * (frames * channels * bits // 8)
    fmt = struct.pack("<HHIIHH", tag, channels, rate, rate * channels * bits // 8,
                      channels * bits // 8, bits)
    body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + extra
    body += b"data" + struct.pack("<I", len(data) if data_len is None else data_len) + data
    return b"RIFF" + struct.pack("<I", len(body)) + body


def gguf(n_kv=1):
    """Minimal GGUF v3: no tensors, n_kv entries of a uint32 key."""
    blob = b"GGUF" + struct.pack("<IQQ", 3, 0, n_kv)
    for i in range(n_kv):
        key = f"k{i}".encode()
        blob += struct.pack("<Q", len(key)) + key + struct.pack("<II", 4, 7)
    return blob


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    gdir = OUT.parent / "gguf"
    gdir.mkdir(parents=True, exist_ok=True)
    (gdir / "minimal.gguf").write_bytes(gguf())
    (gdir / "no_kv.gguf").write_bytes(gguf(0))
    (gdir / "huge_count.gguf").write_bytes(b"GGUF" + struct.pack("<IQQ", 3, 1 << 62, 1 << 62))
    seeds = {
        "mono16k.wav": wav(),
        "stereo16k.wav": wav(channels=2),
        "stale_length.wav": wav(data_len=0xFFFFFFFF),
        "wrong_rate.wav": wav(rate=44100),
        "list_chunk.wav": wav(extra=b"LIST" + struct.pack("<I", 4) + b"abcd"),
        "truncated.wav": wav()[:30],
    }
    for name, blob in seeds.items():
        (OUT / name).write_bytes(blob)


if __name__ == "__main__":
    main()
