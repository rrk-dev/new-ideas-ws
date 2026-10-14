// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(searchRepository)
final searchRepositoryProvider = SearchRepositoryProvider._();

final class SearchRepositoryProvider
    extends
        $FunctionalProvider<
          SearchRepository,
          SearchRepository,
          SearchRepository
        >
    with $Provider<SearchRepository> {
  SearchRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchRepositoryHash();

  @$internal
  @override
  $ProviderElement<SearchRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SearchRepository create(Ref ref) {
    return searchRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchRepository>(value),
    );
  }
}

String _$searchRepositoryHash() => r'4ad5c0b9aa3dc3e40a8cfccae2f73efe162c5c3a';

/// The Library's search text, filters and sort (kept across tab switches).

@ProviderFor(LibraryFilterState)
final libraryFilterStateProvider = LibraryFilterStateProvider._();

/// The Library's search text, filters and sort (kept across tab switches).
final class LibraryFilterStateProvider
    extends $NotifierProvider<LibraryFilterState, LibraryFilter> {
  /// The Library's search text, filters and sort (kept across tab switches).
  LibraryFilterStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryFilterStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryFilterStateHash();

  @$internal
  @override
  LibraryFilterState create() => LibraryFilterState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryFilter>(value),
    );
  }
}

String _$libraryFilterStateHash() =>
    r'c9aec0e3ef2b7b57fb20ead2555cf1c4a3a3c7ab';

/// The Library's search text, filters and sort (kept across tab switches).

