// Value vocabularies persisted by name (drift `textEnum`). Renaming a value is
// a schema change: add a migration that rewrites stored rows.

/// Lifecycle of a recording (AUD-01/AUD-07).
enum RecordingStatus { recording, inProgress, recorded, failed }

/// Where the audio came from.
enum RecordingSource { mic, imported }

/// Why capture stopped (SEC-09: call interruptions never auto-resume).
enum StopReason { user, callInterruption, maxDuration, silence, lowStorage }

/// Timeline marker kinds.
enum MarkerKind { user, gap, callInterruption, consent }

/// Origin of an extraction profile.
enum ProfileSource { builtin, user, enterprise }

/// How a vault folder is addressed on the platform.
enum VaultPlatform { androidSaf, iosBookmark, appLocal }

/// State of one Markdown export (EXP-06 outbox).
enum ExportStatus { pending, writing, written, failed }

/// Kind of installed model file.
enum ModelType { stt, llm, vad, diarization }
