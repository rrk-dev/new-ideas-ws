import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_orchestrator.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/templates/data/template_note_renderer.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_llm_engine.dart';
import '../../fakes/fake_stt_engine.dart';
import '../../fakes/fake_vault_writer.dart';
import 'template_fixtures.dart';

NoteInput input({
  String profileId = 'meeting',
  bool valid = true,
  bool consent = true,
  Map<String, Object?>? json,
}) => NoteInput(
  recording: RecordingRow(
    id: 'rec-1',
    title: '',
    createdAt: DateTime(2026, 10, 13, 14, 5),
    durationMs: 65000,
    status: RecordingStatus.values.first,
    source: RecordingSource.values.first,
    tags: const ['work'],
    consentConfirmedAt: consent ? DateTime.utc(2026, 10, 13, 12) : null,
    recovered: false,
  ),
  extraction: ExtractionRow(
    id: 'x1',
    recordingId: 'rec-1',
    profileId: profileId,
    profileVersion: 1,
    modelId: 'llm-q4',
    json: json ?? meetingFull(),
    valid: valid,
    createdAt: DateTime(2026, 10, 13, 14, 10),
  ),
  segments: const [
    TranscriptSegmentRow(
      id: 1,
      transcriptId: 't1',
      seq: 0,
      startMs: 5000,
      endMs: 9000,
      speaker: 'Priya',
      body: 'Hello # there',
    ),
  ],
);

void main() {
  final warnings = <String>[];
  final renderer = TemplateNoteRenderer(
    profiles: builtinProfiles,
    templates: builtinTemplates,
    appVersion: '1.0.0',
    onWarnings: warnings.addAll,
  );
  setUp(warnings.clear);

  test('renders the profile default template', () {
    final md = renderer(input());
    expect(
      md,
      startsWith('---\ntitle: "Q4 Planning Sync"\ndate: 2026-10-13\n'),
    );
    expect(md, contains('- [ ] Update the client SDK (@Sam) 📅 2026-10-16'));
    expect(md, contains('consent_at: "2026-10-13T'));
    expect(warnings, isEmpty);
  });

  test(
    '[SEC-07/AC2] consent_at is in the front-matter only when confirmed',
    () {
      final withConsent = renderer(input());
      final front = withConsent.split('\n---\n').first;
      expect(front, contains('consent_at: "2026-10-13T'));
      expect(renderer(input(consent: false)), isNot(contains('consent_at')));
    },
  );

  test('invalid extraction or unknown profile → summary-only', () {
    final md = renderer(input(valid: false, json: {'summary': 'Prose.'}));
    expect(md, contains('extraction: failed'));
    expect(md, contains('## Summary\n\nProse.'));
    expect(md, contains('> [00:00:05] Priya: Hello # there'));
    final unknown = renderer(input(profileId: 'gone'));
    expect(unknown, contains('extraction: failed'));
    expect(unknown, contains('# Q4 Planning Sync'));
  });

  test('user template override; broken template falls back with a '
      'warning; profiles without a template get a generated one', () {
    final mine = TemplateNoteRenderer(
      profiles: builtinProfiles,
      templates: builtinTemplates,
      appVersion: '1',
      userTemplates: const {'mine': '# {{meta.date}}'},
      templateOverrides: const {'meeting': 'mine'},
    );
    expect(mine(input()), '# 2026-10-13\n');

    final custom = customProfile();
    final broken = TemplateNoteRenderer(
      profiles: builtinProfiles,
      templates: builtinTemplates,
      appVersion: '1',
      userProfiles: {custom.id: custom},
      userTemplates: {custom.templateId: '{{#data.site}}'},
      onWarnings: warnings.addAll,
    );
    final md = broken(input(profileId: custom.id, json: customFull()));
    expect(warnings.single, contains('${custom.templateId}:1:1'));
    // Generated from the schema.
    expect(md, contains('## Measurements'));
    expect(md, contains('- [x] Helmets (@Lena)'));
  });

  test('seam: defaultSteps hands engines.renderer to RenderStep', () {
    final db = memoryDb();
    final steps = defaultSteps(
      db: db,
      paths: StoragePaths('/tmp/vv-unused'),
      engines: PipelineEngines(
        stt: FakeSttEngine(),
        llm: FakeLlmEngine(),
        vault: FakeVaultWriter(),
        renderer: renderer.call,
      ),
    );
    final render = steps.whereType<RenderStep>().single;
    expect(render.renderer(input()), renderer(input()));
  });
}
