// failWith mirrors the vv-testing fake contract; a setter reads poorly.
// ignore_for_file: use_setters_to_change_properties

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';

/// In-memory [VaultWriter]; written notes are kept in [notes].
class FakeVaultWriter implements VaultWriter {
  final Map<String, String> notes = {};
  Failure? _failure;

  void failWith(Failure failure) => _failure = failure;

  @override
  Future<Result<WrittenNote>> write(NoteDraft note) async {
    if (_failure case final failure?) return Err(failure);
    notes[note.relativePath] = note.markdown;
    return Ok(WrittenNote('fake://${note.relativePath}'));
  }
}
