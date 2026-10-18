import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/app_paths.dart';
import 'package:vaultvoice/core/theme/app_theme.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';
import 'package:vaultvoice/features/library/presentation/transcript_navigation.dart';
import 'package:vaultvoice/features/mindmap/data/mind_map_providers.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_layout.dart';
import 'package:vaultvoice/features/mindmap/presentation/mind_map_tab.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';

import '../fakes/fake_share_service.dart';

final AppLocalizations _l = lookupAppLocalizations(const Locale('en'));

const _map = MindMapNode(
  id: 'n0',
  label: 'Q4 planning',
  children: [
    MindMapNode(
      id: 'n1',
      label: 'Roadmap',
      t: '00:01:05',
      children: [MindMapNode(id: 'n2', label: 'SDK update', t: '00:02:10')],
    ),
    MindMapNode(id: 'n3', label: 'Hiring'),
  ],
);

/// A tree beyond the stored limits, to stress the layout.
MindMapNode _big(int branches, int leaves) {
  var n = 0;
  return MindMapNode(
    id: 'r',
    label: 'Root',
    children: [
      for (var b = 0; b < branches; b++)
        MindMapNode(
          id: 'b$b',
          label: 'Branch $b',
          children: [
            for (var l = 0; l < leaves; l++)
              MindMapNode(id: 'l${n++}', label: 'Leaf $b.$l'),
          ],
        ),
    ],
  );
}

class _Nav implements TranscriptNavigator {
  final opened = <int?>[];

  @override
  void open(BuildContext context, String recordingId, {int? atMs}) =>
      opened.add(atMs);
}

class _Rig {
  _Rig(this.nav, this.share);

  final _Nav nav;
  final FakeShareService share;
}

Future<_Rig> _pump(
  WidgetTester t,
  MindMapNode map, {
  bool screenReader = false,
  ThemeData? theme,
  Directory? tmp,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  t.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final db = VaultVoiceDatabase(NativeDatabase.memory());
  addTearDown(() => t.runAsync(db.close));
  final nav = _Nav();
  final share = FakeShareService();
  final dir = tmp ?? Directory.systemTemp.createTempSync('map03');
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        vaultVoiceDatabaseProvider.overrideWithValue(db),
        recordingMindMapProvider('rec-a')
            .overrideWith((ref) => Stream.value(map)),
        mindMapRequestedProvider('rec-a')
            .overrideWith((ref) => Stream.value(false)),
        recordingTranscriptProvider('rec-a').overrideWith(
          (ref) => Stream.value(const <TranscriptLine>[
            TranscriptLine(startMs: 0, endMs: 1000, text: 'Hello'),
          ]),
        ),
        processingViewsProvider.overrideWith((ref) async => []),
        transcriptNavigatorProvider.overrideWithValue(nav),
        shareServiceProvider.overrideWithValue(share),
        appPathsProvider.overrideWithValue(
          AppPaths(root: dir, temp: Directory('${dir.path}/tmp')),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme ?? AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(accessibleNavigation: screenReader),
          child: child!,
        ),
        home: const Scaffold(body: MindMapTab(recordingId: 'rec-a')),
      ),
    ),
  );
  await t.pumpAndSettle();
  return _Rig(nav, share);
}

Future<void> _untilShared(WidgetTester t, _Rig rig) async {
  for (var i = 0; i < 100 && rig.share.shared.isEmpty; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
  }
}

