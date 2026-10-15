// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_indicator_binding.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Active for the whole app session; watched by the launch screen.

@ProviderFor(recordingIndicatorBinding)
final recordingIndicatorBindingProvider = RecordingIndicatorBindingProvider._();

/// Active for the whole app session; watched by the launch screen.

final class RecordingIndicatorBindingProvider
    extends
        $FunctionalProvider<
          RecordingIndicatorBinding,
          RecordingIndicatorBinding,
          RecordingIndicatorBinding
        >
    with $Provider<RecordingIndicatorBinding> {
  /// Active for the whole app session; watched by the launch screen.
  RecordingIndicatorBindingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingIndicatorBindingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingIndicatorBindingHash();

  @$internal
  @override
  $ProviderElement<RecordingIndicatorBinding> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecordingIndicatorBinding create(Ref ref) {
    return recordingIndicatorBinding(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecordingIndicatorBinding value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecordingIndicatorBinding>(value),
    );
  }
}

String _$recordingIndicatorBindingHash() =>
    r'a5e74085573a83500e9437831c9b80fcf599ab3d';
