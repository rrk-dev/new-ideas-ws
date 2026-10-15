# engineering-007 — Login token strategy

Synthetic dialogue (no real people). One turn per line: `Name: text`.

Sam: For login we need to pick between session cookies and JSON web tokens.
Mei: Cookies are easy to revoke. Tokens work better for the mobile apps.
Sam: We'll use short lived tokens with refresh tokens.
Mei: I'll implement the refresh endpoint, POST slash auth slash refresh.
