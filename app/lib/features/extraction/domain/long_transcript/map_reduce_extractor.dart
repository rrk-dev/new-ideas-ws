import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/core/utils/ids.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/extraction_prompts.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/partial_reducer.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/token_budget.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';
import 'package:vaultvoice/features/extraction/domain/output_schema_validator.dart';
import 'package:vaultvoice/features/extraction/domain/structured_extractor.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_grammar.dart';

/// Schemas, grammars and reduce strategies of one profile version.
@immutable
final class MapReduceSpec {
  const MapReduceSpec({
    required this.schema,
    required this.grammar,
    required this.strategyFor,
    Map<String, Object?>? mapSchema,
    String? mapGrammar,
  }) : mapSchema = mapSchema ?? schema,
       mapGrammar = mapGrammar ?? grammar;

  /// `map_schema` when the profile declares one, else `schema` (same fields,
  /// filled partially per chunk).
  factory MapReduceSpec.fromProfile(Profile p, ProfileGrammars g) {
    final hasMap = p.mapSchema != null && g.mapSchema != null;
    return MapReduceSpec(
      schema: p.schema.toJson(),
      grammar: g.schema,
      mapSchema: hasMap ? p.mapSchema!.toJson() : null,
      mapGrammar: hasMap ? g.mapSchema : null,
      strategyFor: p.reduceStrategyFor,
    );
  }

  final Map<String, Object?> schema;
  final String grammar;
  final Map<String, Object?> mapSchema;
  final String mapGrammar;
  final ReduceStrategy Function(String field) strategyFor;
}

/// What one extraction works on.
@immutable
final class LongExtractionInput {
  const LongExtractionInput({
    required this.lines,
    required this.prompts,
    required this.spec,
    required this.tier,
    this.maxTokens = 1024,
    this.paramsKey = '',
  });

  final List<TranscriptLine> lines;
  final ExtractionPromptSource prompts;
  final MapReduceSpec spec;
  final DeviceTier tier;

  /// Output limit of a single-pass call (map calls may use less).
  final int maxTokens;

  /// Model id + profile id/version etc.: part of the checkpoint hash, so a
  /// resume never mixes partial results of different models/profiles.
  final String paramsKey;
}

/// Map-step checkpoint (vv-pipeline-orchestrator → chunk checkpoints):
/// `{paramsHash, chunks: [{s,e,o}], results: {"<i>": partial | null}}`.
/// Partial results are content: they live only in the encrypted DB
/// (`jobs.checkpoint`) and are never logged.
@immutable
final class MapReduceCheckpoint {
  const MapReduceCheckpoint({
    required this.paramsHash,
    required this.chunks,
    this.results = const {},
  });

  static MapReduceCheckpoint? fromJson(Map<String, Object?> json) {
    final mr = json['mapReduce'];
    if (mr is! Map<String, Object?>) return null;
    final hash = mr['paramsHash'];
    final chunks = mr['chunks'];
    final results = mr['results'];
    if (hash is! String || chunks is! List || results is! Map) return null;
    return MapReduceCheckpoint(
      paramsHash: hash,
      chunks: [
        for (final c in chunks.cast<Map<String, Object?>>())
          (c['s']! as int, c['e']! as int, c['o']! as int),
      ],
      results: {
        for (final e in results.entries)
          int.parse(e.key as String): e.value as Map<String, Object?>?,
      },
    );
  }

  final String paramsHash;

  /// `(start, end, overlapLines)` per chunk.
  final List<(int, int, int)> chunks;

  /// Finished chunks: index → partial JSON (null = failed validation).
  final Map<int, Map<String, Object?>?> results;

  MapReduceCheckpoint withResult(int index, Map<String, Object?>? data) =>
      MapReduceCheckpoint(
        paramsHash: paramsHash,
        chunks: chunks,
        results: {...results, index: data},
      );

  Map<String, Object?> toJson() => {
    'mapReduce': {
      'paramsHash': paramsHash,
      'chunks': [
        for (final (s, e, o) in chunks) {'s': s, 'e': e, 'o': o},
      ],
      'results': {for (final e in results.entries) '${e.key}': e.value},
    },
  };
}

