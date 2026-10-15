# engineering-027 — Editor state management

Synthetic dialogue (no real people). One turn per line: `Name: text`.

Kofi: The editor state is spread across many widgets.
Hana: A single store makes it predictable.
Lena: But a single store re-renders too much unless we use selectors.
Kofi: Single store with selectors.
Hana: I'll move the toolbar state into the store.
Lena: Do we keep undo history in the store too?
