import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/export/data/export_outbox.dart';
import 'package:vaultvoice/features/export/data/routing_providers.dart';
import 'package:vaultvoice/features/pipeline/data/background_guard.dart';
import 'package:vaultvoice/features/pipeline/data/background_providers.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_isolate.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/domain/background_platform.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_services_host.dart';

import '../db/db_test_utils.dart';

/// EXP-06 outbox: counts resume rechecks (no DB / platform access).
class _Outbox implements ExportOutbox {
  int rechecks = 0;

  @override
  Future<int> recheck() async => ++rechecks;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the device conditions forwarded to the worker.
class _Worker implements PipelineClient, PipelineConditions {
  final List<bool> foreground = [];
  int pressure = 0;

  @override
  Future<void> setForeground({required bool foreground}) async =>
      this.foreground.add(foreground);

  @override
  Future<void> memoryPressure() async => pressure++;

  @override
  Stream<JobEvent> get events => const Stream.empty();

  @override
  Future<Result<String>> enqueue(
    String recordingId, {
    bool userInitiated = false,
    String? profileId,
  }) async => const Ok('j');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records what the host tells the background guard (FND-08).
class _Guard extends BackgroundProcessingGuard {
  _Guard(VaultVoiceDatabase db)
    : super(
        platform: const NoBackgroundProcessingPlatform(),
        jobs: const Stream.empty(),
        client: () => throw StateError('unused'),
        settings: db.settingsRepository,
        texts: (title: '', text: ''),
      );

  final List<bool> foreground = [];
  bool started = false;

  @override
  Future<void> start() async => started = true;

  @override
  void setForeground({required bool foreground}) =>
      this.foreground.add(foreground);

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('[FND-11/AC1] the app host forwards lifecycle and memory '
      'pressure to a running worker, never starting one', (tester) async {
    final worker = _Worker();
    var started = false;
    final db = memoryDb();
    final guard = _Guard(db);
    final outbox = _Outbox();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultVoiceDatabaseProvider.overrideWithValue(db),
          backgroundProcessingGuardProvider.overrideWithValue(guard),
          exportOutboxProvider.overrideWithValue(outbox),
          pipelineClientProvider.overrideWith((ref) async {
            started = true;
            return worker;
          }),
        ],
        child: const ProcessingServicesHost(child: SizedBox()),
      ),
    );
    // Not running yet: lifecycle events are dropped, the worker not spawned.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(started, isFalse);
    expect(worker.foreground, isEmpty);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SizedBox)),
    );
    await tester.runAsync(() => container.read(pipelineClientProvider.future));
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleMemoryPressure();
    await tester.pump();
    expect(worker.foreground, [true, false]);
    expect(worker.pressure, 1);
    // FND-08: the guard was started and follows the lifecycle too.
    expect(guard.started, isTrue);
    expect(guard.foreground, containsAllInOrder([false, true, false]));
    // EXP-06 (integration W3): back in the foreground ⇒ one outbox recheck.
    expect(outbox.rechecks, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero); // drift stream close timers
  });
}
