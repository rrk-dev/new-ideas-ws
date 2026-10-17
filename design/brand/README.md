# Lumen brand masters (APP-07)

Calm and minimal: soft neutrals and one teal accent. The mark is five rounded voice bars with a
small orb of light.

| Token | Hex | Use |
|---|---|---|
| Teal | `#0F766E` | Icon background, light-theme mark |
| Mint | `#2DD4BF` | Dark-theme mark |
| Paper | `#F6F7F5` | Light background |
| Ink | `#0F1715` | Dark background |
| Mist | `#F4F7F6` | Bars on the teal icon |
| Glow | `#FFF4C9` | Orb on the teal icon |

Files: `lumen-icon.svg` / `lumen-icon-dark.svg` (rounded tile), `lumen-mark-*.svg`, and
`lumen-wordmark-*.svg` (the wordmark text uses a system sans fallback; the app draws it with the
theme font). Masters use only `<rect>`/`<circle>` with flat fills so `tools/brand/make_icons.py`
can rasterise them with Pillow alone. Regenerate all icons:

    python3 -m venv .venv-brand && .venv-brand/bin/pip install pillow
    .venv-brand/bin/python tools/brand/make_icons.py

The in-app mark (`LumenMark`) mirrors this geometry; keep them in sync.
