import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/recording/domain/quick_capture_handoff.dart';
import 'package:vaultvoice/features/recording/domain/recording_controller.dart';
import 'package:vaultvoice/features/recording/domain/start_source.dart';

import '../../fakes/fake_call_guard.dart';
import '../../fakes/fake_capture_backend.dart';

const _id = '3f2b8c5e-9d41-4a7b-8e6f-0c1d2e3f4a5b';
const _kotlinDir = 'android/app/src/main/kotlin/com/vaultvoice/vaultvoice';

class _Source implements QuickCaptureSource {
  _Source(this._queue);

  final List<QuickCaptureMessage?> _queue;

  @override
  Future<QuickCaptureMessage?> consumeRequest() async =>
      _queue.isEmpty ? null : _queue.removeAt(0);
}

QuickCaptureMessage _msg(String entry, {int remainingMs = 9000}) =>
    QuickCaptureMessage(
      id: _id,
      entry: entry,
      mode: quickCaptureModeNavigate,
      remainingMs: remainingMs,
    );

String _code(String text) => text
    .split('\n')
    .where((l) {
      final t = l.trimLeft();
      return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
    })
    .join('\n');

String _read(String rel) => File(rel).readAsStringSync();

List<File> _quickCaptureKotlin() =>
    Directory('$_kotlinDir/quickcapture')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.kt') && !f.path.endsWith('.g.kt'))
        .toList();

Set<String> _names(String xml, String tag) => RegExp(
  '<$tag\\b[^>]*?android:name="([^"]+)"',
  dotAll: true,
).allMatches(xml).map((m) => m.group(1)!).toSet();

