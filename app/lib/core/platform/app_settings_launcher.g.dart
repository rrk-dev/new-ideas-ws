// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_launcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appSettingsLauncher)
final appSettingsLauncherProvider = AppSettingsLauncherProvider._();

final class AppSettingsLauncherProvider
    extends
        $FunctionalProvider<
          AppSettingsLauncher,
          AppSettingsLauncher,
          AppSettingsLauncher
        >
    with $Provider<AppSettingsLauncher> {
  AppSettingsLauncherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsLauncherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsLauncherHash();

  @$internal
  @override
  $ProviderElement<AppSettingsLauncher> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppSettingsLauncher create(Ref ref) {
    return appSettingsLauncher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettingsLauncher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettingsLauncher>(value),
    );
  }
}

String _$appSettingsLauncherHash() =>
    r'251530866093493199941b779357b16dc5c9e7a2';
