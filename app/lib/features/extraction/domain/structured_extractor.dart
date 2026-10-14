import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/features/extraction/domain/output_schema_validator.dart';

/// One structured extraction (LLM-05). The prompts come from the profile
/// prompt builder (PRF-02); [grammar] is the profile's cached GBNF
/// (generated once on save by `NativeSchemaGrammarConverter`).
@immutable
final class ExtractionRequest {
  const ExtractionRequest({
    required this.systemPrompt,
    required this.userPrompt,
    required this.schema,
    required this.grammar,
    this.transcriptTimestamps = const {},
    this.maxTokens = 1024,
    this.summaryPrompt,
  });

  final String systemPrompt;

  /// Instructions + the delimited `<transcript>` block.
  final String userPrompt;
  final Map<String, Object?> schema;
  final String grammar;

  /// `hh:mm:ss` timestamps present in the transcript (evidence check).
  final Set<String> transcriptTimestamps;
  final int maxTokens;

  /// Fallback prompt (title + 2–4 sentence summary); defaults to a generic
  /// instruction around [userPrompt].
  final String? summaryPrompt;
}

/// Result of [StructuredExtractor.extract].
@immutable
final class ExtractionOutcome {
  const ExtractionOutcome({
    required this.valid,
    required this.repairUsed,
    this.data,
    this.fallbackSummary,
    this.droppedEvidence = 0,
    this.issues = const [],
  });

  /// Schema-valid JSON (after evidence cleanup); null when [valid] is false.
  final Map<String, Object?>? data;

  /// `extractions.valid`: false ⇒ render the `summary-only` template.
  final bool valid;
  final bool repairUsed;

  /// Free-text summary when structured extraction failed twice.
  final String? fallbackSummary;

  /// Evidence timestamps removed because they do not exist in the transcript.
  final int droppedEvidence;

  /// Validation issues of the last failed attempt (paths/rules only).
  final List<String> issues;
}

/// Grammar-constrained extraction with schema validation, one repair
/// attempt and a summary-only fallback (vv-llm-inference → Constrained
/// output / Fallback).
final class StructuredExtractor {
  const StructuredExtractor(
    this._engine, {
    this.validator = const OutputSchemaValidator(),
    this.evidenceKey = 't',
  });

  final LlmEngine _engine;
  final OutputSchemaValidator validator;

  /// Object key holding an `hh:mm:ss` evidence timestamp.
  final String evidenceKey;

  static final _timestamp = RegExp(r'^\d{2}:[0-5]\d:[0-5]\d$');

  Future<Result<ExtractionOutcome>> extract(
    ExtractionRequest req, {
    CancelToken? cancel,
  }) async {
    final first = await _engine.generate(
      LlmRequest(
        prompt: req.userPrompt,
        systemPrompt: req.systemPrompt,
        grammar: req.grammar,
        maxTokens: req.maxTokens,
      ),
      cancel: cancel,
    );
    if (first case Err(:final failure)) return Err(failure);
    var output = first.valueOrNull!;
    var (data, issues) = _parse(output, req.schema);
    if (data != null) return Ok(_accept(data, req, repairUsed: false));

    // One repair attempt: the error list + previous output, greedy.
    final repair = await _engine.generate(
      LlmRequest(
        prompt:
            '${req.userPrompt}\n\nYour previous answer did not match the '
            'required JSON schema. Problems:\n- ${issues.join('\n- ')}\n'
            'Previous answer:\n$output\n'
            'Return the corrected JSON only.',
        systemPrompt: req.systemPrompt,
        grammar: req.grammar,
        maxTokens: req.maxTokens,
        sampling: const LlmSampling(preset: LlmPreset.deterministic),
      ),
      cancel: cancel,
    );
    if (repair case Err(:final failure)) {
      if (failure is CancelledFailure || failure is OutOfMemoryFailure) {
        return Err(failure);
      }
    } else {
      output = repair.valueOrNull!;
      (data, issues) = _parse(output, req.schema);
      if (data != null) return Ok(_accept(data, req, repairUsed: true));
    }

    // Fallback: free-text summary (title + 2–4 sentences).
    final summary = await _engine.generate(
      LlmRequest(
        prompt:
            req.summaryPrompt ??
            '${req.userPrompt}\n\nInstead of JSON, write a short title on '
                'the first line, then a 2–4 sentence summary.',
        systemPrompt: req.systemPrompt,
        maxTokens: 300,
        sampling: const LlmSampling(preset: LlmPreset.summary),
      ),
      cancel: cancel,
    );
    if (summary case Err(:final failure)) return Err(failure);
    return Ok(
      ExtractionOutcome(
        valid: false,
        repairUsed: true,
        fallbackSummary: summary.valueOrNull!.trim(),
        issues: issues,
      ),
    );
  }

  (Map<String, Object?>?, List<String>) _parse(
    String output,
    Map<String, Object?> schema,
  ) {
    final Object? decoded;
    try {
      decoded = jsonDecode(output);
    } on FormatException {
      return (null, [r'$: not valid JSON']);
    }
    final issues = validator.validate(decoded, schema);
    if (issues.isNotEmpty || decoded is! Map<String, Object?>) {
      return (null, issues.isEmpty ? [r'$: expected object'] : issues);
    }
    return (decoded, const []);
  }

  ExtractionOutcome _accept(
    Map<String, Object?> data,
    ExtractionRequest req, {
    required bool repairUsed,
  }) {
    var dropped = 0;
    // Schema-aware cleanup of unverifiable evidence (`t` not in the
    // transcript): optional key -> removed; nullable -> null; required and
    // non-nullable -> the whole list item is dropped (an item whose only
    // evidence is invented is most likely invented too). The result stays
    // schema-valid.
    const drop = Object();
    Object? clean(Object? v, Map<String, Object?>? s) {
      if (v is Map<String, Object?>) {
        final props = (s?['properties'] as Map<String, Object?>?) ?? const {};
        final required = (s?['required'] as List<Object?>?) ?? const [];
        final out = <String, Object?>{};
        for (final e in v.entries) {
          final sub = props[e.key] as Map<String, Object?>?;
          if (e.key == evidenceKey && e.value is String) {
            final ts = e.value! as String;
            if (!_timestamp.hasMatch(ts) ||
                !req.transcriptTimestamps.contains(ts)) {
              dropped++;
              final type = sub?['type'];
              final nullable =
                  type == 'null' || (type is List && type.contains('null'));
              if (nullable) {
                out[e.key] = null;
              } else if (required.contains(e.key)) {
                return drop;
              }
              continue;
            }
          }
          out[e.key] = clean(e.value, sub);
        }
        return out;
      }
      if (v is List) {
        final item = s?['items'] as Map<String, Object?>?;
        return [
          for (final x in v)
            if (clean(x, item) case final c when !identical(c, drop)) c,
        ];
      }
      return v;
    }

    final cleaned = clean(data, req.schema);
    return ExtractionOutcome(
      valid: true,
      repairUsed: repairUsed,
      data: identical(cleaned, drop)
          ? const <String, Object?>{}
          : cleaned! as Map<String, Object?>,
      droppedEvidence: dropped,
    );
  }
}

/// `hh:mm:ss` timestamps of transcript lines formatted `[hh:mm:ss] …`.
Set<String> transcriptTimestamps(String transcript) => {
  for (final m in RegExp(r'\[(\d{2}:[0-5]\d:[0-5]\d)\]').allMatches(transcript))
    m.group(1)!,
};
