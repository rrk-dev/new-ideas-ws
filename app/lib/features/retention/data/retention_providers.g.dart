// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retention_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(recordingPurger)
final recordingPurgerProvider = RecordingPurgerProvider._();

final class RecordingPurgerProvider
    extends
        $FunctionalProvider<
          AsyncValue<RecordingPurger>,
          RecordingPurger,
          FutureOr<RecordingPurger>
        >
    with $FutureModifier<RecordingPurger>, $FutureProvider<RecordingPurger> {
  RecordingPurgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingPurgerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingPurgerHash();

  @$internal
  @override
  $FutureProviderElement<RecordingPurger> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RecordingPurger> create(Ref ref) {
    return recordingPurger(ref);
  }
}

String _$recordingPurgerHash() => r'36b0abf6ae05c73386cdb0b37d6a50261cec0cf3';

@ProviderFor(retentionSweeper)
final retentionSweeperProvider = RetentionSweeperProvider._();

final class RetentionSweeperProvider
    extends
        $FunctionalProvider<
          AsyncValue<RetentionSweeper>,
          RetentionSweeper,
          FutureOr<RetentionSweeper>
        >
    with $FutureModifier<RetentionSweeper>, $FutureProvider<RetentionSweeper> {
  RetentionSweeperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'retentionSweeperProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$retentionSweeperHash();

  @$internal
  @override
  $FutureProviderElement<RetentionSweeper> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RetentionSweeper> create(Ref ref) {
    return retentionSweeper(ref);
  }
}

String _$retentionSweeperHash() => r'187cd19303c5231f0ea48fd866e0ae6764f3241f';

/// The secure "Delete all data" (Settings → Privacy).

@ProviderFor(secureDataWiper)
final secureDataWiperProvider = SecureDataWiperProvider._();

/// The secure "Delete all data" (Settings → Privacy).

final class SecureDataWiperProvider
    extends $FunctionalProvider<DataWiper, DataWiper, DataWiper>
    with $Provider<DataWiper> {
  /// The secure "Delete all data" (Settings → Privacy).
  SecureDataWiperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secureDataWiperProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secureDataWiperHash();

  @$internal
  @override
  $ProviderElement<DataWiper> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DataWiper create(Ref ref) {
    return secureDataWiper(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DataWiper value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DataWiper>(value),
    );
  }
}

String _$secureDataWiperHash() => r'81305476c4494cde713abd0d46bcd8de11376a0b';

/// Runs the retention sweep at start and every [kRetentionInterval]; also
/// completes a pending database-key rotation. Started from `App`.

@ProviderFor(retentionScheduler)
final retentionSchedulerProvider = RetentionSchedulerProvider._();

/// Runs the retention sweep at start and every [kRetentionInterval]; also
/// completes a pending database-key rotation. Started from `App`.

final class RetentionSchedulerProvider
    extends
        $FunctionalProvider<
          RetentionScheduler,
          RetentionScheduler,
          RetentionScheduler
        >
    with $Provider<RetentionScheduler> {
  /// Runs the retention sweep at start and every [kRetentionInterval]; also
  /// completes a pending database-key rotation. Started from `App`.
  RetentionSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'retentionSchedulerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$retentionSchedulerHash();

  @$internal
  @override
  $ProviderElement<RetentionScheduler> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RetentionScheduler create(Ref ref) {
    return retentionScheduler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RetentionScheduler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RetentionScheduler>(value),
    );
  }
}

String _$retentionSchedulerHash() =>
    r'1e73d449daac81058bbce629d6472601fed81c36';
