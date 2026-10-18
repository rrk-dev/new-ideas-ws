import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_theme.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';
import 'package:vaultvoice/features/library/presentation/transcript_navigation.dart';
import 'package:vaultvoice/features/mindmap/data/mind_map_providers.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map.dart';
import 'package:vaultvoice/features/mindmap/presentation/mind_map_tab.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_client.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

import '../helpers/processing_fixtures.dart';

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

const _lines = [TranscriptLine(startMs: 0, endMs: 1000, text: 'Hello')];

class _Nav implements TranscriptNavigator {
  final opened = <({String id, int? atMs})>[];

  @override
  void open(BuildContext context, String recordingId, {int? atMs}) =>
      opened.add((id: recordingId, atMs: atMs));
}

class _Client implements PipelineClient {
  final calls = <String>[];

  @override
  Future<Result<String>> enqueue(
    String recordingId, {
    bool userInitiated = false,
    String? profileId,
  }) async {
    calls.add('enqueue:$recordingId');
    return const Ok('j');
  }

  @override
  Future<Result<void>> rerun(
    String jobId,
    PipelineStepId from, {
    String? profileId,
  }) async {
    calls.add('rerun:$jobId:${from.name}');
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rig {
  _Rig(this.client, this.nav, this.db);

  final _Client client;
  final _Nav nav;
  final VaultVoiceDatabase db;
}

Future<_Rig> _pump(
  WidgetTester t, {
  MindMapNode? map,
  bool requested = false,
  List<TranscriptLine> lines = _lines,
  JobState? jobState,
  ThemeData? theme,
  double scale = 1,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  t.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = _Client();
  final nav = _Nav();
  final db = VaultVoiceDatabase(NativeDatabase.memory());
  addTearDown(() => t.runAsync(db.close));
  final overrides = <Override>[
    vaultVoiceDatabaseProvider.overrideWithValue(db),
    recordingMindMapProvider('rec-a').overrideWith((ref) => Stream.value(map)),
    mindMapRequestedProvider('rec-a')
        .overrideWith((ref) => Stream.value(requested)),
    recordingTranscriptProvider('rec-a')
        .overrideWith((ref) => Stream.value(lines)),
    processingViewsProvider.overrideWith(
      (ref) async => [
        if (jobState != null) progressView(id: 'a', state: jobState),
      ],
    ),
    pipelineClientProvider.overrideWith((ref) async => client),
    transcriptNavigatorProvider.overrideWithValue(nav),
  ];
  await t.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme ?? AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(body: MindMapTab(recordingId: 'rec-a')),
      ),
    ),
  );
  await t.pumpAndSettle();
  if (map != null) {
    // MAP-02 covers the text tree; Graph is the default since MAP-03.
    await t.tap(find.text(_l.mindMapViewTree));
    await t.pumpAndSettle();
  }
  return _Rig(client, nav, db);
}

void main() {
  testWidgets('[MAP-02/AC1] not generated: Generate queues the mind-map step '
      'and records the request', (t) async {
    final rig = await _pump(t);
    expect(find.text(_l.mindMapNone), findsOneWidget);
    await t.tap(find.text(_l.mindMapGenerate));
    await t.pumpAndSettle();
    expect(rig.client.calls, ['enqueue:rec-a']);
    final stored = await t.runAsync(
      () =>
          rig.db.settingsRepository.get(SettingKeys.mindMapRequestFor('rec-a')),
    );
    expect(stored!.valueOrNull, true);
  });

  testWidgets('[MAP-02/AC1] without a transcript there is nothing to build '
      'from', (t) async {
    await _pump(t, lines: const []);
    expect(find.text(_l.mindMapNeedsTranscript), findsOneWidget);
    expect(find.text(_l.mindMapGenerate), findsNothing);
  });

  testWidgets('[MAP-02/AC1] generating shows progress and no action', (
    t,
  ) async {
    await _pump(t, requested: true, jobState: JobState.mapping);
    expect(find.text(_l.mindMapGenerating), findsOneWidget);
    expect(find.text(_l.mindMapGenerate), findsNothing);
  });

  testWidgets('[MAP-02/AC1] failed (requested, nothing running) offers retry '
      'that reruns the mind-map step', (t) async {
    final rig = await _pump(t, requested: true, jobState: JobState.failed);
    expect(find.text(_l.mindMapFailed), findsOneWidget);
    await t.tap(find.text(_l.mindMapRetry));
    await t.pumpAndSettle();
    expect(rig.client.calls, ['rerun:a:mindMap']);
  });

  testWidgets('[MAP-02/AC1] populated: collapse hides and expand restores '
      'the subtree', (t) async {
    await _pump(t, map: _map);
    expect(find.text('SDK update'), findsOneWidget);
    await t.tap(find.byTooltip(_l.mindMapCollapse('Roadmap')));
    await t.pumpAndSettle();
    expect(find.text('SDK update'), findsNothing);
    expect(find.text('Roadmap'), findsOneWidget);
    await t.tap(find.byTooltip(_l.mindMapExpand('Roadmap')));
    await t.pumpAndSettle();
    expect(find.text('SDK update'), findsOneWidget);
  });

  testWidgets('[MAP-02/AC1] a node with evidence opens the transcript at its '
      'timestamp; one without says so', (t) async {
    final rig = await _pump(t, map: _map);
    await t.tap(find.text('Roadmap'));
    await t.pumpAndSettle();
    expect(find.text(_l.mindMapEvidenceAt('00:01:05')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('mindmap-open-transcript')));
    expect(rig.nav.opened.single, (id: 'rec-a', atMs: 65000));
    await t.tap(find.text('Hiring'));
    await t.pumpAndSettle();
    expect(find.text(_l.mindMapNoEvidence), findsOneWidget);
    expect(find.byKey(const ValueKey('mindmap-open-transcript')), findsNothing);
    expect(mindMapStampMs('01:02:03'), 3723000);
    expect(mindMapStampMs('bad'), isNull);
  });

  testWidgets('[MAP-02/AC1] export reruns from render', (t) async {
    final rig = await _pump(t, map: _map, jobState: JobState.done);
    await t.tap(find.byKey(const ValueKey('mindmap-export')));
    await t.pumpAndSettle();
    expect(rig.client.calls, ['rerun:a:render']);
  });

  for (final dark in [false, true]) {
    testWidgets('[MAP-02/AC4] ${dark ? 'dark' : 'light'}: screen-reader '
        'traversal in tree order, tap targets, contrast and 200 % text', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await _pump(
        t,
        map: _map,
        theme: dark ? AppTheme.dark : AppTheme.light,
        scale: 2,
      );
      expect(t.takeException(), isNull);
      expect(
        find.bySemanticsLabel(_l.mindMapSummary(4, 'Q4 planning')),
        findsOneWidget,
      );
      // Labels carry the tree level, and rows are in depth-first order.
      final order = [
        for (final (label, level) in [
          ('Q4 planning', 1),
          ('Roadmap', 2),
          ('SDK update', 3),
          ('Hiring', 2),
        ])
          t
              .getTopLeft(
                find.bySemanticsLabel(_l.mindMapNodeSemantics(label, level)),
              )
              .dy,
      ];
      expect(order, [...order]..sort());
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(t, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}
