import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:re_editor/re_editor.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';
import 'package:vaultvoice/features/templates/data/template_editor_providers.dart';
import 'package:vaultvoice/features/templates/data/template_store.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';
import 'package:vaultvoice/features/templates/domain/template_editing.dart';
import 'package:vaultvoice/features/templates/presentation/template_editor_screen.dart';
import 'package:vaultvoice/features/templates/presentation/templates_screen.dart';

import '../fakes/fake_clock.dart';
import '../unit/templates/template_fixtures.dart';

class _MemoryTemplates implements TemplateStore {
  final Map<String, CustomTemplate> templates = {};
  final Map<String, String> bindings = {};
  final _changes = StreamController<void>.broadcast();

  List<CustomTemplate> get _list =>
      templates.values.toList()..sort((a, b) => a.id.compareTo(b.id));

  @override
  Stream<List<CustomTemplate>> watch() async* {
    yield _list;
    yield* _changes.stream.map((_) => _list);
  }

  @override
  Future<Result<void>> save(CustomTemplate t) async {
    templates[t.id] = t;
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<void>> delete(String id) async {
    templates.remove(id);
    bindings.removeWhere((_, v) => v == id);
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Stream<Map<String, String>> watchBindings() async* {
    yield {...bindings};
    yield* _changes.stream.map((_) => {...bindings});
  }

  @override
  Future<Result<void>> bind(String profileId, String? templateId) async {
    if (templateId == null) {
      bindings.remove(profileId);
    } else {
      bindings[profileId] = templateId;
    }
    _changes.add(null);
    return const Ok(null);
  }
}

CustomTemplate mine({String body = '# {{data.title}}\n'}) => CustomTemplate(
  id: 'mine',
  body: body,
  filenamePattern: '{{slug}}.md',
  profileId: 'meeting',
  baseId: 'meeting-default',
);

void main() {
  late _MemoryTemplates store;

  setUp(() => store = _MemoryTemplates());

  Future<GoRouter> pump(
    WidgetTester t,
    String location, {
    DistributionMode mode = DistributionMode.personal,
  }) async {
    t.view
      ..physicalSize = const Size(800, 3000)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/settings/templates',
          builder: (_, _) => const TemplatesScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, s) =>
                  TemplateEditorScreen(templateId: s.pathParameters['id']!),
            ),
          ],
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 10))),
          distributionModeProvider.overrideWithValue(mode),
          paywallPresenterProvider.overrideWithValue(
            const NoPaywallPresenter(),
          ),
          templateStoreProvider.overrideWithValue(store),
          builtinTemplateSourcesProvider.overrideWith(
            (ref) async => {
              for (final i in kBuiltinTemplates)
                i.id: File(i.assetPath).readAsStringSync(),
            },
          ),
          editorProfilesProvider.overrideWith(
            (ref) async => builtinProfiles.all,
          ),
          templatePreviewRecordingsProvider.overrideWith(
            (ref, id) async => const [],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
    return router;
  }

  CodeLineEditingController code(WidgetTester t) =>
      t.widget<CodeEditor>(find.byType(CodeEditor)).controller!;

  String rawPreview(WidgetTester t) => t
      .widget<SelectableText>(
        find.byKey(const ValueKey('template-preview-raw')),
      )
      .data!;

  testWidgets('[EXP-07/AC1] preview updates < 200 ms after typing stops; '
      'syntax errors are shown inline at their line', (t) async {
    await store.save(mine());
    await pump(t, '/settings/templates/mine');
    expect(rawPreview(t), '# ${sampleDataFor(profile('meeting'))['title']}\n');

    code(t).text = '# {{meta.title}} edited\n';
    await t.pump(const Duration(milliseconds: 100));
    expect(rawPreview(t), isNot(contains('edited')), reason: 'debounced');
    await t.pump(const Duration(milliseconds: 60)); // 160 ms < 200 ms
    expect(rawPreview(t), '# Sample note edited\n');

    code(t).text = 'ok\n{{#data.action_items}}\n';
    await t.pump(kPreviewDebounce);
    expect(find.textContaining('Line '), findsWidgets);
    expect(find.text('Fix the template to see a preview.'), findsOneWidget);
    final gutter = t.widget<DefaultCodeLineNumber>(
      find.byType(DefaultCodeLineNumber),
    );
    expect(gutter.customLineIndex2Text!(1), startsWith('⚠'));
    expect(gutter.customLineIndex2Text!(0), '1');

    // Save is refused while there are problems.
    await t.tap(find.byKey(const ValueKey('template-save')));
    await t.pump();
    expect(find.textContaining('before saving'), findsOneWidget);
    expect(store.templates['mine']!.body, '# {{data.title}}\n');
    await t.pumpAndSettle();
  });

  testWidgets('valid edits save body + filename pattern; binding toggles', (
    t,
  ) async {
    await store.save(mine());
    await pump(t, '/settings/templates/mine');
    code(t).text = '# {{data.title}} v2\n';
    await t.enterText(
      find.byKey(const ValueKey('template-pattern')),
      '{{date:YYYY}}/{{slug}}.md',
    );
    await t.tap(find.byKey(const ValueKey('template-save')));
    await t.pumpAndSettle();
    expect(store.templates['mine']!.body, '# {{data.title}} v2\n');
    expect(
      store.templates['mine']!.filenamePattern,
      '{{date:YYYY}}/{{slug}}.md',
    );

    await t.tap(find.byKey(const ValueKey('template-bind')));
    await t.pumpAndSettle();
    expect(store.bindings, {'meeting': 'mine'});

    await t.enterText(find.byKey(const ValueKey('template-pattern')), '../x');
    await t.tap(find.byKey(const ValueKey('template-save')));
    await t.pumpAndSettle();
    expect(find.text('Folders must stay inside the vault.'), findsOneWidget);
  });

  testWidgets('rendered toggle; reset to default; delete', (t) async {
    await store.save(mine(body: '# {{data.title}}\n\n**bold**\n'));
    await pump(t, '/settings/templates/mine');
    await t.tap(find.text('Rendered'));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('template-preview-rendered')),
      findsOneWidget,
    );

    await t.tap(find.byKey(const ValueKey('template-more')));
    await t.pumpAndSettle();
    await t.tap(find.text('Reset to default'));
    await t.pumpAndSettle();
    expect(code(t).text, templateSource('meeting-default'));

    await t.tap(find.byKey(const ValueKey('template-more')));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete template'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete template').last);
    await t.pumpAndSettle();
    expect(store.templates, isEmpty);
  });

  testWidgets('built-ins are read-only and can be duplicated', (t) async {
    final router = await pump(t, '/settings/templates/meeting-logseq');
    expect(find.byKey(const ValueKey('template-readonly')), findsOneWidget);
    expect(find.byKey(const ValueKey('template-save')), findsNothing);
    expect(t.widget<CodeEditor>(find.byType(CodeEditor)).readOnly, isTrue);

    await t.tap(find.byKey(const ValueKey('template-duplicate')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('template-duplicate-name')),
      'My Logseq',
    );
    await t.tap(find.text('Create'));
    await t.pumpAndSettle();
    final copy = store.templates['my-logseq']!;
    expect(copy.body, templateSource('meeting-logseq'));
    expect(copy.baseId, 'meeting-logseq');
    expect(copy.profileId, 'meeting');
    expect(router.state.uri.path, '/settings/templates/my-logseq');
  });

  testWidgets('Free (commercial): duplicate refused, custom read-only', (
    t,
  ) async {
    await store.save(mine());
    await pump(t, '/settings/templates', mode: DistributionMode.commercial);
    expect(find.byKey(const ValueKey('templates-locked')), findsOneWidget);
    await t.tap(find.text('mine'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('template-save')), findsNothing);
    expect(t.widget<CodeEditor>(find.byType(CodeEditor)).readOnly, isTrue);
    await t.tap(find.byKey(const ValueKey('template-duplicate')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('template-duplicate-name')), findsNothing);
  });

  test('routes exist', () {
    expect(const TemplatesRoute().location, '/settings/templates');
    expect(
      const TemplateEditorRoute(templateId: 'x').location,
      '/settings/templates/x',
    );
  });
}
