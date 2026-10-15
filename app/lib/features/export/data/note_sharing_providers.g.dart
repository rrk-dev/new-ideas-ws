// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_sharing_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Built-in templates parsed from assets once per launch.

@ProviderFor(builtinTemplates)
final builtinTemplatesProvider = BuiltinTemplatesProvider._();

/// Built-in templates parsed from assets once per launch.

final class BuiltinTemplatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<BuiltinTemplates>,
          BuiltinTemplates,
          FutureOr<BuiltinTemplates>
        >
    with $FutureModifier<BuiltinTemplates>, $FutureProvider<BuiltinTemplates> {
  /// Built-in templates parsed from assets once per launch.
  BuiltinTemplatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'builtinTemplatesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$builtinTemplatesHash();

  @$internal
  @override
  $FutureProviderElement<BuiltinTemplates> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BuiltinTemplates> create(Ref ref) {
    return builtinTemplates(ref);
  }
}

String _$builtinTemplatesHash() => r'72d682e46b66b78bb007d04da2e6bcbde9ecc65b';

@ProviderFor(noteSharing)
final noteSharingProvider = NoteSharingProvider._();

final class NoteSharingProvider
    extends
        $FunctionalProvider<
          AsyncValue<NoteSharing>,
          NoteSharing,
          FutureOr<NoteSharing>
        >
    with $FutureModifier<NoteSharing>, $FutureProvider<NoteSharing> {
  NoteSharingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteSharingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteSharingHash();

  @$internal
  @override
  $FutureProviderElement<NoteSharing> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NoteSharing> create(Ref ref) {
    return noteSharing(ref);
  }
}

String _$noteSharingHash() => r'7bc8f402e0643e2f237211b13d389ab2c456f00f';

/// Formats the note of [recordingId] can be shared in (empty: no note).

@ProviderFor(shareableFormats)
final shareableFormatsProvider = ShareableFormatsFamily._();

/// Formats the note of [recordingId] can be shared in (empty: no note).

final class ShareableFormatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<TemplateFlavor>>,
          Set<TemplateFlavor>,
          FutureOr<Set<TemplateFlavor>>
        >
    with
        $FutureModifier<Set<TemplateFlavor>>,
        $FutureProvider<Set<TemplateFlavor>> {
  /// Formats the note of [recordingId] can be shared in (empty: no note).
  ShareableFormatsProvider._({
    required ShareableFormatsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'shareableFormatsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$shareableFormatsHash();

  @override
  String toString() {
    return r'shareableFormatsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Set<TemplateFlavor>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<TemplateFlavor>> create(Ref ref) {
    final argument = this.argument as String;
    return shareableFormats(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ShareableFormatsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$shareableFormatsHash() => r'141964324320025bb69c18180c95b8cab5992606';

/// Formats the note of [recordingId] can be shared in (empty: no note).

final class ShareableFormatsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Set<TemplateFlavor>>, String> {
  ShareableFormatsFamily._()
    : super(
        retry: null,
        name: r'shareableFormatsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Formats the note of [recordingId] can be shared in (empty: no note).

  ShareableFormatsProvider call(String recordingId) =>
      ShareableFormatsProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'shareableFormatsProvider';
}
