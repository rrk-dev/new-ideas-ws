# engineering-009 — Background email sending

Synthetic dialogue (no real people). One turn per line: `Name: text`.

Nadia: Email sending blocks the request thread right now.
Tomas: We should move it to a background job queue.
Kofi: A queue adds retries for free, but we need to monitor it.
Nadia: Agreed, we move email sending to a job queue.
Tomas: I'll add a dead letter queue for failed jobs.
Kofi: How many retries before a job goes to the dead letter queue?
