// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminders_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Apple Reminders exists on iOS and macOS only; Android shows no action
/// (ADR-TSK-01 §3). Tests override it.

@ProviderFor(remindersSupported)
final remindersSupportedProvider = RemindersSupportedProvider._();

/// Apple Reminders exists on iOS and macOS only; Android shows no action
/// (ADR-TSK-01 §3). Tests override it.

final class RemindersSupportedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Apple Reminders exists on iOS and macOS only; Android shows no action
  /// (ADR-TSK-01 §3). Tests override it.
  RemindersSupportedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remindersSupportedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remindersSupportedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return remindersSupported(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$remindersSupportedHash() =>
    r'0e88be49f6f038dc2eb0f6528a62293fa4c66f8b';

@ProviderFor(remindersPlatform)
final remindersPlatformProvider = RemindersPlatformProvider._();

final class RemindersPlatformProvider
    extends
        $FunctionalProvider<
          RemindersPlatform,
          RemindersPlatform,
          RemindersPlatform
        >
    with $Provider<RemindersPlatform> {
  RemindersPlatformProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remindersPlatformProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remindersPlatformHash();

  @$internal
  @override
  $ProviderElement<RemindersPlatform> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RemindersPlatform create(Ref ref) {
    return remindersPlatform(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemindersPlatform value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemindersPlatform>(value),
    );
  }
}

String _$remindersPlatformHash() => r'33fd1fb2e8a20812d644ed044dfe7fcffc3bea51';

@ProviderFor(remindersExporter)
final remindersExporterProvider = RemindersExporterProvider._();

final class RemindersExporterProvider
    extends
        $FunctionalProvider<
          RemindersExporter,
          RemindersExporter,
          RemindersExporter
        >
    with $Provider<RemindersExporter> {
  RemindersExporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remindersExporterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remindersExporterHash();

  @$internal
  @override
  $ProviderElement<RemindersExporter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RemindersExporter create(Ref ref) {
    return remindersExporter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemindersExporter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemindersExporter>(value),
    );
  }
}

String _$remindersExporterHash() => r'227debd96732f8ebb921143a13eddf6694432b4a';
