import 'package:vaultvoice/core/errors/result.dart';

/// A Markdown note to write into the user's vault.
class NoteDraft {
  const NoteDraft({required this.relativePath, required this.markdown});

  /// Path relative to the vault root.
  final String relativePath;
  final String markdown;
}

/// Where a note ended up (opaque token, e.g. a SAF URI or bookmark path).
class WrittenNote {
  const WrittenNote(this.location);

  final String location;
}

/// Writes notes into the user-chosen vault folder.
abstract interface class VaultWriter {
  Future<Result<WrittenNote>> write(NoteDraft note);
}
