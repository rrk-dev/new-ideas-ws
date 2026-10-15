// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_navigation.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(transcriptNavigator)
final transcriptNavigatorProvider = TranscriptNavigatorProvider._();

final class TranscriptNavigatorProvider
    extends
        $FunctionalProvider<
          TranscriptNavigator,
          TranscriptNavigator,
          TranscriptNavigator
        >
    with $Provider<TranscriptNavigator> {
  TranscriptNavigatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transcriptNavigatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transcriptNavigatorHash();

  @$internal
  @override
  $ProviderElement<TranscriptNavigator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TranscriptNavigator create(Ref ref) {
    return transcriptNavigator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranscriptNavigator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranscriptNavigator>(value),
    );
  }
}

String _$transcriptNavigatorHash() =>
    r'0da28c8bcf7a0e9c19086ee25a56a27e54b2cdae';
