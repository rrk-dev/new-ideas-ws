// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `<appSupport>/vv` layout. Tests override with a temp directory.

@ProviderFor(storagePaths)
final storagePathsProvider = StoragePathsProvider._();

/// `<appSupport>/vv` layout. Tests override with a temp directory.

final class StoragePathsProvider
    extends
        $FunctionalProvider<
          AsyncValue<StoragePaths>,
          StoragePaths,
          FutureOr<StoragePaths>
        >
    with $FutureModifier<StoragePaths>, $FutureProvider<StoragePaths> {
  /// `<appSupport>/vv` layout. Tests override with a temp directory.
  StoragePathsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storagePathsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storagePathsHash();

  @$internal
  @override
  $FutureProviderElement<StoragePaths> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<StoragePaths> create(Ref ref) {
    return storagePaths(ref);
  }
}

String _$storagePathsHash() => r'812dc45de9c08bd72c55bd45a36e45f207a40a03';

/// Cipher hook for the DB connection. SEC-01 overrides this with the
/// Keychain/Keystore-keyed sqlite3mc cipher.

@ProviderFor(databaseCipher)
final databaseCipherProvider = DatabaseCipherProvider._();

/// Cipher hook for the DB connection. SEC-01 overrides this with the
/// Keychain/Keystore-keyed sqlite3mc cipher.

final class DatabaseCipherProvider
    extends $FunctionalProvider<DatabaseCipher, DatabaseCipher, DatabaseCipher>
    with $Provider<DatabaseCipher> {
  /// Cipher hook for the DB connection. SEC-01 overrides this with the
  /// Keychain/Keystore-keyed sqlite3mc cipher.
  DatabaseCipherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseCipherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseCipherHash();

  @$internal
  @override
  $ProviderElement<DatabaseCipher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DatabaseCipher create(Ref ref) {
    return databaseCipher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DatabaseCipher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DatabaseCipher>(value),
    );
  }
}

String _$databaseCipherHash() => r'4a16ad41b10fe96474e8c0e40c091aa2610d97d2';

/// The single database instance of this process. Opening is lazy (the path
/// is resolved asynchronously) and runs on a drift background isolate.
/// Tests override with `VaultVoiceDatabase(NativeDatabase.memory())`.

@ProviderFor(vaultVoiceDatabase)
final vaultVoiceDatabaseProvider = VaultVoiceDatabaseProvider._();

/// The single database instance of this process. Opening is lazy (the path
/// is resolved asynchronously) and runs on a drift background isolate.
/// Tests override with `VaultVoiceDatabase(NativeDatabase.memory())`.

final class VaultVoiceDatabaseProvider
    extends
        $FunctionalProvider<
          VaultVoiceDatabase,
          VaultVoiceDatabase,
          VaultVoiceDatabase
        >
    with $Provider<VaultVoiceDatabase> {
  /// The single database instance of this process. Opening is lazy (the path
  /// is resolved asynchronously) and runs on a drift background isolate.
  /// Tests override with `VaultVoiceDatabase(NativeDatabase.memory())`.
  VaultVoiceDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultVoiceDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultVoiceDatabaseHash();

  @$internal
  @override
  $ProviderElement<VaultVoiceDatabase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VaultVoiceDatabase create(Ref ref) {
    return vaultVoiceDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VaultVoiceDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VaultVoiceDatabase>(value),
    );
  }
}

String _$vaultVoiceDatabaseHash() =>
    r'a02ea01957cb1a876143b688cf5532287b859ff9';

@ProviderFor(recordingsRepository)
final recordingsRepositoryProvider = RecordingsRepositoryProvider._();

final class RecordingsRepositoryProvider
    extends
        $FunctionalProvider<
          RecordingsRepository,
          RecordingsRepository,
          RecordingsRepository
        >
    with $Provider<RecordingsRepository> {
  RecordingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<RecordingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecordingsRepository create(Ref ref) {
    return recordingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecordingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecordingsRepository>(value),
    );
  }
}

String _$recordingsRepositoryHash() =>
    r'a3808a42da4ccbbde9343ccd302ed7e955ecf658';

@ProviderFor(transcriptsRepository)
final transcriptsRepositoryProvider = TranscriptsRepositoryProvider._();

