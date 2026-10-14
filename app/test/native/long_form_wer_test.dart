@TestOn('mac-os || linux')
@Timeout(Duration(minutes: 10))
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/features/recording/domain/wav_header.dart';
import 'package:vaultvoice/features/transcription/data/whisper_stt_engine.dart';
import 'package:vaultvoice/features/transcription/domain/hallucination_guards.dart';
import 'package:vaultvoice/features/transcription/domain/window_planner.dart';
import 'package:vv_native/vv_native.dart';

/// STT-04 AC2 on the host build: the long-form path (30–120 s VAD windows
/// over 30 s chunk files, `vv_stt_transcribe_ranges`, prompt carry, guards)
/// must stay within 1 WER point of transcribing every clip on its own.
///
/// Needs `native/build.sh host`, a model (`VV_STT04_MODEL`, default
/// `ggml-base.en-q5_1.bin` from the bench cache, else `ggml-tiny.en.bin`
/// from the test models) and the STT-07 TTS corpus
/// (`tools/bench/stt_variants/make_corpus.sh`, macOS). Skipped otherwise.
String? _hostLib() {
  final fromEnv = Platform.environment['VV_NATIVE_LIB'];
  if (fromEnv != null) return fromEnv;
  final ext = Platform.isMacOS ? 'dylib' : 'so';
  final f = File('../native/build/host/libvv_native.$ext');
  return f.existsSync() ? f.absolute.path : null;
}

final String _home = Platform.environment['HOME'] ?? '';
final String _bench =
    Platform.environment['VV_BENCH_MODELS_DIR'] ??
    '$_home/.cache/vaultvoice/bench';

String? _model() {
  for (final m in [
    Platform.environment['VV_STT04_MODEL'],
    '$_bench/ggml-base.en-q5_1.bin',
    '${Platform.environment['VV_TEST_MODELS_DIR'] ?? '$_home/.cache/vaultvoice/test-models'}/ggml-tiny.en.bin',
  ]) {
    if (m != null && File(m).existsSync()) return m;
  }
  return null;
}

const _clips = [
  'en-meeting-1',
  'en-meeting-2',
  'en-warranty-1',
  'en-engineering-1',
  'en-notes-1',
];

Int16List _pcm(String path) {
  final b = File(path).readAsBytesSync();
  final view = ByteData.sublistView(b);
  var pos = 12;
  while (pos + 8 <= b.length) {
    final id = String.fromCharCodes(b.sublist(pos, pos + 4));
    final len = view.getUint32(pos + 4, Endian.little);
    if (id == 'data') {
      final data = Uint8List.fromList(b.sublist(pos + 8, pos + 8 + len));
      return data.buffer.asInt16List();
    }
    pos += 8 + len + (len & 1);
  }
  throw StateError('no data chunk');
}

void _writeWav(File f, Int16List pcm) => f.writeAsBytesSync([
  ...WavHeader.build(dataBytes: pcm.length * 2),
  ...pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.length * 2),
]);

/// Minimal energy VAD (test-only stand-in for AUD-03): 30 ms frames,
/// speech when RMS > 1 % FS; gaps < 300 ms merged; 100 ms padding.
List<SpeechSpan> _energyVad(Int16List pcm) {
  const frame = 480;
  final spans = <SpeechSpan>[];
  int? start;
  for (var i = 0; i + frame <= pcm.length; i += frame) {
    var sum = 0.0;
    for (var j = i; j < i + frame; j++) {
      sum += pcm[j] * pcm[j];
    }
    final speech = sqrt(sum / frame) / 32768 > 0.01;
    final ms = i ~/ 16;
    if (speech && start == null) start = ms;
    if (!speech && start != null) {
      spans.add(SpeechSpan(start, ms));
      start = null;
    }
  }
  if (start != null) spans.add(SpeechSpan(start, pcm.length ~/ 16));
  final merged = <SpeechSpan>[];
  for (final s in spans) {
    if (merged.isNotEmpty && s.startMs - merged.last.endMs < 300) {
      merged.add(SpeechSpan(merged.removeLast().startMs, s.endMs));
    } else {
      merged.add(s);
    }
  }
  final total = pcm.length ~/ 16;
  return [
    for (final s in merged)
      SpeechSpan(max(0, s.startMs - 100), min(total, s.endMs + 100)),
  ];
}

