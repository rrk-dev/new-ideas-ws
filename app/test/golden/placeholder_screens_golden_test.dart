import 'package:vaultvoice/features/library/presentation/library_screen.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';

import '../helpers/golden.dart';
import '../helpers/library_fixtures.dart';

void main() {
  goldenTest(
    'Record screen',
    fileName: 'record_screen',
    builder: (_) => const RecordScreen(),
  );
  // APP-02: the real Library (was a placeholder until then).
  goldenTest(
    '[APP-02] Library screen',
    fileName: 'library_screen',
    overrides: libraryOverrides(),
    builder: (_) => const LibraryScreen(),
  );
}
