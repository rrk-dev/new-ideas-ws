#!/usr/bin/env python3
"""Write synthetic Play listing graphics and a silent demo WAV (REL-05).

Solid brand-color PNGs (no photographs, no people). A short 16 kHz mono
silence WAV for App Review import. Stdlib only.
"""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Matches AppColors.seed (0xFF3F51B5).
BRAND = (0x3F, 0x51, 0xB5)
IMAGES = ROOT / "app/android/fastlane/metadata/android/en-US/images"
WAV = ROOT / "app/test/fixtures/audio/store_demo_silence.wav"


def _chunk(tag: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)


def write_png(path: Path, width: int, height: int, rgb: tuple[int, int, int]) -> None:
    raw = b"".join(b"\x00" + bytes(rgb) * width for _ in range(height))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", zlib.compress(raw, 9))
        + _chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def write_silence_wav(path: Path, seconds: float = 0.5, rate: int = 16000) -> None:
    n = int(rate * seconds)
    data = b"\x00\x00" * n
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as fh:
        fh.write(b"RIFF")
        fh.write(struct.pack("<I", 36 + len(data)))
        fh.write(b"WAVEfmt ")
        fh.write(struct.pack("<IHHIIHH", 16, 1, 1, rate, rate * 2, 2, 16))
        fh.write(b"data")
        fh.write(struct.pack("<I", len(data)))
        fh.write(data)


def main() -> None:
    write_png(IMAGES / "featureGraphic.png", 1024, 500, BRAND)
    write_png(IMAGES / "icon.png", 512, 512, BRAND)
    write_silence_wav(WAV)
    print(f"wrote {IMAGES / 'featureGraphic.png'}")
    print(f"wrote {IMAGES / 'icon.png'}")
    print(f"wrote {WAV}")


if __name__ == "__main__":
    main()
