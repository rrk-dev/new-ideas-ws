import 'package:drift/drift.dart' show Value;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/repositories/recordings_repository.dart';
import 'package:vaultvoice/core/db/repositories/settings_repository.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/recording/domain/recording_session.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';

/// Writes the recording-screen choices of one recording (AUD-08).
/// Content-free logging only — titles and tags are user content.
class RecordingSessionService {
  RecordingSessionService({
    required RecordingsRepository recordings,
    required this._settings,
    this._enqueue,
  }) : _repo = recordings;

  final RecordingsRepository _repo;
  final SettingsRepository _settings;

  /// Queues a recording in the FND-05 pipeline (`PipelineClient.enqueue`).
  final Future<Result<void>> Function(String recordingId, {bool userInitiated})?
  _enqueue;

  /// Called when a recording from the Record screen has stopped: queues it
  /// for processing when `processing.auto_process` is on (default). Returns
  /// whether it was queued; otherwise the screen offers "Process now".
  Future<bool> finish(String recordingId) async {
    final enqueue = _enqueue;
    if (enqueue == null) return false;
    final stored = await _settings.get(AppSettings.autoProcess.key);
    final auto = AppSettings.autoProcess.decode(stored.valueOrNull);
    if (!auto) return false;
    try {
      return await enqueue(recordingId) is Ok;
    } on Object {
      return false;
    }
  }

  /// "Process now": queues the recording at the front of the pipeline.
  Future<bool> processNow(String recordingId) async {
    final enqueue = _enqueue;
    if (enqueue == null) return false;
    try {
      return await enqueue(recordingId, userInitiated: true) is Ok;
    } on Object {
      return false;
    }
  }

  /// Applies the pre-recording choices right after the start: profile
  /// (`recordings.profile_id`), destination, and the consent confirmation
  /// time (SEC-07 hook → `recordings.consent_confirmed_at`).
  Future<Result<void>> applySetup(
    String recordingId,
    RecordingSetup setup, {
    DateTime? consentConfirmedAt,
  }) async {
    final r = await _repo.updateFields(
      recordingId,
      RecordingsCompanion(
        profileId: Value(setup.profileId),
        consentConfirmedAt: consentConfirmedAt == null
            ? const Value.absent()
            : Value(consentConfirmedAt),
      ),
    );
    if (r case Err()) return r;
    return await _setDestination(recordingId, setup.destinationId);
  }

  /// A user bookmark ("important moment") at [at] on the recording's time
  /// base: `markers` row with `kind = user` (surfaced to the LLM prompt).
  Future<Result<int>> addMarker(String recordingId, Duration at) =>
      _repo.addMarker(
        MarkersCompanion.insert(
          recordingId: recordingId,
          atMs: at.inMilliseconds,
          kind: MarkerKind.user,
        ),
      );

  /// Post-recording details: title, tags, and the (possibly changed)
  /// profile/destination. Tags are trimmed, de-duplicated, empty ones
  /// dropped.
  Future<Result<void>> saveDetails(
    String recordingId, {
    required String title,
    required List<String> tags,
    required RecordingSetup setup,
  }) async {
    final cleanTags = <String>[];
    for (final t in tags) {
      final v = t.trim();
      if (v.isNotEmpty && !cleanTags.contains(v)) cleanTags.add(v);
    }
    final r = await _repo.updateFields(
      recordingId,
      RecordingsCompanion(
        title: Value(title.trim()),
        tags: Value(cleanTags),
        profileId: Value(setup.profileId),
      ),
    );
    if (r case Err()) return r;
    return await _setDestination(recordingId, setup.destinationId);
  }

  Future<Result<void>> _setDestination(String id, String? targetId) async =>
      targetId == null
      ? await _settings.remove(recordingDestinationKey(id))
      : await _settings.set(recordingDestinationKey(id), targetId);

  /// Splits a comma-separated tag field.
  static List<String> parseTags(String text) => text.split(',');
}
