// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mind_map_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The stored mind map of a recording; null when none exists or the stored
/// tree no longer validates (it is then treated as not generated).

@ProviderFor(recordingMindMap)
final recordingMindMapProvider = RecordingMindMapFamily._();

/// The stored mind map of a recording; null when none exists or the stored
/// tree no longer validates (it is then treated as not generated).

final class RecordingMindMapProvider
    extends
        $FunctionalProvider<
          AsyncValue<MindMapNode?>,
          MindMapNode?,
          Stream<MindMapNode?>
        >
    with $FutureModifier<MindMapNode?>, $StreamProvider<MindMapNode?> {
  /// The stored mind map of a recording; null when none exists or the stored
  /// tree no longer validates (it is then treated as not generated).
  RecordingMindMapProvider._({
    required RecordingMindMapFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'recordingMindMapProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recordingMindMapHash();

  @override
  String toString() {
    return r'recordingMindMapProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<MindMapNode?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<MindMapNode?> create(Ref ref) {
    final argument = this.argument as String;
    return recordingMindMap(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RecordingMindMapProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recordingMindMapHash() => r'f43e5111ad4f91c633439013b41109d1fe317ee3';

/// The stored mind map of a recording; null when none exists or the stored
/// tree no longer validates (it is then treated as not generated).

final class RecordingMindMapFamily extends $Family
    with $FunctionalFamilyOverride<Stream<MindMapNode?>, String> {
  RecordingMindMapFamily._()
    : super(
        retry: null,
        name: r'recordingMindMapProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The stored mind map of a recording; null when none exists or the stored
  /// tree no longer validates (it is then treated as not generated).

  RecordingMindMapProvider call(String recordingId) =>
      RecordingMindMapProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'recordingMindMapProvider';
}

/// True while the user's request for a map is outstanding (set on Generate,
/// cleared by the step when the map is committed or rejected).

@ProviderFor(mindMapRequested)
final mindMapRequestedProvider = MindMapRequestedFamily._();

/// True while the user's request for a map is outstanding (set on Generate,
/// cleared by the step when the map is committed or rejected).

final class MindMapRequestedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// True while the user's request for a map is outstanding (set on Generate,
  /// cleared by the step when the map is committed or rejected).
  MindMapRequestedProvider._({
    required MindMapRequestedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mindMapRequestedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mindMapRequestedHash();

  @override
  String toString() {
    return r'mindMapRequestedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    final argument = this.argument as String;
    return mindMapRequested(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MindMapRequestedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mindMapRequestedHash() => r'5b8a4d32c5b2a720d7ff7f4ec696d84c0b5b8942';

/// True while the user's request for a map is outstanding (set on Generate,
/// cleared by the step when the map is committed or rejected).

final class MindMapRequestedFamily extends $Family
    with $FunctionalFamilyOverride<Stream<bool>, String> {
  MindMapRequestedFamily._()
    : super(
        retry: null,
        name: r'mindMapRequestedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// True while the user's request for a map is outstanding (set on Generate,
  /// cleared by the step when the map is committed or rejected).

  MindMapRequestedProvider call(String recordingId) =>
      MindMapRequestedProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'mindMapRequestedProvider';
}
