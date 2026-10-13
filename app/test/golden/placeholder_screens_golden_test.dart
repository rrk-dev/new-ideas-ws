import 'package:vaultvoice/features/library/presentation/library_screen.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';

import '../helpers/golden.dart';

void main() {
  goldenTest(
    'Record screen',
    fileName: 'record_screen',
    builder: (_) => const RecordScreen(),
  );
  goldenTest(
    'Library screen',
    fileName: 'library_screen',
    builder: (_) => const LibraryScreen(),
  );
}