void main() {
  test('[QCP-03/AC2] Android entries only navigate; a recording is never '
      'started and expired, reused or missing requests are dropped', () async {
    final capture = FakeCaptureBackend();
    final controller = RecordingController(
      capture: capture,
      callGuard: FakeCallGuard(),
      clock: const SystemClock(),
      isAppInForeground: () => true,
    );
    for (final entry in ['androidWidget', 'androidTile', 'androidShortcut']) {
      final navigations = <QuickCaptureEntry>[];
      final h = QuickCaptureHandoff(
        source: _Source([
          _msg(entry),
          _msg(entry),
          _msg(entry, remainingMs: 0),
          null,
        ]),
        navigateToRecord: navigations.add,
      );
      expect(await h.consume(), QuickCaptureOutcome.navigated);
      expect(await h.consume(), QuickCaptureOutcome.replayed);
      expect(await h.consume(), QuickCaptureOutcome.expired);
      expect(await h.consume(), QuickCaptureOutcome.none);
      expect(navigations.map((e) => e.name), [entry]);
    }
    expect(controller.state.phase, RecordingPhase.idle);
    expect(capture.calls, isEmpty);
    expect(capture.micOpen, isFalse);
    expect(StartSource.values.map((s) => s.name), [
      'inAppButton',
      'homeScreenWidget',
      'androidQuickSettingsTile',
      'iosControl',
    ], reason: 'no new StartSource for quick capture');
  });

  test('[QCP-03/AC2] the Android entry points never reach the recorder', () {
    for (final f in _quickCaptureKotlin()) {
      final s = _code(f.readAsStringSync());
      for (final banned in [
        'RecordingService',
        'RecordingIndicator',
        'AudioRecord',
        'MediaRecorder',
        'startForeground',
        'startForegroundService',
        'StartSource',
      ]) {
        expect(s, isNot(contains(banned)), reason: '${f.path} $banned');
      }
    }
    final store = _code(_read('$_kotlinDir/quickcapture/QuickCaptureStore.kt'));
    expect(store, contains('TTL_MS = 10_000L'));
    for (final banned in ['SharedPreferences', 'File(', 'openFileOutput']) {
      expect(store, isNot(contains(banned)));
    }
  });

  test('[QCP-03/AC4] the manifest adds only the widget receiver, the tile '
      'service and the shortcut metadata; no new permission', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    expect(_names(manifest, 'receiver'), {
      '.quickcapture.RecordWidgetProvider',
    });
    expect(_names(manifest, 'service'), {
      '.modeldownload.ModelDownloadService',
      '.ProcessingService',
      '.RecordingService',
      '.quickcapture.QuickCaptureTileService',
    });
    expect(_names(manifest, 'activity'), {'.MainActivity'});
    expect(_names(manifest, 'uses-permission'), {
      'android.permission.ACCESS_NETWORK_STATE',
      'android.permission.INTERNET',
      'android.permission.FOREGROUND_SERVICE',
      'android.permission.FOREGROUND_SERVICE_DATA_SYNC',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.RECORD_AUDIO',
      'android.permission.FOREGROUND_SERVICE_MICROPHONE',
      'android.permission.FOREGROUND_SERVICE_MEDIA_PROCESSING',
      'android.permission.USE_BIOMETRIC',
    });
    expect(
      RegExp('foregroundServiceType="([^"]+)"')
          .allMatches(manifest)
          .map((m) => m.group(1))
          .toList(),
      ['dataSync', 'dataSync|mediaProcessing', 'microphone'],
    );
    final receiver = RegExp(
      '<receiver.*?</receiver>',
      dotAll: true,
    ).firstMatch(manifest)!.group(0)!;
    expect(receiver, contains('android:exported="false"'));
    final tile = RegExp(
      '<service[^>]*QuickCaptureTileService.*?</service>',
      dotAll: true,
    ).firstMatch(manifest)!.group(0)!;
    expect(tile, contains('android.permission.BIND_QUICK_SETTINGS_TILE'));
    expect(tile, isNot(contains('foregroundServiceType')));
    expect(manifest, contains('android.app.shortcuts'));
    for (final flavor in ['dev', 'prod']) {
      final shortcuts = _read('android/app/src/$flavor/res/xml/shortcuts.xml');
      expect(shortcuts, contains('androidShortcut'));
      expect(shortcuts, contains('com.vaultvoice.vaultvoice.MainActivity'));
      expect(RegExp(r'<shortcut\b').allMatches(shortcuts), hasLength(1));
    }
    final policy = _read('../tools/ci/check_recording_policy.py');
    expect(policy, contains('root / "app/android/app/src"'));
  });

  test('[QCP-03/AC5] widget, tile and shortcut show only static strings', () {
    final strings = _read(
      'android/app/src/main/res/values/quick_capture_strings.xml',
    );
    final values = RegExp('<string name="[^"]+">([^<]*)</string>')
        .allMatches(strings)
        .map((m) => m.group(1)!)
        .toList();
    expect(values, isNotEmpty);
    for (final v in values) {
      expect(v, isNot(matches(RegExp(r'[%{$]|\\n|@'))), reason: v);
    }
    final layout = _read(
      'android/app/src/main/res/layout/lumen_record_widget.xml',
    );
    final texts = RegExp('android:text="([^"]+)"')
        .allMatches(layout)
        .map((m) => m.group(1)!);
    for (final t in texts) {
      expect(t, startsWith('@string/quick_capture_'));
    }
    final provider = _code(
      _read('$_kotlinDir/quickcapture/RecordWidgetProvider.kt'),
    );
    for (final banned in [
      'setTextViewText',
      'RemoteViewsService',
      'setRemoteAdapter',
    ]) {
      expect(provider, isNot(contains(banned)));
    }
    for (final f in _quickCaptureKotlin()) {
      final s = _code(f.readAsStringSync());
      for (final banned in [
        'sqlite',
        'Room',
        'ContentResolver',
        'getSharedPreferences',
      ]) {
        expect(s, isNot(contains(banned)), reason: '${f.path} $banned');
      }
    }
    final widgetInfo = _read(
      'android/app/src/main/res/xml/lumen_record_widget_info.xml',
    );
    expect(widgetInfo, contains('android:updatePeriodMillis="0"'));
    expect(widgetInfo, isNot(contains('configure')));
  });
}
