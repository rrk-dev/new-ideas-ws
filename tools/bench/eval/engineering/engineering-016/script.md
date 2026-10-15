# engineering-016 — API rate limiting

Synthetic dialogue (no real people). One turn per line: `Name: text`.

Sam: Some clients send too many requests.
Hana: A token bucket per API key would limit bursts fairly.
Omar: A fixed window is simpler but allows spikes at the window edge.
Sam: Token bucket it is.
Hana: I'll implement the token bucket middleware.
