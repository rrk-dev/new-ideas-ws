import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/export/domain/vault_target_options.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_markdown.dart';

import '../templates/template_fixtures.dart';

/// Text goldens of the mind-map section appended to a vault note; regenerate
/// with `fvm flutter test --update-goldens test/unit/mindmap/` and lint with
/// `tools/ci/markdownlint.sh`.
const _dir = 'test/fixtures/markdown/golden/mindmap';
const _base = 'test/fixtures/markdown/golden/meeting-default.full.md';

const _full = MindMapNode(
  id: 'n0',
  label: 'Q4 planning',
  children: [
    MindMapNode(
      id: 'n1',
      label: 'Roadmap',
      t: '00:01:05',
      children: [
        MindMapNode(id: 'n2', label: 'SDK update', t: '00:02:10'),
        MindMapNode(id: 'n3', label: 'Migration guide'),
      ],
    ),
    MindMapNode(id: 'n4', label: 'Hiring', t: '00:05:00'),
  ],
);

MindMapNode _adversarial() => MindMapNode(
  id: 'n0',
  label: adversarialStrings[2],
  children: [
    for (var i = 0; i < adversarialStrings.length; i++)
      MindMapNode(id: 'n${i + 1}', label: adversarialStrings[i]),
  ],
);

void _golden(String name, String actual) {
  final file = File('$_dir/$name');
  if (autoUpdateGoldenFiles) {
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(actual);
  }
  expect(actual, file.readAsStringSync(), reason: name);
}

void main() {
  final note = File(_base).readAsStringSync();

  test('[MAP-02/AC2] a stored tree renders as a nested list under a heading '
      'and lints clean', () {
    final md = mindMapNoteSection(_full);
    expect(
      md,
      '## Mind map\n\n'
      '- Q4 planning\n'
      '  - Roadmap (00:01:05)\n'
      '    - SDK update (00:02:10)\n'
      '    - Migration guide\n'
      '  - Hiring (00:05:00)\n',
    );
    expect(mindMapStandaloneMarkdown(_full), startsWith('# Q4 planning\n\n'));
  });

  test('[MAP-02/AC2] adversarial labels cannot open links, wikilinks, '
      'front-matter, HTML, code or template tags', () {
    final md = mindMapNoteSection(_adversarial());
    final lines = md.split('\n').skip(2).where((l) => l.isNotEmpty).toList();
    // One list item per node: no label breaks out of its line.
    expect(lines, hasLength(adversarialStrings.length + 1));
    for (final l in lines) {
      expect(l.trimLeft(), startsWith('- '));
    }
    expect(md, isNot(contains('[[')));
    expect(md, isNot(contains(']]')));
    expect(md, isNot(contains('{{data')));
    expect(md, isNot(contains('{{#')));
    expect(md, isNot(contains(RegExp(r'(?<!\\)<'))));
    expect(md, isNot(contains('```')));
    expect(md, isNot(contains('\n---')));
    expect(
      mindMapLabel('see [x](http://a.b) www.c.de'),
      isNot(contains(RegExp(r'(?<!\\)[\[\]]'))),
    );
    expect(mindMapLabel('http://a.b'), isNot(contains('://')));
    expect(mindMapLabel('   '), '…');
  });

  test('[MAP-02/AC3] vault-note goldens: full, empty and adversarial', () {
    _golden('note.full.md', appendMindMapSection(note, _full));
    _golden('note.empty.md', appendMindMapSection(note, null));
    _golden('note.adversarial.md', appendMindMapSection(note, _adversarial()));
    expect(appendMindMapSection(note, null), note);
    expect(appendMindMapSection(note, _full), contains('\n## Mind map\n'));
  });

  test('[MAP-02/AC3] an invalid stored tree is not exported', () {
    expect(mindMapFromJson({'id': 'n0'}), isNull);
    expect(mindMapFromJson(_full.toJson()), isA<MindMapNode>());
  });

  test(
    '[MAP-02/AC3] the sidecar is a separate opt-in note beside the note',
    () {
      expect(
        SidecarPaths.mindMap('Meetings/2026-10-14-a.md'),
        'Meetings/2026-10-14-a.mindmap.md',
      );
      expect(VaultTargetOptions.defaults.mindMapSidecar, isFalse);
      final on = VaultTargetOptions.defaults.copyWith(mindMapSidecar: true);
      expect(VaultTargetOptions.fromJson(on.toJson()), on);
    },
  );
}
