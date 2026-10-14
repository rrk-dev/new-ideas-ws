import 'package:vaultvoice/core/db/repositories/vault_repository.dart';
import 'package:vaultvoice/features/export/domain/export_collision.dart';

/// The stable-identity inputs of [planExport] for one recording × target,
/// read from the `exports` table (FND-04): this recording's previous export
/// (`rel_path` + `content_hash` of what we wrote) and the paths other
/// recordings' exports already own in the same target.
class ExportIdentity {
  const ExportIdentity({this.prior, this.claimedByOthers = const {}});

  /// Loads the identity of ([recordingId], [targetId]) from [repo].
  ///
  /// Any status counts: a `pending`/`failed` row (EXP-06 outbox retry)
  /// names the path planned for this recording, and a `failed` row may hide
  /// an earlier successful write to the same path — reusing it avoids a
  /// duplicate on retry.
  static Future<ExportIdentity> load(
    VaultRepository repo, {
    required String recordingId,
    required String targetId,
  }) async {
    final rows = await repo.watchExports().first;
    PriorExport? prior;
    final claimed = <String>{};
    for (final r in rows) {
      if (r.targetId != targetId) continue;
      if (r.recordingId == recordingId) {
        prior = PriorExport(relPath: r.relPath, contentHash: r.contentHash);
      } else {
        claimed.add(r.relPath);
      }
    }
    return ExportIdentity(prior: prior, claimedByOthers: claimed);
  }

  final PriorExport? prior;
  final Set<String> claimedByOthers;
}
