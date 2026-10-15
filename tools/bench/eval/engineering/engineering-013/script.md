# engineering-013 — Zero downtime schema migration

Synthetic dialogue (no real people). One turn per line: `Name: text`.

Aisha: The migration to the new schema needs downtime.
Diego: We can avoid downtime with expand and contract: add the new column, backfill, then drop the old one.
Aisha: Expand and contract takes three releases though.
Diego: Still worth it. Let's do expand and contract.
Aisha: I'll write the backfill script.
