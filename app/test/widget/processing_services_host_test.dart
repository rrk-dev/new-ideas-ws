import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_isolate.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_services_host.dart';

import '../db/db_test_utils.dart';

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

void main() {
  testWidgets('[FND-11/AC1] the app host forwards lifecycle and memory '
      'pressure to a running worker, never starting one', (tester) async {
    final worker = _Worker();
    var started = false;
    final db = memoryDb();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultVoiceDatabaseProvider.overrideWithValue(db),
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
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero); // drift stream close timers
  });
}
