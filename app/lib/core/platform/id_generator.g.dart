// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'id_generator.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(idGenerator)
final idGeneratorProvider = IdGeneratorProvider._();

final class IdGeneratorProvider
    extends $FunctionalProvider<IdGenerator, IdGenerator, IdGenerator>
    with $Provider<IdGenerator> {
  IdGeneratorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'idGeneratorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$idGeneratorHash();

  @$internal
  @override
  $ProviderElement<IdGenerator> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IdGenerator create(Ref ref) {
    return idGenerator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IdGenerator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IdGenerator>(value),
    );
  }
}

String _$idGeneratorHash() => r'33d878f6e343af1c672e0184b3b113cc4ea75cb3';
