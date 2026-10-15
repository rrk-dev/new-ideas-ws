import 'package:vaultvoice/features/library/presentation/recording_detail_screen.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';

import '../helpers/golden.dart';
import '../helpers/library_fixtures.dart';

void main() {
  goldenTest(
    '[APP-02] Recording detail',
    fileName: 'recording_detail_screen',
    overrides: [
      ...libraryOverrides(),
      processingViewsProvider.overrideWith((ref) async => const []),
    ],
    builder: (_) => const RecordingDetailScreen(recordingId: 'rec-a'),
  );
}
