import 'package:vaultvoice/core/errors/result.dart';

/// Free-space thresholds for recording (`vv-audio-capture` → Recording):
/// refuse to start below [minFreeToStart], warn below [warnBelow], and stop
/// + finalize below [stopBelow]. 1 h of 16 kHz PCM16 mono ≈ 115 MB.
final class StoragePolicy {
  const StoragePolicy({
    this.minFreeToStart = 200 * mb,
    this.warnBelow = 500 * mb,
    this.stopBelow = 100 * mb,
    this.checkInterval = const Duration(seconds: 30),
  });

  static const int mb = 1024 * 1024;

  final int minFreeToStart;
  final int warnBelow;
  final int stopBelow;

  /// How often free space is re-checked while recording.
  final Duration checkInterval;

  /// Decision before opening the microphone.
  StorageVerdict beforeStart(int freeBytes) {
    if (freeBytes < minFreeToStart) return StorageVerdict.refuse;
    if (freeBytes < warnBelow) return StorageVerdict.warn;
    return StorageVerdict.ok;
  }

  /// Decision while recording.
  StorageVerdict whileRecording(int freeBytes) {
    if (freeBytes < stopBelow) return StorageVerdict.stop;
    if (freeBytes < warnBelow) return StorageVerdict.warn;
    return StorageVerdict.ok;
  }
}

/// Outcome of a free-space check.
enum StorageVerdict { ok, warn, refuse, stop }

/// Reports free bytes on the volume holding app-private storage.
abstract interface class DiskSpaceProbe {
  /// Free bytes available to the app at [path]; [Err] when unknown.
  Future<Result<int>> freeBytes(String path);
}
