import 'dart:async';

import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/transcription/data/window_result_cache.dart';
import 'package:vaultvoice/features/transcription/domain/hallucination_guards.dart';
import 'package:vaultvoice/features/transcription/domain/window_planner.dart';

/// Whether near-real-time transcription may run while recording
/// (vv-whisper-stt → Long-form windowing §4): only when the user enabled it,
/// the device tier is at least Mid, and the phone is charging or above 50 %
/// battery.
///
/// PRODUCT-DECISION: the setting defaults to off (battery/thermal cost
/// while recording); the user opts in under Settings → Processing.
bool nearRealTimeAllowed({
  required bool enabled,
  required DeviceTier tier,
  required bool charging,
  required int batteryPercent,
}) => enabled && tier != DeviceTier.low && (charging || batteryPercent > 50);

/// GPU for live windows: never while the app is in the background on iOS
/// (no Metal in background — vv-background-execution); otherwise whatever
/// the shared backend policy allows.
bool liveUseGpu({
  required bool isIos,
  required bool inForeground,
  required bool policyAllowsGpu,
}) => policyAllowsGpu && (inForeground || !isIos);

/// Transcribes the final windows of a recording **while it is still being
/// recorded** (STT-04 near-real-time mode), so the transcript is ready
/// shortly after the user stops. Results go to [cache]; the pipeline's
/// transcribe step reuses every window whose audio and decode parameters
/// match and only decodes the rest (normally just the last window).
///
/// Never starts or extends a recording (SEC-09) — it only reads chunks the
/// recorder already finalized. [canRun] must return false while another
/// heavy model is loaded (STT and LLM are never resident together) or the
/// policy ([nearRealTimeAllowed]) stops holding.
class LiveTranscriber {
  LiveTranscriber({
    required this.recordingId,
    required this.engine,
    required this.cache,
    required this.modelId,
    required this.language,
    this.config = const WindowPlanConfig(),
    bool Function()? canRun,
  }) : canRun = canRun ?? _yes;

  static bool _yes() => true;

  final String recordingId;
  final WindowedSttEngine engine;
  final WindowResultCache cache;
  final String modelId;
  final String language;
  final WindowPlanConfig config;
  final bool Function() canRun;

  final _done = <String>{};
  String? _previous;
  Future<int> _queue = Future.value(0);

  /// Windows transcribed so far (keys).
  Set<String> get transcribed => Set.unmodifiable(_done);

  /// New audio/VAD is on disk up to [horizonMs]: transcribe every window
  /// that became final. Calls are serialized. Returns the number of windows
  /// decoded by this call.
  Future<int> update({
    required List<PlanChunk> chunks,
    required List<SpeechSpan> speech,
    required int horizonMs,
    CancelToken? cancel,
  }) {
    final run = _queue.then((_) => _update(chunks, speech, horizonMs, cancel));
    _queue = run.then((n) => n, onError: (_) => 0);
    return run;
  }

  Future<int> _update(
    List<PlanChunk> chunks,
    List<SpeechSpan> speech,
    int horizonMs,
    CancelToken? cancel,
  ) async {
    final plan = planWindows(
      chunks: chunks,
      speech: speech,
      config: config,
      horizonMs: horizonMs,
    );
    final key = sttParamsKey(modelId, language);
    var decoded = 0;
    for (final w in plan.windows) {
      if (_done.contains(w.key)) continue;
      if ((cancel?.isCancelled ?? false) || !canRun()) break;
      final cached = await cache.lookup(recordingId, w.key, key);
      if (cached != null) {
        _done.add(w.key);
        continue;
      }
      final result = await engine.transcribeRanges(
        [
          for (final r in w.ranges)
            SttAudioRange(
              path: r.path,
              startMs: r.fileStartMs,
              endMs: r.fileEndMs,
              recordingOffsetMs: r.recordingOffsetMs,
            ),
        ],
        cancel: cancel,
        options: SttOptions(
          language: language,
          initialPrompt: carryPrompt(previousText: _previous),
        ),
      );
      switch (result) {
        case Err():
          // Leave it to the pipeline job (it retries/reports properly).
          return decoded;
        case Ok(value: final transcript):
          await cache.store(recordingId, w.key, key, transcript.segments);
          _done.add(w.key);
          decoded++;
          final kept = applyGuards(transcript.segments).kept;
          if (kept.isNotEmpty) _previous = kept.map((s) => s.text).join(' ');
      }
    }
    return decoded;
  }
}
