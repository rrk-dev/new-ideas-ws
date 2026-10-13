import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/id_generator.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/core/platform/stt_engine.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';

import '../fakes/fake_llm_engine.dart';
import '../fakes/fake_stt_engine.dart';
import '../helpers/fixtures.dart';
import '../helpers/pipeline_harness.dart';

/// Example pipeline test (QA-01). It stands in for the real orchestrator
/// (FND-05) with [_runOnce], a straight-line transcribe → extract → render →
/// write over the engine providers, to show how pipeline tests use the
/// harness, fixtures, deterministic clock/IDs and the acceptance-tag
/// convention (`[<ID>/ACn]` in the test name; docs/testing.md).
void main() {
  late PipelineHarness h;

  setUp(() {
    h = PipelineHarness(
      stt: FakeSttEngine(segments: Fixtures.transcript('meeting_short')),
      llm: FakeLlmEngine(
        tokens: tokensOf(Fixtures.readString('llm/meeting_short.json').trim()),
        perToken: const Duration(milliseconds: 1),
      ),
    );
  });

  test('[QA-01/AC1] example tagged test: fakes drive the pipeline to the '
      'expected Markdown fixture', () async {
    final progress = <double>[];
    final tokens = <String>[];
    final audio = writeSynthWav(h.workDir, 'rec.wav');

    final result = await _runOnce(
      h.container,
      audio.path,
      onProgress: progress.add,
      onToken: tokens.add,
    );

    expect(result.valueOrNull?.location, 'fake://notes/id-0001.md');
    expect(
      h.vault.notes['notes/id-0001.md'],
      Fixtures.readString('markdown/meeting_short.md'),
    );
    expect(progress, [0.25, 0.5, 0.75, 1.0]);
    expect(tokens.join(), contains('"decisions"'));
    expect(h.stt.calls, [audio.path]);
    expect(h.llm.requests.single.prompt, contains('watering schedule'));
  });

  test(
    'kill mid-extraction, restart, re-run: one note, no data loss',
    () async {
      final audio = writeSynthWav(h.workDir, 'rec.wav');
      final cancel = CancelToken();
      final killed = _runOnce(
        h.container,
        audio.path,
        cancel: cancel,
        onToken: (_) => cancel.cancel(), // "app killed" after the first token
      );
      expect((await killed).failureOrNull, isA<CancelledFailure>());
      expect(h.vault.notes, isEmpty);

      final relaunched = h.restart();
      final result = await _runOnce(relaunched, audio.path);

      expect(result.isOk, isTrue);
      expect(h.vault.notes.keys, ['notes/id-0002.md']);
      expect(h.restarts, 1);
    },
  );

  test('an injected engine failure surfaces as that Failure', () async {
    h.stt.failWith(const ModelMissingFailure('ggml-tiny.en'));
    final result = await _runOnce(h.container, 'missing.wav');
    expect(result.failureOrNull, isA<ModelMissingFailure>());
    expect(h.llm.requests, isEmpty);
    expect(h.vault.notes, isEmpty);
  });
}

Future<Result<WrittenNote>> _runOnce(
  ProviderContainer c,
  String audioPath, {
  CancelToken? cancel,
  ProgressCallback? onProgress,
  void Function(String token)? onToken,
}) async {
  final id = c.read(idGeneratorProvider).next();
  final created = c.read(clockProvider).now();
  final transcribed = await c
      .read(sttEngineProvider)
      .transcribe(audioPath, cancel: cancel, onProgress: onProgress);
  final Transcript transcript;
  switch (transcribed) {
    case Ok(:final value):
      transcript = value;
    case Err(:final failure):
      return Err(failure);
  }
  final extracted = await c
      .read(llmEngineProvider)
      .generate(
        LlmRequest(prompt: 'Extract meeting notes:\n${transcript.text}'),
        cancel: cancel,
        onToken: onToken,
      );
  final String json;
  switch (extracted) {
    case Ok(:final value):
      json = value;
    case Err(:final failure):
      return Err(failure);
  }
  final data = jsonDecode(json) as Map<String, Object?>;
  final items = (data['action_items']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final markdown = StringBuffer()
    ..writeln('---')
    ..writeln('id: $id')
    ..writeln('created: ${created.toIso8601String()}')
    ..writeln('title: "${data['title']}"')
    ..writeln('---')
    ..writeln()
    ..writeln('# ${data['title']}')
    ..writeln()
    ..writeln('## Decisions');
  for (final d in (data['decisions']! as List<Object?>).cast<String>()) {
    markdown.writeln('- $d');
  }
  markdown
    ..writeln()
    ..writeln('## Action items');
  for (final i in items) {
    markdown.writeln('- [ ] ${i['owner']}: ${i['task']} (due ${i['due']})');
  }
  markdown
    ..writeln()
    ..writeln('## Transcript')
    ..writeln(transcript.text);
  return await c
      .read(vaultWriterProvider)
      .write(
        NoteDraft(relativePath: 'notes/$id.md', markdown: markdown.toString()),
      );
}
