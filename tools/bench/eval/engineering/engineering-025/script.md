# engineering-025 — Public API versioning

Synthetic dialogue (no real people). One turn per line: `Name: text`.

Sam: How do we version the public API?
Aisha: Version in the URL, like slash v2 slash orders, is explicit.
Sam: A header is cleaner but harder to test in a browser.
Aisha: URL versioning then.
Sam: I'll add the v2 prefix to the router.
