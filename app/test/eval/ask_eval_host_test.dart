@TestOn('mac-os || linux')
library;

// End-to-end eval of the Ask engine (`AskService`, ASK-03): builds the
// synthetic library of `tools/bench/ask/library.json` in an in-memory
// database, then asks every question of `questions.json` through the same
// code path the app uses (FTS5 retrieval, grounded prompt, grammar-constrained
// 3B answer, citation validation). One JSON line per question.
//
// Skipped unless ASK_EVAL_MODEL is set. Run and scored by
// `python3 tools/bench/ask/ask_eval.py` (see its --help); direct use, from
// app/:
//   ASK_EVAL_MODEL=<3b.gguf> ASK_EVAL_OUT=<results.jsonl> \
//     [ASK_EVAL_LIB=<libvv_native>] [ASK_EVAL_REWRITE=1] [ASK_EVAL_ONLY=E01,U03] \
//     fvm flutter test test/eval/ask_eval_host_test.dart
//
// ASK_EVAL_REWRITE adds the pre-registered LLM query-rewrite arm: the model
// first lists search keywords, which extend the FTS query. Everything is
// synthetic and local; nothing leaves the machine.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/ask/data/db_ask_retriever.dart';
import 'package:vaultvoice/features/ask/domain/ask_models.dart';
import 'package:vaultvoice/features/ask/domain/ask_query.dart';
import 'package:vaultvoice/features/ask/domain/ask_retriever.dart';
import 'package:vaultvoice/features/ask/domain/ask_service.dart';
import 'package:vaultvoice/features/extraction/data/ffi_llm_runtime.dart';
import 'package:vaultvoice/features/extraction/data/native_schema_grammar_converter.dart';
import 'package:vaultvoice/features/extraction/domain/llm_backend_policy.dart';
import 'package:vaultvoice/features/extraction/domain/llm_service.dart';
import 'package:vaultvoice/features/extraction/domain/model_residency.dart';
import 'package:vv_native/vv_native.dart';

final class _FixedClock implements Clock {
  const _FixedClock(this.at);
  final DateTime at;
  @override
  DateTime now() => at;
}

/// Eval-only arm: the LLM lists keywords that extend the FTS query.
final class _RewritingRetriever implements AskRetriever {
  _RewritingRetriever(this.inner, this.llm);

  final AskRetriever inner;
  final LlmEngine llm;

  @override
  Future<Result<List<AskPassage>>> retrieve(AskQuery query) async {
    final res = await llm.generate(
      LlmRequest(
        systemPrompt:
            'List up to 8 short search keywords (single words, synonyms '
            'included) for finding the answer to the question in voice '
            'notes. Output only the keywords separated by spaces.',
        prompt: query.question,
        maxTokens: 40,
      ),
    );
    final extra = switch (res) {
      Ok(:final value) => askContentStems(value),
      Err() => const <String>[],
    };
    final stems = {...query.stems, ...extra}.toList();
    return await inner.retrieve(
      AskQuery(
        question: query.question,
        stems: stems,
        range: query.range,
        recordingId: query.recordingId,
        profileId: query.profileId,
        tags: query.tags,
      ),
    );
  }
}

void main() {
  final env = Platform.environment;
  final model = env['ASK_EVAL_MODEL'];
  test(
    'Ask end-to-end eval',
    () async {
      final bench = Directory('../tools/bench').path;
      final lib =
          env['ASK_EVAL_LIB'] ?? '../native/build/host/libvv_native.dylib';
      await _run(
        bench: bench,
        lib: lib,
        model: model!,
        out: env['ASK_EVAL_OUT'],
        nCtx: int.parse(env['ASK_EVAL_NCTX'] ?? '$kAskContextSize'),
        rewrite: env['ASK_EVAL_REWRITE'] == '1',
        verify: env['ASK_EVAL_VERIFY'] == '1',
        only: env['ASK_EVAL_ONLY']?.split(',').toSet(),
      );
    },
    skip: model == null ? 'set ASK_EVAL_MODEL (3B GGUF)' : null,
    timeout: const Timeout(Duration(hours: 2)),
  );
}

