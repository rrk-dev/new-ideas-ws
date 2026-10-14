// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(latestTranscript)
final latestTranscriptProvider = LatestTranscriptFamily._();

final class LatestTranscriptProvider
    extends
        $FunctionalProvider<
          AsyncValue<TranscriptMeta?>,
          TranscriptMeta?,
          Stream<TranscriptMeta?>
        >
    with $FutureModifier<TranscriptMeta?>, $StreamProvider<TranscriptMeta?> {
  LatestTranscriptProvider._({
    required LatestTranscriptFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'latestTranscriptProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$latestTranscriptHash();

  @override
  String toString() {
    return r'latestTranscriptProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<TranscriptMeta?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<TranscriptMeta?> create(Ref ref) {
    final argument = this.argument as String;
    return latestTranscript(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LatestTranscriptProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$latestTranscriptHash() => r'655416bfd149e9783f40dfa4ea88d7fa04fb2204';

final class LatestTranscriptFamily extends $Family
    with $FunctionalFamilyOverride<Stream<TranscriptMeta?>, String> {
  LatestTranscriptFamily._()
    : super(
        retry: null,
        name: r'latestTranscriptProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LatestTranscriptProvider call(String recordingId) =>
      LatestTranscriptProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'latestTranscriptProvider';
}

/// Segments of one transcript (speaker = raw label), sorted by start.

@ProviderFor(transcriptSegments)
final transcriptSegmentsProvider = TranscriptSegmentsFamily._();

/// Segments of one transcript (speaker = raw label), sorted by start.

final class TranscriptSegmentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TranscriptSegmentView>>,
          List<TranscriptSegmentView>,
          Stream<List<TranscriptSegmentView>>
        >
    with
        $FutureModifier<List<TranscriptSegmentView>>,
        $StreamProvider<List<TranscriptSegmentView>> {
  /// Segments of one transcript (speaker = raw label), sorted by start.
  TranscriptSegmentsProvider._({
    required TranscriptSegmentsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transcriptSegmentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transcriptSegmentsHash();

  @override
  String toString() {
    return r'transcriptSegmentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<TranscriptSegmentView>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TranscriptSegmentView>> create(Ref ref) {
    final argument = this.argument as String;
    return transcriptSegments(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TranscriptSegmentsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transcriptSegmentsHash() =>
    r'db2118c8a969be57ac672731531ee94f86189698';

/// Segments of one transcript (speaker = raw label), sorted by start.

final class TranscriptSegmentsFamily extends $Family
    with
        $FunctionalFamilyOverride<Stream<List<TranscriptSegmentView>>, String> {
  TranscriptSegmentsFamily._()
    : super(
        retry: null,
        name: r'transcriptSegmentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Segments of one transcript (speaker = raw label), sorted by start.

  TranscriptSegmentsProvider call(String transcriptId) =>
      TranscriptSegmentsProvider._(argument: transcriptId, from: this);

  @override
  String toString() => r'transcriptSegmentsProvider';
}

/// Timeline markers shown in the transcript. Consent markers are
/// bookkeeping (SEC-09), not timeline content.

@ProviderFor(transcriptMarkers)
final transcriptMarkersProvider = TranscriptMarkersFamily._();

/// Timeline markers shown in the transcript. Consent markers are
/// bookkeeping (SEC-09), not timeline content.

final class TranscriptMarkersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TranscriptMarkerView>>,
          List<TranscriptMarkerView>,
          Stream<List<TranscriptMarkerView>>
        >
    with
        $FutureModifier<List<TranscriptMarkerView>>,
        $StreamProvider<List<TranscriptMarkerView>> {
  /// Timeline markers shown in the transcript. Consent markers are
  /// bookkeeping (SEC-09), not timeline content.
  TranscriptMarkersProvider._({
    required TranscriptMarkersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transcriptMarkersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transcriptMarkersHash();

  @override
  String toString() {
    return r'transcriptMarkersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<TranscriptMarkerView>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TranscriptMarkerView>> create(Ref ref) {
    final argument = this.argument as String;
    return transcriptMarkers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TranscriptMarkersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transcriptMarkersHash() => r'1254cf7b4ae9b47eca64f4512d892825404017cc';

/// Timeline markers shown in the transcript. Consent markers are
/// bookkeeping (SEC-09), not timeline content.

final class TranscriptMarkersFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<TranscriptMarkerView>>, String> {
  TranscriptMarkersFamily._()
    : super(
        retry: null,
        name: r'transcriptMarkersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Timeline markers shown in the transcript. Consent markers are
  /// bookkeeping (SEC-09), not timeline content.

  TranscriptMarkersProvider call(String recordingId) =>
      TranscriptMarkersProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'transcriptMarkersProvider';
}

/// Speaker label → display name (renames from STT-05/APP).

@ProviderFor(speakerNames)
final speakerNamesProvider = SpeakerNamesFamily._();

/// Speaker label → display name (renames from STT-05/APP).

final class SpeakerNamesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          Stream<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $StreamProvider<Map<String, String>> {
  /// Speaker label → display name (renames from STT-05/APP).
  SpeakerNamesProvider._({
    required SpeakerNamesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'speakerNamesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$speakerNamesHash();

  @override
  String toString() {
    return r'speakerNamesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, String>> create(Ref ref) {
    final argument = this.argument as String;
    return speakerNames(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SpeakerNamesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$speakerNamesHash() => r'2cdebaced2c9172ac95ec5295375b02a9317061e';

/// Speaker label → display name (renames from STT-05/APP).

final class SpeakerNamesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Map<String, String>>, String> {
  SpeakerNamesFamily._()
    : super(
        retry: null,
        name: r'speakerNamesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Speaker label → display name (renames from STT-05/APP).

  SpeakerNamesProvider call(String recordingId) =>
      SpeakerNamesProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'speakerNamesProvider';
}

/// The newest transcript of [recordingId] with its segments, speaker names
/// and user markers; null before the first transcription.

@ProviderFor(transcriptView)
final transcriptViewProvider = TranscriptViewFamily._();

/// The newest transcript of [recordingId] with its segments, speaker names
/// and user markers; null before the first transcription.

final class TranscriptViewProvider
    extends
        $FunctionalProvider<
          AsyncValue<TranscriptViewData?>,
          TranscriptViewData?,
          FutureOr<TranscriptViewData?>
        >
    with
        $FutureModifier<TranscriptViewData?>,
        $FutureProvider<TranscriptViewData?> {
  /// The newest transcript of [recordingId] with its segments, speaker names
  /// and user markers; null before the first transcription.
  TranscriptViewProvider._({
    required TranscriptViewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transcriptViewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transcriptViewHash();

  @override
  String toString() {
    return r'transcriptViewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TranscriptViewData?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TranscriptViewData?> create(Ref ref) {
    final argument = this.argument as String;
    return transcriptView(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TranscriptViewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transcriptViewHash() => r'87b3a5946515ec0a4410461bd866da6435fe251c';

/// The newest transcript of [recordingId] with its segments, speaker names
/// and user markers; null before the first transcription.

final class TranscriptViewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TranscriptViewData?>, String> {
  TranscriptViewFamily._()
    : super(
        retry: null,
        name: r'transcriptViewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The newest transcript of [recordingId] with its segments, speaker names
  /// and user markers; null before the first transcription.

  TranscriptViewProvider call(String recordingId) =>
      TranscriptViewProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'transcriptViewProvider';
}

/// Creates the audio player (tests override with a fake).

@ProviderFor(transcriptPlayerFactory)
final transcriptPlayerFactoryProvider = TranscriptPlayerFactoryProvider._();

/// Creates the audio player (tests override with a fake).

final class TranscriptPlayerFactoryProvider
    extends
        $FunctionalProvider<
          TranscriptPlayerFactory,
          TranscriptPlayerFactory,
          TranscriptPlayerFactory
        >
    with $Provider<TranscriptPlayerFactory> {
  /// Creates the audio player (tests override with a fake).
  TranscriptPlayerFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transcriptPlayerFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transcriptPlayerFactoryHash();

  @$internal
  @override
  $ProviderElement<TranscriptPlayerFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TranscriptPlayerFactory create(Ref ref) {
    return transcriptPlayerFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranscriptPlayerFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranscriptPlayerFactory>(value),
    );
  }
}

String _$transcriptPlayerFactoryHash() =>
    r'630cb9ebc8ba5b9dc46f2ff306b23d2b30189433';

/// Playback of [recordingId]'s chunks; disposed with the screen.

@ProviderFor(transcriptPlayback)
final transcriptPlaybackProvider = TranscriptPlaybackFamily._();

/// Playback of [recordingId]'s chunks; disposed with the screen.

final class TranscriptPlaybackProvider
    extends
        $FunctionalProvider<
          AsyncValue<TranscriptPlayback>,
          TranscriptPlayback,
          FutureOr<TranscriptPlayback>
        >
    with
        $FutureModifier<TranscriptPlayback>,
        $FutureProvider<TranscriptPlayback> {
  /// Playback of [recordingId]'s chunks; disposed with the screen.
  TranscriptPlaybackProvider._({
    required TranscriptPlaybackFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transcriptPlaybackProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transcriptPlaybackHash();

  @override
  String toString() {
    return r'transcriptPlaybackProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TranscriptPlayback> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TranscriptPlayback> create(Ref ref) {
    final argument = this.argument as String;
    return transcriptPlayback(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TranscriptPlaybackProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transcriptPlaybackHash() =>
    r'5ecad91cc1fcea45c4e7d775aae04b80f38f6aa6';

/// Playback of [recordingId]'s chunks; disposed with the screen.

final class TranscriptPlaybackFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TranscriptPlayback>, String> {
  TranscriptPlaybackFamily._()
    : super(
        retry: null,
        name: r'transcriptPlaybackProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Playback of [recordingId]'s chunks; disposed with the screen.

  TranscriptPlaybackProvider call(String recordingId) =>
      TranscriptPlaybackProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'transcriptPlaybackProvider';
}

/// Edits and re-extraction for the transcript screen. Kept alive: commands
/// outlive the widget that started them (a dialog closes mid-write).

@ProviderFor(transcriptEditor)
final transcriptEditorProvider = TranscriptEditorFamily._();

/// Edits and re-extraction for the transcript screen. Kept alive: commands
/// outlive the widget that started them (a dialog closes mid-write).

final class TranscriptEditorProvider
    extends
        $FunctionalProvider<
          TranscriptEditor,
          TranscriptEditor,
          TranscriptEditor
        >
    with $Provider<TranscriptEditor> {
  /// Edits and re-extraction for the transcript screen. Kept alive: commands
  /// outlive the widget that started them (a dialog closes mid-write).
  TranscriptEditorProvider._({
    required TranscriptEditorFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transcriptEditorProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transcriptEditorHash();

  @override
  String toString() {
    return r'transcriptEditorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<TranscriptEditor> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TranscriptEditor create(Ref ref) {
    final argument = this.argument as String;
    return transcriptEditor(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranscriptEditor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranscriptEditor>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TranscriptEditorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transcriptEditorHash() => r'ff0625cb08b29a8598070dc812177659f868b671';

/// Edits and re-extraction for the transcript screen. Kept alive: commands
/// outlive the widget that started them (a dialog closes mid-write).

final class TranscriptEditorFamily extends $Family
    with $FunctionalFamilyOverride<TranscriptEditor, String> {
  TranscriptEditorFamily._()
    : super(
        retry: null,
        name: r'transcriptEditorProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Edits and re-extraction for the transcript screen. Kept alive: commands
  /// outlive the widget that started them (a dialog closes mid-write).

  TranscriptEditorProvider call(String recordingId) =>
      TranscriptEditorProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'transcriptEditorProvider';
}
