import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String text) =>
    text.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');

String _read(String rel) => File(rel).readAsStringSync();

String _swiftCode(String rel) => _code(_read(rel));

List<File> _swift(String dir) =>
    Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.swift'))
        .toList();

void main() {
  final extensionSources = [
    ..._swift('ios/LumenWidgets'),
    ..._swift('ios/QuickCaptureShared'),
  ];

  test('[QCP-02/AC1] the widget and control only open the Record screen', () {
    final widget = _read('ios/LumenWidgets/RecordWidget.swift');
    final control = _read('ios/LumenWidgets/RecordControl.swift');
    final intent = _read('ios/QuickCaptureShared/OpenRecordScreenIntent.swift');
    expect(widget, contains('lumen://record?entry=widget'));
    expect(control, contains('OpenRecordScreenIntent()'));
    expect(intent, contains('submit(entry: .iosControl)'));
    for (final src in [widget, control, intent]) {
      expect(src, isNot(contains('AVAudio')));
      expect(src, isNot(contains('startRecording')));
    }
  });

  test('[QCP-02/AC2] the native store is in-memory, single-use, 10 s', () {
    final store = _swiftCode('ios/QuickCaptureShared/QuickCaptureStore.swift');
    expect(store, contains('ttl'));
    expect(store, contains('= 10'));
    expect(store, isNot(contains('UserDefaults')));
    expect(store, isNot(contains('FileManager')));
  });

  test('[QCP-02/AC3] no start-now, Shortcuts or Action Button entry point', () {
    for (final f in extensionSources) {
      final s = _code(f.readAsStringSync());
      expect(s, isNot(contains('AppShortcutsProvider')), reason: f.path);
      expect(s, isNot(contains('StartRecording')), reason: f.path);
    }
  });

  test('[QCP-02/AC4] extension sources never touch call or audio APIs', () {
    for (final f in extensionSources) {
      final s = _code(f.readAsStringSync());
      for (final banned in ['CallKit', 'CXCall', 'AVAudio', 'AVFoundation']) {
        expect(s, isNot(contains(banned)), reason: '${f.path} $banned');
      }
    }
  });

  test('[QCP-02/AC5] widget surfaces show only static strings', () {
    for (final f in extensionSources) {
      final s = _code(f.readAsStringSync());
      for (final banned in [
        'UserDefaults',
        'FileManager',
        'containerURL',
        'AppGroup',
        'sqlite',
        'URLSession',
        r'\(',
      ]) {
        expect(s, isNot(contains(banned)), reason: '${f.path} $banned');
      }
    }
    final widget = _swiftCode('ios/LumenWidgets/RecordWidget.swift');
    final textArgs = RegExp(r'(?:Text|Label)\(\s*([^,)\s]+)')
        .allMatches(widget);
    expect(textArgs, isNotEmpty);
    for (final m in textArgs) {
      expect(m.group(1), startsWith('LumenWidgetContent.'));
    }
  });

  test(
    '[QCP-02/AC6] Info.plist, entitlements and project add no capability',
    () {
      final ext = _read('ios/LumenWidgets/Info.plist');
      expect(ext, isNot(contains('UsageDescription')));
      expect(ext, isNot(contains('UIBackgroundModes')));
      expect(ext, isNot(contains('NSAppTransportSecurity')));
      expect(ext, contains('com.apple.widgetkit-extension'));

      final runner = _read('ios/Runner/Info.plist');
      expect(
        RegExp(
          r'<key>UIBackgroundModes</key>\s*<array>\s*<string>audio</string>'
          r'\s*<string>processing</string>\s*</array>',
        ).hasMatch(runner),
        isTrue,
      );
      expect(
        RegExp(
          r'<key>CFBundleURLSchemes</key>\s*<array>\s*<string>lumen</string>'
          r'\s*</array>',
        ).hasMatch(runner),
        isTrue,
      );
      expect(
        RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<false/>')
            .hasMatch(runner),
        isTrue,
      );

      final ents = _read('ios/Runner/Runner.entitlements');
      expect(ents, isNot(contains('application-groups')));
      expect(
        Directory('ios/LumenWidgets').listSync().map((e) => e.path),
        isNot(anyElement(endsWith('.entitlements'))),
      );

      final pbx = _read('ios/Runner.xcodeproj/project.pbxproj');
      expect(pbx, contains('LumenWidgets'));
      expect(pbx, isNot(contains('application-groups')));

      final policy = _read('../tools/ci/check_recording_policy.py');
      expect(policy, contains('app/ios/LumenWidgets'));
      expect(policy, contains('app/ios/QuickCaptureShared'));
    },
  );
}
