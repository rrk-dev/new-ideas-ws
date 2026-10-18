import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/core/logging/redaction.dart';

/// Quick-capture hand-off (QCP-02, ADR-QCP-01 → "Single-use hand-off
/// request").
///
/// A widget or Lock Screen control tap only *opens the app on the Record
/// screen*. The native side keeps one in-memory request; this class validates
/// it and asks [QuickCaptureHandoff.navigateToRecord] to navigate. It has no
/// reference to `RecordingController` and cannot express a start: recording
/// begins only with the in-app Record tap (`StartSource.inAppButton`).

/// Which surface issued the request. Routing and labelling only: this is NOT
/// a `StartSource`.
enum QuickCaptureEntry {
  iosWidget,
  iosControl;

  static QuickCaptureEntry? tryParse(String? name) {
    for (final e in values) {
      if (e.name == name) return e;
    }
    return null;
  }
}

/// The only supported mode: open the Record screen.
const quickCaptureModeNavigate = 'navigate';

/// A request lives this long after it was issued.
const quickCaptureTtl = Duration(seconds: 10);

/// How many consumed ids are remembered to reject replays.
const quickCaptureReplayMemory = 16;

/// Wire form of a pending request (native → Dart): static fields only.
class QuickCaptureMessage {
  const QuickCaptureMessage({
    required this.id,
    required this.entry,
    required this.mode,
    required this.remainingMs,
  });

  /// Random 128-bit UUIDv4.
  final String id;
  final String entry;
  final String mode;

  /// Milliseconds left before `expiresAt`, measured by the native monotonic
  /// clock when the request was consumed.
  final int remainingMs;
}

/// Native in-memory store (`ios/Runner/QuickCaptureStore.swift`).
abstract interface class QuickCaptureSource {
  /// Returns the pending request and deletes it atomically; null if none.
  Future<QuickCaptureMessage?> consumeRequest();
}

enum QuickCaptureOutcome {
  none,
  navigated,
  malformed,
  expired,
  replayed;

  bool get isDropped =>
      this == malformed || this == expired || this == replayed;
}

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

class QuickCaptureHandoff {
  QuickCaptureHandoff({
    required this.source,
    required this.navigateToRecord,
    this.logger,
  });

  final QuickCaptureSource source;

  /// Opens the Record screen. Must not start a recording.
  final void Function(QuickCaptureEntry entry) navigateToRecord;
  final Logger? logger;

  final List<String> _consumed = [];

  /// Consumes at most one request. Never throws.
  Future<QuickCaptureOutcome> consume() async {
    final QuickCaptureMessage? message;
    try {
      message = await source.consumeRequest();
    } on Object {
      // No native store (macOS, tests without a fake): nothing to consume.
      return QuickCaptureOutcome.none;
    }
    if (message == null) return QuickCaptureOutcome.none;
    final outcome = _validate(message);
    if (outcome == QuickCaptureOutcome.navigated) {
      _consumed.add(message.id.toLowerCase());
      if (_consumed.length > quickCaptureReplayMemory) _consumed.removeAt(0);
      navigateToRecord(QuickCaptureEntry.tryParse(message.entry)!);
    } else {
      logger?.warning(
        'quickcapture',
        'hand-off dropped',
        fields: {'reason': LogId(outcome.name)},
      );
    }
    return outcome;
  }

  QuickCaptureOutcome _validate(QuickCaptureMessage m) {
    if (!_uuidV4.hasMatch(m.id) ||
        QuickCaptureEntry.tryParse(m.entry) == null ||
        m.mode != quickCaptureModeNavigate ||
        m.remainingMs > quickCaptureTtl.inMilliseconds) {
      return QuickCaptureOutcome.malformed;
    }
    if (m.remainingMs <= 0) return QuickCaptureOutcome.expired;
    if (_consumed.contains(m.id.toLowerCase())) {
      return QuickCaptureOutcome.replayed;
    }
    return QuickCaptureOutcome.navigated;
  }
}
