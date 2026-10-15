import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/app_paths.dart';
import 'package:vaultvoice/core/platform/share_service.dart';
import 'package:vaultvoice/features/export/data/note_sharing.dart';
import 'package:vaultvoice/features/export/data/note_sharing_providers.dart';
import 'package:vaultvoice/features/export/presentation/share_note_sheet.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';

import '../fakes/fake_share_service.dart';

class _Sharing extends Fake implements NoteSharing {
  final requested = <TemplateFlavor>[];

  @override
  Future<Set<TemplateFlavor>> available(String recordingId) async =>
      TemplateFlavor.values.toSet();

  @override
  Future<Result<ShareableNote>> render(
    String recordingId,
    TemplateFlavor flavor,
  ) async {
    requested.add(flavor);
    return Ok(
      ShareableNote(
        markdown: '# ${flavor.name}\n',
        fileName: '2026-10-13-meeting-note.md',
      ),
    );
  }
}

void main() {
  late _Sharing sharing;
  late FakeShareService share;
  late Directory tmp;
  final clipboard = <String>[];

  setUp(() {
    sharing = _Sharing();
    share = FakeShareService();
    tmp = Directory.systemTemp.createTempSync('vv_note_share_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    clipboard.clear();
  });

  Future<void> pump(WidgetTester t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          noteSharingProvider.overrideWith((ref) async => sharing),
          recordingNoteChangesProvider.overrideWith(
            (ref, id) => const Stream<int>.empty(),
          ),
          shareServiceProvider.overrideWithValue(share),
          appPathsProvider.overrideWithValue(
            AppPaths(root: tmp, temp: Directory('${tmp.path}/tmp')),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: const [ShareNoteButton(recordingId: 'r1')]),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('note-share')));
    await t.pumpAndSettle();
  }

  testWidgets('share as .md file in the chosen format', (t) async {
    await pump(t);
    await t.tap(find.text('Logseq'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('note-share-file')));
    // Real file IO: let it complete outside fake async.
    for (var i = 0; i < 20 && share.shared.isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump();
    }
    await t.pumpAndSettle();
    expect(sharing.requested, [TemplateFlavor.logseq]);
    final s = share.shared.single;
    expect(s.mimeType, 'text/markdown');
    expect(s.path, endsWith('2026-10-13-meeting-note.md'));
    expect(File(s.path).readAsStringSync(), '# logseq\n');
    expect(s.subject, '2026-10-13-meeting-note');
    expect(find.byType(ShareNoteSheet), findsNothing, reason: 'sheet closes');
  });

  testWidgets('share as text and copy to clipboard', (t) async {
    await pump(t);
    await t.tap(find.text('Plain'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('note-share-text')));
    await t.pumpAndSettle();
    expect(share.texts.single.text, '# plain\n');

    await t.tap(find.byKey(const ValueKey('note-share')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('note-copy')));
    await t.pumpAndSettle();
    expect(clipboard, ['# obsidian\n']);
    expect(find.text('Note copied.'), findsOneWidget);
  });

  testWidgets('unavailable share sheet is reported', (t) async {
    share.outcome = ShareOutcome.unavailable;
    await pump(t);
    await t.tap(find.byKey(const ValueKey('note-share-text')));
    await t.pumpAndSettle();
    expect(
      find.text('Sharing is not available on this device.'),
      findsOneWidget,
    );
  });
}
