import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/map_reduce_extractor.dart';
import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_projection.dart';
import 'package:vaultvoice/features/mindmap/domain/mind_map_schema.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/profiles/domain/transcript_grounding.dart';

/// How the tree is produced (ADR-MAP-01).
enum MindMapMethod {
  /// A: deterministic projection of the extraction JSON.
  projection,

  /// B: grammar-constrained LLM topic pass (map-reduce for long transcripts).
  llm,

  /// C: A's branches plus B's topics.
  hybrid,
}

/// Outcome of one generation. [tree] is null when the result was rejected
/// (nothing is stored); the counters feed the eval metrics.
@immutable
final class MindMapResult {
  const MindMapResult({
    required this.method,
    required this.tree,
    required this.schemaValid,
    this.rawLabels = 0,
    this.groundedLabels = 0,
  });

  final MindMapMethod method;
  final MindMapNode? tree;

  /// The source of the tree was valid: the LLM topic output matched its
  /// schema (B/C) or the extraction JSON was available (A).
  final bool schemaValid;

  /// LLM-offered non-root labels, and how many the transcript supports
  /// (measured before any filter). Zero for the projection.
  final int rawLabels;
  final int groundedLabels;
}

/// Everything one generation reads.
@immutable
final class MindMapInput {
  const MindMapInput({
    required this.lines,
    required this.tier,
    required this.modelId,
    this.extraction,
    this.fallbackTitle = 'Recording',
    this.maxTokens = 768,
  });

  final List<TranscriptLine> lines;
  final Map<String, Object?>? extraction;
  final DeviceTier tier;
  final String modelId;
  final String fallbackTitle;
  final int maxTokens;
}

/// The only way trees get made: every result went through
/// [normalizeMindMap], so it passes [validateMindMap] or is null.
final class MindMapGenerator {
  MindMapGenerator({required this.method, this.extractor, this.grammar})
    : assert(
        method == MindMapMethod.projection ||
            (extractor != null && grammar != null),
        'the LLM methods need an extractor and a grammar',
      );

  final MindMapMethod method;
  final MapReduceExtractor? extractor;

  /// GBNF of [kMindMapLlmSchema].
  final String? grammar;

  Future<Result<MindMapResult>> generate(
    MindMapInput input, {
    CancelToken? cancel,
    ProgressCallback? onProgress,
    MapReduceCheckpointStore? checkpoints,
  }) async {
    final stamps = {for (final l in input.lines) formatTimestamp(l.startMs)};
    final projected = method == MindMapMethod.llm
        ? null
        : projectExtraction(
            input.extraction,
            fallbackTitle: input.fallbackTitle,
          );
    if (method == MindMapMethod.projection) {
      final tree = normalizeMindMap(projected, transcriptTimestamps: stamps);
      return Ok(
        MindMapResult(
          method: method,
          tree: tree,
          schemaValid: input.extraction != null,
        ),
      );
    }

    final run = await extractor!.extract(
      LongExtractionInput(
        lines: input.lines,
        prompts: const MindMapPromptSource(),
        spec: MapReduceSpec(
          schema: kMindMapLlmSchema,
          grammar: grammar!,
          strategyFor: mindMapReduceStrategy,
        ),
        tier: input.tier,
        maxTokens: input.maxTokens,
        paramsKey: 'mindmap|${input.modelId}',
      ),
      cancel: cancel,
      onProgress: onProgress,
      checkpoints: checkpoints,
    );
    if (run case Err(:final failure)) return Err(failure);
    final outcome = run.valueOrNull!.outcome;
    final topics = _topicsToRaw(
      outcome.valid ? outcome.data : null,
      input.fallbackTitle,
    );

    final grounding = TranscriptGrounding(
      input.lines.map((l) => l.text).join('\n'),
    );
    var raw = 0;
    var supported = 0;
    void count(Object? node) {
      for (final c in ((node as Map?)?['children'] as List?) ?? const []) {
        raw++;
        if (grounding.supports((c as Map)['label'] as String? ?? '')) {
          supported++;
        }
        count(c);
      }
    }

    count(topics);

    // Only LLM-written labels are checked against the transcript; the
    // projection's branch names are fixed field names.
    final grounded = normalizeMindMap(
      topics,
      transcriptTimestamps: stamps,
      grounded: grounding.supports,
    );
    final MindMapNode? tree;
    if (method == MindMapMethod.hybrid && projected != null) {
      tree = normalizeMindMap({
        ...projected,
        'children': [
          ...(projected['children']! as List),
          ...(grounded?.toJson()['children'] as List? ?? const []),
        ],
      }, transcriptTimestamps: stamps);
    } else {
      tree = grounded;
    }
    return Ok(
      MindMapResult(
        method: method,
        tree: tree,
        schemaValid: outcome.valid,
        rawLabels: raw,
        groundedLabels: supported,
      ),
    );
  }

  static Map<String, Object?>? _topicsToRaw(
    Map<String, Object?>? data,
    String fallbackTitle,
  ) {
    if (data == null) return null;
    final title = data['title'];
    return {
      'label': title is String && title.trim().isNotEmpty
          ? title
          : fallbackTitle,
      'children': [
        for (final t in (data['topics'] as List?) ?? const [])
          if (t is Map)
            {
              'label': t['label'],
              't': t['t'],
              'children': [
                for (final p in (t['points'] as List?) ?? const [])
                  {'label': p, 'children': <Object?>[]},
              ],
            },
      ],
    };
  }
}