void main() {
  test('[MAP-03/AC1] layout is deterministic, centred and overlap-free', () {
    final a = MindMapLayout.compute(_big(5, 4));
    final b = MindMapLayout.compute(_big(5, 4));
    expect(
      [for (final n in a.nodes) (n.node.id, n.x, n.y)],
      [for (final n in b.nodes) (n.node.id, n.x, n.y)],
    );
    for (var i = 0; i < a.nodes.length; i++) {
      for (var j = i + 1; j < a.nodes.length; j++) {
        final p = a.nodes[i];
        final q = a.nodes[j];
        final overlap =
            (p.x - q.x).abs() < a.nodeWidth && (p.y - q.y).abs() < a.nodeHeight;
        expect(overlap, isFalse, reason: '${p.node.id} vs ${q.node.id}');
      }
    }
    final root = a.nodes.first;
    final kids = a.edges
        .where((e) => e.parent == 0)
        .map((e) => a.nodes[e.child]);
    expect(root.y, (kids.first.y + kids.last.y) / 2);
    expect(a.edges.length, a.nodes.length - 1);
  });

  test('[MAP-03/AC1] one-node map and collapsed subtrees', () {
    const one = MindMapNode(id: 'n0', label: 'Only');
    final single = MindMapLayout.compute(one);
    expect(single.nodes, hasLength(1));
    expect(single.edges, isEmpty);
    expect(single.height, single.nodeHeight);
    final collapsed = MindMapLayout.compute(_map, collapsed: const {'n1'});
    expect(collapsed.nodes.map((n) => n.node.id), ['n0', 'n1', 'n3']);
  });

  testWidgets('[MAP-03/AC2] 120 nodes: layout within budget and no relayout '
      'while panning or zooming', (t) async {
    final big = _big(10, 11);
    expect(big.count, 121);
    final sw = Stopwatch()..start();
    MindMapLayout.compute(big);
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(100));

    await _pump(t, big);
    final runs = MindMapLayout.layoutRuns;
    await t.drag(
      find.byKey(const ValueKey('mindmap-graph')),
      const Offset(-80, -40),
    );
    await t.pump();
    final center = t.getCenter(find.byKey(const ValueKey('mindmap-graph')));
    final g1 = await t.startGesture(center - const Offset(20, 0));
    final g2 = await t.startGesture(center + const Offset(20, 0));
    await g1.moveBy(const Offset(-30, 0));
    await g2.moveBy(const Offset(30, 0));
    await g1.up();
    await g2.up();
    await t.pumpAndSettle();
    expect(MindMapLayout.layoutRuns, runs);
    expect(find.byKey(const ValueKey('mindmap-fit')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('mindmap-fit')));
    await t.pumpAndSettle();
    expect(MindMapLayout.layoutRuns, runs);
  });

  testWidgets('[MAP-03/AC3] tapping a node collapses and expands it and '
      'shows its full label; the stamp opens the transcript', (t) async {
    final rig = await _pump(t, _map);
    expect(find.byKey(const ValueKey('mindmap-card-n2')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('mindmap-card-n1')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('mindmap-card-n2')), findsNothing);
    expect(find.byKey(const ValueKey('mindmap-evidence')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('mindmap-card-n1')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('mindmap-card-n2')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('mindmap-stamp-n2')));
    expect(rig.nav.opened.single, 130000);
  });

  testWidgets('[MAP-03/AC3] a long label is ellipsised on the card and shown '
      'in full in the evidence panel; a one-node map renders', (t) async {
    final long = 'Very long label ' * 3;
    await _pump(
      t,
      MindMapNode(
        id: 'n0',
        label: long.trim(),
        children: const [MindMapNode(id: 'n1', label: 'x')],
      ),
    );
    await t.tap(find.byKey(const ValueKey('mindmap-card-n0')));
    await t.pumpAndSettle();
    expect(find.text(long.trim()), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });

  testWidgets('[MAP-03/AC4] Graph is the default, toggles to Tree and back; '
      'a screen reader defaults to Tree', (t) async {
    await _pump(t, _map);
    expect(find.byKey(const ValueKey('mindmap-graph')), findsOneWidget);
    expect(find.byKey(const ValueKey('mindmap-canvas')), findsNothing);
    await t.tap(find.text(_l.mindMapViewTree));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('mindmap-canvas')), findsOneWidget);
    await t.tap(find.text(_l.mindMapViewGraph));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('mindmap-graph')), findsOneWidget);
  });

  testWidgets('[MAP-03/AC4] with a screen reader the Tree is the default', (
    t,
  ) async {
    await _pump(t, _map, screenReader: true);
    expect(find.byKey(const ValueKey('mindmap-canvas')), findsOneWidget);
    expect(find.byKey(const ValueKey('mindmap-graph')), findsNothing);
  });

  testWidgets('[MAP-03/AC5] PNG export writes non-empty PNG bytes and shares '
      'the file', (t) async {
    final rig = await _pump(t, _map);
    await t.tap(find.byKey(const ValueKey('mindmap-share-image')));
    await _untilShared(t, rig);
    final shared = rig.share.shared.single;
    expect(shared.mimeType, 'image/png');
    final bytes = File(shared.path).readAsBytesSync();
    expect(bytes.length, greaterThan(100));
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  for (final dark in [false, true]) {
    testWidgets('[MAP-03/AC6] ${dark ? 'dark' : 'light'}: every graph node '
        'has a semantics label with level and expanded state', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, _map, theme: dark ? AppTheme.dark : AppTheme.light);
      for (final (label, level) in [
        ('Q4 planning', 1),
        ('Roadmap', 2),
        ('SDK update', 3),
        ('Hiring', 2),
      ]) {
        expect(
          find.bySemanticsLabel(_l.mindMapNodeSemantics(label, level)),
          findsOneWidget,
        );
      }
      final data = t
          .getSemantics(
            find.bySemanticsLabel(_l.mindMapNodeSemantics('Roadmap', 2)),
          )
          .getSemanticsData();
      expect(data.flagsCollection.isExpanded == ui.Tristate.isTrue, isTrue);
      await expectLater(t, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  testWidgets('[MAP-03/AC6] the Tree view lists all nodes', (t) async {
    await _pump(t, _map, screenReader: true);
    for (final label in ['Q4 planning', 'Roadmap', 'SDK update', 'Hiring']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('[MAP-03/AC7] interaction and export log no label text; '
      'hostile labels stay plain text', (t) async {
    final logs = <String>[];
    final old = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add(m ?? '');
    const hostile = '[[x]](javascript:1) <b>---</b>';
    final rig = await _pump(
      t,
      const MindMapNode(
        id: 'n0',
        label: hostile,
        children: [MindMapNode(id: 'n1', label: 'child', t: '00:00:01')],
      ),
    );
    await t.tap(find.byKey(const ValueKey('mindmap-card-n0')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('mindmap-share-image')));
    await _untilShared(t, rig);
    debugPrint = old;
    expect(find.text(hostile), findsWidgets);
    expect(
      logs.where((l) => l.contains('child') || l.contains('x]]')),
      isEmpty,
    );
    for (final f in [
      'lib/features/mindmap/presentation/mind_map_graph.dart',
      'lib/features/mindmap/domain/mind_map_layout.dart',
    ]) {
      expect(
        RegExp(r'\b(print|debugPrint|log\w*)\(')
            .hasMatch(File(f).readAsStringSync()),
        isFalse,
      );
    }
  });
}
