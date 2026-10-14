import 'dart:isolate';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vv_native/vv_native.dart';

/// JSON Schema → GBNF over `vv_json_schema_to_gbnf` (LLM-05, llama.cpp's
/// json-schema-to-grammar in `vv_jsg`).
///
/// Implements PRF-01's `SchemaGrammarConverter` interface
/// (`features/profiles/domain/profile_grammar.dart` on
/// `task/PRF-01-profile-data-model`, not merged into this branch): same
/// method, `Future<Result<String>> toGbnf(String schemaJson)`. Add
/// `implements SchemaGrammarConverter` when PRF-01 lands — no other change.
/// A conversion failure is a profile validation error.
final class NativeSchemaGrammarConverter {
  NativeSchemaGrammarConverter({this.hostPath});

  /// Host library path (tests); null on devices.
  final String? hostPath;

  Future<Result<String>> toGbnf(String schemaJson) async {
    final hostPath = this.hostPath;
    try {
      // Large schemas take a few ms; keep it off the UI isolate.
      final gbnf = await Isolate.run(
        () => VvNative.open(hostPath: hostPath).jsonSchemaToGbnf(schemaJson),
      );
      return Ok(gbnf);
    } on VvLlmException catch (e) {
      return Err(
        e.code == VV_E_INVALID_ARG
            ? NativeFailure(e.code, 'schema cannot be converted to a grammar')
            : NativeFailure(e.code, 'grammar conversion failed'),
      );
    }
  }
}