/// Persists map checkpoints (pipeline: `StepContext.saveCheckpoint`).
abstract interface class MapReduceCheckpointStore {
  /// The checkpoint a resumed step starts from (null on a fresh run).
  MapReduceCheckpoint? get initial;

  /// Persists [checkpoint] after a finished chunk (atomically with it).
  Future<void> save(MapReduceCheckpoint checkpoint, double progress);
}

/// Result of [MapReduceExtractor.extract] (stats are content-free).
@immutable
final class LongExtractionResult {
  const LongExtractionResult({
    required this.outcome,
    required this.plan,
    this.chunks = 1,
    this.failedChunks = 0,
    this.resumedChunks = 0,
    this.llmReduceCalls = 0,
  });

  final ExtractionOutcome outcome;
  final ExtractionPlan plan;
  final int chunks;

  /// Map chunks whose output stayed schema-invalid after the repair.
  final int failedChunks;

  /// Chunks taken from the checkpoint instead of re-running.
  final int resumedChunks;
  final int llmReduceCalls;
}

/// Long-transcript extraction (LLM-06): plans single-pass vs map-reduce from
/// exact token counts, runs the map step chunk by chunk with checkpoints and
/// KV prefix reuse, merges partial JSON deterministically in Dart and asks
/// the LLM only for prose fields (`llm_summarize`). Short transcripts take
/// the LLM-05 single-pass path unchanged.
final class MapReduceExtractor {
  MapReduceExtractor({
    required this.engine,
    required this.tokenizer,
    this.planner = const TokenBudgetPlanner(),
    this.reducer = const PartialReducer(),
    this.validator = const OutputSchemaValidator(),
    this.reduceMaxTokens = 400,
  }) : _extractor = StructuredExtractor(engine, validator: validator);

  final LlmEngine engine;
  final LlmTokenizer tokenizer;
  final TokenBudgetPlanner planner;
  final PartialReducer reducer;
  final OutputSchemaValidator validator;

  /// Output cap of one prose-reduce call.
  final int reduceMaxTokens;
  final StructuredExtractor _extractor;

