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
}
