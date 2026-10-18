// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ask_chat.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The conversation on screen: library-wide ([recordingId] null) or about
/// one recording. Locking the app cancels a running question and clears the
/// screen (SEC-03: nothing stays readable behind the lock).

@ProviderFor(AskChat)
final askChatProvider = AskChatFamily._();

/// The conversation on screen: library-wide ([recordingId] null) or about
/// one recording. Locking the app cancels a running question and clears the
/// screen (SEC-03: nothing stays readable behind the lock).
final class AskChatProvider extends $NotifierProvider<AskChat, AskChatState> {
  /// The conversation on screen: library-wide ([recordingId] null) or about
  /// one recording. Locking the app cancels a running question and clears the
  /// screen (SEC-03: nothing stays readable behind the lock).
  AskChatProvider._({
    required AskChatFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'askChatProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$askChatHash();

  @override
  String toString() {
    return r'askChatProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AskChat create() => AskChat();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AskChatState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AskChatState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AskChatProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$askChatHash() => r'f784363d39abd2234aff4b799ccf5c5ba59b0c3d';

/// The conversation on screen: library-wide ([recordingId] null) or about
/// one recording. Locking the app cancels a running question and clears the
/// screen (SEC-03: nothing stays readable behind the lock).

final class AskChatFamily extends $Family
    with
        $ClassFamilyOverride<
          AskChat,
          AskChatState,
          AskChatState,
          AskChatState,
          String?
        > {
  AskChatFamily._()
    : super(
        retry: null,
        name: r'askChatProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The conversation on screen: library-wide ([recordingId] null) or about
  /// one recording. Locking the app cancels a running question and clears the
  /// screen (SEC-03: nothing stays readable behind the lock).

  AskChatProvider call(String? recordingId) =>
      AskChatProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'askChatProvider';
}

/// The conversation on screen: library-wide ([recordingId] null) or about
/// one recording. Locking the app cancels a running question and clears the
/// screen (SEC-03: nothing stays readable behind the lock).

abstract class _$AskChat extends $Notifier<AskChatState> {
  late final _$args = ref.$arg as String?;
  String? get recordingId => _$args;

  AskChatState build(String? recordingId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AskChatState, AskChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AskChatState, AskChatState>,
              AskChatState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