List<String> _norm(String t) => t
    .toLowerCase()
    .replaceAll('’', "'")
    .replaceAll(RegExp(r"(?<!\w)'|'(?!\w)"), ' ')
    .replaceAll(RegExp(r"[^\w\s']|_"), ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toList();

/// Word edit distance (same normalization as vv-benchmark-eval/wer.py).
int _edits(List<String> r, List<String> h) {
  var prev = List<int>.generate(h.length + 1, (j) => j);
  for (var i = 1; i <= r.length; i++) {
    final cur = List<int>.filled(h.length + 1, 0)..[0] = i;
    for (var j = 1; j <= h.length; j++) {
      cur[j] = r[i - 1] == h[j - 1]
          ? prev[j - 1]
          : 1 + min(prev[j - 1], min(prev[j], cur[j - 1]));
    }
    prev = cur;
  }
  return prev[h.length];
}

void main() {
  final lib = _hostLib();
  final model = _model();
  final corpus = Directory('$_bench/corpus');
  final haveCorpus = _clips.every(
    (c) => File('${corpus.path}/$c.wav').existsSync(),
  );
  final skip = lib == null
      ? 'run native/build.sh host first'
      : model == null
      ? 'no whisper model in the bench/test-model cache'
      : !haveCorpus
      ? 'run tools/bench/stt_variants/make_corpus.sh (macOS)'
      : null;

  test('[STT-04/AC2] stitched long-form WER within 1 pt of per-clip WER', () async {
    VvNative.open(hostPath: lib).loadBackends(gpuMask: VV_GPU_METAL);
    final tmp = Directory.systemTemp.createTempSync('vv_stt04_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final engine = WhisperSttEngine(
      modelId: 'stt04',
      modelPath: () async => model,
      hostLibPath: lib,
    );
    addTearDown(engine.unload);

    // Per clip.
    final refs = <String>[];
    var perClipEdits = 0;
    var words = 0;
    final pcms = <Int16List>[];
    for (final c in _clips) {
      final ref = File('${corpus.path}/$c.txt').readAsStringSync();
      refs.add(ref);
      final hyp = (await engine.transcribe('${corpus.path}/$c.wav'))
          .valueOrNull!
          .text;
      perClipEdits += _edits(_norm(ref), _norm(hyp));
      words += _norm(ref).length;
      pcms.add(_pcm('${corpus.path}/$c.wav'));
    }
    final perClipWer = perClipEdits / words;

    // One "recording": clips separated by 2.5 s of silence, cut into 30 s
    // chunk files exactly like the recorder does (mid-word cuts included).
    final gap = Int16List(2500 * 16);
    final all = <int>[];
    for (final p in pcms) {
      all
        ..addAll(p)
        ..addAll(gap);
    }
    final stream = Int16List.fromList(all);
    const chunkSamples = 30000 * 16;
    final chunks = <PlanChunk>[];
    for (var s = 0, i = 0; s < stream.length; s += chunkSamples, i++) {
      final e = min(stream.length, s + chunkSamples);
      final f = File('${tmp.path}/chunk_$i.wav');
      _writeWav(f, Int16List.sublistView(stream, s, e));
      chunks.add(
        PlanChunk(seq: i, path: f.path, startMs: s ~/ 16, endMs: e ~/ 16),
      );
    }
    final plan = planWindows(chunks: chunks, speech: _energyVad(stream));
    expect(plan.windows.length, greaterThan(1));
    expect(
      plan.windows.any((w) => w.ranges.map((r) => r.path).toSet().length > 1),
      isTrue,
      reason: 'some window must span a chunk boundary',
    );

    final out = <String>[];
    String? previous;
    var lastEnd = -1;
    for (final w in plan.windows) {
      final r = await engine.transcribeRanges(
        [
          for (final x in w.ranges)
            SttAudioRange(
              path: x.path,
              startMs: x.fileStartMs,
              endMs: x.fileEndMs,
              recordingOffsetMs: x.recordingOffsetMs,
            ),
        ],
        options: SttOptions(initialPrompt: carryPrompt(previousText: previous)),
      );
      final kept = applyGuards(
        r.valueOrNull!.segments,
        previous: previous,
      ).kept;
      for (final s in kept) {
        // Recording-timeline mapping: inside the window, monotonic.
        expect(s.start.inMilliseconds, greaterThanOrEqualTo(w.startMs - 50));
        expect(s.end.inMilliseconds, lessThanOrEqualTo(w.endMs + 50));
        expect(s.start.inMilliseconds, greaterThanOrEqualTo(lastEnd - 1000));
        lastEnd = s.end.inMilliseconds;
      }
      out.addAll(kept.map((s) => s.text));
      if (kept.isNotEmpty) previous = kept.map((s) => s.text).join(' ');
    }
    final stitchedWer =
        _edits(_norm(refs.join(' ')), _norm(out.join(' '))) / words;
    // Visible in the test log for the Completion Notes.
    // ignore: avoid_print
    print(
      'STT-04/AC2 model=${model!.split('/').last} windows=${plan.windows.length} '
      'perClipWER=${(perClipWer * 100).toStringAsFixed(2)}% '
      'stitchedWER=${(stitchedWer * 100).toStringAsFixed(2)}%',
    );
    expect(stitchedWer, lessThanOrEqualTo(perClipWer + 0.01));
  }, skip: skip);
}
