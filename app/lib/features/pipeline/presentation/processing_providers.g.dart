// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'processing_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Local notifications. Default: shows nothing; `bootstrap` overrides it
/// with `FlutterLocalNotifier` on iOS/Android, tests with a fake.

@ProviderFor(localNotifications)
final localNotificationsProvider = LocalNotificationsProvider._();

/// Local notifications. Default: shows nothing; `bootstrap` overrides it
/// with `FlutterLocalNotifier` on iOS/Android, tests with a fake.

final class LocalNotificationsProvider
    extends $FunctionalProvider<LocalNotifier, LocalNotifier, LocalNotifier>
    with $Provider<LocalNotifier> {
  /// Local notifications. Default: shows nothing; `bootstrap` overrides it
  /// with `FlutterLocalNotifier` on iOS/Android, tests with a fake.
  LocalNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localNotificationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localNotificationsHash();

  @$internal
  @override
  $ProviderElement<LocalNotifier> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalNotifier create(Ref ref) {
    return localNotifications(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalNotifier value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalNotifier>(value),
    );
  }
}

String _$localNotificationsHash() =>
    r'614f466adb44956d3660338b782c2af9aeeb55c3';

@ProviderFor(processingNotificationTexts)
final processingNotificationTextsProvider =
    ProcessingNotificationTextsProvider._();

final class ProcessingNotificationTextsProvider
    extends
        $FunctionalProvider<
          ProcessingNotificationTexts,
          ProcessingNotificationTexts,
          ProcessingNotificationTexts
        >
    with $Provider<ProcessingNotificationTexts> {
  ProcessingNotificationTextsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'processingNotificationTextsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$processingNotificationTextsHash();

  @$internal
  @override
  $ProviderElement<ProcessingNotificationTexts> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProcessingNotificationTexts create(Ref ref) {
    return processingNotificationTexts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProcessingNotificationTexts value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProcessingNotificationTexts>(value),
    );
  }
}

String _$processingNotificationTextsHash() =>
    r'1810b87450f919cd696ffce33778332047181348';

/// The UI-isolate job observer (throughput, notifications, deep links).
/// Created on first use; `ProcessingServicesHost` starts it at app start.

@ProviderFor(processingMonitor)
final processingMonitorProvider = ProcessingMonitorProvider._();

/// The UI-isolate job observer (throughput, notifications, deep links).
/// Created on first use; `ProcessingServicesHost` starts it at app start.

final class ProcessingMonitorProvider
    extends
        $FunctionalProvider<
          ProcessingMonitor,
          ProcessingMonitor,
          ProcessingMonitor
        >
    with $Provider<ProcessingMonitor> {
  /// The UI-isolate job observer (throughput, notifications, deep links).
  /// Created on first use; `ProcessingServicesHost` starts it at app start.
  ProcessingMonitorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'processingMonitorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$processingMonitorHash();

  @$internal
  @override
  $ProviderElement<ProcessingMonitor> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProcessingMonitor create(Ref ref) {
    return processingMonitor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProcessingMonitor value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProcessingMonitor>(value),
    );
  }
}

String _$processingMonitorHash() => r'825ef5ff400e1176cc9ba2ea2fdaddeba8296413';

/// Wall-clock ticks so ETAs count down between job updates.

@ProviderFor(processingNow)
final processingNowProvider = ProcessingNowProvider._();

/// Wall-clock ticks so ETAs count down between job updates.

final class ProcessingNowProvider
    extends
        $FunctionalProvider<AsyncValue<DateTime>, DateTime, Stream<DateTime>>
    with $FutureModifier<DateTime>, $StreamProvider<DateTime> {
  /// Wall-clock ticks so ETAs count down between job updates.
  ProcessingNowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'processingNowProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$processingNowHash();

  @$internal
  @override
  $StreamProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DateTime> create(Ref ref) {
    return processingNow(ref);
  }
}

String _$processingNowHash() => r'6ae8138f009f7c38bcf6d0fe007208bb4e09ff43';

/// Measured per-step throughput of this device (`settings`).

@ProviderFor(throughputStats)
final throughputStatsProvider = ThroughputStatsProvider._();

/// Measured per-step throughput of this device (`settings`).

final class ThroughputStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ThroughputStats>,
          ThroughputStats,
          Stream<ThroughputStats>
        >
    with $FutureModifier<ThroughputStats>, $StreamProvider<ThroughputStats> {
  /// Measured per-step throughput of this device (`settings`).
  ThroughputStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'throughputStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$throughputStatsHash();

  @$internal
  @override
  $StreamProviderElement<ThroughputStats> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ThroughputStats> create(Ref ref) {
    return throughputStats(ref);
  }
}

String _$throughputStatsHash() => r'ee703eef9e809b259f5db16e5d20ae726d65dbb2';

/// Title + length of every recording, by id.

@ProviderFor(recordingFacts)
final recordingFactsProvider = RecordingFactsProvider._();

/// Title + length of every recording, by id.

final class RecordingFactsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, RecordingFacts>>,
          Map<String, RecordingFacts>,
          Stream<Map<String, RecordingFacts>>
        >
    with
        $FutureModifier<Map<String, RecordingFacts>>,
        $StreamProvider<Map<String, RecordingFacts>> {
  /// Title + length of every recording, by id.
  RecordingFactsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recordingFactsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recordingFactsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, RecordingFacts>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, RecordingFacts>> create(Ref ref) {
    return recordingFacts(ref);
  }
}

String _$recordingFactsHash() => r'8f279cfe5f575fcc0da5520f0c4455f498eff6af';

/// Progress views of every job, in queue order.

@ProviderFor(processingViews)
final processingViewsProvider = ProcessingViewsProvider._();

/// Progress views of every job, in queue order.

final class ProcessingViewsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<JobProgressView>>,
          List<JobProgressView>,
          FutureOr<List<JobProgressView>>
        >
    with
        $FutureModifier<List<JobProgressView>>,
        $FutureProvider<List<JobProgressView>> {
  /// Progress views of every job, in queue order.
  ProcessingViewsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'processingViewsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$processingViewsHash();

  @$internal
  @override
  $FutureProviderElement<List<JobProgressView>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<JobProgressView>> create(Ref ref) {
    return processingViews(ref);
  }
}

String _$processingViewsHash() => r'40b56b90d544b7695926fec8022c3bc14c74d7ff';
