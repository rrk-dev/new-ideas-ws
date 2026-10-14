import 'dart:async';
import 'dart:typed_data';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/recording/domain/audio_format.dart';
import 'package:vaultvoice/features/recording/domain/pcm_mic_source.dart';
import 'package:vaultvoice/features/recording/domain/storage_policy.dart';

/// Scriptable microphone: tests push PCM with [emit]; [micOpen] models the
/// OS input being open (no audio exists while it is closed).
class FakePcmMicSource implements PcmMicSource {
  bool permission = true;
  bool micOpen = false;
  int opens = 0;
  int permissionRequests = 0;
  Failure? openFailure;
  final requests = <MicRequest>[];
  List<AudioInputDevice> devices = const [
    AudioInputDevice(id: 'builtin', label: 'iPhone Microphone'),
  ];

  StreamController<MicEvent>? _events;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    if (request) permissionRequests++;
    return permission;
  }

  @override
  Future<Result<List<AudioInputDevice>>> inputDevices() async => Ok(devices);

  @override
  Future<Result<Stream<MicEvent>>> open(MicRequest request) async {
    opens++;
    requests.add(request);
    if (openFailure case final f?) return Err(f);
    micOpen = true;
    final c = StreamController<MicEvent>(sync: true);
    _events = c;
    return Ok(c.stream);
  }

  @override
  Future<void> close() async {
    micOpen = false;
    final c = _events;
    _events = null;
    await c?.close();
  }

  /// Delivers [pcm] as captured at [at]. Throws if the mic is closed: a
  /// closed OS input cannot produce audio.
  void emit(Uint8List pcm, DateTime at) {
    if (!micOpen) throw StateError('microphone is closed');
    _events!.add(MicData(pcm, at));
  }

  /// Delivers any other event (format change, interruption, failure).
  void emitEvent(MicEvent event) => _events!.add(event);
}

/// Scriptable free-space probe.
class FakeDiskSpaceProbe implements DiskSpaceProbe {
  FakeDiskSpaceProbe([this.free = 10 * 1024 * 1024 * 1024]);

  /// Free bytes; null = unknown (probe error).
  int? free;
  int queries = 0;

  @override
  Future<Result<int>> freeBytes(String path) async {
    queries++;
    final f = free;
    return f == null ? const Err(StorageFailure('unknown')) : Ok(f);
  }
}

/// PCM16 mono helpers for tests.
abstract final class Pcm {
  /// [n] samples of `value(i)` (index from [start]) as PCM16 LE.
  static Uint8List of(int n, int Function(int i) value, {int start = 0}) {
    final b = ByteData(n * 2);
    for (var i = 0; i < n; i++) {
      b.setInt16(i * 2, value(start + i).clamp(-32768, 32767), Endian.little);
    }
    return b.buffer.asUint8List();
  }

  /// A ramp that encodes the absolute sample index (mod 2^15) — every sample
  /// is distinguishable, so drops/duplicates are detectable.
  static Uint8List counter(int n, {int start = 0}) =>
      of(n, (i) => i % 30000, start: start);

  /// Samples of PCM16 LE [bytes].
  static List<int> samples(Uint8List bytes) {
    final v = ByteData.sublistView(bytes);
    return [
      for (var i = 0; i + 1 < bytes.length; i += 2)
        v.getInt16(i, Endian.little),
    ];
  }

  /// Samples in [d] at 16 kHz.
  static int n(Duration d) => AudioFormat.samplesFor(d);
}
