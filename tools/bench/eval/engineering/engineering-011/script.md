# engineering-011 — Pagination for the items list

Synthetic dialogue (no real people). One turn per line: `Name: text`.

Omar: The list endpoint returns everything at once, which is too slow.
Hana: Offset pagination is simple but breaks when items are inserted.
Omar: Cursor pagination is stable. GET slash items with a cursor and a limit.
Hana: Let's use cursor pagination.
Omar: I'll update the client SDK to follow the cursor.
