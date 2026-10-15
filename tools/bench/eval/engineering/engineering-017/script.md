# engineering-017 — Notification system design

Synthetic dialogue (no real people). One turn per line: `Name: text`.

Mei: Let's design the notification system.
Ravi: We need push notifications, email and in-app messages.
Mei: One notification service with channels as plugins.
Ravi: The service exposes POST slash notifications with a user id, a channel and a message.
Mei: Plugins keep channels separate, but we need a common retry policy.
Ravi: Let's use exponential backoff for all channels.
Mei: Agreed. I'll write the plugin interface.
Ravi: I'll build the email channel first.
Mei: What about user preferences for quiet hours?
Ravi: Good point, we haven't decided.
