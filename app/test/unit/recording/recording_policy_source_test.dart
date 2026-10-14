import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over `lib/` backing the SEC-09 code-review checklist
/// (docs/adr/ADR-SEC-09-recording-policy.md → "Review checklist").
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();
  String rel(File f) => f.path.replaceAll(r'\', '/');

  test('[SEC-09/AC4] only RecordingController opens or reopens the '
      'microphone', () {
    final micCall = RegExp(r'\.\s*(openMicrophone|resumeCapture)\s*\(');
    final recorderStart = RegExp(
      r'recorder\w*\s*\.\s*(start|startStream)\s*\(',
      caseSensitive: false,
    );
    final offenders = [
      for (final f in sources)
        if (!rel(f).endsWith('recording/domain/recording_controller.dart') &&
            (micCall.hasMatch(f.readAsStringSync()) ||
                recorderStart.hasMatch(f.readAsStringSync())))
          rel(f),
    ];
    expect(offenders, isEmpty);
  });

  test('[SEC-09/AC4] recordings start only from presentation code (a tap '
      'handler), never from startup, data or domain code', () {
    final startCall = RegExp(r'\.start\(\s*StartSource\.');
    final resumeCall = RegExp(r'\.resume\(\s*ResumeSource\.');
    final offenders = <String>[];
    var presentationCallers = 0;
    for (final f in sources) {
      final text = f.readAsStringSync();
      if (!startCall.hasMatch(text) && !resumeCall.hasMatch(text)) continue;
      if (rel(f).contains('/presentation/')) {
        presentationCallers++;
      } else {
        offenders.add(rel(f));
      }
    }
    expect(offenders, isEmpty);
    // The debug screen's button is the only caller until AUD-08.
    expect(presentationCallers, greaterThanOrEqualTo(1));
    for (final entry in ['lib/bootstrap.dart', 'lib/app.dart']) {
      expect(File(entry).readAsStringSync(), isNot(contains('StartSource')));
    }
  });

  test('[SEC-09/AC4] no timer, lifecycle or stream callback starts a '
      'recording', () {
    // A start must sit in a tap handler: reject start calls inside
    // Timer/Future.delayed/listen/initState/didChangeAppLifecycleState bodies
    // (same-line heuristic + forbidden wiring patterns).
    final indirect = RegExp(
      r'(Timer|Future\.delayed|\.listen|initState|didChangeAppLifecycleState|'
      r'addPostFrameCallback)[^;\n]*\.start\(\s*StartSource\.',
    );
    final offenders = [
      for (final f in sources)
        if (indirect.hasMatch(f.readAsStringSync())) rel(f),
    ];
    expect(offenders, isEmpty);
  });

  test('only RecordMicSource starts the plugin stream, only '
      'RecordCaptureBackend opens a PcmMicSource, and only from '
      'openMicrophone/resumeCapture (AUD-01)', () {
    final streamStart = RegExp(
      r'\.\s*(startStream|start)\s*\(\s*(rec\.)?'
      '(RecordConfig|buildRecordConfig)',
    );
    final pluginStarters = [
      for (final f in sources)
        if (streamStart.hasMatch(f.readAsStringSync())) rel(f),
    ];
    expect(pluginStarters, [
      'lib/features/recording/data/record_mic_source.dart',
    ]);

    final micOpen = RegExp(r'\.open\(\s*(_request\b|(const\s+)?MicRequest\()');
    final micOpeners = [
      for (final f in sources)
        if (micOpen.hasMatch(f.readAsStringSync())) rel(f),
    ];
    expect(micOpeners, [
      'lib/features/recording/data/record_capture_backend.dart',
    ]);

    final backend = File(
      'lib/features/recording/data/record_capture_backend.dart',
    ).readAsStringSync();
    String body(String method) {
      final start = backend.indexOf('> $method(');
      expect(start, isNot(-1), reason: method);
      final end = backend.indexOf('@override', start);
      return backend.substring(start, end == -1 ? backend.length : end);
    }

    final openMic = RegExp(r'\b_openMic\(');
    expect(openMic.allMatches(backend), hasLength(3)); // definition + 2 calls
    expect(openMic.allMatches(body('openMicrophone')), hasLength(1));
    expect(openMic.allMatches(body('resumeCapture')), hasLength(1));
    expect(micOpen.allMatches(backend), hasLength(1));
  });
}
