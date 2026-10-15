import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/transcription/domain/window_planner.dart';

/// 30 s chunks back to back from 0, optionally with a pause before [pauseAt].
List<PlanChunk> _chunks(int n, {int? pauseAt, int pauseMs = 0}) {
  final out = <PlanChunk>[];
  var t = 0;
  for (var i = 0; i < n; i++) {
    if (i == pauseAt) t += pauseMs;
    out.add(
      PlanChunk(seq: i, path: '/a/c$i.wav', startMs: t, endMs: t + 30000),
    );
    t += 30000;
  }
  return out;
}

/// Speech of [len] ms every [every] ms (gap = every − len), from [from].
List<SpeechSpan> _speech(
  int from,
  int to, {
  int len = 4000,
  int every = 5000,
}) => [for (var t = from; t + len <= to; t += every) SpeechSpan(t, t + len)];

void main() {
  group('planWindows', () {
    test('windows hold 30–120 s of audio and are cut only inside silences', () {
      final chunks = _chunks(20); // 10 min
      final speech = _speech(0, 600000);
      final plan = planWindows(chunks: chunks, speech: speech);
      expect(plan.complete, isTrue);
      expect(plan.windows, isNotEmpty);
      for (final w in plan.windows.take(plan.windows.length - 1)) {
        expect(w.audioMs, inInclusiveRange(30000, 120000));
      }
      // Every window edge is a speech-span edge (never mid-word).
      final starts = speech.map((s) => s.startMs).toSet();
      final ends = speech.map((s) => s.endMs).toSet();
      for (final w in plan.windows) {
        expect(starts, contains(w.startMs));
        expect(ends, contains(w.endMs));
      }
      // Windows are consecutive and cover all speech exactly once.
      for (var i = 1; i < plan.windows.length; i++) {
        expect(plan.windows[i].index, i);
        expect(plan.windows[i].startMs, greaterThan(plan.windows[i - 1].endMs));
      }
      final covered = plan.windows.fold<int>(0, (a, w) => a + w.audioMs);
      // 1 s pauses (≤ 2 s) are kept inside windows, so covered ≥ speech.
      expect(covered, greaterThanOrEqualTo(speech.length * 4000));
    });

    test('silences longer than 2 s are removed; shorter ones kept', () {
      final chunks = _chunks(2);
      final plan = planWindows(
        chunks: chunks,
        speech: const [
          SpeechSpan(0, 10000),
          SpeechSpan(11500, 20000), // 1.5 s pause: kept
          SpeechSpan(25000, 40000), // 5 s silence: removed
        ],
      );
      final w = plan.windows.single;
      expect(w.audioMs, 20000 + 15000);
      // Ranges: [0, 20000) of c0; then [25000, 30000) of c0 + [0, 10000) of c1.
      expect(
        w.ranges.map((r) => (r.path, r.fileStartMs, r.fileEndMs)).toList(),
        [
          ('/a/c0.wav', 0, 20000),
          ('/a/c0.wav', 25000, 30000),
          ('/a/c1.wav', 0, 10000),
        ],
      );
      // Range offsets map file ms back to recording ms.
      expect(w.ranges.last.recordingStartMs, 30000);
      expect(w.ranges.last.recordingEndMs, 40000);
    });

    test('a pause between chunks (paused recording) maps to the right file '
        'offsets', () {
      final chunks = _chunks(2, pauseAt: 1, pauseMs: 60000); // c1 at 90 s
      final plan = planWindows(
        chunks: chunks,
        speech: const [SpeechSpan(20000, 30000), SpeechSpan(90000, 115000)],
      );
      final ranges = plan.windows.expand((w) => w.ranges).toList();
      expect(
        ranges.map(
          (r) => (r.path, r.fileStartMs, r.fileEndMs, r.recordingOffsetMs),
        ),
        [('/a/c0.wav', 20000, 30000, 0), ('/a/c1.wav', 0, 25000, 90000)],
      );
    });

    test('continuous speech longer than 120 s is split at the maximum', () {
      final plan = planWindows(
        chunks: _chunks(10),
        speech: const [SpeechSpan(0, 300000)],
      );
      expect(plan.windows.map((w) => w.audioMs), [120000, 120000, 60000]);
    });

    test('no VAD data → windows at chunk boundaries (pre-VAD behaviour)', () {
      final plan = planWindows(chunks: _chunks(3), speech: const []);
      expect(plan.windows, hasLength(3));
      for (final (i, w) in plan.windows.indexed) {
        expect(w.ranges.single.path, '/a/c$i.wav');
        expect(w.audioMs, 30000);
      }
    });

    test('silence only → no windows; empty recording → no windows', () {
      expect(
        planWindows(
          chunks: _chunks(2),
          speech: const [SpeechSpan(500000, 600000)], // outside the audio
        ).windows,
        isEmpty,
      );
      expect(planWindows(chunks: const [], speech: const []).windows, isEmpty);
    });

    test('overlapping/unsorted spans are merged', () {
      final plan = planWindows(
        chunks: _chunks(2),
        speech: const [
          SpeechSpan(20000, 35000),
          SpeechSpan(0, 10000),
          SpeechSpan(5000, 21000),
        ],
      );
      expect(plan.windows.single.ranges.map((r) => r.recordingStartMs), [
        0,
        30000,
      ]);
      expect(plan.windows.single.audioMs, 35000);
    });

    test('horizon plans are a prefix of the complete plan (near-real-time '
        'results can be reused)', () {
      final rnd = Random(7);
      for (var trial = 0; trial < 50; trial++) {
        final speech = <SpeechSpan>[];
        var t = rnd.nextInt(3000);
        while (t < 1200000) {
          final len = 300 + rnd.nextInt(rnd.nextBool() ? 8000 : 40000);
          speech.add(SpeechSpan(t, t + len));
          t += len + 300 + rnd.nextInt(rnd.nextInt(5) == 0 ? 15000 : 2500);
        }
        final chunks = _chunks(41);
        final full = planWindows(chunks: chunks, speech: speech);
        for (final horizon in [60000, 333333, 700000, 1199999]) {
          final known = [
            for (final s in speech)
              if (s.startMs < horizon)
                SpeechSpan(s.startMs, s.endMs < horizon ? s.endMs : horizon),
          ];
          final partial = planWindows(
            chunks: chunks,
            speech: known,
            horizonMs: horizon,
          );
          expect(partial.complete, isFalse);
          expect(
            partial.windows.length,
            lessThanOrEqualTo(full.windows.length),
          );
          for (final w in partial.windows) {
            expect(w, full.windows[w.index], reason: 'trial $trial @ $horizon');
            expect(w.key, full.windows[w.index].key);
            expect(w.endMs + 1000, lessThanOrEqualTo(horizon));
          }
        }
      }
    });

    test('2-hour recording: every window stays bounded (memory per decode '
        'does not grow with length)', () {
      final chunks = _chunks(240); // 2 h of 30 s chunks
      final plan = planWindows(chunks: chunks, speech: _speech(0, 7200000));
      expect(plan.windows.length, greaterThan(60));
      expect(
        plan.windows.map((w) => w.audioMs).reduce(max),
        lessThanOrEqualTo(120000),
      );
      expect(plan.windows.last.endMs, lessThanOrEqualTo(7200000));
    });

    test('sttParamsKey changes with model or language', () {
      expect(sttParamsKey('m', 'en'), sttParamsKey('m', 'en'));
      expect(sttParamsKey('m', 'en'), isNot(sttParamsKey('m', 'de')));
      expect(sttParamsKey('m', 'en'), isNot(sttParamsKey('n', 'en')));
    });
  });
}
