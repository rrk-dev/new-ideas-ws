import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_queue_screen.dart';
import 'package:vaultvoice/features/pipeline/presentation/recording_status_screen.dart';

import '../helpers/golden.dart';
import '../helpers/processing_fixtures.dart';

void main() {
  final overrides = [
    processingViewsProvider.overrideWith((ref) async => sampleQueue()),
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
