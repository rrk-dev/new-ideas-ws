/// Remembers the newest accepted catalog's `issued_at` so a replayed older
/// (validly signed) catalog is rejected after an app restart.
///
/// MDL-01 ships the in-memory version; a persistent implementation (DB,
/// FND-04) replaces it via `catalogStateStoreProvider` (follow-up MDL-05).
abstract interface class CatalogStateStore {
  Future<DateTime?> lastAcceptedIssuedAt();

  Future<void> saveAcceptedIssuedAt(DateTime issuedAt);
}

class InMemoryCatalogStateStore implements CatalogStateStore {
  InMemoryCatalogStateStore([this._value]);

  DateTime? _value;

  @override
  Future<DateTime?> lastAcceptedIssuedAt() async => _value;

  @override
  Future<void> saveAcceptedIssuedAt(DateTime issuedAt) async =>
      _value = issuedAt;
}
