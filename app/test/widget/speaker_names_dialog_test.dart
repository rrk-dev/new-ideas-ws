import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/transcription/presentation/speaker_names_dialog.dart';

import '../db/db_test_utils.dart';

void main() {
  testWidgets('[STT-05/AC3] renaming a speaker in the dialog is stored for '
      'that recording', (tester) async {
    final db = memoryDb();
    await tester.runAsync(() async {
      await seedRecording(db, 'r1');
      expectOk(
        await db.recordingsRepository.replaceSpeakers('r1', [
          'Speaker 1',
          'Speaker 2',
        ]),
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingsRepositoryProvider.overrideWithValue(
            db.recordingsRepository,
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SpeakerNamesDialog(recordingId: 'r1')),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'Priya');
    await tester.tap(find.text('Save'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    final names = await tester.runAsync(
      () => db.recordingsRepository.speakerNames('r1'),
    );
    expect(expectOk(names!), {'Speaker 2': 'Priya'});
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
