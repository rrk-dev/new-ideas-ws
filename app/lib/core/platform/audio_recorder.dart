/// A finished recording on disk.
///
/// The FND-02 `AudioRecorder` interface (a bare `start()` without a
/// start source) was retired by AUD-01: microphone capture is opened only
/// through `RecordingController.start(StartSource)` (SEC-09), which drives
/// the `CaptureBackend` seam (`features/recording/domain/capture_backend.dart`).
/// See docs/adr/ADR-AUD-01-recording-service.md.
class RecordedAudio {
  const RecordedAudio({
    required this.path,
    required this.duration,
    this.recordingId,
  });

  /// Directory of the recording's chunks, relative to the storage root
  /// (`audio/<recording_id>`).
  final String path;

  /// Recorded audio duration (paused spans excluded), from the sample count.
  final Duration duration;

  /// The `recordings` row id; null for captures without a DB row.
  final String? recordingId;
}