final class TranscriptsRepositoryProvider
    extends
        $FunctionalProvider<
          TranscriptsRepository,
          TranscriptsRepository,
          TranscriptsRepository
        >
    with $Provider<TranscriptsRepository> {
  TranscriptsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transcriptsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transcriptsRepositoryHash();

  @$internal
  @override
  $ProviderElement<TranscriptsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TranscriptsRepository create(Ref ref) {
    return transcriptsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranscriptsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranscriptsRepository>(value),
    );
  }
}

String _$transcriptsRepositoryHash() =>
    r'2179fad3a55bcc24472d7d6513dd19ac4c124c68';

@ProviderFor(jobsRepository)
final jobsRepositoryProvider = JobsRepositoryProvider._();

final class JobsRepositoryProvider
    extends $FunctionalProvider<JobsRepository, JobsRepository, JobsRepository>
    with $Provider<JobsRepository> {
  JobsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jobsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jobsRepositoryHash();

  @$internal
  @override
  $ProviderElement<JobsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  JobsRepository create(Ref ref) {
    return jobsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JobsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JobsRepository>(value),
    );
  }
}

String _$jobsRepositoryHash() => r'360babf872085e0de5c30511e174e3209beabb04';

@ProviderFor(profilesRepository)
final profilesRepositoryProvider = ProfilesRepositoryProvider._();

final class ProfilesRepositoryProvider
    extends
        $FunctionalProvider<
          ProfilesRepository,
          ProfilesRepository,
          ProfilesRepository
        >
    with $Provider<ProfilesRepository> {
  ProfilesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profilesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profilesRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfilesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfilesRepository create(Ref ref) {
    return profilesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfilesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfilesRepository>(value),
    );
  }
}

String _$profilesRepositoryHash() =>
    r'962a7a3285a6b6df64e0886386613bef8fb3c7a6';

@ProviderFor(extractionsRepository)
final extractionsRepositoryProvider = ExtractionsRepositoryProvider._();

final class ExtractionsRepositoryProvider
    extends
        $FunctionalProvider<
          ExtractionsRepository,
          ExtractionsRepository,
          ExtractionsRepository
        >
    with $Provider<ExtractionsRepository> {
  ExtractionsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'extractionsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$extractionsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ExtractionsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExtractionsRepository create(Ref ref) {
    return extractionsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExtractionsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExtractionsRepository>(value),
    );
  }
}

String _$extractionsRepositoryHash() =>
    r'eba00545580422d8176257166291215d758e4bb2';

@ProviderFor(vaultRepository)
final vaultRepositoryProvider = VaultRepositoryProvider._();

final class VaultRepositoryProvider
    extends
        $FunctionalProvider<VaultRepository, VaultRepository, VaultRepository>
    with $Provider<VaultRepository> {
  VaultRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultRepositoryHash();

  @$internal
  @override
  $ProviderElement<VaultRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VaultRepository create(Ref ref) {
    return vaultRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VaultRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VaultRepository>(value),
    );
  }
}

String _$vaultRepositoryHash() => r'892679ac1c39b4609398af1f897ae2cebf8b1660';

@ProviderFor(modelsRepository)
final modelsRepositoryProvider = ModelsRepositoryProvider._();

final class ModelsRepositoryProvider
    extends
        $FunctionalProvider<
          ModelsRepository,
          ModelsRepository,
          ModelsRepository
        >
    with $Provider<ModelsRepository> {
  ModelsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ModelsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ModelsRepository create(Ref ref) {
    return modelsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelsRepository>(value),
    );
  }
}

String _$modelsRepositoryHash() => r'60e18debdf8216a1e59ce2fab8a3aa7e6eb5812b';

@ProviderFor(settingsRepository)
final settingsRepositoryProvider = SettingsRepositoryProvider._();

final class SettingsRepositoryProvider
    extends
        $FunctionalProvider<
          SettingsRepository,
          SettingsRepository,
          SettingsRepository
        >
    with $Provider<SettingsRepository> {
  SettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SettingsRepository create(Ref ref) {
    return settingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsRepository>(value),
    );
  }
}

String _$settingsRepositoryHash() =>
    r'e340a1d6215b9d360ca9b2513f5dd0a39992e0e0';
