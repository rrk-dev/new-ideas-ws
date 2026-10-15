import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/data/recording_recovery.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';

import '../helpers/record_screen_overrides.dart';

void main() {
  testWidgets('a recovered recording is offered once: "Recovered recording '
      'from <time> — process now?"; Process now queues it', (t) async {
    final processed = <String>[];
    final started = DateTime(2026, 10, 13, 9, 41);
    List<Override> overrides() => [
      ...recordScreenPickerOverrides(),
      recoveredRecordingsProvider.overrideWith(
        (ref) async => [
          RecoveredRecording(
            recordingId: 'r1',
            startedAt: started,
            duration: const Duration(minutes: 3, seconds: 7),
            chunks: 1,
          ),
          RecoveredRecording(
            recordingId: 'r2',
            startedAt: started,
            duration: const Duration(seconds: 5),
            chunks: 1,
          ),
        ],
      ),
      recoveredRecordingProcessorProvider.overrideWithValue(
        (id) async => processed.add(id),
      ),
    ];
    const screen = MaterialApp(home: RecordScreen());

    await t.pumpWidget(ProviderScope(overrides: overrides(), child: screen));
    await t.pumpAndSettle();
    expect(
      find.textContaining(
        'Recovered recording from Oct 13, 2026 9:41 AM — process now?',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Length: 3m 07s'), findsOneWidget);
    await t.tap(find.text('Process now'));
    await t.pumpAndSettle();
    expect(processed, ['r1']);

    // Second recording: Later does not process it.
    expect(find.textContaining('Length: 0m 05s'), findsOneWidget);
    await t.tap(find.text('Later'));
    await t.pumpAndSettle();
    expect(processed, ['r1']);
    expect(find.byType(AlertDialog), findsNothing);

    // Rebuilding the screen does not ask again in the same process.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(ProviderScope(overrides: overrides(), child: screen));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