Future<void> _run({
  required String bench,
  required String lib,
  required String model,
  required int nCtx,
  required bool rewrite,
  required bool verify,
  String? out,
  Set<String>? only,
}) async {
  final library = jsonDecode(
    File('$bench/ask/library.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final questions = [
    for (final f in ['questions.json', 'questions_ask05.json'])
      ...((jsonDecode(File('$bench/ask/$f').readAsStringSync())
                  as Map<String, Object?>)['questions']!
              as List<Object?>)
          .cast<Map<String, Object?>>(),
  ];

  final db = VaultVoiceDatabase(NativeDatabase.memory());
  await _seed(db, library, bench);

  final native = VvNative.open(hostPath: lib);
  final llm = LlmService(
    runtime: FfiLlmRuntime(native),
    modelPath: model,
    backend: () =>
        const LlmBackendChoice(useGpu: false, reason: 'ask-eval host cpu'),
    contextSize: nCtx,
  );
  final residency = ModelResidency()..register(ResidentModel.llm, llm.unload);
  final today = DateTime.parse(library['today']! as String);
  final dbRetriever = DbAskRetriever(db);
  final service = AskService(
    retriever: rewrite ? _RewritingRetriever(dbRetriever, llm) : dbRetriever,
    engine: llm,
    grammarConverter: NativeSchemaGrammarConverter(hostPath: lib),
    residency: residency,
    deviceSupportsAsk: () => true,
    modelInstalled: () => true,
    pipelineBusy: () => false,
    contextSize: nCtx,
    clock: _FixedClock(DateTime(today.year, today.month, today.day, 12)),
    idleUnload: const Duration(hours: 1),
    verifyCitations: verify,
  );

  final sink = out == null ? null : File(out).openWrite();
  try {
    for (final q in questions) {
      final id = q['id']! as String;
      if (only != null && !only.contains(id)) continue;
      final watch = Stopwatch()..start();
      final res = await service.ask(AskRequest(question: q['q']! as String));
      watch.stop();
      final record = <String, Object?>{
        'id': id,
        'ms': watch.elapsedMilliseconds,
        'arm': rewrite ? 'rewrite' : 'base',
      };
      switch (res) {
        case Ok(:final value):
          record.addAll({
            'outcome': value.outcome.name,
            'answer': value.answer,
            'citations': [
              for (final c in value.citations)
                {'rec': c.recordingId, 't': formatAskTimestamp(c.tMs)},
            ],
            'passages': [
              for (final p in value.passages)
                {'rec': p.recordingId, 't': p.timestamp, 'kind': p.kind.name},
            ],
          });
        case Err(:final failure):
          record.addAll({'outcome': 'error', 'error': failure.message});
      }
      sink?.writeln(jsonEncode(record));
    }
  } finally {
    await sink?.close();
    llm.unload();
    await db.close();
  }
}

int _ms(String hms) {
  final p = hms.split(':').map(int.parse).toList();
  return ((p[0] * 60 + p[1]) * 60 + p[2]) * 1000;
}

Future<void> _seed(
  VaultVoiceDatabase db,
  Map<String, Object?> library,
  String bench,
) async {
  final line = RegExp(r'\[(\d\d:\d\d:\d\d)\]\s*(.*)');
  for (final r
      in (library['recordings']! as List<Object?>)
          .cast<Map<String, Object?>>()) {
    final id = r['id']! as String;
    final profile = r['profile']! as String;
    final dir = '$bench/eval/$profile/$id';
    final expected = jsonDecode(
      File('$dir/expected.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final title =
        (expected['title'] as String?) ??
        [
          'brand',
          'product',
          'model',
        ].map((k) => '${expected[k] ?? ''}').join(' ').trim();
    final d = DateTime.parse(r['date']! as String);
    final at = DateTime(d.year, d.month, d.day, 12);
    await db
        .into(db.recordings)
        .insert(
          RecordingsCompanion.insert(
            id: id,
            createdAt: at,
            status: RecordingStatus.recorded,
            source: RecordingSource.mic,
            title: Value(title),
            profileId: Value(profile),
          ),
        );
    await db
        .into(db.transcripts)
        .insert(
          TranscriptsCompanion.insert(
            id: 't-$id',
            recordingId: id,
            modelId: 'eval',
            language: 'en',
            createdAt: at,
          ),
        );
    var seq = 0;
    for (final l in File('$dir/transcript.txt').readAsLinesSync()) {
      final m = line.firstMatch(l);
      if (m == null) continue;
      final start = _ms(m.group(1)!);
      await db
          .into(db.transcriptSegments)
          .insert(
            TranscriptSegmentsCompanion.insert(
              transcriptId: 't-$id',
              seq: seq++,
              startMs: start,
              endMs: start + 2000,
              body: m.group(2)!,
            ),
          );
    }
    await db
        .into(db.extractions)
        .insert(
          ExtractionsCompanion.insert(
            id: 'x-$id',
            recordingId: id,
            profileId: profile,
            profileVersion: 1,
            modelId: 'eval',
            json: expected,
            valid: true,
            createdAt: at,
          ),
        );
  }
}
