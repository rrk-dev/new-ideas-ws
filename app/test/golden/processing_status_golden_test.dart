import 'package:vaultvoice/features/export/data/note_sharing_providers.dart';
import 'package:vaultvoice/features/models/data/model_management_providers.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_queue_screen.dart';
import 'package:vaultvoice/features/pipeline/presentation/recording_status_screen.dart';

import '../helpers/golden.dart';
import '../helpers/processing_fixtures.dart';

void main() {
  final overrides = [
    processingViewsProvider.overrideWith((ref) async => sampleQueue()),
    modelEntriesProvider.overrideWith((ref) async => const []),
    // The real stream keeps a drift timer alive after the tree is disposed.
    recordingNoteChangesProvider.overrideWith(
      (ref, id) => const Stream<int>.empty(),
    ),
  ];
  goldenTest(
    '[APP-04] Recording processing status',
    fileName: 'recording_status_screen',
    overrides: overrides,
    builder: (_) => const RecordingStatusScreen(recordingId: 'rec-a'),
  );
  goldenTest(
    '[APP-04] Processing queue',
    fileName: 'processing_queue_screen',
    overrides: overrides,
    builder: (_) => const ProcessingQueueScreen(),
  );
}
