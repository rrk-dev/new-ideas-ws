import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/recording/data/audio_import_providers.dart';
import 'package:vaultvoice/features/recording/data/audio_import_service.dart';
import 'package:vaultvoice/features/recording/data/pigeon_audio_decoder.dart';
import 'package:vaultvoice/features/recording/data/wav_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/audio_import.dart';
import 'package:vaultvoice/features/recording/presentation/audio_import_flow.dart';

import '../db/db_test_utils.dart';
import '../helpers/deterministic.dart';

class _Decoder implements AudioDecoder {
  int calls = 0;

  @override
  Future<DecodeResult> decodeToPcm(String srcPath, String dstPath) async {
    calls++;
    return const DecodeRefused(DecodeError.failed);
  }
}

class _Picker implements AudioFilePicker {
  _Picker(this.path);

  final String? path;

  @override
  Future<String?> pick() async => path;
}

class _Inbox implements SharedAudioInbox {
  final pending = <SharedAudio>[];
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<SharedAudio>> take() async {
    final out = [...pending];
    pending.clear();
    return out;
  }

  void push(SharedAudio a) {
    pending.add(a);
    _changes.add(null);
  }
}

void main() {
  late Directory dir;
  late _Decoder decoder;
  late _Inbox inbox;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vv_import_ui_');
    decoder = _Decoder();
    inbox = _Inbox();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  File file(String name) =>
      File(p.join(dir.path, name))..writeAsBytesSync(const [1, 2, 3]);

  Future<void> pump(
    WidgetTester t, {
    ImportPlatform platform = ImportPlatform.android,
    String? picked,
  }) async {
    final service = AudioImportService(
      decoder: decoder,
      recordings: memoryDb().recordingsRepository,
      paths: StoragePaths(p.join(dir.path, 'vv')),
      codec: const WavChunkCodec(),
      clock: testClock(),
      ids: testIds(),
      platform: platform,
      enqueue: (_) async {},
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          audioImportServiceProvider.overrideWith((ref) async => service),
          audioFilePickerProvider.overrideWithValue(_Picker(picked)),
          sharedAudioInboxProvider.overrideWithValue(inbox),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: const [ImportAudioButton()]),
            body: const SharedAudioImportListener(child: SizedBox()),
          ),
        ),
      ),
    );
    await t.pump();
  }

  testWidgets('[AUD-06/AC1] the attestation must be ticked before Import is '
      'possible', (t) async {
    final f = file('memo.m4a');
    await pump(t, picked: f.path);
    await t.tap(find.byKey(const ValueKey('import-audio')));
    await t.pumpAndSettle();
    expect(find.byType(ImportAttestationDialog), findsOneWidget);
    expect(
      find.textContaining('everyone in it consented to being recorded'),
      findsOneWidget,
    );
    final confirm = find.byKey(const ValueKey('import-confirm'));
    expect(t.widget<FilledButton>(confirm).onPressed, isNull);
    await t.tap(find.byKey(const ValueKey('import-attest')));
    await t.pump();
    expect(t.widget<FilledButton>(confirm).onPressed, isNotNull);
    await t.tap(confirm);
    // Real file IO completes outside fake async; pump until the message.
    final failed = find.text('The file could not be imported.');
    for (var i = 0; i < 100 && failed.evaluate().isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump();
    }
    expect(decoder.calls, 1);
    expect(find.text('The file could not be imported.'), findsOneWidget);
  });

  testWidgets('cancelling the attestation imports nothing and deletes a '
      'shared copy', (t) async {
    final f = file('shared.mp3');
    await pump(t);
    inbox.push(SharedAudio(path: f.path, extension: 'mp3'));
    await t.pumpAndSettle();
    expect(find.byType(ImportAttestationDialog), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(decoder.calls, 0);
    expect(f.existsSync(), isFalse);
  });

  testWidgets('[AUD-06/AC2] a file shared into the app (share sheet / App '
      'Group inbox) is offered for import behind the attestation', (t) async {
    final f = file('x');
    inbox.pending.add(SharedAudio(path: f.path, extension: 'm4a'));
    await pump(t);
    await t.pumpAndSettle();
    expect(find.byType(ImportAttestationDialog), findsOneWidget);
  });

  testWidgets('[AUD-06/AC1] an unsupported format shows a clear message '
      'without asking for the attestation', (t) async {
    final f = file('voice.opus');
    await pump(t, platform: ImportPlatform.ios, picked: f.path);
    await t.tap(find.byKey(const ValueKey('import-audio')));
    await t.pumpAndSettle();
    expect(find.byType(ImportAttestationDialog), findsNothing);
    expect(
      find.text('Ogg/Opus files can’t be imported on this device.'),
      findsOneWidget,
    );
    expect(f.existsSync(), isFalse, reason: 'picker copy removed');
    expect(decoder.calls, 0);
  });
}
