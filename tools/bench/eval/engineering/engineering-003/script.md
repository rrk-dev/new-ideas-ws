# engineering-003 — Search performance

Synthetic dialogue (no real people). One turn per line: `Name: text`.

Mei: The search page is slow because every request hits the database.
Diego: We could add a Redis cache in front of the search queries.
Aisha: A cache is fast but invalidation gets tricky when documents change.
Mei: Alternatively we build a search index with incremental updates.
Diego: The index is more work but stays consistent.
Aisha: Let's prototype the cache first and measure.
Mei: I'll set up the cache prototype this week.
