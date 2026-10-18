import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/legal/domain/legal_documents.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

part 'legal_providers.g.dart';

/// Whether the user still has to accept the current [kLegalVersion]. Unknown
/// (settings still loading) never blocks. Existing users have no record, so
/// they are asked once.
@Riverpod(keepAlive: true)
Stream<bool> legalAcceptanceRequired(Ref ref) => ref
    .watch(settingsStoreProvider)
    .watch(LegalKeys.acceptedVersion)
    .map((v) => v != kLegalVersion);

/// Persists the explicit acceptance (version, time, age confirmation).
@Riverpod(keepAlive: true)
LegalStore legalStore(Ref ref) => LegalStore(ref);

class LegalStore {
  LegalStore(this._ref);

  final Ref _ref;

  Future<Result<void>> accept() async {
    final store = _ref.read(settingsStoreProvider);
    final at = _ref.read(clockProvider).now().toUtc().millisecondsSinceEpoch;
    final age = await store.set(LegalKeys.ageConfirmed, true);
    if (age is Err) return age;
    final time = await store.set(LegalKeys.acceptedAt, at);
    if (time is Err) return time;
    // Last, so an interrupted write never counts as accepted.
    return await store.set(LegalKeys.acceptedVersion, kLegalVersion);
  }
}
