# engineering-001 — Image thumbnail generation

Synthetic dialogue (no real people). One turn per line: `Name: text`.

Lena: For image thumbnails we either generate them on upload or on demand.
Omar: On upload is fast to serve but wastes storage. On demand saves storage but the first view is slow.
Lena: Let's generate on upload. Omar, can you write the resize worker?
Omar: Sure. Open question is which sizes we keep.