abstract class _$LibraryFilterState extends $Notifier<LibraryFilter> {
  LibraryFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LibraryFilter, LibraryFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LibraryFilter, LibraryFilter>,
              LibraryFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Every recording as a Library item, recomputed whenever recordings, jobs,
/// exports, vault targets or extractions change.

@ProviderFor(libraryItems)
final libraryItemsProvider = LibraryItemsProvider._();

/// Every recording as a Library item, recomputed whenever recordings, jobs,
/// exports, vault targets or extractions change.

final class LibraryItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LibraryItem>>,
          List<LibraryItem>,
          Stream<List<LibraryItem>>
        >
    with
        $FutureModifier<List<LibraryItem>>,
        $StreamProvider<List<LibraryItem>> {
  /// Every recording as a Library item, recomputed whenever recordings, jobs,
  /// exports, vault targets or extractions change.
  LibraryItemsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryItemsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryItemsHash();

  @$internal
  @override
  $StreamProviderElement<List<LibraryItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<LibraryItem>> create(Ref ref) {
    return libraryItems(ref);
  }
}

String _$libraryItemsHash() => r'cb555eba52617f91420acc58ea41d81ca115e1b7';

@ProviderFor(libraryResults)
final libraryResultsProvider = LibraryResultsProvider._();

final class LibraryResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<LibraryResults>,
          LibraryResults,
          FutureOr<LibraryResults>
        >
    with $FutureModifier<LibraryResults>, $FutureProvider<LibraryResults> {
  LibraryResultsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryResultsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryResultsHash();

  @$internal
  @override
  $FutureProviderElement<LibraryResults> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LibraryResults> create(Ref ref) {
    return libraryResults(ref);
  }
}

String _$libraryResultsHash() => r'5a2462c3fb597e2d15425ac6f7c507cceb08d4d2';

/// Profile names by id (built-in + user), for list subtitles and filters.

@ProviderFor(profileNames)
final profileNamesProvider = ProfileNamesProvider._();

/// Profile names by id (built-in + user), for list subtitles and filters.

final class ProfileNamesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          Stream<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $StreamProvider<Map<String, String>> {
  /// Profile names by id (built-in + user), for list subtitles and filters.
  ProfileNamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileNamesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileNamesHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, String>> create(Ref ref) {
    return profileNames(ref);
  }
}

String _$profileNamesHash() => r'fb2e6086fbb2e0f79d1aafdb68a2e74d49c233a4';

@ProviderFor(recordingHeader)
final recordingHeaderProvider = RecordingHeaderFamily._();

final class RecordingHeaderProvider
    extends
        $FunctionalProvider<
          AsyncValue<RecordingHeader?>,
          RecordingHeader?,
          Stream<RecordingHeader?>
        >
    with $FutureModifier<RecordingHeader?>, $StreamProvider<RecordingHeader?> {
  RecordingHeaderProvider._({
    required RecordingHeaderFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'recordingHeaderProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recordingHeaderHash();

  @override
  String toString() {
    return r'recordingHeaderProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<RecordingHeader?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<RecordingHeader?> create(Ref ref) {
    final argument = this.argument as String;
    return recordingHeader(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RecordingHeaderProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recordingHeaderHash() => r'67a69b24b8c23f89245787d6ff4b2886d73467c5';

final class RecordingHeaderFamily extends $Family
    with $FunctionalFamilyOverride<Stream<RecordingHeader?>, String> {
  RecordingHeaderFamily._()
    : super(
        retry: null,
        name: r'recordingHeaderProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RecordingHeaderProvider call(String recordingId) =>
      RecordingHeaderProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'recordingHeaderProvider';
}

/// Lines of the newest transcript (empty before transcription).

@ProviderFor(recordingTranscript)
final recordingTranscriptProvider = RecordingTranscriptFamily._();

/// Lines of the newest transcript (empty before transcription).

final class RecordingTranscriptProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TranscriptLine>>,
          List<TranscriptLine>,
          Stream<List<TranscriptLine>>
        >
    with
        $FutureModifier<List<TranscriptLine>>,
        $StreamProvider<List<TranscriptLine>> {
  /// Lines of the newest transcript (empty before transcription).
  RecordingTranscriptProvider._({
    required RecordingTranscriptFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'recordingTranscriptProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recordingTranscriptHash();

  @override
  String toString() {
    return r'recordingTranscriptProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<TranscriptLine>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TranscriptLine>> create(Ref ref) {
    final argument = this.argument as String;
    return recordingTranscript(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RecordingTranscriptProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recordingTranscriptHash() =>
    r'be9350e44f6443bcf2ff97faf44a038e642fa9a6';

/// Lines of the newest transcript (empty before transcription).

final class RecordingTranscriptFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<TranscriptLine>>, String> {
  RecordingTranscriptFamily._()
    : super(
        retry: null,
        name: r'recordingTranscriptProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Lines of the newest transcript (empty before transcription).

  RecordingTranscriptProvider call(String recordingId) =>
      RecordingTranscriptProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'recordingTranscriptProvider';
}

/// Export history of one recording.

@ProviderFor(recordingExports)
final recordingExportsProvider = RecordingExportsFamily._();

/// Export history of one recording.

final class RecordingExportsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ExportInfo>>,
          List<ExportInfo>,
          Stream<List<ExportInfo>>
        >
    with $FutureModifier<List<ExportInfo>>, $StreamProvider<List<ExportInfo>> {
  /// Export history of one recording.
  RecordingExportsProvider._({
    required RecordingExportsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'recordingExportsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recordingExportsHash();

  @override
  String toString() {
    return r'recordingExportsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ExportInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ExportInfo>> create(Ref ref) {
    final argument = this.argument as String;
    return recordingExports(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RecordingExportsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recordingExportsHash() => r'5a6e2a13965881fd41d446c1360ddd19dea10953';

/// Export history of one recording.

final class RecordingExportsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ExportInfo>>, String> {
  RecordingExportsFamily._()
    : super(
        retry: null,
        name: r'recordingExportsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Export history of one recording.

  RecordingExportsProvider call(String recordingId) =>
      RecordingExportsProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'recordingExportsProvider';
}

@ProviderFor(recordingExtraction)
final recordingExtractionProvider = RecordingExtractionFamily._();

final class RecordingExtractionProvider
    extends
        $FunctionalProvider<
          AsyncValue<ExtractionView?>,
          ExtractionView?,
          Stream<ExtractionView?>
        >
    with $FutureModifier<ExtractionView?>, $StreamProvider<ExtractionView?> {
  RecordingExtractionProvider._({
    required RecordingExtractionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'recordingExtractionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recordingExtractionHash();

  @override
  String toString() {
    return r'recordingExtractionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ExtractionView?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ExtractionView?> create(Ref ref) {
    final argument = this.argument as String;
    return recordingExtraction(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RecordingExtractionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recordingExtractionHash() =>
    r'c746b9946ff8e5232a00b8f8bf3b86ac623b50ab';

final class RecordingExtractionFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ExtractionView?>, String> {
  RecordingExtractionFamily._()
    : super(
        retry: null,
        name: r'recordingExtractionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RecordingExtractionProvider call(String recordingId) =>
      RecordingExtractionProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'recordingExtractionProvider';
}

/// Action items across recordings, newest recording first.

@ProviderFor(actionItems)
final actionItemsProvider = ActionItemsFamily._();

/// Action items across recordings, newest recording first.

final class ActionItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ActionItemView>>,
          List<ActionItemView>,
          Stream<List<ActionItemView>>
        >
    with
        $FutureModifier<List<ActionItemView>>,
        $StreamProvider<List<ActionItemView>> {
  /// Action items across recordings, newest recording first.
  ActionItemsProvider._({
    required ActionItemsFamily super.from,
    required bool super.argument,
  }) : super(
         retry: null,
         name: r'actionItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$actionItemsHash();

  @override
  String toString() {
    return r'actionItemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ActionItemView>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ActionItemView>> create(Ref ref) {
    final argument = this.argument as bool;
    return actionItems(ref, openOnly: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActionItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$actionItemsHash() => r'a9fdc9c303fa49c211414979756e26efacf2843c';

/// Action items across recordings, newest recording first.

final class ActionItemsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ActionItemView>>, bool> {
  ActionItemsFamily._()
    : super(
        retry: null,
        name: r'actionItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Action items across recordings, newest recording first.

  ActionItemsProvider call({required bool openOnly}) =>
      ActionItemsProvider._(argument: openOnly, from: this);

  @override
  String toString() => r'actionItemsProvider';
}

/// Deletes recordings (and, on request, their exported notes).

@ProviderFor(recordingDeleter)
final recordingDeleterProvider = RecordingDeleterProvider._();

/// Deletes recordings (and, on request, their exported notes).

final class RecordingDeleterProvider
    extends
        $FunctionalProvider<
          AsyncValue<RecordingDeleter>,
          RecordingDeleter,
          FutureOr<RecordingDeleter>
        >
    with $FutureModifier<RecordingDeleter>, $FutureProvider<RecordingDeleter> {
  /// Deletes recordings (and, on request, their exported notes).
  RecordingDeleterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingDeleterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingDeleterHash();

  @$internal
  @override
  $FutureProviderElement<RecordingDeleter> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RecordingDeleter> create(Ref ref) {
    return recordingDeleter(ref);
  }
}

String _$recordingDeleterHash() => r'886fb5ee20639fc49afa202d28d3c6ab571c9089';
