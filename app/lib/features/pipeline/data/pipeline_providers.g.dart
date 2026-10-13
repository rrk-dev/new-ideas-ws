// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pipeline_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Builds the real engines inside the worker isolate. No default: STT-03,
/// LLM-04 and EXP-05 supply it via `bootstrap(overrides: …)`; tests use a
/// factory of fakes.

@ProviderFor(pipelineEnginesFactory)
final pipelineEnginesFactoryProvider = PipelineEnginesFactoryProvider._();

/// Builds the real engines inside the worker isolate. No default: STT-03,
/// LLM-04 and EXP-05 supply it via `bootstrap(overrides: …)`; tests use a
/// factory of fakes.

final class PipelineEnginesFactoryProvider
    extends
        $FunctionalProvider<
          PipelineEnginesFactory,
          PipelineEnginesFactory,
          PipelineEnginesFactory
        >
    with $Provider<PipelineEnginesFactory> {
  /// Builds the real engines inside the worker isolate. No default: STT-03,
  /// LLM-04 and EXP-05 supply it via `bootstrap(overrides: …)`; tests use a
  /// factory of fakes.
  PipelineEnginesFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pipelineEnginesFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pipelineEnginesFactoryHash();

  @$internal
  @override
  $ProviderElement<PipelineEnginesFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PipelineEnginesFactory create(Ref ref) {
    return pipelineEnginesFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PipelineEnginesFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PipelineEnginesFactory>(value),
    );
  }
}

String _$pipelineEnginesFactoryHash() =>
    r'84a126dd419e7876113f7a256c2a8ae47eb72a22';

@ProviderFor(pipelineConfig)
final pipelineConfigProvider = PipelineConfigProvider._();

final class PipelineConfigProvider
    extends $FunctionalProvider<PipelineConfig, PipelineConfig, PipelineConfig>
    with $Provider<PipelineConfig> {
  PipelineConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pipelineConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pipelineConfigHash();

  @$internal
  @override
  $ProviderElement<PipelineConfig> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PipelineConfig create(Ref ref) {
    return pipelineConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PipelineConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PipelineConfig>(value),
    );
  }
}

String _$pipelineConfigHash() => r'fda05444bab265cba94f341f877d01d6ed4c5b66';

/// The pipeline worker, running on its own background isolate and sharing
/// the process's single database connection.

@ProviderFor(pipelineClient)
final pipelineClientProvider = PipelineClientProvider._();

/// The pipeline worker, running on its own background isolate and sharing
/// the process's single database connection.

final class PipelineClientProvider
    extends
        $FunctionalProvider<
          AsyncValue<PipelineClient>,
          PipelineClient,
          FutureOr<PipelineClient>
        >
    with $FutureModifier<PipelineClient>, $FutureProvider<PipelineClient> {
  /// The pipeline worker, running on its own background isolate and sharing
  /// the process's single database connection.
  PipelineClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pipelineClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pipelineClientHash();

  @$internal
  @override
  $FutureProviderElement<PipelineClient> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PipelineClient> create(Ref ref) {
    return pipelineClient(ref);
  }
}

String _$pipelineClientHash() => r'8989effdfae3194e044e5f8062c2aa4248c96d62';

/// Every job in queue order (global queue indicator, APP-04).

@ProviderFor(pipelineJobs)
final pipelineJobsProvider = PipelineJobsProvider._();

/// Every job in queue order (global queue indicator, APP-04).

final class PipelineJobsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<JobSnapshot>>,
          List<JobSnapshot>,
          Stream<List<JobSnapshot>>
        >
    with
        $FutureModifier<List<JobSnapshot>>,
        $StreamProvider<List<JobSnapshot>> {
  /// Every job in queue order (global queue indicator, APP-04).
  PipelineJobsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pipelineJobsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pipelineJobsHash();

  @$internal
  @override
  $StreamProviderElement<List<JobSnapshot>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<JobSnapshot>> create(Ref ref) {
    return pipelineJobs(ref);
  }
}

String _$pipelineJobsHash() => r'2f72e2e0f18d23833ca4f70c2f440ce1e9bddf15';

/// Jobs of one recording (per-recording progress, APP-04).

@ProviderFor(recordingJobs)
final recordingJobsProvider = RecordingJobsFamily._();

/// Jobs of one recording (per-recording progress, APP-04).

final class RecordingJobsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<JobSnapshot>>,
          List<JobSnapshot>,
          Stream<List<JobSnapshot>>
        >
    with
        $FutureModifier<List<JobSnapshot>>,
        $StreamProvider<List<JobSnapshot>> {
  /// Jobs of one recording (per-recording progress, APP-04).
  RecordingJobsProvider._({
    required RecordingJobsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'recordingJobsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recordingJobsHash();

  @override
  String toString() {
    return r'recordingJobsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<JobSnapshot>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<JobSnapshot>> create(Ref ref) {
    final argument = this.argument as String;
    return recordingJobs(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RecordingJobsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recordingJobsHash() => r'2785504984934786f96728c357e416a9cecd05b6';

/// Jobs of one recording (per-recording progress, APP-04).

final class RecordingJobsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<JobSnapshot>>, String> {
  RecordingJobsFamily._()
    : super(
        retry: null,
        name: r'recordingJobsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Jobs of one recording (per-recording progress, APP-04).

  RecordingJobsProvider call(String recordingId) =>
      RecordingJobsProvider._(argument: recordingId, from: this);

  @override
  String toString() => r'recordingJobsProvider';
}
