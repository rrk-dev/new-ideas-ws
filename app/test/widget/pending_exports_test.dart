import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/export/data/export_outbox.dart';
import 'package:vaultvoice/features/export/data/routing_providers.dart';
import 'package:vaultvoice/features/export/domain/pending_export.dart';
import 'package:vaultvoice/features/export/presentation/pending_exports_screen.dart';

class _Outbox extends Fake implements ExportOutbox {
  final calls = <String>[];
  bool fail = false;

  Result<T> _r<T>(String call, T v) {
    calls.add(call);
    return fail ? const Err(StorageFailure('x')) : Ok(v);
  }

  @override
  Future<Result<bool>> regrant(
    String targetId, {
    bool sameFolder = true,
  }) async => _r('regrant:$targetId:$sameFolder', true);

  @override
  Future<Result<void>> retry(PendingExport item) async =>
      _r('retry:${item.recordingId}', null);

  @override
  Future<Result<bool>> addFolder() async => _r('add', true);

  @override
  Future<Result<void>> saveOnDevice() async => _r('device', null);
}

const _items = [
  PendingExport(
    recordingId: 'r0',
    title: '',
    reason: PendingReason.noDestination,
    jobId: 'j0',
  ),
  PendingExport(
    recordingId: 'r1',
    title: 'Standup',
    reason: PendingReason.accessRevoked,
    jobId: 'j1',
    targetId: 'v',
    targetName: 'Work vault',
  ),
  PendingExport(
    recordingId: 'r2',
    title: 'Warranty',
    reason: PendingReason.retrying,
    jobId: 'j2',
    targetId: 'v',
    targetName: 'Work vault',
  ),
];

void main() {
  late _Outbox outbox;

  setUp(() => outbox = _Outbox());

  Future<void> pump(WidgetTester t, List<PendingExport> items) async {
    t.view
      ..physicalSize = const Size(600, 2000)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          exportOutboxProvider.overrideWithValue(outbox),
          pendingExportsProvider.overrideWith((ref) => Stream.value(items)),
        ],
        child: const MaterialApp(home: PendingExportsScreen()),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('lists pending notes with the matching actions', (t) async {
    await pump(t, _items);
    expect(find.text('Untitled recording'), findsOneWidget);
    expect(find.text('No vault folder chosen yet'), findsOneWidget);
    expect(find.text('Access to Work vault was removed'), findsOneWidget);
    expect(
      find.text(
        'Work vault is not reachable right now. Retrying automatically.',
      ),
      findsOneWidget,
    );

    await t.tap(find.byKey(const ValueKey('pending-device-r0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('pending-choose-r0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('pending-regrant-r1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('pending-change-r1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('pending-retry-r2')));
    await t.pumpAndSettle();
    expect(outbox.calls, [
      'device',
      'add',
      'regrant:v:true',
      'regrant:v:false',
      'retry:r2',
    ]);
    expect(find.byKey(const ValueKey('pending-retry-r1')), findsNothing);
  });

  testWidgets('failed action shows a message; empty state', (t) async {
    outbox.fail = true;
    await pump(t, _items);
    await t.tap(find.byKey(const ValueKey('pending-retry-r2')));
    await t.pumpAndSettle();
    expect(find.text('That did not work. Please try again.'), findsOneWidget);

    await pump(t, const []);
    expect(
      find.text('Every note has reached its vault folder.'),
      findsOneWidget,
    );
  });
}