  Future<Result<LongExtractionResult>> extract(
    LongExtractionInput input, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
    MapReduceCheckpointStore? checkpoints,
  }) async {
    try {
      return await _extract(input, cancel, onProgress, checkpoints);
    } on _Abort catch (e) {
      return Err(e.failure);
    }
  }

  Future<T> _ok<T>(Future<Result<T>> r) async => switch (await r) {
    Ok(:final value) => value,
    Err(:final failure) => throw _Abort(failure),
  };

  Future<Result<LongExtractionResult>> _extract(
    LongExtractionInput input,
    CancelToken? cancel,
    ProgressCallback? onProgress,
    MapReduceCheckpointStore? checkpoints,
  ) async {
    final prompts = input.prompts;
    final system = prompts.systemPrompt;
    final chunkSystem = prompts.chunkSystemPrompt;
    final ctx = await _ok(tokenizer.contextWindow());
    var lines = input.lines;
    var lineTokens = [
      for (final l in lines) await _ok(tokenizer.countTokens(l.render())),
    ];
    final block = prompts.transcript(lines);
    final single = await _ok(
      tokenizer.countPromptTokens(
        prompts.singleUser(block, withExamples: true),
        systemPrompt: system,
      ),
    );
    final singleNoEx = await _ok(
      tokenizer.countPromptTokens(
        prompts.singleUser(block, withExamples: false),
        systemPrompt: system,
      ),
    );
    final emptyInfo = ChunkInfo(
      index: 99,
      count: 99,
      startMs: 0,
      endMs: lines.isEmpty ? 0 : lines.last.startMs,
    );
    final mapOverhead = await _ok(
      tokenizer.countPromptTokens(
        prompts.chunkUser(prompts.transcript(const []), emptyInfo),
        systemPrompt: chunkSystem,
      ),
    );
    final transcriptTokens = lineTokens.fold<int>(0, (a, b) => a + b);
    final ExtractionPlan plan;
    try {
      plan = planner.plan(
        contextWindow: ctx,
        transcriptTokens: transcriptTokens,
        maxOutputTokens: input.maxTokens,
        singlePromptTokens: single,
        singlePromptTokensNoExamples: singleNoEx,
        mapOverheadTokens: mapOverhead,
        tier: input.tier,
      );
    } on ContextTooSmall {
      return const Err(OutOfMemoryFailure());
    }

    if (!plan.isMapReduce) {
      final spec = input.spec;
      var tokens = 0;
      final out = await _ok(
        _extractor.extract(
          ExtractionRequest(
            systemPrompt: system,
            userPrompt: prompts.singleUser(
              block,
              withExamples: plan.mode == ExtractionMode.singlePass,
            ),
            schema: spec.schema,
            grammar: spec.grammar,
            transcriptTimestamps: transcriptTimestamps(block),
            maxTokens: input.maxTokens,
          ),
          cancel: cancel,
          onToken: (_) =>
              onProgress?.call((++tokens / input.maxTokens).clamp(0.0, 0.99)),
        ),
      );
      onProgress?.call(1);
      return Ok(LongExtractionResult(outcome: out, plan: plan));
    }

    // Map step. Each chunk block is recounted exactly; a chunk over budget
    // (merges across joined lines) re-plans with a 10% smaller target.
    final budget = plan.chunkTokens;
    final maxLine = budget ~/ 3;
    if (lineTokens.any((t) => t > maxLine)) {
      lines = splitLongLines(lines, lineTokens, maxLine);
      lineTokens = [
        for (final l in lines) await _ok(tokenizer.countTokens(l.render())),
      ];
    }
    var target = budget;
    late List<TranscriptChunk> chunks;
    for (var attempt = 0; ; attempt++) {
      chunks = chunkTranscript(
        lines,
        lineTokens,
        maxTokens: target,
        overlapTokens: plan.overlapTokens,
      );
      var worst = 0;
      for (final c in chunks) {
        final n = await _ok(
          tokenizer.countTokens(
            prompts.transcript(lines.sublist(c.start, c.end)),
          ),
        );
        if (n > worst) worst = n;
      }
      if (worst <= budget || attempt == 3) break;
      target = (target * 0.9).floor();
    }

    final hash = fnv1a32(
      jsonEncode([
        input.paramsKey,
        ctx,
        plan.maxOutputTokens,
        fnv1a32(block),
        [for (final c in chunks) c.toJson()],
      ]),
    );
    var cp = checkpoints?.initial;
    var resumed = 0;
    if (cp == null || cp.paramsHash != hash) {
      cp = MapReduceCheckpoint(
        paramsHash: hash,
        chunks: [for (final c in chunks) (c.start, c.end, c.overlapLines)],
      );
    } else {
      resumed = cp.results.length;
    }

    final spec = input.spec;
    // Progress units: one per map chunk + one per prose field to reduce.
    final proseFields = [
      for (final f
          in ((spec.schema['properties'] as Map<String, Object?>?) ?? const {})
              .keys)
        if (spec.strategyFor(f) == ReduceStrategy.llmSummarize) f,
    ];
    final units = chunks.length + proseFields.length;
    var repairUsed = false;
    var dropped = 0;
    for (final c in chunks) {
      if (cp!.results.containsKey(c.index)) continue;
      if (cancel?.isCancelled ?? false) return const Err(CancelledFailure());
      final chunkLines = lines.sublist(c.start, c.end);
      final chunkBlock = prompts.transcript(chunkLines);
      final info = ChunkInfo(
        index: c.index,
        count: chunks.length,
        startMs: chunkLines.first.startMs,
        endMs: chunkLines.last.startMs,
      );
      var tokens = 0;
      final done = c.index;
      final out = await _ok(
        _extractor.extract(
          ExtractionRequest(
            systemPrompt: chunkSystem,
            userPrompt: prompts.chunkUser(chunkBlock, info),
            schema: spec.mapSchema,
            grammar: spec.mapGrammar,
            transcriptTimestamps: transcriptTimestamps(chunkBlock),
            maxTokens: plan.maxOutputTokens,
            summaryFallback: false,
            reusePrefix: true,
          ),
          cancel: cancel,
          onToken: (_) => onProgress?.call(
            (done + (++tokens / plan.maxOutputTokens).clamp(0.0, 0.95)) / units,
          ),
        ),
      );
      repairUsed |= out.repairUsed;
      dropped += out.droppedEvidence;
      cp = cp.withResult(c.index, out.valid ? out.data : null);
      final progress = (c.index + 1) / units;
      if (checkpoints != null) {
        await checkpoints.save(cp, progress);
      }
      onProgress?.call(progress);
    }

    final partials = [
      for (final c in chunks)
        PartialResult(
          chunkIndex: c.index,
          chunkStartMs: lines[c.start].startMs,
          data: cp!.results[c.index],
        ),
    ];
    final failed = partials.where((p) => p.data == null).length;
    if (failed == chunks.length) {
      // Nothing structured survived: summary-only fallback (LLM-05 rule)
      // over the beginning of the recording.
      final first = lines.sublist(chunks.first.start, chunks.first.end);
      final summary = await _ok(
        engine.generate(
          LlmRequest(
            prompt:
                '<transcript>\n${prompts.transcript(first)}\n</transcript>'
                '\n\nWrite a short title on the '
                'first line, then a 2–4 sentence summary.',
            systemPrompt: system,
            maxTokens: 300,
            sampling: const LlmSampling(preset: LlmPreset.summary),
          ),
          cancel: cancel,
        ),
      );
      onProgress?.call(1);
      return Ok(
        LongExtractionResult(
          outcome: ExtractionOutcome(
            valid: false,
            repairUsed: true,
            fallbackSummary: summary.trim(),
            issues: const [r'$: every map chunk failed validation'],
          ),
          plan: plan,
          chunks: chunks.length,
          failedChunks: failed,
          resumedChunks: resumed,
        ),
      );
    }

    final reduced = reducer.reduce(
      schema: spec.schema,
      strategyFor: spec.strategyFor,
      partials: partials,
    );
    final data = {...reduced.data};
    var llmCalls = 0;
    final props = (spec.schema['properties'] as Map<String, Object?>?) ?? {};
    for (final (i, field) in proseFields.indexed) {
      final fs = (props[field] as Map<String, Object?>?) ?? const {};
      final maxLength = (fs['maxLength'] as num?)?.toInt() ?? 600;
      final parts = reduced.proseInputs[field] ?? const <String>[];
      if (parts.isEmpty) {
        data[field] = null;
      } else if (parts.length == 1) {
        data[field] = _clip(parts.single, maxLength);
      } else {
        final (text, calls) = await _reduceProse(
          input,
          field,
          parts,
          maxLength: maxLength,
          description: fs['description'] as String?,
          contextWindow: ctx,
          cancel: cancel,
        );
        llmCalls += calls;
        data[field] = text;
      }
      onProgress?.call((chunks.length + i + 1) / units);
    }

    final conformed = _conform(data, spec.schema);
    final issues = validator.validate(conformed, spec.schema);
    onProgress?.call(1);
    return Ok(
      LongExtractionResult(
        outcome: ExtractionOutcome(
          valid: issues.isEmpty,
          repairUsed: repairUsed,
          data: issues.isEmpty ? conformed : null,
          droppedEvidence: dropped,
          issues: issues,
          fallbackSummary: issues.isEmpty
              ? null
              : conformed['summary'] as String?,
        ),
        plan: plan,
        chunks: chunks.length,
        failedChunks: failed,
        resumedChunks: resumed,
        llmReduceCalls: llmCalls,
      ),
    );
  }

  /// One prose field from its parts; hierarchical when the parts do not fit
  /// one prompt (halves → partial texts → final).
  Future<(String, int)> _reduceProse(
    LongExtractionInput input,
    String field,
    List<String> parts, {
    required int maxLength,
    required String? description,
    required int contextWindow,
    required CancelToken? cancel,
  }) async {
    final prompts = input.prompts;
    final user = prompts.reduceUser(
      field,
      parts,
      maxLength: maxLength,
      description: description,
    );
    final n = await _ok(
      tokenizer.countPromptTokens(user, systemPrompt: prompts.systemPrompt),
    );
    if (n + reduceMaxTokens + planner.safetyTokens > contextWindow &&
        parts.length > 2) {
      final mid = parts.length ~/ 2;
      final (a, ca) = await _reduceProse(
        input,
        field,
        parts.sublist(0, mid),
        maxLength: maxLength,
        description: description,
        contextWindow: contextWindow,
        cancel: cancel,
      );
      final (b, cb) = await _reduceProse(
        input,
        field,
        parts.sublist(mid),
        maxLength: maxLength,
        description: description,
        contextWindow: contextWindow,
        cancel: cancel,
      );
      final (c, cc) = await _reduceProse(
        input,
        field,
        [a, b],
        maxLength: maxLength,
        description: description,
        contextWindow: contextWindow,
        cancel: cancel,
      );
      return (c, ca + cb + cc);
    }
    final text = await _ok(
      engine.generate(
        LlmRequest(
          prompt: user,
          systemPrompt: prompts.systemPrompt,
          maxTokens: reduceMaxTokens,
          sampling: const LlmSampling(preset: LlmPreset.summary),
          reusePrefix: true,
        ),
        cancel: cancel,
      ),
    );
    final cleaned = _cleanProse(text, singleLine: maxLength <= 120);
    // An empty answer falls back to the first part (still grounded).
    return (
      cleaned.isEmpty
          ? _clip(parts.first, maxLength)
          : _clip(cleaned, maxLength),
      1,
    );
  }

  static String _cleanProse(String raw, {required bool singleLine}) {
    var t = raw.trim();
    t = t.replaceFirst(
      RegExp(r'^(here is|here.s|sure[,!]?)[^\n:]*:\s*', caseSensitive: false),
      '',
    );
    if (singleLine) t = t.split('\n').first.trim();
    if (t.length >= 2 &&
        (t.startsWith('"') && t.endsWith('"') ||
            t.startsWith("'") && t.endsWith("'"))) {
      t = t.substring(1, t.length - 1).trim();
    }
    return t;
  }

  /// Cuts [s] to [max] code points, at a word boundary when possible.
  static String _clip(String s, int max) {
    final runes = s.runes.toList();
    if (runes.length <= max) return s;
    var cut = String.fromCharCodes(runes.take(max));
    final space = cut.lastIndexOf(' ');
    if (space > max * 0.6) cut = cut.substring(0, space);
    return cut.trimRight();
  }

  /// Fills fields the map schema did not produce: lists → `[]`, nullable →
  /// null, required strings → `''`; drops keys outside the schema.
  static Map<String, Object?> _conform(
    Map<String, Object?> data,
    Map<String, Object?> schema,
  ) {
    final props = (schema['properties'] as Map<String, Object?>?) ?? const {};
    final required = (schema['required'] as List<Object?>?) ?? const [];
    final out = <String, Object?>{};
    for (final e in props.entries) {
      final s = e.value! as Map<String, Object?>;
      final type = s['type'];
      final nullable = type is List && type.contains('null');
      final v = data[e.key];
      if (v != null) {
        out[e.key] = v is String && s['maxLength'] is num
            ? _clip(v, (s['maxLength']! as num).toInt())
            : v;
      } else if (type == 'array') {
        out[e.key] = const <Object?>[];
      } else if (nullable) {
        out[e.key] = null;
      } else if (required.contains(e.key) && type == 'string') {
        out[e.key] = '';
      }
    }
    return out;
  }
}

final class _Abort implements Exception {
  const _Abort(this.failure);

  final Failure failure;
}
