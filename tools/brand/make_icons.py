#!/usr/bin/env python3
"""Generate every Lumen raster icon from the SVG masters in design/brand/ (APP-07).

Reproducible and dependency-light: needs only Pillow. The masters are restricted to
<rect>/<circle> shapes with flat fills (see design/brand/README.md), which this script
rasterises itself with 4x supersampling, so no system graphics library is required.

    python3 -m venv .venv-brand && .venv-brand/bin/pip install pillow
    .venv-brand/bin/python tools/brand/make_icons.py            # write icons
    .venv-brand/bin/python tools/brand/make_icons.py --check    # fail if outputs differ

Outputs: iOS AppIcon / AppIcon-dev / AppIcon-prod (RGB, no alpha), iOS LaunchImage,
macOS AppIcon, Android legacy + adaptive foreground + monochrome mipmaps, and the
flutter_launcher_icons source PNGs in app/assets/icon/.
"""

from __future__ import annotations

import argparse
import io
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
BRAND = ROOT / "design" / "brand"
APP = ROOT / "app"
SS = 4  # supersampling factor
CANVAS = 1024


def _attrs(tag: str) -> dict[str, str]:
    return dict(re.findall(r'([\w-]+)="([^"]*)"', tag))


def _hex(color: str) -> tuple[int, int, int]:
    color = color.lstrip("#")
    return tuple(int(color[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


class Master:
    """Parsed icon master: background colour, waveform bars and the light orb."""

    def __init__(self, path: Path) -> None:
        text = path.read_text(encoding="utf-8")
        self.bg = _hex(_attrs(re.search(r'<rect id="bg"[^>]*>', text).group(0))["fill"])  # type: ignore[union-attr]
        group = re.search(r'<g id="mark" fill="([^"]+)">(.*?)</g>', text, re.S)
        self.bar_color = _hex(group.group(1))  # type: ignore[union-attr]
        self.bars = []
        for tag in re.findall(r"<rect [^>]*/>", group.group(2)):  # type: ignore[union-attr]
            a = _attrs(tag)
            self.bars.append(tuple(float(a[k]) for k in ("x", "y", "width", "height", "rx")))
        orb = _attrs(re.search(r'<circle id="orb"[^>]*>', text).group(0))  # type: ignore[union-attr]
        self.orb = (float(orb["cx"]), float(orb["cy"]), float(orb["r"]))
        self.orb_color = _hex(orb["fill"])


LIGHT = Master(BRAND / "lumen-icon.svg")


def draw_mark(
    draw: ImageDraw.ImageDraw,
    m: Master,
    scale: float,
    dx: float = 0,
    dy: float = 0,
    bars=None,
    orb=None,
) -> None:
    for x, y, w, h, rx in m.bars:
        box = [(x + dx) * scale, (y + dy) * scale, (x + w + dx) * scale, (y + h + dy) * scale]
        draw.rounded_rectangle(box, radius=rx * scale, fill=bars or m.bar_color)
    cx, cy, r = m.orb
    draw.ellipse(
        [(cx + dx - r) * scale, (cy + dy - r) * scale, (cx + dx + r) * scale, (cy + dy + r) * scale],
        fill=orb or m.orb_color,
    )


def _finish(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.LANCZOS)


def tile(size: int, *, radius: float = 0, inset: float = 0, dev: bool = False, alpha: bool = False) -> Image.Image:
    """Icon tile: teal square (rounded when radius>0) with the mark.

    inset is the transparent margin as a fraction of the canvas (macOS grid).
    """
    big = size * SS
    mode = "RGBA" if alpha else "RGB"
    img = Image.new(mode, (big, big), (0, 0, 0, 0) if alpha else LIGHT.bg)
    d = ImageDraw.Draw(img)
    scale = big / CANVAS
    inner = 1 - 2 * inset
    if alpha:
        pad = inset * CANVAS * scale
        d.rounded_rectangle(
            [pad, pad, big - pad, big - pad], radius=radius * inner * scale, fill=LIGHT.bg
        )
    mark = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw_mark(ImageDraw.Draw(mark), LIGHT, scale * inner, dx=(CANVAS * inset) / inner, dy=(CANVAS * inset) / inner)
    img.paste(mark, (0, 0), mark)
    if dev:
        _dev_badge(img, big)
    return _finish(img, size)


def _dev_badge(img: Image.Image, big: int) -> None:
    """Bottom band with a stroked 'DEV' (no font dependency)."""
    d = ImageDraw.Draw(img)
    top = int(big * 0.78)
    d.rectangle([0, top, big, big], fill=(16, 23, 21))
    h = (big - top) * 0.52
    w = h * 0.62
    stroke = max(2, int(h * 0.2))
    gap = w * 0.45
    total = 3 * w + 2 * gap
    x0 = (big - total) / 2
    y0 = top + ((big - top) - h) / 2
    ink = (244, 247, 246)

    def line(points):
        d.line(points, fill=ink, width=stroke, joint="curve")
        for px, py in (points[0], points[-1]):
            d.ellipse([px - stroke / 2, py - stroke / 2, px + stroke / 2, py + stroke / 2], fill=ink)

    # D
    line([(x0, y0), (x0, y0 + h)])
    d.arc([x0 - w * 0.9, y0, x0 + w, y0 + h], -90, 90, fill=ink, width=stroke)
    # E
    xe = x0 + w + gap
    line([(xe + w, y0), (xe, y0), (xe, y0 + h), (xe + w, y0 + h)])
    line([(xe, y0 + h / 2), (xe + w * 0.8, y0 + h / 2)])
    # V
    xv = xe + w + gap
    line([(xv, y0), (xv + w / 2, y0 + h), (xv + w, y0)])


def foreground(size: int, *, mono: bool) -> Image.Image:
    """Adaptive-icon layer: mark centred inside the 66dp safe zone of a 108dp canvas."""
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    black = (0, 0, 0)
    # mark bbox is x 224..800, y 250..810 -> centre (512, 530); shift to canvas centre
    draw_mark(
        ImageDraw.Draw(img),
        LIGHT,
        big / CANVAS,
        dy=-18,
        bars=black if mono else None,
        orb=black if mono else None,
    )
    return _finish(img, size)


def launch_mark(size: int) -> Image.Image:
    """Rounded teal tile; centred on the launch screen's existing background."""
    return tile(size, radius=224, alpha=True)


def png_bytes(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def build() -> dict[Path, bytes]:
    out: dict[Path, bytes] = {}

    def put(path: Path, img: Image.Image) -> None:
        out[path] = png_bytes(img)

    # iOS: full-bleed, RGB (no alpha); the OS applies the corner mask.
    ios = APP / "ios/Runner/Assets.xcassets"
    for name, dev in (("AppIcon", False), ("AppIcon-prod", False), ("AppIcon-dev", True)):
        contents = json.loads((ios / f"{name}.appiconset/Contents.json").read_text())
        cache: dict[int, Image.Image] = {}
        for entry in contents["images"]:
            w = float(entry["size"].split("x")[0])
            px = round(w * int(entry["scale"].rstrip("x")))
            cache.setdefault(px, tile(px, dev=dev))
            put(ios / f"{name}.appiconset" / entry["filename"], cache[px])

    # iOS launch image (168pt @1x/2x/3x).
    for suffix, px in (("", 168), ("@2x", 336), ("@3x", 504)):
        put(ios / f"LaunchImage.imageset/LaunchImage{suffix}.png", launch_mark(px))

    # macOS: rounded tile on the 824/1024 grid with transparent margin.
    mac = APP / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((mac / "Contents.json").read_text())
    for entry in contents["images"]:
        w = float(entry["size"].split("x")[0])
        px = round(w * int(entry["scale"].rstrip("x")))
        put(mac / entry["filename"], tile(px, radius=224, inset=0.0977, alpha=True))

    # flutter_launcher_icons sources (1024, no alpha).
    put(APP / "assets/icon/icon_prod.png", tile(1024))
    put(APP / "assets/icon/icon_dev.png", tile(1024, dev=True))

    # Android: legacy launcher + adaptive layers.
    res = APP / "android/app/src/main/res"
    for density, legacy, layer in (
        ("mdpi", 48, 108),
        ("hdpi", 72, 162),
        ("xhdpi", 96, 216),
        ("xxhdpi", 144, 324),
        ("xxxhdpi", 192, 432),
    ):
        put(res / f"mipmap-{density}/ic_launcher.png", tile(legacy, radius=224, alpha=True))
        put(res / f"mipmap-{density}/ic_launcher_foreground.png", foreground(layer, mono=False))
        put(res / f"mipmap-{density}/ic_launcher_monochrome.png", foreground(layer, mono=True))
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="verify outputs are up to date")
    args = parser.parse_args()
    files = build()
    stale = [p for p, data in files.items() if not p.exists() or p.read_bytes() != data]
    if args.check:
        for p in stale:
            print(f"stale: {p.relative_to(ROOT)}", file=sys.stderr)
        return 1 if stale else 0
    for p in stale:
        p.write_bytes(files[p])
    print(f"wrote {len(stale)} of {len(files)} icon files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
