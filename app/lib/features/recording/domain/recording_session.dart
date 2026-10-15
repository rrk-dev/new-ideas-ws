/// The recording that is open right now (AUD-08): its row id and the
/// recorded time on the recording's own time base (paused spans excluded,
/// from the sample count). Implemented by `RecordCaptureBackend`.
abstract interface class ActiveRecording {
  String? get recordingId;

  Duration get recorded;
}

/// An extraction profile the user can pre-select ([id] null = Auto, PRF-06).
final class ProfileChoice {
  const ProfileChoice({
    required this.id,
    required this.name,
    this.consentRequired = false,
  });

  final String id;
  final String name;

  /// `consent_confirmation: required` (SEC-07): the "everyone present
  /// agrees" confirmation must be given before the microphone opens.
  final bool consentRequired;
}

/// A vault folder the note can go to ([id] null = Auto: routing rules).
final class DestinationChoice {
  const DestinationChoice({required this.id, required this.name});

  final String id;
  final String name;
}

/// What the user picked on the recording screen; null = Auto.
final class RecordingSetup {
  const RecordingSetup({this.profileId, this.destinationId});

  final String? profileId;
  final String? destinationId;

  RecordingSetup copyWith({
    String? Function()? profileId,
    String? Function()? destinationId,
  }) => RecordingSetup(
    profileId: profileId == null ? this.profileId : profileId(),
    destinationId: destinationId == null ? this.destinationId : destinationId(),
  );
}

/// `settings` key holding a recording's chosen destination (vault target
/// id). Read by the pipeline's WriteStep; absent = routing rules / first
/// target. A settings key (not a column) until the next schema migration
/// (follow-up AUD-11).
String recordingDestinationKey(String recordingId) =>
    'recording.destination.$recordingId';
