import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/profiles/data/profile_registry.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/extraction_prompts.dart';
import 'package:vaultvoice/features/profiles/domain/profile_grammar.dart';

part 'profile_providers.g.dart';

/// Schema → GBNF converter. No default: LLM-05 overrides it with the
/// native-bridge implementation (`vv_json_schema_to_gbnf`); tests use
/// `FakeSchemaGrammarConverter`.
@Riverpod(keepAlive: true)
SchemaGrammarConverter schemaGrammarConverter(Ref ref) =>
    throw UnimplementedError(
      'schemaGrammarConverterProvider must be overridden',
    );

/// Asset loader; tests override it to read from disk or memory.
@Riverpod(keepAlive: true)
Future<String> Function(String key) profileAssetLoader(Ref ref) =>
    rootBundle.loadString;

/// Built-in profiles, parsed from assets once per launch.
@Riverpod(keepAlive: true)
Future<BuiltinProfiles> builtinProfiles(Ref ref) async {
  final load = ref.watch(profileAssetLoaderProvider);
  return BuiltinProfiles.parse({
    for (final asset in kBuiltinProfileAssets) asset: await load(asset),
  });
}

@Riverpod(keepAlive: true)
Future<ProfileRegistry> profileRegistry(Ref ref) async => ProfileRegistry(
  dao: ref.watch(profilesRepositoryProvider),
  builtins: await ref.watch(builtinProfilesProvider.future),
  grammarConverter: ref.watch(schemaGrammarConverterProvider),
  clock: ref.watch(clockProvider),
);

/// PRF-02 extraction prompts for a profile — the seam the extract step
/// (FND-11) and the map-reduce strategy (LLM-06) call for single-pass and
/// per-chunk prompts. The exact-budget chat-message path is
/// `PromptBuilder(SessionPromptTokenizer(session)).build(...)`.
@Riverpod(keepAlive: true)
ExtractionPromptsFactory extractionPrompts(Ref ref) =>
    (profile, {metadata}) => ExtractionPrompts(profile, metadata: metadata);
