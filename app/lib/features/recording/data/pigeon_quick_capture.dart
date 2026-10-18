import 'package:vaultvoice/features/recording/data/pigeon/quick_capture_api.g.dart';
import 'package:vaultvoice/features/recording/domain/quick_capture_handoff.dart';

/// [QuickCaptureSource] backed by the Pigeon `QuickCaptureHostApi`
/// (`ios/Runner/QuickCaptureHostApiImpl.swift`, in-memory store). Platforms
/// without the host API (macOS, Android, tests) throw, which the hand-off
/// treats as "nothing pending".
class PigeonQuickCapture implements QuickCaptureSource {
  PigeonQuickCapture({QuickCaptureHostApi? api})
    : _api = api ?? QuickCaptureHostApi();

  final QuickCaptureHostApi _api;

  @override
  Future<QuickCaptureMessage?> consumeRequest() async {
    final m = await _api.consumeRequest();
    if (m == null) return null;
    return QuickCaptureMessage(
      id: m.id,
      entry: m.entry,
      mode: m.mode,
      remainingMs: m.remainingMs,
    );
  }
}
