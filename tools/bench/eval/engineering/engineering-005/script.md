# engineering-005 — Streaming CSV importer

Synthetic dialogue (no real people). One turn per line: `Name: text`.

Kofi: Idea for the importer: stream the CSV file instead of loading it into memory.
Kofi: That way large files don't crash the app.
Kofi: To do: benchmark streaming with a one gigabyte file.
