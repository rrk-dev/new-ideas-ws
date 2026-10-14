import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';
import 'package:vaultvoice/features/templates/domain/template_generator.dart';
import 'package:yaml/yaml.dart';

import 'template_fixtures.dart';

void main() {
  final profiles = {
    for (final id in ['meeting', 'warranty', 'engineering']) id: profile(id),
    'site-visit': customProfile(),
  };

  for (final MapEntry(key: id, value: p) in profiles.entries) {
    test('generated template for $id passes the strict check', () {
      final source = generateTemplate(p);
      expect(engine.validate(source, rootShapeFor(p), name: id), isEmpty);
    });
  }

  test('custom profile: every field kind renders, full and all-null', () {
    final p = customProfile();
    final t = engine.compile(generateTemplate(p)).valueOrNull!;
    String renderWith(Map<String, Object?> data) {
      final note = engine.render(
        t,
        buildRenderContext(
          profile: p,
          data: data,
          meta: {...metaFull(), 'profile_id': 'site-visit'},
          transcript: const {},
        ),
      );
      expect(note.warnings, isEmpty);
      return note.markdown;
    }

    final full = renderWith(customFull());
    expect(full, contains('# Recording title\n'));
    expect(full, contains('- **Site:** North tower | level 3'));
    expect(full, contains('- **Workers:** 12'));
    expect(full, contains('- **Safe:** true'));
    expect(full, contains('- **Passed:** false'));
    expect(full, contains('- **Visit date iso:** 2026-10-13'));
    expect(full, contains('## Report\n\nConcrete poured. # not a heading\n'));
    expect(full, contains(r'- {\{x}}'));
    expect(full, contains('- [x] Helmets (@Lena)\n'));
    expect(full, contains('- [ ] Scaffold tags — Due: Friday 📅 2026-10-16\n'));
    expect(full, contains('| Name | Value |\n| --- | --- |\n| Slab | 21.5 |'));
    expect(
      full,
      contains('## Contact\n\n- **Name:** Ana\n- **Phone:** +1 555'),
    );
    expect(full, contains('**Emails:**\n\n- ana@example.com'));
    final fm = full.substring(4, full.indexOf('\n---\n'));
    expect((loadYaml(fm) as YamlMap)['type'], 'site-visit');

    final empty = renderWith(const {});
    expect(empty, isNot(contains('## Report')));
    expect(empty, isNot(contains('## Contact')));
    expect(empty, contains('- **Safe:**\n'));
    expect(empty, isNot(contains('\n\n\n')));
  });

  test('title field becomes the heading', () {
    final src = generateTemplate(profile('meeting'));
    expect(src, contains('# {{#has_title}}{{data.title}}{{/has_title}}'));
    expect(src, isNot(contains('{{#md_table}}data.action_items')));
    expect(src, contains('{{#checkbox}}{{task}}'));
  });
}
