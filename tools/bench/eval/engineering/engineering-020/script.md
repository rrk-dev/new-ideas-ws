# engineering-020 — Order shipped webhooks

Synthetic dialogue (no real people). One turn per line: `Name: text`.

Nadia: Partners want webhooks when an order ships.
Sam: We expose POST slash webhooks to register a URL, and DELETE slash webhooks slash id to remove it.
Nadia: We should sign each payload with a shared secret.
Sam: Agreed, payloads are signed.
Nadia: I'll document the signature format.
